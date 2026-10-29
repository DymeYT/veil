// Launcher sources and actions beyond Spotlight: ⌘K secondary actions, window switcher, folder browsing,
// Cursor recent projects, browser bookmarks, emoji, developer utilities and typo tolerance.
// All read on demand while the panel is open; nothing runs while it is hidden. No permission prompts.
import AppKit
import CryptoKit
import SQLite3

// URLs built from typed text never crash: encode, and fall back to a harmless URL
func safeURL(_ s: String) -> URL {
    URL(string: s) ?? URL(string: s.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "") ?? URL(string: "about:blank")!
}
func dictURL(_ term: String) -> URL { safeURL("dict://" + (term.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")) }

// MARK: typo tolerance (used by score() for 4+ character queries)

// Every query letter appears in order, starting at the beginning of a word: "sfri" -> Safari
func wordSubsequence(_ q: String, _ n: String) -> Bool {
    guard let first = q.first, n.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.first == first }) else { return false }
    var i = q.startIndex
    for ch in n where i < q.endIndex && ch == q[i] { i = q.index(after: i) }
    return i == q.endIndex
}

// One edit (insert, delete, substitute or swap neighbours) between the query and a word's prefix: "saafri", "sfaari"
func withinOneEdit(_ a: String, _ b: String) -> Bool {
    let a = Array(a), b = Array(b)
    guard a.first == b.first else { return false }  // typos keep the first letter; "uuid" must not match "guid"
    if abs(a.count - b.count) > 1 { return false }
    var i = 0, j = 0, edits = 0
    while i < a.count && j < b.count {
        if a[i] == b[j] { i += 1; j += 1; continue }
        edits += 1
        if edits > 1 { return false }
        if i + 1 < a.count && j + 1 < b.count && a[i] == b[j + 1] && a[i + 1] == b[j] { i += 2; j += 2; continue }  // swap
        if a.count > b.count { i += 1 } else if a.count < b.count { j += 1 } else { i += 1; j += 1 }
    }
    return edits + (a.count - i) + (b.count - j) <= 1
}

// MARK: ⌘K secondary actions

struct SecondaryAction: Identifiable {
    let title: String
    let keys: String
    let symbol: String
    let run: () -> Void
    var id: String { title }
}

func shell(_ argv: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: argv[0])
    p.arguments = Array(argv.dropFirst())
    p.environment = ProcessInfo.processInfo.environment.merging(["PATH": binPath]) { $1 }
    try? p.run()
}

func copyText(_ s: String, secret: Bool = false) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(s, forType: .string)
    if secret {  // nspasteboard.org convention: clipboard managers (including ours) skip it
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    } else {
        ClipHistory.shared.capture(from: "Veil Search")
    }
}

