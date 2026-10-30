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

    /// The notch's horizontal extent on the built-in display (nil on displays without one).
    static func notch(_ screen: NSScreen) -> (minX: CGFloat, maxX: CGFloat, height: CGFloat)? {
        guard screen.safeAreaInsets.top > 0, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea else { return nil }
        return (screen.frame.minX + l.maxX, screen.frame.minX + r.minX, screen.safeAreaInsets.top)
    }

    func show(_ kind: OSDKind, level: Double?, title: String, detail: String = "") {
        let p = palette()
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        // The overlay grows out of the notch, into the black band every theme keeps around it: never over windows.
        let wing: CGFloat = 150
        let frame: NSRect
        if let n = OSD.notch(screen) {
            frame = NSRect(x: n.minX - wing, y: screen.frame.maxY - n.height, width: n.maxX - n.minX + wing * 2, height: n.height)
        } else {
            frame = NSRect(x: screen.frame.midX - 260, y: screen.frame.maxY - 44, width: 520, height: 34)
        }
        if panel == nil || themeID != p.s("theme_id", "") {
            let w = panel ?? NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false; w.ignoresMouseEvents = true
            w.level = .statusBar + 1; w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel = w; themeID = p.s("theme_id", "")
        }
        let notchWidth = OSD.notch(screen).map { $0.maxX - $0.minX } ?? 0
        panel?.contentView = NSHostingView(rootView: OSDView(m: model, p: p, notchWidth: notchWidth).frame(width: frame.width, height: frame.height))
        panel?.setFrame(frame, display: false)
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduce ? nil : .easeOut(duration: 0.18)) {
            model.kind = kind; model.level = level; model.title = title; model.detail = detail
        }
        panel?.orderFrontRegardless()
        withAnimation(reduce ? .easeOut(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.8)) { model.visible = true }
        hide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeIn(duration: reduce ? 0.12 : 0.24)) { self.model.visible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { if !self.model.visible { self.panel?.orderOut(nil) } }
        }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}

/// A notch island: black like the notch, flush with the top edge, its wings carrying the reading in the theme's voice.
struct OSDView: View {
    @ObservedObject var m: OSDModel
    let p: Palette
    var notchWidth: CGFloat = 0
    var theme: String { p.s("theme_id", "") }
    func ui(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name = p.s("ui_font", "")
        return name.isEmpty ? .system(size: size, weight: weight) : .custom(name, size: size).weight(weight)
    }
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
    var accent: Color { p["cyan"] }
    var label: String {
        switch theme {
        case "eclipse": return m.title.lowercased()
        case "dark-souls-3": return m.title
        default: return m.title.uppercased()
        }
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16, style: .continuous)
        HStack(spacing: 0) {
            // left wing: what changed
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent)
                Text(label).font(ui(13, .semibold)).tracking(theme == "eclipse" || theme == "dark-souls-3" ? 0 : 1.4)
                    .foregroundStyle(Color.white.opacity(0.92)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            Spacer().frame(width: notchWidth)
            // right wing: the reading
            HStack(spacing: 10) {
                if let l = m.level { meter(l).frame(height: 6) } else { Spacer(minLength: 0) }
                Text(m.level == nil ? m.detail : percent).font(ui(13, .bold).monospacedDigit())
                    .foregroundStyle(theme == "night-city" ? p["yellow"] : Color.white.opacity(0.92)).lineLimit(1)
            }
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(Color.black))
        // grows sideways out of the notch, then settles
        .scaleEffect(x: m.visible ? 1 : max(0.3, notchWidth / 520), y: 1, anchor: .center)
        .opacity(m.visible ? 1 : 0)
    }

    /// Each theme's meter: Night City segments, Eclipse a single stroke, Cinder moonlit glow, Paradis a field ruler, Arasaka a red rule.
    @ViewBuilder func meter(_ l: Double) -> some View {
        switch theme {
        case "night-city":
            HStack(spacing: 2) {
                ForEach(0..<16, id: \.self) { i in Rectangle().fill(Double(i) < l * 16 ? accent : Color.white.opacity(0.14)) }
            }
        case "eclipse":
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                    Rectangle().fill(accent).frame(width: max(2, g.size.width * l), height: 2)
                }.frame(maxHeight: .infinity)
            }
        case "dark-souls-3":
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(LinearGradient(colors: [p["blue"], .white], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * l).shadow(color: accent.opacity(0.8), radius: 5)
                }
            }
        case "paradis":
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    Rectangle().fill(accent).frame(width: g.size.width * l)
                }
            }
        default:
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule().fill(accent).frame(width: g.size.width * l)
                }
            }
        }
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
