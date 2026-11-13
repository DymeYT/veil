// Desktop Glyph board: full-desktop snap grid, catalog of tiles, drag + fluent resize.
// Wallpaper layer; empty chrome click-through. Stable API for unify in-process hosting.
// VEI-37: remove via AX right-click menu + drag-to-trash (SwiftUI contextMenu never fires — pass-through host).
// VEI-54: live-display geometry sync, empty→Finder, local CPU/RAM, Glyph-home default spine.
import AppKit
import Combine
import Darwin
import SwiftUI

/// NSMenu target for AX right-click (board hit-tests nil → SwiftUI menus never open).
private final class GlyphCtxMenu: NSObject {
    weak var board: DesktopGlyphBoard?
    var id: DesktopGlyphID = .cpu
    @objc func remove() { Task { @MainActor in self.board?.removePin(self.id) } }
    @objc func reset() { Task { @MainActor in self.board?.resetToDefault() } }
    @objc func hideAll() { Task { @MainActor in self.board?.toggleEnabled() } }
    @objc func toggleAdd(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let gid = DesktopGlyphID(rawValue: raw) else { return }
        Task { @MainActor in self.board?.togglePin(gid) }
    }
}

enum DesktopGlyphID: String, Codable, CaseIterable, Identifiable {
    case clock, quick, cava, media
    case cpu, mem, gpu, battery, net, volume, sys

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    /// Default span when first pinned (compact). Resize can grow up to maxSpan.
    var defaultSpan: (cols: Int, rows: Int) {
        switch self {
        case .clock, .quick: return (2, 2)
        case .media: return (2, 1)
        default: return (1, 1)
        }
    }
    var maxSpan: (cols: Int, rows: Int) {
        switch self {
        case .clock, .quick: return (4, 3)
        case .media: return (4, 2)
        case .battery: return (4, 3) // large → multi-device board
        default: return (3, 2)
        }
    }
}

struct DesktopGlyphPin: Codable, Identifiable, Equatable {
    var id: DesktopGlyphID
    var col: Int
    var row: Int
    var pinned: Bool
    /// Fluent size in grid cells (persisted). Nil → id.defaultSpan.
    var colSpan: Int?
    var rowSpan: Int?
    var nx: Double?
    var ny: Double?

    var spanCols: Int { max(1, colSpan ?? id.defaultSpan.cols) }
    var spanRows: Int { max(1, rowSpan ?? id.defaultSpan.rows) }
}

/// Full click-through host (VEI-42). Window uses `ignoresMouseEvents = true`; hitTest always nil.
/// Tile click/drag/remove stay on AX global monitors — never steal empty-desktop / show-desktop clicks.
final class GlyphBoardHost<Content: View>: NSHostingView<Content> {
    weak var board: DesktopGlyphBoard?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class DesktopGlyphBoard: ObservableObject {
    static let shared = DesktopGlyphBoard()
    @Published var pins: [DesktopGlyphPin] = []
    @Published var enabled = true
    @Published var dragging: DesktopGlyphID?
    @Published var resizing: DesktopGlyphID?
    @Published var dragCol: Int?
    @Published var dragRow: Int?
    @Published var dragTranslation: CGSize = .zero
    @Published var resizeSpan: (cols: Int, rows: Int)?
    @Published var showGridGuides = false
    /// Drag-to-remove: cursor is over the bottom trash zone.
    @Published var overTrash = false

    /// Full-desktop grid — cells fill usable frame (bar/Dock insets), even gutters.
    let cols = 16
    let rows = 10
    let gutter: CGFloat = 10
    let marginX: CGFloat = 28
    /// v6: Glyph-home spine defaults + live geometry / local metrics (VEI-54).
    private let storeVersion = 6

    /// Board-owned metric readouts so tiles refresh without observing VeilPanelHost.
    @Published var cpuText = "—"
    @Published var memText = "—"
    @Published var gpuText = "—"
    @Published var batteryText = "—"
    @Published var netText = "Wi‑Fi"
    @Published var volumeText = "—"
    @Published var statusLine = ""

    private var window: NSWindow?
    private var host: GlyphBoardHost<AnyView>?
    private var tick: Timer?
    private var geomTick: Timer?
    private var lastScreenSig = ""
    private var loadedTheme: String?
    private var mouseMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var pendingID: DesktopGlyphID?
    private var pendingResize = false
    private var dragStartScreen: CGPoint = .zero
    private var dragArmed = false
    private var resizeStartSpan: (cols: Int, rows: Int) = (1, 1)
    private let dragThreshold: CGFloat = 4
    private var menuTarget: GlyphCtxMenu?
    private var lastLocalMetricsFetch = Date.distantPast
    private var themeId: String { Palette.load().s("theme_id", "nothing") }
    private var storePath: String { ncRoot + "/generated/desktop-glyphs-\(themeId).json" }
    private var legacyStorePath: String { ncRoot + "/generated/desktop-glyphs.json" }

    private var reduceMotion: Bool {
        VeilFeature.forceReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var needsMetaTick: Bool {
        pins.contains {
            $0.pinned && [.media, .sys, .cpu, .mem, .gpu, .battery, .net, .volume].contains($0.id)
        }
    }

    func start() {
        // Kill any leftover animated-panel husk before showing the board.
        VeilPanelHost.shared.dismissImmediate()
        load()
        guard enabled, !veilIsOff else { stop(); return }
        ensureWindow(force: true)
        installMouseMonitors()
        installScreenObserver()
        syncTick()
        syncGeomTick()
        refreshMetaOnly()
    }

    func stop() {
        tick?.invalidate(); tick = nil
        geomTick?.invalidate(); geomTick = nil
        removeScreenObserver()
        removeMouseMonitors()
        clearInteraction()
        window?.orderOut(nil)
        window?.contentView = nil
        host = nil
        window = nil
        lastScreenSig = ""
    }

    private func clearInteraction() {
        pendingID = nil
        pendingResize = false
        dragArmed = false
        dragTranslation = .zero
        resizeSpan = nil
        dragging = nil
        resizing = nil
        showGridGuides = false
        overTrash = false
    }

    private func syncTick() {
        tick?.invalidate(); tick = nil
        guard enabled, !veilIsOff, needsMetaTick else { return }
        let quiet = FileManager.default.fileExists(atPath: ncRoot + "/generated/quiet")
        let interval: TimeInterval = (reduceMotion || quiet) ? 90 : 5
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncGeometryIfNeeded()
                self?.refreshMetaOnly()
            }
        }
        t.tolerance = min(1.0, interval * 0.25)
        RunLoop.main.add(t, forMode: .common)
        tick = t
    }

