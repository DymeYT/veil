// Veil on/off. `veil off` stops the rice (all but Rift) and posts app.veil.search.mode "off": Veil Search then
// steps aside (no ⌘Space, overlays, notch band or focus effects).
// ⌃⌥⌘V toggles from anywhere, so the way back never depends on the parts that were switched off.
import AppKit

var veilIsOff: Bool { FileManager.default.fileExists(atPath: home + "/.config/veil/generated/off") }

enum VeilMode {
    static func toggle() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: home + "/.local/bin/veil")
        p.arguments = ["toggle"]
        p.environment = ProcessInfo.processInfo.environment.merging(["PATH": home + "/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"]) { $1 }
        try? p.run()
    }
}
