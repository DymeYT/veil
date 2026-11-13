import AppKit
import Combine
import ScreenCaptureKit
import SwiftUI

// MARK: - Feature flags (animated panels default on; SketchyBar popups are the fallback)

enum VeilFeature {
    static var root: String { ncRoot + "/generated/features" }

    /// Default-on: SwiftUI music + control panels with motion. Disable → SketchyBar popups.
    static var animatedPanels: Bool { !FileManager.default.fileExists(atPath: root + "/disable-animated-panels") }

    /// Opt-in SketchyBar popup path during transition (`veil feature enable sketchybar-popups`).
    static var sketchybarPopups: Bool {
        FileManager.default.fileExists(atPath: root + "/enable-sketchybar-popups")
            || !animatedPanels
    }

    /// Default-on custom Veil status bar. Disable → keep SketchyBar as the strip.
    static var veilBar: Bool { !FileManager.default.fileExists(atPath: root + "/disable-veil-bar") }
}

// MARK: - Window thumbnails (ScreenCaptureKit; falls back to app icons)

struct WinThumb: Identifiable, Hashable {
    var id: CGWindowID
    var app: String
    var title: String
    var bundle: String?
}

func riftWindowsDetailed(_ list: [[String: Any]]) -> [Int: [WinThumb]] {
    var out: [Int: [WinThumb]] = [:]
    for ws in list {
        guard let i = ws["index"] as? Int else { continue }
        out[i] = ((ws["windows"] as? [[String: Any]]) ?? []).compactMap { w -> WinThumb? in
            let sid = (w["window_server_id"] as? Int).map { CGWindowID($0) }
                ?? (w["id"] as? [String: Any]).flatMap { $0["idx"] as? Int }.map { CGWindowID($0) }
            guard let sid else { return nil }
            return WinThumb(
                id: sid,
                app: w["app_name"] as? String ?? "?",
                title: w["title"] as? String ?? "",
                bundle: w["bundle_id"] as? String
            )
        }
    }
    return out
}

enum WindowCapture {
    static func image(for windowID: CGWindowID, maxSide: CGFloat = 200) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else { return nil }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            let scale = max(window.frame.width, window.frame.height) > 0
                ? min(1, maxSide / max(window.frame.width, window.frame.height))
                : 0.25
            config.width = max(2, Int(window.frame.width * scale))
            config.height = max(2, Int(window.frame.height * scale))
            config.showsCursor = false
            config.captureResolution = .best
            let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            return img
        } catch {
            return nil
        }
    }

    static func appIcon(bundle: String?, app: String) -> NSImage {
        if let bundle, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: app) ?? NSImage()
    }
}

// MARK: - Overview card with live window previews

