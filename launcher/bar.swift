import AppKit
import Darwin
import Combine
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

    /// Default-on thin in-process strip. Disable → SketchyBar: `veil feature disable veil-bar`.
    /// Matches bin/veil (`disable-veil-bar`); unify retires the SketchyBar LaunchAgent.
    static var veilBar: Bool { !FileManager.default.fileExists(atPath: root + "/disable-veil-bar") }

    /// Default-on live window thumbs for the selected Overview card (out-of-process SCK).
    static var overviewLiveThumbs: Bool { !FileManager.default.fileExists(atPath: root + "/disable-overview-live-thumbs") }

    /// Opt-in: force the Reduce Motion still-path (panels appear/dismiss without fade).
    static var forceReduceMotion: Bool { FileManager.default.fileExists(atPath: root + "/enable-force-reduce-motion") }

    /// Opt-in idle theme companion (VEI-40) — never ScreenSaverEngine.
    static var saverCompanion: Bool { FileManager.default.fileExists(atPath: root + "/enable-saver-companion") }

    /// Opt-in window-server chrome experiments (VEI-41) — thicker focus ring / soft halo.
    static var wsChrome: Bool { FileManager.default.fileExists(atPath: root + "/enable-ws-chrome") }
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
    /// Capture via short-lived `veil-thumbs` so ScreenCaptureKit RSS dies with the helper.
    static func images(for ids: [CGWindowID], maxSide: CGFloat = 96) async -> [CGWindowID: NSImage] {
        _ = maxSide
        guard !ids.isEmpty, !Task.isCancelled else { return [:] }
        let helper = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/veil-thumbs").path
        let bin = FileManager.default.isExecutableFile(atPath: helper)
            ? helper
            : (home + "/.local/bin/veil-thumbs")
        guard FileManager.default.isExecutableFile(atPath: bin) else { return [:] }
        let outDir = NSTemporaryDirectory() + "veil-thumbs-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: outDir) }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = [outDir] + ids.map { String($0) }
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            while proc.isRunning {
                if Task.isCancelled {
                    proc.terminate()
                    break
                }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            proc.waitUntilExit()
        } catch {
            return [:]
        }
        guard !Task.isCancelled else { return [:] }
        var out: [CGWindowID: NSImage] = [:]
        out.reserveCapacity(ids.count)
        for id in ids {
            let path = (outDir as NSString).appendingPathComponent("\(id).png")
            if let img = NSImage(contentsOfFile: path) { out[id] = img }
        }
        return out
    }

    static func appIcon(bundle: String?, app: String) -> NSImage {
        // Route through IconCache so Overview does not retain full multi-rep workspace icons.
        if let bundle, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            return IconCache.icon(url.path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) {
            return IconCache.icon(url.path)
        }
        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: app) ?? NSImage()
    }
}

// MARK: - Overview card with live window previews

struct OverviewWindowStrip: View {
    let thumbs: [WinThumb]
    let palette: Palette
    /// Live ScreenCaptureKit only for the selected card — icons everywhere else keeps RSS light.
    var live: Bool = false
    @State private var images: [CGWindowID: NSImage] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var maxThumbs: Int { live ? 2 : 3 }

