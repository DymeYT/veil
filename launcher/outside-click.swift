import AppKit

/// Outside-click monitors + shared overlay dismiss registry (VEI-53).
/// Main-thread only (AppKit). Not @MainActor so App.show/hide can call sync without
/// isolation walls — hosts are hopped via MainActor.assumeIsolated.
/// `dismissAll` is the one-shot path: Esc / outside-click / `dismiss-popups` must bury
/// launcher + Control + Quick + music + Glyph — never leave stuck chrome.
enum OutsideClick {
    private static var registry: [String: () -> Void] = [:]
    private static var dismissing = false

    /// Register an overlay dismiss hook. Replaces any prior hook for `id`.
    /// Lane C: wire panel outside-click / Esc to `dismissAll()` (see lane-requests.md).
    static func register(_ id: String, dismiss: @escaping () -> Void) {
        registry[id] = dismiss
    }

    static func unregister(_ id: String) {
        registry.removeValue(forKey: id)
    }

    private static func onMain(_ body: @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(body)
        } else {
            DispatchQueue.main.sync { MainActor.assumeIsolated(body) }
        }
    }

    /// Kill every registered overlay in one shot. Re-entrant calls are no-ops.
    /// Hard-falls back to Glyph + VeilPanelHost so a missed registration cannot stick UI.
    static func dismissAll() {
        onMain {
            guard !dismissing else { return }
            dismissing = true
            defer { dismissing = false }
            let handlers = Array(registry.values)
            for h in handlers { h() }
            GlyphShell.shared.dismiss()
            VeilPanelHost.shared.dismissImmediate()
        }
    }

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
