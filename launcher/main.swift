// Veil Search: the Veil ⌘Space launcher. A non-activating floating panel (never tiled, never
// steals the app focus) over apps, files (Spotlight index), math, System Settings, workspaces,
// Veil commands and themes. Colors come from generated/launcher.json (written by veil-theme).
// Build: launcher/build.sh. Self-check: "Veil Search.app/Contents/MacOS/veil-search" --selftest
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers
import CoreText

let home = FileManager.default.homeDirectoryForCurrentUser.path
let ncRoot = home + "/.config/veil"
let binPath = "\(home)/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

// MARK: palette

struct Palette {
    var c: [String: Color] = [:]
    var text: [String: String] = [:]  // theme strings: chip, brand, ws
    subscript(_ role: String) -> Color { c[role] ?? .gray }
    func s(_ key: String, _ fallback: String) -> String { text[key] ?? fallback }
    func num(_ key: String, _ fallback: CGFloat) -> CGFloat { text[key].flatMap { Double($0) }.map { CGFloat($0) } ?? fallback }
    func flag(_ key: String) -> Bool { text[key] == "true" }
    // the theme's letter case for chrome words (headers, badges, buttons)
    func cased(_ x: String) -> String {
        switch text["case"] { case "lower": return x.lowercased(); case "title": return x.capitalized; default: return x.uppercased() }
    }

    static func load(_ path: String = ncRoot + "/generated/launcher.json") -> Palette {
        var p = Palette()
        let url = URL(fileURLWithPath: path)
        let raw = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: String] ?? [:]
        let fallback = ["bg_float": "0e1524", "bg_dark": "070a12", "surface": "151b2d", "border": "26324a",
                        "selection": "26385a", "line": "334563", "comment": "76849c", "dim": "8794ad",
                        "fg": "d9f4ff", "white": "ffffff", "cyan": "00e5ff", "magenta": "ff4fbc", "yellow": "fcee09", "green": "5af7a5"]
        p.text = raw
        uiFamily = raw["ui_font"] ?? uiFamily
        monoFamily = raw["ui_mono"] ?? monoFamily
        for (k, v) in fallback.merging(raw, uniquingKeysWith: { $1 }) {
            guard v.count == 6, let n = UInt32(v, radix: 16) else { continue }
            p.c[k] = Color(red: Double(n >> 16 & 255) / 255, green: Double(n >> 8 & 255) / 255, blue: Double(n & 255) / 255)
        }
        return p
    }
}

// Theme fonts: ui for titles and chrome, mono for paths and values (set by Palette.load).
var uiFamily = "JetBrainsMono Nerd Font"
var monoFamily = "JetBrainsMono Nerd Font"
func weight(_ face: String) -> Font.Weight {
    ["Regular": .regular, "Medium": .medium, "SemiBold": .semibold, "Bold": .bold, "ExtraBold": .heavy][face] ?? .medium
}
// Resolve real installed faces once. Sandboxed renderer processes cannot always see
// per-user CoreText registrations, so register only the requested local family if needed.
enum ThemeFonts {
    static let cache = NSCache<NSString, NSFont>()
    static var attempted = Set<String>()
    static let localFiles = (try? FileManager.default.contentsOfDirectory(
        at: URL(fileURLWithPath: home + "/Library/Fonts"), includingPropertiesForKeys: nil)) ?? []
    static func font(_ family: String, _ size: CGFloat, _ face: String) -> NSFont {
        let key = "\(family)|\(size)|\(face)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let level = ["Regular": 5, "Medium": 6, "SemiBold": 8, "Bold": 9, "ExtraBold": 11][face] ?? 6
        if NSFontManager.shared.font(withFamily: family, traits: [], weight: level, size: size) == nil,
           attempted.insert(family).inserted {
            let normalize = { (value: String) in value.lowercased().filter { $0.isLetter || $0.isNumber } }
            let prefix = normalize(family)
            for file in localFiles where normalize(file.lastPathComponent).hasPrefix(prefix) {
                CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
            }
        }
        let result = NSFontManager.shared.font(withFamily: family, traits: [], weight: level, size: size)
            ?? NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size)
        cache.countLimit = 256
        cache.setObject(result, forKey: key)
        return result
    }
}
func mono(_ size: CGFloat, _ face: String = "Medium") -> Font { Font(ThemeFonts.font(uiFamily, size, face)) }
func code(_ size: CGFloat, _ face: String = "Regular") -> Font { Font(ThemeFonts.font(monoFamily, size, face)) }

// Source-specific vector marks, loaded once from auditable local contours.
struct SymbolContours: Decodable {
    let viewBox: [Double]
    let contours: [[[Double]]]
}
struct SourceSymbol: Shape {
    let name: String
    nonisolated(unsafe) static var cache: [String: SymbolContours] = [:]
    // art/symbols/<name>.json: viewBox [w, h] and closed polygon contours, filled even-odd
    static func load(_ name: String) -> SymbolContours? {
        if let s = cache[name] { return s }
        guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        let url = URL(fileURLWithPath: ncRoot + "/art/symbols/\(name).json")
        guard let data = try? Data(contentsOf: url),
              let symbol = try? JSONDecoder().decode(SymbolContours.self, from: data),
              symbol.viewBox.count == 2, symbol.viewBox.allSatisfy({ $0 > 0 }),
              symbol.contours.allSatisfy({ $0.count >= 3 && $0.allSatisfy({ $0.count == 2 }) }) else { return nil }
        cache[name] = symbol
        return symbol
    }
    static var brand: SymbolContours? { load("brand-of-sacrifice") }
    var aspect: CGFloat { Self.load(name).map { CGFloat($0.viewBox[0] / $0.viewBox[1]) } ?? 1 }
    func path(in rect: CGRect) -> Path {
        guard let symbol = Self.load(name) else { return Path() }
        let scale = min(rect.width / symbol.viewBox[0], rect.height / symbol.viewBox[1])
        let x = rect.midX - symbol.viewBox[0] * scale / 2
        let y = rect.midY - symbol.viewBox[1] * scale / 2
        var path = Path()
        for contour in symbol.contours {
            path.move(to: CGPoint(x: x + contour[0][0] * scale, y: y + contour[0][1] * scale))
            for point in contour.dropFirst() { path.addLine(to: CGPoint(x: x + point[0] * scale, y: y + point[1] * scale)) }
            path.closeSubpath()
        }
        return path
    }
}

// MARK: results

enum Kind: Int, CaseIterable {
    case top, calc, answer, app, setting, action, nc, file, web
    func header(_ brand: String) -> String {
        ["TOP HIT", "CALCULATOR", "ANSWERS", "APPLICATIONS", "SYSTEM SETTINGS", "ACTIONS", brand, "FILES & FOLDERS", "SEARCH"][rawValue]
    }
}

enum Action {
    case open(URL)
    case copy(String)
    case run([String])
}

struct Item: Identifiable {
    var kind: Kind
    var title: String
    var subtitle = ""
    var symbol = ""  // SF Symbol when there is no file icon
    var path: String?  // file or app path: real icon, reveal in Finder, copy path
    var action: Action
    var score = 0
    var extra = ""  // workspace index or theme id, for the detail pane
    var origin: Kind? = nil  // the kind before promotion to TOP HIT, so labels stay accurate
    var key: String { path ?? title }
    var id: String { "\(kind.rawValue)|\(key)" }
}

// Fuzzy score of `name` for query `q` (both compared lowercased), nil when it doesn't match.
func score(_ q: String, _ name: String) -> Int? {
    let n = name.lowercased(), q = q.lowercased()
    if q.isEmpty { return nil }
    if n == q { return 1000 }
    if n.hasPrefix(q) { return 900 - min(n.count - q.count, 99) }
    let words = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
    if words.contains(where: { $0.hasPrefix(q) }) { return 800 }
    if String(words.compactMap(\.first)).hasPrefix(q) && q.count > 1 { return 750 }  // "vsc" -> Visual Studio Code
    let squash = { (s: String) in s.filter { $0.isLetter || $0.isNumber } }
    if squash(n).contains(squash(q)) && !squash(q).isEmpty { return 600 }  // "wifi" -> "Wi-Fi"
    guard q.count >= 4 else { return nil }  // short queries stay strict so "saf" never matches "Workspace 5 · FREE"
    if wordSubsequence(q, n) { return 420 }  // "sfri" -> Safari
    if words.contains(where: { withinOneEdit(q, String($0.prefix(q.count))) || withinOneEdit(q, String($0)) }) { return 380 }  // one typo
    return nil
}

// Tiny calculator: + - * / % ^ parentheses, unary minus. nil on anything else.
func calc(_ s: String) -> Double? {
    var s = s.lowercased()
    // "15% of 80" -> 15/100*80
    if let r = s.range(of: #"^\s*([\d.]+)\s*%\s*of\s*([\d.]+)\s*$"#, options: .regularExpression) {
        let parts = s[r].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).filter { !$0.isEmpty }
        if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]) { return a / 100 * b }
    }
    s = s.replacingOccurrences(of: "π", with: "pi")
    let chars = Array(s.filter { $0 != " " }.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/"))
    var i = 0
    func peek() -> Character? { i < chars.count ? chars[i] : nil }
    func number() -> Double? {
        if peek() == "(" { i += 1; let v = expr(); guard peek() == ")" else { return nil }; i += 1; return v }
        if peek() == "-" { i += 1; return number().map { -$0 } }
        if let c = peek(), c.isLetter {
            let st = i
            while let c = peek(), c.isLetter || c.isNumber { i += 1 }
            let name = String(chars[st..<i])
            if name == "pi" { return Double.pi }
            if name == "e" { return M_E }
            let fns: [String: (Double) -> Double] = ["sqrt": sqrt, "sin": sin, "cos": cos, "tan": tan, "ln": log, "log": log10,
                                                     "log2": log2, "abs": abs, "exp": exp, "round": { $0.rounded() }, "floor": floor, "ceil": ceil]
            guard let f = fns[name], peek() == "(" else { return nil }
            return number().map(f)
        }
        let start = i
        while let c = peek(), c.isNumber || c == "." { i += 1 }
        return Double(String(chars[start..<i]))
    }
    func power() -> Double? {
        guard let b = number() else { return nil }
        if peek() == "^" { i += 1; guard let e = power() else { return nil }; return pow(b, e) }
        return b
    }
    func term() -> Double? {
        guard var v = power() else { return nil }
        while let op = peek(), "*/%".contains(op) {
            i += 1
            guard let r = power() else { return nil }
            v = op == "*" ? v * r : op == "/" ? v / r : v.truncatingRemainder(dividingBy: r)
        }
        return v
    }
    func expr() -> Double? {
        guard var v = term() else { return nil }
        while let op = peek(), "+-".contains(op) {
            i += 1
            guard let r = term() else { return nil }
            v = op == "+" ? v + r : v - r
        }
        return v
    }
    guard let v = expr(), i == chars.count, v.isFinite else { return nil }
    return v
}

func formatNumber(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 1e15 { return String(Int64(v)) }
    let f = NumberFormatter()
    f.maximumSignificantDigits = 12
    f.numberStyle = abs(v) >= 1e15 || abs(v) < 1e-6 ? .scientific : .decimal
    f.usesGroupingSeparator = false
    return f.string(from: v as NSNumber) ?? "\(v)"
}

