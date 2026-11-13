// Glyph / Nothing OS surfaces for Veil: Quick, Deck, Prefs, Power, Home, Walls,
// VPN, Cal, Buds, Shot, Charms, Style (theme creator), Lock/Login mocks.
// Edge Glyph lights ride OSD when theme_id == nothing. Lock never touches ScreenSaverEngine.
import AppKit
import Carbon
import Combine
import SwiftUI

enum GlyphKind: String, CaseIterable {
    case quick, deck, prefs, power, home, walls, vpn, cal, buds, shot, charms, style, lockMock, loginMock
}

// MARK: - Shell host

@MainActor
final class GlyphShell: ObservableObject {
    static let shared = GlyphShell()
    @Published var kind: GlyphKind?
    @Published var sel = 0
    @Published var styleSource = "nothing"   // nothing | wall | palette
    @Published var styleScheme = "mocha"
    @Published var styleVariant = "tonalspot"
    @Published var styleLight = false
    @Published var previewName = "Nothing"
    @Published var toast = ""
    private var window: NSWindow?
    private var keyMonitor: Any?
    private var reduceMotion: Bool {
        VeilFeature.forceReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func toggle(_ k: GlyphKind) {
        if kind == k { dismiss(); return }
        present(k)
    }

    func present(_ k: GlyphKind) {
        kind = k
        sel = k == .power ? 2 : 0
        ensureWindow()
        refresh()
        guard let window else { return }
        window.alphaValue = reduceMotion ? 1 : 0
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
        installKeys()
    }

    func dismiss() {
        removeKeys()
        // Instant teardown — never leave an empty chrome layer while fade-out races.
        let window = self.window
        kind = nil
        window?.orderOut(nil)
        window?.contentView = nil
        window?.alphaValue = 1
        self.window = nil
    }

    private func ensureWindow() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame: NSRect
        switch kind {
        case .quick:
            let w: CGFloat = 470, h: CGFloat = 620
            frame = NSRect(x: screen.visibleFrame.maxX - w - 14,
                           y: screen.visibleFrame.minY + 14, width: w, height: h)
        case .deck:
            let w = min(980, screen.visibleFrame.width - 40), h: CGFloat = 280
            frame = NSRect(x: screen.visibleFrame.midX - w / 2,
                           y: screen.visibleFrame.minY + 18, width: w, height: h)
        case .power, .lockMock, .loginMock, .home, .style:
            frame = screen.frame
        case .prefs, .walls, .vpn, .cal, .buds, .shot, .charms:
            let w: CGFloat = 560, h: CGFloat = 520
            frame = NSRect(x: screen.visibleFrame.midX - w / 2,
                           y: screen.visibleFrame.midY - h / 2, width: w, height: h)
        case .none:
            frame = .zero
        }
        if window == nil {
            let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = true
            w.level = .statusBar + 2
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
            w.isReleasedWhenClosed = false
            w.hidesOnDeactivate = false
            window = w
        }
        window?.setFrame(frame, display: true)
        refresh()
    }

    private func refresh() {
        guard let window, let kind else { return }
        let p = Palette.load()
        window.contentView = NSHostingView(rootView:
            GlyphRoot(shell: self, kind: kind, p: p)
                .frame(width: window.frame.width, height: window.frame.height)
        )
    }

