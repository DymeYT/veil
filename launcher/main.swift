// Veil Search: the Veil ⌘Space launcher. Spotlight-grade focus steal + keystroke sink over
// apps, files (Spotlight index), math, System Settings, workspaces, Veil commands and themes.
// Never tiled. Colors come from generated/launcher.json (written by veil-theme).
// Build: launcher/build.sh. Self-check: "Veil Search.app/Contents/MacOS/veil-search" --selftest
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers
import CoreText
import Darwin
import ImageIO

let home = FileManager.default.homeDirectoryForCurrentUser.path
let ncRoot = ProcessInfo.processInfo.environment["VEIL_ROOT"] ?? home + "/.config/veil"
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
        // .uncached: theme apply atomically replaces this file; a mapped cache kept stale ws after brand updates.
        let raw = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url, options: [.uncached]))) as? [String: String] ?? [:]
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
    var matchScore: Int? = nil
    var extra = ""  // workspace index or theme id, for the detail pane
    var origin: Kind? = nil  // the kind before promotion to TOP HIT, so labels stay accurate
    var key: String { path ?? title }
    var id: String { resultIdentity }
    var resultIdentity: String { "\((origin ?? kind).rawValue)|\(key)|\(title)|\(subtitle)" }
    var learningKey: String { "\((origin ?? kind).rawValue)|\(key)" }
    var isInformational: Bool { if case .copy(let value) = action { return value.isEmpty }; return false }
    // Copy results derive their identity from user content. They must never become disk-backed ranking or pin keys.
    var canPersist: Bool {
        if case .copy = action { return false }
        return ![Kind.answer, .calc].contains(origin ?? kind) && !["secret", "clip", "tab", "window", "menu"].contains(extra)
    }
}

func canRememberQuery(_ query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let privateCommands = ["clip", "b64", "unb64", "url", "sha256", "password", "upper", "lower", "title", "snake", "camel", "json", "count", "trim"]
    return !q.isEmpty && !privateCommands.contains { q == $0 || q.hasPrefix($0 + " ") } && !ClipHistory.looksLikeSecret(query)
}

// Match strength is independent of usage, so a popular typo cannot beat a literal match.
struct SearchTerm {
    let lower: String
    let compact: String
    private let length: Int
    private let permitsTypo: Bool

    init(_ query: String) {
        lower = query.lowercased()
        compact = lower.filter { $0.isLetter || $0.isNumber }
        length = lower.count
        permitsTypo = length >= 4 && length <= 64 && lower.allSatisfy(\.isLetter)
    }

    func score(_ name: String) -> Int? {
        guard !lower.isEmpty else { return nil }
        let title = name.lowercased()
        if title == lower { return 1000 }
        let words = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if !compact.isEmpty && words.joined() == compact { return 990 }
        if title.hasPrefix(lower) { return 900 - min(title.count - length, 32) }
        if words.contains(where: { $0.hasPrefix(lower) }) { return 810 }
        if length > 1, String(words.compactMap(\.first)).hasPrefix(lower) { return 750 }
        if compact.count >= 3 && words.joined().contains(compact) { return 600 }
        guard permitsTypo else { return nil }
        for word in words where word.allSatisfy(\.isLetter) {
            if length >= 5 || word.first == lower.first, withinOneEdit(lower, String(word)) { return 540 }
            if word.first == lower.first, word.count > length, withinOneEdit(lower, String(word.prefix(length))) { return 510 }
        }
        if words.contains(where: { word in
            guard word.first == lower.first, word.count <= length + 3 else { return false }
            var next = lower.startIndex
            for letter in word where next < lower.endIndex && letter == lower[next] { next = lower.index(after: next) }
            return next == lower.endIndex
        }) { return 420 }
        return nil
    }
}

func score(_ query: String, _ name: String) -> Int? { SearchTerm(query).score(name) }

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

private let sketchybarBin: String = {
    for path in ["/opt/homebrew/bin/sketchybar", "/usr/local/bin/sketchybar", home + "/.local/bin/sketchybar"] {
        if FileManager.default.isExecutableFile(atPath: path) { return path }
    }
    return "/opt/homebrew/bin/sketchybar"
}()

/// True when a bar label is a slot numeral (diamond regression) rather than theme vocabulary.
func isNumericWorkspaceToken(_ raw: String) -> Bool {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return !t.isEmpty && t.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
}

func themeTomlWorkspaceNames() -> [String] {
    guard let idData = try? Data(contentsOf: URL(fileURLWithPath: ncRoot + "/current"), options: [.uncached]),
          let id = String(data: idData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          let tomlData = try? Data(contentsOf: URL(fileURLWithPath: ncRoot + "/themes/\(id).toml"), options: [.uncached]),
          let toml = String(data: tomlData, encoding: .utf8) else { return [] }
    let re = try? NSRegularExpression(pattern: "(?m)^ws\\s*=\\s*\"([^\"]+)\"")
    let ns = toml as NSString
    var last = ""
    re?.enumerateMatches(in: toml, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
        guard let m, m.numberOfRanges > 1 else { return }
        last = ns.substring(with: m.range(at: 1))
    }
    return last.split(separator: " ").map(String.init).filter { !$0.isEmpty }
}

func riftWorkspaceNames() -> [String] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: home + "/.config/rift/config.toml"), options: [.uncached]),
          let text = String(data: data, encoding: .utf8) else { return [] }
    let re = try? NSRegularExpression(pattern: "workspace_names\\s*=\\s*\\[([^\\]]*)\\]", options: [])
    let ns = text as NSString
    guard let match = re?.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 else { return [] }
    let body = ns.substring(with: match.range(at: 1))
    var names: [String] = []
    let quoted = try? NSRegularExpression(pattern: "\"([^\"]+)\"")
    let bns = body as NSString
    quoted?.enumerateMatches(in: body, range: NSRange(location: 0, length: bns.length)) { m, _, _ in
        guard let m, m.numberOfRanges > 1 else { return }
        names.append(bns.substring(with: m.range(at: 1)))
    }
    return names
}

func sketchybarWorkspaceNames() -> [String] {
    var fromBar: [String] = []
    for i in 0..<5 {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: sketchybarBin)
        p.arguments = ["--query", "ws.\(i)"]
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { break }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { break }
        let label = ((obj["label"] as? [String: Any])?["value"] as? String) ?? ""
        let icon = ((obj["icon"] as? [String: Any])?["value"] as? String) ?? ""
        // Prefer label; fall back to icon only when label empty (never prefer a lone numeral over a named icon).
        var name = label.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespaces)
        if name.isEmpty || isNumericWorkspaceToken(name) {
            let iconName = icon.trimmingCharacters(in: .whitespaces)
            if !iconName.isEmpty && !isNumericWorkspaceToken(iconName)
                && iconName != "◆" && iconName != "◈" && iconName != "◇" {
                name = iconName
            }
        }
        if name.isEmpty || isNumericWorkspaceToken(name) { break }
        fromBar.append(name)
    }
    return fromBar.count == 5 ? fromBar : []
}