func secondaryActions(_ it: Item, quickLook: @escaping () -> Void) -> [SecondaryAction] {
    var out: [SecondaryAction] = []
    if let path = it.path {
        let url = URL(fileURLWithPath: path)
        let isApp = path.hasSuffix(".app")
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        out.append(SecondaryAction(title: "Show in Finder", keys: "⌘↵", symbol: "folder") { NSWorkspace.shared.activateFileViewerSelecting([url]) })
        if !isApp { out.append(SecondaryAction(title: "Quick Look", keys: "⌘Y", symbol: "eye", run: quickLook)) }
        out.append(SecondaryAction(title: "Copy Path", keys: "⌘C", symbol: "doc.on.doc") { copyText(path) })
        out.append(SecondaryAction(title: "Copy as File", keys: "", symbol: "doc.on.clipboard") {
            NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([url as NSURL])
        })
        if !isApp {
            for app in NSWorkspace.shared.urlsForApplications(toOpen: url).prefix(4) {
                let name = app.deletingPathExtension().lastPathComponent
                out.append(SecondaryAction(title: "Open with \(name)", keys: "", symbol: "arrow.up.forward.app") {
                    NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                })
            }
        }
        let folder = isDir.boolValue && !isApp ? path : (path as NSString).deletingLastPathComponent
        if !isApp {
            out.append(SecondaryAction(title: "Open Terminal Here", keys: "", symbol: "terminal") {
                shell(["/usr/bin/open", "-na", "Ghostty.app", "--args", "--working-directory=\(folder)"])
            })
        }
        if FileManager.default.fileExists(atPath: "/Applications/Cursor.app") && !isApp {
            out.append(SecondaryAction(title: "Open in Cursor", keys: "", symbol: "chevron.left.forwardslash.chevron.right") {
                shell(["/usr/bin/open", "-a", "Cursor", path])
            })
        }
        if !isApp {
            out.append(SecondaryAction(title: "Compress", keys: "", symbol: "archivebox") {
                shell(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", path, path + ".zip"])
            })
            out.append(SecondaryAction(title: "Move to Trash", keys: "⌘⌫", symbol: "trash") { NSWorkspace.shared.recycle([url]) })
        }
        if isApp, let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == path }) {
            out.append(SecondaryAction(title: "Hide", keys: "", symbol: "eye.slash") { running.hide() })
            out.append(SecondaryAction(title: "Quit", keys: "", symbol: "xmark.circle") { running.terminate() })
        }
    } else {
        switch it.action {
        case .open(let url): out.append(SecondaryAction(title: "Copy Link", keys: "⌘C", symbol: "link") { copyText(url.absoluteString) })
        case .copy(let s): out.append(SecondaryAction(title: "Copy", keys: "⌘C", symbol: "doc.on.doc") { copyText(s) })
        case .run: break
        }
        out.append(SecondaryAction(title: "Copy Title", keys: "", symbol: "textformat") { copyText(it.title) })
    }
    out.append(SecondaryAction(title: "Pin to Start Screen", keys: "⌘P", symbol: "pin") {
        var pins = UserDefaults.standard.stringArray(forKey: "pins") ?? []
        if !pins.contains(it.key) { pins.insert(it.key, at: 0); UserDefaults.standard.set(pins, forKey: "pins") }
    })
    out.append(SecondaryAction(title: "Large Type", keys: "⌘L", symbol: "textformat.size") {
        DispatchQueue.main.async { (NSApp.delegate as? App)?.largeTypeText(it) }
    })
    return out
}

// MARK: window switcher (Rift already knows every window; no Screen Recording needed)

func windowItems() -> [Item] {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: home + "/.local/bin/rift-cli")
    p.arguments = ["query", "workspaces"]
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return [] }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    var out: [Item] = []
    for ws in list {
        let wsName = ws["name"] as? String ?? ""
        for w in (ws["windows"] as? [[String: Any]]) ?? [] {
            guard let id = w["id"] as? [String: Any], let idData = try? JSONSerialization.data(withJSONObject: id),
                  let idJSON = String(data: idData, encoding: .utf8) else { continue }
            let app = w["app_name"] as? String ?? "", title = w["title"] as? String ?? ""
            let bundle = (w["bundle_id"] as? String).flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.path }
            out.append(Item(kind: .action, title: title.isEmpty ? app : title, subtitle: "\(app) · \(wsName)", symbol: "macwindow",
                            path: bundle, action: .run([home + "/.local/bin/rift-cli", "execute", "window", "focus", "--window-id", idJSON]),
                            score: -120, extra: "window"))
        }
    }
    return out
}

// MARK: folder browsing ("~/Dev", "/Applications")

func folderItems(_ q: String) -> [Item]? {
    guard q.hasPrefix("~") || q.hasPrefix("/") else { return nil }
    let expanded = (q as NSString).expandingTildeInPath
    let dir: String, filter: String
    if q.hasSuffix("/") { dir = expanded; filter = "" } else { dir = (expanded as NSString).deletingLastPathComponent; filter = (expanded as NSString).lastPathComponent.lowercased() }
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
    let entries = names.filter { !$0.hasPrefix(".") && (filter.isEmpty || $0.lowercased().contains(filter)) }
        .sorted { a, b in
            let pa = filter.isEmpty ? 0 : (a.lowercased().hasPrefix(filter) ? 0 : 1), pb = filter.isEmpty ? 0 : (b.lowercased().hasPrefix(filter) ? 0 : 1)
            return (pa, a.lowercased()) < (pb, b.lowercased())
        }
    return entries.prefix(40).map { name in
        let path = (dir as NSString).appendingPathComponent(name)
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return Item(kind: .file, title: name, subtitle: (dir as NSString).abbreviatingWithTildeInPath, symbol: isDir.boolValue ? "folder" : "doc",
                    path: path, action: .open(URL(fileURLWithPath: path)), score: 900, extra: isDir.boolValue && !name.hasSuffix(".app") ? "dir" : "")
    }
}