    var body: some View {
        Group {
            if thumbs.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette["bg_dark"])
                    Text("Empty")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(palette["dim"])
                }
                .frame(height: 64)
            } else {
                GeometryReader { geo in
                    let count = min(thumbs.count, maxThumbs)
                    let gap: CGFloat = 5
                    let w = max(36, (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
                    HStack(spacing: gap) {
                        ForEach(thumbs.prefix(count)) { thumb in
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .frame(width: w, height: geo.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(palette["border"].opacity(0.7), lineWidth: 1)
                            )
                            .accessibilityLabel("\(thumb.app)\(thumb.title.isEmpty ? "" : ": \(thumb.title)")")
                        }
                    }
                }
                .frame(height: 64)
            }
        }
        .task(id: "\(live)-\(thumbs.prefix(maxThumbs).map(\.id))") {
            await load()
        }
        .onDisappear { images = [:] }
        .onChange(of: live) { _, isLive in
            if !isLive { images = [:] }
        }
    }

    private func load() async {
        guard live else {
            await MainActor.run { images = [:] }
            return
        }
        let ids = thumbs.prefix(2).map(\.id)
        let batch = await WindowCapture.images(for: Array(ids), maxSide: 96)
        guard !Task.isCancelled else { return }
        await MainActor.run {
            images = batch
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
    @Published var musicAlbum = ""
    @Published var musicSource = "Now playing"
    @Published var musicArtwork: NSImage?
    @Published var playing = false
    @Published var statusLine = ""
    /// Structured status for desktop Glyph catalog tiles.
    @Published var cpuText = "—"
    @Published var memText = "—"
    @Published var gpuText = "—"
    @Published var batteryText = "—"
    @Published var netText = "Wi‑Fi"
    @Published var volumeText = "—"
    /// Live control-panel toggles (VEI-39).
    @Published var wifiOn = true
    @Published var bluetoothOn = true
    @Published var focusOn = false
    @Published var volumeLevel: Double = 0.5
    @Published var brightnessLevel: Double = 0.7
    @Published var muted = false
    /// Continuity / Bluetooth accessories for large Battery Glyph (VEI-32).
    @Published var batteryDevices: [BatteryDevice] = []
    /// AppKit screen rect of the bar button that opened the panel (nil → resolve from SketchyBar).
    var anchorRect: NSRect?
    private var window: NSWindow?
    private var dismissGeneration = 0
    private var outsideMonitors: [Any] = []
    private var lastMusicFetch = Date.distantPast
    private var lastStatusFetch = Date.distantPast
    private var lastBatteryDevicesFetch = Date.distantPast
    private var lastMusicKey = ""
    private var reduceMotion: Bool {
        VeilFeature.forceReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func toggle(_ k: VeilPanelKind, near anchor: NSRect? = nil) {
        if kind == k { dismiss(); return }
        present(k, near: anchor)
    }

    func present(_ k: VeilPanelKind, near anchor: NSRect? = nil) {
        if VeilFeature.sketchybarPopups {
            // Caller should use SketchyBar; keep host quiet.
            dismiss()
            return
        }
        kind = k
        anchorRect = anchor ?? Self.sketchybarItemRect(for: k) ?? anchorRect
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
        installOutsideClick()
    }

    func dismiss() {
        dismissImmediate(animated: false)
    }

    /// Instant tear-down — never leave a kind=nil hosting view on screen
    /// (VeilPanelView painted chrome around EmptyView → blank bottom-left husk).
    func dismissImmediate(animated: Bool = false) {
        _ = animated // reserved; husks require sync kill
        dismissGeneration &+= 1
        OutsideClick.remove(&outsideMonitors)
        let window = self.window
        kind = nil
        anchorRect = nil
        window?.orderOut(nil)
        window?.contentView = nil
        window?.alphaValue = 1
        self.window = nil
    }

    private func installOutsideClick() {
        OutsideClick.remove(&outsideMonitors)
        let gen = dismissGeneration
        let anchor = anchorRect
        outsideMonitors = OutsideClick.install(
            window: window,
            ignoreUntil: Date().addingTimeInterval(0.4),
            extraSafeFrames: {
                var frames: [NSRect] = []
                if let anchor { frames.append(anchor.insetBy(dx: -8, dy: -8)) }
                if let bar = VeilBarController.shared.barWindowFrame { frames.append(bar) }
                return frames
            },
            onOutside: { [weak self] in
                guard let self, self.dismissGeneration == gen else { return }
                GlyphShell.shared.dismiss()
                self.dismissImmediate()
            }
        )
    }

    /// Prefer in-process Veil bar anchors when that strip owns chrome (SketchyBar parks
    /// `bounding_rects` at -9999 while `hidden=on`, which previously threw panels off-screen).
    static func sketchybarItemRect(for kind: VeilPanelKind) -> NSRect? {
        if VeilFeature.veilBar, let r = VeilBarController.shared.itemRect(for: kind) {
            return r
        }
        let item: String
        switch kind {
        case .music: item = "music"
        case .control: item = "city"
        case .keys: item = "keys"
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar")
        if !FileManager.default.isExecutableFile(atPath: p.executableURL!.path) {
            p.executableURL = URL(fileURLWithPath: "/usr/local/bin/sketchybar")
        }
        p.arguments = ["--query", item]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return VeilBarController.shared.itemRect(for: kind) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rects = obj["bounding_rects"] as? [String: Any] else {
            return VeilBarController.shared.itemRect(for: kind)
        }
        // Prefer the display under the mouse; else first rect.
        let mouse = NSEvent.mouseLocation
        var chosen: (origin: [Double], size: [Double])?
        for (_, v) in rects {
            guard let r = v as? [String: Any],
                  let origin = r["origin"] as? [Double], origin.count == 2,
                  let size = r["size"] as? [Double], size.count == 2 else { continue }
            // Hidden SketchyBar parks items at (-9999,-9999) — ignore.
            if origin[0] < -1000 || origin[1] < -1000 { continue }
            if chosen == nil { chosen = (origin, size) }
            if abs(origin[0] + size[0] / 2 - mouse.x) < 400 { chosen = (origin, size); break }
        }
        guard let chosen else { return VeilBarController.shared.itemRect(for: kind) }
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main ?? NSScreen.screens[0]
        // SketchyBar Y is measured downward from the top of the display.
        let x = screen.frame.minX + chosen.origin[0]
        let y = screen.frame.maxY - chosen.origin[1] - chosen.size[1]
        return NSRect(x: x, y: y, width: chosen.size[0], height: chosen.size[1])
    }

    private func panelSize() -> (CGFloat, CGFloat) {
        let width: CGFloat
        let height: CGFloat
        switch kind {
        case .control: width = 360; height = 520
        case .keys: width = 340; height = 360
        // Compact: content-sized — avoid sparse empty chrome under the track row.
        case .music: width = 288; height = musicArtwork == nil ? 148 : 168
        case nil: width = 1; height = 1 // unused — ensureWindow refuses nil kind
        }
        return (width, height)
    }

    /// Place the panel beside the bar button: above a bottom bar, below a top bar; X centered on the button.
    private func frameNearAnchor(width: CGFloat, height: CGFloat) -> NSRect {
        let screen = NSScreen.screens.first(where: {
            if let a = anchorRect { return a.intersects($0.frame) }
            return NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main ?? NSScreen.screens[0]
        let gap: CGFloat = 8
        let barBottom = Palette.load().s("bar_position", "top") == "bottom"
        let anchor = anchorRect ?? {
            // Fallback: mouse X on the bar edge.
            let m = NSEvent.mouseLocation
            let y = barBottom ? screen.visibleFrame.minY : screen.visibleFrame.maxY - 28
            return NSRect(x: m.x - 12, y: y, width: 24, height: 28)
        }()
        var x = anchor.midX - width / 2
        x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
        if barBottom {
            // Open above the button when the bar is at the bottom.
            let above = anchor.minY - gap - height
            return NSRect(x: x, y: max(above, screen.visibleFrame.minY + 4), width: width, height: height)
        } else {
            // Open below the button when the bar is at the top.
            let below = anchor.maxY + gap
            return NSRect(x: x, y: min(below, screen.visibleFrame.maxY - height - 4), width: width, height: height)
        }
    }

    private func ensureWindow() {
        // Never materialize a panel with no kind — that was the blank bottom-left husk.
        guard kind != nil else {
            dismissImmediate(animated: false)
            return
        }
        let (width, height) = panelSize()
        let frame = frameNearAnchor(width: width, height: height)
        if let window {
            window.setFrame(frame, display: true)
            window.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
            return
        }
        let w = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false // no soft shadow bleed past opaque Glyph panel
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.hidesOnDeactivate = false
        w.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
        window = w
    }

    func refreshContent() {
        guard kind != nil else { dismiss(); return }
        switch kind {
        case .music: loadMusic(fetchArtwork: true, force: true)
        case .control:
            ensureStatusMeta(force: true)
            refreshControlToggles()
        case .keys: break
        case nil: break
        }
        if let window {
            let (width, height) = panelSize()
            let frame = frameNearAnchor(width: width, height: height)
            window.setFrame(frame, display: true)
            window.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
        }
    }

    /// Glyph / desktop surfaces: metadata only by default. Artwork fetch is reserved for the open music panel.
    func ensureMusicMeta(artwork: Bool = false) {
        loadMusic(fetchArtwork: artwork, force: false)
    }

    /// Sys Glyph / control panel: veil-metrics + volume — debounced so a 60s tick cannot stack Process storms.
    func ensureStatusMeta(force: Bool = false) {
        if !force, Date().timeIntervalSince(lastStatusFetch) < 20 { return }
        lastStatusFetch = Date()
        loadStatus()
        refreshControlToggles()
    }

    /// Snapshot Wi‑Fi / BT / Focus / volume / brightness for live control chrome.
    func refreshControlToggles() {
        DispatchQueue.global(qos: .userInitiated).async {
            let wifi = SystemControls.wifiOn
            let bt = SystemControls.bluetoothOn
            let focus = SystemControls.focusOn
            let vol = SystemControls.volumeLevel() ?? 0.5
            let muted = SystemControls.isMuted()
            let bright = Double(Brightness.get() ?? 0.7)
            DispatchQueue.main.async {
                self.wifiOn = wifi
                self.bluetoothOn = bt
                self.focusOn = focus
                self.volumeLevel = vol
                self.muted = muted
                self.brightnessLevel = bright
                self.volumeText = muted ? "MUTE" : "\(Int((vol * 100).rounded()))%"
            }
        }
    }

    func toggleWifi() {
        DispatchQueue.global(qos: .userInitiated).async {
            let on = SystemControls.toggleWifi()
            DispatchQueue.main.async {
                self.wifiOn = on
                self.netText = on ? "Wi‑Fi" : "Wi‑Fi off"
            }
        }
    }

    func toggleBluetooth() {
        DispatchQueue.global(qos: .userInitiated).async {
            let on = SystemControls.toggleBluetooth()
            DispatchQueue.main.async { self.bluetoothOn = on }
        }
    }

    func toggleFocus() {
        DispatchQueue.global(qos: .userInitiated).async {
            let on = SystemControls.enableDoNotDisturb()
            DispatchQueue.main.async { self.focusOn = on }
        }
    }

    /// Control Focus tile — turn Do Not Disturb on (not a Settings husk).
    func enableDoNotDisturb() {
        DispatchQueue.global(qos: .userInitiated).async {
            let on = SystemControls.enableDoNotDisturb()
            DispatchQueue.main.async { self.focusOn = on }
        }
    }

    func openDisplays() { SystemControls.openDisplays() }

    func setVolume(_ level: Double) {
        volumeLevel = level
        volumeText = "\(Int((level * 100).rounded()))%"
        DispatchQueue.global(qos: .userInitiated).async {
            SystemControls.setVolume(level)
        }
    }

    func setBrightness(_ level: Double) {
        brightnessLevel = level
        SystemControls.setBrightness(level)
    }

    func toggleMute() {
        DispatchQueue.global(qos: .userInitiated).async {
            SystemControls.toggleMute()
            let muted = SystemControls.isMuted()
            let vol = SystemControls.volumeLevel() ?? 0
            DispatchQueue.main.async {
                self.muted = muted
                self.volumeLevel = vol
                self.volumeText = muted ? "MUTE" : "\(Int((vol * 100).rounded()))%"
            }
        }
    }

    /// Open the launcher theme gallery (not the Style creator — that is ⌃⌥Y / Glyph Style).
    func openThemeGallery() {
        runVeil(["themes"])
    }

    private func loadMusic(fetchArtwork: Bool = true, force: Bool = false) {
        // Debounce idle callers (desktop Glyph tick). Open panel always refreshes.
        if !force, !fetchArtwork, Date().timeIntervalSince(lastMusicFetch) < 15 { return }
        lastMusicFetch = Date()
        // Metadata first (cheap); artwork in a second call so the panel can paint title immediately.
        applyMusicMetadata(from: mediaControlJSON(noArtwork: true))
        if musicTitle == "Nothing playing" {
            applyMusicSnapshotFallback()
        }
        let key = "\(musicTitle)|\(musicArtist)|\(playing)"
        let titleUnchanged = key == lastMusicKey
        lastMusicKey = key
        guard fetchArtwork else {
            // Cheap path: reuse disk cache when title matches; never spawn the artwork retry storm.
            if musicArtwork == nil, titleUnchanged || musicTitle != "Nothing playing",
               let img = NSImage(contentsOfFile: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg") {
                musicArtwork = img
            }
            return
        }
        // Skip artwork Process loop when we already have art for this track.
        if titleUnchanged, musicArtwork != nil { return }
        // Artwork off the main hot path. Cider often omits artworkData on the first get —
        // retry, and persist a JPEG cache so the panel can load from disk on the main thread.
        let expectedTitle = musicTitle
        let cacheURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var wrote = false
            for attempt in 0..<4 {
                if let obj = Self.mediaControlJSONSync(noArtwork: false),
                   let raw = obj["artworkData"] as? String, raw.count > 200,
                   let data = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]) {
                    try? data.write(to: cacheURL, options: .atomic)
                    wrote = true
                    break
                }
                if attempt < 3 { Thread.sleep(forTimeInterval: 0.35) }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if wrote, let img = NSImage(contentsOf: cacheURL) {
                    self.musicArtwork = img
                } else if self.musicTitle != expectedTitle {
                    self.musicArtwork = nil
                }
                if self.kind == .music { self.ensureWindow() }
                else if self.kind == nil { self.dismissImmediate(animated: false) }
            }
        }
    }

    private func applyMusicMetadata(from obj: [String: Any]?) {
        guard let obj,
              let title = (obj["title"] as? String)?.nilIfEmpty ?? (obj["name"] as? String)?.nilIfEmpty else {
            return
        }
        musicTitle = title
        musicArtist = (obj["artist"] as? String) ?? (obj["artistName"] as? String) ?? ""
        musicAlbum = (obj["album"] as? String) ?? (obj["albumName"] as? String) ?? ""
        let bundle = (obj["bundleIdentifier"] as? String) ?? (obj["bundleID"] as? String) ?? ""
        musicSource = bundle.split(separator: ".").last.map(String.init)
            ?? (obj["displayName"] as? String) ?? "Now playing"
        if bundle.lowercased().contains("cider") { musicSource = "Cider" }
        playing = (obj["playing"] as? Bool)
            ?? (obj["isPlaying"] as? Bool)
            ?? ((obj["playbackRate"] as? Double).map { $0 > 0 } ?? false)
    }

    private func applyMusicSnapshotFallback() {
        let snap = Process()
        snap.executableURL = URL(fileURLWithPath: "/bin/bash")
        snap.arguments = ["-lc", #""$HOME/.config/sketchybar/plugins/veil.sh" music snapshot 2>/dev/null || true"#]
        let pipe = Pipe()
        snap.standardOutput = pipe
        snap.standardError = FileHandle.nullDevice
        if (try? snap.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            snap.waitUntilExit()
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = (obj["title"] as? String)?.nilIfEmpty {
                musicTitle = title
                musicArtist = (obj["artist"] as? String) ?? ""
                musicAlbum = (obj["album"] as? String) ?? ""
                musicSource = (obj["source"] as? String)?.nilIfEmpty ?? "Now playing"
                playing = (obj["state"] as? String) == "playing"
                return
            }
        }
        musicTitle = "Nothing playing"
        musicArtist = ""
        musicAlbum = ""
        musicSource = "Now playing"
        musicArtwork = nil
        playing = false
    }

    private func mediaControlJSON(noArtwork: Bool) -> [String: Any]? {
        Self.mediaControlJSONSync(noArtwork: noArtwork)
    }

    nonisolated private static func mediaControlJSONSync(noArtwork: Bool) -> [String: Any]? {
        let mc = Process()
        mc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        mc.arguments = noArtwork ? ["media-control", "get", "--no-artwork"] : ["media-control", "get"]
        let mcp = Pipe()
        mc.standardOutput = mcp
        mc.standardError = FileHandle.nullDevice
        guard (try? mc.run()) != nil else { return nil }
        let data = mcp.fileHandleForReading.readDataToEndOfFile()
        mc.waitUntilExit()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    nonisolated private static func decodeArtwork(from obj: [String: Any]?) -> NSImage? {
        guard let raw = obj?["artworkData"] as? String, !raw.isEmpty,
              let data = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]),
              let img = NSImage(data: data) else { return nil }
        // Decode off-main; SwiftUI `.resizable()` scales for the 72pt tile (no AppKit lockFocus).
        return img
    }

    private func loadStatus() {
        let quiet = FileManager.default.fileExists(atPath: ncRoot + "/generated/quiet")
        let motionOff = VeilFeature.forceReduceMotion
            || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var cpu = "?", mem = "?", vol = "?"
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
            if bits.count >= 2 { cpu = bits[0]; mem = bits[1] }
        }
        let vp = Process()
        vp.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        vp.arguments = ["-e", "if output muted of (get volume settings) then return \"MUTE\"",
                        "-e", "return (output volume of (get volume settings) as text) & \"%\""]
        let vpPipe = Pipe()
        vp.standardOutput = vpPipe
        vp.standardError = FileHandle.nullDevice
        if (try? vp.run()) != nil {
            vol = String(data: vpPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
            vp.waitUntilExit()
        }
        cpuText = cpu == "?" ? "—" : "\(cpu)%"
        memText = mem == "?" ? "—" : "\(mem)G"
        volumeText = vol
        gpuText = "—" // discrete GPU counter rarely exposed on Apple silicon
        netText = "Wi‑Fi"
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
                batteryText = String(bout[match])
            } else {
                batteryText = "—"
            }
        }
        refreshBatteryDevices(force: false)
        var parts = ["CPU \(cpuText)", "MEM \(memText)", "VOL \(volumeText)"]
        if quiet { parts.append("QUIET") }
        if motionOff { parts.append("MOTION OFF") }
        statusLine = parts.joined(separator: "  ·  ")
    }

    /// Mac + BT/Continuity accessories (AirPods, Watch, iPhone when levels exist).
    func refreshBatteryDevices(force: Bool = false) {
        if !force, Date().timeIntervalSince(lastBatteryDevicesFetch) < 45 { return }
        lastBatteryDevicesFetch = Date()
        let macLevel = Int(batteryText.filter(\.isNumber))
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var devices: [BatteryDevice] = [
                BatteryDevice(id: "mac", name: Host.current().localizedName ?? "Mac",
                              kind: .mac, level: macLevel, detail: nil)
            ]
            devices.append(contentsOf: Self.parseBluetoothBatteries())
            // Prefer devices with a known level; keep a few named peers without levels last.
            devices.sort { a, b in
                switch (a.level != nil, b.level != nil) {
                case (true, false): return true
                case (false, true): return false
                default:
                    if a.kind.sortRank != b.kind.sortRank { return a.kind.sortRank < b.kind.sortRank }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
            DispatchQueue.main.async { self?.batteryDevices = devices }
        }
    }

    nonisolated private static func parseBluetoothBatteries() -> [BatteryDevice] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-xml"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]],
              let first = root.first,
              let items = first["_items"] as? [[String: Any]] else { return [] }

        var out: [BatteryDevice] = []
        var seen = Set<String>()

        func ingest(dict: [String: Any], nameFallback: String) {
            let name = (dict["device_name"] as? String)
                ?? (dict["device_minorType"] as? String)
                ?? nameFallback
            let addr = (dict["device_address"] as? String) ?? name
            guard !seen.contains(addr) else { return }

            let left = Self.percent(dict["device_batteryLevelLeft"] ?? dict["BatteryPercentLeft"])
            let right = Self.percent(dict["device_batteryLevelRight"] ?? dict["BatteryPercentRight"])
            let caseLvl = Self.percent(dict["device_batteryLevelCase"] ?? dict["BatteryPercentCase"])
            let single = Self.percent(dict["device_batteryLevel"] ?? dict["device_batteryLevelMain"]
                                      ?? dict["BatteryPercent"] ?? dict["Battery"])

            var level = single
            var detail: String?
            if left != nil || right != nil || caseLvl != nil {
                var parts: [String] = []
                if let left { parts.append("L\(left)") }
                if let right { parts.append("R\(right)") }
                if let caseLvl { parts.append("C\(caseLvl)") }
                detail = parts.isEmpty ? nil : parts.joined(separator: " ")
                let vals = [left, right].compactMap { $0 }
                if level == nil, !vals.isEmpty { level = vals.min() }
            }

            let lower = name.lowercased()
            let kind: BatteryDevice.Kind
            if lower.contains("airpods") || lower.contains("buds") || lower.contains("headphone") {
                kind = .buds
            } else if lower.contains("watch") {
                kind = .watch
            } else if lower.contains("iphone") || lower.contains("ipad") {
                kind = .phone
            } else if level == nil && detail == nil {
                return // skip nameless peers with no battery telemetry
            } else {
                kind = .other
            }

            // Skip Find-My ghost buds with no levels.
            if kind == .buds, level == nil, detail == nil { return }
            if kind == .phone, level == nil { return } // Continuity often lists phones without %

            seen.insert(addr)
            out.append(BatteryDevice(id: addr, name: Self.shortName(name), kind: kind, level: level, detail: detail))
        }

        for block in items {
            for key in ["device_connected", "device_not_connected"] {
                // macOS shape: [ { "Device Name": { device_address, device_batteryLevel… } }, … ]
                if let list = block[key] as? [[String: Any]] {
                    for entry in list {
                        for (name, raw) in entry {
                            guard var dict = raw as? [String: Any] else { continue }
                            dict["device_name"] = name
                            ingest(dict: dict, nameFallback: name)
                        }
                    }
                } else if let map = block[key] as? [String: [String: Any]] {
                    for (name, dict) in map { ingest(dict: dict, nameFallback: name) }
                }
            }
        }
        return out
    }

    nonisolated private static func percent(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return min(100, max(0, i)) }
        if let d = raw as? Double { return min(100, max(0, Int(d.rounded()))) }
        if let s = raw as? String {
            let digits = s.filter(\.isNumber)
            if let i = Int(digits) { return min(100, max(0, i)) }
        }
        return nil
    }

    nonisolated private static func shortName(_ name: String) -> String {
        var n = name
        for prefix in ["Mario’s ", "Mario's ", "Aryan’s ", "Aryan's ", "daniel’s ", "daniel's "] {
            if n.hasPrefix(prefix) { n = String(n.dropFirst(prefix.count)); break }
        }
        if n.count > 18 { return String(n.prefix(16)) + "…" }
        return n
    }

    func musicAction(_ action: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-lc", "\"$HOME/.config/sketchybar/plugins/veil.sh\" music \(action)"]
        try? p.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.loadMusic(fetchArtwork: true, force: true)
            if self?.kind == .music { self?.ensureWindow() }
        }
    }

    func runVeil(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: home + "/.local/bin/veil")
        p.arguments = args
        try? p.run()
        dismiss()
    }
}

