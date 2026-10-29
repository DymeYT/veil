// Themed system overlays: volume, display brightness, Caps Lock and power, each drawn in the active
// environment's own grammar and animated in. Veil Search takes the volume and brightness keys (5% steps,
// via an event tap that needs Accessibility) so the macOS overlay never competes with these.
import AppKit
import Carbon
import IOKit.ps
import Network
import SwiftUI

enum OSDKind { case volume, brightness, caps, power, battery, network, input }

final class OSDModel: ObservableObject {
    @Published var kind = OSDKind.volume
    @Published var level: Double? = 0.5   // nil for on/off overlays
    @Published var title = ""
    @Published var detail = ""
    @Published var visible = false
}

final class OSD {
    static let shared = OSD()
    let model = OSDModel()
    private var panel: NSPanel?
    private var themeID = ""
    private var hide: DispatchWorkItem?
    var palette: () -> Palette = { Palette.load() }

    func show(_ kind: OSDKind, level: Double?, title: String, detail: String = "") {
        let p = palette()
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let size = NSSize(width: 300, height: 64)
        let barBelowNotch: CGFloat = p.s("bar_position", "top") == "top" ? 38 : 0
        let top = screen.frame.maxY - max(screen.safeAreaInsets.top, 24) - barBelowNotch - 10
        let frame = NSRect(x: screen.frame.midX - size.width / 2, y: top - size.height, width: size.width, height: size.height)
        if panel == nil || themeID != p.s("theme_id", "") {
            let w = panel ?? NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false; w.ignoresMouseEvents = true
            w.level = .statusBar; w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            w.contentView = NSHostingView(rootView: OSDView(m: model, p: p).frame(width: size.width, height: size.height))
            panel = w; themeID = p.s("theme_id", "")
        }
        panel?.setFrame(frame, display: false)
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduce ? nil : .easeOut(duration: 0.18)) {
            model.kind = kind; model.level = level; model.title = title; model.detail = detail
        }
        panel?.orderFrontRegardless()
        withAnimation(reduce ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.78)) { model.visible = true }
        hide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeIn(duration: reduce ? 0.12 : 0.22)) { self.model.visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { if !self.model.visible { self.panel?.orderOut(nil) } }
        }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}

struct OSDView: View {
    @ObservedObject var m: OSDModel
    let p: Palette
    var theme: String { p.s("theme_id", "") }
    func ui(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name = p.s("ui_font", "")
        return name.isEmpty ? .system(size: size, weight: weight) : .custom(name, size: size).weight(weight)
    }
    func mono(_ size: CGFloat) -> Font {
        let name = p.s("ui_mono", "")
        return name.isEmpty ? .system(size: size, weight: .bold).monospacedDigit() : .custom(name, size: size).weight(.bold)
    }
    var r: CGFloat { min(max(p.num("radius_window", 12), 6), 16) }
    var symbol: String {
        switch m.kind {
        case .volume:
            let l = m.level ?? 0
            return l == 0 ? "speaker.slash.fill" : l < 0.34 ? "speaker.wave.1.fill" : l < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness: return (m.level ?? 0) < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .caps: return "capslock.fill"
        case .power: return m.detail.contains("Charging") || m.detail.contains("charged") ? "bolt.fill" : "battery.75percent"
        case .battery: return (m.level ?? 0) <= 0.1 ? "battery.0percent" : "battery.25percent"
        case .network: return m.detail == "Offline" ? "wifi.slash" : "wifi"
        case .input: return "keyboard"
        }
    }
    var percent: String { m.level.map { "\(Int(($0 * 100).rounded()))" } ?? "" }

