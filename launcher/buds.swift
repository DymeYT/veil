// VEI-58: Buds panel — active/connected AirPods only (no stale history), adaptive Max vs L/R.
import AppKit
import SwiftUI

struct BudsInfo: Equatable {
    /// Dual-bud (Pro/3) vs single-battery headset (Max / headphones).
    enum FormFactor: String, Equatable {
        case none
        case earbuds
        case headset
    }

    var name = ""
    var connected = false
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int?
    var ancCapable = false
    var formFactor: FormFactor = .none
    /// True when this device matches the Mac's default audio output.
    var isAudioActive = false
    var productID = ""
    var services = ""

    enum NoiseMode: String, CaseIterable, Hashable {
        case off, transparency, anc, openSettings
        var title: String {
            switch self {
            case .off: return "Off"
            case .transparency: return "Transparent"
            case .anc: return "ANC"
            case .openSettings: return "Sound…"
            }
        }
        static var hardwareModes: [NoiseMode] { [.off, .transparency, .anc] }
    }

    /// Short status for the panel subtitle — never invents a disconnected ghost name.
    var statusLine: String {
        guard connected, !name.isEmpty else { return "No headphones connected" }
        if isAudioActive { return "\(name) · active" }
        return "\(name) · connected"
    }

    var showsNoiseControl: Bool { connected && ancCapable }

    // MARK: - Probe

    static func probe() -> BudsInfo {
        // QA-only: VEIL_BUDS_FIXTURE=empty|max|earbuds — never set in normal use.
        if let fixture = ProcessInfo.processInfo.environment["VEIL_BUDS_FIXTURE"] {
            return fixtureInfo(fixture)
        }
        let devices = parseBluetoothDevices()
        let activeOutput = defaultAudioOutputName()
        let connected = devices.filter(\.connected)
        guard !connected.isEmpty else { return BudsInfo() }

        // Merge BLE + classic duplicates that share a display name while connected.
        let merged = mergeConnected(connected)

        // Prefer the device that is the Mac's current audio route, then audio-stack peers.
        let best = pickActive(from: merged, audioOutput: activeOutput)
        guard var info = best else { return BudsInfo() }

        info.isAudioActive = namesMatch(info.name, activeOutput)
        info.formFactor = inferFormFactor(info)
        info.ancCapable = inferANC(info)
        info.connected = true
        return info
    }

    // MARK: - Fixtures (proof / QA)

    private static func fixtureInfo(_ key: String) -> BudsInfo {
        switch key.lowercased() {
        case "empty", "none", "disconnected":
            return BudsInfo()
        case "max", "headset":
            var i = BudsInfo()
            i.name = "Mario’s AirPods Max"
            i.connected = true
            i.isAudioActive = true
            i.single = 100
            i.formFactor = .headset
            i.ancCapable = true
            i.productID = "0x202D"
            return i
        case "earbuds", "pro":
            var i = BudsInfo()
            i.name = "Mario's Airpods Pro"
            i.connected = true
            i.isAudioActive = true
            i.left = 100
            i.right = 100
            i.caseLevel = 26
            i.formFactor = .earbuds
            i.ancCapable = true
            i.productID = "0x2024"
            return i
        default:
            return BudsInfo()
        }
    }

    // MARK: - Selection

    private struct RawDevice: Equatable {
        var name: String
        var connected: Bool
        var left: Int?
        var right: Int?
        var caseLevel: Int?
        var single: Int?
        var productID: String = ""
        var services: String = ""
        var address: String = ""
        var minorType: String = ""

        var isHeadphoneLike: Bool {
            let lower = name.lowercased()
            if lower.contains("find my") { return false }
            if lower.contains("airpods") || lower.contains("buds") || lower.contains("headphone")
                || lower.contains("nothing") || lower.contains("cmf") { return true }
            let mt = minorType.lowercased()
            return mt.contains("headphone") || mt.contains("headset") || mt.contains("earbuds")
        }

        var hasAudioStack: Bool {
            let s = services.uppercased()
            return s.contains("A2DP") || s.contains("HFP") || s.contains("AVRCP") || s.contains("ACL")
        }

        var batteryScore: Int {
            [left, right, caseLevel, single].compactMap { $0 }.count
        }