struct BatteryDevice: Identifiable, Equatable {
    enum Kind: String { case mac, buds, watch, phone, other
        var sortRank: Int {
            switch self {
            case .mac: return 0
            case .buds: return 1
            case .watch: return 2
            case .phone: return 3
            case .other: return 4
            }
        }
        var symbol: String {
            switch self {
            case .mac: return "laptopcomputer"
            case .buds: return "earbuds"
            case .watch: return "applewatch"
            case .phone: return "iphone"
            case .other: return "battery.100"
            }
        }
    }
    var id: String
    var name: String
    var kind: Kind
    var level: Int?
    var detail: String?
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct VeilPanelView: View {
    @ObservedObject var host: VeilPanelHost
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var p: Palette { Palette.load() }

    var body: some View {
        // No chrome when kind is nil — a dismissed/empty host must not paint a blank card.
        Group {
            if let kind = host.kind {
                VStack(alignment: .leading, spacing: 0) {
                    switch kind {
                    case .music: musicBody
                    case .control: controlBody
                    case .keys: keysBody
                    }
                }
                .padding(kind == .music ? 10 : 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .circular)
                        .fill(p["surface"]) // opaque solid — no frosted bleed
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .circular).strokeBorder(p["border"], lineWidth: 1))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .circular))
                .compositingGroup()
                .pressable()
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: host.kind)
    }

    private var musicBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(host.musicSource.uppercased())
                .font(panelFont(10, .bold, mono: true))
                .foregroundStyle(p["cyan"])
            HStack(alignment: .center, spacing: 10) {
                Group {
                    if let art = host.musicArtwork {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .id(ObjectIdentifier(art))
                    } else if let disk = NSImage(contentsOfFile: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg") {
                        Image(nsImage: disk)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        ZStack {
                            p["surface"]
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(p["dim"])
                        }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: themeCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: themeCorner, style: .continuous)
                        .strokeBorder(p["border"].opacity(0.7), lineWidth: 1)
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(host.musicTitle)
                        .font(panelFont(14, .semibold))
                        .foregroundStyle(p["fg"])
                        .lineLimit(2)
                    if !host.musicArtist.isEmpty {
                        Text(host.musicArtist)
                            .font(panelFont(11, .medium))
                            .foregroundStyle(p["dim"])
                            .lineLimit(1)
                    }
                    if !host.musicAlbum.isEmpty {
                        Text(host.musicAlbum)
                            .font(panelFont(10, .medium, mono: true))
                            .foregroundStyle(p["comment"])
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                panelButton("backward.fill") { host.musicAction("previous") }
                panelButton(host.playing ? "pause.fill" : "play.fill") { host.musicAction("playpause") }
                panelButton("forward.fill") { host.musicAction("next") }
                Spacer()
                Button("Close") { host.dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(p["comment"])
                    .pressable()
            }
        }
    }

    private var themeCorner: CGFloat {
        // Match each theme's launcher radius language (Glyph-style round vs Eclipse square).
        let r = p.num("l_radius", 14)
        return max(4, min(r, 22))
    }

    private func panelFont(_ size: CGFloat, _ weight: Font.Weight, mono: Bool = false) -> Font {
        let name = mono ? p.s("ui_mono", "") : p.s("ui_font", "")
        if name.isEmpty {
            return mono
                ? .system(size: size, weight: weight, design: .monospaced)
                : .system(size: size, weight: weight)
        }
        return .custom(name, size: size).weight(weight)
    }

    private var controlBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(p.cased("Controls"))
                    .font(panelFont(12, .bold, mono: true))
                    .foregroundStyle(p["yellow"])
                Spacer()
                Text(host.statusLine)
                    .font(panelFont(10, .medium, mono: true))
                    .foregroundStyle(p["dim"])
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            // One tile per function — no Sound/Network mini-rows (dup volume + settings).
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                controlToggle("Wi‑Fi", host.wifiOn ? "wifi" : "wifi.slash", host.wifiOn,
                              onPrimary: { host.toggleWifi() },
                              onSettings: { SystemControls.openWiFiSettings(); host.dismiss() })
                controlToggle("BT", "wave.3.right", host.bluetoothOn,
                              onPrimary: { host.toggleBluetooth() },
                              onSettings: { SystemControls.openBluetoothSettings(); host.dismiss() })
                controlToggle("Focus", "moon.fill", host.focusOn,
                              onPrimary: { host.enableDoNotDisturb() },
                              onSettings: nil)
                controlToggle("Displays", "display.2", false,
                              onPrimary: { host.openDisplays() },
                              onSettings: nil)
            }
            controlSlider("VOLUME", host.muted ? 0 : host.volumeLevel) { host.setVolume($0) }
            controlSlider("BRIGHTNESS", host.brightnessLevel) { host.setBrightness($0) }
            HStack(spacing: 8) {
                panelButton(host.muted ? "speaker.slash.fill" : "speaker.wave.2.fill") { host.toggleMute() }
                Text(host.muted ? "MUTED" : host.volumeText)
                    .font(panelFont(11, .semibold, mono: true))
                    .foregroundStyle(p["dim"])
                Spacer()
            }
            Divider().overlay(p["border"])
            // Themes → gallery/switcher — Style creator stays ⌃⌥Y / Glyph Style.
            controlRow("Themes", "paintpalette") { host.openThemeGallery() }
            controlRow("Workspace Overview", "rectangle.grid.2x2") { host.runVeil(["overview"]) }
            controlRow("Launcher", "magnifyingglass") { host.runVeil(["launch"]) }
            controlRow("Show menu bar", "menubar.rectangle") {
                VeilBarController.shared.revealMenuBar()
                host.dismiss()
            }
            HStack(spacing: 8) {
                miniRow("Quiet", "leaf") { host.runVeil(["toggle-quiet"]) }
                miniRow("Reload", "arrow.clockwise") { host.runVeil(["reload"]) }
            }
            Spacer(minLength: 0)
            Button("Close") { host.dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(p["comment"])
                .pressable()
        }
        .onAppear { host.refreshControlToggles() }
    }

    private func controlToggle(_ title: String, _ symbol: String, _ on: Bool,
                               onPrimary: @escaping () -> Void,
                               onSettings: (() -> Void)?) -> some View {
        Button(action: onPrimary) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(title.uppercased())
                    .font(panelFont(8, .bold, mono: true))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? p["bg_dark"] : p["fg"])
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? p["yellow"] : p["surface"])
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(p["border"], lineWidth: on ? 0 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .pressable()
        .contextMenu {
            if let onSettings {
                Button("Open \(title) Settings") { onSettings() }
            }
        }
    }

    private func controlSlider(_ label: String, _ value: Double, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(panelFont(9, .bold, mono: true))
                .foregroundStyle(p["dim"])
                .tracking(1.2)
            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: 0...1)
            .tint(p["fg"])
        }
    }

    private func miniRow(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(p["cyan"]).frame(width: 16)
                Text(title).foregroundStyle(p["fg"]).font(panelFont(12, .medium))
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(p["surface"]))
        }
        .buttonStyle(.plain)
        .pressable()
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
            .background(RoundedRectangle(cornerRadius: 8).fill(p["surface"]))
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

