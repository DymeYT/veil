// Desktop Glyph board: compact snap-to-grid wallpaper widgets (drag + snap, persist per theme).
// Above desktop icons, below app windows. Empty chrome passes clicks through — tiles do not.
import AppKit
import Combine
import SwiftUI

enum DesktopGlyphID: String, Codable, CaseIterable, Identifiable {
    case clock, quick, cava, media, sys
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clock: return "CLOCK"
        case .quick: return "QUICK"
        case .cava: return "CAVA"
        case .media: return "MEDIA"
        case .sys: return "SYS"
        }
    }
    /// Compact Glyph-Matrix-ish spans (cells are ~92pt squares).
    var span: (cols: Int, rows: Int) {
        switch self {
        case .clock: return (2, 2)
        case .quick: return (2, 2)
        case .cava: return (1, 1)
        case .media: return (2, 1)
        case .sys: return (1, 1)
        }
    }
}

struct DesktopGlyphPin: Codable, Identifiable, Equatable {
    var id: DesktopGlyphID
    var col: Int
    var row: Int
    var pinned: Bool
    var nx: Double?
    var ny: Double?
}

/// Hit-test only inside pinned tile frames so wallpaper stays click-through.
/// Drag is AppKit-native (mouseDown/Dragged/Up) — SwiftUI DragGesture never sees
/// desktop-level hosting-root hits, which is why earlier “drag” shipped dead.
final class GlyphBoardHost<Content: View>: NSHostingView<Content> {
    weak var board: DesktopGlyphBoard?
    private var dragID: DesktopGlyphID?
    private var dragStartLocal: CGPoint = .zero
    private var dragArmed = false
    private let dragThreshold: CGFloat = 4

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let board, board.enabled else { return nil }
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return nil }
        let local = flipped(point)
        if board.dragging != nil || dragArmed { return self }
        guard pin(at: local) != nil else { return nil }
        // Prefer real AppKit controls (rare); otherwise capture on self for drag.
        if let hit = super.hitTest(point), hit !== self, isControlish(hit) { return hit }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        let local = flipped(convert(event.locationInWindow, from: nil))
        guard let board, let pin = pin(at: local) else { return }
        dragID = pin.id
        dragStartLocal = local
        dragArmed = false
        // Don't beginDrag until threshold — keeps short clicks free for controls.
    }

    override func mouseDragged(with event: NSEvent) {
        guard let board, let id = dragID else { return }
        let local = flipped(convert(event.locationInWindow, from: nil))
        let dx = local.x - dragStartLocal.x
        let dy = local.y - dragStartLocal.y
        if !dragArmed {
            if hypot(dx, dy) < dragThreshold { return }
            dragArmed = true
            board.beginDrag(id)
        }
        board.dragTranslation = CGSize(width: dx, height: dy)
        board.updateDrag(local: local, canvas: bounds.size)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragID = nil
            dragArmed = false
            dragStartLocal = .zero
        }
        guard let board else { return }
        if dragArmed {
            board.dragTranslation = .zero
            board.endDrag(commit: true)
        } else if let id = dragID {
            // Click without drag — open the matching Glyph surface when useful.
            switch id {
            case .clock: GlyphShell.shared.present(.cal)
            case .quick: GlyphShell.shared.present(.quick)
            case .media: VeilPanelHost.shared.toggle(.music, near: nil)
            case .cava, .sys: break
            }
        }
    }

    private func flipped(_ point: NSPoint) -> CGPoint {
        isFlipped ? CGPoint(x: point.x, y: point.y)
                  : CGPoint(x: point.x, y: bounds.height - point.y)
    }

    private func pin(at local: CGPoint) -> DesktopGlyphPin? {
        guard let board else { return nil }
        let m = board.metrics(in: bounds.size)
        // Prefer topmost (later) pins; dragging tile wins via board.dragging frames.
        for pin in board.pins.reversed() where pin.pinned {
            let home = DesktopGlyphPin(id: pin.id, col: pin.col, row: pin.row, pinned: true)
            var frame = board.frame(for: home, metrics: m)
            if board.dragging == pin.id {
                frame = frame.offsetBy(dx: board.dragTranslation.width, dy: board.dragTranslation.height)
            }
            if frame.insetBy(dx: -4, dy: -4).contains(local) { return pin }
        }
        return nil
    }

    private func isControlish(_ view: NSView) -> Bool {
        var v: NSView? = view
        while let cur = v {
            if cur is NSControl || cur is NSButton { return true }
            let name = NSStringFromClass(type(of: cur))
            if name.contains("Button") || name.contains("Control") { return true }
            if cur === self { break }
            v = cur.superview
        }
        return false
    }
}