let settingsPanes: [(String, String, String)] = [
    ("Wi-Fi", "com.apple.wifi-settings-extension", "wifi"), ("Bluetooth", "com.apple.BluetoothSettings", "dot.radiowaves.left.and.right"),
    ("Network", "com.apple.Network-Settings.extension", "network"), ("Battery", "com.apple.Battery-Settings.extension", "battery.75percent"),
    ("Displays", "com.apple.Displays-Settings.extension", "display"), ("Sound", "com.apple.Sound-Settings.extension", "speaker.wave.2"),
    ("Notifications", "com.apple.Notifications-Settings.extension", "bell.badge"), ("Focus", "com.apple.Focus-Settings.extension", "moon"),
    ("Appearance", "com.apple.Appearance-Settings.extension", "circle.lefthalf.filled"), ("Wallpaper", "com.apple.Wallpaper-Settings.extension", "photo"),
    ("Desktop & Dock", "com.apple.Desktop-Settings.extension", "dock.rectangle"), ("Menu Bar", "com.apple.ControlCenter-Settings.extension", "menubar.rectangle"),
    ("Keyboard", "com.apple.Keyboard-Settings.extension", "keyboard"), ("Trackpad", "com.apple.Trackpad-Settings.extension", "rectangle.and.hand.point.up.left"),
    ("Mouse", "com.apple.Mouse-Settings.extension", "computermouse"), ("Privacy & Security", "com.apple.settings.PrivacySecurity.extension", "hand.raised"),
    ("Accessibility", "com.apple.Accessibility-Settings.extension", "accessibility"), ("Lock Screen", "com.apple.Lock-Screen-Settings.extension", "lock"),
    ("Touch ID & Password", "com.apple.Touch-ID-Settings.extension", "touchid"), ("Users & Groups", "com.apple.Users-Groups-Settings.extension", "person.2"),
    ("Login Items & Extensions", "com.apple.LoginItems-Settings.extension", "list.bullet"), ("Software Update", "com.apple.Software-Update-Settings.extension", "arrow.triangle.2.circlepath"),
    ("Storage", "com.apple.settings.Storage", "internaldrive"), ("General", "com.apple.systempreferences.GeneralSettings", "gearshape"),
    ("Language & Region", "com.apple.Localization-Settings.extension", "globe"), ("Date & Time", "com.apple.Date-Time-Settings.extension", "clock"),
    ("Sharing", "com.apple.Sharing-Settings.extension", "square.and.arrow.up"), ("Screen Time", "com.apple.Screen-Time-Settings.extension", "hourglass"),
    ("Spotlight", "com.apple.Spotlight-Settings.extension", "magnifyingglass"), ("Time Machine", "com.apple.Time-Machine-Settings.extension", "clock.arrow.circlepath"),
    ("Printers & Scanners", "com.apple.Print-Scan-Settings.extension", "printer"), ("Internet Accounts", "com.apple.Internet-Accounts-Settings.extension", "at"),
    ("VPN", "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", "lock.shield"), ("Siri", "com.apple.Siri-Settings.extension", "waveform"),
]

func ncItems(_ ws: [String]) -> [Item] {
    let nc = home + "/.local/bin/veil"
    var items: [Item] = []
    for (i, name) in ws.enumerated() {
        items.append(Item(kind: .nc, title: "Workspace \(i + 1) · \(name)", subtitle: "Switch workspace  ⌥\(i + 1)", symbol: "square.grid.2x2",
                          action: .run([home + "/.local/bin/rift-cli", "execute", "workspace", "switch", "\(i)"]), extra: "\(i)"))
    }
    let commands = [("Quiet mode on / off", "toggle-quiet", "leaf"), ("Pause / resume tiling", "pause", "pause.circle"),
                    ("Reload bar and window manager", "reload", "arrow.clockwise"), ("Recover windows", "recover", "lifepreserver"),
                    ("System monitor (btop)", "btop", "waveform.path.ecg"), ("Self-test", "selftest-notify", "checkmark.seal")]
    for (title, cmd, sym) in commands {
        items.append(Item(kind: .nc, title: title, subtitle: "veil \(cmd.replacingOccurrences(of: "-notify", with: ""))", symbol: sym, action: .run([nc, cmd])))
    }
    let current = (try? String(contentsOfFile: ncRoot + "/current", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    let themes = (try? FileManager.default.contentsOfDirectory(atPath: ncRoot + "/themes")) ?? []
    for file in themes.sorted() where file.hasSuffix(".toml") {
        let id = String(file.dropLast(5))
        let text = (try? String(contentsOfFile: ncRoot + "/themes/" + file, encoding: .utf8)) ?? ""
        let name = text.split(separator: "\n").first { $0.hasPrefix("name = ") }.map { $0.dropFirst(7).trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) } ?? id
        items.append(Item(kind: .nc, title: "Theme: \(name)", subtitle: id == current ? "Current theme" : "Apply theme", symbol: "paintpalette",
                          action: .run([home + "/.local/bin/veil-theme", "apply", id]), extra: id))
    }
    return items
}

func themeSwatches(_ id: String) -> [Color] {
    let text = (try? String(contentsOfFile: "\(ncRoot)/themes/\(id).toml", encoding: .utf8)) ?? ""
    var colors: [String: String] = [:]
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: "=").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }
        if parts.count == 2, parts[1].count == 6, UInt32(parts[1], radix: 16) != nil { colors[parts[0]] = parts[1] }
    }
    return ["bg", "surface", "fg", "cyan", "magenta", "yellow", "red", "green", "blue"].compactMap { colors[$0] }.compactMap { hex in
        UInt32(hex, radix: 16).map { Color(red: Double($0 >> 16 & 255) / 255, green: Double($0 >> 8 & 255) / 255, blue: Double($0 & 255) / 255) }
    }
}

struct Win: Hashable { var app: String; var title: String; var bundle: String? }

// Windows per workspace index, from Rift (for the workspace detail pane).
func riftWindows() -> [Int: [Win]] {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: home + "/.local/bin/rift-cli")
    p.arguments = ["query", "workspaces"]
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return [:] }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
    var out: [Int: [Win]] = [:]
    for ws in list {
        guard let i = ws["index"] as? Int else { continue }
        out[i] = ((ws["windows"] as? [[String: Any]]) ?? []).map {
            Win(app: $0["app_name"] as? String ?? "?", title: $0["title"] as? String ?? "", bundle: $0["bundle_id"] as? String)
        }
    }
    return out
}

// Web search in the default browser (x-web-search:// has no handler on macOS 27).
func webSearch(_ q: String) -> URL {
    var c = URLComponents(string: "https://www.google.com/search")!
    c.queryItems = [URLQueryItem(name: "q", value: q)]
    c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")  // a literal + is a space to Google
    return c.url!
}

func hexColor(_ hex: String) -> Color? {
    guard let v = UInt32(hex, radix: 16) else { return nil }
    return Color(red: Double(v >> 16 & 255) / 255, green: Double(v >> 8 & 255) / 255, blue: Double(v & 255) / 255)
}

func scanApps() -> [Item] {
    let fm = FileManager.default
    var roots = ["/Applications", "/System/Applications", home + "/Applications", "/System/Applications/Utilities", "/Applications/Utilities"]
    var seen = Set<String>(), items: [Item] = []
    // one level of subfolders (e.g. /Applications/Setapp), like Spotlight
    for r in roots where !r.hasSuffix("Utilities") {
        for d in (try? fm.contentsOfDirectory(atPath: r)) ?? [] where !d.hasSuffix(".app") && !d.hasPrefix(".") { roots.append(r + "/" + d) }
    }
    for r in roots {
        for f in (try? fm.contentsOfDirectory(atPath: r)) ?? [] where f.hasSuffix(".app") {
            let path = r + "/" + f, name = String(f.dropLast(4))
            guard !seen.contains(name), Bundle(path: path)?.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
            seen.insert(name)
            items.append(Item(kind: .app, title: name, subtitle: (r as NSString).abbreviatingWithTildeInPath, path: path, action: .open(URL(fileURLWithPath: path))))
        }
    }
    items.append(Item(kind: .app, title: "Finder", subtitle: "/System/Library/CoreServices", path: "/System/Library/CoreServices/Finder.app",
                      action: .open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))))
    return items
}

// MARK: model