        func toInfo() -> BudsInfo {
            var i = BudsInfo()
            i.name = name
            i.connected = connected
            i.left = left
            i.right = right
            i.caseLevel = caseLevel
            i.single = single
            i.productID = productID
            i.services = services
            return i
        }
    }

    private static func mergeConnected(_ devices: [RawDevice]) -> [RawDevice] {
        var byKey: [String: RawDevice] = [:]
        var order: [String] = []
        for d in devices {
            let key = normalizeName(d.name)
            if var existing = byKey[key] {
                if d.left != nil { existing.left = d.left }
                if d.right != nil { existing.right = d.right }
                if d.caseLevel != nil { existing.caseLevel = d.caseLevel }
                if d.single != nil { existing.single = d.single }
                if d.productID.count > existing.productID.count { existing.productID = d.productID }
                if d.services.count > existing.services.count { existing.services = d.services }
                if existing.address.isEmpty { existing.address = d.address }
                if existing.minorType.isEmpty { existing.minorType = d.minorType }
                byKey[key] = existing
            } else {
                byKey[key] = d
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }
    }

    private static func pickActive(from devices: [RawDevice], audioOutput: String?) -> BudsInfo? {
        guard !devices.isEmpty else { return nil }
        if let audioOutput, !audioOutput.isEmpty {
            if let match = devices.first(where: { namesMatch($0.name, audioOutput) }) {
                return match.toInfo()
            }
        }
        // Prefer classic audio connection over BLE-only Continuity ghosts.
        if let audio = devices.first(where: \.hasAudioStack) {
            return audio.toInfo()
        }
        // Otherwise richest battery telemetry among connected headphone-like peers.
        let ranked = devices.sorted { a, b in
            if a.batteryScore != b.batteryScore { return a.batteryScore > b.batteryScore }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return ranked.first?.toInfo()
    }

    private static func inferFormFactor(_ info: BudsInfo) -> FormFactor {
        let lower = info.name.lowercased()
        let pid = info.productID.lowercased().replacingOccurrences(of: "0x", with: "")
        if lower.contains("max") || pid == "202d" { return .headset }
        if info.left != nil || info.right != nil { return .earbuds }
        if info.single != nil { return .headset }
        if lower.contains("airpods") || lower.contains("buds") { return .earbuds }
        return .headset
    }

    private static func inferANC(_ info: BudsInfo) -> Bool {
        let lower = info.name.lowercased()
        if lower.contains("airpods") || lower.contains("nothing") || lower.contains("cmf") { return true }
        let pid = info.productID.lowercased().replacingOccurrences(of: "0x", with: "")
        // Known ANC Apple product IDs: Pro / Max / 3 / 4 families commonly used here.
        let ancIDs: Set<String> = ["2014", "2024", "2027", "202d", "200e", "200f", "2013", "2019", "201b"]
        return ancIDs.contains(pid)
    }

    private static func normalizeName(_ s: String) -> String {
        s
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func namesMatch(_ a: String, _ b: String?) -> Bool {
        guard let b, !b.isEmpty else { return false }
        return normalizeName(a) == normalizeName(b)
    }

    // MARK: - Audio route

    /// Default output device name from system_profiler (Bluetooth AirPods when active).
    private static func defaultAudioOutputName() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPAudioDataType"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()

        var currentName: String?
        var defaultOutput: String?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Device headers sit at indent "        Name:"
            if line.hasPrefix("        "), !line.hasPrefix("          "), trimmed.hasSuffix(":") {
                currentName = String(trimmed.dropLast())
                continue
            }
            if trimmed == "Default Output Device: Yes", let currentName {
                defaultOutput = currentName
            }
        }
        return defaultOutput
    }

    // MARK: - Bluetooth parse

    private static func parseBluetoothDevices() -> [RawDevice] {
        if let json = parseBluetoothJSON(), !json.isEmpty { return json }
        return parseBluetoothText()
    }

    private static func parseBluetoothJSON() -> [RawDevice]? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }

