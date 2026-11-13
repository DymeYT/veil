import AppKit
import Foundation

/// Supervises borders + Rift as children of veil-search so login only needs `app.veil.search`.
/// SketchyBar / borders / rift LaunchAgents are booted out once the host owns them.
@MainActor
final class VeilHost {
    static let shared = VeilHost()

    private var bordersProc: Process?
    private var riftProc: Process?
    private var bordersWanted = false
    private var riftWanted = false
    private var agentsRetired = false
    private var bordersWatch: DispatchSourceProcess?
    private var riftWatch: DispatchSourceProcess?

    /// Full host start (login / recover): retire zoo agents, run borders + rift under us.
    func start() {
        guard !veilIsOff else { stopChrome(); return }
        bordersWanted = true
        riftWanted = true
        retireZooAgentsIfNeeded()
        ensureBorders()
        ensureRift()
    }

    /// `veil off` — drop borders chrome; leave tiling (Rift) running.
    func stopChrome() {
        bordersWanted = false
        stopBorders()
    }

    /// Theme apply — refresh border colors from generated bordersrc.
    func reloadBorders() {
        guard bordersWanted, !veilIsOff else { return }
        stopBorders()
        ensureBorders()
    }

    /// Explicit stop of supervised Rift (`veil quit`).
    func stopRift() {
        riftWanted = false
        terminate(&riftProc, watch: &riftWatch)
    }

    func stopAll() {
        bordersWanted = false
        riftWanted = false
        stopBorders()
        stopRift()
    }

    // MARK: - Agents

    /// Boot out SketchyBar / borders / Rift LaunchAgents so only `app.veil.search` remains.
    private func retireZooAgentsIfNeeded() {
        guard !agentsRetired else {
            // Still reap stragglers if something relaunched them.
            if VeilFeature.veilBar { killMatching("sketchybar") }
            killMatching("borders")
            return
        }
        agentsRetired = true
        let uid = getuid()
        for label in ["app.veil.sketchybar", "app.veil.borders", "git.acsandmann.rift"] {
            launchctl(["bootout", "gui/\(uid)/\(label)"])
        }
        // Rift's own service helper may reinstall — uninstall so we own the binary.
        let rift = Process()
        rift.executableURL = URL(fileURLWithPath: home + "/.local/bin/rift")
        rift.arguments = ["service", "uninstall"]
        rift.standardOutput = FileHandle.nullDevice
        rift.standardError = FileHandle.nullDevice
        try? rift.run()
        rift.waitUntilExit()
        if VeilFeature.veilBar { killMatching("sketchybar") }
        // Kill launchd-owned borders/rift so we can respawn as children (not double).
        killMatching("borders")
        // Don't kill our own future child — only foreign rift before we spawn.
        if riftProc == nil { killMatching("rift") }
    }

    // MARK: - Borders

    private func ensureBorders() {
        guard bordersWanted, !veilIsOff else { return }
        if let p = bordersProc, p.isRunning { return }
        stopBorders()
        let script = home + "/.config/borders/bordersrc"
        let bin = "/opt/homebrew/bin/borders"
        let p = Process()
        if FileManager.default.isExecutableFile(atPath: script) {
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [script]
        } else if FileManager.default.isExecutableFile(atPath: bin) {
            // Fallback when bordersrc missing — theme apply should have written it.
            let pal = Palette.load()
            let style = pal.s("border_style", "round")
            let width = pal.s("border_width", "1.0")
            let active = pal.s("border_active", "0xffd71921")
            let inactive = pal.s("border_inactive", "0x00000000")
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = [
                "style=\(style)", "width=\(width)", "hidpi=off", "ax_focus=on", "order=below",
                "background_color=0x00000000", "active_color=\(active)", "inactive_color=\(inactive)",
                "blacklist=Veil Search"
            ]
        } else {
            return
        }
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.bordersProc === proc { self.bordersProc = nil }
                if self.bordersWanted, !veilIsOff {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.ensureBorders() }
                }
            }
        }
        do {
            try p.run()
            bordersProc = p
        } catch {
            bordersProc = nil
        }
    }

    private func stopBorders() {
        terminate(&bordersProc, watch: &bordersWatch)
        killMatching("borders")
    }

    // MARK: - Rift

    private func ensureRift() {
        guard riftWanted else { return }
        if let p = riftProc, p.isRunning { return }
        // Take ownership: kill launchd/manual copies, then spawn as our child.
        terminate(&riftProc, watch: &riftWatch)
        killMatching("rift")
        let bin = home + "/.local/bin/rift"
        guard FileManager.default.isExecutableFile(atPath: bin) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = []
        p.environment = [
            "PATH": "\(home)/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "RUST_LOG": "error,warn,info",
            "HOME": home
        ]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.riftProc === proc { self.riftProc = nil }
                if self.riftWanted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.ensureRift() }
                }
            }
        }
        do {
            try p.run()
            riftProc = p
        } catch {
            riftProc = nil
        }
    }

    // MARK: - Helpers

    private func terminate(_ proc: inout Process?, watch: inout DispatchSourceProcess?) {
        watch?.cancel()
        watch = nil
        if let p = proc, p.isRunning {
            p.terminationHandler = nil
            p.terminate()
            // Give it a beat; escalate if needed.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                if p.isRunning { p.interrupt() }
            }
        }
        proc = nil
    }

    private func killMatching(_ name: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments = ["-x", name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    private func pgrep(_ name: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-xq", name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func launchctl(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }
}