/// Live workspace vocabulary — must match the settled bar after `veil-theme apply`.
/// Never trust cached palette alone; never accept diamond-style numeric 1–5 as vocabulary.
func liveWorkspaceNames(paletteWS: [String] = []) -> [String] {
    // 1) SketchyBar live labels when they carry real theme words
    let fromBar = sketchybarWorkspaceNames()
    if fromBar.count == 5 { return fromBar }

    // 2) Theme.toml ws= (canonical vocabulary veil-theme expands into the bar)
    let fromTheme = themeTomlWorkspaceNames()
    if fromTheme.count >= 5 { return Array(fromTheme.prefix(5)) }

    // 3) Rift config workspace_names
    let fromRift = riftWorkspaceNames()
    if fromRift.count >= 5 { return Array(fromRift.prefix(5)) }

    // 4) Fresh launcher.json
    let fromLauncher = Palette.load().s("ws", "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
    if fromLauncher.count >= 5 { return Array(fromLauncher.prefix(5)) }

    // 5) Caller palette / default
    if paletteWS.count >= 5 { return Array(paletteWS.prefix(5)) }
    return ["ONE", "TWO", "THREE", "FOUR", "FIVE"]
}

/// Overview cards only — never Theme: gallery rows. Titles are bare ws names for OCR/product sync.
/// Explicit `paletteWS` (≥5) wins — fixtures/selftest must not be overridden by live bar names.
func overviewWorkspaceCards(paletteWS: [String] = []) -> [Item] {
    let names = paletteWS.count >= 5
        ? Array(paletteWS.prefix(5))
        : liveWorkspaceNames(paletteWS: paletteWS)
    let rift = home + "/.local/bin/rift-cli"
    return names.enumerated().map { i, name in
        Item(kind: .nc,
             title: name,
             subtitle: "Workspace \(i + 1)  ⌥\(i + 1)",
             symbol: "square.grid.2x2",
             action: .run([rift, "execute", "workspace", "switch", "\(i)"]),
             score: 10_000 - i,
             extra: "overview-ws:\(i)")
    }
}

func ncItems(_ ws: [String]) -> [Item] {
    let nc = home + "/.local/bin/veil"
    var items: [Item] = []
    for (i, name) in ws.enumerated() {
        items.append(Item(kind: .nc, title: "Workspace \(i + 1) · \(name)", subtitle: "Switch workspace  ⌥\(i + 1)", symbol: "square.grid.2x2",
                          action: .run([home + "/.local/bin/rift-cli", "execute", "workspace", "switch", "\(i)"]), extra: "\(i)"))
    }
    items.append(Item(kind: .nc, title: "Workspace Overview", subtitle: "Browse all workspaces  ⌃⌥M",
                      symbol: "rectangle.grid.2x2", action: .run([nc, "overview"])))
    let commands = [("Turn Veil off (stock macOS)", "off", "power"), ("Quiet mode on / off", "toggle-quiet", "leaf"), ("Pause / resume tiling", "pause", "pause.circle"),
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
    items.append(Item(kind: .nc, title: "Theme: Stock macOS", subtitle: "Turn Veil off · ⌃⌥⌘V brings it back", symbol: "power",
                      action: .run([nc, "off"]), extra: "stock"))
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
func riftWorkspaces() -> [[String: Any]] {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: home + "/.local/bin/rift-cli")
    p.arguments = ["query", "workspaces"]
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return [] }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
}

func riftWindows(_ list: [[String: Any]]) -> [Int: [Win]] {
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
    /// Live window thumbnails for Workspace Overview (ScreenCaptureKit / app-icon fallback).
    @Published var overviewThumbs: [Int: [WinThumb]] = [:]
    @Published var shown = false
    /// Exclusive launcher surface — overview and theme gallery never share card sources.
    enum Surface: Equatable { case search, overview, themes }
    @Published var surface: Surface = .search
    /// Overview-only cards (never Theme: rows). Bound by overviewPicker exclusively.
    @Published var overviewCards: [Item] = []
    /// Theme-gallery-only cards. Bound by themePicker exclusively.
    @Published var themeCards: [Item] = []
    var overviewActive: Bool { surface == .overview }
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
    var fileItems: [Item] = []
    private var mdQuery: NSMetadataQuery?
    var usage: [String: Int] = UserDefaults.standard.dictionary(forKey: "usage") as? [String: Int] ?? [:]
    var queryChoices = UserDefaults.standard.dictionary(forKey: "queryChoices") as? [String: [String: Int]] ?? [:]
    var close: () -> Void = {}

    static func migrateRankingPrivacy(_ store: UserDefaults) -> Bool {
        guard store.integer(forKey: "rankingPrivacyVersion") < 2 else { return false }
        // Legacy keys mixed arbitrary clipboard text with titles/paths, so they cannot be safely classified.
        for key in ["usage", "history", "pins", "queryChoices"] { store.removeObject(forKey: key) }
        store.set(2, forKey: "rankingPrivacyVersion")
        return true
    }

    private var refreshGeneration = 0
    private var shortcutsLoadedAt = Date.distantPast
    private var loadingShortcuts = false

    func refresh(updateHiddenResults: Bool = false) {
        // Always reread launcher.json — theme apply must not leave stale ws/brand in memory.
        palette = Palette.load()
        ncCache = ncItems(liveWorkspaceNames(paletteWS: wsNames))
        SourceCache.reload()
        refreshGeneration += 1
        let generation = refreshGeneration
        if !loadingShortcuts && Date().timeIntervalSince(shortcutsLoadedAt) > 60 {
            loadingShortcuts = true
            DispatchQueue.global(qos: .utility).async {
                let result = shortcutItems()
                DispatchQueue.main.async {
                    self.shortcuts = result
                    self.shortcutsLoadedAt = Date()
                    self.loadingShortcuts = false
                    if (self.shown || updateHiddenResults) && !self.query.isEmpty { self.search() }
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let workspaces = riftWorkspaces()
            let a = scanApps(), w = riftWindows(workspaces), ow = windowItems(workspaces)
            let pj = cursorProjects(), bm = bookmarkItems()
            DispatchQueue.main.async {
                guard generation == self.refreshGeneration else { return }
                self.apps = a; self.windows = w; self.openWindows = ow; self.projects = pj; self.bookmarks = bm
                if (self.shown || updateHiddenResults) && !self.query.isEmpty { self.search() }
            }
        }
        if SafariTabs.enabled {
            DispatchQueue.global(qos: .utility).async {
                let tabs = SafariTabs.load()
                DispatchQueue.main.async {
                    guard generation == self.refreshGeneration else { return }
                    SafariTabs.tabs = tabs
                    if (self.shown || updateHiddenResults) && !self.query.isEmpty { self.search() }
                }
            }
        } else {
            SafariTabs.tabs = []
        }
    }

    var wsNames: [String] { palette.s("ws", "NET CODE COMMS MEDIA FREE").split(separator: " ").map(String.init) }

    // Exact-query choices can reorder similarly matched results. Global usage only breaks ties.
    func preference(_ item: Item, for term: String) -> Int {
        guard item.canPersist else { return 0 }
        let recent = usage[item.key] ?? 0
        let chosen = queryChoices[term]?[item.learningKey] ?? 0
        return min(max(0, recent), 6) * 2 + min(max(0, chosen), 5) * 8
    }

    private func recordSelection(_ item: Item, query: String) {
        guard item.canPersist, canRememberQuery(query) else { return }
        usage[item.key] = min(999, max(0, usage[item.key] ?? 0)) + 1
        history.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        history.insert(query, at: 0)
        history = Array(history.prefix(50))

        let term = query.lowercased()
        var choices = queryChoices[term] ?? [:]
        choices[item.learningKey] = min(999, max(0, choices[item.learningKey] ?? 0)) + 1
        if choices.count > 10, let least = choices.filter({ $0.key != item.learningKey }).min(by: { $0.value < $1.value }) {
            choices.removeValue(forKey: least.key)
        }
        queryChoices[term] = choices
        let retained = Set(history.map { $0.lowercased() })
        queryChoices = queryChoices.filter { retained.contains($0.key) }
        UserDefaults.standard.set(history, forKey: "history")
        UserDefaults.standard.set(usage, forKey: "usage")
        UserDefaults.standard.set(queryChoices, forKey: "queryChoices")
    }

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q != fileQuery { cancelFileSearch() }
        if mode == 4 || !Weather.isWeatherQuery(q) { Weather.shared.cancelPending() }
        var out: [Item] = []
        // clipboard mode: ⌘4 or "clip …"
        if mode == 4 || q.lowercased() == "clip" || q.lowercased().hasPrefix("clip ") {
            let f = mode == 4 ? q : String(q.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            cancelFileSearch()
            let clips = ClipHistory.shared.items(f)
            publish(clips.isEmpty ? [Item(kind: .answer, title: ClipHistory.enabled ? "Clipboard history is empty" : "Clipboard history is off", subtitle: ClipHistory.enabled ? "Copied text appears here (kept for 8 hours, never saved to disk)" : "Enable with defaults write app.veil.search clipboardHistory -bool true",
                                          symbol: "doc.on.clipboard", action: .copy(""), score: 0)] : clips)
            return
        }
        // Exclusive surfaces — never let Theme: rows and overview chrome share `items`.
        if surface == .overview || q.lowercased() == "overview" {
            cancelFileSearch()
            enterOverview()
            return
        }
        if surface == .themes || q.lowercased() == "theme" {
            cancelFileSearch()
            enterThemes()
            return
        }
        if q.isEmpty {
            cancelFileSearch()
            items = []
            selected = 0
            return
        }
        surface = .search
        if let entries = folderItems(q) {  // "~/Dev/": browse instead of search
            cancelFileSearch()
            publish(entries); return
        }
        if let emoji = emojiItems(q) { cancelFileSearch(); publish(emoji); return }
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
        let term = SearchTerm(q)
        func ranked(_ list: [Item], limit: Int) -> [Item] {
            list.compactMap { item -> Item? in
                guard let strength = term.score(item.title) else { return nil }
                var item = item
                item.matchScore = strength
                item.score += strength + preference(item, for: term.lower)
                return item
            }.sorted(by: ranksAhead).prefix(limit).map { $0 }
        }
        out += ranked(apps, limit: 6)
        out += ranked(settingsPanes.map { Item(kind: .setting, title: $0.0, subtitle: "System Settings", symbol: $0.2,
                                               action: .open(safeURL("x-apple.systempreferences:\($0.1)"))) }, limit: 4)
        let commands = ncCache
        out += ranked(commands, limit: commands.count)  // include every installed environment
        let systemItems = moreSystemItems(q)
        out += ranked(systemActionItems() + glyphSurfaceItems() + systemItems.filter { $0.score < 2000 }, limit: 5)
        out += systemItems.filter { $0.score >= 2000 }
        out += ranked(scriptItems(q), limit: 3)
        let vaultItems = obsidianItems(q)
        out += ranked(vaultItems.filter { $0.score < 2000 }, limit: 2)
        out += vaultItems.filter { $0.score >= 2000 }
        // Shortcuts only when a word of the name starts with the query ("sa" → "Save…", not "Source Adder")
        let ql = q.lowercased()
        out += ranked(shortcuts.filter { $0.title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains { $0.hasPrefix(ql) } }, limit: 4)
        out += ranked(openWindows, limit: 4)
        out += ranked(projects, limit: 4)
        out += ranked(bookmarks, limit: 4)
        out += ranked(SafariTabs.tabs, limit: 4) + SafariTabs.offer(q)
        out += ContactSource.items(q)
        out += CalendarSource.upcoming(q) + CalendarSource.create(q)
        let menus = MenuItems.items(q)
        if !menus.isEmpty { cancelFileSearch(); publish(menus); return }
        // inline dictionary definition when nothing stronger answers a plain word
        if !out.contains(where: { $0.score >= 800 }), let d = definitionAnswer(q) { out.append(d) }
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

    private func ranksAhead(_ lhs: Item, _ rhs: Item) -> Bool {
        // Match classes preserve literal intent; score within each class includes personal preference.
        func tier(_ item: Item) -> Int {
            guard let match = item.matchScore else { return item.score }
            switch match {
            case 990...: return 1000
            case 868...: return 900
            default: return match
            }
        }
        return (tier(lhs), lhs.score) > (tier(rhs), rhs.score)
    }

    // Promote the best actionable match, then preserve explicit selection across asynchronous updates.
    func publish(_ list: [Item]) {
        let previous = userMoved && items.indices.contains(selected) ? items[selected].resultIdentity : nil
        var list = list.filter { item in
            let kind = item.origin ?? item.kind
            switch mode {
            case 1: return kind == .app
            case 2: return kind == .file
            case 3: return [.action, .setting, .nc].contains(kind)
            default: return true
            }
        }
        if list.first?.kind != .calc, list.first?.kind != .top,
           let best = list.indices.filter({ index in
               let item = list[index]
               return [.answer, .app, .setting, .action, .nc, .file].contains(item.kind) &&
                   (item.matchScore.map { $0 >= 510 } ?? (item.score >= 800))
           }).max(by: { ranksAhead(list[$1], list[$0]) }) {
            var top = list.remove(at: best); top.origin = top.kind; top.kind = .top; list.insert(top, at: 0)
        }
        items = list.enumerated().sorted { ($0.element.kind.rawValue, $0.offset) < ($1.element.kind.rawValue, $1.offset) }.map(\.element)
        selected = previous.flatMap { identity in items.firstIndex { $0.resultIdentity == identity } } ?? 0
    }

    // Files from the Spotlight index: name matches first (prefix, then anywhere), content matches after, recent first.
    private var fileQuery: String?
    private var fileSearchWork: DispatchWorkItem?

    func cancelFileSearch() {
        fileSearchWork?.cancel()
        fileSearchWork = nil
        stopMetadataQuery()
        fileQuery = nil
        if !fileItems.isEmpty { fileItems = [] }
        if searchingFiles { searchingFiles = false }
    }

    private func stopMetadataQuery() {
        guard let mq = mdQuery else { return }
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: mq)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryGatheringProgress, object: mq)
        mdQuery = nil
        mq.stop()
    }

    func searchFiles(_ query: String) {
        guard query != fileQuery else { return }
        fileQuery = query
        var q = query, kindClause = ""
        if let (uti, rest) = kindFilter(query) { kindClause = "kMDItemContentTypeTree == \"\(uti)\""; q = rest }
        guard q.count >= 2 || (!kindClause.isEmpty && q.isEmpty) else { return }
        let esc = q.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var name = q.isEmpty ? "" : "kMDItemFSName == \"*\(esc)*\"cd"
        if q.count >= 4 { name = "(\(name) || kMDItemTextContent == \"\(esc)*\"cdw)" }
        let predicate = [name, kindClause].filter { !$0.isEmpty }.joined(separator: " && ")
        searchingFiles = true
        let work = DispatchWorkItem { [weak self] in self?.startFileSearch(predicate) }
        fileSearchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: work)
    }

    private func startFileSearch(_ predicate: String) {
        fileSearchWork = nil
        guard let pred = NSPredicate(fromMetadataQueryString: predicate) else { searchingFiles = false; return }
        let mq = NSMetadataQuery()
        mq.predicate = pred
        mq.searchScopes = [NSMetadataQueryUserHomeScope]
        mq.notificationBatchingInterval = 0.15
        NotificationCenter.default.addObserver(self, selector: #selector(filesUpdated), name: .NSMetadataQueryDidFinishGathering, object: mq)
        NotificationCenter.default.addObserver(self, selector: #selector(filesUpdated), name: .NSMetadataQueryGatheringProgress, object: mq)
        mdQuery = mq
        if !mq.start() { stopMetadataQuery(); searchingFiles = false }
    }

    /// Bury framework / plugin / asset-pack junk so simple app queries stay Spotlight-clean.
    static let noise = try! NSRegularExpression(pattern:
        #"/Library/|/\.|\.app/|\.framework\b|\.appex\b|\.xpc\b|\.bundle/|/Frameworks/|/PlugIns/|/XPCServices/|\.car$|node_modules|/build/|DerivedData|/target/|/vendor/|/dist/|/externals?/|/third_party/|\.(pyc|o|d)$"#)

    @objc func filesUpdated(_ note: Notification) {
        guard let mq = note.object as? NSMetadataQuery, mq === mdQuery else { return }
        mq.disableUpdates()
        let typed = query.trimmingCharacters(in: .whitespaces)
        let lower = typed.lowercased()
        let q = (kindFilter(typed)?.1 ?? typed).lowercased()
        var found: [(Item, Int, Double)] = []
        for i in 0..<min(mq.resultCount, 600) {
            guard let r = mq.result(at: i) as? NSMetadataItem, let path = r.value(forAttribute: kMDItemPath as String) as? String else { continue }
            if Model.noise.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil { continue }
            let name = (path as NSString).lastPathComponent
            let lname = name.lowercased()
            // Framework asset names (CepheiPrefs.framework Safari.png etc.) — bury hard.
            let pathLower = path.lowercased()
            if pathLower.contains(".framework") || pathLower.contains("/frameworks/") || lname.hasSuffix(".car") { continue }
            let group = lname.hasPrefix(q) ? 0 : lname.contains(q) ? 1 : 2
            let used = (r.value(forAttribute: kMDItemLastUsedDate as String) as? Date ?? r.value(forAttribute: kMDItemContentModificationDate as String) as? Date)?.timeIntervalSince1970 ?? 0
            let isDir = (r.value(forAttribute: kMDItemContentType as String) as? String) == "public.folder"
            var it = Item(kind: .file, title: name, subtitle: ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath,
                          // a file whose name only starts with the query ranks below apps, settings and answers;
                          // an exact name leads the files, but the top hit stays with apps, settings and answers
                          symbol: isDir ? "folder" : "doc", path: path, action: .open(URL(fileURLWithPath: path)),
                          score: (lname == q || (lname as NSString).deletingPathExtension == q) ? 790 : group == 0 ? 700 : group == 1 ? 600 : 100)
            if !q.isEmpty {
                let nameWithoutExtension = (lname as NSString).deletingPathExtension
                if lname == q || nameWithoutExtension == q { it.matchScore = 990 }
                else if group == 0 { it.matchScore = 868 }
            }
            it.score += preference(it, for: lower)
            found.append((it, group, used))
        }
        mq.enableUpdates()
        var seenNames: [String: Int] = [:]
        let sorted = found.sorted { ($0.1, -$0.0.score, -$0.2) < ($1.1, -$1.0.score, -$1.2) }.filter { f in  // at most two of the same filename
            seenNames[f.0.title, default: 0] += 1
            return seenNames[f.0.title]! <= 2
        }
        fileItems = (sorted.filter { $0.1 < 2 }.prefix(8) + sorted.filter { $0.1 == 2 }.prefix(3)).prefix(8).map(\.0)
        if note.name == .NSMetadataQueryDidFinishGathering { searchingFiles = false; stopMetadataQuery() }
        publish(pending + fileItems + pendingWeb)
    }

    // the rest of the selected result's title when the query is its prefix
    var completion: String? {
        guard !choosingTheme, !query.isEmpty, items.indices.contains(selected) else { return nil }
        let t = items[selected].title
        guard !t.hasSuffix("…"), t.count > query.count, t.lowercased().hasPrefix(query.lowercased()) else { return nil }
        return String(t.dropFirst(query.count))
    }

    var userMoved = false  // keep the selection on a row only after the user picked it

    /// Columns in the result grid (Foundry's console and Cinder's register are two-up); 1 for lists.
    var choosingTheme: Bool { surface == .themes }
    var choosingOverview: Bool { surface == .overview }
    var gridColumns: Int {
        if choosingTheme { return 3 }
        if choosingOverview { return 2 }
        return ["console", "embers"].contains(palette.s("layout", "")) ? 2 : 1
    }

    /// Build workspace cards BEFORE flipping chrome — never leave Theme: rows under WORKSPACE OVERVIEW.
    func enterOverview() {
        mode = 0
        actionsOpen = false
        cancelFileSearch()
        palette = Palette.load()
        let names = liveWorkspaceNames(paletteWS: wsNames)
        ncCache = ncItems(names)
        let cards = overviewWorkspaceCards(paletteWS: names)
        let safe = cards.isEmpty
            ? [Item(kind: .answer, title: "No workspaces", subtitle: "Theme vocabulary missing",
                    symbol: "rectangle.grid.2x2", action: .copy(""), score: 0)]
            : cards
        // Live window list for thumbnails (Rift window_server_id → ScreenCaptureKit).
        let rift = riftWorkspaces()
        windows = riftWindows(rift)
        overviewThumbs = riftWindowsDetailed(rift)
        // Cards first, then exclusive surface — prevents gallery bleed for one paint cycle.
        overviewCards = safe
        themeCards = []
        items = safe
        selected = 0
        surface = .overview
        if query.trimmingCharacters(in: .whitespaces).lowercased() != "overview" {
            // Avoid re-entrant search wiping surface: set without didSet search if possible.
            if renderingFixture {
                query = "overview"
            } else {
                renderingFixture = true
                query = "overview"
                renderingFixture = false
            }
        }
    }

    func enterThemes() {
        mode = 0
        actionsOpen = false
        cancelFileSearch()
        palette = Palette.load()
        // Keep a pre-seeded ncCache (selftest / fixtures); otherwise refresh from live theme list.
        if ncCache.filter({ $0.symbol == "paintpalette" }).isEmpty {
            ncCache = ncItems(liveWorkspaceNames(paletteWS: wsNames))
        }
        let themes = ncCache.filter { $0.symbol == "paintpalette" }.sorted {
            ($0.subtitle == "Current theme" ? 0 : 1, $0.title) < ($1.subtitle == "Current theme" ? 0 : 1, $1.title)
        }
        themeCards = themes
        overviewCards = []
        items = themes
        selected = 0
        surface = .themes
        if query.trimmingCharacters(in: .whitespaces).lowercased() != "theme" {
            renderingFixture = true
            query = "theme"
            renderingFixture = false
        }
    }

    func presentOverviewCards() { enterOverview() }

    func toggleThemePicker() {
        if surface == .themes {
            surface = .search
            overviewCards = []
            themeCards = []
            query = ""
            items = []
        } else {
            enterThemes()
        }
    }

    /// Grid moves: up/down by a row, left/right by a column, stopping at the edges instead of wrapping.
    func moveGrid(dx: Int, dy: Int) {
        let pool = surfaceItems()
        guard !pool.isEmpty else { return }
        let c = gridColumns, col = selected % c
        let next = dx != 0 ? (col + dx >= 0 && col + dx < c ? selected + dx : selected) : selected + dy * c
        selected = max(0, min(pool.count - 1, next)); userMoved = true
    }

    func move(_ d: Int) {
        let pool = surfaceItems()
        if !pool.isEmpty { selected = (selected + d + pool.count) % pool.count; userMoved = true }
    }

    func surfaceItems() -> [Item] {
        switch surface {
        case .overview: return overviewCards
        case .themes: return themeCards
        case .search: return items
        }
    }

    func activate(_ i: Int? = nil, reveal: Bool = false, paste: Bool = false) {
        let pool = surfaceItems()
        guard pool.indices.contains(i ?? selected) else { return }
        let it = pool[i ?? selected]
        guard !it.isInformational else { return }
        // permission rows ask, then search again with the new source
        if it.extra.hasPrefix("grant:") {
            let what = String(it.extra.dropFirst(6))
            let again: () -> Void = { [weak self] in self?.refresh() }
            switch what {
            case "contacts": ContactSource.request(again)
            case "calendar", "reminders": CalendarSource.request(what, again)
            case "safari": UserDefaults.standard.set(true, forKey: "safariTabs"); again()
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
            let fallback: (Bool) -> Void = { [weak self] pasted in
                guard !pasted, let self else { return }
                (NSApp.delegate as? App)?.show(query: self.query)
                self.toast = "Copied · paste manually"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { self.toast = "" }
            }
            if !pasteIntoFrontApp(text, secret: it.extra == "secret", completion: fallback) { fallback(false) }
            return
        }
        recordSelection(it, query: query.trimmingCharacters(in: .whitespaces))
        if case .copy = it.action, !reveal {  // brief confirmation before the panel goes away
            copyText({ if case .copy(let v) = it.action { return v }; return "" }(), secret: it.extra == "secret")
            toast = "Copied"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { self.toast = ""; self.close() }
            return
        }
        // Spotlight feel: UI gone this frame; open/run never blocks dismiss.
        close()
        let action = it.action
        let path = it.path
        let extra = it.extra
        let secret = it.extra == "secret"
        DispatchQueue.main.async {
            if reveal, let p = path {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
                return
            }
            switch action {
            case .open(let url):
                NSWorkspace.shared.open(url.isFileURL ? (obsidianURL(for: url.path) ?? url) : url)
            case .copy(let s):
                copyText(s, secret: secret)
            case .run(let argv):
                let p = Process()
                p.executableURL = URL(fileURLWithPath: argv[0])
                p.arguments = Array(argv.dropFirst())
                p.environment = ProcessInfo.processInfo.environment.merging(["PATH": binPath]) { $1 }
                if extra.hasPrefix("stdin:"), let data = Data(base64Encoded: String(extra.dropFirst(6))) {
                    let pipe = Pipe(); p.standardInput = pipe
                    try? p.run(); pipe.fileHandleForWriting.write(data); try? pipe.fileHandleForWriting.close()
                } else if argv[0].hasSuffix("veil-theme") {
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
        guard items[selected].canPersist else { toast = "Private results aren't saved"; return }
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
        guard !it.isInformational else { return }
        let s: String
        if case .copy(let v) = it.action { s = v } else { s = it.path ?? it.title }
        copyText(s, secret: it.extra == "secret")
        close()
    }
}

// MARK: views

enum IconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 64
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()

    static func clear() { cache.removeAllObjects() }

    static func icon(_ path: String) -> NSImage {
        let key = path as NSString
        if let icon = cache.object(forKey: key) { return icon }
        let source = NSWorkspace.shared.icon(forFile: path)
        // The largest icon in Search is 96 points. Store one Retina representation
        // instead of retaining every representation from the system icon bundle.
        let size = NSSize(width: 96, height: 96)
        let pixels = 192
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return source }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        bitmap.size = size
        let icon = NSImage(size: size)
        icon.addRepresentation(bitmap)
        cache.setObject(icon, forKey: key, cost: bitmap.bytesPerRow * pixels)
        return icon
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
            glyph.foregroundStyle(ink).frame(width: size, height: size).background(Circle().fill(fill))
        case "diamond":
            glyph.font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(ink).frame(width: size, height: size)
                .background(Rectangle().fill(fill).frame(width: size * 0.7, height: size * 0.7).rotationEffect(.degrees(45)))
                .overlay(Rectangle().stroke(edge, lineWidth: 1).frame(width: size * 0.7, height: size * 0.7).rotationEffect(.degrees(45)))
        case "square":
            glyph.foregroundStyle(ink).frame(width: size, height: size).background(Rectangle().fill(fill))
                .overlay(alignment: .topLeading) { Rectangle().fill(.white.opacity(0.14)).frame(height: 1.5) }
                .overlay(alignment: .bottomTrailing) { Rectangle().fill(.black.opacity(0.45)).frame(width: size, height: 2) }
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
        }
    }
}

// Group header per theme: plain caps, a centered rule with diamonds, a subway route bullet, a panel strip, or an ornament.
struct GroupHeader: View {
    let text: String
    let kind: Kind
    let p: Palette
    var body: some View {
        let t = Text(text).font(mono(12, "Bold")).tracking(1.6)
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
                Text(String(text.prefix(1))).font(mono(11, "Bold")).foregroundStyle(p["bg_dark"])
                    .frame(width: 17, height: 17).background(Circle().fill(p[lines[kind.rawValue % lines.count]]))
                t.foregroundStyle(p["fg"])
            }.padding(.leading, 12)
        case "strip":
            t.foregroundStyle(p["dim"]).padding(.leading, 12).frame(maxWidth: .infinity, alignment: .leading).frame(height: 20)
                .background(p["bg_dark"]).overlay(alignment: .bottom) { p["border"].frame(height: 1) }
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
                    Text(item.subtitle).font(code(12)).foregroundStyle(lit ? p["bg_dark"].opacity(0.8) : selected ? p["fg"].opacity(0.82) : p["comment"])
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
        case "plain": shape.fill(p["selection"].opacity(0.85))  // one treatment: the fill alone, no leading bar
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
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(p["cyan"]).frame(width: 3, height: 22).offset(x: -1) }
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
                    Text(p.cased(kindLabel)).font(mono(11, "Bold")).foregroundStyle(p["cyan"])
                    Text(item.subtitle).font(code(10.5)).foregroundStyle(p["dim"]).lineLimit(1).truncationMode(item.path == nil ? .tail : .head)
                }
                Spacer(minLength: 0)
                actionButton.frame(width: 110)
            }
            .padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).frame(height: 92)
            .background(p["bg_dark"])
            .task(id: m.shown ? item.id : nil) { if m.shown { await loadThumb() } else { thumb = nil } }
        } else { fullBody }
    }

    var fullBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero.frame(maxWidth: .infinity).frame(height: 132)
            Text(item.title).font(mono(16, "Bold")).foregroundStyle(p["white"]).lineLimit(2).truncationMode(.middle)
                .padding(.top, 4)
            Text(p.cased(kindLabel)).font(mono(11, "Bold")).tracking(1.4).foregroundStyle(p["cyan"])
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: p.num("chip_radius", 4)).fill(p["cyan"].opacity(0.14)))
                .padding(.top, 8)
            Rectangle().fill(p["border"]).frame(height: 1).padding(.vertical, 14)
            content
            Spacer(minLength: 0)
            actionButton
        }
        .padding(18)
        .frame(width: asCard ? 278 : 300)
        .frame(maxHeight: .infinity)
        .background(asCard ? .clear : p["bg_dark"])
        .overlay(alignment: .leading) { if !asCard { Rectangle().fill(p["border"]).frame(width: 1) } }
        .task(id: m.shown ? item.id : nil) { if m.shown { await loadThumb() } else { thumb = nil } }
    }

    var actionButton: some View {
        Button { m.activate() } label: {
            let shape = RoundedRectangle(cornerRadius: min(p.num("radius", 16) * 0.45, 8))
            let outline = p.s("button", "fill") == "outline"
            Text("\(p.cased(verb))  ↵").font(mono(11, "Bold")).tracking(1.4).foregroundStyle(outline ? p["cyan"] : p["bg_dark"])
                .frame(maxWidth: .infinity).frame(height: 34)
                .background(shape.fill(outline ? p["cyan"].opacity(0.08) : p["cyan"]))
                .overlay(shape.stroke(outline ? p["cyan"].opacity(0.8) : .clear, lineWidth: 1))
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
        } else if let t = thumb {
            Image(nsImage: t).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 220, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
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
                }
            }
            .padding(.bottom, 14)
            HStack {
                Text(p.cased("STATUS")).font(mono(11, "Bold")).tracking(1.4).foregroundStyle(p["comment"]).lineLimit(1)
                Spacer(minLength: 8)
                Text(item.subtitle).font(mono(11, "Bold")).foregroundStyle(item.subtitle == "Current theme" ? p["green"] : p["fg"])
                    .lineLimit(1).truncationMode(.tail)
            }
        } else if item.symbol == "square.grid.2x2", let i = Int(item.extra) {
            let wins = m.windows[i] ?? []
            fact("WINDOWS", wins.isEmpty ? "Empty" : "\(wins.count)")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(wins.prefix(6), id: \.self) { w in
                    HStack(spacing: 8) {
                        if let icon = IconCache.app(w.bundle) { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                        Text(w.title.isEmpty ? w.app : w.title).font(mono(10.5, "Regular")).foregroundStyle(p["fg"])
                            .lineLimit(1).truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading)
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
                ScrollView { Text(text).font(code(11)).foregroundStyle(p["fg"].opacity(0.85)).lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(maxHeight: 150).padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(p["bg_dark"]))
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
            Text(p.cased(label)).font(mono(11.5, "Bold")).tracking(1.4).foregroundStyle(p["dim"])
            Text(value).font(code(12.5, "Medium")).foregroundStyle(p["fg"]).lineLimit(3).truncationMode(.middle)
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
        guard !Task.isCancelled else { return }
        thumb = nil
        guard let path = item.path, !path.hasSuffix(".app") else { return }
        let ext = (path as NSString).pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "pdf", "mov", "mp4", "key", "pages", "numbers", "psd", "svg"].contains(ext) else { return }
        let generator = QLThumbnailGenerator.shared
        let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path),
                                                   size: CGSize(width: 220, height: 120),
                                                   scale: 2, representationTypes: .thumbnail)
        let thumbnail = await withTaskCancellationHandler {
            try? await generator.generateBestRepresentation(for: request)
        } onCancel: {
            generator.cancel(request)
        }
        if !Task.isCancelled { thumb = thumbnail?.nsImage }
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

