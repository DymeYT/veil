import AppKit
import QuartzCore
import ScreenSaver

private struct Theme {
    private struct Snapshot: Decodable {
        let palette: [String: String]
        let jpeg: Data?
    }

    let values: [String: String]
    let artwork: NSImage?

    static func load() -> Theme {
        let root = URL(fileURLWithPath: NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory())
            .appendingPathComponent(".config/veil", isDirectory: true)
        let installedConfig = root.appendingPathComponent("generated/launcher.json")
        let bundle = Bundle(for: VeilScreenSaverView.self)
        let bundledConfig = bundle.url(forResource: "appearance", withExtension: "json")
        let liveValues = read(installedConfig)
        let liveArt = liveValues.flatMap { values in
            values["theme_id"].flatMap { id in
                guard !id.isEmpty,
                      id.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else { return nil as NSImage? }
                return NSImage(contentsOf: root.appendingPathComponent("art/\(id).jpg"))
            }
        }
        if let liveValues, let liveArt {
            return Theme(values: liveValues, artwork: liveArt)
        }
        let sharedURL = URL(fileURLWithPath: "/Users/Shared/Veil-\(getuid())/appearance.json")
        let snapshot = try? JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: sharedURL))
        let values = liveValues ?? snapshot?.palette ?? bundledConfig.flatMap(read) ?? [:]
        let sharedArt = snapshot.flatMap { snapshot in
            snapshot.palette["theme_id"] == values["theme_id"] ? snapshot.jpeg.flatMap(NSImage.init(data:)) : nil
        }
        let bundledArt = values["theme_id"].flatMap {
            bundle.url(forResource: $0, withExtension: "jpg").flatMap(NSImage.init(contentsOf:))
        }
        return Theme(values: values, artwork: sharedArt ?? bundledArt)
    }

    private static func read(_ url: URL) -> [String: String]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: String]
    }

    func color(_ key: String, fallback: UInt32) -> NSColor {
        let value = values[key].flatMap { UInt32($0, radix: 16) } ?? fallback
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}

@objc(VeilScreenSaverView)
final class VeilScreenSaverView: ScreenSaverView {
    private let composition = CALayer()
    private let backdrop = CALayer()
    private let shade = CAGradientLayer()
    private let rule = CALayer()
    private let title = CATextLayer()
    private var observing = false
    private var typeface: String?
    private var isUmbra = false
    private let subtitle = CATextLayer()
    private let orbit = CAShapeLayer()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        animationTimeInterval = 60
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        layer?.addSublayer(composition)
        composition.addSublayer(backdrop)
        composition.addSublayer(shade)
        composition.addSublayer(rule)
        composition.addSublayer(orbit)
        composition.addSublayer(title)
        composition.addSublayer(subtitle)
        orbit.fillColor = nil
        subtitle.truncationMode = .end
        backdrop.contentsGravity = .resizeAspectFill
        shade.startPoint = CGPoint(x: 0, y: 0)
        shade.endPoint = CGPoint(x: 0.72, y: 0.82)
        shade.locations = [0, 0.50, 1]
        title.truncationMode = .end
        loadTheme()
    }

    private func loadTheme() {
        let appearance = Theme.load()
        backdrop.backgroundColor = appearance.color("surface", fallback: 0x151b2d).cgColor
        backdrop.contents = appearance.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        shade.colors = [NSColor.black.withAlphaComponent(0.82).cgColor,
                        appearance.color("bg_dark", fallback: 0x070a12).withAlphaComponent(0.26).cgColor,
                        NSColor.clear.cgColor]
        isUmbra = appearance.values["theme_id"] == "umbra"
        typeface = appearance.values["ui_font"]
        subtitle.isHidden = !isUmbra
        orbit.isHidden = !isUmbra
        subtitle.string = "TOTAL LUNAR ECLIPSE"
        subtitle.foregroundColor = appearance.color("cyan", fallback: 0xbde9f1).cgColor
        orbit.strokeColor = appearance.color("cyan", fallback: 0xbde9f1).withAlphaComponent(0.28).cgColor
        title.foregroundColor = appearance.color("white", fallback: 0xffffff).cgColor
        title.string = appearance.values["brand"] ?? "VEIL"
        rule.backgroundColor = appearance.color("cyan", fallback: 0x00e5ff).cgColor
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let fontSize = max(11, min(50, bounds.width * 0.036))
        let inset = max(8, bounds.width * 0.08)
        let bottom = max(8, bounds.height * 0.11)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        composition.frame = bounds
        backdrop.frame = composition.bounds
        shade.frame = composition.bounds
        title.contentsScale = window?.backingScaleFactor ?? 2
        title.font = typeface.flatMap { NSFont(name: $0, size: fontSize) }
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        title.fontSize = fontSize
        title.frame = CGRect(x: inset, y: bottom, width: max(0, bounds.width - 2 * inset),
                             height: fontSize * 1.22)
        rule.frame = CGRect(x: inset, y: title.frame.maxY + fontSize * 0.35,
                            width: fontSize * 0.7, height: max(1, fontSize * 0.045))
        if isUmbra {
            let captionSize = max(8, fontSize * 0.29)
            subtitle.contentsScale = title.contentsScale
            subtitle.font = NSFont.monospacedSystemFont(ofSize: captionSize, weight: .medium)
            subtitle.fontSize = captionSize
            subtitle.frame = CGRect(x: inset, y: max(0, bottom - captionSize * 1.8),
                                    width: title.frame.width, height: captionSize * 1.4)
            let arc = CGMutablePath()
            let radius = min(bounds.width, bounds.height) * 0.12
            arc.addArc(center: CGPoint(x: bounds.width - inset, y: bottom), radius: radius,
                       startAngle: .pi * 0.62, endAngle: .pi * 1.42, clockwise: false)
            orbit.frame = composition.bounds
            orbit.path = arc
            orbit.lineWidth = 1 / title.contentsScale
        }
        CATransaction.commit()
    }

    override func startAnimation() {
        loadTheme()
        super.startAnimation()
        guard !observing else { return }
        observing = true
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(motionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
        motionChanged()
    }

    @objc private func motionChanged() {
        backdrop.removeAnimation(forKey: "drift")
        guard isAnimating, !isPreview, backdrop.contents != nil,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let drift = CABasicAnimation(keyPath: "transform.scale")
        drift.fromValue = 1
        drift.toValue = 1.06
        drift.duration = isUmbra ? 38 : 24
        drift.autoreverses = true
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        backdrop.add(drift, forKey: "drift")
    }

    override func stopAnimation() {
        backdrop.removeAnimation(forKey: "drift")
        stopObserving()
        super.stopAnimation()
    }

    private func stopObserving() {
        guard observing else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        observing = false
    }

    deinit {
        stopObserving()
    }
}