// MARK: Cursor recent projects (read-only SQLite; no permission needed)

func cursorProjects() -> [Item] {
    let db = home + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    guard FileManager.default.fileExists(atPath: db) else { return [] }
    var handle: OpaquePointer?
    guard sqlite3_open_v2("file:\(db)?immutable=1", &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_close(handle) }
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(handle, "SELECT value FROM ItemTable WHERE key='history.recentlyOpenedPathsList'", -1, &stmt, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_finalize(stmt) }
    guard sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0),
          let o = try? JSONSerialization.jsonObject(with: Data(String(cString: c).utf8)) as? [String: Any],
          let entries = o["entries"] as? [[String: Any]] else { return [] }
    return entries.prefix(30).compactMap { e in
        guard let uri = (e["folderUri"] ?? e["fileUri"]) as? String, let url = URL(string: uri), url.isFileURL else { return nil }
        let path = url.path
        return Item(kind: .action, title: url.lastPathComponent, subtitle: "Cursor · \((path as NSString).deletingLastPathComponent as NSString)".replacingOccurrences(of: home, with: "~"),
                    symbol: "chevron.left.forwardslash.chevron.right", action: .run(["/usr/bin/open", "-a", "Cursor", path]), score: -80, extra: "project")
    }
}

// MARK: browser bookmarks (Chrome JSON, Arc sidebar JSON; Safari's file needs Full Disk Access, so it is skipped)

func bookmarkItems() -> [Item] {
    var out: [Item] = []
    func add(_ title: String, _ url: String, _ source: String) {
        guard let u = URL(string: url), ["http", "https"].contains(u.scheme ?? "") else { return }
        out.append(Item(kind: .web, title: title.isEmpty ? (u.host ?? url) : title, subtitle: "\(source) bookmark · \(u.host ?? "")",
                        symbol: "bookmark", action: .open(u), score: -100, extra: url))
    }
    let chrome = home + "/Library/Application Support/Google/Chrome/Default/Bookmarks"
    if let d = FileManager.default.contents(atPath: chrome), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
       let roots = o["roots"] as? [String: Any] {
        func walk(_ n: Any) {
            guard let n = n as? [String: Any] else { return }
            if n["type"] as? String == "url" { add(n["name"] as? String ?? "", n["url"] as? String ?? "", "Chrome") }
            (n["children"] as? [Any])?.forEach(walk)
        }
        roots.values.forEach(walk)
    }
    let arc = home + "/Library/Application Support/Arc/StorableSidebar.json"
    if let d = FileManager.default.contents(atPath: arc), let o = try? JSONSerialization.jsonObject(with: d) {
        func walk(_ n: Any) {
            if let dict = n as? [String: Any] {
                if let tab = (dict["data"] as? [String: Any])?["tab"] as? [String: Any], let url = tab["savedURL"] as? String {
                    add((dict["title"] as? String) ?? (tab["savedTitle"] as? String ?? ""), url, "Arc")
                }
                dict.values.forEach(walk)
            } else if let arr = n as? [Any] { arr.forEach(walk) }
        }
        walk(o)
    }
    var seen = Set<String>()
    return out.filter { seen.insert($0.extra).inserted }
}

// MARK: emoji (":fire", "emoji heart"); names come from Unicode itself, built once on first use

nonisolated(unsafe) var emojiTable: [(String, String)] = []

func emojiItems(_ q: String) -> [Item]? {
    let l = q.lowercased()
    let term: String
    if l.hasPrefix(":") { term = String(l.dropFirst()) } else if l.hasPrefix("emoji ") { term = String(l.dropFirst(6)) } else { return nil }
    if emojiTable.isEmpty {
        for range in [0x1F300...0x1FAFF, 0x2600...0x27BF] {
            for v in range {
                guard let s = Unicode.Scalar(v), s.properties.isEmojiPresentation, let name = s.properties.name else { continue }
                emojiTable.append((String(Character(s)), name.lowercased()))
            }
        }
    }
    let words = term.split(separator: " ").map(String.init)
    return emojiTable.filter { e in words.allSatisfy { e.1.contains($0) } }.prefix(24).map {
        Item(kind: .answer, title: $0.1.capitalized, subtitle: "Emoji   ↵ copies", symbol: "face.smiling", action: .copy($0.0), score: 1950, extra: "emoji:" + $0.0)
    }
}

