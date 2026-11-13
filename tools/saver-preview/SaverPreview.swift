import AppKit
import QuartzCore

/// Safe theme-aware screen-saver preview. Runs in a normal NSWindow — never
/// ScreenSaverEngine, never locks the session. Respects Reduce Motion (still).

final class DriftView: NSView {
    var image: NSImage?
    var reduceMotion = false
    private var layerImage: CALayer?
    private var timer: Timer?

    override func viewDidMoveToWindow() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        guard let image else { return }
        let host = CALayer()
        host.contents = image
        host.contentsGravity = .resizeAspectFill
        host.frame = bounds.insetBy(dx: -40, dy: -40)
        layer?.addSublayer(host)
        layerImage = host
        guard !reduceMotion else { return }
        let anim = CABasicAnimation(keyPath: "position")
        anim.fromValue = NSValue(point: CGPoint(x: bounds.midX - 12, y: bounds.midY - 8))
        anim.toValue = NSValue(point: CGPoint(x: bounds.midX + 12, y: bounds.midY + 8))
        anim.duration = 8
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        host.add(anim, forKey: "veil-drift")
    }

    override func layout() {
        super.layout()
        layerImage?.frame = bounds.insetBy(dx: -40, dy: -40)
    }
}

@main
enum SaverPreview {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let root = (ProcessInfo.processInfo.environment["VEIL_ROOT"]
            ?? NSString(string: "~/.config/veil").expandingTildeInPath)
        let theme = (try? String(contentsOfFile: root + "/current", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "umbra"
        let art = root + "/art/\(theme).jpg"
        let shared = "/Users/Shared/Veil-\(getuid())"
        let sharedArt = (try? FileManager.default.contentsOfDirectory(atPath: shared))?
            .first(where: { $0.hasSuffix(".jpg") }).map { shared + "/" + $0 }
        let path = FileManager.default.fileExists(atPath: art) ? art : (sharedArt ?? art)
        let image = NSImage(contentsOfFile: path)
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let frame = NSRect(x: screen.midX - 520, y: screen.midY - 320, width: 1040, height: 640)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Veil Screen Saver Preview — \(theme)\(reduce ? " (Reduce Motion)" : "")"
        window.isReleasedWhenClosed = false
        let view = DriftView(frame: NSRect(origin: .zero, size: frame.size))
        view.image = image
        view.reduceMotion = reduce
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        // Auto-close so overnight agents can capture without leaving a stuck window.
        let seconds = Double(CommandLine.arguments.dropFirst().first ?? "4") ?? 4
        DispatchQueue.main.asyncAfter(deadline: .now() + max(2, seconds)) {
            app.terminate(nil)
        }
        app.run()
    }
}