struct OverviewCard: View {
    let item: Item
    let palette: Palette
    let selected: Bool
    let index: Int
    var windows: [WinThumb] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? palette["bg_dark"] : palette["yellow"])
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(selected ? palette["yellow"] : palette["surface"]))
                Spacer(minLength: 6)
                Text(windows.isEmpty ? "empty" : "\(windows.count) win")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(selected ? palette["cyan"] : palette["dim"])
            }
            // VEI-53 / #22: omit Empty husk slots — live thumbs only when windows exist.
            if !windows.isEmpty {
                OverviewWindowStrip(thumbs: windows, palette: palette, live: selected && VeilFeature.overviewLiveThumbs)
            }
            Text(item.title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(palette["fg"])
                .lineLimit(1).truncationMode(.tail)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(item.title)
            Text(item.subtitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette["dim"])
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .circular)
                .fill(selected ? palette["selection"] : palette["surface"])
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .circular))
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .circular)
                .strokeBorder(selected ? palette["cyan"] : palette["border"], lineWidth: selected ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workspace \(item.title)")
        .pressable()
    }
}

struct ThemePreview: View {
    let item: Item
    let palette: Palette
    let selected: Bool
    @State private var artwork: CGImage?
    @State private var swatches: [Color] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [swatches.dropFirst(3).first?.opacity(0.62) ?? palette["surface"],
                                        swatches.first ?? palette["bg_dark"]],
                               startPoint: .topTrailing, endPoint: .bottomLeading)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                            .frame(width: 120, height: 120)
                            .offset(x: 18, y: 16)
                            .accessibilityHidden(true)
                    }
                    .clipped()
                if let artwork {
                    GeometryReader { geometry in
                        Image(decorative: artwork, scale: 1)
                            .resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                }
                HStack(spacing: 3) {
                    ForEach(Array(swatches.dropFirst(2).prefix(5).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 7, height: 7)
                    }
                }
                .padding(6)
                .background(palette["bg_dark"], in: Capsule())
                .padding(8)
            }
            .frame(height: 84)
            HStack(spacing: 6) {
                Text(item.title.replacingOccurrences(of: "Theme: ", with: ""))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if item.subtitle == "Current theme" {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(palette["cyan"])
                        .accessibilityLabel("Current theme")
                        .layoutPriority(1)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .foregroundStyle(palette["fg"])
            .background(palette["surface"])
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? palette["cyan"] : palette["border"], lineWidth: selected ? 2 : 1))
        .task(id: item.extra) {
            let id = item.extra
            swatches = themeSwatches(id)
            let image = await Task.detached(priority: .utility) { () -> CGImage? in
                let url = URL(fileURLWithPath: ncRoot + "/art/\(id).jpg")
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 280
                ] as CFDictionary)
            }.value
            if !Task.isCancelled { artwork = image }
        }
    }
}