final class Model: NSObject, ObservableObject {
    @Published var query = "" { didSet { if query != oldValue && !renderingFixture { userMoved = false; search() } } }
    var renderingFixture = false
    @Published var items: [Item] = []
    @Published var selected = 0
    @Published var palette = Palette.load()
    @Published var searchingFiles = false
    @Published var windows: [Int: [Win]] = [:]
    @Published var shown = false
    var openMouse = NSPoint.zero  // hover selects only after the pointer moves from where it was at open
    var apps: [Item] = []
    var shortcuts: [Item] = []
    var openWindows: [Item] = []
    var ncCache: [Item] = []
    var projects: [Item] = []
    var bookmarks: [Item] = []
    @Published var actionsOpen = false
    @Published var mode = 0  // ⌘1 apps, ⌘2 files, ⌘3 actions, ⌘4 clipboard; 0 = everything
    static let modeNames = ["", "Apps", "Files", "Actions", "Clipboard"]
    @Published var actionIndex = 0
    @Published var toast = ""
    var history: [String] = UserDefaults.standard.stringArray(forKey: "history") ?? []
    var pins: [String] = UserDefaults.standard.stringArray(forKey: "pins") ?? []
    var historyIndex = -1
    var recentFiles: [Item] = []
    var fileItems: [Item] = []
    var mdQuery: NSMetadataQuery?
    var usage: [String: Int] = UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int] ?? [:]
    var close: () -> Void = {}

    func refresh() {
        palette = Palette.load()
        ncCache = ncItems(wsNames)
        SourceCache.reload()
        DispatchQueue.global(qos: .userInitiated).async {
            SafariTabs.load()
            let a = scanApps(), w = riftWindows(), sc = shortcutItems(), ow = windowItems(), pj = cursorProjects(), bm = bookmarkItems()
            DispatchQueue.main.async {
                self.apps = a; self.windows = w; self.shortcuts = sc; self.openWindows = ow; self.projects = pj; self.bookmarks = bm
                self.search()
            }
        }
    }

    var wsNames: [String] { palette.s("ws", "NET CODE COMMS MEDIA FREE").split(separator: " ").map(String.init) }

    // frecency plus what was chosen last time for this query prefix (LaunchBar-style learning)
    func boost(_ it: Item) -> Int {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let learned = q.isEmpty ? 0 : (usage["q:\(q.prefix(4))|\(it.key)"] ?? 0)
        return min((usage[it.key] ?? 0) * 25, 250) + min(learned * 150, 450)
    }

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        var out: [Item] = []
        // clipboard mode: ⌘4 or "clip …"
        if mode == 4 || q.lowercased() == "clip" || q.lowercased().hasPrefix("clip ") {
            let f = mode == 4 ? q : String(q.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            mdQuery?.stop(); searchingFiles = false
            let clips = ClipHistory.shared.items(f)
            publish(clips.isEmpty ? [Item(kind: .answer, title: "Clipboard history is empty", subtitle: "Copied text appears here (kept for 8 hours, never saved to disk)",
                                          symbol: "doc.on.clipboard", action: .copy(""), score: 0)] : clips)
            return
        }
        if q.isEmpty {
            // start state: what you use most, like Spotlight's recents
            let all = apps + ncCache
            let pinned = pins.compactMap { k in all.first { $0.key == k } }.map { var i = $0; i.kind = .top; i.extra = i.extra.isEmpty ? "pinned" : i.extra; return i }
            out = pinned + all.filter { (usage[$0.key] ?? 0) > 0 && !pins.contains($0.key) }
                .sorted { (usage[$0.key] ?? 0) > (usage[$1.key] ?? 0) }.prefix(max(0, 6 - pinned.count)).map {
                var i = $0; i.kind = .top; return i
            }
            // opens as just the search field, like Spotlight; results appear once you type
            fileItems = []
            searchingFiles = false
            mdQuery?.stop()
            items = []
            selected = 0
            return
        }
        if let entries = folderItems(q) {  // "~/Dev/": browse instead of search
            fileItems = []; mdQuery?.stop(); searchingFiles = false
            publish(entries); return
        }
        if let emoji = emojiItems(q) { mdQuery?.stop(); searchingFiles = false; publish(emoji); return }
        out += aliasItems(q)
        if let w = Weather.shared.answer(q, refresh: { [weak self] in self?.search() }) { out.append(w) }
        out += utilityAnswers(q)
        if let item = prefixSearch(q) { out.append(item) }
        out += unitAnswers(q)
        out += currencyAnswers(q) { [weak self] in self?.search() }
        if let t = timeAnswer(q) { out.append(t) }
        out += runningAppActions(q)
        if q.rangeOfCharacter(from: .decimalDigits) != nil, q.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/%^()×÷")) != nil,
           let v = calc(q) {
            let r = formatNumber(v)
            out.append(Item(kind: .calc, title: r, subtitle: "\(q) =   ↵ copies the result", symbol: "equal", action: .copy(r), score: 2000))
        }
        func ranked(_ list: [Item], limit: Int) -> [Item] {
            list.compactMap { it -> Item? in
                guard let s = score(q, it.title) else { return nil }
                var it = it; it.score = s + boost(it) + it.score; return it  // an item's own score is a tie-breaking bias
            }.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
        }
        out += ranked(apps, limit: 6)
        out += ranked(settingsPanes.map { Item(kind: .setting, title: $0.0, subtitle: "System Settings", symbol: $0.2,
                                               action: .open(safeURL("x-apple.systempreferences:\($0.1)"))) }, limit: 4)
        let commands = ncCache
        out += ranked(commands, limit: commands.count)  // include every installed environment
        out += ranked(systemActionItems() + moreSystemItems(q).filter { $0.score < 2000 }, limit: 3)
        out += moreSystemItems(q).filter { $0.score >= 2000 }
        out += ranked(scriptItems(q), limit: 3)
        out += ranked(obsidianItems(q).filter { $0.score < 2000 }, limit: 2)
        out += obsidianItems(q).filter { $0.score >= 2000 }
        out += ranked(shortcuts, limit: 4)
        out += ranked(openWindows, limit: 4)
        out += ranked(projects, limit: 4)
        out += ranked(bookmarks, limit: 4)
        out += ranked(SafariTabs.tabs, limit: 4) + SafariTabs.offer(q)
        out += ContactSource.items(q)
        out += CalendarSource.upcoming(q) + CalendarSource.create(q)
        let menus = MenuItems.items(q)
        if !menus.isEmpty { mdQuery?.stop(); searchingFiles = false; publish(menus); return }
        // inline dictionary definition when nothing stronger answers a plain word
        if !out.contains(where: { $0.score >= 800 }), let d = definitionAnswer(q) { out.append(d) }
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        var web: [Item] = []
        // a URL: has a scheme, starts with www., or ends in a common web TLD (so "README.md" stays a file search)
        let tlds = "com|org|net|io|dev|app|ai|co|edu|gov|me|tv|gg|xyz|info|so|sh|us|uk|ca|de|fr|jp|in|au|nz|eu|ly|to|fm|tech|site|news|blog"
        if !q.contains(" "), q.range(of: #"^(https?://\S+|www\.\S+|[\w-]+(\.[\w-]+)*\.("# + tlds + #")(/\S*)?)$"#, options: [.regularExpression, .caseInsensitive]) != nil,
           let url = URL(string: q.hasPrefix("http") ? q : "https://" + q) {
            out.append(Item(kind: .action, title: "Open \(q)", subtitle: "Website", symbol: "globe", action: .open(url), score: 2100))
        }
        web.append(Item(kind: .web, title: "Search the web for “\(q)”", subtitle: "Safari", symbol: "magnifyingglass",
                        action: .open(webSearch(q))))
        web.append(Item(kind: .web, title: "Look up “\(q)”", subtitle: "Dictionary", symbol: "character.book.closed",
                        action: .open(dictURL(q))))
        if q.count >= 2 { web.append(finderSearchItem(q)) }
        pending = out
        pendingWeb = web
        publish(out + fileItems + web)
        searchFiles(q)
    }

    var pending: [Item] = []
    var pendingWeb: [Item] = []

    // Promote the best strong match to TOP HIT and keep groups in a fixed order.
    func publish(_ list: [Item]) {
        var list = list
        if let best = list.indices.filter({ [.answer, .app, .setting, .action, .nc, .file].contains(list[$0].kind) && list[$0].score >= 800 })
            .max(by: { list[$0].score < list[$1].score }), list.first?.kind != .calc, list.first?.kind != .top {
            var top = list.remove(at: best); top.origin = top.kind; top.kind = .top; list.insert(top, at: 0)
        }
        let order = { (k: Kind) in k.rawValue }
        if mode == 1 { list = list.filter { $0.kind == .app || ($0.kind == .top && ($0.path ?? "").hasSuffix(".app")) } }
        if mode == 2 { list = list.filter { $0.kind == .file || ($0.kind == .top && $0.path != nil && !($0.path ?? "").hasSuffix(".app")) } }
        if mode == 3 { list = list.filter { [.action, .setting, .nc].contains($0.kind) || ($0.kind == .top && $0.path == nil) } }
        items = list.enumerated().sorted { (order($0.element.kind), $0.offset) < (order($1.element.kind), $1.offset) }.map(\.element)
        selected = min(selected, max(items.count - 1, 0))
        if selected >= items.count || query.isEmpty { selected = 0 }
    }

    // Files from the Spotlight index: name matches first (prefix, then anywhere), content matches after, recent first.
    var recentMode = false

    func searchFiles(_ query: String, recent: Bool = false) {
        mdQuery?.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryGatheringProgress, object: nil)
        recentMode = recent
        var q = query, kindClause = ""
        if let (uti, rest) = kindFilter(query) { kindClause = "kMDItemContentTypeTree == \"\(uti)\""; q = rest }
        let qs: String
        if recent {
            qs = "kMDItemLastUsedDate >= $time.today(-3) && kMDItemContentTypeTree != \"com.apple.application\""
        } else {
            guard q.count >= 2 || (!kindClause.isEmpty && q.isEmpty) else { fileItems = []; searchingFiles = false; return }
            let esc = q.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var name = q.isEmpty ? "" : "kMDItemFSName == \"*\(esc)*\"cd"
            if q.count >= 4 { name = "(\(name) || kMDItemTextContent == \"\(esc)*\"cdw)" }
            qs = [name, kindClause].filter { !$0.isEmpty }.joined(separator: " && ")
        }
        guard let pred = NSPredicate(fromMetadataQueryString: qs) else { return }
        let mq = NSMetadataQuery()
        mq.predicate = pred
        mq.searchScopes = [NSMetadataQueryUserHomeScope]
        mq.notificationBatchingInterval = 0.15
        NotificationCenter.default.addObserver(self, selector: #selector(filesUpdated), name: .NSMetadataQueryDidFinishGathering, object: mq)
        NotificationCenter.default.addObserver(self, selector: #selector(filesUpdated), name: .NSMetadataQueryGatheringProgress, object: mq)
        mdQuery = mq
        searchingFiles = !recent  // the start screen's recents load quietly
        mq.start()
    }

    static let noise = try! NSRegularExpression(pattern:
        #"/Library/|/\.|\.app/|node_modules|/build/|DerivedData|/target/|/vendor/|/dist/|/externals?/|/third_party/|\.(pyc|o|d)$"#)

    @objc func filesUpdated(_ note: Notification) {
        guard let mq = note.object as? NSMetadataQuery, mq === mdQuery else { return }
        mq.disableUpdates()
        let typed = query.trimmingCharacters(in: .whitespaces)
        let q = (kindFilter(typed)?.1 ?? typed).lowercased()
        var found: [(Item, Int, Double)] = []
        for i in 0..<min(mq.resultCount, 600) {
            guard let r = mq.result(at: i) as? NSMetadataItem, let path = r.value(forAttribute: kMDItemPath as String) as? String else { continue }
            if Model.noise.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil { continue }
            let name = (path as NSString).lastPathComponent
            let lname = name.lowercased()
            let group = lname.hasPrefix(q) ? 0 : lname.contains(q) ? 1 : 2
            let used = (r.value(forAttribute: kMDItemLastUsedDate as String) as? Date ?? r.value(forAttribute: kMDItemContentModificationDate as String) as? Date)?.timeIntervalSince1970 ?? 0
            let isDir = (r.value(forAttribute: kMDItemContentType as String) as? String) == "public.folder"
            let it = Item(kind: .file, title: name, subtitle: ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath,
                          // a file whose name only starts with the query ranks below apps, settings and answers;
                          // only an exact name (with or without extension) can be the top hit
                          symbol: isDir ? "folder" : "doc", path: path, action: .open(URL(fileURLWithPath: path)),
                          score: (lname == q || (lname as NSString).deletingPathExtension == q) ? 870 : group == 0 ? 700 : group == 1 ? 600 : 100)
            found.append((it, group, used))
        }
        mq.enableUpdates()
        if recentMode {
            recentFiles = found.sorted { $0.2 > $1.2 }.prefix(6).map { var i = $0.0; i.score = 0; return i }
            if note.name == .NSMetadataQueryDidFinishGathering { mq.stop() }
            if query.trimmingCharacters(in: .whitespaces).isEmpty { publish(items.filter { $0.kind == .top } + recentFiles) }
            return
        }
        var seenNames: [String: Int] = [:]
        let sorted = found.sorted { ($0.1, -$0.2) < ($1.1, -$1.2) }.filter { f in  // at most two of the same filename
            seenNames[f.0.title, default: 0] += 1
            return seenNames[f.0.title]! <= 2
        }
        fileItems = (sorted.filter { $0.1 < 2 }.prefix(8) + sorted.filter { $0.1 == 2 }.prefix(3)).prefix(8).map(\.0)
        if note.name == .NSMetadataQueryDidFinishGathering { searchingFiles = false; mq.stop() }
        let sel = userMoved && items.indices.contains(selected) ? items[selected].id : nil
        publish(pending + fileItems + pendingWeb)
        if let sel, let i = items.firstIndex(where: { $0.id == sel }) { selected = i } else if !userMoved { selected = 0 }
    }

    // the rest of the selected result's title when the query is its prefix
    var completion: String? {
        guard !query.isEmpty, items.indices.contains(selected) else { return nil }
        let t = items[selected].title
        guard !t.hasSuffix("…"), t.count > query.count, t.lowercased().hasPrefix(query.lowercased()) else { return nil }
        return String(t.dropFirst(query.count))
    }

    var userMoved = false  // keep the selection on a row only after the user picked it
    func move(_ d: Int) { if !items.isEmpty { selected = (selected + d + items.count) % items.count; userMoved = true } }

    func activate(_ i: Int? = nil, reveal: Bool = false, paste: Bool = false) {
        guard items.indices.contains(i ?? selected) else { return }
        let it = items[i ?? selected]
        // permission rows ask, then search again with the new source
        if it.extra.hasPrefix("grant:") {
            let what = String(it.extra.dropFirst(6))
            let again: () -> Void = { [weak self] in self?.refresh() }
            switch what {
            case "contacts": ContactSource.request(again)
            case "calendar", "reminders": CalendarSource.request(what, again)
            case "safari": UserDefaults.standard.set(true, forKey: "safariTabs"); DispatchQueue.global().async { SafariTabs.load(); DispatchQueue.main.async(execute: again) }
            default: MenuItems.requestTrust()
            }
            return
        }
        if it.extra.hasPrefix("event\u{1F}") || it.extra.hasPrefix("reminder\u{1F}") {
            toast = CalendarSource.perform(it.extra)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.toast = ""; self.close() }
            return
        }
        if it.extra == "menu" { close(); MenuItems.press(it.id); return }
        if paste {
            let text: String = { if case .copy(let v) = it.action { return v }; return it.path ?? it.title }()
            // without Accessibility the paste can't happen: copy instead and say so while the panel is still open
            guard AXIsProcessTrusted() else {
                copyText(text, secret: it.extra == "secret")
                toast = "Copied · allow Accessibility to paste"
                MenuItems.requestTrust()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { self.toast = ""; self.close() }
                return
            }
            close()
            _ = pasteIntoFrontApp(text, secret: it.extra == "secret")
            return
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        usage[it.key, default: 0] += 1
        let secretQuery = ["b64 ", "unb64 ", "sha256 ", "password"].contains { q.lowercased().hasPrefix($0) } || it.extra == "secret"
        if !q.isEmpty && !secretQuery {
            usage["q:\(q.lowercased().prefix(4))|\(it.key)", default: 0] += 1
            history.removeAll { $0 == q }; history.insert(q, at: 0); history = Array(history.prefix(50))
            UserDefaults.standard.set(history, forKey: "history")
        }
        UserDefaults.standard.set(usage, forKey: "usage")
        if case .copy = it.action, !reveal {  // brief confirmation before the panel goes away
            copyText({ if case .copy(let v) = it.action { return v }; return "" }(), secret: it.extra == "secret")
            toast = "Copied"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.toast = ""; self.close() }
            return
        }
        close()
        if reveal, let p = it.path { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)]); return }
        switch it.action {
        case .open(let url): NSWorkspace.shared.open(url.isFileURL ? (obsidianURL(for: url.path) ?? url) : url)
        case .copy(let s): NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string)
        case .run(let argv):
            let p = Process()
            p.executableURL = URL(fileURLWithPath: argv[0])
            p.arguments = Array(argv.dropFirst())
            p.environment = ProcessInfo.processInfo.environment.merging(["PATH": binPath]) { $1 }
            if it.extra.hasPrefix("stdin:"), let data = Data(base64Encoded: String(it.extra.dropFirst(6))) {
                let pipe = Pipe(); p.standardInput = pipe
                try? p.run(); pipe.fileHandleForWriting.write(data); try? pipe.fileHandleForWriting.close()
            } else if argv[0].hasSuffix("veil-theme") {
                // report a refused theme change instead of failing silently
                let err = Pipe(); p.standardError = err
                try? p.run()
                DispatchQueue.global().async {
                    p.waitUntilExit()
                    guard p.terminationStatus != 0 else { return }
                    let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .split(separator: "\n").last.map(String.init) ?? "Theme change failed"
                    let safe = msg.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "'")
                    _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", "display notification \"\(safe)\" with title \"Veil theme\""])
                }
            } else { try? p.run() }
        }
    }

    // ⌘Y: Quick Look the selected file, as in Finder and Spotlight
    func quickLook() {
        guard items.indices.contains(selected), let path = items[selected].path, !path.hasSuffix(".app") else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        p.arguments = ["-p", path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    // ↑ on an empty query walks back through recent searches
    func recallHistory(_ d: Int) -> Bool {
        guard !history.isEmpty, query.isEmpty || historyIndex >= 0 else { return false }
        historyIndex = max(-1, min(history.count - 1, historyIndex + d))
        query = historyIndex < 0 ? "" : history[historyIndex]
        return true
    }

    var currentActions: [SecondaryAction] {
        guard items.indices.contains(selected) else { return [] }
        let it = items[selected]
        return contactActions(it) + secondaryActions(it, quickLook: { [weak self] in self?.quickLook() })
    }

    func runAction(_ i: Int) {
        let acts = currentActions
        guard acts.indices.contains(i) else { return }
        actionsOpen = false
        close()
        acts[i].run()
    }

    func togglePin() {
        guard items.indices.contains(selected) else { return }
        let k = items[selected].key
        if let i = pins.firstIndex(of: k) { pins.remove(at: i); toast = "Unpinned" } else { pins.insert(k, at: 0); toast = "Pinned to the start screen" }
        UserDefaults.standard.set(pins, forKey: "pins")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.toast = "" }
    }

    func trashSelected() {
        guard items.indices.contains(selected), let path = items[selected].path, !path.hasSuffix(".app") else { return }
        // the row goes and the toast confirms only once Finder has really moved it
        NSWorkspace.shared.recycle([URL(fileURLWithPath: path)]) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error == nil, let i = self.items.firstIndex(where: { $0.path == path }) {
                    self.items.remove(at: i)
                    self.selected = min(self.selected, max(self.items.count - 1, 0))
                }
                self.toast = error == nil ? "Moved to Trash" : "Couldn't move to Trash"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.toast = "" }
            }
        }
    }

    func copySelected() {
        guard items.indices.contains(selected) else { return }
        let it = items[selected]
        let s: String
        if case .copy(let v) = it.action { s = v } else { s = it.path ?? it.title }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        close()
    }
}

