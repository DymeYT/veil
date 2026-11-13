// Desktop Glyph board: pin-able widgets on the wallpaper layer (above desktop icons,
// below app windows). Hits pass through empty space. Every theme can use the same board.
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
}

struct DesktopGlyphPin: Codable, Identifiable, Equatable {
    var id: DesktopGlyphID
    /// Normalized position in the visible frame (0…1), origin bottom-leading.
    var nx: Double
    var ny: Double
    var pinned: Bool
}

@MainActor
final class DesktopGlyphBoard: ObservableObject {
    static let shared = DesktopGlyphBoard()
    @Published var pins: [DesktopGlyphPin] = []
    @Published var enabled = true
    private var window: NSWindow?
    private var tick: Timer?
    private let storePath = ncRoot + "/generated/desktop-glyphs.json"

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

    func togglePin(_ id: DesktopGlyphID) {
        if let i = pins.firstIndex(where: { $0.id == id }) {
            pins[i].pinned.toggle()
        } else {
            pins.append(defaultPin(id, pinned: true))
        }
        save(); refresh()
    }

    func setPin(_ id: DesktopGlyphID, pinned: Bool) {
        if let i = pins.firstIndex(where: { $0.id == id }) {
            pins[i].pinned = pinned
        } else if pinned {
            pins.append(defaultPin(id, pinned: true))
        }
        save(); refresh()
    }

    private func defaultPin(_ id: DesktopGlyphID, pinned: Bool) -> DesktopGlyphPin {
        // Sensible defaults: clock left, quick + cava right — clear of bottom/top bar.
        switch id {
        case .clock: return DesktopGlyphPin(id: .clock, nx: 0.08, ny: 0.55, pinned: pinned)
        case .quick: return DesktopGlyphPin(id: .quick, nx: 0.72, ny: 0.62, pinned: pinned)
        case .cava: return DesktopGlyphPin(id: .cava, nx: 0.84, ny: 0.38, pinned: pinned)
        case .media: return DesktopGlyphPin(id: .media, nx: 0.72, ny: 0.38, pinned: pinned)
        case .sys: return DesktopGlyphPin(id: .sys, nx: 0.84, ny: 0.62, pinned: pinned)
        }
    }

    private func defaultLayout() -> [DesktopGlyphPin] {
        // Home-like desktop: clock + Quick (replaces calendar slot) + cava + sys.
        [.clock, .quick, .cava, .sys].map { defaultPin($0, pinned: true) }
    }

    private func load() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: storePath)),
           let obj = try? JSONDecoder().decode(Store.self, from: data) {
            enabled = obj.enabled
            pins = obj.pins.isEmpty ? defaultLayout() : obj.pins
        } else {
            enabled = true
            pins = defaultLayout()
            save()
        }
    }

    private func save() {
        let dir = (storePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(Store(enabled: enabled, pins: pins))
        try? data?.write(to: URL(fileURLWithPath: storePath), options: .atomic)
    }

    private struct Store: Codable {
        var enabled: Bool
        var pins: [DesktopGlyphPin]
    }

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
            // Above desktop icons / notch band; below normal app windows.
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

    func refresh() {
        guard enabled, !veilIsOff else { stop(); return }
        ensureWindow()
        VeilPanelHost.shared.ensureMusicMeta()
        objectWillChange.send()
    }

    /// SwiftUI local point (origin top-leading, Y down). `ny` stays “up the screen” in storage.
    func localPoint(for pin: DesktopGlyphPin, in size: CGSize) -> CGPoint {
        let barBottom = Palette.load().s("bar_position", "top") == "bottom"
        let pad: CGFloat = 56
        let topPad = barBottom ? 12 : pad
        let bottomPad = barBottom ? pad : 12
        let usableH = max(1, size.height - topPad - bottomPad)
        let x = CGFloat(pin.nx) * size.width
        // pin.ny 0 → near bottom usable edge; 1 → near top usable edge.
        let yFromBottom = bottomPad + CGFloat(pin.ny) * usableH
        let y = size.height - yFromBottom
        return CGPoint(x: x, y: y)
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
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(board.pins.filter(\.pinned)) { pin in
                    let pt = board.localPoint(for: pin, in: geo.size)
                    widget(pin)
                        .position(pt)
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: board.pins)
        }
        .allowsHitTesting(true)
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
                .font(display(64))
                .foregroundStyle(p["fg"])
            Text(dateLine())
                .font(mono(11))
                .foregroundStyle(p["comment"])
                .tracking(1.5)
            Text(greeting())
                .font(ui(18))
                .foregroundStyle(p["fg"])
            // Clock click → calendar (calendar Glyph kept reachable here, not as Home tile).
            Button {
                GlyphShell.shared.present(.cal)
            } label: {
                Text("CALENDAR")
                    .font(mono(9))
                    .foregroundStyle(p["cyan"])
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
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
            HStack(spacing: 8) {
                Button("Style") { GlyphShell.shared.present(.style) }.buttonStyle(GlyphBtn(p: p, filled: true))
                Button("Shot") { GlyphShell.shared.present(.shot) }.buttonStyle(GlyphBtn(p: p))
                Button("Power") { GlyphShell.shared.present(.power) }.buttonStyle(GlyphBtn(p: p))
            }
        }
        .padding(16)
        .frame(width: 280)
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
        .frame(width: 120, height: 120)
        .background(Circle().fill(p["bg_float"].opacity(0.92)))
        .contextMenu { pinMenu(.cava) }
    }

    private var mediaWidget: some View {
        HStack(spacing: 10) {
            Group {
                if let art = VeilPanelHost.shared.musicArtwork {
                    Image(nsImage: art).resizable().aspectRatio(1, contentMode: .fill)
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
        .frame(width: 260)
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
        }
        .padding(14)
        .frame(width: 140, height: 120)
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
