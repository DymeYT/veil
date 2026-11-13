import AppKit

/// VEI-35: dismiss floating Veil UI when the user clicks anywhere outside it.
/// Global monitors are required for `.nonactivatingPanel` hosts that never become key.
@MainActor
enum OutsideClick {
    /// Install global (+ local) mouse-down monitors. Caller must `remove` on dismiss.
    /// `ignoreUntil` avoids dismissing from the same click that opened the surface.
    static func install(
        window: NSWindow?,
        ignoreUntil: Date = Date().addingTimeInterval(0.35),
        extraSafeFrames: @escaping () -> [NSRect] = { [] },
        onOutside: @escaping () -> Void
    ) -> [Any] {
        var monitors: [Any] = []
        let fire: (NSEvent) -> Void = { _ in
            guard Date() >= ignoreUntil else { return }
            guard let window, window.isVisible else { return }
            let pt = NSEvent.mouseLocation
            if window.frame.contains(pt) { return }
            for r in extraSafeFrames() where r.contains(pt) { return }
            onOutside()
        }
        if let g = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: fire
        ) {
            monitors.append(g)
        }
        if let l = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { e in
                fire(e)
                return e
            }
        ) {
            monitors.append(l)
        }
        return monitors
    }

    static func remove(_ monitors: inout [Any]) {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
    }
}