// MARK: views

final class IconCache {
    static var cache: [String: NSImage] = [:]
    static func icon(_ path: String) -> NSImage {
        if let i = cache[path] { return i }
        let i = NSWorkspace.shared.icon(forFile: path)
        cache[path] = i
        return i
    }
    static func app(_ bundle: String?) -> NSImage? {
        guard let b = bundle, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) else { return nil }
        return icon(url.path)
    }
}

struct SymbolTile: View {
    let symbol: String
    let size: CGFloat
    let lit: Bool
    let p: Palette
    // shape per theme: rounded square, circle (route bullet), diamond, bevelled square, or a tall card
    var body: some View {
        let glyph = Image(systemName: symbol).font(.system(size: size * 0.44, weight: .semibold))
        let fill = lit ? p["cyan"] : p["surface"], ink = lit ? p["bg_dark"] : p["cyan"], edge = lit ? Color.clear : p["border"]
        switch p.s("tile", "rounded") {
        case "circle":
            glyph.foregroundStyle(ink).frame(width: size, height: size).background(Circle().fill(fill)).overlay(Circle().stroke(edge, lineWidth: 1))
        case "diamond":
            glyph.font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(ink).frame(width: size, height: size)
                .background(Rectangle().fill(fill).frame(width: size * 0.7, height: size * 0.7).rotationEffect(.degrees(45)))
                .overlay(Rectangle().stroke(edge, lineWidth: 1).frame(width: size * 0.7, height: size * 0.7).rotationEffect(.degrees(45)))
        case "square":
            glyph.foregroundStyle(ink).frame(width: size, height: size).background(Rectangle().fill(fill))
                .overlay(alignment: .topLeading) { Rectangle().fill(.white.opacity(0.14)).frame(height: 1.5) }
                .overlay(alignment: .bottomTrailing) { Rectangle().fill(.black.opacity(0.45)).frame(width: size, height: 2) }
                .overlay(Rectangle().stroke(edge, lineWidth: 1))
        case "card":
            glyph.font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(lit ? p["bg_dark"] : p["yellow"])
                .frame(width: size * 0.76, height: size)
                .background(RoundedRectangle(cornerRadius: 3).fill(lit ? p["yellow"] : p["surface"]))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(p["yellow"].opacity(lit ? 0 : 0.5), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(p["yellow"].opacity(0.25), lineWidth: 0.5).padding(2.5))
                .frame(width: size, height: size)
        default:
            glyph.foregroundStyle(ink).frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(edge, lineWidth: 1))
        }
    }
}

// Group header per theme: plain caps, a centered rule with diamonds, a subway route bullet, a panel strip, or an ornament.
struct GroupHeader: View {
    let text: String
    let kind: Kind
    let p: Palette
    var body: some View {
        let t = Text(text).font(mono(10, "Bold")).tracking(1.6)
        switch p.s("head", "plain") {
        case "rule":
            HStack(spacing: 8) {
                p["line"].frame(height: 1)
                t.foregroundStyle(p["dim"]).fixedSize()
                p["line"].frame(height: 1)
            }.padding(.horizontal, 14)
        case "bullet":
            let lines = ["yellow", "red", "green", "blue", "magenta", "cyan", "dim"]
            HStack(spacing: 7) {
                Text(String(text.prefix(1))).font(mono(10, "Bold")).foregroundStyle(p["bg_dark"])
                    .frame(width: 17, height: 17).background(Circle().fill(p[lines[kind.rawValue % lines.count]]))
                t.foregroundStyle(p["fg"])
            }.padding(.leading, 12)
        case "strip":
            t.foregroundStyle(p["dim"]).padding(.leading, 12).frame(maxWidth: .infinity, alignment: .leading).frame(height: 20)
                .background(p["bg_dark"].opacity(0.7)).overlay(alignment: .bottom) { p["border"].frame(height: 1) }
        case "ornament":
            HStack(spacing: 8) {
                Text("❦").font(.system(size: 11)).foregroundStyle(p["yellow"])
                t.foregroundStyle(p["dim"]).fixedSize()
                LinearGradient(colors: [p["yellow"].opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing).frame(height: 1)
            }.padding(.leading, 12)
        default:
            t.foregroundStyle(p["comment"]).padding(.leading, 14)
        }
    }
}

struct Row: View {
    let item: Item
    let selected: Bool
    let p: Palette
    let ns: Namespace.ID

    var style: String { p.s("row", "bar") }
    var lit: Bool { selected && style == "slot" }  // Factorio: the selected row is a lit orange button

    var body: some View {
        HStack(spacing: 12) {
            if let path = item.path {
                Image(nsImage: IconCache.icon(path)).resizable().interpolation(.high).frame(width: 30, height: 30)
            } else if item.extra.hasPrefix("emoji:") {
                Text(String(item.extra.dropFirst(6))).font(.system(size: 22)).frame(width: 30, height: 30)
            } else if item.extra.hasPrefix("color:"), let c = hexColor(String(item.extra.dropFirst(6))) {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(c).frame(width: 30, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(p["border"], lineWidth: 1))
            } else {
                SymbolTile(symbol: item.symbol, size: 30, lit: selected && !lit, p: p)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text((style == "bracket" && selected ? "▸ " : "") + item.title)
                    .font(mono(item.kind == .calc ? 20 : 13.5, item.kind == .calc ? "Bold" : "Medium"))
                    .foregroundStyle(lit ? p["bg_dark"] : selected ? (["soft", "bracket"].contains(style) ? p["cyan"] : p["white"]) : p["fg"])
                    .lineLimit(1).truncationMode(.middle)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle).font(code(11)).foregroundStyle(lit ? p["bg_dark"].opacity(0.8) : selected ? p["fg"].opacity(0.82) : p["comment"])
                        .lineLimit(1).truncationMode(item.path == nil ? .tail : .head)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .frame(height: item.kind == .calc ? max(54, p.num("row_height", 44)) : p.num("row_height", 44))
        .background {
            if selected { selection.matchedGeometryEffect(id: "selection", in: ns) }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder var selection: some View {
        let radius = style == "capsule" ? 22 : min(max(p.num("radius", 16) * 0.6, 2), 12)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch style {
        case "slot": shape.fill(p["cyan"])
        case "soft": shape.fill(p["selection"].opacity(0.6))
        case "bracket": shape.fill(p["selection"].opacity(0.3))
        case "capsule": shape.fill(p["cyan"].opacity(0.14)).overlay(shape.stroke(p["cyan"].opacity(0.35), lineWidth: 1))
        case "thread":
            shape.fill(p["selection"].opacity(0.45))
                .overlay(alignment: .bottom) { Rectangle().fill(p["cyan"]).frame(height: 1).padding(.horizontal, 10) }
        case "sign":
            shape.fill(p["selection"].opacity(0.9))
                .overlay(alignment: .leading) { Rectangle().fill(p["yellow"]).frame(width: 4) }
                .clipShape(shape)
        default:
            shape.fill(p["selection"].opacity(0.85))
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(p["magenta"]).frame(width: 3, height: 22).offset(x: -1) }
        }
    }
}

// Right-hand pane: what Enter will act on, with a preview and the facts Spotlight would show.
struct Detail: View {
    let item: Item
    @ObservedObject var m: Model
    var asCard = false
    var compact = false
    @State var thumb: NSImage?

    var p: Palette { m.palette }

    @ViewBuilder var body: some View {
        if compact {
            HStack(spacing: 16) {
                hero.frame(width: 64, height: 64).clipped().accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(mono(15, "Bold")).foregroundStyle(p["fg"]).lineLimit(1).truncationMode(.middle)
                    Text(p.cased(kindLabel)).font(mono(10, "Bold")).foregroundStyle(p["cyan"])
                    Text(item.subtitle).font(code(10.5)).foregroundStyle(p["dim"]).lineLimit(1).truncationMode(item.path == nil ? .tail : .head)
                }
                Spacer(minLength: 0)
                actionButton.frame(width: 110)
            }
            .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).frame(height: 92)
            .background(p["bg_dark"].opacity(0.45))
            .task(id: item.id) { await loadThumb() }
        } else { fullBody }
    }

