// Spotlight-parity answers and actions: unit and currency conversion, definitions, world clock, system actions,
// quitting running apps, Shortcuts, search-engine prefixes, file-kind filters and recent files.
// Everything here is computed on demand while typing; nothing polls in the background.
import AppKit
import CoreServices

// MARK: units

private let unitTable: [String: Dimension] = {
    var t: [String: Dimension] = [:]
    func add(_ u: Dimension, _ names: String) { for n in names.split(separator: " ") { t[String(n)] = u } }
    add(UnitLength.millimeters, "mm millimeter millimeters millimetre millimetres")
    add(UnitLength.centimeters, "cm centimeter centimeters centimetre centimetres")
    add(UnitLength.meters, "m meter meters metre metres")
    add(UnitLength.kilometers, "km kilometer kilometers kilometre kilometres")
    add(UnitLength.inches, "in inch inches \"")
    add(UnitLength.feet, "ft foot feet '")
    add(UnitLength.yards, "yd yard yards")
    add(UnitLength.miles, "mi mile miles")
    add(UnitLength.nauticalMiles, "nmi")
    add(UnitMass.milligrams, "mg milligram milligrams")
    add(UnitMass.grams, "g gram grams")
    add(UnitMass.kilograms, "kg kilo kilos kilogram kilograms")
    add(UnitMass.ounces, "oz ounce ounces")
    add(UnitMass.pounds, "lb lbs pound pounds")
    add(UnitMass.stones, "st stone stones")
    add(UnitTemperature.celsius, "c °c celsius")
    add(UnitTemperature.fahrenheit, "f °f fahrenheit")
    add(UnitTemperature.kelvin, "k kelvin")
    add(UnitVolume.milliliters, "ml milliliter milliliters millilitre")
    add(UnitVolume.liters, "l liter liters litre litres")
    add(UnitVolume.cups, "cup cups")
    add(UnitVolume.fluidOunces, "floz")
    add(UnitVolume.gallons, "gal gallon gallons")
    add(UnitVolume.teaspoons, "tsp teaspoon teaspoons")
    add(UnitVolume.tablespoons, "tbsp tablespoon tablespoons")
    add(UnitSpeed.kilometersPerHour, "kph kmh km/h")
    add(UnitSpeed.milesPerHour, "mph")
    add(UnitSpeed.metersPerSecond, "m/s mps")
    add(UnitSpeed.knots, "kn knot knots")
    add(UnitInformationStorage.bytes, "b byte bytes")
    add(UnitInformationStorage.kilobytes, "kb")
    add(UnitInformationStorage.megabytes, "mb")
    add(UnitInformationStorage.gigabytes, "gb")
    add(UnitInformationStorage.terabytes, "tb")
    add(UnitInformationStorage.kibibytes, "kib")
    add(UnitInformationStorage.mebibytes, "mib")
    add(UnitInformationStorage.gibibytes, "gib")
    add(UnitDuration.seconds, "s sec secs second seconds")
    add(UnitDuration.minutes, "min mins minute minutes")
    add(UnitDuration.hours, "h hr hrs hour hours")
    add(UnitArea.squareMeters, "m2 sqm")
    add(UnitArea.squareFeet, "ft2 sqft")
    add(UnitArea.acres, "acre acres")
    add(UnitArea.hectares, "ha hectare hectares")
    add(UnitEnergy.kilocalories, "kcal cal calorie calories")
    add(UnitEnergy.kilojoules, "kj")
    return t
}()

// sensible default targets when only "10 km" is typed
private func defaultTargets(_ u: Dimension) -> [Dimension] {
    switch u {
    case UnitLength.kilometers: return [UnitLength.miles]
    case UnitLength.miles: return [UnitLength.kilometers]
    case UnitLength.meters: return [UnitLength.feet]
    case UnitLength.feet: return [UnitLength.meters]
    case UnitLength.inches: return [UnitLength.centimeters]
    case UnitLength.centimeters: return [UnitLength.inches]
    case UnitMass.kilograms: return [UnitMass.pounds]
    case UnitMass.pounds: return [UnitMass.kilograms]
    case UnitMass.ounces: return [UnitMass.grams]
    case UnitMass.grams: return [UnitMass.ounces]
    case UnitTemperature.celsius: return [UnitTemperature.fahrenheit]
    case UnitTemperature.fahrenheit: return [UnitTemperature.celsius]
    case UnitVolume.liters: return [UnitVolume.gallons]
    case UnitVolume.gallons: return [UnitVolume.liters]
    case UnitSpeed.milesPerHour: return [UnitSpeed.kilometersPerHour]
    case UnitSpeed.kilometersPerHour: return [UnitSpeed.milesPerHour]
    default: return []
    }
}