        var out: [RawDevice] = []
        for block in list {
            for (sectionKey, connected) in [("device_connected", true), ("device_not_connected", false)] {
                guard let entries = block[sectionKey] as? [[String: Any]] else { continue }
                for entry in entries {
                    for (name, raw) in entry {
                        guard let dict = raw as? [String: Any] else { continue }
                        var d = RawDevice(name: name, connected: connected)
                        d.address = stringVal(dict["device_address"])
                        d.productID = stringVal(dict["device_productID"])
                        d.services = stringVal(dict["device_services"])
                        d.minorType = stringVal(dict["device_minorType"])
                        d.left = percent(dict["device_batteryLevelLeft"])
                        d.right = percent(dict["device_batteryLevelRight"])
                        d.caseLevel = percent(dict["device_batteryLevelCase"])
                        d.single = percent(dict["device_batteryLevelMain"])
                            ?? percent(dict["device_batteryLevel"])
                        if d.isHeadphoneLike { out.append(d) }
                    }
                }
            }
        }
        return out
    }

    private static func parseBluetoothText() -> [RawDevice] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()

        func pct(_ line: String) -> Int? {
            let digits = line.filter(\.isNumber)
            return digits.isEmpty ? nil : Int(digits)
        }

        var section = ""
        var current = RawDevice(name: "", connected: false)
        var out: [RawDevice] = []

        func flush() {
            guard !current.name.isEmpty, current.isHeadphoneLike else {
                current = RawDevice(name: "", connected: false)
                return
            }
            out.append(current)
            current = RawDevice(name: "", connected: false)
        }

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Connected:" { section = "connected"; continue }
            if trimmed == "Not Connected:" { section = "not"; continue }
            if (section == "connected" || section == "not"),
               line.hasPrefix("          "),
               !line.hasPrefix("              "),
               trimmed.hasSuffix(":") {
                flush()
                current.name = String(trimmed.dropLast())
                current.connected = section == "connected"
                continue
            }
            guard !current.name.isEmpty else { continue }
            if trimmed.hasPrefix("Left Battery Level:") { current.left = pct(trimmed) }
            else if trimmed.hasPrefix("Right Battery Level:") { current.right = pct(trimmed) }
            else if trimmed.hasPrefix("Case Battery Level:") { current.caseLevel = pct(trimmed) }
            else if trimmed.hasPrefix("Battery Level:") { current.single = pct(trimmed) }
            else if trimmed.hasPrefix("Product ID:") {
                current.productID = trimmed.replacingOccurrences(of: "Product ID:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Services:") {
                current.services = trimmed.replacingOccurrences(of: "Services:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Minor Type:") {
                current.minorType = trimmed.replacingOccurrences(of: "Minor Type:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Address:") {
                current.address = trimmed.replacingOccurrences(of: "Address:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        flush()
        return out
    }

    private static func stringVal(_ raw: Any?) -> String {
        if let s = raw as? String { return s }
        if let i = raw as? Int { return String(i) }
        return ""
    }

    private static func percent(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return min(100, max(0, i)) }
        if let d = raw as? Double { return min(100, max(0, Int(d.rounded()))) }
        if let s = raw as? String {
            let digits = s.filter(\.isNumber)
            if let i = Int(digits) { return min(100, max(0, i)) }
        }
        return nil
    }

    static func loadNoiseMode() -> NoiseMode {
        let path = NSHomeDirectory() + "/.config/veil/generated/buds-noise-mode"
        guard let s = try? String(contentsOfFile: path, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let m = NoiseMode(rawValue: s) else { return .off }
        return m
    }

    static func saveNoiseMode(_ mode: NoiseMode) {
        let dir = NSHomeDirectory() + "/.config/veil/generated"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? mode.rawValue.write(toFile: dir + "/buds-noise-mode", atomically: true, encoding: .utf8)
    }
}

@MainActor
extension GlyphShell {
    func refreshBuds() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let info = BudsInfo.probe()
            let mode = BudsInfo.loadNoiseMode()
            DispatchQueue.main.async {
                self?.budsInfo = info
                // Don't leave a stale ANC chip selected when nothing is connected.
                self?.noiseMode = info.connected ? mode : .off
                self?.refresh()
            }
        }
    }

    func setNoiseMode(_ mode: BudsInfo.NoiseMode) {
        guard mode != .openSettings else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
            return
        }
        guard budsInfo.connected else {
            toast = "Connect AirPods to change noise control"
            refresh()
            return
        }
        noiseMode = mode
        BudsInfo.saveNoiseMode(mode)
        toast = "Noise: \(mode.title) · Control Center sets hardware ANC (private SPI = AMFI)"
        refresh()
    }
}

