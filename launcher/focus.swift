// Focus pulse: when focus moves to another window, a ring in the theme's accent blooms around it and fades,
// handing over to the steady border. Event-driven (app activation + the frontmost app's focused-window change),
// never polled; off under Reduce Motion and `veil quiet`.
import AppKit
import SwiftUI
import ApplicationServices

final class FocusPulseModel: ObservableObject { @Published var on = false }

struct FocusPulseView: View {
    @ObservedObject var m: FocusPulseModel
    let color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(color, lineWidth: 2)
            .shadow(color: color.opacity(0.9), radius: m.on ? 14 : 2)
            .padding(10)  // room for the glow inside the panel
            .scaleEffect(m.on ? 1 : 1.015)
            .opacity(m.on ? 1 : 0)
    }
}

final class FocusPulse {
    static let shared = FocusPulse()
    var palette: () -> Palette = { Palette.load() }
    private let model = FocusPulseModel()
    private var panel: NSPanel?
    private var observer: AXObserver?
    private var pending: DispatchWorkItem?
    private var lastFrame = CGRect.zero

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.watch(app.processIdentifier)
            self?.pulse()
        }
        if let app = NSWorkspace.shared.frontmostApplication { watch(app.processIdentifier) }
    }

    /// Window switches inside one app (two Ghostty windows) don't activate an app, so follow its focused window too.
    private func watch(_ pid: pid_t) {
        if let o = observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode) }
        observer = nil
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<FocusPulse>.fromOpaque(refcon).takeUnretainedValue().pulse()
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let o = created else { return }
        AXObserverAddNotification(o, AXUIElementCreateApplication(pid), kAXFocusedWindowChangedNotification as CFString,
                                  Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        observer = o
    }

    func pulse() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !FileManager.default.fileExists(atPath: home + "/.config/veil/generated/quiet") else { return }
        pending?.cancel()
        // a beat for Rift to settle the window before its frame is read
        let w = DispatchWorkItem { [weak self] in self?.bloom() }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: w)
    }

    /// The focused window's frame in AppKit coordinates (origin bottom-left of the primary screen).
    private func focusedFrame() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }  // not our own panels
        var win: CFTypeRef?, posV: CFTypeRef?, sizeV: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute as CFString, &win) == .success,
              let win, CFGetTypeID(win) == AXUIElementGetTypeID() else { return nil }
        let w = win as! AXUIElement
        AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &posV)
        AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &sizeV)
        var pos = CGPoint.zero, size = CGSize.zero
        guard let posV, let sizeV, CFGetTypeID(posV) == AXValueGetTypeID(), CFGetTypeID(sizeV) == AXValueGetTypeID(),
              AXValueGetValue(posV as! AXValue, .cgPoint, &pos), AXValueGetValue(sizeV as! AXValue, .cgSize, &size),
              size.width > 120, size.height > 80, let primary = NSScreen.screens.first else { return nil }
        return CGRect(x: pos.x, y: primary.frame.maxY - pos.y - size.height, width: size.width, height: size.height)
    }

    private func bloom() {
        guard let f = focusedFrame() else { return }
        let frame = f.insetBy(dx: -10, dy: -10)
        let w = panel ?? {
            let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false; p.ignoresMouseEvents = true
            p.level = .floating; p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            return p
        }()
        panel = w
        w.contentView = NSHostingView(rootView: FocusPulseView(m: model, color: palette()["cyan"]))
        w.setFrame(frame, display: false)
        model.on = false
        w.orderFrontRegardless()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { model.on = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            withAnimation(.easeIn(duration: 0.34)) { self?.model.on = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { [weak self] in
            if self?.model.on == false { self?.panel?.orderOut(nil) }
        }
    }
}