    var fullBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero.frame(maxWidth: .infinity).frame(height: 132)
            Text(item.title).font(mono(16, "Bold")).foregroundStyle(p["white"]).lineLimit(2).truncationMode(.middle)
                .padding(.top, 4)
            Text(p.cased(kindLabel)).font(mono(10, "Bold")).tracking(1.4).foregroundStyle(p["cyan"])
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: p.num("chip_radius", 4)).fill(p["cyan"].opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: p.num("chip_radius", 4)).stroke(p["cyan"].opacity(0.35), lineWidth: 1))
                .padding(.top, 8)
            Rectangle().fill(p["border"]).frame(height: 1).padding(.vertical, 14)
            content
            Spacer(minLength: 0)
            actionButton
        }
        .padding(18)
        .frame(width: asCard ? 278 : 300)
        .frame(maxHeight: .infinity)
        .background(asCard ? .clear : p["bg_dark"].opacity(0.35))
        .overlay(alignment: .leading) { if !asCard { Rectangle().fill(p["border"]).frame(width: 1) } }
        .task(id: item.id) { await loadThumb() }
    }

    var actionButton: some View {
        Button { m.activate() } label: {
            Text("\(p.cased(verb))  ↵").font(mono(11, "Bold")).tracking(1.4).foregroundStyle(p["bg_dark"])
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(RoundedRectangle(cornerRadius: min(p.num("radius", 16) * 0.45, 8)).fill(p["cyan"]))
        }
        .buttonStyle(.plain).accessibilityLabel("\(verb.capitalized) \(item.title)")
    }

    var kindLabel: String {
        switch item.extra {
        case "project": return "CURSOR PROJECT"
        case "window": return "WINDOW"
        default: break
        }
        if item.extra == "clip" { return "CLIPBOARD" }
        if item.extra.hasPrefix("emoji:") { return "EMOJI" }
        if item.kind == .top, let o = item.origin, o != .top {
            var copy = item; copy.kind = o
            return Detail(item: copy, m: m).kindLabel
        }
        if item.extra.hasPrefix("color:") { return "COLOR" }
        switch item.kind {
        case .top, .app, .file:
            if let path = item.path {
                if path.hasSuffix(".app") { return "APPLICATION" }
                let t = (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.localizedTypeDescriptionKey]))?.localizedTypeDescription
                return (t ?? "FILE").uppercased()
            }
            return item.symbol == "paintpalette" ? "THEME" : item.symbol == "square.grid.2x2" ? "WORKSPACE" : p.s("brand", "VEIL")
        case .calc: return "CALCULATOR"
        case .answer: return item.symbol == "character.book.closed" ? "DEFINITION" : "ANSWER"
        case .action: return item.subtitle == "Run shortcut" ? "SHORTCUT" : "ACTION"
        case .setting: return "SYSTEM SETTINGS"
        case .nc: return item.symbol == "paintpalette" ? "THEME" : item.symbol == "square.grid.2x2" ? "WORKSPACE" : "COMMAND"
        case .web: return item.symbol == "character.book.closed" && !item.extra.isEmpty ? "DEFINITION" : item.subtitle.uppercased()
        }
    }

    var verb: String {
        switch item.action {
        case .copy: return "COPY"
        case .run: return item.symbol == "paintpalette" ? "APPLY" : item.symbol == "square.grid.2x2" ? "SWITCH" : "RUN"
        case .open: return item.kind == .web ? "SEARCH" : "OPEN"
        }
    }

    @ViewBuilder var hero: some View {
        if item.extra.hasPrefix("emoji:") {
            Text(String(item.extra.dropFirst(6))).font(.system(size: 72))
        } else if item.extra.hasPrefix("color:"), let c = hexColor(String(item.extra.dropFirst(6))) {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(c).frame(width: 120, height: 92)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(p["border"], lineWidth: 1))
        } else if let t = thumb {
            Image(nsImage: t).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 220, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        } else if let path = item.path {
            Image(nsImage: IconCache.icon(path)).resizable().interpolation(.high).frame(width: 96, height: 96)
                .shadow(color: p["cyan"].opacity(0.18), radius: 18)
        } else if item.kind == .calc {
            Text("=").font(mono(64, "ExtraBold")).foregroundStyle(p["cyan"]).shadow(color: p["cyan"].opacity(0.5), radius: 16)
        } else {
            SymbolTile(symbol: item.symbol, size: 76, lit: true, p: p).shadow(color: p["cyan"].opacity(0.35), radius: 20)
        }
    }

    @ViewBuilder var content: some View {
        if item.symbol == "paintpalette" {
            let sw = themeSwatches(item.extra)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(sw.enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(c).frame(height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(p["border"], lineWidth: 1))
                }
            }
            .padding(.bottom, 14)
            HStack {
                Text(p.cased("STATUS")).font(mono(10, "Bold")).tracking(1.4).foregroundStyle(p["comment"])
                Spacer()
                Text(item.subtitle).font(mono(11, "Bold")).foregroundStyle(item.subtitle == "Current theme" ? p["green"] : p["fg"])
            }
        } else if item.symbol == "square.grid.2x2", let i = Int(item.extra) {
            let wins = m.windows[i] ?? []
            fact("WINDOWS", wins.isEmpty ? "Empty" : "\(wins.count)")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(wins.prefix(6), id: \.self) { w in
                    HStack(spacing: 8) {
                        if let icon = IconCache.app(w.bundle) { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                        Text(w.title.isEmpty ? w.app : w.title).font(mono(10.5, "Regular")).foregroundStyle(p["fg"]).lineLimit(1)
                    }
                }
            }.padding(.top, 4)
        } else if item.symbol == "character.book.closed", !item.extra.isEmpty {
            ScrollView { Text(item.extra).font(code(11.5)).foregroundStyle(p["fg"]).lineSpacing(3).textSelection(.enabled) }
        } else if case .copy(let v) = item.action {
            Text(item.extra == "secret" ? String(repeating: "•", count: min(v.count, 24)) : v).font(mono(28, "Bold")).foregroundStyle(p["white"]).lineLimit(item.extra == "clip" ? 8 : 2).minimumScaleFactor(0.4).textSelection(.enabled)
            if item.extra == "clip" { fact("COPIED", item.subtitle.components(separatedBy: "   ").first ?? "") }
            else if (item.origin ?? item.kind) == .calc { fact("EXPRESSION", m.query) }
            else { fact("QUERY", m.query) }
        } else if let path = item.path {
            if let text = textPreview(path) {
                // Spotlight-style content preview for text and code
                ScrollView { Text(text).font(code(10)).foregroundStyle(p["fg"].opacity(0.85)).lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(maxHeight: 150).padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(p["bg_dark"].opacity(0.6)))
                    .padding(.bottom, 10)
                let facts = fileFacts(path).filter { $0.0 != "WHERE" }
                ForEach(facts, id: \.0) { fact($0.0, $0.1) }
            } else {
                let facts = fileFacts(path)
                ForEach(facts, id: \.0) { fact($0.0, $0.1) }
            }
        } else {
            fact(item.kind == .nc ? "COMMAND" : "OPENS", item.subtitle)
        }
    }

    // first lines of a small text or code file (read only for the selected result)
    func textPreview(_ path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let v = try? url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey, .isDirectoryKey]), v.isDirectory != true,
              let type = v.contentType, type.conforms(to: .text) || type.conforms(to: .sourceCode), (v.fileSize ?? 0) < 2_000_000,
              let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        guard let data = try? h.read(upToCount: 2400), let s = String(data: data, encoding: .utf8) else { return nil }
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false).prefix(24).joined(separator: "\n")
        return lines.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : lines
    }

    func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(p.cased(label)).font(mono(10, "Bold")).tracking(1.4).foregroundStyle(p["comment"])
            Text(value).font(code(11, "Medium")).foregroundStyle(p["fg"]).lineLimit(3).truncationMode(.middle)
        }
        .padding(.bottom, 10)
    }

    func fileFacts(_ path: String) -> [(String, String)] {
        let url = URL(fileURLWithPath: path)
        let v = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        var out: [(String, String)] = []
        if path.hasSuffix(".app"), let ver = Bundle(path: path)?.infoDictionary?["CFBundleShortVersionString"] as? String { out.append(("VERSION", ver)) }
        if v?.isDirectory != true, !path.hasSuffix(".app"), let size = v?.fileSize { out.append(("SIZE", ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))) }
        if let d = v?.contentModificationDate {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            out.append(("MODIFIED", f.localizedString(for: d, relativeTo: Date())))
        }
        out.append(("WHERE", ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath))
        return out
    }

    func loadThumb() async {
        thumb = nil
        guard let path = item.path, !path.hasSuffix(".app") else { return }
        let ext = (path as NSString).pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "pdf", "mov", "mp4", "key", "pages", "numbers", "psd", "svg"].contains(ext) else { return }
        let req = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path), size: CGSize(width: 440, height: 240), scale: 2, representationTypes: .thumbnail)
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { thumb = rep.nsImage }
    }
}

// Frame signature drawn over the card: HUD corner brackets, an inset gilded border, a raised bevel, or a horizon glow.
struct Frame: View {
    let kind: String
    let radius: CGFloat
    let p: Palette
    var body: some View {
        switch kind {
        case "hud":
            GeometryReader { g in
                Path { path in
                    let a: CGFloat = 18, o: CGFloat = -5, w = g.size.width, h = g.size.height
                    for (x, y, dx, dy) in [(o, o, 1.0, 1.0), (w - o, o, -1.0, 1.0), (o, h - o, 1.0, -1.0), (w - o, h - o, -1.0, -1.0)] {
                        path.move(to: CGPoint(x: x, y: y + dy * a)); path.addLine(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x + dx * a, y: y))
                    }
                }
                .stroke(p["cyan"], lineWidth: 2)
            }
            .allowsHitTesting(false)
        case "inset":
            RoundedRectangle(cornerRadius: max(radius - 3, 1), style: .continuous).stroke(p["yellow"].opacity(0.4), lineWidth: 1).padding(5)
                .allowsHitTesting(false)
        case "bevel":
            ZStack {
                VStack { Color.white.opacity(0.12).frame(height: 2); Spacer() }
                HStack { Color.white.opacity(0.08).frame(width: 2); Spacer() }
                VStack { Spacer(); Color.black.opacity(0.5).frame(height: 2) }
                HStack { Spacer(); Color.black.opacity(0.45).frame(width: 2) }
            }
            .padding(2).allowsHitTesting(false)
        case "horizon":
            VStack { Spacer(); LinearGradient(colors: [.clear, p["magenta"].opacity(0.8), p["yellow"].opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing).frame(height: 1) }
                .allowsHitTesting(false)
        default: EmptyView()
        }
    }
}