func unitAnswers(_ q: String) -> [Item] {
    let pat = #"^\s*(-?[\d.,]+)\s*([a-zA-Z°/"'0-9]*[a-zA-Z°/"'])(?:\s+(?:to|in|as|=)\s+([a-zA-Z°/"'0-9]*[a-zA-Z°/"']))?\s*$"#
    guard let m = q.range(of: pat, options: .regularExpression) else { return [] }
    let s = String(q[m])
    let rx = try! NSRegularExpression(pattern: pat)
    guard let r = rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return [] }
    func g(_ i: Int) -> String? { Range(r.range(at: i), in: s).map { String(s[$0]) } }
    guard let v = Double((g(1) ?? "").replacingOccurrences(of: ",", with: "")), let fromName = g(2)?.lowercased(),
          let from = unitTable[fromName] else { return [] }
    let targets: [Dimension]
    if let toName = g(3)?.lowercased() {
        guard let to = unitTable[toName], type(of: to) == type(of: from) else { return [] }
        targets = [to]
    } else { targets = defaultTargets(from) }
    let f = MeasurementFormatter()
    f.unitOptions = .providedUnit
    f.unitStyle = .medium
    f.numberFormatter.maximumFractionDigits = 4
    return targets.map { to in
        let out = Measurement(value: v, unit: from).converted(to: to)
        let text = f.string(from: out)
        return Item(kind: .answer, title: text, subtitle: "\(f.string(from: Measurement(value: v, unit: from))) =   ↵ copies",
                    symbol: "arrow.left.arrow.right", action: .copy(f.numberFormatter.string(from: out.value as NSNumber) ?? text), score: 1900)
    }
}

// MARK: currency (ECB reference rates via frankfurter.app, fetched only when a currency query is typed; cached for 12 h)

final class Rates {
    static let shared = Rates()
    private(set) var rates: [String: Double] = UserDefaults.standard.dictionary(forKey: "fx.rates") as? [String: Double] ?? [:]
    private var fetched = UserDefaults.standard.double(forKey: "fx.time")
    private var loading = false
    private var lastAttempt = 0.0
    var stale: Bool { Date().timeIntervalSince1970 - fetched > 43200 || rates.isEmpty }
    func refresh(then done: @escaping () -> Void) {
        guard stale, !loading, Date().timeIntervalSince1970 - lastAttempt > 60,  // offline: retry at most once a minute
              let url = URL(string: "https://api.frankfurter.app/latest?from=USD") else { return }
        loading = true
        lastAttempt = Date().timeIntervalSince1970
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.loading = false
                guard let data, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      var r = o["rates"] as? [String: Double] else { return }
                r["USD"] = 1
                self.rates = r
                self.fetched = Date().timeIntervalSince1970
                UserDefaults.standard.set(r, forKey: "fx.rates")
                UserDefaults.standard.set(self.fetched, forKey: "fx.time")
                done()
            }
        }.resume()
    }
}

private let currencyAliases: [String: String] = ["$": "USD", "dollar": "USD", "dollars": "USD", "€": "EUR", "euro": "EUR", "euros": "EUR",
    "£": "GBP", "pound sterling": "GBP", "¥": "JPY", "yen": "JPY", "rupee": "INR", "rupees": "INR", "₹": "INR"]

func currencyAnswers(_ q: String, onRates: @escaping () -> Void) -> [Item] {
    let pat = #"^\s*([$€£¥₹]?)\s*([\d.,]+)\s*([a-zA-Z]{3}|dollars?|euros?|yen|rupees?)?(?:\s+(?:to|in)\s+([a-zA-Z]{3}|dollars?|euros?|yen|rupees?))?\s*$"#
    let rx = try! NSRegularExpression(pattern: pat, options: .caseInsensitive)
    guard let r = rx.firstMatch(in: q, range: NSRange(q.startIndex..., in: q)) else { return [] }
    func g(_ i: Int) -> String? { Range(r.range(at: i), in: q).map { String(q[$0]) }.flatMap { $0.isEmpty ? nil : $0 } }
    func code(_ s: String?) -> String? { s.map { currencyAliases[$0.lowercased()] ?? $0.uppercased() } }
    guard let v = Double((g(2) ?? "").replacingOccurrences(of: ",", with: "")) else { return [] }
    guard let from = code(g(1)) ?? code(g(3)) else { return [] }
    let known = Set(["USD", "EUR", "GBP", "JPY", "INR", "CAD", "AUD", "CHF", "CNY", "KRW", "MXN", "BRL", "SEK", "NOK", "SGD", "HKD", "NZD"])
    guard known.contains(from) else { return [] }
    let local = Locale.current.currency?.identifier ?? "USD"
    let targets = code(g(4)).map { [$0] } ?? (from == local ? (local == "USD" ? ["EUR", "GBP"] : ["USD"]) : [local])
    if Rates.shared.stale { Rates.shared.refresh(then: onRates) }
    let rates = Rates.shared.rates
    guard let rf = rates[from] else { return [] }
    let f = NumberFormatter()
    f.numberStyle = .currency
    return targets.compactMap { to in
        guard let rt = rates[to] else { return nil }
        let out = v / rf * rt
        f.currencyCode = to
        let text = f.string(from: out as NSNumber) ?? "\(out) \(to)"
        f.currencyCode = from
        return Item(kind: .answer, title: text, subtitle: "\(f.string(from: v as NSNumber) ?? "\(v) \(from)") · ECB rate   ↵ copies",
                    symbol: "dollarsign.arrow.circlepath", action: .copy(String(format: "%.2f", out)), score: 1900)
    }
}

