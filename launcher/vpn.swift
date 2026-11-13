// VEI-36: VPN panel — scutil --nc list/start/stop (no AMFI).
import AppKit
import SwiftUI

struct VPNService: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let connected: Bool
    let detail: String

    static func list() -> [VPNService] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        p.arguments = ["--nc", "list"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        var out: [VPNService] = []
        for line in text.split(separator: "\n") {
            let s = String(line)
            guard s.contains("\""), let q1 = s.firstIndex(of: "\""),
                  let q2 = s[s.index(after: q1)...].firstIndex(of: "\"") else { continue }
            let name = String(s[s.index(after: q1)..<q2])
            guard !name.isEmpty else { continue }
            let connected = s.contains("(Connected)")
            let enabled = s.hasPrefix("*")
            var proto = "VPN"
            if let r = s.range(of: #"\[VPN:[^\]]+\]"#, options: .regularExpression) {
                proto = String(s[r]).replacingOccurrences(of: "[VPN:", with: "").replacingOccurrences(of: "]", with: "")
            }
            let detail = [
                connected ? "Connected" : (enabled ? "Enabled" : "Idle"),
                proto,
            ].joined(separator: " · ")
            out.append(VPNService(name: name, connected: connected, detail: detail))
        }
        return out
    }
}

@MainActor
extension GlyphShell {
    func refreshVPN() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let services = VPNService.list()
            DispatchQueue.main.async {
                self?.vpnServices = services
                self?.refresh()
            }
        }
    }

    func toggleVPN(_ svc: VPNService) {
        let action = svc.connected ? "stop" : "start"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        p.arguments = ["--nc", action, svc.name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        toast = "\(action == "start" ? "Connecting" : "Disconnecting") \(svc.name)…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshVPN()
        }
    }
}

extension GlyphRoot {
    var vpn: some View {
        let clash = FileManager.default.fileExists(atPath: "/Applications/Clash Verge.app")
            || FileManager.default.fileExists(atPath: NSString("~/Applications/Clash Verge.app").expandingTildeInPath)
        let services = shell.vpnServices
        return ZStack {
            Color.clear.contentShape(Rectangle()).onTapGesture { shell.dismiss() }
            VStack(alignment: .leading, spacing: 14) {
                Text("VPN").font(doto(32)).foregroundStyle(fg)
                Text(services.isEmpty
                     ? "No scutil VPN services"
                     : "\(services.count) service\(services.count == 1 ? "" : "s") · click to toggle")
                    .font(mono(10)).foregroundStyle(muted)
                ForEach(services) { svc in
                    Button {
                        shell.toggleVPN(svc)
                    } label: {
                        HStack {
                            Circle().fill(svc.connected ? Color.green : muted).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(svc.name).font(ui(14)).foregroundStyle(fg)
                                Text(svc.detail).font(mono(9)).foregroundStyle(muted)
                            }
                            Spacer()
                            Text(svc.connected ? "ON" : "OFF")
                                .font(mono(10)).foregroundStyle(svc.connected ? fg : muted)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bg))
                    }.buttonStyle(.plain)
                }
                if clash {
                    Button("Open Clash Verge") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Clash Verge.app"))
                        shell.dismiss()
                    }.buttonStyle(GlyphBtn(p: p, filled: true))
                }
                Button("Open Network Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!)
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
}