    private func installKeys() {
        removeKeys()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.kind != nil else { return e }
            if e.keyCode == UInt16(kVK_Escape) { self.dismiss(); return nil }
            if self.kind == .power {
                if e.keyCode == UInt16(kVK_UpArrow) || e.keyCode == UInt16(kVK_ANSI_K) {
                    self.sel = (self.sel + 4) % 5; self.refresh(); return nil
                }
                if e.keyCode == UInt16(kVK_DownArrow) || e.keyCode == UInt16(kVK_ANSI_J) || e.keyCode == UInt16(kVK_Tab) {
                    self.sel = (self.sel + 1) % 5; self.refresh(); return nil
                }
                if e.keyCode == UInt16(kVK_Return) || e.keyCode == UInt16(kVK_ANSI_KeypadEnter) {
                    self.runPower(self.sel); return nil
                }
            }
            return e
        }
    }

    private func removeKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Power actions. LOCK is inert (mock toast) — never ScreenSaverEngine / loginwindow lock from this menu.
    func runPower(_ i: Int) {
        dismiss()
        switch i {
        case 0:
            toast = "Lock UI is mock-only on Mac (no ScreenSaverEngine)."
            present(.lockMock)
        case 1:
            _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["sleepnow"])
        case 2:
            _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"),
                                 arguments: ["-e", "tell application \"loginwindow\" to «event aevtrsdn»"])
        case 3:
            _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"),
                                 arguments: ["-e", "tell application \"loginwindow\" to «event aevtrrst»"])
        case 4:
            _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"),
                                 arguments: ["-e", "tell application \"loginwindow\" to «event aevtrlgo»"])
        default: break
        }
    }

    func applyStylePack(id: String) {
        let bin = (Bundle.main.executableURL?.deletingLastPathComponent().path)
            .map { "\($0)/../../../../../.config/veil/bin/veil-theme" }
        let themeBin = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/veil/bin/veil-theme").path
        let path = FileManager.default.isExecutableFile(atPath: themeBin) ? themeBin : (bin ?? themeBin)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["apply", id]
        p.environment = ProcessInfo.processInfo.environment
        try? p.run()
        toast = "Applying \(id)…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.dismiss() }
    }

    func exportPack(name: String) {
        let script = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/veil/bin/veil-style").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: script)
        p.arguments = ["export", name]
        try? p.run()
        toast = "Exported theme pack \(name)"
    }

    static func registerHotkeys() {
        // Glyph surfaces: ⌃⌥ + letter (⌘Space stays launcher). Avoid ⌃⌥⌘V (Veil on/off) and Option←/→.
        let pairs: [(UInt32, UInt32, UInt32, GlyphKind)] = [
            (UInt32(kVK_ANSI_A), UInt32(controlKey | optionKey), 10, .quick),
            (UInt32(kVK_Space), UInt32(controlKey | optionKey), 11, .deck),
            (UInt32(kVK_ANSI_I), UInt32(controlKey | optionKey), 12, .prefs),
            (UInt32(kVK_Escape), UInt32(controlKey | optionKey), 13, .power),
            (UInt32(kVK_ANSI_W), UInt32(controlKey | optionKey), 14, .walls),
            (UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), 15, .vpn),
            (UInt32(kVK_ANSI_C), UInt32(controlKey | optionKey), 16, .cal),
            (UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey), 17, .buds),
            (UInt32(kVK_ANSI_S), UInt32(controlKey | optionKey), 18, .shot),
            (UInt32(kVK_ANSI_Period), UInt32(controlKey | optionKey), 19, .charms),
            (UInt32(kVK_ANSI_Y), UInt32(controlKey | optionKey), 20, .style),
            (UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey), 21, .home),
        ]
        for (key, mods, id, _) in pairs {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(key, mods, EventHotKeyID(signature: OSType(0x474C_5048), id: id),
                                GetApplicationEventTarget(), 0, &ref)
        }
        // ⌃⌥V → clipboard history via launcher (not ⌃⌥⌘V Veil toggle)
        var clipRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey),
                            EventHotKeyID(signature: OSType(0x474C_5048), id: 22),
                            GetApplicationEventTarget(), 0, &clipRef)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, ev, _) -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard hk.signature == OSType(0x474C_5048) else { return OSStatus(eventNotHandledErr) }
            if hk.id == 22 {
                let run = {
                    DistributedNotificationCenter.default().postNotificationName(
                        Notification.Name("app.veil.search.show"), object: "clip ", userInfo: nil, deliverImmediately: true)
                }
                if Thread.isMainThread { run() } else { DispatchQueue.main.sync(execute: run) }
                return noErr
            }
            let map: [UInt32: GlyphKind] = [
                10: .quick, 11: .deck, 12: .prefs, 13: .power, 14: .walls, 15: .vpn,
                16: .cal, 17: .buds, 18: .shot, 19: .charms, 20: .style, 21: .home
            ]
            guard let kind = map[hk.id] else { return OSStatus(eventNotHandledErr) }
            let run = { GlyphShell.shared.toggle(kind) }
            if Thread.isMainThread { run() } else { DispatchQueue.main.sync(execute: run) }
            return noErr
        }, 1, &spec, nil, nil)

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("app.veil.glyph.show"), object: nil, queue: .main
        ) { n in
            let raw = (n.object as? String) ?? ""
            guard let kind = GlyphKind(rawValue: raw) else { return }
            Task { @MainActor in GlyphShell.shared.toggle(kind) }
        }
    }
}