struct LauncherView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @ObservedObject var m: Model
    @FocusState var focused: Bool
    @Namespace var ns

    var body: some View {
        let p = m.palette
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                chip(p).layoutPriority(1)
                if m.mode != 0 {
                    Text(p.cased(Model.modeNames[m.mode])).font(mono(11, "Bold")).tracking(0.8).foregroundStyle(p["bg_dark"])
                        .lineLimit(1).padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(p["cyan"]))
                        .layoutPriority(1)
                }
                TextField("", text: $m.query, prompt: Text(p.s("prompt", "Search apps, files, settings, math…")).foregroundStyle(p["comment"]))
                    .textFieldStyle(.plain).font(mono(21, "Medium")).foregroundStyle(p["white"])
                    .focused($focused).tint(p["cyan"]).onSubmit { m.activate() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(0)
                    .background(alignment: .leading) {
                        // ghost completion of the selected result; → accepts
                        if let rest = m.completion {
                            Text("\(Text(m.query).foregroundColor(.clear))\(Text(rest).foregroundColor(p["comment"].opacity(0.75)))")
                                .font(mono(21, "Medium")).lineLimit(1).truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .allowsHitTesting(false)
                        }
                    }
                    .clipped()
                if layout == "umbra" {
                    Button { m.toggleThemePicker() } label: {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(m.choosingTheme ? p["yellow"] : p["dim"])
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .help("Browse themes (⌃⌥T · ⌘T in launcher · Search “theme”)")
                    .accessibilityLabel("Browse themes")
                    .layoutPriority(1)
                }
                if m.searchingFiles {
                    ProgressView().controlSize(.small).tint(p["cyan"]).layoutPriority(1)
                } else if m.query.isEmpty && p.s("frame", "none") == "hud" {
                    // HUD readout while idle — drop when the field needs the room
                    Text("SYS ONLINE  //  \(Date().formatted(date: .omitted, time: .shortened))").font(code(11, "Bold")).tracking(1.4)
                        .foregroundStyle(p["cyan"].opacity(0.8)).lineLimit(1).layoutPriority(-1)
                } else if !m.query.isEmpty {
                    Text(p.cased("\(m.items.count) result\(m.items.count == 1 ? "" : "s")")).font(mono(11, "Bold")).tracking(1.2).foregroundStyle(p["comment"])
                        .lineLimit(1).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: p.num("chip_radius", 5)).stroke(p["border"], lineWidth: 1))
                        .layoutPriority(-1)
                }
            }
            .padding(.horizontal, 18).frame(height: 62)
            .background(p.s("frame", "none") == "station" ? p["bg_dark"] : .clear)

            let surfaceHasCards = m.surface == .overview ? !m.overviewCards.isEmpty
                : m.surface == .themes ? !m.themeCards.isEmpty
                : !m.items.isEmpty
            if surfaceHasCards {
                if p.s("frame", "none") == "station" { p["white"].opacity(0.85).frame(height: 2) } else { divider(p) }
                // Exclusive surfaces: chrome and card source are one enum — never mix Theme: into overview.
                if m.surface == .themes { themePicker(p).frame(height: 412) }
                else if m.surface == .overview { overviewPicker(p).frame(height: 412) }
                else { results(p).frame(height: 412) }
                HStack(spacing: 16) {
                    // four hints at most (the rest live in ⌘K); narrow launchers drop to two
                    if m.surface == .themes {
                        hint("↑↓←→", "navigate"); hint("↵", "apply"); hint("esc", "back")
                    } else if m.surface == .overview {
                        hint("↑↓", "workspace"); hint("↵", "switch"); hint("esc", "close")
                    } else { ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { hint("↵", "open"); hint("⌘K", "actions"); hint("⌘C", "copy"); hint("esc", "close") }
                        HStack(spacing: 16) { hint("↵", "open"); hint("⌘K", "actions") }
                    } }
                    Spacer(minLength: 12)
                    Text(p.cased("\(p.s("brand", "VEIL")) // search")).font(mono(11, "Bold")).tracking(1.4).foregroundStyle(p["comment"]).lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 18).frame(height: 32)
                .background(p["bg_dark"]) // opaque footer — no frosted strip
                .overlay(alignment: .top) { Rectangle().fill(p["border"]).frame(height: 1) }
            }
        }
        .frame(width: p.num("width", 860))
        .background(
            ZStack(alignment: .top) {
                // Opaque theme fill only — VisualEffect / translucency killed (VEI-31).
                p["bg_float"]
                Texture(kind: p.s("texture", "scanlines"), p: p)
                accentLine(p)
            }
        )
        .clipShape(PanelShape(chamfer: p.s("corner", "round") == "chamfer", radius: p.num("radius", 16)))
        .compositingGroup() // flatten opaque chrome — no soft AA frost fringe
        .overlay(PanelShape(chamfer: p.s("corner", "round") == "chamfer", radius: p.num("radius", 16)).stroke(p["border"], lineWidth: p.num("border_width", 1)))
        .overlay { Frame(kind: p.s("frame", "none"), radius: p.num("radius", 16), p: p) }
        .overlay(alignment: .bottomTrailing) { if m.actionsOpen { ActionPanel(m: m, p: p).padding(.trailing, 16).padding(.bottom, 44) } }
        .overlay(alignment: .bottom) {
            if !m.toast.isEmpty {
                Text(p.cased(m.toast)).font(mono(12, "Bold")).tracking(1).foregroundStyle(p["bg_dark"])
                    .lineLimit(1).truncationMode(.tail).minimumScaleFactor(0.75)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(p["cyan"])).padding(.bottom, 46)
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: m.toast)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: m.actionsOpen)
        // No soft outer shadow — bled past opaque chrome like a frosted husk.
        .scaleEffect(m.shown || reduceMotion ? 1 : 0.97, anchor: p.s("place", "top") == "bottom" ? .bottom : .top)
        .opacity(m.shown ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: m.shown)
        .padding(.horizontal, 40).padding(.top, 40).padding(.bottom, p.s("place", "top") == "bottom" ? 84 : 40)
        .frame(maxHeight: .infinity, alignment: p.s("place", "top") == "bottom" ? .bottom : .top)
        .onChange(of: m.shown) { _, shown in
            if !m.renderingFixture { focused = shown }
        }
    }

    var layout: String { m.palette.s("layout", "split") }

    @ViewBuilder func results(_ p: Palette) -> some View {
        switch layout {
        case "umbra":
            HStack(spacing: 0) {
                resultList(p).padding(.horizontal, 8)
                Rectangle().fill(p["border"]).frame(width: 1)
                VStack(spacing: 0) {
                    sectionTitle("Preview", p)
                    preview(p)
                }
                .frame(width: 320)
                .background(alignment: .topTrailing) {
                    Circle()
                        .strokeBorder(p["cyan"].opacity(0.17), lineWidth: 1)
                        .frame(width: 260, height: 260)
                        .offset(x: 100, y: -158)
                        .accessibilityHidden(true)
                }
                .background(p["bg_dark"])
                .clipped()
            }
        case "ops":
            // Arasaka: a wide executive command band — directory header, one full-width column, details in a strip below
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("荒坂").font(.system(size: 15, weight: .semibold)).foregroundStyle(p["cyan"])
                    Rectangle().fill(p["cyan"]).frame(width: 18, height: 2)
                    Text("NETWORK DIRECTORY").font(mono(11, "Bold")).tracking(2.4).foregroundStyle(p["fg"])
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20).frame(height: 34).background(p["bg_dark"])
                p["cyan"].opacity(0.6).frame(height: 1)
                resultList(p).padding(.horizontal, 10)
                p["border"].frame(height: 1)
                preview(p, compact: true)
            }
        case "console":
            HStack(spacing: 8) {
                VStack(spacing: 0) { sectionTitle("RESULTS", p); resultList(p, grid: true) }
                preview(p)
            }.padding(8)
        case "transit":
            VStack(spacing: 0) {
                HStack { Text("DESTINATION"); Spacer(); Text("ACTION") }
                    .font(mono(11, "Bold")).foregroundStyle(p["fg"]).padding(.horizontal, 18).frame(height: 28)
                resultList(p)
                preview(p, compact: true)
            }
        case "airy":
            VStack(spacing: 0) { resultList(p).padding(.horizontal, 24); preview(p, compact: true) }
        case "archive":
            HStack(spacing: 0) {
                resultList(p).padding(.trailing, 4)
                preview(p).frame(width: 300).background(p["bg_dark"])
            }
        case "field":
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("FIELD\nINDEX").font(mono(19, "Bold")).foregroundStyle(p["fg"])
                    Rectangle().fill(p["cyan"]).frame(width: 28, height: 2)
                    Text("\(m.items.count)\nRESULTS").font(code(11, "Bold")).foregroundStyle(p["dim"])
                    Spacer()
                    Text("\(Image(systemName: "command")) SPACE").font(code(11)).foregroundStyle(p["comment"])
                }.padding(18).frame(width: 124).background(p["bg_dark"])
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
                    Text("GRACE").font(code(11, "Bold")).tracking(2).foregroundStyle(p["yellow"])
                    Rectangle().fill(p["yellow"].opacity(0.75)).frame(width: 30, height: 1)
                    Text(String(format: "%02d", m.items.count)).font(mono(28, "Regular")).foregroundStyle(p["fg"])
                    Text("GUIDANCE").font(code(11, "Bold")).tracking(1).foregroundStyle(p["comment"])
                    Spacer()
                    Text("↵  OPEN").font(code(11, "Bold")).foregroundStyle(p["dim"])
                }
                .padding(16).frame(width: 106).background(p["bg_dark"])
                Rectangle().fill(p["yellow"].opacity(0.3)).frame(width: 1)
                VStack(spacing: 0) { sectionTitle("SITES OF GRACE", p); resultList(p) }
                preview(p)
            }
        case "embers":
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BOREAL VALLEY").font(mono(11, "Bold")).tracking(2).foregroundStyle(p["yellow"])
                        Text("\(m.items.count) traces in the archive").font(mono(11)).foregroundStyle(p["comment"])
                            .lineLimit(1).truncationMode(.tail)
                    }.padding(.leading, 18)
                    Spacer(minLength: 8)
                    preview(p, compact: true).frame(width: 330)
                }.frame(height: 104).background(p["bg_dark"])
                p["yellow"].opacity(0.42).frame(height: 1)
                resultList(p, grid: true).padding(6)
            }
        case "posture":
            HStack(spacing: 0) {
                VStack(spacing: 0) { sectionTitle("DOJO INDEX", p); resultList(p) }
                VStack(spacing: 12) {
                    Text("INDEX").font(code(11, "Bold")).tracking(1).foregroundStyle(p["comment"])
                    ForEach(0..<5, id: \.self) { i in
                        Capsule().fill(i == min(m.selected, 4) ? p["red"] : p["line"])
                            .frame(width: 4, height: i == min(m.selected, 4) ? 42 : 22)
                    }
                    Text(String(format: "%02d", min(m.selected + 1, m.items.count)))
                        .font(code(11, "Bold")).foregroundStyle(p["dim"])
                }
                .frame(width: 42).background(p["bg_dark"])
                Rectangle().fill(p["red"].opacity(0.35)).frame(width: 1)
                preview(p)
            }
        default:
            HStack(spacing: 0) { resultList(p); preview(p, card: p.s("detail", "panel") == "card") }
        }
    }

    func themePicker(_ p: Palette) -> some View {
        let cards = m.themeCards
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                        Button { m.activate(index) } label: {
                            ThemePreview(item: item, palette: p, selected: index == m.selected)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .accessibilityAddTraits(index == m.selected ? .isSelected : [])
                    }
                }
                .padding(12)
            }
            .onChange(of: m.selected) { _, index in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { proxy.scrollTo(index) }
            }
        }
    }

    /// Theme-aware workspace overview surface (pairs with Rift mission control on ⌃⌥M).
    /// Cards come ONLY from overviewCards — never from Theme gallery `items`.
    func overviewPicker(_ p: Palette) -> some View {
        let cards = m.overviewCards
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(p.cased("Workspace Overview"))
                    .font(mono(13, "Bold")).tracking(1.6).foregroundStyle(p["yellow"])
                    .lineLimit(1).layoutPriority(1)
                Text(p.cased("⌃⌥M · Esc dismisses"))
                    .font(mono(11, "Bold")).tracking(0.8).foregroundStyle(p["dim"])
                    .lineLimit(1).layoutPriority(-1)
                Spacer(minLength: 8)
                Text(p.cased("\(cards.count) spaces"))
                    .font(mono(11, "Bold")).tracking(1.2).foregroundStyle(p["comment"])
                    .lineLimit(1).layoutPriority(1)
            }
            .padding(.horizontal, 16).frame(height: 36)
            .overlay(alignment: .bottom) { p["border"].frame(height: 1) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                            Button { m.activate(index) } label: {
                                OverviewCard(item: item, palette: p, selected: index == m.selected, index: index,
                                             windows: m.overviewThumbs[index] ?? [])
                            }
                            .buttonStyle(.plain)
                            .id(index)
                            .accessibilityAddTraits(index == m.selected ? .isSelected : [])
                        }
                    }
                    .padding(14)
                }
                .onChange(of: m.selected) { _, index in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { proxy.scrollTo(index) }
                }
            }
        }
    }

    func sectionTitle(_ text: String, _ p: Palette) -> some View {
        Text(text).font(mono(11, "Bold")).tracking(2).foregroundStyle(p["dim"])
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
                            result(item, index: i, p: p)
                                .background(RoundedRectangle(cornerRadius: max(p.num("chip_radius", 4), 3), style: .continuous).fill(p["surface"]))
                        }
                    }.padding(6)
                } else {
                    VStack(alignment: .leading, spacing: layout == "airy" ? 3 : 1) {  // eager: ~25 rows at most, and lazy rows at the clipped edge rendered blank
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
                    }.padding(.horizontal, 8).padding(.bottom, 60)  // the last row can always scroll clear of the fade
                }
            }
            // the selection glides between rows instead of jumping
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.86), value: m.selected)
            // fade the clipped bottom edge so a cut-off section header never reads as an empty group
            .mask(VStack(spacing: 0) { Color.black; LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 56) })
            .onChange(of: m.selected) { _, selected in
                if m.items.indices.contains(selected) { proxy.scrollTo(m.items[selected].id) }
            }
        }
    }

    func result(_ item: Item, index: Int, p: Palette) -> some View {
        HStack(spacing: 0) {
            if layout == "transit" {
                Text(String(index + 1))
                    .font(code(layout == "ink" ? 11 : 15, "Bold"))
                    .foregroundStyle(layout == "transit" ? p["bg_dark"] : p["comment"])
                    .frame(width: 28, height: 28)
                    .background { if layout == "transit" { Circle().fill(p["yellow"]) } }.padding(.leading, 8)
            }
            Row(item: item, selected: index == m.selected, p: p, ns: ns)
            if layout == "transit" {
                Text(item.kind == .app ? "APP" : item.kind == .file ? "FILE" : "→")
                    .font(mono(11, "Bold")).foregroundStyle(p["dim"]).padding(.trailing, 16)
            }
        }
        .overlay(alignment: .bottom) { if layout == "transit" || layout == "ink" { p["border"].frame(height: 1) } }
        .contentShape(Rectangle()).id(item.id)
        .onDrag { item.path.flatMap { NSItemProvider(contentsOf: URL(fileURLWithPath: $0)) } ?? NSItemProvider(object: item.title as NSString) }
        .pressable()
        .onTapGesture { m.activate(index) }
        .onHover { if $0 && NSEvent.mouseLocation != m.openMouse { m.selected = index; m.userMoved = true } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(index == m.selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { m.activate(index) }
    }

    // brand chip: filled plate, outline, or plain colored text
    @ViewBuilder func chip(_ p: Palette) -> some View {
        let shape = RoundedRectangle(cornerRadius: p.num("chip_radius", 5), style: .continuous)
        let t = Text(p.s("symbol", "").isEmpty ? p.s("chip", "NC//") : p.s("brand", "Search"))
            .font(mono(13, "ExtraBold")).lineLimit(1).truncationMode(.tail)
        if SourceSymbol.load(p.s("symbol", "")) != nil {
            let mark = SourceSymbol(name: p.s("symbol", ""))
            // fit the mark in a 30pt square-ish slot at its own proportions
            let sz = p.num("symbol_size", 30)  // per theme: Eclipse shows the Brand larger
            mark.fill(p["cyan"], style: FillStyle(eoFill: true))
                .frame(width: min(sz * 1.4, sz * mark.aspect), height: min(sz, sz * 1.4 / mark.aspect)).frame(minWidth: sz + 4).frame(height: sz + 6)
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
            Text(key).font(mono(12, "Bold")).foregroundStyle(m.palette["dim"])
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 4).stroke(m.palette["border"], lineWidth: 1))
            Text(label).font(mono(12, "Regular")).foregroundStyle(m.palette["dim"])  // 12 pt: the footer read as fine print at 11
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
            Text(p.cased("actions")).font(mono(11, "Bold")).tracking(1.6).foregroundStyle(p["comment"])
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
            ForEach(Array(acts.enumerated()), id: \.element.id) { i, a in
                HStack(spacing: 10) {
                    Image(systemName: a.symbol).font(.system(size: 12, weight: .semibold)).frame(width: 18)
                        .foregroundStyle(i == m.actionIndex ? p["bg_dark"] : p["cyan"])
                    Text(a.title).font(mono(12.5, "Medium")).foregroundStyle(i == m.actionIndex ? p["bg_dark"] : p["fg"])
                        .lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !a.keys.isEmpty {
                        Text(a.keys).font(code(10.5, "Bold")).foregroundStyle(i == m.actionIndex ? p["bg_dark"].opacity(0.7) : p["comment"])
                            .lineLimit(1).layoutPriority(1)
                    }
                }
                .padding(.horizontal, 12).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: max(p.num("chip_radius", 5), 2), style: .continuous)
                    .fill(i == m.actionIndex ? p["cyan"] : .clear))
                .contentShape(Rectangle())
                .pressable()
                .onTapGesture { m.runAction(i) }
                .onHover { if $0 { m.actionIndex = i } }
            }
        }
        .padding(6).frame(width: 300)
        .background(RoundedRectangle(cornerRadius: min(p.num("radius", 16), 12), style: .circular).fill(p["surface"]))
        .clipShape(RoundedRectangle(cornerRadius: min(p.num("radius", 16), 12), style: .circular))
        .compositingGroup()
        .overlay(RoundedRectangle(cornerRadius: min(p.num("radius", 16), 12), style: .continuous).stroke(p["border"], lineWidth: 1))
        
    }
}