// Static card textures, drawn once (no idle cost): CRT scanlines, silk threads, paper grain, dusk sky.
struct Texture: View {
    let kind: String
    let p: Palette
    var body: some View {
        switch kind {
        case "dusk":
            ZStack {
                LinearGradient(colors: [p["blue"].opacity(0.04), p["magenta"].opacity(0.16), p["yellow"].opacity(0.16)], startPoint: .top, endPoint: .bottom)
                Texture(kind: "stars", p: p)
            }
            .allowsHitTesting(false)
        case "none": Color.clear
        default:
            Canvas { ctx, size in
                switch kind {
                case "scanlines":
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.018)))
                        y += 3
                    }
                case "threads":
                    var x: CGFloat = -size.height
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: size.height)); path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        ctx.stroke(path, with: .color(.white.opacity(0.022)), lineWidth: 0.6)
                        x += 16
                    }
                case "blueprint":
                    var x: CGFloat = 0
                    while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(p["blue"].opacity(0.07))); x += 24 }
                    var y: CGFloat = 0
                    while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(p["blue"].opacity(0.07))); y += 24 }
                case "stars":
                    var seed: UInt64 = 1729
                    for _ in 0..<140 {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        let x = CGFloat((seed >> 33) % 4096) / 4096 * size.width
                        let y = CGFloat((seed >> 17) & 4095) / 4096 * size.height * 0.75
                        let d = CGFloat(seed & 3) * 0.5 + 0.8
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(0.10 + Double(seed & 7) / 40)))
                    }
                case "bokeh":
                    for (fx, fy, r) in [(0.12, 0.2, 90.0), (0.85, 0.15, 120.0), (0.55, 0.9, 140.0), (0.3, 0.7, 70.0)] {
                        ctx.fill(Path(ellipseIn: CGRect(x: size.width * fx - r, y: size.height * fy - r, width: r * 2, height: r * 2)),
                                 with: .color(p["cyan"].opacity(0.05)))
                    }
                case "grain":
                    var seed: UInt64 = 2077
                    for _ in 0..<6000 {
                        seed = seed &* 6364136223846793005 &+ 1442695040888963407
                        let x = CGFloat(seed >> 33 % 4096) / 4096 * size.width
                        let y = CGFloat((seed >> 17) & 4095) / 4096 * size.height
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(Double(seed & 7) / 180)))
                    }
                default: break
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct LauncherView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var m: Model
    @FocusState var focused: Bool
    @Namespace var ns

    var body: some View {
        let p = m.palette
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                chip(p)
                if m.mode != 0 {
                    Text(p.cased(Model.modeNames[m.mode])).font(mono(11, "Bold")).tracking(0.8).foregroundStyle(p["bg_dark"])
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(p["cyan"]))
                }
                TextField("", text: $m.query, prompt: Text(p.s("prompt", "Search apps, files, settings, math…")).foregroundStyle(p["comment"]))
                    .textFieldStyle(.plain).font(mono(21, "Medium")).foregroundStyle(p["white"])
                    .focused($focused).tint(p["cyan"]).onSubmit { m.activate() }
                    .background(alignment: .leading) {
                        // ghost completion of the selected result; → accepts
                        if let rest = m.completion {
                            (Text(m.query).foregroundColor(.clear) + Text(rest).foregroundColor(p["comment"].opacity(0.75)))
                                .font(mono(21, "Medium")).lineLimit(1).allowsHitTesting(false)
                        }
                    }
                if m.searchingFiles {
                    ProgressView().controlSize(.small).tint(p["cyan"])
                } else if m.query.isEmpty && p.s("frame", "none") == "hud" {
                    // HUD readout while idle
                    Text("SYS ONLINE  //  \(Date().formatted(date: .omitted, time: .shortened))").font(code(10, "Bold")).tracking(1.4)
                        .foregroundStyle(p["cyan"].opacity(0.8))
                } else if !m.query.isEmpty {
                    Text(p.cased("\(m.items.count) result\(m.items.count == 1 ? "" : "s")")).font(mono(10, "Bold")).tracking(1.2).foregroundStyle(p["comment"])
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: p.num("chip_radius", 5)).stroke(p["border"], lineWidth: 1))
                }
            }
            .padding(.horizontal, 18).frame(height: 62)
            .background(p.s("frame", "none") == "station" ? p["bg_dark"] : .clear)

            if !m.items.isEmpty {
                if p.s("frame", "none") == "station" { p["white"].opacity(0.85).frame(height: 2) } else { divider(p) }
                results(p).frame(height: 412)
                HStack(spacing: 16) {
                    // narrow launchers (Hallownest) drop the less used hints instead of clipping them
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { hint("↵", "open"); hint("⌘↵", "show in Finder"); hint("⌘K", "actions"); hint("⌥↵", "paste"); hint("⌘C", "copy"); hint("⌘Y", "quick look"); hint("esc", "close") }
                        HStack(spacing: 16) { hint("↵", "open"); hint("⌘K", "actions"); hint("⌘C", "copy"); hint("esc", "close") }
                        HStack(spacing: 16) { hint("↵", "open"); hint("⌘K", "actions") }
                    }
                    Spacer(minLength: 12)
                    Text(p.cased("\(p.s("brand", "VEIL")) // search")).font(mono(11, "Bold")).tracking(1.4).foregroundStyle(p["comment"]).lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 18).frame(height: 32)
                .background(p["bg_dark"].opacity(0.55))
                .overlay(alignment: .top) { Rectangle().fill(p["border"]).frame(height: 1) }
            }
        }
        .frame(width: p.num("width", 860))
        .background(
            ZStack(alignment: .top) {
                VisualEffect()
                p["bg_float"].opacity(p.num("opacity", 0.88))
                Texture(kind: p.s("texture", "scanlines"), p: p)
                accentLine(p)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: p.num("radius", 16), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: p.num("radius", 16), style: .continuous).strokeBorder(p["border"], lineWidth: p.num("border_width", 1)))
        .overlay { Frame(kind: p.s("frame", "none"), radius: p.num("radius", 16), p: p) }
        .overlay(alignment: .bottomTrailing) { if m.actionsOpen { ActionPanel(m: m, p: p).padding(.trailing, 16).padding(.bottom, 44) } }
        .overlay(alignment: .bottom) {
            if !m.toast.isEmpty {
                Text(p.cased(m.toast)).font(mono(12, "Bold")).tracking(1).foregroundStyle(p["bg_dark"])
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(p["cyan"])).padding(.bottom, 46)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: m.toast)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: m.actionsOpen)
        .shadow(color: p["cyan"].opacity(p.flag("glow") ? 0.14 : 0), radius: 32, y: 6)
        .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
        .scaleEffect(m.shown || reduceMotion ? 1 : 0.97, anchor: p.s("place", "top") == "bottom" ? .bottom : .top)
        .opacity(m.shown ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: m.shown)
        .padding(40)
        .frame(maxHeight: .infinity, alignment: p.s("place", "top") == "bottom" ? .bottom : .top)
        .onAppear { if !m.renderingFixture { focused = true } }
    }

    var layout: String { m.palette.s("layout", "split") }

    @ViewBuilder func results(_ p: Palette) -> some View {
        switch layout {
        case "ops":
            HStack(spacing: 0) {
                // the corporation's Japanese name, set vertically like a lobby directory
                VStack(spacing: 6) {
                    ForEach(["荒", "坂"], id: \.self) { Text($0).font(.system(size: 17, weight: .semibold)).foregroundStyle(p["cyan"]) }
                    Rectangle().fill(p["cyan"]).frame(width: 14, height: 2).padding(.top, 8)
                    Spacer()
                }
                .padding(.top, 22).frame(width: 48).background(p["bg_dark"].opacity(0.7))
                Rectangle().fill(p["border"]).frame(width: 1)
                VStack(spacing: 0) { sectionTitle("NETWORK DIRECTORY", p); resultList(p) }
                preview(p)
            }
        case "console":
            HStack(spacing: 8) {
                VStack(spacing: 0) { sectionTitle("RESULTS", p); resultList(p, grid: true) }
                preview(p)
            }.padding(8)
        case "transit":
            VStack(spacing: 0) {
                HStack { Text("DESTINATION"); Spacer(); Text("ACTION") }
                    .font(mono(10, "Bold")).foregroundStyle(p["fg"]).padding(.horizontal, 18).frame(height: 28)
                resultList(p)
                preview(p, compact: true)
            }
        case "ledger":
            HStack(spacing: 0) {
                preview(p, card: true)
                VStack(spacing: 0) { sectionTitle("RESULTS", p); resultList(p) }
            }
        case "airy":
            VStack(spacing: 0) { resultList(p).padding(.horizontal, 24); preview(p, compact: true) }
        case "archive":
            HStack(spacing: 0) {
                resultList(p).padding(.trailing, 4)
                preview(p).frame(width: 300).background(p["bg_dark"].opacity(0.35))
            }
        case "field":
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("FIELD\nINDEX").font(mono(19, "Bold")).foregroundStyle(p["fg"])
                    Rectangle().fill(p["cyan"]).frame(width: 28, height: 2)
                    Text("\(m.items.count)\nRESULTS").font(code(10, "Bold")).foregroundStyle(p["dim"])
                    Spacer()
                    Text("⌘ SPACE").font(code(10)).foregroundStyle(p["comment"])
                }.padding(18).frame(width: 124).background(p["bg_dark"].opacity(0.5))
                VStack(spacing: 0) { resultList(p); preview(p, compact: true) }
            }
        case "ink":
            HStack(spacing: 0) {
                VStack(spacing: 0) { sectionTitle("INDEX", p); resultList(p) }
                Rectangle().fill(p["fg"].opacity(0.25)).frame(width: 1).padding(.vertical, 18)
                preview(p)
            }
        case "grace":
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("GRACE").font(code(10, "Bold")).tracking(2).foregroundStyle(p["yellow"])
                    Rectangle().fill(p["yellow"].opacity(0.75)).frame(width: 30, height: 1)
                    Text(String(format: "%02d", m.items.count)).font(mono(28, "Regular")).foregroundStyle(p["fg"])
                    Text("GUIDANCE").font(code(10, "Bold")).tracking(1).foregroundStyle(p["comment"])
                    Spacer()
                    Text("↵  OPEN").font(code(10, "Bold")).foregroundStyle(p["dim"])
                }
                .padding(16).frame(width: 106).background(p["bg_dark"].opacity(0.72))
                Rectangle().fill(p["yellow"].opacity(0.3)).frame(width: 1)
                VStack(spacing: 0) { sectionTitle("SITES OF GRACE", p); resultList(p) }
                preview(p)
            }
        case "embers":
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EMBER REGISTER").font(mono(11, "Bold")).tracking(2).foregroundStyle(p["yellow"])
                        Text("\(m.items.count) traces in the archive").font(mono(10)).foregroundStyle(p["comment"])
                    }.padding(.leading, 18)
                    Spacer(minLength: 8)
                    preview(p, compact: true).frame(width: 330)
                }.frame(height: 104).background(p["bg_dark"].opacity(0.56))
                p["yellow"].opacity(0.42).frame(height: 1)
                resultList(p, grid: true).padding(6)
            }
        case "posture":
            HStack(spacing: 0) {
                VStack(spacing: 0) { sectionTitle("DOJO INDEX", p); resultList(p) }
                VStack(spacing: 12) {
                    Text("INDEX").font(code(10, "Bold")).tracking(1).foregroundStyle(p["comment"])
                    ForEach(0..<5, id: \.self) { i in
                        Capsule().fill(i == min(m.selected, 4) ? p["red"] : p["line"])
                            .frame(width: 4, height: i == min(m.selected, 4) ? 42 : 22)
                    }
                    Text(String(format: "%02d", min(m.selected + 1, m.items.count)))
                        .font(code(10, "Bold")).foregroundStyle(p["dim"])
                }
                .frame(width: 42).background(p["bg_dark"].opacity(0.64))
                Rectangle().fill(p["red"].opacity(0.35)).frame(width: 1)
                preview(p)
            }
        default:
            HStack(spacing: 0) { resultList(p); preview(p, card: p.s("detail", "panel") == "card") }
        }
    }

    func sectionTitle(_ text: String, _ p: Palette) -> some View {
        Text(text).font(mono(10, "Bold")).tracking(2).foregroundStyle(p["dim"])
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).frame(height: 30)
    }

    @ViewBuilder func preview(_ p: Palette, compact: Bool = false, card: Bool = false) -> some View {
        if m.items.indices.contains(m.selected) {
            if card {
                Detail(item: m.items[m.selected], m: m, asCard: true)
                    .background(RoundedRectangle(cornerRadius: 8).fill(p["surface"]))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(p["yellow"].opacity(0.55), lineWidth: 1.5)).padding(14)
            } else { Detail(item: m.items[m.selected], m: m, compact: compact) }
        }
    }

    func resultList(_ p: Palette, grid: Bool = false) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if grid {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(Array(m.items.enumerated()), id: \.element.id) { i, item in
                            result(item, index: i, p: p).background(p["surface"]).overlay(Rectangle().stroke(p["border"], lineWidth: 1))
                        }
                    }.padding(6)
                } else {
                    LazyVStack(alignment: .leading, spacing: layout == "airy" ? 3 : 1) {
                        ForEach(Array(m.items.enumerated()), id: \.element.id) { i, item in
                            // a header and its first row are one unit, so a clipped list never ends on a bare header
                            VStack(alignment: .leading, spacing: 0) {
                                if !["transit", "ink", "field"].contains(layout), i == 0 || m.items[i - 1].kind != item.kind {
                                    GroupHeader(text: p.cased(m.query.isEmpty && item.kind == .top ? "FREQUENT" : m.query.isEmpty && item.kind == .file ? "RECENT" : item.kind.header(p.s("brand", "VEIL"))), kind: item.kind, p: p)
                                        .padding(.top, i == 0 ? 8 : 12).padding(.bottom, 4)
                                }
                                result(item, index: i, p: p)
                            }
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 40)  // the last row can always scroll clear of the fade
                }
            }
            // fade the clipped bottom edge so a cut-off section header never reads as an empty group
            .mask(VStack(spacing: 0) { Color.black; LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 36) })
            .onChange(of: m.selected) { _, selected in
                if m.items.indices.contains(selected) { proxy.scrollTo(m.items[selected].id) }
            }
        }
    }

    func result(_ item: Item, index: Int, p: Palette) -> some View {
        HStack(spacing: 0) {
            if layout == "ink" || layout == "transit" {
                Text(layout == "ink" ? String(format: "%02d", index + 1) : String(index + 1))
                    .font(code(layout == "ink" ? 11 : 15, "Bold"))
                    .foregroundStyle(layout == "transit" ? p["bg_dark"] : p["comment"])
                    .frame(width: 28, height: 28)
                    .background { if layout == "transit" { Circle().fill(p["yellow"]) } }.padding(.leading, 8)
            }
            Row(item: item, selected: index == m.selected, p: p, ns: ns)
            if layout == "transit" {
                Text(item.kind == .app ? "APP" : item.kind == .file ? "FILE" : "→")
                    .font(mono(10, "Bold")).foregroundStyle(p["dim"]).padding(.trailing, 16)
            }
        }
        .overlay(alignment: .bottom) { if layout == "transit" || layout == "ink" { p["border"].frame(height: 1) } }
        .contentShape(Rectangle()).id(item.id)
        .onDrag { item.path.flatMap { NSItemProvider(contentsOf: URL(fileURLWithPath: $0)) } ?? NSItemProvider(object: item.title as NSString) }
        .onTapGesture { m.activate(index) }
        .onHover { if $0 && NSEvent.mouseLocation != m.openMouse { m.selected = index; m.userMoved = true } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(index == m.selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { m.activate(index) }
    }

    // brand chip: filled plate, outline, or plain colored text
    @ViewBuilder func chip(_ p: Palette) -> some View {
        let shape = RoundedRectangle(cornerRadius: p.num("chip_radius", 5), style: .continuous)
        let t = Text(p.s("symbol", "").isEmpty ? p.s("chip", "NC//") : p.s("brand", "Search")).font(mono(13, "ExtraBold"))
        if SourceSymbol.load(p.s("symbol", "")) != nil {
            let mark = SourceSymbol(name: p.s("symbol", ""))
            // fit the mark in a 30pt square-ish slot at its own proportions
            mark.fill(p["cyan"], style: FillStyle(eoFill: true))
                .frame(width: min(42, 30 * mark.aspect), height: min(30, 42 / mark.aspect)).frame(minWidth: 34).frame(height: 36)
                .accessibilityLabel("Search")
        } else {
        switch p.s("chip_style", "filled") {
        case "outline": t.foregroundStyle(p["yellow"]).padding(.horizontal, 8).padding(.vertical, 4).overlay(shape.stroke(p["yellow"], lineWidth: 1))
        case "text": t.font(mono(17, "Bold")).foregroundStyle(p["yellow"])
        default: t.foregroundStyle(p["bg_dark"]).padding(.horizontal, 8).padding(.vertical, 4).background(shape.fill(p["yellow"]))
                  .shadow(color: p["yellow"].opacity(p.flag("glow") ? 0.35 : 0), radius: 8)
        }
        }
    }

    // the rule under the search field
    @ViewBuilder func divider(_ p: Palette) -> some View {
        switch p.s("line_style", "gradient") {
        case "gradient": LinearGradient(colors: [p["cyan"].opacity(0.7), p["magenta"].opacity(0.5), p["border"].opacity(0)], startPoint: .leading, endPoint: .trailing).frame(height: 1)
        case "double": VStack(spacing: 2) { p["yellow"].opacity(0.55).frame(height: 1); p["yellow"].opacity(0.25).frame(height: 1) }
        case "solid": p["cyan"].opacity(0.6).frame(height: 1)
        default: p["border"].frame(height: 1)
        }
    }

    // the edge across the top of the card
    @ViewBuilder func accentLine(_ p: Palette) -> some View {
        switch p.s("line_style", "gradient") {
        case "gradient": LinearGradient(colors: [p["cyan"], p["magenta"]], startPoint: .leading, endPoint: .trailing).frame(height: 2)
        case "double": VStack(spacing: 3) { p["yellow"].frame(height: 1); p["yellow"].opacity(0.5).frame(height: 1) }.padding(.top, 3).padding(.horizontal, 10)
        case "solid": p["cyan"].frame(height: 2)
        default: EmptyView()
        }
    }

    func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(mono(11, "Bold")).foregroundStyle(m.palette["dim"])
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 4).stroke(m.palette["border"], lineWidth: 1))
            Text(label).font(mono(11, "Regular")).foregroundStyle(m.palette["comment"])  // 11 pt floor: ~9.3 pt physical at More Space
        }.lineLimit(1).fixedSize()
    }
}