@MainActor
final class DesktopGlyphBoard: ObservableObject {
    static let shared = DesktopGlyphBoard()
    @Published var pins: [DesktopGlyphPin] = []
    @Published var enabled = true
    @Published var dragging: DesktopGlyphID?
    @Published var dragCol: Int?
    @Published var dragRow: Int?
    @Published var dragTranslation: CGSize = .zero
    @Published var showGridGuides = false

    /// Dense compact board — fixed cell size, centered; not a stretched full-screen card grid.
    let cols = 8
    let rows = 6
    let cellSide: CGFloat = 92
    let gutter: CGFloat = 10
    /// Persist schema: v3 = compact 8×6 fixed cells + GlyphBoardHost drag fix.
    private let storeVersion = 3

    private var window: NSWindow?
    private var host: GlyphBoardHost<AnyView>?
    private var tick: Timer?
    private var lastScreenSig = ""
    private var loadedTheme: String?
    private var themeId: String { Palette.load().s("theme_id", "nothing") }
    private var storePath: String { ncRoot + "/generated/desktop-glyphs-\(themeId).json" }
    private var legacyStorePath: String { ncRoot + "/generated/desktop-glyphs.json" }

    private var reduceMotion: Bool {
        VeilFeature.forceReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Media/sys need slow meta; clock/quick/cava are local or static — no tick required.
    private var needsMetaTick: Bool {
        pins.contains { $0.pinned && ($0.id == .media || $0.id == .sys) }
    }

    func start() {
        load()
        guard enabled, !veilIsOff else { stop(); return }
        ensureWindow(force: true)
        syncTick()
        refreshMetaOnly()
    }

    func stop() {
        tick?.invalidate(); tick = nil
        window?.orderOut(nil)
        window?.contentView = nil
        host = nil
        window = nil
        lastScreenSig = ""
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
        enabled.toggle()
        save()
        if enabled { start() } else { stop() }
    }

    func resetToDefault() {
        pins = defaultLayout()
        save(); refresh()
    }

    func togglePin(_ id: DesktopGlyphID) {
        if let i = pins.firstIndex(where: { $0.id == id }) {
            pins[i].pinned.toggle()
            if pins[i].pinned { pins[i] = placeWithoutOverlap(pins[i]) }
        } else {
            pins.append(placeWithoutOverlap(DesktopGlyphPin(id: id, col: 0, row: 0, pinned: true)))
        }
        save(); refresh()
    }

    func setPin(_ id: DesktopGlyphID, pinned: Bool) {
        if let i = pins.firstIndex(where: { $0.id == id }) {
            pins[i].pinned = pinned
        } else if pinned {
            pins.append(placeWithoutOverlap(DesktopGlyphPin(id: id, col: 0, row: 0, pinned: true)))
        }
        save(); refresh()
    }

    func move(_ id: DesktopGlyphID, toCol col: Int, toRow row: Int) {
        guard let i = pins.firstIndex(where: { $0.id == id }) else { return }
        let span = id.span
        pins[i].col = min(max(0, col), cols - span.cols)
        pins[i].row = min(max(0, row), rows - span.rows)
        resolveOverlaps(preferring: id)
        dragging = nil
        dragCol = nil
        dragRow = nil
        showGridGuides = false
        save()
        objectWillChange.send()
    }

    func beginDrag(_ id: DesktopGlyphID) {
        dragging = id
        showGridGuides = true
        dragTranslation = .zero
        if let p = pins.first(where: { $0.id == id }) {
            dragCol = p.col; dragRow = p.row
        }
        // Raise above desktop icons so tracking isn't stolen mid-drag.
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 4)
        objectWillChange.send()
    }