    var body: some View {
        content
            .opacity(m.visible ? 1 : 0)
            .offset(y: m.visible ? 0 : -14)
            .scaleEffect(m.visible ? 1 : 0.96, anchor: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder var content: some View {
        switch theme {
        case "night-city": nightCity
        case "arasaka": arasaka
        case "paradis": paradis
        case "eclipse": eclipse
        case "dark-souls-3": cinder
        default: standard
        }
    }

    // Night City: a HUD readout, corner brackets, a segmented bar
    var nightCity: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(p["cyan"]).frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(m.title.uppercased()).font(mono(11)).tracking(1.6).foregroundStyle(p["fg"])
                    Spacer()
                    Text(m.level == nil ? m.detail.uppercased() : percent).font(mono(11)).foregroundStyle(p["yellow"])
                }
                if let l = m.level {
                    HStack(spacing: 3) {
                        ForEach(0..<20, id: \.self) { i in
                            Rectangle().fill(Double(i) < l * 20 ? p["cyan"] : p["fg"].opacity(0.12)).frame(height: 6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(p["bg_dark"].opacity(0.96)))
        .overlay(Brackets().stroke(p["cyan"], lineWidth: 1.5))
        .shadow(color: p["cyan"].opacity(0.25), radius: 12)
    }

    // Arasaka: a bone-white plate with a red rule, condensed caps
    var arasaka: some View {
        HStack(spacing: 0) {
            Rectangle().fill(p["cyan"]).frame(width: 4)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(m.title.uppercased()).font(ui(12, .bold)).tracking(2.4).foregroundStyle(Color(white: 0.08))
                    Spacer()
                    Text(m.level == nil ? m.detail.uppercased() : percent).font(ui(12, .bold)).foregroundStyle(p["cyan"])
                }
                if let l = m.level {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(white: 0.08).opacity(0.14))
                        GeometryReader { g in Rectangle().fill(p["cyan"]).frame(width: g.size.width * l) }
                    }.frame(height: 3)
                }
            }.padding(.horizontal, 14).padding(.vertical, 11)
        }
        .background(Color(red: 0.93, green: 0.91, blue: 0.86))
        .clipShape(RoundedRectangle(cornerRadius: r * 0.6, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }

    // Paradis: a typewritten field-report tag with a dotted leader
    var paradis: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(m.title.uppercased()).font(ui(13, .bold)).foregroundStyle(p["fg"])
                Spacer(minLength: 0)
                Text(m.level == nil ? m.detail.uppercased() : "\(percent)%").font(ui(13, .bold)).foregroundStyle(p["cyan"])
            }
            if let l = m.level {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().stroke(p["fg"].opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        Rectangle().fill(p["cyan"].opacity(0.85)).frame(width: g.size.width * l)
                    }
                }.frame(height: 6)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: r * 0.5, style: .continuous).fill(p["surface"]))
        .overlay(RoundedRectangle(cornerRadius: r * 0.5, style: .continuous).stroke(p["fg"].opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }

    // Eclipse: ink black, one crimson stroke, a serif numeral
    var eclipse: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.title.lowercased()).font(ui(14).italic()).foregroundStyle(p["fg"].opacity(0.75))
                Spacer()
                Text(m.level == nil ? m.detail.lowercased() : percent).font(ui(20, .bold)).foregroundStyle(p["fg"])
            }
            if let l = m.level {
                GeometryReader { g in
                    Rectangle().fill(p["cyan"]).frame(width: max(2, g.size.width * l), height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: 2)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: r * 0.5, style: .continuous).fill(Color.black.opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: r * 0.5, style: .continuous).stroke(p["fg"].opacity(0.16), lineWidth: 1))
    }

    // Cinder (Irithyll): a serif label over a moonlit bar that glows
    var cinder: some View {
        VStack(spacing: 7) {
            HStack {
                Text(m.title).font(ui(14, .medium)).foregroundStyle(p["fg"])
                Spacer()
                Text(m.level == nil ? m.detail : percent).font(ui(14, .medium)).foregroundStyle(p["yellow"])
            }
            if let l = m.level {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(p["fg"].opacity(0.1))
                        Capsule().fill(LinearGradient(colors: [p["blue"], p["white"]], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * l)
                            .shadow(color: p["cyan"].opacity(0.75), radius: 7)
                    }
                }.frame(height: 4)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 6).fill(p["bg_dark"].opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(p["cyan"].opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 5)
    }

    // every other environment: a quiet capsule in its palette
    var standard: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(p["fg"]).frame(width: 22)
            if let l = m.level {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(p["fg"].opacity(0.16))
                        Capsule().fill(p["cyan"]).frame(width: g.size.width * l)
                    }
                }.frame(height: 5)
                Text(percent).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(p["fg"]).frame(width: 28, alignment: .trailing)
            } else {
                Text(m.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(p["fg"])
                Spacer()
                Text(m.detail).font(.system(size: 12)).foregroundStyle(p["comment"])
            }
        }
        .padding(.horizontal, 16).frame(height: 40)
        .background(Capsule().fill(p["bg_dark"].opacity(0.95)))
        .overlay(Capsule().strokeBorder(p["border"], lineWidth: 1))
    }
}