// ⌘K: every secondary action for the selected result, with its shortcut, in the theme's materials.
struct ActionPanel: View {
    @ObservedObject var m: Model
    let p: Palette
    var body: some View {
        let acts = m.currentActions
        VStack(alignment: .leading, spacing: 0) {
            Text(p.cased("actions")).font(mono(10, "Bold")).tracking(1.6).foregroundStyle(p["comment"])
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
            ForEach(Array(acts.enumerated()), id: \.element.id) { i, a in
                HStack(spacing: 10) {
                    Image(systemName: a.symbol).font(.system(size: 12, weight: .semibold)).frame(width: 18)
                        .foregroundStyle(i == m.actionIndex ? p["bg_dark"] : p["cyan"])
                    Text(a.title).font(mono(12.5, "Medium")).foregroundStyle(i == m.actionIndex ? p["bg_dark"] : p["fg"])
                    Spacer(minLength: 12)
                    if !a.keys.isEmpty {
                        Text(a.keys).font(code(10.5, "Bold")).foregroundStyle(i == m.actionIndex ? p["bg_dark"].opacity(0.7) : p["comment"])
                    }
                }
                .padding(.horizontal, 12).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: max(p.num("chip_radius", 5), 2), style: .continuous)
                    .fill(i == m.actionIndex ? p["cyan"] : .clear))
                .contentShape(Rectangle())
                .onTapGesture { m.runAction(i) }
                .onHover { if $0 { m.actionIndex = i } }
            }
        }
        .padding(6).frame(width: 300)
        .background(RoundedRectangle(cornerRadius: min(p.num("radius", 16), 12), style: .continuous).fill(p["bg_float"]))
        .overlay(RoundedRectangle(cornerRadius: min(p.num("radius", 16), 12), style: .continuous).stroke(p["border"], lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: panel + app

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { (NSApp.delegate as? App)?.hide() }
    override var canBecomeMain: Bool { false }
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var panel: Panel!
    var hotKey: EventHotKeyRef?
    var lastToggle = Date.distantPast

    func applicationDidFinishLaunching(_ n: Notification) {
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 940, height: 640),
                      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: LauncherView(m: model))
        panel.contentView?.wantsLayer = true
        model.close = { [weak self] in self?.hide() }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, e.window === self.panel else { return e }
            let cmd = e.modifierFlags.contains(.command), ctrl = e.modifierFlags.contains(.control)
            // ⌘K action panel takes the keyboard while open
            if self.model.actionsOpen {
                let n = self.model.currentActions.count
                switch Int(e.keyCode) {
                case kVK_Escape, kVK_ANSI_K where cmd: self.model.actionsOpen = false; return nil
                case kVK_DownArrow: self.model.actionIndex = n == 0 ? 0 : (self.model.actionIndex + 1) % n; return nil
                case kVK_UpArrow: self.model.actionIndex = n == 0 ? 0 : (self.model.actionIndex - 1 + n) % n; return nil
                case kVK_Return, kVK_ANSI_KeypadEnter: self.model.runAction(self.model.actionIndex); return nil
                default: return nil
                }
            }
            switch Int(e.keyCode) {
            case kVK_Escape:  // Esc clears the query, then the mode, then closes
                if !self.model.query.isEmpty { self.model.query = ""; self.model.historyIndex = -1 }
                else if self.model.mode != 0 { self.model.mode = 0; self.model.search() }
                else { self.hide() }
                return nil
            case kVK_ANSI_1 where cmd, kVK_ANSI_2 where cmd, kVK_ANSI_3 where cmd, kVK_ANSI_4 where cmd:
                let m = [kVK_ANSI_1: 1, kVK_ANSI_2: 2, kVK_ANSI_3: 3, kVK_ANSI_4: 4][Int(e.keyCode)] ?? 0
                self.model.mode = self.model.mode == m ? 0 : m
                self.model.selected = 0
                self.model.search(); return nil
            case kVK_ANSI_R where cmd: self.model.activate(reveal: true); return nil
            case kVK_ANSI_P where cmd: self.model.togglePin(); return nil
            case kVK_RightArrow where !cmd:
                // → at the end of the query accepts the ghost completion
                if let rest = self.model.completion, let tv = self.panel.firstResponder as? NSTextView,
                   tv.selectedRange().location == (self.model.query as NSString).length {
                    self.model.query += rest; return nil
                }
                return e
            case kVK_ANSI_L where cmd: self.showLargeType(); return nil
            case kVK_ANSI_K where cmd: self.model.actionIndex = 0; self.model.actionsOpen = !self.model.currentActions.isEmpty; return nil
            // ⌘⌫ deletes the query text like every macOS field; Move to Trash stays in the ⌘K actions
            case kVK_Delete where cmd: if !self.model.query.isEmpty { return e }; self.model.trashSelected(); return nil
            case kVK_DownArrow:
                if self.model.historyIndex >= 0 { _ = self.model.recallHistory(-1); return nil }
                self.model.move(1); return nil
            case kVK_UpArrow:
                if (self.model.query.isEmpty || self.model.historyIndex >= 0), self.model.recallHistory(1) { return nil }
                self.model.move(-1); return nil
            case kVK_Tab:
                // Tab enters a folder while browsing; otherwise it moves the selection
                if !e.modifierFlags.contains(.shift), self.model.items.indices.contains(self.model.selected),
                   self.model.items[self.model.selected].extra == "dir", let p = self.model.items[self.model.selected].path {
                    self.model.query = (p as NSString).abbreviatingWithTildeInPath + "/"; return nil
                }
                self.model.move(e.modifierFlags.contains(.shift) ? -1 : 1); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter: self.model.activate(reveal: cmd, paste: e.modifierFlags.contains(.option)); return nil
            case kVK_ANSI_N where ctrl: self.model.move(1); return nil
            case kVK_ANSI_P where ctrl: self.model.move(-1); return nil
            case kVK_ANSI_O where ctrl: self.model.activate(reveal: true); return nil
            case kVK_ANSI_Y where cmd: self.model.quickLook(); return nil
            case kVK_ANSI_C where cmd:
                // copy the text selection when there is one, otherwise the selected result
                if let tv = self.panel.firstResponder as? NSTextView, tv.selectedRange().length > 0 { return e }
                self.model.copySelected(); return nil
            default: return e
            }
        }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { (NSApp.delegate as? App)?.toggle() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x4E43_5348), id: 1)  // "NCSH"
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { NSLog("veil-search: could not register ⌘Space (status \(status)); is Spotlight still using it?") }
        model.refresh()
        // veil launch --query "x" (and screenshots/tests) open the panel with a query
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.show"), object: nil, queue: .main) { [weak self] n in
            self?.show(query: n.object as? String ?? "")
        }
        // functional check: top results for one query per feature, written to ~/Library/Caches/veil-search-verify.txt
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.verify"), object: nil, queue: .main) { [weak self] _ in
            guard let m = self?.model else { return }
            let queries = ["safari", "sfri", "wifi", "2+2*3", "sqrt(144)", "15% of 80", "10 km to mi", "100 f to c", "100 usd to eur", "time in tokyo",
                           "serendipity", "weather", "uuid", "#ff8800", ":fire", "upper", "lock", "volume 30", "quit finder", "g swift",
                           "yt lofi", "so swift", "~/Developer/", "pdf: whitepaper", "lethean", "theme", "github.com", "README.md",
                           "event lunch friday 1pm", "remind call mum at 6pm", "cal", "tabs", "contacts", "m export", "clip", "password"]
            var out: [String] = []
            func dump(_ i: Int) {
                guard i < queries.count else {
                    m.mdQuery?.stop(); m.query = ""
                    try? out.joined(separator: "\n").write(toFile: home + "/Library/Caches/veil-search-verify.txt", atomically: true, encoding: .utf8)
                    return
                }
                try? queries[i].write(toFile: home + "/Library/Caches/veil-search-verify-current.txt", atomically: true, encoding: .utf8)
                m.query = queries[i]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {  // let file results and lookups arrive
                    let top = m.items.prefix(3).map { "\($0.title.prefix(48)) [\($0.origin ?? $0.kind)]" }.joined(separator: " | ")
                    out.append("\(queries[i].padding(toLength: 24, withPad: " ", startingAt: 0)) → \(top.isEmpty ? "(none)" : top)")
                    dump(i + 1)
                }
            }
            dump(0)
        }
        // benchmark hook: average time of search() over common queries (written to ~/Library/Caches/veil-search-bench.txt)
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.bench"), object: nil, queue: .main) { [weak self] _ in
            guard let m = self?.model else { return }
            var lines: [String] = []
            for q in ["s", "sa", "saf", "safari", "10 km to mi", "sqrt(2)", "weather", "lethean", "~/Dev"] {
                m.query = q
                let t0 = CFAbsoluteTimeGetCurrent()
                for _ in 0..<20 { m.search() }
                lines.append(String(format: "%-14@ %6.2f ms", q as NSString, (CFAbsoluteTimeGetCurrent() - t0) / 20 * 1000))
            }
            m.mdQuery?.stop()
            try? lines.joined(separator: "\n").write(toFile: home + "/Library/Caches/veil-search-bench.txt", atomically: true, encoding: .utf8)
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.largetype"), object: nil, queue: .main) { [weak self] _ in
            self?.showLargeType()
        }
        // test hook: open the ⌘K action panel for the current selection
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.actions"), object: nil, queue: .main) { [weak self] _ in
            guard let m = self?.model else { return }
            m.actionIndex = 0; m.actionsOpen = !m.currentActions.isEmpty
        }
        // ask for every optional permission in one sitting: Contacts, Calendar, Reminders, Accessibility, Safari, System Events
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.permissions"), object: nil, queue: .main) { _ in
            NSApp.activate(ignoringOtherApps: true)
            ContactSource.request {
                CalendarSource.request("calendar") {
                    CalendarSource.request("reminders") {
                        MenuItems.requestTrust()
                        DispatchQueue.global().async {
                            for app in ["Safari", "System Events"] {
                                var err: NSDictionary?
                                _ = NSAppleScript(source: "tell application \"\(app)\" to count windows")?.executeAndReturnError(&err)
                            }
                        }
                    }
                }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.splash"), object: nil, queue: .main) { [weak self] _ in
            self?.showSplash()
        }
        // veil-theme: set this image as the desktop picture on every screen
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.desktop"), object: nil, queue: .main) { n in
            guard let path = n.object as? String else { return }
            for screen in NSScreen.screens { try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:]) }
            self.band.reload(Palette.load())
        }
        band.reload(Palette.load())
        ClipHistory.shared.start()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.band.reload(Palette.load()) }
    }

    // `open -a "Veil Search"` (veil launch, the bar menu) toggles too
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { toggle(); return false }

    func toggle() {
        guard Date().timeIntervalSince(lastToggle) > 0.15 else { return }  // debounce key repeat
        lastToggle = Date()
        panel.isVisible ? hide() : show()
    }

    // ⌘L Large Type: the selected answer across the screen, readable from across the room
    var largeType: NSWindow?
    func showLargeType() {
        guard model.items.indices.contains(model.selected) else { return }
        largeTypeText(model.items[model.selected])
    }
    func largeTypeText(_ it: Item) {
        var text = it.title
        if case .copy(let v) = it.action, !v.isEmpty, it.extra != "secret" { text = v }
        hide()
        dismissLargeType()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let w = Panel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.level = .screenSaver; w.backgroundColor = .clear; w.isOpaque = false; w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let p = model.palette
        w.contentView = NSHostingView(rootView: ZStack {
            Color.black.opacity(0.55)
            Text(text).font(mono(min(160, max(48, 2400 / CGFloat(max(text.count, 1)))), "Bold")).foregroundStyle(p["white"])
                .multilineTextAlignment(.center).minimumScaleFactor(0.2).padding(60)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(p["bg_float"].opacity(0.95)))
                .padding(120)
            VStack { Spacer(); Text("Press any key or click to close").font(code(12)).foregroundStyle(.white.opacity(0.6)).padding(.bottom, 40) }
        }.ignoresSafeArea())
        w.makeKeyAndOrderFront(nil)
        largeType = w
        // any key or click anywhere closes it, whether or not the window has focus; never left up for more than 15 s
        let close: (NSEvent) -> Void = { [weak self] _ in DispatchQueue.main.async { self?.dismissLargeType() } }
        largeTypeMonitors = [
            NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { e in close(e); return nil } as Any,
            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown], handler: close) as Any,
        ]
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self, weak w] in if self?.largeType === w { self?.dismissLargeType() } }
    }

    var largeTypeMonitors: [Any] = []
    func dismissLargeType() {
        largeType?.orderOut(nil)
        largeType = nil
        largeTypeMonitors.forEach { NSEvent.removeMonitor($0) }
        largeTypeMonitors = []
    }

    func show(query: String = "") {
        ClipHistory.shared.capture()
        MenuItems.frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        model.query = query
        model.selected = 0
        model.openMouse = NSEvent.mouseLocation
        model.refresh()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let f = screen.frame
        // width and placement follow the theme: top third (default), centered, or a banner under the bar
        let p = model.palette
        panel.setContentSize(NSSize(width: p.num("width", 860) + 80, height: 640))
        let top: CGFloat
        switch p.s("place", "top") {
        case "center": top = f.maxY - f.height * 0.26 + 40
        case "banner": top = f.maxY - 44 + 40
        case "bottom": top = f.minY + 48 - 40 + 640  // card rises from just above a bottom bar
        default: top = f.maxY - f.height * 0.18 + 40
        }
        panel.setFrameTopLeftPoint(NSPoint(x: f.midX - panel.frame.width / 2, y: top))
        model.shown = false
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            self.model.shown = true
            self.panel.makeFirstResponder(self.panel.contentView?.firstTextField)
        }
    }

    var splash: NSWindow?
    let band = NotchBand()

    func showSplash() {
        let p = Palette.load()
        model.palette = p
        model.search()  // update theme status and workspace names with the new palette
        splash?.orderOut(nil); splash?.contentView = nil
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main!
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .screenSaver
        w.backgroundColor = .clear
        w.isOpaque = false
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        w.contentView = NSHostingView(rootView: SplashView(p: p))
        w.alphaValue = 0
        w.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.25; w.animator().alphaValue = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            // drop the view too: an ordered-out SplashView keeps its TimelineView redrawing every frame
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.45; w.animator().alphaValue = 0 }, completionHandler: { w.orderOut(nil); w.contentView = nil })
        }
        splash = w
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        model.shown = false
        model.actionsOpen = false
        model.historyIndex = -1
        model.mode = 0
        model.mdQuery?.stop()
    }

    func windowDidResignKey(_ n: Notification) { hide() }
}