// MARK: definitions (the built-in Dictionary, read locally)

func definitionAnswer(_ q: String) -> Item? {
    let w = q.trimmingCharacters(in: .whitespaces)
    guard w.count >= 3, w.count <= 30, w.allSatisfy({ $0.isLetter || $0 == "-" || $0 == " " }), w.split(separator: " ").count <= 2 else { return nil }
    guard let def = DCSCopyTextDefinition(nil, w as CFString, CFRange(location: 0, length: (w as NSString).length))?.takeRetainedValue() as String? else { return nil }
    let clean = def.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    let enc = w.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? w
    return Item(kind: .web, title: w, subtitle: String(clean.prefix(160)), symbol: "character.book.closed",
                action: .open(dictURL(w)), score: 300, extra: clean)
}

// MARK: world clock ("time in tokyo", "tokyo time")

func timeAnswer(_ q: String) -> Item? {
    let l = q.lowercased()
    var city = ""
    if l.hasPrefix("time in ") { city = String(l.dropFirst(8)) } else if l.hasSuffix(" time") { city = String(l.dropLast(5)) } else { return nil }
    city = city.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_")
    guard city.count >= 3 else { return nil }
    let aliases = ["nyc": "New_York", "new_york_city": "New_York", "la": "Los_Angeles", "sf": "Los_Angeles", "san_francisco": "Los_Angeles",
                   "delhi": "Kolkata", "mumbai": "Kolkata", "bangalore": "Kolkata", "beijing": "Shanghai", "kyoto": "Tokyo"]
    let target = (aliases[city] ?? city).lowercased()
    guard let id = TimeZone.knownTimeZoneIdentifiers.first(where: { ($0.split(separator: "/").last ?? "").lowercased() == target }),
          let tz = TimeZone(identifier: id) else { return nil }
    let f = DateFormatter()
    f.timeZone = tz
    f.dateFormat = "h:mm a"
    let d = DateFormatter()
    d.timeZone = tz
    d.dateFormat = "EEEE d MMM"
    let place = id.split(separator: "/").last!.replacingOccurrences(of: "_", with: " ")
    let diff = (tz.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 3600
    return Item(kind: .answer, title: "\(f.string(from: Date())) in \(place)",
                subtitle: "\(d.string(from: Date())) · \(diff >= 0 ? "+" : "")\(diff) h from here   ↵ copies", symbol: "clock",
                action: .copy(f.string(from: Date())), score: 1900)
}

// MARK: system actions

let systemActions: [(String, String, String, [String])] = [
    ("Lock Screen", "Locks the Mac now (⌃⌘Q)", "lock", ["/usr/bin/osascript", "-e", "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"]),
    ("Sleep", "Puts the Mac to sleep", "moon.zzz", ["/usr/bin/pmset", "sleepnow"]),
    ("Restart…", "Asks before restarting", "restart", ["/usr/bin/osascript", "-e", "tell application \"loginwindow\" to «event aevtrrst»"]),
    ("Shut Down…", "Asks before shutting down", "power", ["/usr/bin/osascript", "-e", "tell application \"loginwindow\" to «event aevtrsdn»"]),
    ("Log Out…", "Asks before logging out", "rectangle.portrait.and.arrow.right", ["/usr/bin/osascript", "-e", "tell application \"loginwindow\" to «event aevtrlgo»"]),
    ("Toggle Dark Mode", "Switches light / dark appearance", "circle.lefthalf.filled",
     ["/usr/bin/osascript", "-e", "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"]),
    ("Empty Trash…", "Asks before permanently deleting", "trash", ["/usr/bin/osascript", "-e",
        "display dialog \"Permanently erase the items in the Trash?\" buttons {\"Cancel\", \"Empty Trash\"} default button \"Cancel\" with icon caution", "-e",
        "tell application \"Finder\" to empty trash"]),
    ("Screen Saver", "Starts the screen saver", "sparkles.tv", ["/usr/bin/open", "-a", "ScreenSaverEngine"]),
]

func systemActionItems() -> [Item] {
    // ranked below apps and files with the same prefix; restart/shut down/log out lowest of all
    // Lock Screen ranks above the System Settings pane of the same name: typing "lock" means lock
    systemActions.map { Item(kind: .action, title: $0.0, subtitle: $0.1, symbol: $0.2, action: .run($0.3),
                             score: $0.0 == "Lock Screen" ? 120 : $0.0.hasSuffix("…") ? -250 : -120) }
}

// "quit safari", "hide music": act on running apps
func runningAppActions(_ q: String) -> [Item] {
    let l = q.lowercased()
    let verbs = [("quit ", "Quit", "xmark.circle"), ("hide ", "Hide", "eye.slash"), ("force quit ", "Force Quit", "exclamationmark.octagon")]
    guard let (prefix, verb, sym) = verbs.sorted(by: { $0.0.count > $1.0.count }).first(where: { l.hasPrefix($0.0) }) else { return [] }
    let name = String(l.dropFirst(prefix.count))
    return NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular && ($0.localizedName ?? "").lowercased().hasPrefix(name) && !name.isEmpty }
        .prefix(4).compactMap { app in
            guard let n = app.localizedName else { return nil }
            let pid = String(app.processIdentifier)
            let argv: [String]
            switch verb {
            case "Quit": argv = ["/usr/bin/osascript", "-e", "tell application id \"\(app.bundleIdentifier ?? "")\" to quit"]
            case "Hide": argv = ["/usr/bin/osascript", "-e", "tell application \"System Events\" to set visible of (first process whose unix id is \(pid)) to false"]
            default: argv = ["/usr/bin/osascript", "-e",
                "display dialog \"Force quit \(n.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))? Unsaved changes will be lost.\" buttons {\"Cancel\", \"Force Quit\"} default button \"Cancel\" with icon caution",
                "-e", "do shell script \"kill -9 \(pid)\""]
            }
            return Item(kind: .action, title: "\(verb) \(n)", subtitle: "Running application", symbol: sym, path: app.bundleURL?.path,
                        action: .run(argv), score: 1500)
        }
}

