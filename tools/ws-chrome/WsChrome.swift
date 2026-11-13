import Foundation

/// VEI-41: window-server chrome experiment (SIP-off safe, soft-signed).
/// Thickens JankyBorders focus ring when enabled. Default OFF.
/// Never ScreenSaverEngine.

@main
enum WsChrome {
    static var root: String { NSString(string: "~/.config/veil").expandingTildeInPath }
    static var flag: String { root + "/generated/features/enable-ws-chrome" }
    static var backup: String { root + "/generated/ws-chrome-bordersrc.bak" }
    static var bordersrc: String { NSString(string: "~/.config/borders/bordersrc").expandingTildeInPath }

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        switch args.first ?? "status" {
        case "status":
            let on = FileManager.default.fileExists(atPath: flag)
            print("ws-chrome=\(on ? "on" : "off")")
            if let text = try? String(contentsOfFile: bordersrc, encoding: .utf8),
               let w = text.range(of: #"width=[0-9.]+"#, options: .regularExpression) {
                print(String(text[w]))
            }
        case "apply", "enable":
            try? FileManager.default.createDirectory(
                atPath: root + "/generated/features", withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: flag, contents: Data(), attributes: nil)
            if !FileManager.default.fileExists(atPath: backup),
               let orig = try? String(contentsOfFile: bordersrc, encoding: .utf8) {
                try? orig.write(toFile: backup, atomically: true, encoding: .utf8)
            }
            guard var text = try? String(contentsOfFile: bordersrc, encoding: .utf8) else {
                fputs("bordersrc missing\n", stderr); exit(1)
            }
            if let r = text.range(of: #"width=[0-9.]+"#, options: .regularExpression) {
                text.replaceSubrange(r, with: "width=8.0")
            } else {
                text = text.replacingOccurrences(of: "borders ", with: "borders width=8.0 ")
            }
            if !text.contains("ax_focus=on") {
                text = text.replacingOccurrences(of: "borders ", with: "borders ax_focus=on ")
            }
            try? text.write(toFile: bordersrc, atomically: true, encoding: .utf8)
            restartBorders()
            print("ws-chrome=on width=8.0")
        case "clear", "disable":
            try? FileManager.default.removeItem(atPath: flag)
            if let orig = try? String(contentsOfFile: backup, encoding: .utf8) {
                try? orig.write(toFile: bordersrc, atomically: true, encoding: .utf8)
                try? FileManager.default.removeItem(atPath: backup)
            } else if var text = try? String(contentsOfFile: bordersrc, encoding: .utf8),
                      let r = text.range(of: #"width=[0-9.]+"#, options: .regularExpression) {
                text.replaceSubrange(r, with: "width=1.5")
                try? text.write(toFile: bordersrc, atomically: true, encoding: .utf8)
            }
            restartBorders()
            print("ws-chrome=off")
        default:
            fputs("usage: veil-ws-chrome status|enable|disable\n", stderr)
            exit(64)
        }
    }

    static func restartBorders() {
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-x", "borders"]
        try? pkill.run()
        pkill.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.25)
        let run = Process()
        run.executableURL = URL(fileURLWithPath: "/bin/bash")
        run.arguments = [bordersrc]
        try? run.run()
        Thread.sleep(forTimeInterval: 0.4)
    }
}