struct OverviewWindowStrip: View {
    let thumbs: [WinThumb]
    let palette: Palette
    @State private var images: [CGWindowID: NSImage] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if thumbs.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette["bg_dark"].opacity(0.55))
                    Text("Empty")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette["dim"])
                }
                .frame(height: 88)
            } else {
                GeometryReader { geo in
                    let count = min(thumbs.count, 4)
                    let gap: CGFloat = 6
                    let w = max(40, (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
                    HStack(spacing: gap) {
                        ForEach(thumbs.prefix(count)) { thumb in
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(palette["bg_dark"])
                                if let img = images[thumb.id] {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: w, height: geo.size.height)
                                        .clipped()
                                        .transition(reduceMotion ? .identity : .opacity)
                                } else {
                                    Image(nsImage: WindowCapture.appIcon(bundle: thumb.bundle, app: thumb.app))
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .frame(width: w, height: geo.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(palette["border"].opacity(0.7), lineWidth: 1)
                            )
                            .accessibilityLabel("\(thumb.app)\(thumb.title.isEmpty ? "" : ": \(thumb.title)")")
                        }
                    }
                }
                .frame(height: 88)
            }
        }
        .task(id: thumbs.map(\.id)) {
            await load()
        }
    }

    private func load() async {
        await withTaskGroup(of: (CGWindowID, NSImage?).self) { group in
            for thumb in thumbs.prefix(4) {
                group.addTask {
                    let img = await WindowCapture.image(for: thumb.id)
                    return (thumb.id, img)
                }
            }
            for await (id, img) in group {
                if let img {
                    await MainActor.run {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            images[id] = img
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Animated panel host (music + control)

enum VeilPanelKind: String { case music, control, keys }

@MainActor
final class VeilPanelHost: ObservableObject {
    static let shared = VeilPanelHost()
    @Published var kind: VeilPanelKind?
    @Published var musicTitle = "Nothing playing"
    @Published var musicArtist = ""
    @Published var musicSource = "Now playing"
    @Published var playing = false
    @Published var statusLine = ""
    private var window: NSWindow?
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func toggle(_ k: VeilPanelKind) {
        if kind == k { dismiss(); return }
        present(k)
    }

    func present(_ k: VeilPanelKind) {
        if VeilFeature.sketchybarPopups {
            // Caller should use SketchyBar; keep host quiet.
            dismiss()
            return
        }
        kind = k
        ensureWindow()
        refreshContent()
        guard let window else { return }
        window.alphaValue = reduceMotion ? 1 : 0
        window.orderFrontRegardless()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
    }

    func dismiss() {
        guard let window, window.isVisible else { kind = nil; return }
        if reduceMotion {
            window.orderOut(nil)
            kind = nil
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.14
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    window.orderOut(nil)
                    self?.kind = nil
                }
            })
        }
    }

    private func ensureWindow() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width: CGFloat = 340
        let height: CGFloat = kind == .control ? 420 : 210
        let x = screen.visibleFrame.maxX - width - 16
        let y = screen.visibleFrame.maxY - height - 12
        let frame = NSRect(x: x, y: y, width: width, height: height)
        if let window {
            window.setFrame(frame, display: true)
            window.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
            return
        }
        let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.hidesOnDeactivate = false
        w.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
        window = w
    }

    func refreshContent() {
        switch kind {
        case .music: loadMusic()
        case .control: loadStatus()
        case .keys: break
        case nil: break
        }
        if let window {
            let height: CGFloat = kind == .control ? 420 : (kind == .keys ? 360 : 210)
            var f = window.frame
            f.size.height = height
            if let screen = window.screen ?? NSScreen.main {
                f.origin.y = screen.visibleFrame.maxY - height - 12
            }
            window.setFrame(f, display: true)
            window.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
        }
    }

    private func loadMusic() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-lc", #""$HOME/.config/sketchybar/plugins/veil.sh" music snapshot 2>/dev/null || true"#]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        // Prefer media-control JSON if present
        let mc = Process()
        mc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        mc.arguments = ["media-control", "get"]
        let mcp = Pipe()
        mc.standardOutput = mcp
        mc.standardError = FileHandle.nullDevice
        if (try? mc.run()) != nil {
            let data = mcp.fileHandleForReading.readDataToEndOfFile()
            mc.waitUntilExit()
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                musicTitle = (obj["title"] as? String)?.nilIfEmpty ?? "Nothing playing"
                musicArtist = (obj["artist"] as? String) ?? ""
                musicSource = (obj["bundleIdentifier"] as? String)?.split(separator: ".").last.map(String.init) ?? "Now playing"
                playing = (obj["playing"] as? Bool) ?? ((obj["playbackRate"] as? Double).map { $0 > 0 } ?? false)
                return
            }
        }
        _ = p
        musicTitle = "Nothing playing"
        musicArtist = ""
        musicSource = "Now playing"
        playing = false
    }

    private func loadStatus() {
        let quiet = FileManager.default.fileExists(atPath: ncRoot + "/generated/quiet")
        let motionOff = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var parts = ["CPU · MEM · VOL"]
        if quiet { parts.append("QUIET") }
        if motionOff { parts.append("MOTION OFF") }
        statusLine = parts.joined(separator: "  ·  ")
    }

    func musicAction(_ action: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-lc", "\"$HOME/.config/sketchybar/plugins/veil.sh\" music \(action)"]
        try? p.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.loadMusic() }
    }

    func runVeil(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: home + "/.local/bin/veil")
        p.arguments = args
        try? p.run()
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct VeilPanelView: View {
    @ObservedObject var host: VeilPanelHost
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var p: Palette { Palette.load() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch host.kind {
            case .music: musicBody
            case .control: controlBody
            case .keys: keysBody
            case nil: EmptyView()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(p["bg_float"].opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p["border"], lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: reduceMotion ? 0 : 18, y: 8)
        )
        .scaleEffect(host.kind == nil ? 0.96 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: host.kind)
        .pressable()
    }

    private var musicBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(host.musicSource.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(p["cyan"])
            Text(host.musicTitle)
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundStyle(p["fg"])
                .lineLimit(2)
            if !host.musicArtist.isEmpty {
                Text(host.musicArtist)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(p["dim"])
            }
            HStack(spacing: 10) {
                panelButton("backward.fill") { host.musicAction("previous") }
                panelButton(host.playing ? "pause.fill" : "play.fill") { host.musicAction("playpause") }
                panelButton("forward.fill") { host.musicAction("next") }
                Spacer()
                Button("Close") { host.dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(p["comment"])
                    .pressable()
            }
            .padding(.top, 4)
        }
    }

    private var controlBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(p.cased("Controls"))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(p["yellow"])
            Text(host.statusLine)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(p["dim"])
            Divider().overlay(p["border"])
            controlRow("Workspace Overview", "rectangle.grid.2x2") { host.runVeil(["overview"]) }
            controlRow("Theme gallery", "paintpalette") { host.runVeil(["themes"]) }
            controlRow("Launcher", "magnifyingglass") { host.runVeil(["launch"]) }
            controlRow("Terminal", "terminal") { host.runVeil(["term"]) }
            controlRow("Monitor", "waveform.path.ecg") { host.runVeil(["btop"]) }
            controlRow("Show menu bar", "menubar.rectangle") {
                VeilBarController.shared.revealMenuBar()
                host.dismiss()
            }
            controlRow("Quiet mode", "leaf") { host.runVeil(["toggle-quiet"]) }
            controlRow("Reload", "arrow.clockwise") { host.runVeil(["reload"]) }
            Spacer(minLength: 0)
            Button("Close") { host.dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(p["comment"])
                .pressable()
        }
    }

    private var keysBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHORTCUTS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(p["yellow"])
            ForEach([
                ("⌘ Space", "Launcher"),
                ("⌃⌥M", "Overview"),
                ("⌃⌥T", "Themes"),
                ("⌥ 1–5", "Workspace"),
                ("Esc", "Dismiss"),
            ], id: \.0) { key, label in
                HStack {
                    Text(key).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(p["cyan"])
                        .frame(width: 88, alignment: .leading)
                    Text(label).font(.system(size: 12)).foregroundStyle(p["fg"])
                    Spacer()
                }
            }
            Spacer(minLength: 0)
            Button("Close") { host.dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(p["comment"])
                .pressable()
        }
    }

    private func controlRow(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(p["cyan"]).frame(width: 18)
                Text(title).foregroundStyle(p["fg"])
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(p["surface"].opacity(0.65)))
        }
        .buttonStyle(.plain)
        .pressable()
    }

    private func panelButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(p["fg"])
                .frame(width: 40, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(p["surface"]))
        }
        .buttonStyle(.plain)
        .pressable()
    }
}