/// Former frosted material — VEI-31: solid opaque fill only (never NSVisualEffectView).
struct VisualEffect: View {
    var body: some View { Palette.load()["bg_float"] }
}

/// Esc → one-shot overlay kill + `veil dismiss-popups` (SketchyBar + Rift overview).
/// NSEvent global monitor (Veil Search needs Accessibility). Never locks; never ScreenSaverEngine.
enum EscDismiss {
    private static var veilBin = NSString(string: "~/.local/bin/veil").expandingTildeInPath

    static func install(veilBin: String) {
        Self.veilBin = veilBin
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { e in
            guard e.keyCode == UInt16(kVK_Escape) else { return }
            run()
        }
    }

    static func run() {
        // Sync kill first — never wait on Process spawn while Control/Quick stick.
        if Thread.isMainThread {
            OutsideClick.dismissAll()
        } else {
            DispatchQueue.main.sync { OutsideClick.dismissAll() }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: veilBin)
            task.arguments = ["dismiss-popups"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
        }
    }
}

// MARK: panel + app

final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { OutsideClick.dismissAll() }
    override var canBecomeMain: Bool { false }
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = Model()
    var panel: Panel!
    var hotKey: EventHotKeyRef?
    var lastToggle = Date.distantPast
    /// Ignore resignKey briefly after show so the panel is not dismissed by the open itself.
    var ignoreResignUntil = Date.distantPast
    /// Distributed hide from a prior `dismiss-popups` must not win over a just-posted show.
    var suppressHideUntil = Date.distantPast
    /// Monotonic show generation — stale force-hides posted before this show are ignored.
    var showGeneration = 0
    var lastShowAt = Date.distantPast
    /// Outside-click monitors for the launcher surface (VEI-53).
    var outsideMonitors: [Any] = []
    /// Global keystroke sink while launcher is up — catches leaks if focus races.
    var focusSink: Any?
    var focusRetryTokens: [UUID] = []

    func applicationDidFinishLaunching(_ n: Notification) {
        if Model.migrateRankingPrivacy(.standard) { model.usage = [:]; model.history = []; model.pins = []; model.queryChoices = [:] }
        // Activating panel — Spotlight-grade focus steal (nonactivating left keys in the prior app).
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 940, height: 640),
                      styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        // Above normal / full-screen media apps so overview/theme surfaces stay visible for product use.
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        model.close = { [weak self] in self?.hide() }
        // Pre-warm the SwiftUI tree so the first ⌘Space does not pay hosting-view compile cost.
        panel.contentView = NSHostingView(rootView: LauncherView(m: model))
        panel.contentView?.wantsLayer = true
        panel.setFrame(NSRect(x: 0, y: 0, width: 1, height: 1), display: false)
        panel.orderOut(nil)

        // Glyph / Nothing OS surfaces (⌃⌥ + letter). Does not steal Option←/→ word navigation.
        GlyphShell.registerHotkeys()
        // Pin-able desktop Glyph widgets (wallpaper layer) — every theme.
        if !veilIsOff { DesktopGlyphBoard.shared.start() }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel.isVisible,
                  e.window === self.panel || (e.window == nil && self.panel.isKeyWindow) else { return e }
            let cmd = e.modifierFlags.contains(.command), ctrl = e.modifierFlags.contains(.control)
            let shift = e.modifierFlags.contains(.shift), option = e.modifierFlags.contains(.option)
            let editor = self.panel.firstResponder as? NSTextView
            let key = Int(e.keyCode)
            if cmd && !ctrl && !option {
                // This accessory app has no Edit menu to dispatch standard text shortcuts.
                switch key {
                case kVK_ANSI_A where !shift: editor?.selectAll(nil); return nil
                case kVK_ANSI_C where !shift:
                    if let editor, editor.selectedRange().length > 0 { editor.copy(nil) }
                    else if !self.model.actionsOpen { self.model.copySelected() }
                    return nil
                case kVK_ANSI_V where !shift: editor?.pasteAsPlainText(nil); return nil
                case kVK_ANSI_X where !shift: editor?.cut(nil); return nil
                case kVK_ANSI_Z:
                    if shift { editor?.undoManager?.redo() }
                    else { editor?.undoManager?.undo() }
                    return nil
                default: break
                }
            }
            // a second ⌘Space closes the launcher even when the search field has the keyboard
            if cmd && !ctrl && !option && !shift && key == kVK_ANSI_T {
                self.model.toggleThemePicker()
                return nil
            }
            if cmd, Int(e.keyCode) == kVK_Space { self.lastToggle = Date(); self.hide(); return nil }  // the hotkey must not reopen it
            // ⌘K action panel takes the keyboard while open
            if self.model.actionsOpen {
                let n = self.model.currentActions.count
                switch Int(e.keyCode) {
                case kVK_Escape: self.model.actionsOpen = false; return nil
                case kVK_ANSI_K where cmd: self.model.actionsOpen = false; return nil
                case kVK_DownArrow: self.model.actionIndex = n == 0 ? 0 : (self.model.actionIndex + 1) % n; return nil
                case kVK_UpArrow: self.model.actionIndex = n == 0 ? 0 : (self.model.actionIndex - 1 + n) % n; return nil
                case kVK_Return, kVK_ANSI_KeypadEnter: self.model.runAction(self.model.actionIndex); return nil
                default: return nil
                }
            }
            switch Int(e.keyCode) {
            case kVK_Escape:  // Always bury sibling overlays; never leave Control/Quick stacked.
                MainActor.assumeIsolated {
                    GlyphShell.shared.dismiss()
                    VeilPanelHost.shared.dismissImmediate()
                }
                if self.model.surface == .overview {
                    self.hide(force: true); return nil
                }
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
            case kVK_RightArrow where !cmd && !option:
                // → at the end of the query accepts the ghost completion
                if let rest = self.model.completion, let tv = self.panel.firstResponder as? NSTextView,
                   tv.selectedRange().location == (self.model.query as NSString).length {
                    self.model.query += rest; return nil
                }
                // in a grid, ←/→ move tiles once you're navigating them (or the field is empty); otherwise they edit the query
                if self.model.gridColumns > 1 && (self.model.choosingTheme || self.model.userMoved || self.model.query.isEmpty) { self.model.moveGrid(dx: 1, dy: 0); return nil }
                return e
            // ⌥←/⌥→ must reach the field for word navigation (never steal for grid)
            case kVK_LeftArrow where !cmd && !option && self.model.gridColumns > 1 && (self.model.choosingTheme || self.model.userMoved || self.model.query.isEmpty):
                self.model.moveGrid(dx: -1, dy: 0); return nil
            case kVK_LeftArrow where option, kVK_RightArrow where option:
                return e
            case kVK_ANSI_L where cmd: self.showLargeType(); return nil
            case kVK_ANSI_K where cmd: self.model.actionIndex = 0; self.model.actionsOpen = !self.model.currentActions.isEmpty; return nil
            // ⌘⌫ deletes the query text like every macOS field; Move to Trash stays in the ⌘K actions
            case kVK_Delete where cmd: if !self.model.query.isEmpty { return e }; self.model.trashSelected(); return nil
            case kVK_DownArrow:
                if self.model.historyIndex >= 0 { _ = self.model.recallHistory(-1); return nil }
                if self.model.gridColumns > 1 { self.model.moveGrid(dx: 0, dy: 1); return nil }
                self.model.move(1); return nil
            case kVK_UpArrow:
                if (self.model.query.isEmpty || self.model.historyIndex >= 0), self.model.recallHistory(1) { return nil }
                if self.model.gridColumns > 1 { self.model.moveGrid(dx: 0, dy: -1); return nil }
                self.model.move(-1); return nil
            case kVK_Tab:
                // Tab enters a folder while browsing; otherwise it moves the selection
                if !e.modifierFlags.contains(.shift), self.model.items.indices.contains(self.model.selected),
                   self.model.items[self.model.selected].extra == "dir", let p = self.model.items[self.model.selected].path {
                    self.model.query = (p as NSString).abbreviatingWithTildeInPath + "/"; return nil
                }
                self.model.move(e.modifierFlags.contains(.shift) ? -1 : 1); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                // Dismiss on Enter: run the selection when there is one, otherwise just close.
                // Closing here (not on the launched app's activation) is what the user feels as "Enter".
                let i = self.model.selected
                if self.model.items.indices.contains(i), !self.model.items[i].isInformational {
                    self.model.activate(reveal: cmd, paste: e.modifierFlags.contains(.option))
                } else {
                    self.hide()
                }
                return nil
            case kVK_ANSI_N where ctrl: self.model.move(1); return nil
            case kVK_ANSI_P where ctrl: self.model.move(-1); return nil
            case kVK_ANSI_O where ctrl: self.model.activate(reveal: true); return nil
            case kVK_ANSI_Y where cmd: self.model.quickLook(); return nil
            default: return e
            }
        }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard status == noErr, hk.signature == OSType(0x4E43_5348), [1, 2, 3, 4].contains(hk.id) else { return OSStatus(eventNotHandledErr) }
            let id = hk.id
            // Spotlight-speed: run on this turn — DispatchQueue.main.async let the next keystrokes
            // hit the previously focused app before the search field exists.
            let run = {
                if id == 2 { VeilMode.toggle() }
                else if id == 3 { (NSApp.delegate as? App)?.show(query: "theme") }  // ⌃⌥T — reliable when Cursor steals ⌘T
                else if id == 4 {  // ⌃⌥O — Control panel (Quick already owns ⌃⌥A in GlyphShell)
                    if let app = NSApp.delegate as? App, app.panel.isVisible {
                        app.hide(force: true)
                    } else {
                        MainActor.assumeIsolated { GlyphShell.shared.dismiss() }
                    }
                    Task { @MainActor in
                        VeilPanelHost.shared.toggle(.control, near: VeilPanelHost.sketchybarItemRect(for: .control))
                    }
                }
                else { (NSApp.delegate as? App)?.toggle() }
            }
            if Thread.isMainThread { run() } else { DispatchQueue.main.sync(execute: run) }
            return noErr
        }, 1, &spec, nil, nil)
        // ⌃⌥⌘V turns Veil on or off; it stays registered while Veil is off, so the way back is always there
        var toggleKey: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | optionKey | controlKey), EventHotKeyID(signature: OSType(0x4E43_5348), id: 2),
                            GetApplicationEventTarget(), 0, &toggleKey)
        // ⌃⌥T opens the theme gallery even when Cursor owns ⌘T
        var themesKey: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_T), UInt32(controlKey | optionKey), EventHotKeyID(signature: OSType(0x4E43_5348), id: 3),
                            GetApplicationEventTarget(), 0, &themesKey)
        // ⌃⌥O opens Control (mouse-only before VEI-53). Avoid Glyph chords + Option←/→.
        var controlHotKey: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_O), UInt32(controlKey | optionKey), EventHotKeyID(signature: OSType(0x4E43_5348), id: 4),
                            GetApplicationEventTarget(), 0, &controlHotKey)
        if !veilIsOff { registerSearchKey() }
        // Esc dismisses every overlay + SketchyBar/Rift without locking anything.
        EscDismiss.install(veilBin: home + "/.local/bin/veil")
        // Shared dismiss registry — Lane C should also wire panel outside-click → dismissAll.
        OutsideClick.register("launcher") { [weak self] in self?.hide(force: true) }
        OutsideClick.register("glyph") {
            MainActor.assumeIsolated { GlyphShell.shared.dismiss() }
        }
        OutsideClick.register("veil-panel") {
            MainActor.assumeIsolated { VeilPanelHost.shared.dismissImmediate() }
        }
        // veil off / on: step aside or come back
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.mode"), object: nil, queue: .main) { [weak self] n in
            guard let self else { return }
            if (n.object as? String) == "off" {
                if let k = self.hotKey { UnregisterEventHotKey(k); self.hotKey = nil }
                self.hide()
                self.dismissLargeType()
                OSD.shared.dismiss()
                self.splash?.orderOut(nil)
                self.splash?.contentView = nil
                self.splash = nil
                MediaKeys.shared.stop()
                FocusPulse.shared.setEnabled(false)
                Task { @MainActor in
                    VeilBarController.shared.stop()
                    VeilPanelHost.shared.dismiss()
                    VeilHost.shared.stopChrome()
                }
                self.band.reload(Palette.load())
            } else {
                FocusPulse.shared.setEnabled(true)
                MediaKeys.shared.start()
                // Spotlight lets go of ⌘Space a beat after its shortcut is switched off
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.registerSearchKey() }
                self.band.reload(Palette.load())
                Task { @MainActor in
                    VeilBarController.shared.start()
                    VeilHost.shared.start()
                }
            }
            ClipHistory.shared.syncPolling()
        }
        // veil launch --query "x" (and screenshots/tests) open the panel with a query
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.show"), object: nil, queue: .main) { [weak self] n in
            self?.show(query: n.object as? String ?? "")
        }
        // veil dismiss-popups / Esc path — bury launcher AND every stacked overlay
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.hide"), object: nil, queue: .main) { [weak self] n in
            guard let self else { return }
            let obj = (n.object as? String) ?? ""
            // Epoch-ms from `veil dismiss-popups`: ignore hides requested before the latest show
            // (fixes themes→dismiss→overview and rapid open/close where a late hide kills the new panel).
            if let hideMs = Double(obj), hideMs > 1_000_000 {
                let hideAt = Date(timeIntervalSince1970: hideMs / 1000.0)
                if hideAt < self.lastShowAt { return }
            } else if obj.lowercased() == "force" {
                // legacy force — honor when panel is up
            } else if Date() < self.suppressHideUntil, !self.panel.isVisible {
                return
            }
            OutsideClick.dismissAll()
        }
        // functional check: top results for one query per feature, written to ~/Library/Caches/veil-search-verify.txt
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.verify"), object: nil, queue: .main) { [weak self] _ in
            guard let m = self?.model else { return }
            m.refresh(updateHiddenResults: true)
            let queries = ["safari", "sfri", "wifi", "2+2*3", "sqrt(144)", "15% of 80", "10 km to mi", "100 f to c", "100 usd to eur", "time in tokyo",
                           "serendipity", "weather", "uuid", "#ff8800", ":fire", "upper", "lock", "volume 30", "quit finder", "g swift",
                           "yt lofi", "so swift", "~/Developer/", "pdf: whitepaper", "lethean", "theme", "github.com", "README.md",
                           "event lunch friday 1pm", "remind call mum at 6pm", "cal", "tabs", "contacts", "m export", "clip", "password"]
            var out: [String] = []
            func dump(_ i: Int) {
                guard i < queries.count else {
                    m.cancelFileSearch(); m.query = ""
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
            m.cancelFileSearch()
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
        // Theme apply finished — drop cached palette/ws so overview matches the bar immediately.
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.theme"), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.model.palette = Palette.load()
            self.model.ncCache = ncItems(liveWorkspaceNames(paletteWS: self.model.wsNames))
            self.band.reload(self.model.palette)
            Task { @MainActor in
                if veilIsOff || !VeilFeature.veilBar { VeilBarController.shared.stop() } else { VeilBarController.shared.start() }
                if !veilIsOff { VeilHost.shared.reloadBorders() }
            }
            if self.model.shown {
                if self.model.surface == .overview {
                    self.model.enterOverview()
                } else if self.model.surface == .themes {
                    self.model.enterThemes()
                } else {
                    self.model.search()
                }
            }
        }
        // veil-theme: set this image as the desktop picture on every screen
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.search.desktop"), object: nil, queue: .main) { n in
            guard let path = n.object as? String else { return }
            for screen in NSScreen.screens { try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:]) }
            self.band.reload(Palette.load())
        }
        band.reload(Palette.load())
        ClipHistory.shared.start()
        OSD.shared.palette = { [weak self] in self?.model.palette ?? Palette.load() }
        MediaKeys.shared.start()
        StateWatch.shared.start()
        FocusPulse.shared.palette = { [weak self] in self?.model.palette ?? Palette.load() }
        FocusPulse.shared.start()
        // Thin in-process bar (default) + supervise borders/Rift under this process.
        if !veilIsOff {
            VeilBarController.shared.start()
            VeilHost.shared.start()
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.host"), object: nil, queue: .main) { n in
            let raw = ((n.object as? String) ?? "").lowercased()
            Task { @MainActor in
                switch raw {
                case "quit-rift", "stop-rift": VeilHost.shared.stopRift()
                case "start", "recover": VeilHost.shared.start()
                case "reload-borders": VeilHost.shared.reloadBorders()
                default: break
                }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.panel"), object: nil, queue: .main) { n in
            let raw = ((n.object as? String) ?? "").lowercased()
            Task { @MainActor in
                // Re-resolve SketchyBar button bounds each open so panels hug the clicked item.
                switch raw {
                case "music": VeilPanelHost.shared.toggle(.music, near: VeilPanelHost.sketchybarItemRect(for: .music))
                case "control", "city": VeilPanelHost.shared.toggle(.control, near: VeilPanelHost.sketchybarItemRect(for: .control))
                case "keys": VeilPanelHost.shared.toggle(.keys, near: VeilPanelHost.sketchybarItemRect(for: .keys))
                case "dismiss", "off": OutsideClick.dismissAll()
                default: break
                }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("app.veil.desktop-glyphs"), object: nil, queue: .main) { n in
            let raw = ((n.object as? String) ?? "").lowercased()
            Task { @MainActor in
                if raw.hasPrefix("add:") {
                    let name = String(raw.dropFirst(4))
                    if let id = DesktopGlyphID(rawValue: name) {
                        DesktopGlyphBoard.shared.setPin(id, pinned: true)
                    }
                    return
                }
                if raw.hasPrefix("remove:") {
                    let name = String(raw.dropFirst(7))
                    if let id = DesktopGlyphID(rawValue: name) {
                        DesktopGlyphBoard.shared.removePin(id)
                    }
                    return
                }
                switch raw {
                case "toggle", "on", "off": DesktopGlyphBoard.shared.toggleEnabled()
                case "refresh", "reload": DesktopGlyphBoard.shared.refresh()
                case "reset", "default": DesktopGlyphBoard.shared.resetToDefault()
                case "prove-drag":
                    // Same pipeline as AX mouse drag — for screenshots when CGEvent is blocked.
                    DesktopGlyphBoard.shared.proveDrag(.cava, toCol: 14, toRow: 7)
                case "prove-remove":
                    DesktopGlyphBoard.shared.proveRemove(.cava)
                case "dismiss-panels":
                    OutsideClick.dismissAll()
                default: DesktopGlyphBoard.shared.start()
                }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                         object: nil, queue: .main) { [weak self] _ in self?.syncWindowMotion() }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.band.reload(Palette.load())
            Task { @MainActor in
                if !veilIsOff, VeilFeature.veilBar { VeilBarController.shared.start() }
            }
        }
    }

    // Follow a live accessibility change without polling or waiting for a theme reapply.
    func syncWindowMotion() {
        let animate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion &&
            !FileManager.default.fileExists(atPath: ncRoot + "/generated/quiet")
        DispatchQueue.global(qos: .utility).async {
            for setting in ["settings.animate", "settings.ui.mission_control.fade_enabled"] {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: home + "/.local/bin/rift-cli")
                task.arguments = ["execute", "config", "set", setting, animate ? "true" : "false"]
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                if (try? task.run()) != nil { task.waitUntilExit() }
            }
        }
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
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let w = Panel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.level = .screenSaver; w.backgroundColor = .clear; w.isOpaque = false; w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let p = model.palette
        w.contentView = NSHostingView(rootView: ZStack {
            p["bg"] // opaque full-screen — no translucent scrim
            Text(text).font(mono(min(160, max(48, 2400 / CGFloat(max(text.count, 1)))), "Bold")).foregroundStyle(p["white"])
                .multilineTextAlignment(.center).lineLimit(6).minimumScaleFactor(0.15)
                .frame(maxWidth: .infinity).padding(60)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(p["bg_float"]))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(120)
            VStack { Spacer(); Text("Press any key or click to close").font(code(12)).foregroundStyle(p["comment"]).padding(.bottom, 40) }
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
        guard !veilIsOff, let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        MenuItems.frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        ClipHistory.shared.setLauncherActive(true)
        // Never stack: bury Control / Quick / music / Glyph before search owns the keyboard.
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                GlyphShell.shared.dismiss()
                VeilPanelHost.shared.dismissImmediate()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    GlyphShell.shared.dismiss()
                    VeilPanelHost.shared.dismissImmediate()
                }
            }
        }
        // Beat a late dismiss-popups hide from the previous surface (killer: themes → dismiss → overview).
        showGeneration += 1
        lastShowAt = Date()
        suppressHideUntil = Date().addingTimeInterval(1.0)
        ignoreResignUntil = Date().addingTimeInterval(0.45)

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch q {
        case "overview":
            model.enterOverview()
        case "theme":
            model.enterThemes()
        default:
            model.surface = .search
            model.overviewCards = []
            model.themeCards = []
            // Clear query synchronously so the field is empty and focused before any keystroke arrives.
            if !query.isEmpty {
                if model.query == query { model.search() } else { model.query = query }
            } else if !model.query.isEmpty {
                model.renderingFixture = true
                model.query = ""
                model.renderingFixture = false
                model.items = []
            }
        }
        model.selected = 0
        model.openMouse = NSEvent.mouseLocation
        model.shown = true

        // Pre-warmed hosting view: never rebuild on the hotkey path.
        if !(panel.contentView is NSHostingView<LauncherView>) {
            panel.contentView = NSHostingView(rootView: LauncherView(m: model))
            panel.contentView?.wantsLayer = true
        }
        let f = screen.frame
        let p = model.palette
        let width = min(f.width, p.num("width", 860) + 80)
        let height = min(f.height, 640)
        // Restore from the idle 1×1 collapse in one setFrame (cheaper than setContentSize + top-left).
        let top: CGFloat
        switch p.s("place", "top") {
        case "center": top = f.maxY - f.height * 0.26 + 40
        case "banner": top = f.maxY - 44 + 40
        case "bottom": top = f.minY + 48 - 40 + height
        default: top = f.maxY - f.height * 0.18 + 40
        }
        let originY = min(top, f.maxY + 40) - height
        panel.setFrame(NSRect(x: f.midX - width / 2, y: originY, width: width, height: height), display: false)

        // Spotlight path: hard activate + key + field focus BEFORE heavy work / scrim.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        stealFocus()
        installFocusSink()
        OutsideClick.remove(&outsideMonitors)
        outsideMonitors = OutsideClick.install(
            window: panel,
            ignoreUntil: Date().addingTimeInterval(0.35),
            extraSafeFrames: {
                var frames: [NSRect] = []
                MainActor.assumeIsolated {
                    if let bar = VeilBarController.shared.barWindowFrame { frames.append(bar) }
                }
                return frames
            },
            onOutside: { OutsideClick.dismissAll() }
        )

        // Deferred: clipboard snapshot, source refresh, scrim — never block first keystroke.
        DispatchQueue.main.async {
            ClipHistory.shared.capture()
            Scrim.shared.show(on: screen, enabled: p.flag("scrim"))
            self.model.refresh()
            if self.model.surface == .overview { self.model.enterOverview() }
            else if self.model.surface == .themes { self.model.enterThemes() }
            // Re-assert focus in case SwiftUI rebuilt the field after refresh.
            self.stealFocus()
        }
    }

    /// Spotlight-grade focus: activate, key the panel, put the caret in the search field.
    func stealFocus() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        if let field = panel.contentView?.firstTextField {
            panel.makeFirstResponder(field)
        }
    }

    /// Global sink while launcher is visible — if focus races, re-steal and ingest the key.
    func installFocusSink() {
        removeFocusSink()
        let gen = showGeneration
        focusSink = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel.isVisible, self.showGeneration == gen else { return }
            if e.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async { OutsideClick.dismissAll() }
                return
            }
            guard !self.panel.isKeyWindow else { return }
            // Reclaim focus; ingest printable chars so they never vanish into the prior app alone.
            DispatchQueue.main.async {
                guard self.panel.isVisible else { return }
                self.stealFocus()
                let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
                if mods.contains(.command) || mods.contains(.control) { return }
                if e.keyCode == UInt16(kVK_Delete) || e.keyCode == UInt16(kVK_ForwardDelete) {
                    if !self.model.query.isEmpty { self.model.query.removeLast() }
                    return
                }
                if let chars = e.characters, !chars.isEmpty,
                   chars.unicodeScalars.allSatisfy({ $0.value >= 0x20 || $0 == "\t" }) {
                    self.model.query += chars.filter { $0 != "\t" && $0 != "\r" && $0 != "\n" }
                }
            }
        }
        focusRetryTokens = []
        for delay in [0.04, 0.10, 0.22] as [TimeInterval] {
            let token = UUID()
            focusRetryTokens.append(token)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.focusRetryTokens.contains(token), self.panel.isVisible else { return }
                self.stealFocus()
            }
        }
    }

    func removeFocusSink() {
        if let focusSink { NSEvent.removeMonitor(focusSink) }
        focusSink = nil
        focusRetryTokens = []
    }

    var splash: NSWindow?
    let band = NotchBand()

    func showSplash() {
        let p = Palette.load()
        model.palette = p
        model.ncCache = ncItems(liveWorkspaceNames(paletteWS: model.wsNames))
        if model.shown { model.search() }
        Task { @MainActor in DesktopGlyphBoard.shared.refresh() }
        splash?.orderOut(nil); splash?.contentView = nil
        guard !veilIsOff, let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .screenSaver
        w.backgroundColor = .clear
        w.isOpaque = false
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        w.contentView = NSHostingView(rootView: SplashView(p: p, size: screen.frame.size))
        w.alphaValue = 0
        w.orderFrontRegardless()
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { $0.duration = reduce ? 0 : 0.2; w.animator().alphaValue = 1 }
        splash = w
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduce ? 0.8 : 1.15)) { [weak self, weak w] in
            guard let self, let w, self.splash === w else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = reduce ? 0 : 0.28; w.animator().alphaValue = 0 }, completionHandler: {
                w.orderOut(nil)
                w.contentView = nil
                if self.splash === w { self.splash = nil }
            })
        }
    }

    func hide(force: Bool = true) {
        _ = force
        OutsideClick.remove(&outsideMonitors)
        removeFocusSink()
        // Instant dismiss first — never wait on teardown or the launched app.
        let wasVisible = panel.isVisible
        if wasVisible { panel.orderOut(nil) }
        model.shown = false
        model.actionsOpen = false
        ClipHistory.shared.setLauncherActive(false)
        Scrim.shared.hide()
        // Sync sibling kill — async Task left Control/music stuck over real work.
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                GlyphShell.shared.dismiss()
                VeilPanelHost.shared.dismissImmediate()
            }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    GlyphShell.shared.dismiss()
                    VeilPanelHost.shared.dismissImmediate()
                }
            }
        }

        guard wasVisible || model.surface != .search else {
            model.overviewCards = []
            model.overviewThumbs = [:]
            model.themeCards = []
            model.windows = [:]
            return
        }
        model.historyIndex = -1
        model.mode = 0
        let q = model.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        model.surface = .search
        model.overviewCards = []
        model.overviewThumbs = [:]
        model.themeCards = []
        model.windows = [:]
        if q == "overview" || q == "theme" || !model.query.isEmpty {
            model.renderingFixture = true
            model.query = ""
            model.renderingFixture = false
            model.items = []
        }
        model.cancelFileSearch()
        Weather.shared.cancelPending()
        // Keep the hosting view warm for Spotlight-speed reopen; only collapse the backing store.
        panel.setFrame(NSRect(x: 0, y: 0, width: 1, height: 1), display: false)
        IconCache.clear()
        malloc_zone_pressure_relief(nil, 0)
    }

    func registerSearchKey() {
        guard hotKey == nil, !veilIsOff else { return }
        let id = EventHotKeyID(signature: OSType(0x4E43_5348), id: 1)  // "NCSH"
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { NSLog("veil-search: could not register ⌘Space (status \(status)); is Spotlight still using it?") }
    }

    func windowDidResignKey(_ n: Notification) {
        guard Date() >= ignoreResignUntil else { return }
        hide()
    }
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
    do {
        let model = Model()
        model.ncCache = [
            Item(kind: .nc, title: "Theme: Umbra", subtitle: "Current theme", symbol: "paintpalette", action: .run(["veil-theme", "apply", "umbra"])),
            Item(kind: .nc, title: "Theme: Night City", symbol: "paintpalette", action: .run(["veil-theme", "apply", "night-city"])),
            Item(kind: .nc, title: "Workspace Overview", action: .run(["veil", "overview"]))
        ]
        model.toggleThemePicker()
        precondition(model.surface == .themes)
        precondition(model.gridColumns == 3 && model.themeCards.count == 2 && model.themeCards.first?.title == "Theme: Umbra")
        precondition(!model.searchingFiles && model.completion == nil)
        model.moveGrid(dx: 1, dy: 0)
        precondition(model.themeCards[model.selected].title == "Theme: Night City")
        // Gallery must not pollute overview surface
        model.enterOverview()
        precondition(model.surface == .overview)
        precondition(model.overviewCards.allSatisfy { !$0.title.hasPrefix("Theme:") })
        precondition(model.themeCards.isEmpty)
        model.toggleThemePicker()  // from overview → themes via toggle clears? enterThemes path
        // toggle from themes closes; ensure clean exit from themes
        if model.surface == .themes { model.toggleThemePicker() }
        precondition(model.surface == .search)
    }
    do {
        let cards = overviewWorkspaceCards(paletteWS: ["FOCUS", "BUILD", "STUDY", "MEDIA", "FLOAT"])
        precondition(cards.count == 5)
        precondition(cards.map(\.title) == ["FOCUS", "BUILD", "STUDY", "MEDIA", "FLOAT"])
        precondition(cards.allSatisfy { !$0.title.hasPrefix("Theme:") })
        precondition(isNumericWorkspaceToken("3") && !isNumericWorkspaceToken("WALL"))
        let model = Model()
        model.renderingFixture = true
        model.enterThemes()
        precondition(model.surface == .themes)
        model.enterOverview()
        precondition(model.surface == .overview)
        precondition(model.overviewCards.allSatisfy { !$0.title.hasPrefix("Theme:") })
        precondition(model.themeCards.isEmpty)
        model.renderingFixture = false
        model.cancelFileSearch()
    }
    for typo in ["sfaari", "safri", "safaari", "safary", "xafari"] {
        precondition(score(typo, "Safari").map { $0 >= 510 } == true)
    }
    precondition(score("uuid", "GUID") == nil)
    do {
        let safari = Item(kind: .app, title: "Safari", action: .open(safeURL("about:blank")))
        let preview = Item(kind: .app, title: "Safari Preview", action: .open(safeURL("about:blank")))
        let safety = Item(kind: .app, title: "Safety", action: .open(safeURL("about:blank")))
        let model = Model()
        model.apps = [preview, safari, safety]
        model.usage = [:]
        model.queryChoices = ["saf": [preview.learningKey: 5], "safari": [preview.learningKey: 5], "safary": [safari.learningKey: 5]]
        model.query = "saf"
        precondition(model.items.first?.title == "Safari Preview")
        model.query = "safari"
        precondition(model.items.first?.title == "Safari")
        model.query = "safary"
        precondition(model.items.first?.title == "Safari")
        model.query = "safety"
        precondition(model.items.first?.title == "Safety")
        model.query = "saf"
        model.move(1)
        let selected = model.items[model.selected].resultIdentity
        model.apps.append(Item(kind: .app, title: "Saf", action: .open(safeURL("about:blank"))))
        model.search()
        precondition(model.items[model.selected].resultIdentity == selected)
        model.cancelFileSearch()
    }
    precondition(calc("sqrt(16)+2^3") == 12 && calc("15% of 80") == 12 && abs((calc("sin(pi/2)") ?? 0) - 1) < 1e-9)
    precondition(unitAnswers("10 km to mi").first?.title.contains("6.2137") == true)
    precondition(unitAnswers("100 f to c").count == 1 && unitAnswers("10 kg to km").isEmpty)
    precondition(timeAnswer("time in tokyo")?.title.contains("Tokyo") == true)
    precondition(kindFilter("pdf: report")?.0 == "com.adobe.pdf" && kindFilter("report") == nil)
    precondition(prefixSearch("yt lofi")?.title.contains("YouTube") == true)
        // URL detection: real domains open, filenames don't
    do { let m = Model(); m.renderingFixture = true; m.query = "README.md"; m.renderingFixture = false
         m.search(); precondition(!m.items.contains { $0.title.hasPrefix("Open README") })
         m.query = "github.com"; precondition(m.items.contains { $0.title == "Open github.com" }); m.cancelFileSearch() }
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
        m.cancelFileSearch()
    }
        precondition(webSearch("c++ & rust").absoluteString == "https://www.google.com/search?q=c%2B%2B%20%26%20rust")
    precondition(score("sfr", "Safari") == nil && score("saf", "Workspace 5 · FREE") == nil)
    // clipboard history never keeps tokens copied from a terminal, but keeps ordinary long words, URLs and paths
    precondition(ClipHistory.looksLikeSecret("ghp_16C7e42F292c6912E7710c838347Ae178B4a"))
    precondition(ClipHistory.looksLikeSecret("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"))
    precondition(ClipHistory.looksLikeSecret("Xq7pL2mZ9vR4tK8wB3nC6yH1"))
    precondition(!canRememberQuery("clip private words") && !canRememberQuery("url private words") && canRememberQuery("safari"))
    precondition(!Item(kind: .answer, title: "private clipboard text", action: .copy("private clipboard text"), extra: "clip").canPersist)
    precondition(Item(kind: .answer, title: "Weather unavailable", action: .copy("")).isInformational)
    do {
        let model = Model()
        model.query = "first query"
        precondition(model.searchingFiles)
        model.fileItems = [Item(kind: .file, title: "old-result.txt", action: .copy("old"))]
        model.query = "second query"
        precondition(model.fileItems.isEmpty && !model.items.contains { $0.title == "old-result.txt" })
        model.query = ":fire"
        precondition(!model.searchingFiles)
        model.cancelFileSearch()
    }
    do {
        let name = "app.veil.search.selftest.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        defer { store.removePersistentDomain(forName: name) }
        for key in ["usage", "history", "pins", "queryChoices"] { store.set(["example-private-content"], forKey: key) }
        precondition(Model.migrateRankingPrivacy(store))
        precondition(["usage", "history", "pins", "queryChoices"].allSatisfy { store.object(forKey: $0) == nil })
        store.set(["Safari": 1], forKey: "usage")
        precondition(!Model.migrateRankingPrivacy(store) && store.dictionary(forKey: "usage")?["Safari"] as? Int == 1)
    }
    precondition(ClipHistory.looksLikeSecret("export TOKEN=glrt-ExampleCredentialValue1234.01.demo"))
    precondition(ClipHistory.looksLikeSecret("curl -H 'Authorization: Bearer ExampleCredentialValue123456' https://example.com"))
    precondition(ClipHistory.looksLikeSecret("config\n-----BEGIN PRIVATE KEY-----\nexample"))
    precondition(!ClipHistory.looksLikeSecret("https://github.com/DymeYT/veil/pull/12345678"))
    precondition(!ClipHistory.looksLikeSecret("/Users/someone/Library/Caches/veil-cpu"))
    precondition(!ClipHistory.looksLikeSecret("internationalization") && !ClipHistory.looksLikeSecret("hello world this is a long sentence 2026"))
    precondition(!ClipHistory.looksLikeSecret("wifi_scanner_dummy_2.cpp") && !ClipHistory.looksLikeSecret("Screenshot_2026-10-29.png"))
    precondition(!ClipHistory.looksLikeSecret("3114cc5eb3eb6858a3495690312065fe9d95c609") && !ClipHistory.looksLikeSecret("550e8400-e29b-41d4-a716-446655440000"))
    precondition(CalendarSource.upcoming("cal").isEmpty)  // "cal" means Calculator or Calendar.app, not the agenda
    precondition((systemActionItems().first { $0.title == "Lock Screen" }?.score ?? 0) > 0)  // the action beats the Settings pane
    // Out-of-process overview thumbs must ship next to the launcher (keeps SCK out of veil-search RSS).
    let thumbs = (Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/MacOS/veil-thumbs")
    precondition(FileManager.default.isExecutableFile(atPath: thumbs), "veil-thumbs missing from app bundle")
    precondition(VeilFeature.overviewLiveThumbs || !VeilFeature.overviewLiveThumbs)  // flag readable
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
// veil-search --render-osd THEME.json OUT.png: draw the theme's volume overlay offscreen (for design review)
if let i = CommandLine.arguments.firstIndex(of: "--render-osd"), CommandLine.arguments.count > i + 2 {
    let a = CommandLine.arguments
    let m = OSDModel(); m.kind = .volume; m.level = 0.55; m.title = "Volume"; m.visible = true
    MainActor.assumeIsolated {
        let r = ImageRenderer(content: OSDView(m: m, p: Palette.load(a[i + 1]), notchWidth: 220).frame(width: 520, height: 38).background(Color(white: 0.3)))
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { exit(1) }
        try? png.write(to: URL(fileURLWithPath: a[i + 2]))
    }
    exit(0)
}
func acquireInstanceLock() -> Int32 {
    let manager = FileManager.default
    let dir = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("app.veil.search", isDirectory: true)
    do {
        try manager.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
        NSLog("Veil Search could not create its runtime directory: \(error.localizedDescription)")
        exit(1)
    }
    // Keep this inode for the process lifetime. Unlinking it would allow a second
    // process to lock a newly created file while the original is still held.
    let fd = Darwin.open(dir.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
    guard fd >= 0 else {
        NSLog("Veil Search could not open its instance lock (errno \(errno))")
        exit(1)
    }
    while flock(fd, LOCK_EX | LOCK_NB) != 0 {
        let code = errno
        if code == EINTR { continue }
        Darwin.close(fd)
        if code == EWOULDBLOCK {
            if !CommandLine.arguments.contains("--background") {
                DistributedNotificationCenter.default().postNotificationName(Notification.Name("app.veil.search.show"),
                                                                               object: nil, userInfo: nil,
                                                                               deliverImmediately: true)
            }
            exit(0)
        }
        NSLog("Veil Search could not acquire its instance lock (errno \(code))")
        exit(1)
    }
    return fd
}

let instanceLock = acquireInstanceLock()
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
Darwin.close(instanceLock)

/// Themes whose bar sits at the bottom, or whose wallpaper is bright at the top edge, leave the notch cut out of
/// the art. This paints black behind it with a short fade, like a hidden menu bar. It sits just above the desktop
/// picture, below every app window and the bar, and ignores the mouse.
final class NotchBand {
    var window: NSWindow?
    func reload(_ p: Palette) {
        guard !veilIsOff, p.flag("notch_band"), let s = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) else {
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




/// Every clickable surface presses in briefly (spring back on release); Reduce Motion keeps it still.
struct Pressable: ViewModifier {
    @State private var down = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .scaleEffect(down && !reduceMotion ? 0.975 : 1)
            .brightness(down ? 0.06 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: down)
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true } }
                .onEnded { _ in down = false })
    }
}
extension View { func pressable() -> some View { modifier(Pressable()) } }