/// NSHostingView that ignores hits on empty chrome so the Dock stays clickable between islands.
/// Never return nil for descendant hits — SwiftUI buttons often resolve through the hosting root.
final class PassThroughHost<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if hit === self { return nil }
        // Walk up: if anything under the host is a control-ish view, keep the hit.
        var v: NSView? = hit
        while let cur = v {
            if cur !== self { return hit }
            v = cur.superview
        }
        return nil
    }
}

// MARK: - In-process Veil status bar (SketchyBar-scale; opt-in until screenshot-proven)
//
 // Hard constraints (Big Dawg rejection of prior strip):
 // - Height matches SketchyBar EDGE_H / ISLE_H (36 strip / 34 islands) — never a fat shelf.
 // - Window level is **below Dock** so autohide Dock can cover and receive clicks.
 // - Bottom placement sits on `screen.frame.minY` like SketchyBar (Rift outer gap clears usable space).
 // - Controls must be clickable; strip uses a normal hosting view (pass-through only for islands).

@MainActor
final class VeilBarController: ObservableObject {
    static let shared = VeilBarController()
    @Published var workspaces: [(index: Int, name: String, active: Bool)] = []
    @Published var chip = "VEIL"
    @Published var clockDate = ""
    @Published var clockTime = ""
    @Published var powerLabel = "PWR --%"
    @Published var musicGlyphPlaying = false
    @Published var barLayout = "strip"
    @Published var barOnBottom = false
    @Published var wsStyle = "dot"
    @Published var chipStyle = "outline"
    private var window: NSWindow?
    private var clockTimer: Timer?
    private var workspaceTimer: Timer?
    private var powerTimer: Timer?
    private var lastWSSignature = ""
    private var lastMetaSignature = ""
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE d"; return f
    }()
    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f
    }()

    /// SketchyBar EDGE_H (strip/bare) / ISLE_H (islands) — keep in lockstep with sketchybarrc.
    var barHeight: CGFloat { barLayout == "islands" ? 34 : 36 }

    /// Screen frame of the in-process bar — safe for outside-click (VEI-35).
    var barWindowFrame: NSRect? { window?.isVisible == true ? window?.frame : nil }

    func start() {
        guard VeilFeature.veilBar, !veilIsOff else { stop(); return }
        reload(forceLayout: true)
        clockTimer?.invalidate()
        workspaceTimer?.invalidate()
        powerTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickClock(); self?.tickPower() }
        }
        let ws = Timer(timeInterval: 12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshWorkspaces() }
        }
        ws.tolerance = 4
        RunLoop.main.add(ws, forMode: .common)
        workspaceTimer = ws
        // Hide SketchyBar chrome while we own the strip (LaunchAgent stays for instant fallback).
        if !VeilFeature.sketchybarPopups { sketchybarHidden(true) }
    }

    func stop() {
        clockTimer?.invalidate(); clockTimer = nil
        workspaceTimer?.invalidate(); workspaceTimer = nil
        powerTimer?.invalidate(); powerTimer = nil
        window?.orderOut(nil); window = nil
        lastWSSignature = ""
        lastMetaSignature = ""
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
        // launcher.json ships `brand` (NOTHING); chip_label is SketchyBar-template-only.
        let nextChip = p.s("brand", p.s("chip_label", "VEIL"))
        let nextLayout = p.s("bar_layout", "strip")
        let nextBottom = p.s("bar_position", "top") == "bottom"
        let nextWSStyle = p.s("ws_style", "text")
        let nextChipStyle = p.s("chip_style", "outline")
        let meta = "\(nextChip)|\(nextLayout)|\(nextBottom)|\(nextWSStyle)|\(nextChipStyle)"
        let metaChanged = meta != lastMetaSignature
        if metaChanged {
            lastMetaSignature = meta
            chip = nextChip
            barLayout = nextLayout
            barOnBottom = nextBottom
            wsStyle = nextWSStyle
            chipStyle = nextChipStyle
            // Theme font formats when present (Nothing: %a %d / %H:%M).
            let df = p.s("clock_date", "EEE d")
            let tf = p.s("clock_time", "HH:mm")
            dateFmt.dateFormat = df.hasPrefix("%") ? Self.strftimeToDateFormat(df) : df
            timeFmt.dateFormat = tf.hasPrefix("%") ? Self.strftimeToDateFormat(tf) : tf
        }
        tickClock()
        tickPower()
        refreshWorkspaces()
        ensureWindow(force: forceLayout || metaChanged)
    }

    /// Minimal strftime → DateFormatter bridge for theme.toml clock_* keys.
    private static func strftimeToDateFormat(_ s: String) -> String {
        s.replacingOccurrences(of: "%a", with: "EEE")
            .replacingOccurrences(of: "%A", with: "EEEE")
            .replacingOccurrences(of: "%d", with: "d")
            .replacingOccurrences(of: "%H", with: "HH")
            .replacingOccurrences(of: "%M", with: "mm")
            .replacingOccurrences(of: "%I", with: "h")
            .replacingOccurrences(of: "%p", with: "a")
            .replacingOccurrences(of: "%m", with: "MM")
            .replacingOccurrences(of: "%Y", with: "yyyy")
    }

    private func tickClock() {
        let now = Date()
        let d = dateFmt.string(from: now).uppercased()
        let t = timeFmt.string(from: now)
        if clockDate != d { clockDate = d }
        if clockTime != t { clockTime = t }
    }

    private func tickPower() {
        let s = StateWatch.power()
        let next = "PWR \(Int((s.level * 100).rounded()))%"
        if powerLabel != next { powerLabel = next }
    }

    private func refreshWorkspaces() {
        let p = Palette.load()
        let paletteWS = p.s("ws", "NET CODE COMMS MEDIA FREE").split(separator: " ").map(String.init)
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

    /// **Below Dock** (level 20). Prior bar used mainMenu−1 (23) and stole Dock autohide hits.
    private static var barLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)
    }

    private func ensureWindow(force: Bool = false) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let h = barHeight
        // Match SketchyBar geometry: bottom strip on screen.frame.minY (not visibleFrame+gap).
        // Rift outer insets reserve usable app space; Dock paints above us at a higher level.
        let frame: NSRect = barOnBottom
            ? NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: h)
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
            w.becomesKeyOnlyIfNeeded = true
            // Islands: pass through clear gaps. Strip: normal hosting so every pixel of the thin edge is hittable.
            w.contentView = Self.makeHost(bar: self, islands: barLayout == "islands")
            window = w
            w.setFrame(frame, display: true)
            w.orderFrontRegardless()
            return
        }
        window?.level = Self.barLevel
        if force || window?.frame != frame {
            window?.setFrame(frame, display: true)
            if force {
                window?.contentView = Self.makeHost(bar: self, islands: barLayout == "islands")
            }
        }
        window?.orderFrontRegardless()
    }

    /// NSHostingView otherwise applies safe-area / titlebar insets that shove a 24pt row off-center in a 36pt strip.
    private static func makeHost(bar: VeilBarController, islands: Bool) -> NSView {
        let root = VeilBarView(bar: bar)
        if islands {
            let h = PassThroughHost(rootView: root)
            if #available(macOS 13.0, *) { h.safeAreaRegions = [] }
            return h
        }
        let h = NSHostingView(rootView: root)
        if #available(macOS 13.0, *) { h.safeAreaRegions = [] }
        return h
    }

    /// Synthetic bar-button frames for panel anchoring while SketchyBar is hidden.
    func itemRect(for kind: VeilPanelKind) -> NSRect? {
        guard let window else { return nil }
        let f = window.frame
        switch kind {
        case .control:
            return NSRect(x: f.minX + 20, y: f.minY, width: 80, height: f.height)
        case .keys:
            return NSRect(x: f.maxX - 200, y: f.minY, width: 28, height: f.height)
        case .music:
            return NSRect(x: f.maxX - 168, y: f.minY, width: 28, height: f.height)
        }
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
    private var islands: Bool { bar.barLayout == "islands" }
    /// SketchyBar `--default background.height=24` inside EDGE_H 36.
    private let rowH: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                chipButton
                HStack(alignment: .center, spacing: 2) {
                    ForEach(bar.workspaces, id: \.index) { ws in workspaceButton(ws) }
                }
            }
            Spacer(minLength: 12)
            HStack(alignment: .center, spacing: 10) {
                barIconButton(system: "music.note", help: "Music") {
                    VeilPanelHost.shared.toggle(.music, near: Self.anchorNearMouse(size: NSSize(width: 24, height: 24)))
                }
                barIconButton(system: "keyboard", help: "Keys") {
                    VeilPanelHost.shared.toggle(.keys, near: Self.anchorNearMouse(size: NSSize(width: 24, height: 24)))
                }
                Text(bar.powerLabel)
                    .font(code(10, "Bold"))
                    .foregroundStyle(p["dim"])
                    .lineLimit(1)
                    .fixedSize()
                // Date/time → Quick settings (same as Quick Glyph). Chip still opens Control.
                Button {
                    animateClick { GlyphShell.shared.present(.quick) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(bar.clockDate)
                            .font(code(10, "Bold"))
                            .foregroundStyle(p["dim"])
                        Text(bar.clockTime)
                            .font(mono(13, "Medium"))
                            .foregroundStyle(p["fg"])
                    }
                    .fixedSize()
                    .frame(height: rowH, alignment: .center)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pressable()
                .help("Quick settings")
            }
            .frame(height: rowH, alignment: .center)
        }
        .padding(.horizontal, islands ? 14 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(islands ? Color.clear : p["bg_dark"])
        // Kill hosting safe-area so the 24pt row sits dead-center in the 36pt strip.
        .ignoresSafeArea()
    }

    private var chipButton: some View {
        Button {
            animateClick {
                if NSEvent.modifierFlags.contains(.option) {
                    bar.revealMenuBar()
                } else {
                    VeilPanelHost.shared.toggle(.control, near: Self.anchorNearMouse(size: NSSize(width: 72, height: 24)))
                }
            }
        } label: {
            Text(bar.chip)
                .font(mono(12, "SemiBold"))
                .foregroundStyle(bar.chipStyle == "filled" ? p["bg_dark"] : p["fg"])
                .padding(.horizontal, 10)
                .frame(height: rowH)
                .background(
                    Capsule(style: .continuous)
                        .fill(bar.chipStyle == "filled" ? p["yellow"] : Color.clear)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(p["yellow"].opacity(bar.chipStyle == "text" ? 0 : 0.95), lineWidth: 1)
                        )
                )
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
            HStack(alignment: .center, spacing: 5) {
                if bar.wsStyle == "dot" {
                    // SketchyBar ● icon — fill center, not sitting on the text baseline.
                    Text("●")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(ws.active ? p["red"] : p["dim"].opacity(0.75))
                        .frame(width: 10, height: rowH, alignment: .center)
                }
                Text(ws.name)
                    .font(code(11, "Bold"))
                    .foregroundStyle(ws.active ? p["fg"] : p["dim"])
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .frame(height: rowH, alignment: .center)
        }
        .buttonStyle(.plain)
        .pressable()
    }

    private func barIconButton(system: String, help: String, action: @escaping () -> Void) -> some View {
        Button { animateClick(action) } label: {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p["fg"])
                .frame(width: 22, height: rowH, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressable()
        .help(help)
    }

    private static func anchorNearMouse(size: NSSize) -> NSRect {
        let m = NSEvent.mouseLocation
        return NSRect(x: m.x - size.width / 2, y: m.y - size.height / 2, width: size.width, height: size.height)
    }

    private func animateClick(_ action: @escaping () -> Void) {
        if reduceMotion { action() }
        else { withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { action() } }
    }
}