/// NSHostingView that ignores hits on fully transparent pixels so the Dock / desktop stay clickable between islands.
final class PassThroughHost<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        // Only swallow events that land on a real subview (buttons), not empty root chrome.
        if hit === self { return nil }
        return hit
    }
}

// MARK: - Custom Veil status bar (replaces SketchyBar when enabled)

@MainActor
final class VeilBarController: ObservableObject {
    static let shared = VeilBarController()
    @Published var workspaces: [(index: Int, name: String, active: Bool)] = []
    @Published var chip = "UMBRA"
    @Published var clock = ""
    @Published var musicGlyphPlaying = false
    private var window: NSWindow?
    private var clockTimer: Timer?
    private var workspaceTimer: Timer?
    private var lastWSSignature = ""
    private var barOnBottom = false
    private let clockFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE h:mm a"
        return f
    }()

    func start() {
        guard VeilFeature.veilBar, !veilIsOff else { stop(); return }
        reload(forceLayout: true)
        clockTimer?.invalidate()
        workspaceTimer?.invalidate()
        // Clock only needs minute resolution — avoid 2Hz Process storms.
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickClock() }
        }
        workspaceTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshWorkspaces() }
        }
        // Hide SketchyBar strip while VeilBar owns the chrome (agent stays alive for fallback).
        if !VeilFeature.sketchybarPopups {
            sketchybarHidden(true)
        }
    }

    func stop() {
        clockTimer?.invalidate(); clockTimer = nil
        workspaceTimer?.invalidate(); workspaceTimer = nil
        window?.orderOut(nil); window = nil
        lastWSSignature = ""
        sketchybarHidden(false)
    }

    private func sketchybarHidden(_ hidden: Bool) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
        p.arguments = ["--bar", hidden ? "hidden=on" : "hidden=off"]
        try? p.run()
    }

    func reload(forceLayout: Bool = false) {
        let p = Palette.load()
        let nextChip = p.s("chip_label", "VEIL")
        if chip != nextChip { chip = nextChip }
        barOnBottom = p.s("bar_position", "top") == "bottom"
        tickClock()
        refreshWorkspaces()
        ensureWindow(force: forceLayout)
    }

    private func tickClock() {
        let next = clockFmt.string(from: Date())
        if clock != next { clock = next }
    }

    private func refreshWorkspaces() {
        let p = Palette.load()
        let paletteWS = p.s("ws", "NET CODE COMMS MEDIA FREE").split(separator: " ").map(String.init)
        // Prefer theme.toml / launcher.json — skip SketchyBar queries while its strip is hidden.
        let fromTheme = themeTomlWorkspaceNames()
        let names: [String]
        if fromTheme.count >= 5 {
            names = Array(fromTheme.prefix(5))
        } else {
            let fromLauncher = p.s("ws", "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
            names = fromLauncher.count >= 5 ? Array(fromLauncher.prefix(5)) : liveWorkspaceNames(paletteWS: paletteWS)
        }
        let list = riftWorkspaces()
        let active = list.first(where: { ($0["is_active"] as? Bool) == true })?["index"] as? Int ?? 0
        let sig = names.joined(separator: "|") + "#\(active)"
        guard sig != lastWSSignature else { return }
        lastWSSignature = sig
        workspaces = names.enumerated().map { i, n in (i, n, i == active) }
    }

    /// Below the macOS menu bar so autohide reveal + Apple/app menus stay usable (statusWindow is above the menu).
    private static var barLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 1)
    }

    private func ensureWindow(force: Bool = false) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let h: CGFloat = 34
        // Bottom themes (Umbra): above the Dock via visibleFrame (tracks Dock height +
        // autohide), plus a small air gap so floating Dock icons aren't clipped.
        // Top themes keep the screen edge under menu-bar level so mouse→top still
        // reveals Apple/app menus above us.
        // Clear the Dock shelf plus icon heads (visibleFrame alone sits flush on the shelf).
        let dockGap: CGFloat = barOnBottom ? 22 : 0
        let frame: NSRect = barOnBottom
            ? NSRect(x: screen.visibleFrame.minX,
                     y: screen.visibleFrame.minY + dockGap,
                     width: screen.visibleFrame.width, height: h)
            : NSRect(x: screen.frame.minX, y: screen.frame.maxY - h, width: screen.frame.width, height: h)
        if window == nil {
            let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.level = Self.barLevel
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            w.isReleasedWhenClosed = false
            w.hidesOnDeactivate = false
            // Pass clicks through clear gaps between islands (SketchyBar-style).
            w.contentView = PassThroughHost(rootView: VeilBarView(bar: self))
            window = w
            w.setFrame(frame, display: true)
            w.orderFrontRegardless()
            return
        }
        window?.level = Self.barLevel
        if force || window?.frame != frame {
            window?.setFrame(frame, display: true)
        }
        window?.orderFrontRegardless()
    }

    /// Temporarily show the stock macOS menu bar (autohide off), then restore Veil's preference.
    func revealMenuBar(seconds: TimeInterval = 12) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"System Events\" to tell dock preferences to set autohide menu bar to false"]
        try? p.run()
        if let screen = NSScreen.main {
            CGWarpMouseCursorPosition(CGPoint(x: screen.frame.midX, y: 0))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard !veilIsOff else { return }
            let restore = Process()
            restore.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            restore.arguments = ["-e", "tell application \"System Events\" to tell dock preferences to set autohide menu bar to true"]
            try? restore.run()
        }
    }
}