extension NSView {
    var firstTextField: NSTextField? {
        if let t = self as? NSTextField, t.isEditable { return t }
        for s in subviews { if let t = s.firstTextField { return t } }
        return nil
    }
}

// MARK: self-check

func selftest() -> Never {
    precondition(calc("2+3*4") == 14)
    precondition(calc("(2+3)*4") == 20)
    precondition(calc("2^10") == 1024)
    precondition(calc("-3+5") == 2)
    precondition(calc("10/4") == 2.5)
    precondition(calc("7%3") == 1)
    precondition(calc("2+") == nil && calc("abc") == nil && calc("1/0") == nil)
    precondition(formatNumber(2.5) == "2.5" && formatNumber(1024) == "1024")
    precondition(score("saf", "Safari")! > score("saf", "Microsoft Safety")!)
    precondition(score("wifi", "Wi-Fi") != nil)
    precondition(score("vsc", "Visual Studio Code") == 750)
    precondition(score("xyz", "Safari") == nil)
    precondition(calc("sqrt(16)+2^3") == 12 && calc("15% of 80") == 12 && abs((calc("sin(pi/2)") ?? 0) - 1) < 1e-9)
    precondition(unitAnswers("10 km to mi").first?.title.contains("6.2137") == true)
    precondition(unitAnswers("100 f to c").count == 1 && unitAnswers("10 kg to km").isEmpty)
    precondition(timeAnswer("time in tokyo")?.title.contains("Tokyo") == true)
    precondition(kindFilter("pdf: report")?.0 == "com.adobe.pdf" && kindFilter("report") == nil)
    precondition(prefixSearch("yt lofi")?.title.contains("YouTube") == true)
        // URL detection: real domains open, filenames don't
    do { let m = Model(); m.renderingFixture = true; m.query = "README.md"; m.renderingFixture = false
         m.search(); precondition(!m.items.contains { $0.title.hasPrefix("Open README") })
         m.query = "github.com"; precondition(m.items.contains { $0.title == "Open github.com" }); m.mdQuery?.stop() }
        precondition((systemActionItems().first { $0.title == "Shut Down…" }?.score ?? 0) < 0)  // never outranks an app
        // crash fuzz: every feature's syntax plus hostile input must search without trapping
    do {
        let m = Model(); m.renderingFixture = true
        let tricky = ["pdf: whitepaper", "kind:pdf x", "a:b", "http://", "https://exa mple.com", "%", "%%20", "\"quoted\"", "'", "\\", "dict://x",
                      "🔥🔥", ":", "::", ":fire", "#", "#zzzzzz", "#ff8800", "~", "~/", "/", "/nonexistent/", "10 to", "10 km to kg", "1e400", "9999999999999999999 km",
                      "sqrt(", "(((((", "1/0", "0^-1", "time in ", "time in nowhere", "weather ", "event ", "remind ", "remind x at 25pm",
                      "m ", "menu", "tabs", "contacts", "clip ", "b64 ", "unb64 !!!", "sha256 ", "random 9 1", "password 0", "password 9999",
                      "quit ", "force quit ", "volume 999", "vol -1", "g ", "yt ", String(repeating: "x", count: 600), "\n", "\t", "a\u{0}b"]
        for q in tricky { m.query = q; m.search(); _ = m.completion }
        m.mdQuery?.stop()
    }
        precondition(webSearch("c++ & rust").absoluteString == "https://www.google.com/search?q=c%2B%2B%20%26%20rust")
    precondition(score("sfr", "Safari") == nil && score("saf", "Workspace 5 · FREE") == nil)
    // clipboard history never keeps tokens copied from a terminal, but keeps ordinary long words, URLs and paths
    precondition(ClipHistory.looksLikeSecret("ghp_16C7e42F292c6912E7710c838347Ae178B4a"))
    precondition(ClipHistory.looksLikeSecret("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"))
    precondition(ClipHistory.looksLikeSecret("Xq7pL2mZ9vR4tK8wB3nC6yH1"))
    precondition(!ClipHistory.looksLikeSecret("https://github.com/DymeYT/veil/pull/12345678"))
    precondition(!ClipHistory.looksLikeSecret("/Users/someone/Library/Caches/veil-cpu"))
    precondition(!ClipHistory.looksLikeSecret("internationalization") && !ClipHistory.looksLikeSecret("hello world this is a long sentence 2026"))
    precondition(!ClipHistory.looksLikeSecret("wifi_scanner_dummy_2.cpp") && !ClipHistory.looksLikeSecret("Screenshot_2026-10-29.png"))
    precondition(!ClipHistory.looksLikeSecret("3114cc5eb3eb6858a3495690312065fe9d95c609") && !ClipHistory.looksLikeSecret("550e8400-e29b-41d4-a716-446655440000"))
    precondition(CalendarSource.upcoming("cal").isEmpty)  // "cal" means Calculator or Calendar.app, not the agenda
    precondition((systemActionItems().first { $0.title == "Lock Screen" }?.score ?? 0) > 0)  // the action beats the Settings pane
    print("veil-search selftest: ok")
    exit(0)
}

if CommandLine.arguments.contains("--selftest") { selftest() }
if renderReviewFixtureIfRequested() { exit(0) }
// veil-search --render-wallpaper THEME.json OUT.png: the theme's wallpaper at 2x
if let i = CommandLine.arguments.firstIndex(of: "--render-wallpaper"), CommandLine.arguments.count > i + 2 {
    let a = CommandLine.arguments
    let p = Palette.load(a[i + 1])
    MainActor.assumeIsolated {
        let r = ImageRenderer(content: WallpaperView(p: p))
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { exit(1) }
        try? png.write(to: URL(fileURLWithPath: a[i + 2]))
    }
    exit(0)
}
// veil-search --render-splash THEME.json OUT.png [t]: draw a theme's boot splash offscreen (for design review)
if let i = CommandLine.arguments.firstIndex(of: "--render-splash"), CommandLine.arguments.count > i + 2 {
    let a = CommandLine.arguments
    let p = Palette.load(a[i + 1])
    let t = a.count > i + 3 ? Double(a[i + 3]) ?? 0.9 : 0.9
    MainActor.assumeIsolated {
        let r = ImageRenderer(content: SplashView(p: p, fixedT: t))
        r.scale = 1
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { exit(1) }
        try? png.write(to: URL(fileURLWithPath: a[i + 2]))
    }
    exit(0)
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

/// Themes whose bar sits at the bottom, or whose wallpaper is bright at the top edge, leave the notch cut out of
/// the art. This paints black behind it with a short fade, like a hidden menu bar. It sits just above the desktop
/// picture, below every app window and the bar, and ignores the mouse.
final class NotchBand {
    var window: NSWindow?
    func reload(_ p: Palette) {
        guard p.flag("notch_band"), let s = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else {
            window?.orderOut(nil); window = nil; return
        }
        let h = s.safeAreaInsets.top, fade: CGFloat = 26
        let f = NSRect(x: s.frame.minX, y: s.frame.maxY - h - fade, width: s.frame.width, height: h + fade)
        let w = window ?? NSWindow(contentRect: f, styleMask: .borderless, backing: .buffered, defer: false)
        w.setFrame(f, display: true)
        w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false; w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        w.contentView = NSHostingView(rootView: VStack(spacing: 0) {
            Color.black.frame(height: h)
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
        })
        w.orderFrontRegardless()
        window = w
    }
}