// MARK: developer utilities (pure functions; the clipboard is read only when one of these is chosen)

func utilityAnswers(_ q: String) -> [Item] {
    var out: [Item] = []
    let l = q.lowercased().trimmingCharacters(in: .whitespaces)
    func answer(_ title: String, _ sub: String, _ sym: String, _ value: String) {
        out.append(Item(kind: .answer, title: title, subtitle: sub + "   ↵ copies", symbol: sym, action: .copy(value), score: 1900))
    }
    if l == "uuid" { let u = UUID().uuidString; answer(u, "New UUID", "number", u) }
    if l.hasPrefix("random") {
        let n = l.split(separator: " ").compactMap { Int($0) }
        let lo = n.count == 2 ? n[0] : 1, hi = n.count == 2 ? n[1] : (n.first ?? 100)
        if lo <= hi { let r = String(Int.random(in: lo...hi)); answer(r, "Random number \(lo)–\(hi)", "dice", r) }
    }
    if l == "password" || l.hasPrefix("password ") {
        let len = Int(l.split(separator: " ").last ?? "") ?? 20
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_!@#%")
        var pw = ""
        let limit = 256 - 256 % chars.count  // rejection sampling: no modulo bias
        while pw.count < max(8, min(len, 64)) {
            var b: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &b)
            if Int(b) < limit { pw.append(chars[Int(b) % chars.count]) }
        }
        out.append(Item(kind: .answer, title: String(repeating: "•", count: pw.count), subtitle: "Generated password (\(pw.count) characters) · not kept in history   ↵ copies",
                        symbol: "key", action: .copy(pw), score: 1900, extra: "secret"))
    }
    if let t = Double(l), t > 946_684_800, t < 4_102_444_800 {  // epoch seconds 2000–2100
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .medium
        let s = f.string(from: Date(timeIntervalSince1970: t)); answer(s, "Unix time \(Int(t))", "calendar", s)
    }
    if l == "now" || l == "epoch" { let s = String(Int(Date().timeIntervalSince1970)); answer(s, "Current Unix time", "clock", s) }
    if let r = l.range(of: #"^#?([0-9a-f]{6})$"#, options: .regularExpression), l.hasPrefix("#") {
        let hex = String(l[r]).replacingOccurrences(of: "#", with: "")
        if let v = UInt32(hex, radix: 16) {
            let rr = (v >> 16) & 255, gg = (v >> 8) & 255, bb = v & 255
            let c = NSColor(red: CGFloat(rr) / 255, green: CGFloat(gg) / 255, blue: CGFloat(bb) / 255, alpha: 1)
            let s = "rgb(\(rr), \(gg), \(bb))"
            answer(s, "#\(hex.uppercased()) · hsb(\(Int(c.hueComponent * 360)), \(Int(c.saturationComponent * 100))%, \(Int(c.brightnessComponent * 100))%)", "eyedropper", s)
            out[out.count - 1].extra = "color:" + hex
        }
    }
    for (prefix, name, f) in [("b64 ", "Base64", { (s: String) in Data(s.utf8).base64EncodedString() }),
                              ("unb64 ", "Base64 decoded", { (s: String) in Data(base64Encoded: s).flatMap { String(data: $0, encoding: .utf8) } ?? "" }),
                              ("url ", "URL-encoded", { (s: String) in s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "" }),
                              ("sha256 ", "SHA-256", { (s: String) in SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() })]
        where q.lowercased().hasPrefix(prefix) {
        let v = f(String(q.dropFirst(prefix.count)))
        if !v.isEmpty { answer(v, name, "function", v) }
    }
    // transforms of the current clipboard text, Spotlight's "Change Case" and more
    let transforms: [String: (String, (String) -> String)] = [
        "upper": ("UPPERCASE", { $0.uppercased() }), "lower": ("lowercase", { $0.lowercased() }), "title": ("Title Case", { $0.capitalized }),
        "snake": ("snake_case", { $0.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "_") }),
        "camel": ("camelCase", { s in let w = s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
                     return (w.first ?? "") + w.dropFirst().map { $0.capitalized }.joined() }),
        "json": ("Pretty JSON", { s in (try? JSONSerialization.jsonObject(with: Data(s.utf8))).flatMap {
                     try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys]) }.flatMap { String(data: $0, encoding: .utf8) } ?? "" }),
        "count": ("Count", { s in "\(s.split(whereSeparator: \.isWhitespace).count) words · \(s.count) characters · \(s.split(separator: "\n").count) lines" }),
        "trim": ("Trimmed", { $0.trimmingCharacters(in: .whitespacesAndNewlines) }),
    ]
    if let (name, f) = transforms[l], let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
        let v = f(clip)
        if !v.isEmpty { answer(String(v.prefix(80)), "\(name) of the clipboard", "wand.and.stars", v) }
    }
    return out
}