/// Night City's HUD corner brackets
struct Brackets: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); let k: CGFloat = 10
        for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0), (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: x + dx * k, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy * k))
        }
        return p
    }
}

// MARK: system hooks

/// Volume and brightness keys in 5% steps (macOS uses sixteenths). Mute and Option+Shift fine steps stay with macOS.
final class MediaKeys {
    static let shared = MediaKeys()
    private var tap: CFMachPort?
    static let step = 0.05

    func start() {
        guard tap == nil else { return }
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = MediaKeys.shared.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
            let key = (ns.data1 & 0xFFFF0000) >> 16, down = ((ns.data1 & 0xFF00) >> 8) == 0xA
            let fine = ns.modifierFlags.contains(.option) && ns.modifierFlags.contains(.shift)
            // 0/1 sound up/down, 2/3 brightness up/down (NX_KEYTYPE_*)
            guard [0, 1, 2, 3].contains(key), !fine else { return Unmanaged.passUnretained(event) }
            if key >= 2 && !Brightness.available { return Unmanaged.passUnretained(event) }
            if down {
                DispatchQueue.main.async {
                    switch key {
                    case 0: MediaKeys.shared.volume(+1)
                    case 1: MediaKeys.shared.volume(-1)
                    case 2: MediaKeys.shared.brightness(+1)
                    default: MediaKeys.shared.brightness(-1)
                    }
                }
            }
            return nil
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: CGEventMask(1 << 14), callback: callback, userInfo: nil) else {
            // not trusted yet: keys stay with macOS, and we try again until Accessibility is granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.start() }
            return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
    }

    /// snap to the 5% grid first, so 47 + up gives 50, not 52
    static func stepped(_ now: Double, _ dir: Int) -> Double {
        let n = (now * 100).rounded()
        let target = dir > 0 ? (floor(n / 5) + 1) * 5 : (ceil(n / 5) - 1) * 5
        return max(0, min(100, target)) / 100
    }

    private func script(_ src: String) -> String {
        var err: NSDictionary?
        return NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue ?? ""
    }

    private let audio = DispatchQueue(label: "veil.volume")  // AppleScript can stall: never on the main thread

    func volume(_ dir: Int) {
        audio.async {
            // HDMI/DisplayPort speakers report no level ("missing value"); macOS can't set those either
            guard let raw = Double(self.script("output volume of (get volume settings)")) else {
                DispatchQueue.main.async { OSD.shared.show(.volume, level: nil, title: "Volume", detail: "Set on the device") }
                return
            }
            let target = MediaKeys.stepped(raw / 100, dir)
            let v = Int((target * 100).rounded())
            _ = self.script("set volume output volume \(v)" + (v > 0 ? " without output muted" : ""))
            _ = try? Process.run(URL(fileURLWithPath: "/opt/homebrew/bin/sketchybar"), arguments: ["--trigger", "volume_change", "INFO=\(v)"])
            DispatchQueue.main.async { OSD.shared.show(.volume, level: target, title: "Volume") }
        }
    }

