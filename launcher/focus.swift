// Focus pulse: when focus moves to another window, a ring in the theme's accent blooms around it and fades,
// handing over to the steady border. Event-driven (app activation + the frontmost app's focused-window change),
// never polled; off under Reduce Motion and `veil quiet`. The same events keep exactly one terminal opaque:
// terminals run slightly translucent (term_opacity) and the focused Ghostty window is toggled solid.
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
    private var watchedWindow: AXUIElement?
    private var pending: DispatchWorkItem?
    private var fade: DispatchWorkItem?
    private var cleanup: DispatchWorkItem?
    private var retarget: [DispatchWorkItem] = []
    private var enabled = false
    private var opaqueTerminal: String?  // the Ghostty window currently toggled solid
    private let terminalQueue = DispatchQueue(label: "app.veil.search.terminal-opacity")

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard self?.enabled == true, let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.watch(app.processIdentifier)
            self?.focusChanged()
        }
        setEnabled(!veilIsOff)
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled, let app = NSWorkspace.shared.frontmostApplication {
            watch(app.processIdentifier)
        } else {
            if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode) }
            observer = nil
            pending?.cancel()
            fade?.cancel()
            cleanup?.cancel()
            retarget.forEach { $0.cancel() }
            retarget = []
            model.on = false
            panel?.orderOut(nil)
            syncTerminalOpacity(forceTranslucent: true)
        }
    }

    /// Window switches inside one app (two Ghostty windows) don't activate an app, so follow its focused window too.
    private func watch(_ pid: pid_t) {
        if let o = observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode) }
        observer = nil
        watchedWindow = nil
        var created: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let self_ = Unmanaged<FocusPulse>.fromOpaque(refcon).takeUnretainedValue()
            let name = (notification as String)
            if name == (kAXFocusedWindowChangedNotification as String) {
                self_.attachWindowNotifications(element)
                self_.focusChanged()
            } else {
                // move / resize while the pulse is visible — retarget without restarting the bloom
                self_.retargetVisiblePulse()
            }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let o = created else { return }
        let appEl = AXUIElementCreateApplication(pid)
        let ref = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(o, appEl, kAXFocusedWindowChangedNotification as CFString, ref) == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        observer = o
        var win: CFTypeRef?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &win) == .success,
           let win, CFGetTypeID(win) == AXUIElementGetTypeID() {
            attachWindowNotifications(win as! AXUIElement)
        }
    }

    private func attachWindowNotifications(_ element: AXUIElement) {
        guard let o = observer else { return }
        let ref = Unmanaged.passUnretained(self).toOpaque()
        if let prev = watchedWindow, CFEqual(prev, element) == false {
            AXObserverRemoveNotification(o, prev, kAXWindowMovedNotification as CFString)
            AXObserverRemoveNotification(o, prev, kAXWindowResizedNotification as CFString)
        }
        // Focused-window-changed may pass the app element; resolve to the window when needed.
        var win: CFTypeRef? = element
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           (role as? String) == (kAXApplicationRole as String) {
            AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &win)
        }
        guard let win, CFGetTypeID(win) == AXUIElementGetTypeID() else { return }
        let window = win as! AXUIElement
        _ = AXObserverAddNotification(o, window, kAXWindowMovedNotification as CFString, ref)
        _ = AXObserverAddNotification(o, window, kAXWindowResizedNotification as CFString, ref)
        watchedWindow = window
    }

    private func retargetVisiblePulse() {
        guard model.on, let next = focusedFrame() else { return }
        panel?.setFrame(next.insetBy(dx: -10, dy: -10), display: true)
    }

    func focusChanged() {
        guard enabled else { return }
        syncTerminalOpacity()
        pulse()
    }

    // a Ghostty config reload keeps a toggled window solid, so theme switches need no resync

    private func syncTerminalOpacity(forceTranslucent: Bool = false) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.mitchellh.ghostty").first != nil else { return }
        let front = !forceTranslucent && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.mitchellh.ghostty"
        terminalQueue.async { [weak self] in
            guard let self, front || self.opaqueTerminal != nil else { return }
            // toggle_background_opacity flips one window between solid and its configured translucency
            let script = """
            on run argv
              set prev to item 2 of argv
              tell application "Ghostty"
                set fid to ""
                if item 1 of argv is "1" then set fid to (id of front window) as text
                if prev is not "" and prev is not fid then
                  try
                    perform action "toggle_background_opacity" on focused terminal of selected tab of (window id prev)
                  end try
                end if
                if fid is not "" and fid is not prev then perform action "toggle_background_opacity" on focused terminal of selected tab of front window
                return fid
              end tell
            end run
            """
            let task = Process(), out = Pipe()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script, front ? "1" : "0", self.opaqueTerminal ?? ""]
            task.standardOutput = out; task.standardError = FileHandle.nullDevice
            guard (try? task.run()) != nil else { return }
            task.waitUntilExit()
            let id = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if task.terminationStatus == 0 { self.opaqueTerminal = id.isEmpty ? nil : id }
        }
    }

    func pulse() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !FileManager.default.fileExists(atPath: home + "/.config/veil/generated/quiet") else { return }
        pending?.cancel()
        retarget.forEach { $0.cancel() }
        retarget = []
        // Beat for Rift to place the window before the first frame read.
        let w = DispatchWorkItem { [weak self] in self?.bloom(track: true) }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: w)
    }

    /// Quartz (AX / CGWindow, origin top-left of main display) → AppKit (origin bottom-left).
    private func quartzToAppKit(_ quartz: CGRect) -> CGRect {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens[0]
        return CGRect(
            x: quartz.origin.x,
            y: primary.frame.maxY - quartz.origin.y - quartz.height,
            width: quartz.width,
            height: quartz.height
        )
    }

    /// Prefer CGWindowList bounds (matches on-screen pixels); fall back to AX position/size.
    private func focusedFrame() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let pid = app.processIdentifier

        var win: CFTypeRef?, posV: CFTypeRef?, sizeV: CFTypeRef?, titleV: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &win) == .success,
              let win, CFGetTypeID(win) == AXUIElementGetTypeID() else { return nil }
        let axWin = win as! AXUIElement
        AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posV)
        AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeV)
        AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleV)
        var pos = CGPoint.zero, size = CGSize.zero
        guard let posV, let sizeV, CFGetTypeID(posV) == AXValueGetTypeID(), CFGetTypeID(sizeV) == AXValueGetTypeID(),
              AXValueGetValue(posV as! AXValue, .cgPoint, &pos), AXValueGetValue(sizeV as! AXValue, .cgSize, &size),
              size.width > 120, size.height > 80 else { return nil }
        let axTitle = titleV as? String ?? ""
        let axQuartz = CGRect(origin: pos, size: size)

        // CGWindowList uses the same top-left space as AX; pick the best on-screen match for this PID.
        var quartz = axQuartz
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] {
            let candidates = info.compactMap { row -> CGRect? in
                guard (row[kCGWindowOwnerPID as String] as? pid_t) == pid,
                      (row[kCGWindowLayer as String] as? Int) == 0,
                      let b = row[kCGWindowBounds as String] as? [String: Any],
                      let x = b["X"] as? CGFloat, let y = b["Y"] as? CGFloat,
                      let w = b["Width"] as? CGFloat, let h = b["Height"] as? CGFloat,
                      w > 120, h > 80 else { return nil }
                return CGRect(x: x, y: y, width: w, height: h)
            }
            if let titled = info.first(where: { row in
                (row[kCGWindowOwnerPID as String] as? pid_t) == pid
                    && (row[kCGWindowLayer as String] as? Int) == 0
                    && !axTitle.isEmpty
                    && (row[kCGWindowName as String] as? String) == axTitle
            }), let b = titled[kCGWindowBounds as String] as? [String: Any],
               let x = b["X"] as? CGFloat, let y = b["Y"] as? CGFloat,
               let w = b["Width"] as? CGFloat, let h = b["Height"] as? CGFloat {
                quartz = CGRect(x: x, y: y, width: w, height: h)
            } else if let nearest = candidates.min(by: {
                abs($0.midX - axQuartz.midX) + abs($0.midY - axQuartz.midY)
                    < abs($1.midX - axQuartz.midX) + abs($1.midY - axQuartz.midY)
            }) {
                quartz = nearest
            }
        }

        let frame = quartzToAppKit(quartz)
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main {
            let area = frame.width * frame.height, screenArea = screen.frame.width * screen.frame.height
            if screenArea > 0, area / screenArea > 0.92 { return nil }
        }
        return frame
    }

    private func bloom(track: Bool) {
        guard enabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let f = focusedFrame() else { return }
        fade?.cancel()
        cleanup?.cancel()
        let frame = f.insetBy(dx: -10, dy: -10)
        let w = panel ?? {
            let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false; p.ignoresMouseEvents = true
            p.level = .floating; p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            return p
        }()
        panel = w
        if !(w.contentView is NSHostingView<FocusPulseView>) {
            w.contentView = NSHostingView(rootView: FocusPulseView(m: model, color: palette()["cyan"]))
        }
        w.setFrame(frame, display: true)
        if !model.on {
            model.on = false
            w.orderFrontRegardless()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { model.on = true }
        } else {
            w.orderFrontRegardless()
        }
        let fade = DispatchWorkItem { [weak self] in
            withAnimation(.easeIn(duration: 0.34)) { self?.model.on = false }
        }
        let cleanup = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        self.fade = fade
        self.cleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: fade)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68, execute: cleanup)

        guard track else { return }
        // Re-stick while Rift finishes the focus animation (border was reading mid-tween frames).
        retarget.forEach { $0.cancel() }
        retarget = [0.08, 0.20, 0.36].map { delay in
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.model.on, let next = self.focusedFrame() else { return }
                self.panel?.setFrame(next.insetBy(dx: -10, dy: -10), display: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }
}