// MARK: - SystemControls (VEI-39) — live Wi‑Fi/BT/Focus/volume/brightness
enum SystemControls {
    private typealias BTGet = @convention(c) () -> Int32
    private typealias BTSet = @convention(c) (Int32) -> Void
    private static let btHandle = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_NOW)
    private static let btGet = dlsym(btHandle, "IOBluetoothPreferenceGetControllerPowerState").map { unsafeBitCast($0, to: BTGet.self) }
    private static let btSet = dlsym(btHandle, "IOBluetoothPreferenceSetControllerPowerState").map { unsafeBitCast($0, to: BTSet.self) }

    /// Prefer the Wi‑Fi hardware port's device (usually en0).
    static var wifiDevice: String {
        let out = run("/usr/sbin/networksetup", ["-listallhardwareports"])
        var port = "", device = "en0"
        for line in out.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("Hardware Port:") { port = s.replacingOccurrences(of: "Hardware Port: ", with: "") }
            else if s.hasPrefix("Device:"), port.localizedCaseInsensitiveContains("Wi-Fi") || port.localizedCaseInsensitiveContains("AirPort") {
                device = s.replacingOccurrences(of: "Device: ", with: "").trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return device
    }

    static var wifiOn: Bool {
        let out = run("/usr/sbin/networksetup", ["-getairportpower", wifiDevice]).lowercased()
        return out.contains(": on")
    }

    @discardableResult
    static func setWifi(_ on: Bool) -> Bool {
        _ = run("/usr/sbin/networksetup", ["-setairportpower", wifiDevice, on ? "on" : "off"])
        let now = wifiOn
        DispatchQueue.main.async {
            OSD.shared.show(.network, level: nil, title: "Wi‑Fi", detail: now ? "On" : "Off")
        }
        return now
    }

    static func toggleWifi() -> Bool { setWifi(!wifiOn) }

    static var bluetoothOn: Bool {
        guard let btGet else { return false }
        return btGet() != 0
    }

    @discardableResult
    static func setBluetooth(_ on: Bool) -> Bool {
        if let btSet {
            btSet(on ? 1 : 0)
        } else {
            openSettings("x-apple.systempreferences:com.apple.BluetoothSettings")
        }
        let now = bluetoothOn
        DispatchQueue.main.async {
            OSD.shared.show(.network, level: nil, title: "Bluetooth", detail: now ? "On" : "Off")
        }
        return now
    }

    static func toggleBluetooth() -> Bool { setBluetooth(!bluetoothOn) }

    /// Best-effort: a Focus / DND assertion is active (Control Center window title/AX).
    static var focusOn: Bool {
        let script = """
        tell application "System Events"
          tell process "ControlCenter"
            repeat with w in windows
              try
                set n to name of w as text
                if n contains "Do Not Disturb" then return "on"
              end try
            end repeat
            if (count of windows) > 0 then
              repeat with e in entire contents of window 1
                try
                  set n to name of e as text
                  if n contains "Do Not Disturb" then return "on"
                end try
              end repeat
            end if
          end tell
        end tell
        return "off"
        """
        var err: NSDictionary?
        let raw = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue?.lowercased() ?? "off"
        return raw.contains("on")
    }

    static func openFocus() {
        openSettings("x-apple.systempreferences:com.apple.Focus-Settings.extension")
        DispatchQueue.main.async {
            OSD.shared.show(.input, level: nil, title: "Focus", detail: "Settings")
        }
    }

    /// Turn Do Not Disturb on. Prefers a Shortcuts named "Veil Do Not Disturb" / "Do Not Disturb",
    /// then Control Center (menu bar is often empty to AX when Veil owns the chrome — open via click),
    /// then Focus Settings.
    @discardableResult
    static func enableDoNotDisturb() -> Bool {
        if runFocusShortcut() {
            DispatchQueue.main.async {
                OSD.shared.show(.input, level: nil, title: "Focus", detail: "Do Not Disturb")
            }
            return true
        }
        if activateDoNotDisturbViaControlCenter() {
            DispatchQueue.main.async {
                OSD.shared.show(.input, level: nil, title: "Focus", detail: "Do Not Disturb")
            }
            return true
        }
        openFocus()
        return false
    }

    /// `shortcuts run` for a user/installed Focus shortcut (optional but most reliable on modern macOS).
    private static func runFocusShortcut() -> Bool {
        for name in ["Veil Do Not Disturb", "Do Not Disturb", "Set Do Not Disturb"] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["run", name]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do {
                try p.run()
                p.waitUntilExit()
                if p.terminationStatus == 0 { return true }
            } catch { continue }
        }
        return false
    }

    /// Reveal the stock menu bar, open Control Center with a click, then AX-click Focus / DND.
    private static func activateDoNotDisturbViaControlCenter() -> Bool {
        _ = NSAppleScript(source: "tell application \"System Events\" to tell dock preferences to set autohide menu bar to false")?
            .executeAndReturnError(nil)
        Thread.sleep(forTimeInterval: 0.45)
        guard let screen = NSScreen.main else { return false }
        let w = screen.frame.width
        // Control Center toggles sit left of the clock; Wi‑Fi/Battery are further left.
        // Sweep a few x positions and stop on a Control Center window that mentions Focus or has several toggles.
        var opened = false
        for dx: CGFloat in [170, 150, 190, 130, 210, 110] {
            clickScreen(x: w - dx, y: 5)
            Thread.sleep(forTimeInterval: 0.4)
            if controlCenterWindowOpen() { opened = true; break }
        }
        guard opened else { return false }
        let script = """
        tell application "System Events"
          tell process "ControlCenter"
            if (count of windows) is 0 then return "missing"
            -- Prefer an explicit Focus / Do Not Disturb control anywhere in the panel.
            repeat with e in entire contents of window 1
              try
                set n to name of e as text
                if n contains "Do Not Disturb" or n contains "Focus" then
                  click e
                  delay 0.2
                  -- If a submenu appeared, prefer DND.
                  try
                    click button "Do Not Disturb" of window 1
                  end try
                  try
                    click checkbox "Do Not Disturb" of window 1
                  end try
                  return "on"
                end if
              end try
            end repeat
            return "missing"
          end tell
        end tell
        """
        var err: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue ?? ""
        return result == "on"
    }

    private static func controlCenterWindowOpen() -> Bool {
        let opts: CGWindowListOption = [.optionOnScreenOnly]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return false }
        return info.contains { ($0[kCGWindowOwnerName as String] as? String ?? "") == "Control Center" }
    }

    private static func clickScreen(x: CGFloat, y: CGFloat) {
        let p = CGPoint(x: x, y: y)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    @discardableResult
    static func toggleFocus() -> Bool { enableDoNotDisturb() }

    static func openDisplays() {
        openSettings("x-apple.systempreferences:com.apple.Displays-Settings.extension")
        DispatchQueue.main.async {
            OSD.shared.show(.brightness, level: Brightness.get().map { Double($0) }, title: "Displays")
        }
    }

    static func openSound() {
        openSettings("x-apple.systempreferences:com.apple.Sound-Settings.extension")
    }

    static func openWiFiSettings() {
        // Prefer Wi‑Fi pane; Network pane is the fallback.
        openSettings("x-apple.systempreferences:com.apple.wifi-settings-extension")
    }

    static func openBluetoothSettings() {
        openSettings("x-apple.systempreferences:com.apple.BluetoothSettings")
    }

    static func openNetwork() {
        openSettings("x-apple.systempreferences:com.apple.Network-Settings.extension")
    }

    static func openSettings(_ url: String) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }

    /// Output volume 0…1 (nil when HDMI/device has no controllable level).
    static func volumeLevel() -> Double? {
        var err: NSDictionary?
        guard let raw = NSAppleScript(source: "output volume of (get volume settings)")?
            .executeAndReturnError(&err).stringValue,
              let v = Double(raw) else { return nil }
        return max(0, min(1, v / 100))
    }

    static func isMuted() -> Bool {
        var err: NSDictionary?
        let raw = NSAppleScript(source: "output muted of (get volume settings)")?
            .executeAndReturnError(&err).stringValue?.lowercased() ?? ""
        return raw.contains("true")
    }

    static func setVolume(_ level: Double) {
        let v = Int((max(0, min(1, level)) * 100).rounded())
        let src = "set volume output volume \(v)" + (v > 0 ? " without output muted" : "")
        var err: NSDictionary?
        _ = NSAppleScript(source: src)?.executeAndReturnError(&err)
        DispatchQueue.main.async {
            OSD.shared.show(.volume, level: Double(v) / 100, title: "Volume")
            VeilPanelHost.shared.volumeText = "\(v)%"
            VeilPanelHost.shared.volumeLevel = Double(v) / 100
        }
    }

    static func toggleMute() {
        let next = !isMuted()
        var err: NSDictionary?
        _ = NSAppleScript(source: "set volume output muted \(next)")?.executeAndReturnError(&err)
        DispatchQueue.main.async {
            OSD.shared.show(.volume, level: next ? 0 : (volumeLevel() ?? 0), title: "Volume", detail: next ? "Muted" : "Unmuted")
        }
    }

    static func setBrightness(_ level: Double) {
        guard Brightness.available else { openDisplays(); return }
        let set = max(0.01, min(1, level))
        Brightness.set(Float(set))
        DispatchQueue.main.async {
            OSD.shared.show(.brightness, level: set, title: "Brightness")
            VeilPanelHost.shared.brightnessLevel = set
        }
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return "" }
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