/// Former translucent dim behind the launcher — killed (VEI-31). Kept as no-op so call sites stay stable.
final class Scrim {
    static let shared = Scrim()
    private var window: NSWindow?
    private var isShowing = false
    func show(on screen: NSScreen, enabled: Bool) {
        // Translucent scrims overextend and were explicitly rejected — never show.
        hide()
        _ = screen; _ = enabled
    }
    func hide() {
        isShowing = false
        guard let w = window else { return }
        let finish = { [weak self] in
            w.orderOut(nil)
            // Drop the fullscreen backing store — keeping a Retina scrim buffer floors RSS hard.
            w.setFrame(NSRect(x: 0, y: 0, width: 1, height: 1), display: false)
            self?.window = nil
        }
        guard w.isVisible else { finish(); return }
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduce {
            finish()
        } else {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; w.animator().alphaValue = 0 }, completionHandler: { [weak self] in
                if self?.isShowing == false { finish() }
            })
        }
    }
}


/// The launcher's outline: rounded, or chamfered (cut corners, the Cyberpunk 2077 interface shape).
struct PanelShape: Shape {
    var chamfer: Bool
    var radius: CGFloat
    func path(in r: CGRect) -> Path {
        guard chamfer else { return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: r) }
        let c = max(radius, 16)  // the cut on the top-left and bottom-right corners; deep enough that both read as deliberate
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }
}