extension GlyphRoot {
    var buds: some View {
        let info = shell.budsInfo
        return ZStack {
            Color.clear.contentShape(Rectangle()).onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text(info.formFactor == .headset ? "AIRPODS" : "BUDS")
                    .font(doto(32)).foregroundStyle(fg)
                Text(info.statusLine)
                    .font(mono(10)).foregroundStyle(muted)

                if info.connected {
                    batteryBlock(info)
                    if info.showsNoiseControl {
                        Text("NOISE CONTROL").font(mono(10)).foregroundStyle(muted)
                        HStack(spacing: 8) {
                            ForEach(BudsInfo.NoiseMode.hardwareModes, id: \.self) { mode in
                                Button(mode.title) { shell.setNoiseMode(mode) }
                                    .buttonStyle(GlyphBtn(p: p, filled: shell.noiseMode == mode))
                            }
                        }
                        Text("Hardware ANC via Control Center (private SPI = AMFI). Levels from Bluetooth.")
                            .font(ui(11)).foregroundStyle(muted)
                    } else {
                        Text("Battery from Bluetooth · ANC when this model supports it.")
                            .font(ui(11)).foregroundStyle(muted)
                    }
                } else {
                    emptyBudsState
                }

                Button("Bluetooth Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!)
                    shell.dismiss()
                }.buttonStyle(GlyphBtn(p: p))
                Button("Close") { shell.dismiss() }.buttonStyle(GlyphBtn(p: p))
            }
            .padding(28)
            .frame(width: 440)
            .background(opaquePanel(28))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .circular))
            .compositingGroup()
            .onTapGesture {}
            .onAppear { shell.refreshBuds() }
        }
    }

    @ViewBuilder
    private func batteryBlock(_ info: BudsInfo) -> some View {
        switch info.formFactor {
        case .headset:
            // AirPods Max / single-battery headphones — one dominant cell, no empty L/R/CASE.
            HStack(spacing: 16) {
                budCell(info.name.lowercased().contains("max") ? "MAX" : "BATTERY",
                        info.single.map { "\($0)%" } ?? "—",
                        symbol: "headphones",
                        wide: true)
                Spacer(minLength: 0)
            }
        case .earbuds:
            // In case: hide separate AirPods L/R — Case only, case icon + case %.
            let inCase = info.caseLevel != nil && info.left == nil && info.right == nil
            if inCase {
                HStack(spacing: 16) {
                    budCell("CASE", info.caseLevel.map { "\($0)%" } ?? "—",
                            symbol: "airpods.chargingcase.fill", wide: true)
                    Spacer(minLength: 0)
                }
            } else {
                let pro = info.name.lowercased().contains("pro")
                HStack(spacing: 20) {
                    budCell("L", info.left.map { "\($0)%" } ?? "—",
                            symbol: pro ? "airpodpro.left" : "airpod.left")
                    budCell("R", info.right.map { "\($0)%" } ?? "—",
                            symbol: pro ? "airpodpro.right" : "airpod.right")
                    budCell("CASE", info.caseLevel.map { "\($0)%" } ?? "—",
                            symbol: "airpods.chargingcase.fill")
                }
            }
        case .none:
            EmptyView()
        }
    }

    private var emptyBudsState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Not connected")
                .font(doto(24)).foregroundStyle(fg)
            Text("Connect AirPods or headphones over Bluetooth. Veil shows the active audio device only — never a leftover paired name.")
                .font(ui(11)).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    func budCell(_ label: String, _ pct: String, symbol: String? = nil, wide: Bool = false) -> some View {
        VStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: wide ? 22 : 16, weight: .semibold))
                    .foregroundStyle(fg)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(label).font(mono(10)).foregroundStyle(muted)
            Text(pct).font(doto(28)).foregroundStyle(fg)
        }
        .frame(width: wide ? 160 : 90, height: 90)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(bg))
    }
}
