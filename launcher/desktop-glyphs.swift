// Desktop Glyph board: snap-to-grid wallpaper-layer widgets (drag + snap, persist per theme).
// Above desktop icons, below app windows. Empty chrome passes clicks through.
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
    /// How many grid cells wide / tall this Glyph occupies.
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
    /// Grid cell of the tile’s top-leading corner (0-based).
    var col: Int
    var row: Int
    var pinned: Bool
    /// Legacy free-float fields (ignored when col/row present in new saves).
    var nx: Double?
    var ny: Double?
}

@MainActor
final class DesktopGlyphBoard: ObservableObject {
    static let shared = DesktopGlyphBoard()
    @Published var pins: [DesktopGlyphPin] = []
    @Published var enabled = true
    @Published var dragging: DesktopGlyphID?
    /// Live drag preview cell (nil when not dragging).
    @Published var dragCol: Int?
    @Published var dragRow: Int?
    @Published var showGridGuides = false

    /// Grid geometry — even gutters, intentional margins clear of the bar.
    let cols = 6
    let rows = 4
    let gutter: CGFloat = 16
    let marginX: CGFloat = 48

    private var window: NSWindow?
    private var tick: Timer?
    private var themeId: String { Palette.load().s("theme_id", "nothing") }
    private var storePath: String { ncRoot + "/generated/desktop-glyphs-\(themeId).json" }
    private var legacyStorePath: String { ncRoot + "/generated/desktop-glyphs.json" }