    func updateDrag(local point: CGPoint, canvas: CGSize) {
        guard let id = dragging else { return }
        let span = id.span
        let cell = cellAt(point: point, canvas: canvas)
        dragCol = min(cols - span.cols, max(0, cell.col))
        dragRow = min(rows - span.rows, max(0, cell.row))
        objectWillChange.send()
    }

    func endDrag(commit: Bool) {
        let id = dragging
        let c = dragCol
        let r = dragRow
        dragTranslation = .zero
        if commit, let id, let c, let r {
            move(id, toCol: c, toRow: r)
        } else {
            dragging = nil; dragCol = nil; dragRow = nil; showGridGuides = false
            objectWillChange.send()
        }
        window?.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
    }

    // MARK: - Compact symmetrical default
    //
    // Fixed 8×6 board centered on the desktop. Clock ∥ Quick as a tight mirrored pair,
    // Sys + Cava tucked under the seam — equal outer margins, even gutters, balanced weight.
    //
    //   0 1 2 3 4 5 6 7
    // 0 . . . . . . . .
    // 1 . [CLOCK][QUICK] .
    // 2 . [    ][     ] .
    // 3 . . [S][C] . . .
    // 4 . . . . . . . .
    // 5 . . . . . . . .
    private func defaultLayout() -> [DesktopGlyphPin] {
        [
            DesktopGlyphPin(id: .clock, col: 2, row: 1, pinned: true),
            DesktopGlyphPin(id: .quick, col: 4, row: 1, pinned: true),
            DesktopGlyphPin(id: .sys,   col: 3, row: 3, pinned: true),
            DesktopGlyphPin(id: .cava,  col: 4, row: 3, pinned: true),
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
                pins = defaultLayout()
                save()
            } else {
                pins = migrateIfNeeded(obj.pins)
            }
        } else if let data = try? Data(contentsOf: legacy),
                  let obj = try? JSONDecoder().decode(Store.self, from: data), !obj.pins.isEmpty {
            enabled = obj.enabled
            pins = defaultLayout()
            save()
        } else {
            enabled = true
            pins = defaultLayout()
            save()
        }
        loadedTheme = themeId
    }

    private func migrateIfNeeded(_ raw: [DesktopGlyphPin]) -> [DesktopGlyphPin] {
        let pinned = raw.filter(\.pinned)
        let allOrigin = pinned.allSatisfy { $0.col == 0 && $0.row == 0 }
        if allOrigin && pinned.count > 1 { return defaultLayout() }
        return raw.map { pin in
            var p = pin
            if let nx = pin.nx, let ny = pin.ny, pin.col == 0 && pin.row == 0 {
                p.col = min(cols - pin.id.span.cols, max(0, Int((nx * Double(cols)).rounded(.down))))
                let rowFromBottom = Int((ny * Double(rows)).rounded(.down))
                p.row = min(rows - pin.id.span.rows, max(0, rows - 1 - rowFromBottom))
                p.nx = nil; p.ny = nil
            }
            p.col = min(max(0, p.col), cols - pin.id.span.cols)
            p.row = min(max(0, p.row), rows - pin.id.span.rows)
            return p
        }
    }

    private func save() {
        let dir = (storePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let cleaned = pins.map { DesktopGlyphPin(id: $0.id, col: $0.col, row: $0.row, pinned: $0.pinned) }
        let data = try? JSONEncoder().encode(Store(enabled: enabled, pins: cleaned, version: storeVersion))
        try? data?.write(to: URL(fileURLWithPath: storePath), options: .atomic)
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
            let root = AnyView(
                DesktopGlyphCanvas(board: self)
                    .frame(width: frame.width, height: frame.height)
            )
            if let host {
                host.rootView = root
                host.board = self
                window?.contentView = host
            } else {
                let h = GlyphBoardHost(rootView: root)
                h.board = self
                host = h
                window?.contentView = h
            }
        }
        if window?.isVisible != true { window?.orderFrontRegardless() }
    }

    func refresh() {
        guard enabled, !veilIsOff else { stop(); return }
        var rebuild = false
        if loadedTheme != themeId {
            load()
            loadedTheme = themeId
            rebuild = true
        }
        ensureWindow(force: rebuild)
        syncTick()
        refreshMetaOnly()
        if rebuild { objectWillChange.send() }
    }

    /// Cheap tick: metadata only — no host rebuild, no artwork Process storm.
    private func refreshMetaOnly() {
        guard enabled, !veilIsOff else { return }
        if pins.contains(where: { $0.pinned && $0.id == .media }) {
            VeilPanelHost.shared.ensureMusicMeta(artwork: false)
        }
        if pins.contains(where: { $0.pinned && $0.id == .sys }) {
            VeilPanelHost.shared.ensureStatusMeta()
        }
    }

    // MARK: - Grid math (fixed cell, centered board)

    struct GridMetrics {
        var origin: CGPoint
        var cell: CGSize
        var gutter: CGFloat
        var canvas: CGSize
    }

    func metrics(in size: CGSize) -> GridMetrics {
        let barBottom = Palette.load().s("bar_position", "top") == "bottom"
        let topPad: CGFloat = barBottom ? 48 : 72
        let bottomPad: CGFloat = barBottom ? 72 : 48
        let boardW = CGFloat(cols) * cellSide + CGFloat(cols - 1) * gutter
        let boardH = CGFloat(rows) * cellSide + CGFloat(rows - 1) * gutter
        let originX = ((size.width - boardW) / 2).rounded(.toNearestOrAwayFromZero)
        let usableH = size.height - topPad - bottomPad
        let originY = topPad + max(0, ((usableH - boardH) / 2)).rounded(.toNearestOrAwayFromZero)
        return GridMetrics(
            origin: CGPoint(x: originX, y: originY),
            cell: CGSize(width: cellSide, height: cellSide),
            gutter: gutter,
            canvas: size
        )
    }

    func frame(for pin: DesktopGlyphPin, metrics m: GridMetrics) -> CGRect {
        // Visual frame stays on the home cell while dragging; finger offset is dragTranslation.
        let span = pin.id.span
        let x = m.origin.x + CGFloat(pin.col) * (m.cell.width + m.gutter)
        let y = m.origin.y + CGFloat(pin.row) * (m.cell.height + m.gutter)
        let w = CGFloat(span.cols) * m.cell.width + CGFloat(span.cols - 1) * m.gutter
        let h = CGFloat(span.rows) * m.cell.height + CGFloat(span.rows - 1) * m.gutter
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Snap preview cell while dragging (guides + drop target).
    func previewFrame(metrics m: GridMetrics) -> CGRect? {
        guard let id = dragging, let c = dragCol, let r = dragRow else { return nil }
        let span = id.span
        let x = m.origin.x + CGFloat(c) * (m.cell.width + m.gutter)
        let y = m.origin.y + CGFloat(r) * (m.cell.height + m.gutter)
        let w = CGFloat(span.cols) * m.cell.width + CGFloat(span.cols - 1) * m.gutter
        let h = CGFloat(span.rows) * m.cell.height + CGFloat(span.rows - 1) * m.gutter
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func cellAt(point: CGPoint, canvas: CGSize) -> (col: Int, row: Int) {
        let m = metrics(in: canvas)
        let x = point.x - m.origin.x
        let y = point.y - m.origin.y
        let strideX = m.cell.width + m.gutter
        let strideY = m.cell.height + m.gutter
        let col = Int(floor(x / max(1, strideX)))
        let row = Int(floor(y / max(1, strideY)))
        return (min(cols - 1, max(0, col)), min(rows - 1, max(0, row)))
    }

    /// Screen-space rect for proof tooling (AppKit bottom-left origin).
    func screenFrame(for id: DesktopGlyphID) -> CGRect? {
        guard let pin = pins.first(where: { $0.id == id && $0.pinned }),
              let screen = NSScreen.main else { return nil }
        let m = metrics(in: screen.frame.size)
        let local = frame(for: pin, metrics: m)
        // SwiftUI y-down → AppKit y-up within screen frame.
        let ax = screen.frame.minX + local.minX
        let ay = screen.frame.maxY - local.minY - local.height
        return CGRect(x: ax, y: ay, width: local.width, height: local.height)
    }

    private func placeWithoutOverlap(_ pin: DesktopGlyphPin) -> DesktopGlyphPin {
        var p = pin
        let span = pin.id.span
        for r in 0...(rows - span.rows) {
            for c in 0...(cols - span.cols) {
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
        let span = pin.id.span
        var s = Set<String>()
        for r in pin.row..<(pin.row + span.rows) {
            for c in pin.col..<(pin.col + span.cols) {
                s.insert("\(c),\(r)")
            }
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
                    gridGuides(m)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    if let preview = board.previewFrame(metrics: m) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(p["cyan"].opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .frame(width: preview.width, height: preview.height)
                            .position(x: preview.midX, y: preview.midY)
                            .allowsHitTesting(false)
                    }
                }
                ForEach(board.pins.filter(\.pinned)) { pin in
                    let frame = board.frame(for: pin, metrics: m)
                    let offset = board.dragging == pin.id ? board.dragTranslation : .zero
                    widget(pin)
                        .frame(width: frame.width, height: frame.height)
                        .scaleEffect(board.dragging == pin.id && !reduceMotion ? 1.04 : 1)
                        .shadow(color: board.dragging == pin.id ? .black.opacity(0.4) : .clear, radius: 14, y: 6)
                        .offset(offset)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .zIndex(board.dragging == pin.id ? 10 : 1)
                        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.86),
                                   value: "\(pin.col),\(pin.row)")
                        .allowsHitTesting(false) // AppKit host owns hit-testing + drag
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func gridGuides(_ m: DesktopGlyphBoard.GridMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<board.rows, id: \.self) { r in
                ForEach(0..<board.cols, id: \.self) { c in
                    let x = m.origin.x + CGFloat(c) * (m.cell.width + m.gutter)
                    let y = m.origin.y + CGFloat(r) * (m.cell.height + m.gutter)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(p["fg"].opacity(0.10), lineWidth: 1)
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
        case .sys: sysWidget
        }
    }

    private var clockWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date(), style: .time)
                .font(display(28))
                .foregroundStyle(p["fg"])
                .minimumScaleFactor(0.45)
                .lineLimit(1)
            Text(dateLine())
                .font(mono(7))
                .foregroundStyle(p["comment"])
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(greeting())
                .font(ui(11))
                .foregroundStyle(p["fg"])
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Button { GlyphShell.shared.present(.cal) } label: {
                Text("CAL").font(mono(8)).foregroundStyle(p["cyan"])
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBG)
        .contextMenu { pinMenu(.clock) }
    }

    private var quickWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("QUICK").font(display(14)).foregroundStyle(p["fg"])
                Spacer(minLength: 0)
                Button { GlyphShell.shared.present(.quick) } label: {
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(p["dim"])
                }.buttonStyle(.plain)
            }
            HStack(spacing: 4) {
                quickChip("Wi‑Fi", "wifi")
                quickChip("BT", "wave.3.right")
                quickChip("Focus", "moon.fill")
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Button("Style") { GlyphShell.shared.present(.style) }.buttonStyle(GlyphBtn(p: p, filled: true))
                Button("Shot") { GlyphShell.shared.present(.shot) }.buttonStyle(GlyphBtn(p: p))
                Button("Power") { GlyphShell.shared.present(.power) }.buttonStyle(GlyphBtn(p: p))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBG)
        .contextMenu { pinMenu(.quick) }
    }

    private var cavaWidget: some View {
        ZStack {
            Circle().stroke(p["border"], lineWidth: 5)
            Circle().trim(from: 0, to: 0.55)
                .stroke(p["cyan"], style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("CAVA").font(mono(8)).foregroundStyle(p["comment"])
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .contextMenu { pinMenu(.cava) }
    }

    private var mediaWidget: some View {
        HStack(spacing: 8) {
            Group {
                if let art = VeilPanelHost.shared.musicArtwork {
                    Image(nsImage: art).resizable().aspectRatio(1, contentMode: .fill)
                } else if let disk = NSImage(contentsOfFile: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg") {
                    Image(nsImage: disk).resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    ZStack {
                        p["surface"]
                        Image(systemName: "music.note").font(.system(size: 11)).foregroundStyle(p["dim"])
                    }
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(VeilPanelHost.shared.musicTitle).font(ui(11, .semibold)).foregroundStyle(p["fg"]).lineLimit(1)
                Text(VeilPanelHost.shared.musicArtist).font(mono(7)).foregroundStyle(p["comment"]).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(tileBG)
        .onTapGesture { VeilPanelHost.shared.toggle(.music, near: nil) }
        .contextMenu { pinMenu(.media) }
    }

    private var sysWidget: some View {
        VStack(spacing: 3) {
            Text("SYS").font(mono(7)).foregroundStyle(p["comment"])
            Text("CPU").font(display(16)).foregroundStyle(p["fg"])
            Text(VeilPanelHost.shared.statusLine.isEmpty ? "· · ·" : VeilPanelHost.shared.statusLine)
                .font(mono(7)).foregroundStyle(p["dim"]).lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .onAppear { VeilPanelHost.shared.ensureStatusMeta() }
        .contextMenu { pinMenu(.sys) }
    }

    private var tileBG: some View {
        RoundedRectangle(cornerRadius: max(10, p.num("l_radius", 16) * 0.55), style: .continuous)
            .fill(p["bg_float"].opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: max(10, p.num("l_radius", 16) * 0.55), style: .continuous)
                    .strokeBorder(p["border"].opacity(0.55), lineWidth: 1)
            )
    }

    private func quickChip(_ t: String, _ sym: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: sym).font(.system(size: 8, weight: .semibold))
            Text(t.uppercased()).font(mono(6))
        }
        .foregroundStyle(p["fg"])
        .padding(.horizontal, 5).padding(.vertical, 4)
        .background(Capsule().fill(p["bg"]))
    }

    @ViewBuilder
    private func pinMenu(_ id: DesktopGlyphID) -> some View {
        Button("Unpin \(id.title)") { board.setPin(id, pinned: false) }
        Button("Reset layout") { board.resetToDefault() }
        Button("Hide all desktop Glyphs") { board.toggleEnabled() }
        Divider()
        ForEach(DesktopGlyphID.allCases) { g in
            Button(board.pins.first(where: { $0.id == g })?.pinned == true ? "✓ \(g.title)" : g.title) {
                board.togglePin(g)
            }
        }
    }

    private func ui(_ size: CGFloat, _ w: Font.Weight = .medium) -> Font {
        let n = p.s("ui_font", "")
        return n.isEmpty ? .system(size: size, weight: w) : .custom(n, size: size).weight(w)
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
        let part = h < 12 ? "morning" : h < 18 ? "afternoon" : "evening"
        return "Good \(part)."
    }
}

// Drag is AppKit-native on GlyphBoardHost (stable for unify in-process hosting).
