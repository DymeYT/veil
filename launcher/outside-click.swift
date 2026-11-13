import AppKit

/// Outside-click monitors + shared overlay dismiss registry (VEI-53 / VEI-64).
/// Main-thread only (AppKit). Not @MainActor so App.show/hide can call sync without
/// isolation walls — hosts are hopped via MainActor.assumeIsolated.
/// `dismissAll` is the one-shot path: Esc / outside-click / `dismiss-popups` must bury
/// launcher + Control + Quick + music + Glyph — never leave stuck chrome.
enum OutsideClick {
    private static var registry: [String: () -> Void] = [:]
    private static var dismissing = false
    /// Session-wide mouse monitors — survive per-panel reinstall races (VEI-64).
    private static var overlayMonitors: [Any] = []
    private static var overlayIgnoreUntil = Date.distantPast

    /// Register an overlay dismiss hook. Replaces any prior hook for `id`.
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
    /// Hard-falls back to Glyph + VeilPanelHost + husk sweep so a missed registration cannot stick UI.
    static func dismissAll() {
        onMain {
            guard !dismissing else { return }
            dismissing = true
            defer { dismissing = false }
            let handlers = Array(registry.values)
            for h in handlers { h() }
            GlyphShell.shared.dismiss()
            VeilPanelHost.shared.dismissImmediate()
            sweepOverlayHusks()
            // Drop session monitors once everything is gone — re-armed on next present.
            if !overlayActive {
                remove(&overlayMonitors)
            }
        }
    }

    /// Any Control / Quick / music / launcher chrome still ordered in?
    @MainActor private static var overlayActive: Bool {
        VeilPanelHost.shared.kind != nil || GlyphShell.shared.kind != nil
            || (NSApp.windows.contains { isOverlayHusk($0) })
    }

    /// Status-bar+ panels that aren't the thin Veil bar or desktop Glyph board.
    @MainActor private static func isOverlayHusk(_ w: NSWindow) -> Bool {
        // Click-through chrome (volume/brightness OSD, notch band) is never an overlay to sweep.
        guard w.isVisible, !w.ignoresMouseEvents else { return false }
        let level = w.level.rawValue
        let barLevel = Int(CGWindowLevelForKey(.dockWindow)) - 1
        let desktopGlyph = Int(CGWindowLevelForKey(.desktopIconWindow)) + 2
        // Keep bar + wallpaper Glyph board + notch band.
        if level <= barLevel { return false }
        if abs(level - desktopGlyph) <= 2 { return false }
        if level < NSWindow.Level.statusBar.rawValue { return false }
        // Thin full-width strip = bar (already filtered by level on bottom themes).
        let f = w.frame
        if f.height <= 40, f.width >= (NSScreen.main?.frame.width ?? 1000) - 4 { return false }
        return true
    }

    @MainActor private static func sweepOverlayHusks() {
        for w in NSApp.windows where isOverlayHusk(w) {
            w.orderOut(nil)
            w.contentView = nil
        }
    }

    /// Arm session-wide outside-click → dismissAll while any overlay is up (VEI-64).
    /// Safe frames = every visible overlay panel; clicks on bar / desktop / apps dismiss.
    static func armOverlayDismiss(ignoreFor: TimeInterval = 0.35) {
        onMain {
            overlayIgnoreUntil = Date().addingTimeInterval(ignoreFor)
            if !overlayMonitors.isEmpty { return }
            let fire: (NSEvent) -> Void = { _ in
                guard Date() >= overlayIgnoreUntil else { return }
                // AppKit delivers monitor events on the main thread.
                let inside: Bool? = MainActor.assumeIsolated {
                    guard overlayActive else { return nil }
                    let pt = NSEvent.mouseLocation
                    // Inside any overlay panel → keep; everywhere else (incl. bar, desktop) → bury.
                    return NSApp.windows.contains { isOverlayHusk($0) && $0.frame.contains(pt) }
                }
                if inside == false { dismissAll() }
            }
            if let g = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown],
                handler: fire
            ) {
                overlayMonitors.append(g)
            }
            if let l = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown],
                handler: { e in
                    fire(e)
                    return e
                }
            ) {
                overlayMonitors.append(l)
            }
        }
    }

    /// One surface at a time: before showing `keep`, bury the launcher and the other overlay host.
    @MainActor static func closeOthers(keep: String) {
        if let app = NSApp.delegate as? App, app.panel?.isVisible == true { app.hide() }
        if keep != "glyph" { GlyphShell.shared.dismiss() }
        if keep != "veil-panel" { VeilPanelHost.shared.dismissImmediate() }
    }

    /// Install global (+ local) mouse-down monitors. Caller must `remove` on dismiss.
    /// Prefer `armOverlayDismiss` for Control/Quick — this remains for launcher/scrim.
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
