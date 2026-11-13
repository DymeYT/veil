// VEI-36: Buds panel — Bluetooth batteries via system_profiler; ANC preference (hardware ANC = AMFI SPI).
import AppKit
import SwiftUI

struct BudsInfo: Equatable {
    var name = ""
    var connected = false
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int?
    var ancCapable = false

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

    static func probe() -> BudsInfo {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return BudsInfo() }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()

        func pct(_ line: String) -> Int? {
            let digits = line.filter(\.isNumber)
            return digits.isEmpty ? nil : Int(digits)
        }

        var section = ""
        var current = BudsInfo()
        var bestConnected: BudsInfo?
        var bestAny: BudsInfo?

        func flush() {
            guard !current.name.isEmpty else { return }
            let lower = current.name.lowercased()
            let isBuds = lower.contains("airpods") || lower.contains("buds") || lower.contains("headphone")
                || lower.contains("nothing") || lower.contains("cmf")
            if isBuds {
                current.ancCapable = lower.contains("airpods") || lower.contains("nothing") || lower.contains("cmf")
                if current.connected { bestConnected = current }
                else if bestAny == nil { bestAny = current }
            }
            current = BudsInfo()
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
        }
        flush()
        return bestConnected ?? bestAny ?? BudsInfo()
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
                self?.noiseMode = mode
                self?.refresh()
            }
        }
    }

    func setNoiseMode(_ mode: BudsInfo.NoiseMode) {
        guard mode != .openSettings else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
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
        let l = info.left.map { "\($0)%" } ?? "—"
        let r = info.right.map { "\($0)%" } ?? "—"
        let c = info.caseLevel.map { "\($0)%" } ?? "—"
        return ZStack {
            Color.clear.contentShape(Rectangle()).onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("BUDS").font(doto(32)).foregroundStyle(fg)
                Text(info.connected
                     ? "\(info.name) · connected"
                     : (info.name.isEmpty ? "No headphones connected" : "\(info.name) · not connected"))
                    .font(mono(10)).foregroundStyle(muted)
                HStack(spacing: 20) {
                    budCell("L", l); budCell("R", r); budCell("CASE", c)
                }
                if let single = info.single, info.left == nil {
                    Text("Battery \(single)%").font(doto(28)).foregroundStyle(fg)
                }
                Text("NOISE CONTROL").font(mono(10)).foregroundStyle(muted)
                HStack(spacing: 8) {
                    ForEach(BudsInfo.NoiseMode.hardwareModes, id: \.self) { mode in
                        Button(mode.title) { shell.setNoiseMode(mode) }
                            .buttonStyle(GlyphBtn(p: p, filled: shell.noiseMode == mode))
                    }
                }
                Text(info.ancCapable
                     ? "Hardware ANC via Control Center (private SPI = AMFI). Levels from Bluetooth."
                     : "Battery from Bluetooth · ANC when AirPods connected.")
                    .font(ui(11)).foregroundStyle(muted)
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
        }
    }

    func budCell(_ label: String, _ pct: String) -> some View {
        VStack {
            Text(label).font(mono(10)).foregroundStyle(muted)
            Text(pct).font(doto(28)).foregroundStyle(fg)
        }
        .frame(width: 90, height: 90)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(bg))
    }
}