    private var reduceMotion: Bool {
        VeilFeature.forceReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func start() {
        load()
        guard enabled, !veilIsOff else { stop(); return }
        ensureWindow()
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func stop() {
        tick?.invalidate(); tick = nil
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
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
        let c = min(max(0, col), cols - span.cols)
        let r = min(max(0, row), rows - span.rows)
        pins[i].col = c
        pins[i].row = r
        // Resolve overlaps by pushing the moved tile first (it wins the cell).
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
        if let p = pins.first(where: { $0.id == id }) {
            dragCol = p.col; dragRow = p.row
        }
    }

    func updateDrag(local point: CGPoint, canvas: CGSize) {
        guard dragging != nil else { return }
        let cell = cellAt(point: point, canvas: canvas)
        dragCol = cell.col
        dragRow = cell.row
    }

    func endDrag(commit: Bool) {
        if commit, let id = dragging, let c = dragCol, let r = dragRow {
            move(id, toCol: c, toRow: r)
        } else {
            dragging = nil; dragCol = nil; dragRow = nil; showGridGuides = false
        }
    }

    // MARK: - Balanced default (symmetrical bento)

    /// 6×4 grid. Clock left 2×2, Quick right 2×2, Sys + Cava stacked in the center column pair —
    /// mirrored margins, even gutters, looks intentional out of the box.
    ///
    /// ```
    ///   0 1 2 3 4 5
    /// 0 [ CLOCK ] . [ QUICK ]
    /// 1 [       ] . [       ]
    /// 2 . . [S][C] . .
    /// 3 . . . . . .
    /// ```
    private func defaultLayout() -> [DesktopGlyphPin] {
        [
            DesktopGlyphPin(id: .clock, col: 0, row: 0, pinned: true),
            DesktopGlyphPin(id: .quick, col: 4, row: 0, pinned: true),
            DesktopGlyphPin(id: .sys,   col: 2, row: 2, pinned: true),
            DesktopGlyphPin(id: .cava,  col: 3, row: 2, pinned: true),
        ]
    }

    private func defaultPin(_ id: DesktopGlyphID, pinned: Bool) -> DesktopGlyphPin {
        defaultLayout().first(where: { $0.id == id })
            ?? DesktopGlyphPin(id: id, col: 0, row: 0, pinned: pinned)
    }

    // MARK: - Persistence (per theme)

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
            // v2 stores have real col/row; v1 / missing version → migrate or reset to balanced default.
            if (obj.version ?? 1) < 2 {
                pins = defaultLayout()
                save()
            } else {
                pins = migrateIfNeeded(obj.pins)
            }
        } else if let data = try? Data(contentsOf: legacy),
                  let obj = try? JSONDecoder().decode(Store.self, from: data), !obj.pins.isEmpty {
            // One-shot migrate free-float → balanced grid for this theme.
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
        // Old saves used nx/ny only (col/row defaulted to 0). Detect “all stacked at 0,0”.
        let allOrigin = raw.filter(\.pinned).allSatisfy { $0.col == 0 && $0.row == 0 }
        if allOrigin && raw.filter(\.pinned).count > 1 {
            return defaultLayout()
        }
        // If any pin still has nx/ny and col/row are 0, map nx/ny → grid.
        return raw.map { pin in
            var p = pin
            if let nx = pin.nx, let ny = pin.ny, pin.col == 0 && pin.row == 0 {
                p.col = min(cols - pin.id.span.cols, max(0, Int((nx * Double(cols)).rounded(.down))))
                // ny was bottom-up; row 0 is top.
                let rowFromBottom = Int((ny * Double(rows)).rounded(.down))
                p.row = min(rows - pin.id.span.rows, max(0, rows - 1 - rowFromBottom))
                p.nx = nil; p.ny = nil
            }
            return p
        }
    }

    private func save() {
        let dir = (storePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let cleaned = pins.map { DesktopGlyphPin(id: $0.id, col: $0.col, row: $0.row, pinned: $0.pinned) }
        let data = try? JSONEncoder().encode(Store(enabled: enabled, pins: cleaned, version: 2))
        try? data?.write(to: URL(fileURLWithPath: storePath), options: .atomic)
    }

    // MARK: - Window

    private func ensureWindow() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        if window == nil {
            let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.hidesOnDeactivate = false
            w.isReleasedWhenClosed = false
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window = w
        }
        window?.setFrame(frame, display: true)
        window?.contentView = PassThroughHost(rootView:
            DesktopGlyphCanvas(board: self)
                .frame(width: frame.width, height: frame.height)
        )
        window?.orderFrontRegardless()
    }

    private var loadedTheme: String?

    func refresh() {
        guard enabled, !veilIsOff else { stop(); return }
        // Theme may have changed — reload that theme’s layout.
        if loadedTheme != themeId {
            load()
            loadedTheme = themeId
        }
        ensureWindow()
        VeilPanelHost.shared.ensureMusicMeta()
        objectWillChange.send()
    }

    // MARK: - Grid math

    struct GridMetrics {
        var origin: CGPoint
        var cell: CGSize
        var gutter: CGFloat
        var canvas: CGSize
    }

    func metrics(in size: CGSize) -> GridMetrics {
        let barBottom = Palette.load().s("bar_position", "top") == "bottom"
        let topPad: CGFloat = barBottom ? 36 : 64
        let bottomPad: CGFloat = barBottom ? 64 : 36
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
        let span = pin.id.span
        let col = displayCol(for: pin)
        let row = displayRow(for: pin)
        let x = m.origin.x + CGFloat(col) * (m.cell.width + m.gutter)
        let y = m.origin.y + CGFloat(row) * (m.cell.height + m.gutter)
        let w = CGFloat(span.cols) * m.cell.width + CGFloat(span.cols - 1) * m.gutter
        let h = CGFloat(span.rows) * m.cell.height + CGFloat(span.rows - 1) * m.gutter
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func displayCol(for pin: DesktopGlyphPin) -> Int {
        if dragging == pin.id, let c = dragCol { return min(cols - pin.id.span.cols, max(0, c)) }
        return pin.col
    }

    private func displayRow(for pin: DesktopGlyphPin) -> Int {
        if dragging == pin.id, let r = dragRow { return min(rows - pin.id.span.rows, max(0, r)) }
        return pin.row
    }

    func cellAt(point: CGPoint, canvas: CGSize) -> (col: Int, row: Int) {
        let m = metrics(in: canvas)
        let x = point.x - m.origin.x
        let y = point.y - m.origin.y
        let strideX = m.cell.width + m.gutter
        let strideY = m.cell.height + m.gutter
        let col = Int(floor(x / strideX))
        let row = Int(floor(y / strideY))
        return (min(cols - 1, max(0, col)), min(rows - 1, max(0, row)))
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
                }
                ForEach(board.pins.filter(\.pinned)) { pin in
                    let frame = board.frame(for: pin, metrics: m)
                    DraggableGlyph(
                        board: board,
                        pin: pin,
                        canvas: geo.size,
                        reduceMotion: reduceMotion
                    ) {
                        widget(pin)
                            .frame(width: frame.width, height: frame.height)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .zIndex(board.dragging == pin.id ? 10 : 1)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.86),
                               value: "\(pin.col),\(pin.row),\(board.dragCol ?? -1),\(board.dragRow ?? -1)")
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(p["fg"].opacity(0.08), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(Date(), style: .time)
                .font(display(56))
                .foregroundStyle(p["fg"])
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(dateLine())
                .font(mono(10))
                .foregroundStyle(p["comment"])
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(greeting())
                .font(ui(16))
                .foregroundStyle(p["fg"])
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { GlyphShell.shared.present(.cal) } label: {
                Text("CALENDAR").font(mono(9)).foregroundStyle(p["cyan"])
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBG)
        .contextMenu { pinMenu(.clock) }
    }

    private var quickWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("QUICK").font(display(22)).foregroundStyle(p["fg"])
                Spacer()
                Button { GlyphShell.shared.present(.quick) } label: {
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(p["dim"])
                }.buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                quickChip("Wi‑Fi", "wifi")
                quickChip("BT", "wave.3.right")
                quickChip("Focus", "moon.fill")
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button("Style") { GlyphShell.shared.present(.style) }.buttonStyle(GlyphBtn(p: p, filled: true))
                Button("Shot") { GlyphShell.shared.present(.shot) }.buttonStyle(GlyphBtn(p: p))
                Button("Power") { GlyphShell.shared.present(.power) }.buttonStyle(GlyphBtn(p: p))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBG)
        .contextMenu { pinMenu(.quick) }
    }

