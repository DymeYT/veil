import Foundation

// Veil SIP-gated Now Playing CLI.
// Default sign: library-validation bypass only (runs under SIP-off without AMFI boot-arg).
// Direct MRMediaRemoteGetNowPlayingInfo often returns nil without the private entitlement;
// when that happens, `get` falls back to Homebrew `media-control` (MediaRemoteAdapter).
// Optional hard sign: VEIL_SIP_PRIVATE_ENTITLEMENTS=1 ./build.sh (needs AMFI relaxed).

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

func mediaControlPath() -> String? {
    let candidates = [
        "/opt/homebrew/bin/media-control",
        "/usr/local/bin/media-control",
    ]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

func runMediaControl(_ arguments: [String]) -> (Int32, Data) {
    guard let bin = mediaControlPath() else { return (127, Data()) }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: bin)
    task.arguments = arguments
    let out = Pipe()
    let err = Pipe()
    task.standardOutput = out
    task.standardError = err
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        return (127, Data())
    }
    return (task.terminationStatus, out.fileHandleForReading.readDataToEndOfFile())
}

func nowPlayingFromMediaControl() -> [String: Any]? {
    let (ec, data) = runMediaControl(["get", "--no-artwork"])
    guard ec == 0, !data.isEmpty,
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          obj["title"] != nil || obj["name"] != nil
    else { return nil }
    var out: [String: Any] = [:]
    if let t = obj["title"] ?? obj["name"] { out["title"] = "\(t)" }
    if let a = obj["artist"] ?? obj["artistName"] { out["artist"] = "\(a)" }
    if let al = obj["album"] ?? obj["albumName"] { out["album"] = "\(al)" }
    if let b = obj["bundleIdentifier"] ?? obj["bundleID"] { out["bundleIdentifier"] = "\(b)" }
    let playing =
        (obj["playing"] as? Bool) == true
        || (obj["isPlaying"] as? Bool) == true
        || ((obj["playbackRate"] as? NSNumber)?.doubleValue ?? 0) > 0.01
    out["playing"] = playing
    out["playbackRate"] = playing ? 1.0 : 0.0
    out["via"] = "media-control"
    return out
}

func nowPlayingJSON(getInfo: MRGetInfo) -> [String: Any]? {
    let sem = DispatchSemaphore(value: 0)
    var result: [String: Any]?
    getInfo(DispatchQueue.global(qos: .userInitiated)) { dict in
        defer { sem.signal() }
        guard let dict = dict as? [String: Any], !dict.isEmpty else { return }
        var out: [String: Any] = [:]
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
        guard out["title"] != nil else { return }
        let rate = (out["playbackRate"] as? Double) ?? 0
        out["playing"] = rate > 0.01
        out["via"] = "mediaremote"
        result = out
    }
    _ = sem.wait(timeout: .now() + 2)
    if let result { return result }
    return nowPlayingFromMediaControl()
}

func usage() {
    fputs("""
    usage: veil-nowplaying-sip get|play|pause|toggle|next|previous|status
      status  print sip=on/off and whether MediaRemote loaded
      get     JSON now-playing (MediaRemote, else media-control adapter)
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
    let adapter = mediaControlPath() != nil ? "ok" : "missing"
    print("sip=\(sip ? "enabled" : "disabled") mediaremote=ok adapter=\(adapter)")
    if sip {
        print("note: with SIP enabled prefer media-control; soft-signed helper still builds")
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
