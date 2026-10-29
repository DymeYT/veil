// Official NSWorkspace bridge. Scope is connected displays in the current Space;
// this cannot capture hidden Spaces, dynamic providers, or removed wallpaper apps.
// https://developer.apple.com/documentation/appkit/nsworkspace/setdesktopimageurl(_:for:options:)
import AppKit
import CoreGraphics

struct ScreenImage: Codable {
    let uuid: String
    let url: String
    let scaling: Int?
    let clipping: Bool?
    let fill: [Double]?
}
struct Snapshot: Codable {
    let version: Int
    let scope: String
    let screens: [ScreenImage]
}
enum RecoveryError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { if case .invalid(let s) = self { return s } }
}
func screenUUID(_ screen: NSScreen) throws -> String {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
          let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else {
        throw RecoveryError.invalid("Display has no stable UUID")
    }
    return CFUUIDCreateString(nil, uuid) as String
}
func imageURL(_ raw: String) throws -> URL {
    guard let url = URL(string: raw), url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost",
          FileManager.default.isReadableFile(atPath: url.path),
          NSImage(contentsOf: url) != nil else {
        throw RecoveryError.invalid("Wallpaper is not a readable local image")
    }
    return url.standardizedFileURL
}
func snapshot(_ screens: [NSScreen]) throws -> Snapshot {
    guard !screens.isEmpty else { throw RecoveryError.invalid("No connected displays") }
    return Snapshot(version: 1, scope: "connected-displays-current-space", screens: try screens.map { screen in
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            throw RecoveryError.invalid("Current wallpaper has no recoverable image URL")
        }
        let valid = try imageURL(url.absoluteString)
        let opts = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
        let color = (opts[.fillColor] as? NSColor)?.usingColorSpace(.deviceRGB)
        return ScreenImage(uuid: try screenUUID(screen), url: valid.absoluteString,
                           scaling: (opts[.imageScaling] as? NSNumber)?.intValue,
                           clipping: (opts[.allowClipping] as? NSNumber)?.boolValue,
                           fill: color.map { [Double($0.redComponent), Double($0.greenComponent), Double($0.blueComponent), Double($0.alphaComponent)] })
    })
}
func options(_ entry: ScreenImage) throws -> [NSWorkspace.DesktopImageOptionKey: Any] {
    var out: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
    if let s = entry.scaling {
        guard (0...3).contains(s) else { throw RecoveryError.invalid("Invalid wallpaper scaling") }
        out[.imageScaling] = s
    }
    if let c = entry.clipping { out[.allowClipping] = c }
    if let rgba = entry.fill {
        guard rgba.count == 4, rgba.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw RecoveryError.invalid("Invalid wallpaper fill color")
        }
        out[.fillColor] = NSColor(deviceRed: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
    }
    return out
}
func restore(_ saved: Snapshot, _ screens: [NSScreen]) throws {
    guard saved.version == 1, saved.scope == "connected-displays-current-space", !saved.screens.isEmpty else {
        throw RecoveryError.invalid("Unsupported or empty wallpaper snapshot")
    }
    var connected: [String: NSScreen] = [:]
    for screen in screens { connected[try screenUUID(screen)] = screen }
    let ids = saved.screens.map(\.uuid)
    guard Set(ids).count == ids.count, Set(ids) == Set(connected.keys) else {
        throw RecoveryError.invalid("Connected display UUIDs differ; no wallpaper was changed")
    }
    // Validate every image and option before touching any display.
    let prepared = try saved.screens.map { (entry: $0, url: try imageURL($0.url), options: try options($0)) }
    let previous = try snapshot(screens)
    do {
        for row in prepared {
            try NSWorkspace.shared.setDesktopImageURL(row.url, for: connected[row.entry.uuid]!, options: row.options)
        }
        for row in prepared {
            guard NSWorkspace.shared.desktopImageURL(for: connected[row.entry.uuid]!)?.standardizedFileURL == row.url else {
                throw RecoveryError.invalid("Wallpaper URL readback did not match")
            }
        }
    } catch {
        var failures: [String] = []
        for row in previous.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(try imageURL(row.url), for: connected[row.uuid]!, options: try options(row))
            } catch { failures.append(row.uuid) }
        }
        throw RecoveryError.invalid("Wallpaper restore failed: \(error). Rollback failures: \(failures.joined(separator: ", "))")
    }
}

do {
    // AppKit desktop-image APIs must run on the main thread.
    precondition(Thread.isMainThread)
    let args = CommandLine.arguments
    if args.count == 2 && args[1] == "capture" {
        FileHandle.standardOutput.write(try JSONEncoder().encode(snapshot(NSScreen.screens)))
    } else if args.count == 3 && args[1] == "restore" {
        let saved = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
        try restore(saved, NSScreen.screens)
        print("Restored connected displays in the current Space; hidden Spaces/providers are not certified")
    } else {
        throw RecoveryError.invalid("usage: veil-wallpaper capture | restore SNAPSHOT.json")
    }
} catch {
    FileHandle.standardError.write(Data("veil-wallpaper: \(error)\n".utf8))
    exit(1)
}