// MARK: clipboard history (Spotlight 26 parity). The change counter is read once a second; text is kept in memory only.

final class ClipHistory {
    static let shared = ClipHistory()
    struct Clip: Codable { var text: String; var date: Date; var app: String }
    // Kept in memory only (the launcher stays running), never written to disk.
    private(set) var clips: [Clip] = []
    private var lastCount = -1
    private let secretApps: Set<String> = ["Passwords", "1Password", "Bitwarden", "Keychain Access", "LastPass", "Dashlane", "KeePassXC"]
    // things password managers mark as private, plus transient content (nspasteboard.org conventions)
    private let skip: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType"]

    private var timer: Timer?

    init() {
        // remove the file earlier builds wrote
        try? FileManager.default.removeItem(atPath: home + "/Library/Application Support/app.veil.search/clips.json")
    }

    /// Watch the pasteboard's change counter once a second (one integer read; macOS has no copy
    /// notification), so every copy is kept, not just the last one before the launcher opens.
    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.capture() }
        t.tolerance = 0.5  // lets macOS coalesce wakeups
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func capture(from app: String = NSWorkspace.shared.frontmostApplication?.localizedName ?? "") {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCount else { return }
        lastCount = pb.changeCount
        if let types = pb.types, types.contains(where: { skip.contains($0.rawValue) }) { return }
        if secretApps.contains(app) { return }
        clips.removeAll { Date().timeIntervalSince($0.date) > 8 * 3600 }  // eight hours, like Spotlight's shortest setting
        // keep the text exactly as copied (a snippet's indentation and final newline paste back unchanged)
        guard let s = pb.string(forType: .string), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, s.count < 20000 else { return }
        // copying a clip again from Veil Search moves it to the top but keeps the app it first came from
        let source = app == "Veil Search" ? (clips.first { $0.text == s }?.app ?? app) : app
        clips.removeAll { $0.text == s }
        clips.insert(Clip(text: s, date: Date(), app: source), at: 0)
        clips = Array(clips.prefix(200))
    }

    func clear() { clips = [] }

    func items(_ filter: String) -> [Item] {
        let f = filter.lowercased()
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        clips.removeAll { Date().timeIntervalSince($0.date) > 8 * 3600 }
        return clips.filter { f.isEmpty || $0.text.lowercased().contains(f) }.prefix(40).map { c in
            let oneLine = c.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ⏎ ")
            let age = Date().timeIntervalSince(c.date) < 60 ? "just now" : rel.localizedString(for: c.date, relativeTo: Date())
            return Item(kind: .answer, title: String(oneLine.prefix(90)), subtitle: "\(c.app.isEmpty ? "Clipboard" : c.app) · \(age)   ↵ copies",
                        symbol: "doc.on.clipboard", action: .copy(c.text), score: 1000, extra: "clip")
        }
    }
}

// MARK: weather on demand ("weather", "weather tokyo"): Open-Meteo, free, no key, fetched only for this query

