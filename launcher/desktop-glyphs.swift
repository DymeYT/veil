// Desktop Glyph board: full-desktop snap grid, catalog of tiles, drag + fluent resize.
// Wallpaper layer; empty chrome click-through. Stable API for unify in-process hosting.
import AppKit
import Combine
import SwiftUI

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

/// Pass-through host; interaction via AX monitors on the board (desktop panels rarely get mouseDown).
final class GlyphBoardHost<Content: View>: NSHostingView<Content> {
    weak var board: DesktopGlyphBoard?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let board, board.dragging != nil || board.resizing != nil else { return nil }
        return self
    }
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

    /// Full-desktop grid — cells fill usable frame (bar/Dock insets), even gutters.
    let cols = 16
    let rows = 10
    let gutter: CGFloat = 10
    let marginX: CGFloat = 28
    /// v5: full-desktop metrics + catalog + per-pin span resize.
    private let storeVersion = 5

    private var window: NSWindow?
    private var host: GlyphBoardHost<AnyView>?
    private var tick: Timer?
    private var lastScreenSig = ""
    private var loadedTheme: String?
    private var mouseMonitors: [Any] = []
    private var pendingID: DesktopGlyphID?
    private var pendingResize = false
    private var dragStartScreen: CGPoint = .zero
    private var dragArmed = false
    private var resizeStartSpan: (cols: Int, rows: Int) = (1, 1)
    private let dragThreshold: CGFloat = 4
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
        syncTick()
        refreshMetaOnly()
    }

    func stop() {
        tick?.invalidate(); tick = nil
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
    }

    private func syncTick() {
        tick?.invalidate(); tick = nil
        guard enabled, !veilIsOff, needsMetaTick else { return }
        let quiet = FileManager.default.fileExists(atPath: ncRoot + "/generated/quiet")
        let interval: TimeInterval = (reduceMotion || quiet) ? 90 : 60
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshMetaOnly() }
        }
        t.tolerance = interval * 0.25
        RunLoop.main.add(t, forMode: .common)
        tick = t
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
            pins[i].pinned.toggle()
            if pins[i].pinned { pins[i] = placeWithoutOverlap(pins[i]) }
        } else {
            pins.append(placeWithoutOverlap(DesktopGlyphPin(
                id: id, col: 0, row: 0, pinned: true,
                colSpan: id.defaultSpan.cols, rowSpan: id.defaultSpan.rows)))
        }
        save(); refresh()
    }

    func setPin(_ id: DesktopGlyphID, pinned: Bool) {
        if let i = pins.firstIndex(where: { $0.id == id }) {
            pins[i].pinned = pinned
        } else if pinned {
            pins.append(placeWithoutOverlap(DesktopGlyphPin(
                id: id, col: 0, row: 0, pinned: true,
                colSpan: id.defaultSpan.cols, rowSpan: id.defaultSpan.rows)))
        }
        save(); refresh()
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
        objectWillChange.send()
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
        dragTranslation = .zero
        if commit, let id, let c, let r { move(id, toCol: c, toRow: r) }
        else { clearInteraction(); objectWillChange.send() }
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
    }

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

    // MARK: - Balanced default on full-desktop grid
    //
    // 16×10 filling the usable frame. Clock ∥ Quick at mirrored margins; compact
    // system chips centered under the seam — even gutters, balanced L/R weight.
    private func defaultLayout() -> [DesktopGlyphPin] {
        [
            DesktopGlyphPin(id: .clock, col: 1, row: 1, pinned: true, colSpan: 2, rowSpan: 2),
            DesktopGlyphPin(id: .quick, col: 13, row: 1, pinned: true, colSpan: 2, rowSpan: 2),
            DesktopGlyphPin(id: .cpu, col: 6, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .mem, col: 7, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .cava, col: 8, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
            DesktopGlyphPin(id: .battery, col: 9, row: 4, pinned: true, colSpan: 1, rowSpan: 1),
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
        for mask in [NSEvent.EventTypeMask.leftMouseDown, .leftMouseDragged, .leftMouseUp] {
            let handler: (NSEvent) -> Void = mask == .leftMouseDown ? down : mask == .leftMouseDragged ? drag : up
            if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) { mouseMonitors.append(g) }
            if let g = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { e in handler(e); return e }) {
                mouseMonitors.append(g)
            }
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
        guard let pin = pinAtScreen(pt) else { pendingID = nil; return }
        pendingID = pin.id
        pendingResize = inResizeHandle(pt, pin: pin)
        dragStartScreen = pt
        dragArmed = false
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
            case .clock: GlyphShell.shared.present(.cal)
            case .quick: GlyphShell.shared.present(.quick)
            case .media: VeilPanelHost.shared.toggle(.music, near: nil)
            default: break
            }
        }
    }

    // MARK: - Window

    private func ensureWindow(force: Bool = false) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        let sig = "\(Int(frame.width))x\(Int(frame.height))@\(Int(frame.origin.x)),\(Int(frame.origin.y))"
        if window == nil {
            let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.hidesOnDeactivate = false
            w.isReleasedWhenClosed = false
            w.ignoresMouseEvents = false
            w.acceptsMouseMovedEvents = true
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window = w
        }
        let screenChanged = sig != lastScreenSig
        if force || screenChanged {
            window?.setFrame(frame, display: true)
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
        var rebuild = false
        if loadedTheme != themeId { load(); loadedTheme = themeId; rebuild = true }
        ensureWindow(force: rebuild)
        if mouseMonitors.isEmpty { installMouseMonitors() }
        syncTick()
        refreshMetaOnly()
        if rebuild { objectWillChange.send() }
    }

    private func refreshMetaOnly() {
        guard enabled, !veilIsOff else { return }
        if pins.contains(where: { $0.pinned && $0.id == .media }) {
            VeilPanelHost.shared.ensureMusicMeta(artwork: false)
        }
        if pins.contains(where: { $0.pinned && [.sys, .cpu, .mem, .gpu, .battery, .net, .volume].contains($0.id) }) {
            VeilPanelHost.shared.ensureStatusMeta()
        }
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
        guard let pin = pins.first(where: { $0.id == id && $0.pinned }),
              let screen = NSScreen.main else { return nil }
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
                    if let preview = board.previewFrame(metrics: m) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(p["cyan"].opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .frame(width: preview.width, height: preview.height)
                            .position(x: preview.midX, y: preview.midY)
                            .allowsHitTesting(false)
                    }
                }
                ForEach(board.pins.filter(\.pinned)) { pin in
                    let frame = board.frame(for: pin, metrics: m)
                    let offset = board.dragging == pin.id ? board.dragTranslation : .zero
                    ZStack(alignment: .bottomTrailing) {
                        widget(pin)
                        // Resize affordance (corner)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(p["dim"].opacity(0.7))
                            .padding(5)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect((board.dragging == pin.id || board.resizing == pin.id) && !reduceMotion ? 1.03 : 1)
                    .shadow(color: (board.dragging == pin.id || board.resizing == pin.id) ? .black.opacity(0.4) : .clear,
                            radius: 12, y: 5)
                    .offset(offset)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .zIndex(board.dragging == pin.id || board.resizing == pin.id ? 10 : 1)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.86),
                               value: "\(pin.col),\(pin.row),\(pin.spanCols),\(pin.spanRows)")
                    .allowsHitTesting(false)
                }
            }
        }
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
        case .cpu: metricWidget(.cpu, "CPU", VeilPanelHost.shared.cpuText)
        case .mem: metricWidget(.mem, "MEM", VeilPanelHost.shared.memText)
        case .gpu: metricWidget(.gpu, "GPU", VeilPanelHost.shared.gpuText)
        case .battery: metricWidget(.battery, "BAT", VeilPanelHost.shared.batteryText)
        case .net: metricWidget(.net, "NET", VeilPanelHost.shared.netText)
        case .volume: metricWidget(.volume, "VOL", VeilPanelHost.shared.volumeText)
        case .sys: sysWidget
        }
    }

    private var clockWidget: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Date(), style: .time).font(display(22)).foregroundStyle(p["fg"])
                .minimumScaleFactor(0.4).lineLimit(1)
            Text(dateLine()).font(mono(7)).foregroundStyle(p["comment"]).lineLimit(1).minimumScaleFactor(0.6)
            Text(greeting()).font(ui(10)).foregroundStyle(p["fg"]).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text("CAL").font(mono(7)).foregroundStyle(p["cyan"])
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
            Text(VeilPanelHost.shared.statusLine.isEmpty ? "· · ·" : VeilPanelHost.shared.statusLine)
                .font(mono(6)).foregroundStyle(p["dim"]).lineLimit(3)
                .multilineTextAlignment(.center).minimumScaleFactor(0.5)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .onAppear { VeilPanelHost.shared.ensureStatusMeta() }
        .contextMenu { pinMenu(.sys) }
    }

    private var tileBG: some View {
        let r = max(8, p.num("l_radius", 16) * 0.45)
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(p["bg_float"].opacity(0.92))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous)
                .strokeBorder(p["border"].opacity(0.55), lineWidth: 1))
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
        Button("Unpin \(id.title)") { board.setPin(id, pinned: false) }
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
