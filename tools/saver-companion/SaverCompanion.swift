import AppKit
import QuartzCore
import IOKit.pwr_mgt

/// VEI-40: theme-accurate idle companion. Full-screen drift over wallpaper art.
/// Never launches ScreenSaverEngine / never locks the session.
/// Enable: `veil feature enable saver-companion` then this binary runs as a LaunchAgent
/// or via `veil saver-companion`. Click / any key / mouse dismisses.

final class DriftView: NSView {
    var image: NSImage?
    var reduceMotion = false
    private var layerImage: CALayer?

    override func viewDidMoveToWindow() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        guard let image else { return }
        let host = CALayer()
        host.contents = image
        host.contentsGravity = .resizeAspectFill
        host.frame = bounds.insetBy(dx: -60, dy: -60)
        layer?.addSublayer(host)
        layerImage = host
        guard !reduceMotion else { return }
        let anim = CABasicAnimation(keyPath: "position")
        anim.fromValue = NSValue(point: CGPoint(x: bounds.midX - 18, y: bounds.midY - 12))
        anim.toValue = NSValue(point: CGPoint(x: bounds.midX + 18, y: bounds.midY + 12))
        anim.duration = 14
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        host.add(anim, forKey: "veil-companion-drift")
    }

    override func layout() {
        super.layout()
        layerImage?.frame = bounds.insetBy(dx: -60, dy: -60)
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }
}

final class CompanionApp: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var idleTimer: Timer?
    var monitors: [Any] = []
    var idleSeconds: TimeInterval = 180
    var reduceMotion = false
    var assertionID: IOPMAssertionID = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = Array(CommandLine.arguments.dropFirst())
        if let idx = args.firstIndex(of: "--idle"), args.indices.contains(idx + 1),
           let v = Double(args[idx + 1]) {
            idleSeconds = max(30, v)
        }
        if args.contains("--now") {
            showCompanion()
            return
        }
        // Idle watch — CGEventSource idle time; never pmset/SSE.
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tickIdle()
        }
        RunLoop.main.add(idleTimer!, forMode: .common)
    }

    func tickIdle() {
        guard window == nil else { return }
        // UINT32_MAX ⇒ seconds since any event in the combined session.
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: UInt32.max)!
        )
        let seconds = idle.isFinite && idle >= 0 ? idle : 0
        if seconds >= idleSeconds {
            showCompanion()
        }
    }

    func showCompanion() {
        guard window == nil else { return }
        let root = (ProcessInfo.processInfo.environment["VEIL_ROOT"]
            ?? NSString(string: "~/.config/veil").expandingTildeInPath)
        let theme = (try? String(contentsOfFile: root + "/current", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "nothing"
        let art = root + "/art/\(theme).jpg"
        let image = NSImage(contentsOfFile: art)
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || ProcessInfo.processInfo.environment["VEIL_SAVER_STILL"] == "1"

        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let w = NSPanel(
            contentRect: screen,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = true
        w.backgroundColor = .black
        w.level = .screenSaver - 1 // below real saver; above normal windows
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.hidesOnDeactivate = false
        let view = DriftView(frame: NSRect(origin: .zero, size: screen.size))
        view.image = image
        view.reduceMotion = reduceMotion
        w.contentView = view
        w.setFrame(screen, display: true)
        w.orderFrontRegardless()
        window = w

        let dismiss: (NSEvent) -> Void = { [weak self] _ in self?.hideCompanion() }
        if let g = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel],
            handler: dismiss
        ) {
            monitors.append(g)
        }
        if let l = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown],
            handler: { e in dismiss(e); return nil }
        ) {
            monitors.append(l)
        }
    }

    func hideCompanion() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors = []
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
    }
}

@main
enum SaverCompanionMain {
    static func main() {
        // Refuse to ever touch ScreenSaverEngine.
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = CompanionApp()
        app.delegate = delegate
        // Keep process alive for idle watch unless --once preview.
        if CommandLine.arguments.contains("--once") {
            delegate.showCompanion()
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { app.terminate(nil) }
        }
        app.run()
    }
}