final class Weather {
    static let shared = Weather()
    var cache: [String: (Date, Item)] = [:]
    private var loading: Set<String> = []
    private var pending: DispatchWorkItem?
    func answer(_ q: String, refresh: @escaping () -> Void) -> Item? {
        let l = q.lowercased()
        guard l == "weather" || l.hasPrefix("weather ") else { return nil }
        let city = l == "weather" ? (UserDefaults.standard.string(forKey: "weatherCity") ?? TimeZone.current.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? "New York")
                                  : String(l.dropFirst(8)).trimmingCharacters(in: .whitespaces)
        // answers last 30 min; failures ("offline", "no such place") 60 s, so the placeholder never spins forever
        if let (t, item) = cache[city], Date().timeIntervalSince(t) < (item.extra == "weather-failed" ? 60 : 1800) { return item }
        let placeholder = Item(kind: .answer, title: "Weather in \(city.capitalized)…", subtitle: "Fetching from Open-Meteo", symbol: "cloud.sun", action: .copy(""), score: 1900)
        guard !loading.contains(city), let enc = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let geo = URL(string: "https://geocoding-api.open-meteo.com/v1/search?count=1&name=\(enc)") else { return placeholder }
        // only ask once typing pauses: partial city names never leave the Mac
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.fetch(city: city, geo: geo, refresh: refresh) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        return placeholder
    }

    private func fail(_ city: String, _ title: String, refresh: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.loading.remove(city)
            self.cache[city] = (Date(), Item(kind: .answer, title: title, subtitle: "Weather · try again in a minute", symbol: "cloud.slash",
                                             action: .copy(""), score: 1900, extra: "weather-failed"))
            refresh()
        }
    }

    private func fetch(city: String, geo: URL, refresh: @escaping () -> Void) {
        loading.insert(city)
        URLSession.shared.dataTask(with: geo) { d, _, err in
            guard let d else { return self.fail(city, err == nil ? "Weather unavailable" : "Couldn't reach Open-Meteo (offline?)", refresh: refresh) }
            guard let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let r = (o["results"] as? [[String: Any]])?.first,
                  let lat = r["latitude"] as? Double, let lon = r["longitude"] as? Double,
                  let fx = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1") else {
                return self.fail(city, "No place called \(city.capitalized)", refresh: refresh)
            }
            let name = [r["name"] as? String, r["country_code"] as? String].compactMap { $0 }.joined(separator: ", ")
            URLSession.shared.dataTask(with: fx) { d2, _, _ in
                DispatchQueue.main.async {
                    self.loading.remove(city)
                    guard let d2, let o2 = try? JSONSerialization.jsonObject(with: d2) as? [String: Any],
                          let cur = o2["current"] as? [String: Any], let t = cur["temperature_2m"] as? Double else {
                        return self.fail(city, "Weather unavailable for \(city.capitalized)", refresh: refresh)
                    }
                    let code = cur["weather_code"] as? Int ?? 0
                    let (desc, sym) = Weather.describe(code)
                    let daily = o2["daily"] as? [String: Any]
                    let hi = (daily?["temperature_2m_max"] as? [Double])?.first, lo = (daily?["temperature_2m_min"] as? [Double])?.first
                    let useF = Locale.current.measurementSystem == .us
                    func fmt(_ c: Double) -> String { useF ? "\(Int((c * 9 / 5 + 32).rounded()))°F" : "\(Int(c.rounded()))°C" }
                    let range = [hi.map { "H " + fmt($0) }, lo.map { "L " + fmt($0) }].compactMap { $0 }.joined(separator: " · ")
                    let item = Item(kind: .answer, title: "\(fmt(t)) · \(desc)", subtitle: "\(name)   \(range)", symbol: sym,
                                    action: .open(safeURL("https://www.google.com/search?q=weather+\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")), score: 1900)
                    self.cache[city] = (Date(), item)
                    refresh()
                }
            }.resume()
        }.resume()
    }

    static func describe(_ code: Int) -> (String, String) {
        switch code {
        case 0: return ("Clear", "sun.max")
        case 1, 2: return ("Partly cloudy", "cloud.sun")
        case 3: return ("Overcast", "cloud")
        case 45, 48: return ("Fog", "cloud.fog")
        case 51...57: return ("Drizzle", "cloud.drizzle")
        case 61...67, 80...82: return ("Rain", "cloud.rain")
        case 71...77, 85, 86: return ("Snow", "cloud.snow")
        case 95...99: return ("Thunderstorm", "cloud.bolt.rain")
        default: return ("—", "cloud")
        }
    }
}

// MARK: quick keys (~/.config/veil/launcher/aliases.json), Spotlight 26's custom quick keys with arguments
// {"ar": {"shortcut": "Add Reminder"}, "so": {"url": "https://stackoverflow.com/search?q={q}"}, "term": {"open": "/Applications/Ghostty.app"}}

