// Veil on/off. `veil off` stops the rice and posts app.veil.search.mode "off": Veil Search then steps aside
// (no ⌘Space, overlays, notch band or focus effects) and brings back windows Rift had parked off-screen.
// ⌃⌥⌘V toggles from anywhere, so the way back never depends on the parts that were switched off.
import AppKit
import ApplicationServices

var veilIsOff: Bool { FileManager.default.fileExists(atPath: home + "/.config/veil/generated/off") }

enum VeilMode {
    static func toggle() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: home + "/.local/bin/veil")
        p.arguments = ["toggle"]
        p.environment = ProcessInfo.processInfo.environment.merging(["PATH": home + "/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"]) { $1 }
        try? p.run()
    }

    /// Rift parks other workspaces' windows in a display's bottom-right corner, and they stay there when it stops.
    /// Any window showing less than a sliver on every screen is brought back in a cascade.
    static func unparkWindows() {
        guard let primary = NSScreen.screens.first else { return }
        // screens in AX coordinates (top-left origin of the primary display)
        let screens = NSScreen.screens.map { CGRect(x: $0.frame.minX, y: primary.frame.maxY - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        let main = screens[0]
        var k: CGFloat = 0
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            var wins: CFTypeRef?
            guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute as CFString, &wins) == .success,
                  let list = wins as? [AXUIElement] else { continue }
            for w in list {
                var posV: CFTypeRef?, sizeV: CFTypeRef?, minimized: CFTypeRef?
                AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimized)
                if (minimized as? Bool) == true { continue }
                AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &posV)
                AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &sizeV)
                var pos = CGPoint.zero, size = CGSize.zero
                guard let posV, let sizeV, CFGetTypeID(posV) == AXValueGetTypeID(), CFGetTypeID(sizeV) == AXValueGetTypeID(),
                      AXValueGetValue(posV as! AXValue, .cgPoint, &pos), AXValueGetValue(sizeV as! AXValue, .cgSize, &size) else { continue }
                let rect = CGRect(origin: pos, size: size)
                let visible = screens.map { $0.intersection(rect) }.filter { !$0.isNull }
                if visible.contains(where: { $0.width >= 100 && $0.height >= 100 }) { continue }
                var newSize = CGSize(width: min(size.width, main.width * 0.8), height: min(size.height, main.height * 0.8))
                var newPos = CGPoint(x: main.minX + 80 + k * 28, y: main.minY + 80 + k * 28)
                k = (k + 1).truncatingRemainder(dividingBy: 10)
                if let v = AXValueCreate(.cgSize, &newSize) { AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, v) }
                if let v = AXValueCreate(.cgPoint, &newPos) { AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, v) }
            }
        }
    }
}