    func brightness(_ dir: Int) {
        guard let now = Brightness.get() else { return }
        let target = MediaKeys.stepped(Double(now), dir)
        let set = max(target, 0.01)  // 0 would turn the panel fully off
        Brightness.set(Float(set))
        OSD.shared.show(.brightness, level: set, title: "Brightness")
    }
}

/// Built-in display brightness through DisplayServices (the private framework Control Center uses).
enum Brightness {
    private typealias Get = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (UInt32, Float) -> Int32
    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getter = dlsym(handle, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: Get.self) }
    private static let setter = dlsym(handle, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: Set.self) }
    static var available: Bool { getter != nil && setter != nil && get() != nil }
    static func get() -> Float? {
        var v: Float = 0
        guard let getter, getter(CGMainDisplayID(), &v) == 0 else { return nil }
        return v
    }
    static func set(_ v: Float) { _ = setter?(CGMainDisplayID(), v) }
}

/// Caps Lock, charger, low battery, network and input-source overlays. All event-driven: nothing polls.
final class StateWatch {
    static let shared = StateWatch()
    private var caps = NSEvent.modifierFlags.contains(.capsLock)
    private var onAC: Bool?
    private var monitor: Any?
    private var warned: Double = 1          // lowest battery threshold already announced
    private let path = NWPathMonitor()
    private var online: Bool?
    private var woke = Date.distantPast

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            guard let self else { return }
            let now = e.modifierFlags.contains(.capsLock)
            if now != self.caps {
                self.caps = now
                OSD.shared.show(.caps, level: nil, title: "Caps Lock", detail: now ? "On" : "Off")
            }
        }
        onAC = StateWatch.power().ac
        // network: announce drops and returns, not the first reading
        path.pathUpdateHandler = { [weak self] p in
            let up = p.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.online = up }
                guard let was = self.online, was != up, Date().timeIntervalSince(self.woke) > 20 else { return }
                let via = p.usesInterfaceType(.wifi) ? "Wi-Fi" : p.usesInterfaceType(.wiredEthernet) ? "Ethernet" : "Network"
                OSD.shared.show(.network, level: nil, title: via, detail: up ? "Back online" : "Offline")
            }
        }
        path.start(queue: .global(qos: .utility))
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.woke = Date()
        }
        // keyboard input source switches (only matters with more than one source)
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
                                                            object: nil, queue: .main) { _ in
            guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
                  let raw = TISGetInputSourceProperty(src, kTISPropertyLocalizedName) else { return }
            let name = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
            OSD.shared.show(.input, level: nil, title: "Input", detail: name)
        }
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let me = Unmanaged<StateWatch>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { me.powerChanged() }
        }, ctx)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }
    }

    static func power() -> (ac: Bool, level: Double, charging: Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let d = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any] else { return (true, 1, false) }
        let cur = d[kIOPSCurrentCapacityKey] as? Int ?? 100, max = d[kIOPSMaxCapacityKey] as? Int ?? 100
        return ((d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue, Double(cur) / Double(max), d[kIOPSIsChargingKey] as? Bool ?? false)
    }

    private func powerChanged() {
        let s = StateWatch.power()
        // low battery: once each at 20%, 10% and 5% while unplugged
        if !s.ac, let t = [0.05, 0.10, 0.20].first(where: { s.level <= $0 }), t < warned {
            warned = t
            OSD.shared.show(.battery, level: s.level, title: "Battery low", detail: "\(Int((s.level * 100).rounded()))% left")
        }
        if s.ac { warned = 1 }
        guard s.ac != onAC else { return }  // only plug and unplug, not every percent
        onAC = s.ac
        OSD.shared.show(.power, level: s.level, title: s.ac ? "Power" : "Battery",
                        detail: s.ac ? (s.charging ? "Charging" : "Fully charged") : "On battery")
    }
}