// MARK: Shortcuts (listed once per launcher open)

func shortcutItems() -> [Item] {
    let p = Process(), pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
    p.arguments = ["list"]
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return [] }
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    p.waitUntilExit()
    return out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.map {
        Item(kind: .action, title: $0, subtitle: "Run shortcut", symbol: "square.stack.3d.up", action: .run(["/usr/bin/shortcuts", "run", $0]), score: -150)
    }
}

// MARK: search-engine prefixes ("g ", "yt ", "gh ", "w ", "maps ", "amz ")

func prefixSearch(_ q: String) -> Item? {
    let engines: [(String, String, String, String)] = [
        ("g ", "Google", "magnifyingglass", "https://www.google.com/search?q="),
        ("yt ", "YouTube", "play.rectangle", "https://www.youtube.com/results?search_query="),
        ("gh ", "GitHub", "chevron.left.forwardslash.chevron.right", "https://github.com/search?q="),
        ("w ", "Wikipedia", "book", "https://en.wikipedia.org/w/index.php?search="),
        ("maps ", "Maps", "map", "maps://?q="),
        ("r ", "Reddit", "bubble.left.and.bubble.right", "https://www.reddit.com/search/?q="),
        ("amz ", "Amazon", "cart", "https://www.amazon.com/s?k="),
    ]
    let l = q.lowercased()
    guard let e = engines.first(where: { l.hasPrefix($0.0) && q.count > $0.0.count }) else { return nil }
    let term = String(q.dropFirst(e.0.count))
    let enc = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?.replacingOccurrences(of: "+", with: "%2B") ?? term
    guard let url = URL(string: e.3 + enc) else { return nil }
    return Item(kind: .web, title: "Search \(e.1) for “\(term)”", subtitle: e.1, symbol: e.2, action: .open(url), score: 2100)
}

// MARK: file-kind filters ("kind:pdf report", "pdf: report", "folder: notes")

func kindFilter(_ q: String) -> (String, String)? {
    let kinds = ["pdf": "com.adobe.pdf", "image": "public.image", "images": "public.image", "folder": "public.folder", "folders": "public.folder",
                 "app": "com.apple.application", "doc": "public.composite-content", "text": "public.text", "video": "public.movie",
                 "movie": "public.movie", "audio": "public.audio", "music": "public.audio", "code": "public.source-code", "zip": "public.archive"]
    let l = q.lowercased()
    for (k, uti) in kinds {
        for p in ["kind:\(k) ", "\(k): "] where l.hasPrefix(p) {
            return (uti, String(q.dropFirst(p.count)).trimmingCharacters(in: .whitespaces))
        }
        if l == "kind:\(k)" || l == "\(k):" { return (uti, "") }  // "pdf:" alone lists recent files of that kind
    }
    return nil
}