// MARK: - Root

struct GlyphRoot: View {
    @ObservedObject var shell: GlyphShell
    let kind: GlyphKind
    let p: Palette
    var red: Color { p["red"] }
    var fg: Color { p["fg"] }
    var muted: Color { p["comment"] }
    var panel: Color { p["bg_float"] }
    var bg: Color { p["bg"] }

    func ui(_ size: CGFloat, _ w: Font.Weight = .medium) -> Font {
        let n = p.s("ui_font", "")
        return n.isEmpty ? .system(size: size, weight: w) : .custom(n, size: size).weight(w)
    }
    func mono(_ size: CGFloat, _ w: Font.Weight = .bold) -> Font {
        let n = p.s("ui_mono", "")
        return n.isEmpty ? .system(size: size, weight: w, design: .monospaced) : .custom(n, size: size).weight(w)
    }
    /// Display digits: Doto on Nothing; each other theme keeps its own UI face (Glyph ideology, theme voice).
    func doto(_ size: CGFloat) -> Font {
        if p.s("theme_id", "") == "nothing" { return .custom("Doto", size: size).weight(.bold) }
        return ui(size, .bold)
    }

    var body: some View {
        ZStack {
            switch kind {
            case .quick: quick
            case .deck: deck
            case .prefs: prefs
            case .power: power
            case .home: home
            case .walls: walls
            case .vpn: vpn
            case .cal: cal
            case .buds: buds
            case .shot: shot
            case .charms: charms
            case .style: styleCreator
            case .lockMock: lockMock
            case .loginMock: loginMock
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Quick (right edge)

    var quick: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(Date(), style: .time).font(doto(42)).foregroundStyle(fg)
                    Spacer()
                    Text("QUICK").font(mono(11)).foregroundStyle(muted).tracking(2)
                }
                HStack(spacing: 10) {
                    pill("Wi‑Fi", "wifi"); pill("Bluetooth", "wave.3.right"); pill("Focus", "moon.fill")
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    tile("Dark", "circle.lefthalf.filled") { shell.applyStylePack(id: "nothing") }
                    tile("Theme", "paintpalette") { shell.present(.style) }
                    tile("Shot", "camera") { shell.present(.shot) }
                    tile("VPN", "lock.shield") { shell.present(.vpn) }
                    tile("Buds", "earbuds") { shell.present(.buds) }
                    tile("Power", "power") { shell.present(.power) }
                }
                sliderRow("VOLUME")
                sliderRow("BRIGHTNESS")
                mediaStrip
                Text("Notifications · empty").font(ui(12)).foregroundStyle(muted)
            }
            .padding(22)
            .frame(width: 470)
            .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(panel))
            .padding(14)
        }
    }

    func pill(_ t: String, _ sym: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: sym).font(.system(size: 11, weight: .semibold))
            Text(t.uppercased()).font(mono(10))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(bg))
    }

    func tile(_ t: String, _ sym: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: sym).font(.system(size: 18, weight: .medium))
                Text(t.uppercased()).font(mono(9)).tracking(1)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(bg))
        }.buttonStyle(.plain)
    }

    func sliderRow(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(mono(9)).foregroundStyle(muted).tracking(2)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Color.white).frame(width: g.size.width * 0.55)
                }
            }.frame(height: 10)
        }
    }

    var mediaStrip: some View {
        HStack(spacing: 14) {
            Group {
                if let art = VeilPanelHost.shared.musicArtwork {
                    Image(nsImage: art).resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Circle().fill(Color.white.opacity(0.08)).overlay(DotField().clipShape(Circle()))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW PLAYING").font(mono(9)).foregroundStyle(muted)
                Text(VeilPanelHost.shared.musicTitle).font(ui(14, .semibold)).foregroundStyle(fg).lineLimit(1)
                Text(VeilPanelHost.shared.musicArtist).font(ui(12)).foregroundStyle(muted).lineLimit(1)
            }
            Spacer()
            Button {
                VeilPanelHost.shared.musicAction("playpause")
            } label: {
                Circle().fill(p["cyan"]).frame(width: 36, height: 36)
                    .overlay(Image(systemName: VeilPanelHost.shared.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(bg))
        .onAppear { VeilPanelHost.shared.ensureMusicMeta(artwork: true) }
    }

    // MARK: Deck

    var deck: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { shell.dismiss() }
            HStack(spacing: 14) {
                deckCard("CPU", sys("cpu"))
                deckCard("MEM", sys("mem"))
                deckCard("BAT", sys("bat"))
                VStack(alignment: .leading, spacing: 8) {
                    Text("DECK").font(mono(10)).foregroundStyle(muted).tracking(3)
                    Text(Date(), style: .time).font(doto(36)).foregroundStyle(fg)
                    Text(greeting()).font(ui(16)).foregroundStyle(fg)
                    HStack(spacing: 8) {
                        Button("Style") { shell.present(.style) }.buttonStyle(GlyphBtn(p: p))
                        Button("Prefs") { shell.present(.prefs) }.buttonStyle(GlyphBtn(p: p))
                        Button("Home") { shell.present(.home) }.buttonStyle(GlyphBtn(p: p))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
            }
            .padding(.horizontal, 20).padding(.bottom, 18)
        }
    }

    func deckCard(_ title: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(mono(10)).foregroundStyle(muted)
            Text(value).font(doto(28)).foregroundStyle(fg)
        }
        .frame(width: 110, height: 110)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
    }

    func sys(_ k: String) -> String {
        switch k {
        case "cpu": return "—"
        case "mem":
            let info = ProcessInfo.processInfo
            return String(format: "%.0fG", Double(info.physicalMemory) / 1e9)
        case "bat":
            return "··"
        default: return "·"
        }
    }

    func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        let part = h < 12 ? "morning" : h < 18 ? "afternoon" : "evening"
        return "Good \(part), nothing."
    }

    // MARK: Prefs

    var prefs: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 18) {
                Text("PREFS").font(doto(36)).foregroundStyle(fg)
                Text("Bar · Home · Audio · Style").font(mono(11)).foregroundStyle(muted).tracking(2)
                Group {
                    prefRow("Bar position", p.s("bar_position", "bottom"))
                    prefRow("Bar layout", p.s("bar_layout", "strip"))
                    prefRow("UI font", p.s("ui_font", "Space Grotesk"))
                    prefRow("Accent", "#D71921")
                }
                HStack {
                    Button("Open Style") { shell.present(.style) }.buttonStyle(GlyphBtn(p: p, filled: true))
                    Button("Home widgets") { shell.present(.home) }.buttonStyle(GlyphBtn(p: p))
                    Spacer()
                    Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
                }
            }
            .padding(28)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(panel))
        }
    }

    func prefRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k.uppercased()).font(mono(10)).foregroundStyle(muted)
            Spacer()
            Text(v).font(ui(14, .semibold)).foregroundStyle(fg)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }

    // MARK: Power

    var power: some View {
        let items = ["LOCK", "SLEEP", "SHUT DOWN", "REBOOT", "LOG OUT"]
        return ZStack {
            bg.opacity(0.96).ignoresSafeArea().onTapGesture { shell.dismiss() }
            HStack(alignment: .center, spacing: 80) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(items.indices, id: \.self) { i in
                        HStack(spacing: 24) {
                            Circle().fill(red).frame(width: 18, height: 18).opacity(shell.sel == i ? 1 : 0)
                            Text(items[i])
                                .font(doto(shell.sel == i ? 48 : 28))
                                .foregroundStyle(shell.sel == i ? fg : muted)
                                .animation(.easeOut(duration: 0.2), value: shell.sel)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { shell.sel = i; shell.runPower(i) }
                    }
                }
                DotRing(progress: 0.42, color: fg, accent: red).frame(width: 160, height: 160)
            }
            .padding(80)
            VStack {
                Spacer()
                Text("LOCK is mock-only · no ScreenSaverEngine").font(mono(10)).foregroundStyle(muted).padding(.bottom, 28)
            }
        }
    }

    // MARK: Home

    var home: some View {
        ZStack {
            bg.ignoresSafeArea().onTapGesture { shell.dismiss() }
            // faint dots
            DotField().opacity(0.35).ignoresSafeArea().allowsHitTesting(false)
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(Date(), style: .time).font(doto(96)).foregroundStyle(fg)
                    Text(dateLine()).font(mono(12)).foregroundStyle(muted).tracking(2)
                    Text(greeting()).font(ui(28)).foregroundStyle(fg).padding(.top, 12)
                    HStack(spacing: 16) {
                        Label("0 NOTIFICATIONS", systemImage: "bell").font(mono(10)).foregroundStyle(muted)
                    }
                }
                Spacer()
                LazyVGrid(columns: [GridItem(.fixed(150)), GridItem(.fixed(150))], spacing: 14) {
                    // Calendar Glyph slot → Quick (calendar remains via clock click / desktop clock).
                    Button { shell.present(.quick) } label: {
                        homeTile("QUICK", Image(systemName: "switch.2").font(.system(size: 36, weight: .medium)))
                    }.buttonStyle(.plain)
                    homeTile("GPU", Text("·").font(doto(42)))
                    homeTile("SYS", Text("CPU").font(mono(12)))
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 8)
                        Circle().trim(from: 0, to: 0.55).stroke(p["cyan"], style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("CAVA").font(mono(10)).foregroundStyle(muted)
                    }
                    .frame(width: 150, height: 150)
                    .background(Circle().fill(panel))
                }
                Text("Calendar · click clock on desktop Glyph or ⌃⌥C")
                    .font(mono(9)).foregroundStyle(muted)
            }
            .padding(60)
            VStack {
                HStack {
                    Spacer()
                    Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p)).padding(24)
                }
                Spacer()
            }
        }
    }

    func homeTile<Content: View>(_ title: String, _ content: Content) -> some View {
        VStack(spacing: 8) {
            Text(title).font(mono(10)).foregroundStyle(muted)
            content.foregroundStyle(fg)
        }
        .frame(width: 150, height: 150)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
    }

    func dateLine() -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE — d MMMM — 'WEEK' w"
        return f.string(from: Date()).uppercased()
    }

    // MARK: Walls

    var walls: some View {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/veil/art")
        let pics = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 16) {
                Text("WALLS").font(doto(32)).foregroundStyle(fg)
                Text("Wallpapers as dots · pick to apply").font(mono(10)).foregroundStyle(muted)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(pics, id: \.path) { url in
                            Button {
                                applyWall(url)
                            } label: {
                                ZStack {
                                    if let img = NSImage(contentsOf: url) {
                                        Image(nsImage: img).resizable().scaledToFill()
                                    }
                                    DotField().opacity(0.45)
                                }
                                .frame(width: 100, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(Text(url.deletingPathExtension().lastPathComponent)
                                    .font(mono(8)).foregroundStyle(.white).padding(4), alignment: .bottomLeading)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 320)
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(24)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
        }
    }

    func applyWall(_ url: URL) {
        let js = "ObjC.import('Foundation'); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately('app.veil.search.desktop', '\(url.path)', $(), true)"
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-l", "JavaScript", "-e", js])
        shell.toast = "Wallpaper: \(url.deletingPathExtension().lastPathComponent)"
    }

    // MARK: VPN

    var vpn: some View {
        let clash = FileManager.default.fileExists(atPath: "/Applications/Clash Verge.app")
            || FileManager.default.fileExists(atPath: NSString("~/Applications/Clash Verge.app").expandingTildeInPath)
        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("VPN").font(doto(32)).foregroundStyle(fg)
                Text(clash ? "Clash Verge detected" : "No Clash Verge · macOS VPN stubs").font(mono(10)).foregroundStyle(muted)
                if clash {
                    Button("Open Clash Verge") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Clash Verge.app"))
                        shell.dismiss()
                    }.buttonStyle(GlyphBtn(p: p, filled: true))
                }
                Button("Open Network Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!)
                    shell.dismiss()
                }.buttonStyle(GlyphBtn(p: p))
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(28)
            .frame(width: 420)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
        }
    }

    // MARK: Cal

    var cal: some View {
        let day = Calendar.current.component(.day, from: Date())
        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 16) {
                Text("CAL").font(doto(32)).foregroundStyle(fg)
                HStack(alignment: .top, spacing: 24) {
                    VStack {
                        Text(DateFormatter.month.string(from: Date()).uppercased()).font(mono(10)).foregroundStyle(muted)
                        Text("\(day)").font(doto(72)).foregroundStyle(fg)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FOCUS TIMER").font(mono(10)).foregroundStyle(muted)
                        Text("25:00").font(doto(36)).foregroundStyle(fg)
                        Text("Click clock in bar · stub timer UI").font(ui(12)).foregroundStyle(muted)
                        let events = CalendarSource.upcoming("today")
                        ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, e in
                            Text(e.title).font(ui(13)).foregroundStyle(fg).lineLimit(1)
                        }
                    }
                }
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(28)
            .frame(width: 480)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
        }
    }

    // MARK: Buds

    var buds: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("BUDS").font(doto(32)).foregroundStyle(fg)
                Text("Nothing / CMF · stub until BLE bridge").font(mono(10)).foregroundStyle(muted)
                HStack(spacing: 20) {
                    bud("L", "—"); bud("R", "—"); bud("CASE", "—")
                }
                Text("ANC · Transparency · Off").font(ui(13)).foregroundStyle(muted)
                Text("Protocol bridge inventable post-SIP; UI ships now.").font(ui(12)).foregroundStyle(muted)
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(28)
            .frame(width: 420)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
        }
    }

    func bud(_ label: String, _ pct: String) -> some View {
        VStack {
            Text(label).font(mono(10)).foregroundStyle(muted)
            Text(pct).font(doto(28)).foregroundStyle(fg)
        }
        .frame(width: 90, height: 90)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(bg))
    }

    // MARK: Shot

    var shot: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("SHOT").font(doto(32)).foregroundStyle(fg)
                Text("Screenshots · recording").font(mono(10)).foregroundStyle(muted)
                HStack(spacing: 10) {
                    Button("Selection") { runShot(["-i"]); shell.dismiss() }.buttonStyle(GlyphBtn(p: p, filled: true))
                    Button("Window") { runShot(["-i", "-w"]); shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
                    Button("Display") { runShot([]); shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
                }
                Button("Record (Cmd+Shift+5)") {
                    _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/open"),
                                         arguments: ["-a", "Screenshot"])
                    shell.dismiss()
                }.buttonStyle(GlyphBtn(p: p))
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(28)
            .frame(width: 480)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
        }
    }

    func runShot(_ args: [String]) {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let name = "Veil-\(Int(Date().timeIntervalSince1970)).png"
        let out = dir.appendingPathComponent(name).path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = args + [out]
        try? p.run()
    }

    // MARK: Charms

    var charms: some View {
        let samples: [(String, String)] = [
            ("😀", "grinning"), ("🔥", "fire"), ("✨", "sparkles"), ("❤️", "heart"),
            ("(╯°□°）╯︵ ┻━┻", "flip"), ("¯\\_(ツ)_/¯", "shrug"), ("→", "arrow"), ("·", "dot")
        ]
        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("CHARMS").font(doto(32)).foregroundStyle(fg)
                Text("Emoji · kaomoji · symbols · also :emoji in launcher").font(mono(10)).foregroundStyle(muted)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(samples, id: \.1) { s in
                        Button {
                            copyText(s.0, secret: false)
                            shell.dismiss()
                        } label: {
                            Text(s.0).font(.system(size: 22))
                                .frame(width: 70, height: 48)
                                .background(RoundedRectangle(cornerRadius: 12).fill(bg))
                        }.buttonStyle(.plain)
                    }
                }
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(28)
            .frame(width: 480)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(panel))
        }
    }

    // MARK: Style / Theme creator

    var styleCreator: some View {
        let palettes = [
            ("nothing", "Nothing"), ("catppuccin-mocha", "Catppuccin Mocha"), ("rose-pine", "Rosé Pine"),
            ("gruvbox", "Gruvbox"), ("nord", "Nord"), ("dracula", "Dracula"),
            ("tokyo-night", "Tokyo Night"), ("everforest", "Everforest"), ("kanagawa", "Kanagawa")
        ]
        let variants = ["monochrome", "neutral", "tonalspot", "rainbow", "content", "fidelity", "fruitsalad", "expressive", "vibrant"]
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { shell.dismiss() }
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("STYLE").font(doto(36)).foregroundStyle(fg)
                    Text("Theme creator · live preview").font(mono(10)).foregroundStyle(muted).tracking(1)
                    Text("SOURCE").font(mono(9)).foregroundStyle(muted)
                    HStack {
                        sourceChip("nothing", "Nothing")
                        sourceChip("wall", "Wallpaper")
                        sourceChip("palette", "Palette")
                    }
                    if shell.styleSource == "palette" {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(palettes, id: \.0) { id, name in
                                    Button {
                                        shell.styleScheme = id
                                        shell.previewName = name
                                        runStylePreview()
                                    } label: {
                                        HStack {
                                            Circle().fill(swatch(for: id)).frame(width: 14, height: 14)
                                            Text(name).font(ui(13)).foregroundStyle(fg)
                                            Spacer()
                                            if shell.styleScheme == id { Circle().fill(red).frame(width: 8, height: 8) }
                                        }
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.frame(height: 180)
                    }
                    if shell.styleSource == "wall" {
                        Text("MATERIAL YOU VARIANT").font(mono(9)).foregroundStyle(muted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(variants, id: \.self) { v in
                                    Button(v) {
                                        shell.styleVariant = v
                                        runStylePreview()
                                    }
                                    .buttonStyle(GlyphBtn(p: p, filled: shell.styleVariant == v))
                                }
                            }
                        }
                    }
                    HStack {
                        Button("Apply everywhere") { applyCreator() }.buttonStyle(GlyphBtn(p: p, filled: true))
                        Button("Save pack") {
                            shell.exportPack(name: shell.previewName.lowercased().replacingOccurrences(of: " ", with: "-"))
                        }.buttonStyle(GlyphBtn(p: p))
                        Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
                    }
                    if !shell.toast.isEmpty {
                        Text(shell.toast).font(mono(10)).foregroundStyle(red)
                    }
                }
                .frame(width: 360)
                // Live desktop mock under cursor / side panel
                VStack(alignment: .leading, spacing: 10) {
                    Text("PREVIEW").font(mono(9)).foregroundStyle(muted)
                    ZStack {
                        RoundedRectangle(cornerRadius: 20).fill(Color.black)
                        DotField().opacity(0.4)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("9:41").font(doto(48)).foregroundStyle(.white)
                            Text(shell.previewName).font(ui(16)).foregroundStyle(.white.opacity(0.9))
                            HStack {
                                Capsule().fill(Color.white.opacity(0.15)).frame(width: 80, height: 10)
                                Circle().fill(previewAccent()).frame(width: 18, height: 18)
                            }
                            Spacer()
                            HStack {
                                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(height: 36)
                            }
                        }
                        .padding(20)
                    }
                    .frame(width: 280, height: 360)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    Text("Shell · bar · borders · terminal follow apply").font(ui(11)).foregroundStyle(muted)
                }
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(panel))
        }
    }

    func sourceChip(_ id: String, _ label: String) -> some View {
        Button(label) {
            shell.styleSource = id
            shell.previewName = id == "nothing" ? "Nothing" : shell.previewName
            runStylePreview()
        }
        .buttonStyle(GlyphBtn(p: p, filled: shell.styleSource == id))
    }

    func swatch(for id: String) -> Color {
        switch id {
        case "nothing": return Color(red: 0.84, green: 0.1, blue: 0.13)
        case "catppuccin-mocha": return Color(red: 0.8, green: 0.65, blue: 0.97)
        case "rose-pine": return Color(red: 0.92, green: 0.74, blue: 0.73)
        case "gruvbox": return Color(red: 1.0, green: 0.5, blue: 0.1)
        case "nord": return Color(red: 0.53, green: 0.75, blue: 0.82)
        case "dracula": return Color(red: 0.74, green: 0.58, blue: 0.98)
        case "tokyo-night": return Color(red: 0.48, green: 0.64, blue: 0.97)
        case "everforest": return Color(red: 0.65, green: 0.75, blue: 0.5)
        case "kanagawa": return Color(red: 0.49, green: 0.61, blue: 0.85)
        default: return .white
        }
    }

    func previewAccent() -> Color {
        if shell.styleSource == "nothing" { return red }
        return swatch(for: shell.styleScheme)
    }

    func runStylePreview() {
        let script = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/veil/bin/veil-style").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: script)
        p.arguments = ["preview", shell.styleSource, shell.styleScheme, shell.styleVariant,
                       shell.styleLight ? "light" : "dark"]
        try? p.run()
        shell.toast = "Preview · \(shell.previewName)"
    }

    func applyCreator() {
        let script = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/veil/bin/veil-style").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: script)
        if shell.styleSource == "nothing" {
            p.arguments = ["apply-named", "nothing"]
        } else if shell.styleSource == "palette" {
            p.arguments = ["apply-named", shell.styleScheme]
        } else {
            p.arguments = ["apply-wall", shell.styleVariant, shell.styleLight ? "light" : "dark"]
        }
        try? p.run()
        shell.toast = "Applied · \(shell.previewName)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { shell.dismiss() }
    }

    // MARK: Lock / Login mocks

    var lockMock: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("LOCK").font(doto(56)).foregroundStyle(.white)
                Text("Mock only · ScreenSaverEngine never engaged").font(mono(11)).foregroundStyle(Color.white.opacity(0.5))
                DotRing(progress: 0.2, color: .white, accent: red).frame(width: 100, height: 100)
                Button("Dismiss") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p, filled: true))
            }
        }
    }

    var loginMock: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("LOGIN").font(doto(48)).foregroundStyle(.white)
                Text("SDDM analog · Mac login cannot be replaced").font(mono(11)).foregroundStyle(Color.white.opacity(0.5))
                Capsule().fill(Color.white.opacity(0.12)).frame(width: 280, height: 36)
                    .overlay(Text("password").font(mono(12)).foregroundStyle(Color.white.opacity(0.35)))
                DotRing(progress: 0.65, color: .white, accent: red).frame(width: 120, height: 120)
                Button("Close mock") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
        }
    }
}

// MARK: - Pieces

struct GlyphBtn: ButtonStyle {
    let p: Palette
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom(p.s("ui_mono", "Space Mono"), size: 10).weight(.bold))
            .foregroundStyle(filled ? Color.white : p["fg"])
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                Capsule().fill(filled ? p["red"] : p["bg"])
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct DotField: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 10
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                             with: .color(.white.opacity(0.18)))
                    x += step
                }
                y += step
            }
        }
    }
}

struct DotRing: View {
    var progress: CGFloat
    var color: Color
    var accent: Color
    var body: some View {
        GeometryReader { g in
            let n = 60
            let r = min(g.size.width, g.size.height) / 2 - 4
            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    let t = Double(i) / Double(n) * 2 * Double.pi - Double.pi / 2
                    let on = CGFloat(i) / CGFloat(n) <= progress
                    Circle()
                        .fill(on ? accent : color.opacity(0.25))
                        .frame(width: 4, height: 4)
                        .position(x: g.size.width / 2 + CGFloat(cos(t)) * r,
                                  y: g.size.height / 2 + CGFloat(sin(t)) * r)
                }
            }
        }
    }
}

private extension DateFormatter {
    static let month: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }()
}
