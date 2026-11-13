import AppKit
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

    /// Opt-in custom Veil status strip. Default is SketchyBar chrome (Umbra islands look + clicks).
    /// Animated panels still ride on SketchyBar item clicks when `animated-panels` is on.
    static var veilBar: Bool { FileManager.default.fileExists(atPath: root + "/enable-veil-bar") }

    /// Default-on live window thumbs for the selected Overview card (out-of-process SCK).
    static var overviewLiveThumbs: Bool { !FileManager.default.fileExists(atPath: root + "/disable-overview-live-thumbs") }

    /// Opt-in: force the Reduce Motion still-path (panels appear/dismiss without fade).
    static var forceReduceMotion: Bool { FileManager.default.fileExists(atPath: root + "/enable-force-reduce-motion") }
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
                        .fill(palette["bg_dark"].opacity(0.55))
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
    /// AppKit screen rect of the bar button that opened the panel (nil → resolve from SketchyBar).
    var anchorRect: NSRect?
    private var window: NSWindow?
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
    }

    func dismiss() {
        guard let window, window.isVisible else {
            kind = nil
            anchorRect = nil
            self.window?.contentView = nil
            self.window = nil
            return
        }
        let finish = { [weak self] in
            window.orderOut(nil)
            window.contentView = nil
            self?.window = nil
            self?.kind = nil
            self?.anchorRect = nil
        }
        if reduceMotion {
            finish()
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.14
                window.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in finish() }
            })
        }
    }

    /// SketchyBar `bounding_rects` use top-left display coords → AppKit bottom-left.
    static func sketchybarItemRect(for kind: VeilPanelKind) -> NSRect? {
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
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rects = obj["bounding_rects"] as? [String: Any] else { return nil }
        // Prefer the display under the mouse; else first rect.
        let mouse = NSEvent.mouseLocation
        var chosen: (origin: [Double], size: [Double])?
        for (_, v) in rects {
            guard let r = v as? [String: Any],
                  let origin = r["origin"] as? [Double], origin.count == 2,
                  let size = r["size"] as? [Double], size.count == 2 else { continue }
            if chosen == nil { chosen = (origin, size) }
            // Heuristic match: same X band as mouse on that display
            if abs(origin[0] + size[0] / 2 - mouse.x) < 400 { chosen = (origin, size); break }
        }
        guard let chosen else { return nil }
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main ?? NSScreen.screens[0]
        // SketchyBar Y is measured downward from the top of the display.
        let x = screen.frame.minX + chosen.origin[0]
        let y = screen.frame.maxY - chosen.origin[1] - chosen.size[1]
        return NSRect(x: x, y: y, width: chosen.size[0], height: chosen.size[1])
    }

    private func panelSize() -> (CGFloat, CGFloat) {
        let width: CGFloat = 340
        let height: CGFloat
        switch kind {
        case .control: height = 420
        case .keys: height = 360
        case .music: height = musicArtwork == nil ? 210 : 280
        case nil: height = 210
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
            let (width, height) = panelSize()
            let frame = frameNearAnchor(width: width, height: height)
            window.setFrame(frame, display: true)
            window.contentView = NSHostingView(rootView: VeilPanelView(host: self).environmentObject(self))
        }
    }

    /// Glyph Quick / other surfaces can refresh now-playing without opening the music panel.
    func ensureMusicMeta() { loadMusic() }

    private func loadMusic() {
        // Metadata first (cheap); artwork in a second call so the panel can paint title immediately.
        applyMusicMetadata(from: mediaControlJSON(noArtwork: true))
        if musicTitle == "Nothing playing" {
            applyMusicSnapshotFallback()
        }
        // Artwork off the main hot path. Cider often omits artworkData on the first get —
        // retry, and persist a JPEG cache so the panel can load from disk on the main thread.
        let expectedTitle = musicTitle
        let cacheURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Caches/veil-music-art.jpg")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var wrote = false
            for attempt in 0..<6 {
                if let obj = Self.mediaControlJSONSync(noArtwork: false),
                   let raw = obj["artworkData"] as? String, raw.count > 200,
                   let data = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]) {
                    try? data.write(to: cacheURL, options: .atomic)
                    wrote = true
                    break
                }
                if attempt < 5 { Thread.sleep(forTimeInterval: 0.4) }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                if wrote, let img = NSImage(contentsOf: cacheURL) {
                    self.musicArtwork = img
                } else if self.musicTitle != expectedTitle {
                    self.musicArtwork = nil
                }
                if self.kind == .music { self.ensureWindow() }
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
        var parts = ["CPU \(cpu)%", "MEM \(mem)G", "VOL \(vol)"]
        if quiet { parts.append("QUIET") }
        if motionOff { parts.append("MOTION OFF") }
        statusLine = parts.joined(separator: "  ·  ")
    }

    func musicAction(_ action: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-lc", "\"$HOME/.config/sketchybar/plugins/veil.sh\" music \(action)"]
        try? p.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.loadMusic()
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
                .font(panelFont(11, .bold, mono: true))
                .foregroundStyle(p["cyan"])
            HStack(alignment: .top, spacing: 12) {
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
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(p["dim"])
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: themeCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: themeCorner, style: .continuous)
                        .strokeBorder(p["border"].opacity(0.7), lineWidth: 1)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.musicTitle)
                        .font(panelFont(17, .semibold))
                        .foregroundStyle(p["fg"])
                        .lineLimit(2)
                    if !host.musicArtist.isEmpty {
                        Text(host.musicArtist)
                            .font(panelFont(13, .medium))
                            .foregroundStyle(p["dim"])
                            .lineLimit(1)
                    }
                    if !host.musicAlbum.isEmpty {
                        Text(host.musicAlbum)
                            .font(panelFont(11, .medium, mono: true))
                            .foregroundStyle(p["comment"])
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
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
                    Button {
                        animateClick {
                            VeilPanelHost.shared.toggle(.music, near: Self.anchorNearMouse(size: NSSize(width: 28, height: 24)))
                        }
                    } label: {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(p["fg"])
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain).pressable()
                    Button {
                        animateClick {
                            VeilPanelHost.shared.toggle(.keys, near: Self.anchorNearMouse(size: NSSize(width: 28, height: 24)))
                        }
                    } label: {
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
                    VeilPanelHost.shared.toggle(.control, near: Self.anchorNearMouse(size: NSSize(width: 80, height: 28)))
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

    /// Approximate the clicked bar control from the mouse (Veil bar path).
    private static func anchorNearMouse(size: NSSize) -> NSRect {
        let m = NSEvent.mouseLocation
        return NSRect(x: m.x - size.width / 2, y: m.y - size.height / 2, width: size.width, height: size.height)
    }

    private func animateClick(_ action: @escaping () -> Void) {
        if reduceMotion {
            action()
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { action() }
        }
    }
}