func aliasItems(_ q: String) -> [Item] {
    let map = SourceCache.aliases
    guard !map.isEmpty else { return [] }
    let parts = q.split(separator: " ", maxSplits: 1).map(String.init)
    guard let key = parts.first?.lowercased(), let entry = map[key] else { return [] }
    let arg = parts.count > 1 ? parts[1] : ""
    if let sc = entry["shortcut"] {
        let tmp = NSTemporaryDirectory() + "nc-alias-input.txt"
        try? arg.write(toFile: tmp, atomically: true, encoding: .utf8)
        return [Item(kind: .action, title: arg.isEmpty ? sc : "\(sc): \(arg)", subtitle: "Quick key “\(key)” · Shortcut", symbol: "bolt",
                     action: .run(["/usr/bin/shortcuts", "run", sc, "--input-path", tmp]), score: 2200)]
    }
    if let u = entry["url"], let url = URL(string: u.replacingOccurrences(of: "{q}", with: arg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? arg)) {
        return [Item(kind: .action, title: arg.isEmpty ? u : "\(key): \(arg)", subtitle: "Quick key “\(key)” · \(url.host ?? "")", symbol: "bolt", action: .open(url), score: 2200)]
    }
    if let o = entry["open"] {
        return [Item(kind: .action, title: "Open \((o as NSString).lastPathComponent)", subtitle: "Quick key “\(key)”", symbol: "bolt", path: o,
                     action: .open(URL(fileURLWithPath: (o as NSString).expandingTildeInPath)), score: 2200)]
    }
    return []
}

// MARK: "Show all in Finder" (Spotlight's ⌥⌘Space hand-off): a saved search with the same predicate

func finderSearchItem(_ q: String) -> Item {
    let esc = q.replacingOccurrences(of: "\"", with: "")
    let raw = "(kMDItemFSName == \"*\(esc)*\"cd)"
    let plist: [String: Any] = ["RawQuery": raw, "SearchCriteria": ["FXScopeArrayOfPaths": [home], "CurrentFolderPath": [home]], "Version": 1]
    let path = NSTemporaryDirectory() + "Veil Search.savedSearch"
    let data = (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) ?? Data()
    // the saved search is written only when this row is chosen
    return Item(kind: .web, title: "Show all in Finder", subtitle: "Every file matching “\(q)”", symbol: "magnifyingglass.circle",
                action: .run(["/bin/sh", "-c", "cat > \"$1\" && open \"$1\"", "sh", path]), score: 0, extra: "stdin:" + data.base64EncodedString())
}

// MARK: Obsidian vaults (obsidian.json lists them; notes already come from the Spotlight index)

// Files read once per panel open (SourceCache.reload in show()), never per keystroke.
enum SourceCache {
    nonisolated(unsafe) static var vaults: [(name: String, path: String)] = []
    nonisolated(unsafe) static var aliases: [String: [String: String]] = [:]
    nonisolated(unsafe) static var scripts: [(path: String, name: String, meta: [String: String])] = []
    static func reload() {
        vaults = readVaults()
        let file = ncRoot + "/launcher/aliases.json"
        aliases = (FileManager.default.contents(atPath: file).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: [String: String]] }) ?? [:]
        let dir = ncRoot + "/launcher/scripts"
        scripts = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted().compactMap { n in
            let path = dir + "/" + n
            guard FileManager.default.isExecutableFile(atPath: path), let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
            var meta: [String: String] = [:]
            for line in text.split(separator: "\n").prefix(15) where line.contains("@veil ") || line.contains("@nc ") {
                let kv = line.components(separatedBy: line.contains("@veil ") ? "@veil " : "@nc ").last!.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if kv.count == 2 { meta[kv[0]] = kv[1] }
            }
            return (path, n, meta)
        }
    }
}

func obsidianVaults() -> [(name: String, path: String)] { SourceCache.vaults }

func readVaults() -> [(name: String, path: String)] {
    let f = home + "/Library/Application Support/obsidian/obsidian.json"
    guard let d = FileManager.default.contents(atPath: f), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let vaults = o["vaults"] as? [String: [String: Any]] else { return [] }
    return vaults.values.compactMap { v in (v["path"] as? String).map { ((($0 as NSString).lastPathComponent), $0) } }
}