    /// Fast geometry heartbeat — catch scaled-display / Space / wake desync without waiting on meta.
    private func syncGeomTick() {
        geomTick?.invalidate(); geomTick = nil
        guard enabled, !veilIsOff else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncGeometryIfNeeded() }
        }
        t.tolerance = 0.25
        RunLoop.main.add(t, forMode: .common)
        geomTick = t
    }

    private func installScreenObserver() {
        removeScreenObserver()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.ensureWindow(force: true) }
        }
    }

    private func removeScreenObserver() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    func toggleEnabled() {
        enabled.toggle(); save()
        if enabled { start() } else { stop() }
    }

    func resetToDefault() {
        pins = defaultLayout(); save(); refresh()
    }

    func togglePin(_ id: DesktopGlyphID) {
        if let i = pins.firstIndex(where: { $0.id == id }) {
            if pins[i].pinned {
                removePin(id)
                return
            }
            pins[i].pinned = true
            pins[i] = placeWithoutOverlap(pins[i])
        } else {
            pins.append(placeWithoutOverlap(DesktopGlyphPin(
                id: id, col: 0, row: 0, pinned: true,
                colSpan: id.defaultSpan.cols, rowSpan: id.defaultSpan.rows)))
        }
        save(); refresh()
    }

    func setPin(_ id: DesktopGlyphID, pinned: Bool) {
        if !pinned {
            removePin(id)
            return
        }
        if let i = pins.firstIndex(where: { $0.id == id }) {
            pins[i].pinned = true
            pins[i] = placeWithoutOverlap(pins[i])
        } else {
            pins.append(placeWithoutOverlap(DesktopGlyphPin(
                id: id, col: 0, row: 0, pinned: true,
                colSpan: id.defaultSpan.cols, rowSpan: id.defaultSpan.rows)))
        }
        save(); refresh()
    }

    /// Delete Glyph from the board and persist (VEI-37).
    func removePin(_ id: DesktopGlyphID) {
        pins.removeAll { $0.id == id }
        clearInteraction()
        save()
        syncTick()
        ensureWindow(force: false)
        objectWillChange.send()
    }

    func move(_ id: DesktopGlyphID, toCol col: Int, toRow row: Int) {
        guard let i = pins.firstIndex(where: { $0.id == id }) else { return }
        let sc = pins[i].spanCols, sr = pins[i].spanRows
        pins[i].col = min(max(0, col), cols - sc)
        pins[i].row = min(max(0, row), rows - sr)
        resolveOverlaps(preferring: id)
        clearInteraction()
        save()
        objectWillChange.send()
    }

    func resize(_ id: DesktopGlyphID, cols c: Int, rows r: Int) {
        guard let i = pins.firstIndex(where: { $0.id == id }) else { return }
        let maxS = id.maxSpan
        let nc = min(max(1, c), maxS.cols, cols - pins[i].col)
        let nr = min(max(1, r), maxS.rows, rows - pins[i].row)
        pins[i].colSpan = nc
        pins[i].rowSpan = nr
        resolveOverlaps(preferring: id)
        clearInteraction()
        save()
        objectWillChange.send()
    }

    func beginDrag(_ id: DesktopGlyphID) {
        dragging = id; resizing = nil
        showGridGuides = true
        dragTranslation = .zero
        if let p = pins.first(where: { $0.id == id }) {
            dragCol = p.col; dragRow = p.row
        }
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 4)
        objectWillChange.send()
    }

    func beginResize(_ id: DesktopGlyphID) {
        resizing = id; dragging = nil
        showGridGuides = true
        if let p = pins.first(where: { $0.id == id }) {
            resizeStartSpan = (p.spanCols, p.spanRows)
            resizeSpan = resizeStartSpan
        }
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 4)
        objectWillChange.send()
    }

    func updateDrag(local point: CGPoint, canvas: CGSize) {
        guard let id = dragging, let pin = pins.first(where: { $0.id == id }) else { return }
        let cell = cellAt(point: point, canvas: canvas)
        dragCol = min(cols - pin.spanCols, max(0, cell.col))
        dragRow = min(rows - pin.spanRows, max(0, cell.row))
        overTrash = trashZone(in: canvas).insetBy(dx: -12, dy: -12).contains(point)
        objectWillChange.send()
    }

    /// Bottom-center drop target while dragging — release here removes the Glyph.
    func trashZone(in canvas: CGSize) -> CGRect {
        let w: CGFloat = 168, h: CGFloat = 52
        return CGRect(x: (canvas.width - w) / 2, y: canvas.height - h - 28, width: w, height: h)
    }

    func updateResize(local point: CGPoint, canvas: CGSize) {
        guard let id = resizing, let pin = pins.first(where: { $0.id == id }) else { return }
        let m = metrics(in: canvas)
        let origin = frame(for: pin, metrics: m)
        let rawW = max(m.cell.width, point.x - origin.minX)
        let rawH = max(m.cell.height, point.y - origin.minY)
        let strideX = m.cell.width + m.gutter
        let strideY = m.cell.height + m.gutter
        var nc = max(1, Int(ceil((rawW + m.gutter) / strideX)))
        var nr = max(1, Int(ceil((rawH + m.gutter) / strideY)))
        nc = min(nc, id.maxSpan.cols, cols - pin.col)
        nr = min(nr, id.maxSpan.rows, rows - pin.row)
        resizeSpan = (nc, nr)
        objectWillChange.send()
    }

    func endDrag(commit: Bool) {
        let id = dragging; let c = dragCol; let r = dragRow
        let dropTrash = overTrash
        dragTranslation = .zero
        if commit, dropTrash, let id {
            removePin(id)
        } else if commit, let id, let c, let r {
            overTrash = false
            move(id, toCol: c, toRow: r)
        } else {
            clearInteraction(); objectWillChange.send()
        }
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
    }

    /// Agent/screenshot path — remove without relying on right-click delivery.
    func proveRemove(_ id: DesktopGlyphID) { removePin(id) }

    func endResize(commit: Bool) {
        let id = resizing; let span = resizeSpan
        if commit, let id, let span { resize(id, cols: span.cols, rows: span.rows) }
        else { clearInteraction(); objectWillChange.send() }
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
    }

    /// Animate move — same pipeline as AX drag (agent VMs block synthetic CGEvents).
    func proveDrag(_ id: DesktopGlyphID, toCol: Int, toRow: Int, duration: TimeInterval = 0.7) {
        guard let pin = pins.first(where: { $0.id == id && $0.pinned }) else { return }
        let size = window?.frame.size ?? NSScreen.main?.frame.size ?? .zero
        let m = metrics(in: size)
        let from = frame(for: pin, metrics: m)
        var dest = pin
        dest.col = min(cols - pin.spanCols, max(0, toCol))
        dest.row = min(rows - pin.spanRows, max(0, toRow))
        let to = frame(for: dest, metrics: m)
        beginDrag(id)
        let steps = 24
        let stepDur = duration / Double(steps)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let ease = t * t * (3 - 2 * t)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDur * Double(i)) { [weak self] in
                guard let self, self.dragging == id else { return }
                self.dragTranslation = CGSize(width: (to.midX - from.midX) * ease,
                                              height: (to.midY - from.midY) * ease)
                self.dragCol = dest.col; self.dragRow = dest.row
                self.objectWillChange.send()
                if i == steps { self.dragTranslation = .zero; self.endDrag(commit: true) }
            }
        }
    }

    // MARK: - Glyph-home default on full-desktop grid (VEI-54)
    //
    // 16×10 usable frame. Large clock plane left; compact metric/Quick spine on the
    // right — Hyprland Glyph-home rhythm, not sparse center islands.
    private func defaultLayout() -> [DesktopGlyphPin] {
        [
            DesktopGlyphPin(id: .clock, col: 1, row: 1, pinned: true, colSpan: 4, rowSpan: 3),
            DesktopGlyphPin(id: .quick, col: 12, row: 1, pinned: true, colSpan: 3, rowSpan: 2),
            DesktopGlyphPin(id: .media, col: 12, row: 3, pinned: true, colSpan: 3, rowSpan: 1),
            DesktopGlyphPin(id: .cpu, col: 12, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .mem, col: 13, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .gpu, col: 14, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .battery, col: 12, row: 5, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .cava, col: 13, row: 5, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .net, col: 14, row: 5, pinned: true, colSpan: 1, rowSpan: 1),
        ]
    }

    // MARK: - Persistence

    private struct Store: Codable {
        var enabled: Bool
        var pins: [DesktopGlyphPin]
        var version: Int?
    }

    private func load() {
        let url = URL(fileURLWithPath: storePath)
        let legacy = URL(fileURLWithPath: legacyStorePath)
        if let data = try? Data(contentsOf: url),
           let obj = try? JSONDecoder().decode(Store.self, from: data), !obj.pins.isEmpty {
            enabled = obj.enabled
            if (obj.version ?? 1) < storeVersion {
                pins = defaultLayout(); save()
            } else {
                pins = migrateIfNeeded(obj.pins)
            }
        } else if FileManager.default.fileExists(atPath: legacy.path),
                  let data = try? Data(contentsOf: legacy),
                  let obj = try? JSONDecoder().decode(Store.self, from: data), !obj.pins.isEmpty {
            enabled = obj.enabled
            pins = defaultLayout(); save()
        } else {
            enabled = true
            pins = defaultLayout(); save()
        }
        loadedTheme = themeId
    }

    private func migrateIfNeeded(_ raw: [DesktopGlyphPin]) -> [DesktopGlyphPin] {
        raw.map { pin in
            var p = pin
            if p.colSpan == nil { p.colSpan = pin.id.defaultSpan.cols }
            if p.rowSpan == nil { p.rowSpan = pin.id.defaultSpan.rows }
            p.col = min(max(0, p.col), cols - p.spanCols)
            p.row = min(max(0, p.row), rows - p.spanRows)
            return p
        }
    }

    private func save() {
        let dir = (storePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let cleaned = pins.map {
            DesktopGlyphPin(id: $0.id, col: $0.col, row: $0.row, pinned: $0.pinned,
                            colSpan: $0.spanCols, rowSpan: $0.spanRows)
        }
        let data = try? JSONEncoder().encode(Store(enabled: enabled, pins: cleaned, version: storeVersion))
        try? data?.write(to: URL(fileURLWithPath: storePath), options: .atomic)
    }

    // MARK: - AX mouse monitors (real drag + resize)

    private func installMouseMonitors() {
        removeMouseMonitors()
        guard AXIsProcessTrusted() else { return }
        let down: (NSEvent) -> Void = { [weak self] e in Task { @MainActor in self?.onMouseDown(e) } }
        let drag: (NSEvent) -> Void = { [weak self] e in Task { @MainActor in self?.onMouseDragged(e) } }
        let up: (NSEvent) -> Void = { [weak self] e in Task { @MainActor in self?.onMouseUp(e) } }
        let right: (NSEvent) -> Void = { [weak self] e in Task { @MainActor in self?.onRightMouseDown(e) } }
        for mask in [NSEvent.EventTypeMask.leftMouseDown, .leftMouseDragged, .leftMouseUp] {
            let handler: (NSEvent) -> Void = mask == .leftMouseDown ? down : mask == .leftMouseDragged ? drag : up
            if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) { mouseMonitors.append(g) }
            if let g = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { e in handler(e); return e }) {
                mouseMonitors.append(g)
            }
        }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown, handler: right) { mouseMonitors.append(g) }
        if let g = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown, handler: { [weak self] e in
            // Swallow only over a pin — empty desktop keeps Finder's menu.
            if self?.pinAtScreen(NSEvent.mouseLocation) != nil {
                Task { @MainActor in self?.onRightMouseDown(e) }
                return nil
            }
            return e
        }) {
            mouseMonitors.append(g)
        }
    }

    private func removeMouseMonitors() {
        for m in mouseMonitors { NSEvent.removeMonitor(m) }
        mouseMonitors.removeAll()
    }

    private func screenToLocal(_ screenPt: CGPoint) -> CGPoint? {
        guard let win = window else { return nil }
        let frame = win.frame
        return CGPoint(x: screenPt.x - frame.minX, y: frame.maxY - screenPt.y)
    }

    private func pinAtScreen(_ screenPt: CGPoint) -> DesktopGlyphPin? {
        guard let local = screenToLocal(screenPt) else { return nil }
        let size = window?.frame.size ?? .zero
        let m = metrics(in: size)
        for pin in pins.reversed() where pin.pinned {
            var f = frame(for: pin, metrics: m)
            if dragging == pin.id { f = f.offsetBy(dx: dragTranslation.width, dy: dragTranslation.height) }
            if f.insetBy(dx: -4, dy: -4).contains(local) { return pin }
        }
        return nil
    }

    private func inResizeHandle(_ screenPt: CGPoint, pin: DesktopGlyphPin) -> Bool {
        guard let local = screenToLocal(screenPt) else { return false }
        let f = frame(for: pin, metrics: metrics(in: window?.frame.size ?? .zero))
        let handle = CGRect(x: f.maxX - 18, y: f.maxY - 18, width: 18, height: 18)
        return handle.contains(local)
    }

    private func onMouseDown(_ event: NSEvent) {
        guard enabled, !veilIsOff else { return }
        let pt = NSEvent.mouseLocation
        // Always re-assert pass-through — never leave a sticky capturing sheet (VEI-54).
        window?.ignoresMouseEvents = true
        guard let pin = pinAtScreen(pt) else {
            pendingID = nil
            activateFinderIfDesktopClick(at: pt)
            return
        }
        pendingID = pin.id
        pendingResize = inResizeHandle(pt, pin: pin)
        dragStartScreen = pt
        dragArmed = false
    }

    /// Empty wallpaper click → Finder frontmost when no foreign window owns the point.
    private func activateFinderIfDesktopClick(at pt: CGPoint) {
        let num = NSWindow.windowNumber(at: pt, belowWindowWithWindowNumber: 0)
        if num != 0 {
            if let win = window, num == win.windowNumber {
                window?.ignoresMouseEvents = true
            } else if let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(num)) as? [[String: Any]],
                      let owner = info.first?[kCGWindowOwnerName as String] as? String,
                      owner != "Finder" {
                return // Real app window under cursor — don't steal.
            }
        }
        DispatchQueue.main.async {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder")
                .first?.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func onMouseDragged(_ event: NSEvent) {
        guard enabled, let id = pendingID else { return }
        let pt = NSEvent.mouseLocation
        let dx = pt.x - dragStartScreen.x
        let dy = dragStartScreen.y - pt.y
        if pendingResize {
            if !dragArmed {
                if hypot(dx, dy) < dragThreshold { return }
                dragArmed = true
                beginResize(id)
            }
            if let local = screenToLocal(pt) {
                updateResize(local: local, canvas: window?.frame.size ?? .zero)
            }
            return
        }
        if !dragArmed {
            if hypot(dx, dy) < dragThreshold { return }
            dragArmed = true
            beginDrag(id)
        }
        dragTranslation = CGSize(width: dx, height: dy)
        if let local = screenToLocal(pt) {
            updateDrag(local: local, canvas: window?.frame.size ?? .zero)
        }
    }

    private func onMouseUp(_ event: NSEvent) {
        defer { pendingID = nil; pendingResize = false; dragArmed = false }
        guard enabled else { return }
        if dragArmed {
            if pendingResize { endResize(commit: true) }
            else { dragTranslation = .zero; endDrag(commit: true) }
            return
        }
        if let id = pendingID, !pendingResize, pinAtScreen(NSEvent.mouseLocation)?.id == id {
            switch id {
            case .clock: GlyphShell.shared.present(.quick)  // VEI-45: date/clock → Quick (not calendar-only)
            case .quick: GlyphShell.shared.present(.quick)
            case .media: VeilPanelHost.shared.toggle(.music, near: nil)
            default: break
            }
        }
    }

    private func onRightMouseDown(_ event: NSEvent) {
        guard enabled, !veilIsOff else { return }
        let pt = NSEvent.mouseLocation
        guard let pin = pinAtScreen(pt) else { return }
        presentPinMenu(for: pin.id, at: pt)
    }

    /// Context menu that actually works on the wallpaper layer (AX path).
    func presentPinMenu(for id: DesktopGlyphID, at screenPt: CGPoint) {
        let target = GlyphCtxMenu()
        target.board = self
        target.id = id
        menuTarget = target

        let menu = NSMenu()
        let remove = NSMenuItem(title: "Remove \(id.title)", action: #selector(GlyphCtxMenu.remove), keyEquivalent: "")
        remove.target = target
        remove.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")
        menu.addItem(remove)
        menu.addItem(NSMenuItem.separator())
        let reset = NSMenuItem(title: "Reset layout", action: #selector(GlyphCtxMenu.reset), keyEquivalent: "")
        reset.target = target
        menu.addItem(reset)
        let hide = NSMenuItem(title: "Hide all desktop Glyphs", action: #selector(GlyphCtxMenu.hideAll), keyEquivalent: "")
        hide.target = target
        menu.addItem(hide)
        menu.addItem(NSMenuItem.separator())
        let addRoot = NSMenuItem(title: "Add Glyph", action: nil, keyEquivalent: "")
        let addSub = NSMenu()
        for g in DesktopGlyphID.allCases {
            let on = pins.first(where: { $0.id == g })?.pinned == true
            let item = NSMenuItem(title: on ? "✓ \(g.title)" : g.title,
                                  action: #selector(GlyphCtxMenu.toggleAdd(_:)), keyEquivalent: "")
            item.target = target
            item.representedObject = g.rawValue
            addSub.addItem(item)
        }
        addRoot.submenu = addSub
        menu.addItem(addRoot)
        menu.popUp(positioning: nil, at: screenPt, in: nil)
    }

    // MARK: - Window

    /// Live main-display frame in AppKit points (not a stale backing/pixel husk).
    private func liveScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) { return hit }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    private func liveFrame() -> NSRect { liveScreen().frame }

    private func screenSignature(_ frame: NSRect, scale: CGFloat) -> String {
        String(format: "%.1fx%.1f@%.1f,%.1f#%.2f", frame.width, frame.height, frame.origin.x, frame.origin.y, scale)
    }

    /// Refit when scaled-display / wake leaves the host at the old 2056×1329 @ (0,-481) husk.
    private func syncGeometryIfNeeded() {
        guard enabled, !veilIsOff else { return }
        let frame = liveFrame()
        let scale = liveScreen().backingScaleFactor
        let sig = screenSignature(frame, scale: scale)
        let winFrame = window?.frame ?? .zero
        let mismatch = window == nil
            || abs(winFrame.width - frame.width) > 0.5
            || abs(winFrame.height - frame.height) > 0.5
            || abs(winFrame.origin.x - frame.origin.x) > 0.5
            || abs(winFrame.origin.y - frame.origin.y) > 0.5
            || sig != lastScreenSig
        if mismatch {
            ensureWindow(force: true)
        } else {
            window?.ignoresMouseEvents = true
        }
    }

    private func ensureWindow(force: Bool = false) {
        let screen = liveScreen()
        let frame = screen.frame
        let sig = screenSignature(frame, scale: screen.backingScaleFactor)
        if window == nil {
            let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.hidesOnDeactivate = false
            w.isReleasedWhenClosed = false
            w.ignoresMouseEvents = true
            w.acceptsMouseMovedEvents = false
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window = w
        }
        // Re-assert every ensure — never leave a sticky capturing layer (VEI-42 / VEI-54).
        window?.ignoresMouseEvents = true
        let winFrame = window?.frame ?? .zero
        let frameDrift = abs(winFrame.width - frame.width) > 0.5
            || abs(winFrame.height - frame.height) > 0.5
            || abs(winFrame.origin.x - frame.origin.x) > 0.5
            || abs(winFrame.origin.y - frame.origin.y) > 0.5
        let screenChanged = sig != lastScreenSig || frameDrift
        if force || screenChanged {
            window?.setFrame(frame, display: true)
            // Second pass — some wake/scale transitions ignore the first setFrame.
            if let w = window, abs(w.frame.width - frame.width) > 0.5 || abs(w.frame.origin.y - frame.origin.y) > 0.5 {
                w.setFrame(frame, display: true)
            }
            lastScreenSig = sig
            let root = AnyView(DesktopGlyphCanvas(board: self).frame(width: frame.width, height: frame.height))
            if let host {
                host.rootView = root; host.board = self; window?.contentView = host
            } else {
                let h = GlyphBoardHost(rootView: root); h.board = self; host = h; window?.contentView = h
            }
        }
        if window?.isVisible != true { window?.orderFrontRegardless() }
    }

    func refresh() {
        guard enabled, !veilIsOff else { stop(); return }
        // Always re-read layout so external edits / proof tooling stick.
        load()
        loadedTheme = themeId
        ensureWindow(force: true)
        if mouseMonitors.isEmpty { installMouseMonitors() }
        installScreenObserver()
        syncTick()
        syncGeomTick()
        refreshMetaOnly()
        objectWillChange.send()
    }

    private func refreshMetaOnly() {
        guard enabled, !veilIsOff else { return }
        if pins.contains(where: { $0.pinned && $0.id == .media }) {
            VeilPanelHost.shared.ensureMusicMeta(artwork: false)
        }
        let wantSys = pins.contains(where: { $0.pinned && [.sys, .cpu, .mem, .gpu, .battery, .net, .volume].contains($0.id) })
        if wantSys {
            // Keep panel host warm for shared chrome, but board owns tile digits (VEI-54).
            VeilPanelHost.shared.ensureStatusMeta()
            sampleLocalMetrics(force: false)
        }
    }

    /// Sample CPU/RAM (and friends) for desktop tiles — never leave "—" husks when metrics work.
    private func sampleLocalMetrics(force: Bool) {
        if !force, Date().timeIntervalSince(lastLocalMetricsFetch) < 4 { return }
        lastLocalMetricsFetch = Date()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sampled = Self.readSystemMetrics()
            DispatchQueue.main.async {
                guard let self else { return }
                self.cpuText = sampled.cpu
                self.memText = sampled.mem
                self.gpuText = sampled.gpu
                self.batteryText = sampled.battery
                self.volumeText = sampled.volume
                self.netText = sampled.net
                self.statusLine = "CPU \(sampled.cpu)  ·  MEM \(sampled.mem)  ·  VOL \(sampled.volume)"
                // Mirror into panel host so Overview / Control stay consistent when they read shared fields.
                if sampled.cpu != "—" { VeilPanelHost.shared.cpuText = sampled.cpu }
                if sampled.mem != "—" { VeilPanelHost.shared.memText = sampled.mem }
                if sampled.battery != "—" { VeilPanelHost.shared.batteryText = sampled.battery }
                if sampled.volume != "—" { VeilPanelHost.shared.volumeText = sampled.volume }
                VeilPanelHost.shared.netText = sampled.net
                VeilPanelHost.shared.statusLine = self.statusLine
                self.objectWillChange.send()
            }
        }
    }

    nonisolated private static func readSystemMetrics() -> (cpu: String, mem: String, gpu: String, battery: String, volume: String, net: String) {
        var cpu = "—", mem = "—", battery = "—", volume = "—", net = "Wi‑Fi"
        let home = NSHomeDirectory()
        let metrics = Process()
        metrics.executableURL = URL(fileURLWithPath: home + "/.local/bin/veil-metrics")
        metrics.arguments = [home + "/Library/Caches/veil-cpu", "--instant"]
        let pipe = Pipe()
        metrics.standardOutput = pipe
        metrics.standardError = FileHandle.nullDevice
        if (try? metrics.run()) != nil {
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            metrics.waitUntilExit()
            let bits = out.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            if bits.count >= 2 {
                cpu = bits[0] == "?" ? "—" : "\(bits[0])%"
                mem = bits[1] == "?" ? "—" : "\(bits[1])G"
            }
        }
        if cpu == "—" || mem == "—" {
            let fallback = hostCPUMemFallback()
            if cpu == "—" { cpu = fallback.cpu }
            if mem == "—" { mem = fallback.mem }
        }
        let batt = Process()
        batt.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        batt.arguments = ["-g", "batt"]
        let bp = Pipe()
        batt.standardOutput = bp
        batt.standardError = FileHandle.nullDevice
        if (try? batt.run()) != nil {
            let bout = String(data: bp.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            batt.waitUntilExit()
            if let match = bout.range(of: #"\d+%"#, options: .regularExpression) {
                battery = String(bout[match])
            }
        }
        let vp = Process()
        vp.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        vp.arguments = ["-e", "if output muted of (get volume settings) then return \"MUTE\"",
                        "-e", "return (output volume of (get volume settings) as text) & \"%\""]
        let vpPipe = Pipe()
        vp.standardOutput = vpPipe
        vp.standardError = FileHandle.nullDevice
        if (try? vp.run()) != nil {
            volume = String(data: vpPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
            vp.waitUntilExit()
            if volume.isEmpty { volume = "—" }
        }
        return (cpu, mem, "—", battery, volume, net)
    }

    nonisolated private static func hostCPUMemFallback() -> (cpu: String, mem: String) {
        var cpu = "—", mem = "—"
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var load = host_cpu_load_info_data_t()
        let kr = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        if kr == KERN_SUCCESS {
            let total = Double(load.cpu_ticks.0 + load.cpu_ticks.1 + load.cpu_ticks.2 + load.cpu_ticks.3)
            let idle = Double(load.cpu_ticks.2) // CPU_STATE_IDLE
            if total > 0 {
                let pct = Int(((total - idle) / total * 100).rounded())
                cpu = "\(min(100, max(0, pct)))%"
            }
        }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        var vm = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let vmKr = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        if vmKr == KERN_SUCCESS, pageSize > 0 {
            let used = UInt64(vm.active_count + vm.wire_count + vm.compressor_page_count) * UInt64(pageSize)
            let gib = Double(used) / 1_073_741_824.0
            mem = String(format: "%.1fG", gib)
        }
        return (cpu, mem)
    }


    // MARK: - Full-desktop grid math

    struct GridMetrics {
        var origin: CGPoint
        var cell: CGSize
        var gutter: CGFloat
        var canvas: CGSize
    }

    func metrics(in size: CGSize) -> GridMetrics {
        let barBottom = Palette.load().s("bar_position", "top") == "bottom"
        // Usable frame: clear menu/notch top and bar/Dock bottom.
        let topPad: CGFloat = barBottom ? 36 : 56
        let bottomPad: CGFloat = barBottom ? 56 : 36
        let usableW = size.width - marginX * 2
        let usableH = size.height - topPad - bottomPad
        let cellW = (usableW - gutter * CGFloat(cols - 1)) / CGFloat(cols)
        let cellH = (usableH - gutter * CGFloat(rows - 1)) / CGFloat(rows)
        return GridMetrics(
            origin: CGPoint(x: marginX, y: topPad),
            cell: CGSize(width: cellW, height: cellH),
            gutter: gutter,
            canvas: size
        )
    }

    func frame(for pin: DesktopGlyphPin, metrics m: GridMetrics) -> CGRect {
        let sc: Int
        let sr: Int
        if resizing == pin.id, let span = resizeSpan {
            sc = span.cols; sr = span.rows
        } else {
            sc = pin.spanCols; sr = pin.spanRows
        }
        let x = m.origin.x + CGFloat(pin.col) * (m.cell.width + m.gutter)
        let y = m.origin.y + CGFloat(pin.row) * (m.cell.height + m.gutter)
        let w = CGFloat(sc) * m.cell.width + CGFloat(sc - 1) * m.gutter
        let h = CGFloat(sr) * m.cell.height + CGFloat(sr - 1) * m.gutter
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func previewFrame(metrics m: GridMetrics) -> CGRect? {
        if let id = dragging, let c = dragCol, let r = dragRow,
           let pin = pins.first(where: { $0.id == id }) {
            let sc = pin.spanCols, sr = pin.spanRows
            let x = m.origin.x + CGFloat(c) * (m.cell.width + m.gutter)
            let y = m.origin.y + CGFloat(r) * (m.cell.height + m.gutter)
            let w = CGFloat(sc) * m.cell.width + CGFloat(sc - 1) * m.gutter
            let h = CGFloat(sr) * m.cell.height + CGFloat(sr - 1) * m.gutter
            return CGRect(x: x, y: y, width: w, height: h)
        }
        return nil
    }

    func cellAt(point: CGPoint, canvas: CGSize) -> (col: Int, row: Int) {
        let m = metrics(in: canvas)
        let x = point.x - m.origin.x
        let y = point.y - m.origin.y
        let col = Int(floor(x / max(1, m.cell.width + m.gutter)))
        let row = Int(floor(y / max(1, m.cell.height + m.gutter)))
        return (min(cols - 1, max(0, col)), min(rows - 1, max(0, row)))
    }

    func screenFrame(for id: DesktopGlyphID) -> CGRect? {
        guard let pin = pins.first(where: { $0.id == id && $0.pinned }) else { return nil }
        let screen = liveScreen()
        let m = metrics(in: screen.frame.size)
        let local = frame(for: pin, metrics: m)
        return CGRect(x: screen.frame.minX + local.minX,
                      y: screen.frame.maxY - local.minY - local.height,
                      width: local.width, height: local.height)
    }

    private func placeWithoutOverlap(_ pin: DesktopGlyphPin) -> DesktopGlyphPin {
        var p = pin
        let sc = pin.spanCols, sr = pin.spanRows
        for r in 0...(rows - sr) {
            for c in 0...(cols - sc) {
                p.col = c; p.row = r
                if !overlaps(p, ignoring: pin.id) { return p }
            }
        }
        return pin
    }

    private func overlaps(_ pin: DesktopGlyphPin, ignoring: DesktopGlyphID?) -> Bool {
        let a = cellSet(pin)
        for other in pins where other.pinned && other.id != pin.id && other.id != ignoring {
            if !a.isDisjoint(with: cellSet(other)) { return true }
        }
        return false
    }

    private func cellSet(_ pin: DesktopGlyphPin) -> Set<String> {
        let sc = pin.spanCols, sr = pin.spanRows
        var s = Set<String>()
        for r in pin.row..<(pin.row + sr) {
            for c in pin.col..<(pin.col + sc) { s.insert("\(c),\(r)") }
        }
        return s
    }

    private func resolveOverlaps(preferring winner: DesktopGlyphID) {
        guard let win = pins.first(where: { $0.id == winner }) else { return }
        for i in pins.indices where pins[i].pinned && pins[i].id != winner {
            if !cellSet(pins[i]).isDisjoint(with: cellSet(win)) {
                pins[i] = placeWithoutOverlap(pins[i])
            }
        }
    }
}

// MARK: - Canvas

struct DesktopGlyphCanvas: View {
    @ObservedObject var board: DesktopGlyphBoard
    private var p: Palette { Palette.load() }
    private var reduceMotion: Bool {
        VeilFeature.forceReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        GeometryReader { geo in
            let m = board.metrics(in: geo.size)
            ZStack(alignment: .topLeading) {
                Color.clear
                if board.showGridGuides {
                    gridGuides(m).allowsHitTesting(false)
                    if let preview = board.previewFrame(metrics: m), !board.overTrash {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(p["cyan"].opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .frame(width: preview.width, height: preview.height)
                            .position(x: preview.midX, y: preview.midY)
                            .allowsHitTesting(false)
                    }
                }
                if board.dragging != nil {
                    trashAffordance(in: geo.size).allowsHitTesting(false)
                }
                ForEach(board.pins.filter(\.pinned)) { pin in
                    let frame = board.frame(for: pin, metrics: m)
                    let offset = board.dragging == pin.id ? board.dragTranslation : .zero
                    let overTrash = board.dragging == pin.id && board.overTrash
                    ZStack(alignment: .bottomTrailing) {
                        widget(pin)
                        // Resize affordance (corner)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(p["dim"].opacity(0.7))
                            .padding(5)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .circular))
                    .compositingGroup() // flatten so AA fringe doesn't read as frost
                    .opacity(overTrash ? 0.55 : 1)
                    .scaleEffect(
                        overTrash && !reduceMotion ? 0.9
                        : ((board.dragging == pin.id || board.resizing == pin.id) && !reduceMotion ? 1.02 : 1)
                    )
                    .offset(offset)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .zIndex(board.dragging == pin.id || board.resizing == pin.id ? 10 : 1)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.86),
                               value: "\(pin.col),\(pin.row),\(pin.spanCols),\(pin.spanRows),\(board.overTrash)")
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func trashAffordance(in canvas: CGSize) -> some View {
        let zone = board.trashZone(in: canvas)
        let hot = board.overTrash
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .fill(p["surface"])
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .circular)
                        .strokeBorder(hot ? p["red"] : p["border"], lineWidth: hot ? 2 : 1)
                )
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                Text(hot ? "RELEASE TO REMOVE" : "DRAG HERE TO REMOVE")
                    .font(mono(9))
                    .tracking(1)
            }
            .foregroundStyle(hot ? p["red"] : p["fg"])
        }
        .frame(width: zone.width, height: zone.height)
        .compositingGroup()
        .position(x: zone.midX, y: zone.midY)
        .opacity(hot ? 1 : 0.92)
    }

    private func gridGuides(_ m: DesktopGlyphBoard.GridMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<board.rows, id: \.self) { r in
                ForEach(0..<board.cols, id: \.self) { c in
                    let x = m.origin.x + CGFloat(c) * (m.cell.width + m.gutter)
                    let y = m.origin.y + CGFloat(r) * (m.cell.height + m.gutter)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(p["fg"].opacity(0.07), lineWidth: 1)
                        .frame(width: m.cell.width, height: m.cell.height)
                        .position(x: x + m.cell.width / 2, y: y + m.cell.height / 2)
                }
            }
        }
    }

    @ViewBuilder
    private func widget(_ pin: DesktopGlyphPin) -> some View {
        switch pin.id {
        case .clock: clockWidget
        case .quick: quickWidget
        case .cava: cavaWidget
        case .media: mediaWidget
        case .cpu: metricWidget(.cpu, "CPU", board.cpuText)
        case .mem: metricWidget(.mem, "MEM", board.memText)
        case .gpu: metricWidget(.gpu, "GPU", board.gpuText)
        case .battery: batteryWidget(pin)
        case .net: metricWidget(.net, "NET", board.netText)
        case .volume: metricWidget(.volume, "VOL", board.volumeText)
        case .sys: sysWidget
        }
    }

    /// Small = Mac-only compact metric; ≥2 cells → Apple-style circular device rings (VEI-32 / UX-loop).
    @ViewBuilder
    private func batteryWidget(_ pin: DesktopGlyphPin) -> some View {
        let large = pin.spanCols >= 2 || pin.spanRows >= 2
        Group {
            if large {
                let devices = Array(VeilPanelHost.shared.batteryDevices.prefix(max(4, pin.spanCols * pin.spanRows)))
                let cols = min(3, max(2, pin.spanCols))
                VStack(alignment: .leading, spacing: 6) {
                    Text("BATTERY").font(mono(7)).foregroundStyle(p["comment"])
                    if devices.isEmpty {
                        batteryRingCell(
                            title: "Mac",
                            symbol: BatteryDevice.Kind.mac.symbol,
                            level: Int(board.batteryText.filter(\.isNumber)),
                            detail: nil
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: cols),
                            spacing: 8
                        ) {
                            ForEach(devices) { d in
                                batteryRingCell(
                                    title: batteryShortName(d),
                                    symbol: batteryRingSymbol(d),
                                    level: d.level,
                                    detail: d.detail
                                )
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(tileBG)
                .onAppear {
                    VeilPanelHost.shared.ensureStatusMeta()
                    VeilPanelHost.shared.refreshBatteryDevices(force: true)
                }
                .contextMenu { pinMenu(.battery) }
            } else {
                metricWidget(.battery, "BAT", board.batteryText)
            }
        }
    }

    /// Apple Battery-widget grammar: opaque circular ring, device glyph inside, short % under.
    private func batteryRingCell(title: String, symbol: String, level: Int?, detail: String?) -> some View {
        let pct = level.map { min(1, max(0, Double($0) / 100)) } ?? 0
        let known = level != nil
        let ring = known ? batteryRingColor(level!) : p["dim"]
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(p["border"].opacity(0.9), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: known ? pct : 0)
                    .stroke(ring, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(p["fg"])
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 52, height: 52)
            Text(title)
                .font(mono(7))
                .foregroundStyle(p["comment"])
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let level {
                Text("\(level)%")
                    .font(mono(9))
                    .foregroundStyle(p["fg"])
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(mono(9))
                    .foregroundStyle(p["dim"])
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(mono(6))
                    .foregroundStyle(p["dim"])
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func batteryShortName(_ d: BatteryDevice) -> String {
        switch d.kind {
        case .mac: return "Mac"
        case .buds:
            let n = d.name.lowercased()
            if n.contains("max") { return "Max" }
            if n.contains("pro") { return "Pro" }
            return "Buds"
        case .watch: return "Watch"
        case .phone:
            return d.name.lowercased().contains("ipad") ? "iPad" : "iPhone"
        case .other:
            let t = d.name.trimmingCharacters(in: .whitespaces)
            return t.count <= 8 ? t : String(t.prefix(7))
        }
    }

    private func batteryRingSymbol(_ d: BatteryDevice) -> String {
        switch d.kind {
        case .mac: return "laptopcomputer"
        case .buds:
            let n = d.name.lowercased()
            if n.contains("max") { return "headphones" }
            return "airpodspro"
        case .watch: return "applewatch"
        case .phone:
            return d.name.lowercased().contains("ipad") ? "ipad" : "iphone"
        case .other: return d.kind.symbol
        }
    }

    private func batteryRingColor(_ level: Int) -> Color {
        if level <= 20 { return p["red"] }
        if level <= 35 { return p["yellow"] }
        return p["cyan"]
    }

    private var clockWidget: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Date(), style: .time).font(display(22)).foregroundStyle(p["fg"])
                .minimumScaleFactor(0.4).lineLimit(1)
            Text(dateLine()).font(mono(7)).foregroundStyle(p["comment"]).lineLimit(1).minimumScaleFactor(0.6)
            Text(greeting()).font(ui(10)).foregroundStyle(p["fg"]).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text("QUICK").font(mono(7)).foregroundStyle(p["cyan"])
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBG)
        .contextMenu { pinMenu(.clock) }
    }

    private var quickWidget: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("QUICK").font(display(12)).foregroundStyle(p["fg"])
            HStack(spacing: 3) {
                chip("Wi‑Fi", "wifi"); chip("BT", "wave.3.right"); chip("Focus", "moon.fill")
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Button("Style") { GlyphShell.shared.present(.style) }.buttonStyle(GlyphBtn(p: p, filled: true))
                Button("Shot") { GlyphShell.shared.present(.shot) }.buttonStyle(GlyphBtn(p: p))
                Button("Power") { GlyphShell.shared.present(.power) }.buttonStyle(GlyphBtn(p: p))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBG)
        .contextMenu { pinMenu(.quick) }
    }

    private var cavaWidget: some View {
        ZStack {
            Circle().stroke(p["border"], lineWidth: 4)
            Circle().trim(from: 0, to: 0.55)
                .stroke(p["cyan"], style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("CAVA").font(mono(7)).foregroundStyle(p["comment"])
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .contextMenu { pinMenu(.cava) }
    }

    private var mediaWidget: some View {
        HStack(spacing: 6) {
            Group {
                if let art = VeilPanelHost.shared.musicArtwork {
                    Image(nsImage: art).resizable().aspectRatio(1, contentMode: .fill)
                } else if let disk = NSImage(contentsOfFile: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg") {
                    Image(nsImage: disk).resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    ZStack { p["surface"]; Image(systemName: "music.note").font(.system(size: 10)).foregroundStyle(p["dim"]) }
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(VeilPanelHost.shared.musicTitle).font(ui(10, .semibold)).foregroundStyle(p["fg"]).lineLimit(1)
                Text(VeilPanelHost.shared.musicArtist).font(mono(6)).foregroundStyle(p["comment"]).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(tileBG)
        .contextMenu { pinMenu(.media) }
    }

    private func metricWidget(_ id: DesktopGlyphID, _ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(mono(7)).foregroundStyle(p["comment"])
            Text(value.isEmpty ? "—" : value).font(display(14)).foregroundStyle(p["fg"])
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .onAppear { VeilPanelHost.shared.ensureStatusMeta() }
        .contextMenu { pinMenu(id) }
    }

    private var sysWidget: some View {
        VStack(spacing: 2) {
            Text("SYS").font(mono(7)).foregroundStyle(p["comment"])
            Text(board.statusLine.isEmpty ? "· · ·" : board.statusLine)
                .font(mono(6)).foregroundStyle(p["dim"]).lineLimit(3)
                .multilineTextAlignment(.center).minimumScaleFactor(0.5)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .onAppear { VeilPanelHost.shared.ensureStatusMeta() }
        .contextMenu { pinMenu(.sys) }
    }

    /// Circular corners clip cleaner than continuous (less soft AA “frost” fringe on black walls).
    private var tileRadius: CGFloat { max(8, p.num("l_radius", 16) * 0.45) }

    /// Opaque theme fill clipped to the tile — no frosted/translucent overshoot.
    private var tileBG: some View {
        let r = tileRadius
        return RoundedRectangle(cornerRadius: r, style: .circular)
            .fill(p["surface"]) // opaque solid card (1a1a1a) — never .opacity()
            .overlay(RoundedRectangle(cornerRadius: r, style: .circular)
                .strokeBorder(p["border"], lineWidth: 1))
    }

    private func chip(_ t: String, _ sym: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: sym).font(.system(size: 7, weight: .semibold))
            Text(t.uppercased()).font(mono(5))
        }
        .foregroundStyle(p["fg"])
        .padding(.horizontal, 4).padding(.vertical, 3)
        .background(Capsule().fill(p["bg"]))
    }

    @ViewBuilder
    private func pinMenu(_ id: DesktopGlyphID) -> some View {
        // Fallback only — real path is AX right-click → NSMenu (pass-through host).
        Button("Remove \(id.title)", role: .destructive) { board.removePin(id) }
        Button("Reset layout") { board.resetToDefault() }
        Button("Hide all desktop Glyphs") { board.toggleEnabled() }
        Divider()
        Text("Add Glyph")
        ForEach(DesktopGlyphID.allCases) { g in
            let on = board.pins.first(where: { $0.id == g })?.pinned == true
            Button(on ? "✓ \(g.title)" : g.title) { board.togglePin(g) }
        }
    }

    private func ui(_ size: CGFloat, _ w: Font.Weight = .medium) -> Font {
        let n = p.s("ui_font", ""); return n.isEmpty ? .system(size: size, weight: w) : .custom(n, size: size).weight(w)
    }
    private func mono(_ size: CGFloat) -> Font {
        let n = p.s("ui_mono", "")
        return n.isEmpty ? .system(size: size, weight: .bold, design: .monospaced) : .custom(n, size: size).weight(.bold)
    }
    private func display(_ size: CGFloat) -> Font {
        if p.s("theme_id", "") == "nothing" { return .custom("Doto", size: size).weight(.bold) }
        return ui(size, .bold)
    }
    private func dateLine() -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM · W'W'"
        return f.string(from: Date()).uppercased()
    }
    private func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        return "Good \(h < 12 ? "morning" : h < 18 ? "afternoon" : "evening")."
    }
}
