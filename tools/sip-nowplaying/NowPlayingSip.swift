import Foundation

// Veil SIP-gated Now Playing CLI.
// Links MediaRemote via dlopen (private framework). With SIP + AMFI on, calls may
// fail; keep `cider-bridge` / media-control as the overnight path. After SIP is off
// and this binary is signed with the bundled entitlements, `veil feature enable
// sip-nowplaying` prefers this helper for get/control without AppleScript.

typealias MRGetInfo = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
typealias MRSendCommand = @convention(c) (UInt32, CFDictionary?) -> Bool

enum Command: UInt32 {
    case play = 0
    case pause = 1
    case toggle = 2
    case stop = 3
    case next = 4
    case previous = 5
}

func loadMediaRemote() -> (MRGetInfo, MRSendCommand)? {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else {
        fputs("veil-nowplaying-sip: dlopen MediaRemote failed\n", stderr)
        return nil
    }
    guard
        let getSym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
        let sendSym = dlsym(handle, "MRMediaRemoteSendCommand")
    else {
        fputs("veil-nowplaying-sip: missing MediaRemote symbols\n", stderr)
        return nil
    }
    return (
        unsafeBitCast(getSym, to: MRGetInfo.self),
        unsafeBitCast(sendSym, to: MRSendCommand.self)
    )
}

func sipEnabled() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
    task.arguments = ["status"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    try? task.run()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let text = String(data: data, encoding: .utf8) ?? ""
    return text.lowercased().contains("enabled")
}

func nowPlayingJSON(getInfo: MRGetInfo) -> [String: Any]? {
    let sem = DispatchSemaphore(value: 0)
    var result: [String: Any]?
    getInfo(DispatchQueue.global(qos: .userInitiated)) { dict in
        defer { sem.signal() }
        guard let dict = dict as? [String: Any] else { return }
        var out: [String: Any] = [:]
        // Keys are CFString private constants; use string bridging of known names.
        for (key, value) in dict {
            let k = String(describing: key)
            if k.contains("Title") || k.hasSuffix("title") { out["title"] = "\(value)" }
            else if k.contains("Artist") { out["artist"] = "\(value)" }
            else if k.contains("Album") && !k.contains("AlbumArtist") { out["album"] = "\(value)" }
            else if k.contains("Bundle") { out["bundleIdentifier"] = "\(value)" }
            else if k.contains("PlaybackRate") {
                if let n = value as? NSNumber { out["playbackRate"] = n.doubleValue }
            }
        }
        // Fallback: dump raw string keys when private key names differ by OS.
        if out["title"] == nil {
            for (key, value) in dict {
                let name = "\(key)"
                if name.localizedCaseInsensitiveContains("title") { out["title"] = "\(value)" }
                if name.localizedCaseInsensitiveContains("artist") && out["artist"] == nil { out["artist"] = "\(value)" }
                if name.localizedCaseInsensitiveContains("album") && out["album"] == nil { out["album"] = "\(value)" }
                if name.localizedCaseInsensitiveContains("bundle") && out["bundleIdentifier"] == nil {
                    out["bundleIdentifier"] = "\(value)"
                }
            }
        }
        let rate = (out["playbackRate"] as? Double) ?? 0
        out["playing"] = rate > 0.01
        result = out
    }
    _ = sem.wait(timeout: .now() + 2)
    return result
}

func usage() {
    fputs("""
    usage: veil-nowplaying-sip get|play|pause|toggle|next|previous|status
      status  print sip=on/off and whether MediaRemote loaded
      get     JSON now-playing (empty object if unavailable)
      play|pause|toggle|next|previous  send MediaRemote command

    """, stderr)
}

let args = CommandLine.arguments.dropFirst()
let verb = args.first ?? "status"

guard let (getInfo, send) = loadMediaRemote() else {
    exit(2)
}

switch verb {
case "status":
    let sip = sipEnabled()
    print("sip=\(sip ? "enabled" : "disabled") mediaremote=ok")
    if sip {
        print("note: with SIP enabled this helper may be blocked by AMFI; overnight path uses media-control")
    }
case "get":
    if let info = nowPlayingJSON(getInfo: getInfo),
       let data = try? JSONSerialization.data(withJSONObject: info, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) {
        print(text)
    } else {
        print("{}")
        exit(1)
    }
case "play":
    exit(send(Command.play.rawValue, nil) ? 0 : 1)
case "pause":
    exit(send(Command.pause.rawValue, nil) ? 0 : 1)
case "toggle", "playpause":
    exit(send(Command.toggle.rawValue, nil) ? 0 : 1)
case "next":
    exit(send(Command.next.rawValue, nil) ? 0 : 1)
case "previous":
    exit(send(Command.previous.rawValue, nil) ? 0 : 1)
default:
    usage()
    exit(64)
}