struct VeilBarView: View {
    @ObservedObject var bar: VeilBarController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var p: Palette { Palette.load() }
    /// Match SketchyBar: Umbra uses floating islands over a clear bar, not a full-bleed strip.
    private var islands: Bool { p.s("bar_layout", "strip") == "islands" }

    var body: some View {
        HStack(spacing: 10) {
            island {
                chipButton
            }
            if islands { Spacer(minLength: 8) }
            island {
                HStack(spacing: 6) {
                    ForEach(bar.workspaces, id: \.index) { ws in workspaceButton(ws) }
                }
            }
            Spacer(minLength: 8)
            island {
                HStack(spacing: 6) {
                    Button { animateClick { VeilPanelHost.shared.toggle(.music) } } label: {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(p["fg"])
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain).pressable()
                    Button { animateClick { VeilPanelHost.shared.toggle(.keys) } } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(p["dim"])
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain).pressable()
                    Text(bar.clock)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(p["fg"])
                        .padding(.trailing, 4)
                }
            }
        }
        .padding(.horizontal, islands ? 12 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(islands ? Color.clear : p["bg_dark"].opacity(0.92))
    }

    private var chipButton: some View {
        Button {
            animateClick {
                if NSEvent.modifierFlags.contains(.option) {
                    bar.revealMenuBar()
                } else {
                    VeilPanelHost.shared.toggle(.control)
                }
            }
        } label: {
            Text(bar.chip)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).strokeBorder(p["cyan"].opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressable()
        .help("Control panel · ⌥-click shows the macOS menu bar")
    }

    private func workspaceButton(_ ws: (index: Int, name: String, active: Bool)) -> some View {
        Button {
            animateClick {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: home + "/.local/bin/rift-cli")
                proc.arguments = ["execute", "workspace", "switch", "\(ws.index)"]
                try? proc.run()
            }
        } label: {
            Text(ws.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(ws.active ? p["cyan"] : p["border"].opacity(0.5), lineWidth: ws.active ? 1.5 : 1)
                )
                .foregroundStyle(ws.active ? p["fg"] : p["dim"])
        }
        .buttonStyle(.plain)
        .pressable()
    }

    @ViewBuilder
    private func island<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if islands {
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(p["bg_dark"].opacity(0.88))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(p["border"].opacity(0.55), lineWidth: 1))
                )
        } else {
            content()
        }
    }

    private func animateClick(_ action: @escaping () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { action() }
        }
    }
}