    private var cavaWidget: some View {
        ZStack {
            Circle().stroke(p["border"], lineWidth: 8)
            Circle().trim(from: 0, to: 0.55)
                .stroke(p["cyan"], style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("CAVA").font(mono(10)).foregroundStyle(p["comment"])
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .contextMenu { pinMenu(.cava) }
    }

    private var mediaWidget: some View {
        HStack(spacing: 10) {
            Group {
                if let art = VeilPanelHost.shared.musicArtwork {
                    Image(nsImage: art).resizable().aspectRatio(1, contentMode: .fill)
                } else if let disk = NSImage(contentsOfFile: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg") {
                    Image(nsImage: disk).resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    ZStack {
                        p["surface"]
                        Image(systemName: "music.note").foregroundStyle(p["dim"])
                    }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(VeilPanelHost.shared.musicTitle).font(ui(13, .semibold)).foregroundStyle(p["fg"]).lineLimit(1)
                Text(VeilPanelHost.shared.musicArtist).font(mono(9)).foregroundStyle(p["comment"]).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(tileBG)
        .onTapGesture { VeilPanelHost.shared.toggle(.music, near: nil) }
        .contextMenu { pinMenu(.media) }
    }

    private var sysWidget: some View {
        VStack(spacing: 6) {
            Text("SYS").font(mono(9)).foregroundStyle(p["comment"])
            Text("CPU").font(display(28)).foregroundStyle(p["fg"])
            Text(VeilPanelHost.shared.statusLine.isEmpty ? "· · ·" : VeilPanelHost.shared.statusLine)
                .font(mono(8)).foregroundStyle(p["dim"]).lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tileBG)
        .onAppear { VeilPanelHost.shared.ensureMusicMeta() }
        .contextMenu { pinMenu(.sys) }
    }

    private var tileBG: some View {
        RoundedRectangle(cornerRadius: max(12, p.num("l_radius", 16) * 0.7), style: .continuous)
            .fill(p["bg_float"].opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: max(12, p.num("l_radius", 16) * 0.7), style: .continuous)
                    .strokeBorder(p["border"].opacity(0.55), lineWidth: 1)
            )
    }

    private func quickChip(_ t: String, _ sym: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: sym).font(.system(size: 10, weight: .semibold))
            Text(t.uppercased()).font(mono(8))
        }
        .foregroundStyle(p["fg"])
        .padding(.horizontal, 8).padding(.vertical, 6)
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
        let f = DateFormatter(); f.dateFormat = "EEEE — d MMMM — 'WEEK' w"
        return f.string(from: Date()).uppercased()
    }
    private func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "morning" : h < 18 ? "afternoon" : "evening"
        return "Good \(part), nothing."
    }
}

// MARK: - Drag + snap

struct DraggableGlyph<Content: View>: View {
    @ObservedObject var board: DesktopGlyphBoard
    let pin: DesktopGlyphPin
    let canvas: CGSize
    let reduceMotion: Bool
    @ViewBuilder var content: () -> Content
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        content()
            .offset(dragOffset)
            .scaleEffect(board.dragging == pin.id && !reduceMotion ? 1.03 : 1)
            .shadow(color: board.dragging == pin.id ? .black.opacity(0.35) : .clear, radius: 18, y: 8)
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if board.dragging != pin.id { board.beginDrag(pin.id) }
                        dragOffset = value.translation
                        let origin = board.frame(for: pin, metrics: board.metrics(in: canvas))
                        let finger = CGPoint(
                            x: origin.midX + value.translation.width,
                            y: origin.midY + value.translation.height
                        )
                        board.updateDrag(local: finger, canvas: canvas)
                    }
                    .onEnded { _ in
                        dragOffset = .zero
                        board.endDrag(commit: true)
                    }
            )
    }
}