func obsidianItems(_ q: String) -> [Item] {
    let vaults = obsidianVaults()
    guard !vaults.isEmpty else { return [] }
    var out = vaults.map { v in
        Item(kind: .action, title: "\(v.name)", subtitle: "Obsidian vault", symbol: "book.closed",
             action: .open(safeURL("obsidian://open?path=\(v.path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v.path)")), extra: "vault")
    }
    let l = q.lowercased()
    if l.hasPrefix("note ") && q.count > 5, let v = vaults.first {
        let name = String(q.dropFirst(5))
        let enc = { (s: String) in s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s }
        out.insert(Item(kind: .action, title: "New note “\(name)”", subtitle: "Obsidian · \(v.name)", symbol: "square.and.pencil",
                        action: .open(safeURL("obsidian://new?vault=\(enc(v.name))&name=\(enc(name))")), score: 2100), at: 0)
    }
    return out
}

// notes inside a vault open in Obsidian rather than a text editor
func obsidianURL(for path: String) -> URL? {
    guard path.hasSuffix(".md"), obsidianVaults().contains(where: { path.hasPrefix($0.path + "/") }) else { return nil }
    return URL(string: "obsidian://open?path=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path)")
}

// MARK: more system commands (no permissions: volume via standard additions, ejecting via NSWorkspace)

func moreSystemItems(_ q: String) -> [Item] {
    var out: [Item] = []
    let l = q.lowercased()
    if l.hasPrefix("volume ") || l.hasPrefix("vol "), let n = Int(l.split(separator: " ").last ?? ""), (0...100).contains(n) {
        out.append(Item(kind: .action, title: "Set volume to \(n)%", subtitle: "Sound", symbol: "speaker.wave.2",
                        action: .run(["/usr/bin/osascript", "-e", "set volume output volume \(n)"]), score: 2100))
    }
    let base: [(String, String, String, [String])] = [
        ("Mute", "Silence the output", "speaker.slash", ["/usr/bin/osascript", "-e", "set volume with output muted"]),
        ("Unmute", "Restore sound", "speaker.wave.2", ["/usr/bin/osascript", "-e", "set volume without output muted"]),
        ("Sleep Displays", "Turns the screens off", "display", ["/usr/bin/pmset", "displaysleepnow"]),
        ("Toggle Hidden Files", "Show or hide dotfiles in Finder", "eye",
         ["/bin/sh", "-c", "v=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null); [ \"$v\" = 1 ] && n=0 || n=1; defaults write com.apple.finder AppleShowAllFiles -bool $n; killall Finder"]),
        ("Keep Awake", "Prevent sleep until you choose Allow Sleep", "cup.and.saucer", ["/bin/sh", "-c", "pkill -f 'caffeinate -di' ; nohup caffeinate -di >/dev/null 2>&1 &"]),
        ("Allow Sleep", "Stop keeping the Mac awake", "moon", ["/usr/bin/pkill", "-f", "caffeinate -di"]),
        ("Eject All Disks", "Unmounts every external volume", "eject", ["/usr/bin/osascript", "-e", "tell application \"Finder\" to eject (every disk whose ejectable is true)"]),
        ("Hide Other Apps", "Leaves only the front app", "rectangle.on.rectangle.slash", ["/usr/bin/osascript", "-e", "tell application \"System Events\" to set visible of (every process whose visible is true and frontmost is false) to false"]),
    ]
    out += base.map { Item(kind: .action, title: $0.0, subtitle: $0.1, symbol: $0.2, action: .run($0.3), score: -120) }
    return out
}

// MARK: user script commands (~/.config/veil/launcher/scripts): headers "# @veil title: …", "# @veil icon: sf.symbol", "# @veil arg: yes" (the older "@nc" also works)

func scriptItems(_ q: String) -> [Item] {
    return SourceCache.scripts.map { (path, n, meta) -> Item in
        let title = meta["title"] ?? n
        let wantsArg = meta["arg"] == "yes"
        let words = q.split(separator: " ", maxSplits: 1).map(String.init)
        let arg = wantsArg && words.count > 1 && title.lowercased().hasPrefix(words[0].lowercased()) ? words[1] : ""
        return Item(kind: .action, title: arg.isEmpty ? title : "\(title): \(arg)", subtitle: "Script · \(n)", symbol: meta["icon"] ?? "terminal",
                    action: .run(arg.isEmpty ? [path] : [path, arg]), extra: "script")
    }
}
