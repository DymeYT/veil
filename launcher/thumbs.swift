import AppKit
import Foundation
import ScreenCaptureKit

/// One-shot window thumbnail helper. Runs ScreenCaptureKit in a short-lived
/// process so veil-search does not keep the SCK RSS floor after Overview closes.
///
/// Usage: veil-thumbs OUT_DIR WINDOW_ID [WINDOW_ID...]
/// Writes OUT_DIR/<id>.png for each successful capture, then exits.
@main
enum VeilThumbs {
    static func main() async {
        // ScreenCaptureKit needs a WindowServer connection; touch NSApp first.
        _ = NSApplication.shared
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 2 else {
            fputs("usage: veil-thumbs OUT_DIR WINDOW_ID...\n", stderr)
            exit(2)
        }
        let outDir = args[0]
        let ids: [CGWindowID] = args.dropFirst().compactMap { UInt32($0).map { CGWindowID($0) } }
        guard !ids.isEmpty else { exit(0) }
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let maxSide: CGFloat = 96
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            for id in ids {
                guard let window = content.windows.first(where: { $0.windowID == id }) else { continue }
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                let scale = max(window.frame.width, window.frame.height) > 0
                    ? min(1, maxSide / max(window.frame.width, window.frame.height))
                    : 0.2
                config.width = max(2, Int(window.frame.width * scale))
                config.height = max(2, Int(window.frame.height * scale))
                config.showsCursor = false
                config.captureResolution = .nominal
                guard let cg = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { continue }
                let rep = NSBitmapImageRep(cgImage: cg)
                guard let png = rep.representation(using: .png, properties: [:]) else { continue }
                let path = (outDir as NSString).appendingPathComponent("\(id).png")
                try? png.write(to: URL(fileURLWithPath: path))
            }
            exit(0)
        } catch {
            exit(1)
        }
    }
}
