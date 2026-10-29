// Boot splash scenes: one illustrated, briefly animated scene per theme (style key `scene`).
// Drawn with Canvas; motion runs only while the 1.8 s splash is on screen.
import SwiftUI

struct RNG {
    var s: UInt64
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double(s >> 11) / Double(1 << 53)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

struct SplashView: View {
    let p: Palette
    var size: CGSize = splashSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var fixedT: Double? = nil  // offscreen renders pass a moment; live splashes animate
    @State var start = Date()
    let artImage: NSImage?

    init(p: Palette, fixedT: Double? = nil, size: CGSize = splashSize) {
        self.p = p
        self.size = size
        self.fixedT = fixedT
        self.artImage = Self.art(p)
    }

    var body: some View {
        if let t = fixedT {
            frame(t)
        } else if reduceMotion {
            frame(1)
        } else {
            TimelineView(.animation) { tl in frame(min(tl.date.timeIntervalSince(start) / 1.8, 1)) }
        }
    }

    // The theme's art (art/<theme>.jpg), if it has one; the drawn scene is the fallback.
    static func art(_ p: Palette) -> NSImage? {
        let id = p.s("theme_id", "")
        return id.isEmpty ? nil : NSImage(contentsOfFile: "\(ncRoot)/art/\(id).jpg")
    }

    func frame(_ t: Double) -> some View {
        let reveal = min(max((t - 0.08) / 0.45, 0), 1)
        let ease = 1 - pow(1 - reveal, 3)
        let left = p.s("title_pos", "left") == "left"
        return ZStack {
            if let img = artImage {
                // slow push-in across the splash
                Image(nsImage: img).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 1.07 - 0.07 * (1 - pow(1 - t, 2)), anchor: .center)
                // legibility: darken toward the title corner, keep the art breathing elsewhere
                LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: p["bg_dark"].opacity(0.88), location: 1)],
                               startPoint: left ? .topTrailing : .top, endPoint: left ? .bottomLeading : .bottom)
                RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center, startRadius: 700, endRadius: 1500)
                TitleBlock(p: p, t: t, ease: ease, align: left ? .leading : .center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: left ? .bottomLeading : .bottom)
                    .padding(.leading, left ? 150 : 0).padding(.bottom, 170)
            } else {
                Canvas { ctx, size in SceneArt.draw(p.s("scene", "neon"), ctx: &ctx, size: size, t: t, p: p) }
                TitleBlock(p: p, t: t, ease: ease)
                    .position(x: size.width / 2, y: SceneArt.titleY(p.s("scene", "neon")) * size.height / 1329)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// The theme's mark, name and tagline, treated per scene.
struct TitleBlock: View {
    let p: Palette
    let t: Double
    let ease: Double
    var align: HorizontalAlignment = .center
    var scene: String { p.s("scene", "neon") }
    var brand: String { p.s("brand", "VEIL") }

    var body: some View {
        VStack(alignment: align, spacing: 22) {
            mark
            title
            rule
            Text(p.s("tagline", "")).font(code(14, "Medium")).tracking(4).foregroundStyle(p["fg"].opacity(0.75))
                .opacity(ease)
        }
        .offset(y: (1 - ease) * 18)
        .opacity(min(ease * 1.4, 1))
    }

    @ViewBuilder var title: some View {
        let font = mono(scene == "skyline" ? 54 : 50, "Bold")
        switch scene {
        case "neon", "tower":
            // chromatic split that settles as the title locks in
            let off = (1 - ease) * 10 + 1.5
            ZStack {
                Text(brand).font(font).tracking(12).foregroundStyle(p["cyan"].opacity(0.85)).offset(x: -off)
                Text(brand).font(font).tracking(12).foregroundStyle(p["magenta"].opacity(0.85)).offset(x: off)
                Text(brand).font(font).tracking(12).foregroundStyle(p["white"])
            }
            .overlay { HUDBrackets(color: p["cyan"]).padding(-26) }
        case "cabin":
            // typewriter: letters arrive one at a time
            let n = Int(Double(brand.count) * min(t / 0.6, 1))
            Text(String(brand.prefix(n)) + (n < brand.count ? "▌" : "")).font(font).tracking(10).foregroundStyle(p["white"])
                .frame(width: 900)
        case "skyline":
            HStack(spacing: 18) {
                Text(brand.capitalized).font(font).foregroundStyle(.white)
                Spacer(minLength: 30)
                HStack(spacing: 8) {
                    ForEach(Array(zip(["1", "4", "A", "N", "7"], ["red", "green", "blue", "yellow", "magenta"])), id: \.0) { l, c in
                        Text(l).font(mono(24, "Bold")).foregroundStyle(c == "yellow" ? .black : .white)
                            .frame(width: 44, height: 44).background(Circle().fill(p[c]))
                    }
                }
            }
            .padding(.horizontal, 30).frame(width: 760, height: 96)
            .background(RoundedRectangle(cornerRadius: 6).fill(.black))
            .overlay(alignment: .top) { Rectangle().fill(.white).frame(height: 3).padding(.horizontal, 30).offset(y: 12) }
        case "cathedral":
            HStack(spacing: 26) {
                Text("❦").font(.system(size: 26)).foregroundStyle(p["yellow"]).scaleEffect(x: -1)
                Text(brand).font(font).tracking(14).foregroundStyle(p["white"])
                Text("❦").font(.system(size: 26)).foregroundStyle(p["yellow"])
            }
        case "art":
            Text(brand).font(font).tracking(8).foregroundStyle(p["white"])
        default:
            Text(brand).font(font).tracking(scene == "cavern" ? 16 : 10).foregroundStyle(p["white"])
                .shadow(color: p["cyan"].opacity(scene == "cavern" ? 0.5 : 0.25), radius: 18)
        }
    }

    @ViewBuilder var mark: some View {
        let shape = RoundedRectangle(cornerRadius: max(p.num("chip_radius", 5) * 2, 2), style: .continuous)
        let t = Text(p.s("chip", "NC//")).font(mono(26, "ExtraBold"))
        switch scene {
        case "skyline", "art": EmptyView()  // signage and quiet art need no extra badge
        default:
            switch p.s("chip_style", "filled") {
            case "outline": t.foregroundStyle(p["yellow"]).padding(.horizontal, 18).padding(.vertical, 8).overlay(shape.stroke(p["yellow"], lineWidth: 1.5))
            case "text": t.font(mono(54, "Bold")).foregroundStyle(p["yellow"]).shadow(color: p["yellow"].opacity(0.45), radius: 18)
            default: t.foregroundStyle(p["bg_dark"]).padding(.horizontal, 18).padding(.vertical, 8).background(shape.fill(p["yellow"]))
                    .shadow(color: p["yellow"].opacity(0.35), radius: 16)
            }
        }
    }

    @ViewBuilder var rule: some View {
        switch scene {
        case "art": EmptyView()
        case "factory":
            // research progress
            VStack(spacing: 8) {
                HStack {
                    Text("RESEARCH").font(mono(12, "Bold")).tracking(3).foregroundStyle(p["dim"])
                    Spacer()
                    Text("\(Int(min(t / 0.9, 1) * 100))%").font(code(12, "Bold")).foregroundStyle(p["cyan"])
                }
                ZStack(alignment: .leading) {
                    Rectangle().fill(p["surface"]).overlay(Rectangle().stroke(p["line"], lineWidth: 1))
                    Rectangle().fill(p["cyan"]).frame(width: 420 * min(t / 0.9, 1)).padding(2)
                }
                .frame(height: 14)
            }
            .frame(width: 420)
        default:
            LinearGradient(colors: [.clear, p["cyan"], p["magenta"], .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 80 + 300 * ease, height: 1.5)
        }
    }
}

struct HUDBrackets: View {
    let color: Color
    var body: some View {
        GeometryReader { g in
            Path { path in
                let a: CGFloat = 22, w = g.size.width, h = g.size.height
                for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)] {
                    path.move(to: CGPoint(x: x, y: y + dy * a)); path.addLine(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x + dx * a, y: y))
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

enum SceneArt {
    static func titleY(_ scene: String) -> CGFloat {
        switch scene { case "neon", "tower": return 400; case "skyline": return 400; case "dusk": return 500; case "cabin": return 360; case "cavern": return 610; default: return 560 }
    }

    static var wallpaper = false  // wallpaper renders leave out the splash-only HUD text

    static func draw(_ scene: String, ctx: inout GraphicsContext, size: CGSize, t: Double, p: Palette) {
        switch scene {
        case "cathedral": cathedral(&ctx, size, t, p)
        case "cavern": cavern(&ctx, size, t, p)
        case "factory": factory(&ctx, size, t, p)
        case "skyline": skyline(&ctx, size, t, p)
        case "dusk": dusk(&ctx, size, t, p)
        case "forest": forest(&ctx, size, t, p)
        case "tower": tower(&ctx, size, t, p)
        default: neon(&ctx, size, t, p)
        }
        vignette(&ctx, size)
    }

    static func fill(_ ctx: inout GraphicsContext, _ size: CGSize, _ colors: [Color], _ stops: [Double]? = nil) {
        let g = Gradient(stops: zip(colors, stops ?? colors.indices.map { Double($0) / Double(max(colors.count - 1, 1)) }).map { .init(color: $0, location: $1) })
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(g, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    static func glow(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ color: Color, _ alpha: Double) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(colors: [color.opacity(alpha), color.opacity(0)]), center: c, startRadius: 0, endRadius: r))
    }

    static func vignette(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.55)]), center: c, startRadius: size.width * 0.32, endRadius: size.width * 0.75))
    }

    // Skyline of rectangles with lit windows; returns nothing, draws one depth layer.
    static func buildings(_ ctx: inout GraphicsContext, _ size: CGSize, seed: UInt64, base: CGFloat, minH: CGFloat, maxH: CGFloat,
                          minW: CGFloat, maxW: CGFloat, body: Color, lit: [Color], litChance: Double, windowAlpha: Double) {
        var r = RNG(s: seed)
        var x: CGFloat = -20
        while x < size.width + 20 {
            let w = CGFloat(r.range(minW, maxW)), h = CGFloat(r.range(minH, maxH))
            let rect = CGRect(x: x, y: base - h, width: w, height: h)
            ctx.fill(Path(rect), with: .color(body))
            if r.next() < 0.18 { ctx.fill(Path(CGRect(x: x + w / 2 - 1, y: base - h - 40, width: 2, height: 40)), with: .color(body)) }
            var wy = base - h + 12
            while wy < base - 10 {
                var wx = x + 8
                while wx < x + w - 10 {
                    if r.next() < litChance {
                        ctx.fill(Path(CGRect(x: wx, y: wy, width: 4, height: 6)), with: .color(lit[Int(r.next() * Double(lit.count))].opacity(windowAlpha * r.range(0.5, 1))))
                    }
                    wx += 10
                }
                wy += 14
            }
            x += w + CGFloat(r.range(2, 14))
        }
    }

    // MARK: Night City: neon skyline, signs, scan sweep, HUD readouts
    static func neon(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["magenta"].opacity(0.22), p["bg_dark"]], [0, 0.45, 0.78, 1])
        glow(&ctx, CGPoint(x: s.width * 0.5, y: s.height * 0.8), 900, p["magenta"], 0.16)
        glow(&ctx, CGPoint(x: s.width * 0.2, y: s.height * 0.75), 500, p["cyan"], 0.10)
        // light trails crossing the sky (aerial traffic)
        for (y0, y1, c) in [(0.12, 0.07, p["cyan"]), (0.15, 0.19, p["magenta"]), (0.09, 0.12, p["yellow"])] {
            var trail = Path()
            trail.move(to: CGPoint(x: -40, y: s.height * CGFloat(y0)))
            trail.addQuadCurve(to: CGPoint(x: s.width + 40, y: s.height * CGFloat(y1)), control: CGPoint(x: s.width / 2, y: s.height * CGFloat((y0 + y1) / 2 - 0.06)))
            var g = ctx
            g.addFilter(.blur(radius: 5))
            g.stroke(trail, with: .color(c.opacity(0.35)), lineWidth: 4)
            ctx.stroke(trail, with: .color(c.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [40, 18], dashPhase: CGFloat(t) * -300))
        }
        buildings(&ctx, s, seed: 3, base: s.height * 0.8, minH: 260, maxH: 640, minW: 40, maxW: 90, body: p["selection"].opacity(0.35),
                  lit: [p["cyan"]], litChance: 0.05, windowAlpha: 0.3)
        buildings(&ctx, s, seed: 7, base: s.height * 0.8, minH: 160, maxH: 520, minW: 50, maxW: 120, body: p["surface"].opacity(0.95),
                  lit: [p["cyan"], p["yellow"], p["magenta"]], litChance: 0.22, windowAlpha: 0.55)
        buildings(&ctx, s, seed: 21, base: s.height * 0.86, minH: 220, maxH: 700, minW: 80, maxW: 190, body: p["bg_dark"],
                  lit: [p["cyan"], p["magenta"]], litChance: 0.08, windowAlpha: 0.7)
        ctx.fill(Path(CGRect(x: 0, y: s.height * 0.8, width: s.width, height: s.height * 0.2)), with: .color(p["bg_dark"]))
        // neon signs mounted on the near facades
        var r = RNG(s: 99)
        for i in 0..<10 {
            let x = CGFloat(r.range(40, Double(s.width) - 60)), y = CGFloat(r.range(Double(s.height) * 0.6, Double(s.height) * 0.76))
            let vertical = r.next() < 0.6
            let rect = vertical ? CGRect(x: x, y: y, width: 14, height: CGFloat(r.range(70, 160))) : CGRect(x: x, y: y, width: CGFloat(r.range(70, 160)), height: 14)
            let c = [p["cyan"], p["magenta"], p["yellow"]][i % 3]
            var g = ctx
            g.addFilter(.blur(radius: 10))
            g.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(c.opacity(0.9)), lineWidth: 4)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(c.opacity(0.18)))
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(c), lineWidth: 1.5)
        }
        // street level: wet reflections
        ctx.fill(Path(CGRect(x: 0, y: s.height * 0.86, width: s.width, height: s.height * 0.14)), with: .color(p["bg_dark"]))
        var rr = RNG(s: 5)
        for _ in 0..<70 {
            let x = CGFloat(rr.range(0, Double(s.width)))
            ctx.fill(Path(CGRect(x: x, y: s.height * 0.87, width: 2, height: CGFloat(rr.range(20, 120)))),
                     with: .color([p["cyan"], p["magenta"]][Int(rr.next() * 2)].opacity(0.12)))
        }
        // scanlines + sweep
        var y: CGFloat = 0
        while y < s.height { ctx.fill(Path(CGRect(x: 0, y: y, width: s.width, height: 1)), with: .color(.white.opacity(0.025))); y += 3 }
        let sweep = s.height * CGFloat(t)
        ctx.fill(Path(CGRect(x: 0, y: sweep - 60, width: s.width, height: 60)),
                 with: .linearGradient(Gradient(colors: [.clear, p["cyan"].opacity(0.10)]), startPoint: CGPoint(x: 0, y: sweep - 60), endPoint: CGPoint(x: 0, y: sweep)))
        guard !wallpaper else { return }
        // HUD readouts
        hudText(&ctx, "NC//OS  2077.10  ·  BOOT 0x7E3", CGPoint(x: 60, y: 70), p["cyan"], .leading)
        hudText(&ctx, "LINK ESTABLISHED  ●", CGPoint(x: s.width - 60, y: 70), p["cyan"], .trailing)
        hudText(&ctx, "SECTOR 04 // WATSON", CGPoint(x: 60, y: s.height - 60), p["dim"], .leading)
        hudText(&ctx, String(format: "SYNC %03d%%", Int(min(t / 0.8, 1) * 100)), CGPoint(x: s.width - 60, y: s.height - 60), p["yellow"], .trailing)
    }

    static func hudText(_ ctx: inout GraphicsContext, _ s: String, _ at: CGPoint, _ c: Color, _ align: HorizontalAlignment) {
        let text = ctx.resolve(Text(s).font(code(13, "Bold")).tracking(3).foregroundColor(c))
        ctx.draw(text, at: at, anchor: align == .leading ? .leading : .trailing)
    }

    // MARK: Pharloom: gothic arch with tracery, silk threads, needle, rising motes
    static func cathedral(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["ws_active"], p["bg_dark"]], [0, 0.4, 0.75, 1])
        let cx = s.width / 2, baseY = s.height * 0.95, w: CGFloat = 640, top = s.height * 0.08
        glow(&ctx, CGPoint(x: cx, y: s.height * 0.42), 620, p["yellow"], 0.13)
        glow(&ctx, CGPoint(x: cx, y: s.height * 0.42), 260, p["magenta"], 0.10)
        _ = top
        // lancet (pointed gothic) arch: two circle arcs of radius = span, each centred on the opposite springer
        func arch(_ inset: CGFloat) -> Path {
            var path = Path()
            let span = w - inset * 2, l = cx - span / 2, rgt = cx + span / 2, spring = s.height * 0.5
            path.move(to: CGPoint(x: l, y: baseY))
            path.addLine(to: CGPoint(x: l, y: spring))
            for i in 0...30 { let a = (180 + 60 * Double(i) / 30) * .pi / 180; path.addLine(to: CGPoint(x: rgt + span * CGFloat(cos(a)), y: spring + span * CGFloat(sin(a)))) }
            for i in 0...30 { let a = (300 + 60 * Double(i) / 30) * .pi / 180; path.addLine(to: CGPoint(x: l + span * CGFloat(cos(a)), y: spring + span * CGFloat(sin(a)))) }
            path.addLine(to: CGPoint(x: rgt, y: baseY))
            return path
        }
        ctx.fill(arch(0), with: .color(p["bg_dark"].opacity(0.55)))
        // quarry glass: a diamond lattice with a few lit panes, clipped to the window
        var glass = ctx
        glass.clip(to: arch(18))
        var q = RNG(s: 4)
        let step: CGFloat = 46
        var gx: CGFloat = cx - w
        while gx < cx + w {
            glass.stroke(Path { $0.move(to: CGPoint(x: gx, y: 0)); $0.addLine(to: CGPoint(x: gx + s.height, y: s.height)) }, with: .color(p["yellow"].opacity(0.10)), lineWidth: 0.8)
            glass.stroke(Path { $0.move(to: CGPoint(x: gx, y: 0)); $0.addLine(to: CGPoint(x: gx - s.height, y: s.height)) }, with: .color(p["yellow"].opacity(0.10)), lineWidth: 0.8)
            gx += step
        }
        for _ in 0..<70 {
            let px = cx + CGFloat(q.range(-0.5, 0.5)) * w, py = CGFloat(q.range(0.1, 0.95)) * s.height
            let d: CGFloat = step / 2
            let pane = Path { $0.move(to: CGPoint(x: px, y: py - d)); $0.addLine(to: CGPoint(x: px + d, y: py)); $0.addLine(to: CGPoint(x: px, y: py + d)); $0.addLine(to: CGPoint(x: px - d, y: py)) }
            glass.fill(pane, with: .color([p["magenta"], p["yellow"], p["cyan"], p["blue"]][Int(q.next() * 4)].opacity(q.range(0.05, 0.16))))
        }
        ctx.stroke(arch(0), with: .color(p["yellow"].opacity(0.55)), lineWidth: 2)
        ctx.stroke(arch(18), with: .color(p["yellow"].opacity(0.25)), lineWidth: 1)
        // tracery: mullions and a rose window
        for i in 1..<4 {
            let x = cx - w / 2 + w * CGFloat(i) / 4
            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: s.height * 0.56)); $0.addLine(to: CGPoint(x: x, y: baseY)) }, with: .color(p["yellow"].opacity(0.3)), lineWidth: 1.5)
        }
        let rose = CGPoint(x: cx, y: s.height * 0.24)
        ctx.stroke(Path(ellipseIn: CGRect(x: rose.x - 90, y: rose.y - 90, width: 180, height: 180)), with: .color(p["yellow"].opacity(0.4)), lineWidth: 1.2)
        for k in 0..<12 {
            let a = Double(k) / 12 * .pi * 2
            ctx.stroke(Path { $0.move(to: rose); $0.addLine(to: CGPoint(x: rose.x + cos(a) * 90, y: rose.y + sin(a) * 90)) }, with: .color(p["yellow"].opacity(0.22)), lineWidth: 0.8)
            ctx.stroke(Path(ellipseIn: CGRect(x: rose.x + cos(a) * 60 - 14, y: rose.y + sin(a) * 60 - 14, width: 28, height: 28)), with: .color(p["magenta"].opacity(0.3)), lineWidth: 0.8)
        }
        // silk threads drifting across
        var r = RNG(s: 3)
        for i in 0..<9 {
            let y0 = CGFloat(r.range(0.15, 0.9)) * s.height, amp = CGFloat(r.range(40, 160)), ph = r.range(0, 6) + t * 1.4
            var path = Path()
            path.move(to: CGPoint(x: -40, y: y0))
            path.addCurve(to: CGPoint(x: s.width + 40, y: y0 + CGFloat(r.range(-120, 120))),
                          control1: CGPoint(x: s.width * 0.33, y: y0 - amp * CGFloat(sin(ph))),
                          control2: CGPoint(x: s.width * 0.66, y: y0 + amp * CGFloat(cos(ph))))
            ctx.stroke(path, with: .color((i % 3 == 0 ? p["magenta"] : p["yellow"]).opacity(0.18 + 0.05 * Double(i % 3))), lineWidth: i % 4 == 0 ? 1.4 : 0.7)
        }
        // the needle
        let n0 = CGPoint(x: s.width * 0.72, y: s.height * 0.16), n1 = CGPoint(x: s.width * 0.6, y: s.height * 0.36)
        ctx.stroke(Path { $0.move(to: n0); $0.addLine(to: n1) }, with: .color(p["fg"].opacity(0.8)), lineWidth: 2)
        ctx.fill(Path { $0.move(to: CGPoint(x: n1.x, y: n1.y + 10)); $0.addLine(to: CGPoint(x: n1.x - 6, y: n1.y)); $0.addLine(to: CGPoint(x: n1.x, y: n1.y - 10)); $0.addLine(to: CGPoint(x: n1.x + 6, y: n1.y)) }, with: .color(p["cyan"]))
        // motes
        var m = RNG(s: 11)
        for _ in 0..<110 {
            let x = CGFloat(m.range(0, Double(s.width))), y = (CGFloat(m.range(0, Double(s.height))) - CGFloat(t) * 80).truncatingRemainder(dividingBy: s.height)
            let d = CGFloat(m.range(1, 3))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y < 0 ? y + s.height : y, width: d, height: d)), with: .color(p["yellow"].opacity(m.range(0.15, 0.55))))
        }
    }

    // MARK: Hallownest: cavern, stalactites, lumafly lantern, soul wisps, the pale mask
    static func cavern(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["surface"], p["bg_dark"]], [0, 0.4, 0.8, 1])
        glow(&ctx, CGPoint(x: s.width / 2, y: s.height * 0.36), 520, p["cyan"], 0.14)
        var r = RNG(s: 17)
        // stalactites (two layers)
        for layer in 0..<2 {
            var x: CGFloat = -30
            while x < s.width + 30 {
                let w = CGFloat(r.range(40, 120)), h = CGFloat(r.range(60, layer == 0 ? 340 : 200))
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x + w * CGFloat(r.range(0.35, 0.65)), y: h)); path.addLine(to: CGPoint(x: x + w, y: 0))
                ctx.fill(path, with: .color(layer == 0 ? p["surface"].opacity(0.75) : p["bg_dark"]))
                x += w * CGFloat(r.range(0.6, 1.0))
            }
        }
        // distant ruined city of spires, in the rain
        var sp = RNG(s: 5)
        var sx: CGFloat = 40
        while sx < s.width {
            let w = CGFloat(sp.range(24, 70)), h = CGFloat(sp.range(140, 420)), b = s.height * 0.8
            var spire = Path()
            spire.move(to: CGPoint(x: sx, y: b)); spire.addLine(to: CGPoint(x: sx, y: b - h))
            spire.addLine(to: CGPoint(x: sx + w / 2, y: b - h - w * 1.6)); spire.addLine(to: CGPoint(x: sx + w, y: b - h)); spire.addLine(to: CGPoint(x: sx + w, y: b))
            ctx.fill(spire, with: .color(p["selection"].opacity(0.32)))
            if sp.next() < 0.5 { ctx.fill(Path(ellipseIn: CGRect(x: sx + w / 2 - 4, y: b - h * 0.6, width: 8, height: 12)), with: .color(p["cyan"].opacity(0.35))) }
            sx += w + CGFloat(sp.range(30, 140))
        }
        var rain = RNG(s: 9)
        for _ in 0..<220 {
            let x = CGFloat(rain.range(0, Double(s.width))), y = (CGFloat(rain.range(0, Double(s.height))) + CGFloat(t) * 900).truncatingRemainder(dividingBy: s.height)
            ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: CGFloat(rain.range(12, 30)))), with: .color(p["fg"].opacity(0.07)))
        }
        // rock floor
        for (layer, col) in [(0, p["surface"].opacity(0.8)), (1, p["bg_dark"])] {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: s.height))
            var x: CGFloat = 0
            while x <= s.width + 60 {
                path.addLine(to: CGPoint(x: x, y: s.height * (layer == 0 ? 0.78 : 0.86) - CGFloat(r.range(0, layer == 0 ? 90 : 60))))
                x += CGFloat(r.range(40, 110))
            }
            path.addLine(to: CGPoint(x: s.width, y: s.height)); path.closeSubpath()
            ctx.fill(path, with: .color(col))
        }
        // lumafly lantern
        let lamp = CGPoint(x: s.width * 0.18, y: s.height * 0.55)
        ctx.stroke(Path { $0.move(to: CGPoint(x: lamp.x, y: 0)); $0.addLine(to: CGPoint(x: lamp.x, y: lamp.y - 26)) }, with: .color(p["comment"].opacity(0.6)), lineWidth: 1)
        glow(&ctx, lamp, 220, p["cyan"], 0.35 + 0.05 * sin(t * 20))
        ctx.fill(Path(ellipseIn: CGRect(x: lamp.x - 14, y: lamp.y - 22, width: 28, height: 40)), with: .color(p["bright_cyan"].opacity(0.9)))
        // soul wisps rising
        var w = RNG(s: 23)
        for _ in 0..<40 {
            let x = CGFloat(w.range(0, Double(s.width))), y = CGFloat(w.range(0.3, 1.0)) * s.height - CGFloat(t) * CGFloat(w.range(30, 120))
            glow(&ctx, CGPoint(x: x, y: y), CGFloat(w.range(6, 18)), p["fg"], w.range(0.15, 0.45))
        }
        // the Knight: dark cloak, pale horned mask
        let c = CGPoint(x: s.width / 2, y: s.height * 0.22)
        var cloak = Path()
        cloak.move(to: CGPoint(x: c.x - 40, y: c.y + 50))
        cloak.addQuadCurve(to: CGPoint(x: c.x - 64, y: c.y + 168), control: CGPoint(x: c.x - 70, y: c.y + 100))
        cloak.addLine(to: CGPoint(x: c.x - 26, y: c.y + 156)); cloak.addLine(to: CGPoint(x: c.x, y: c.y + 172)); cloak.addLine(to: CGPoint(x: c.x + 26, y: c.y + 156))
        cloak.addLine(to: CGPoint(x: c.x + 64, y: c.y + 168))
        cloak.addQuadCurve(to: CGPoint(x: c.x + 40, y: c.y + 50), control: CGPoint(x: c.x + 70, y: c.y + 100))
        cloak.closeSubpath()
        ctx.fill(cloak, with: .color(p["bg_dark"]))
        ctx.stroke(cloak, with: .color(p["cyan"].opacity(0.25)), lineWidth: 1)
        var horns = Path()
        for sgn in [-1.0, 1.0] {
            let k = CGFloat(sgn)
            // horns sweep out to the side, then curl up to a point
            horns.move(to: CGPoint(x: c.x + k * 22, y: c.y - 66))
            horns.addCurve(to: CGPoint(x: c.x + k * 96, y: c.y - 168), control1: CGPoint(x: c.x + k * 70, y: c.y - 70), control2: CGPoint(x: c.x + k * 104, y: c.y - 110))
            horns.addCurve(to: CGPoint(x: c.x + k * 52, y: c.y - 56), control1: CGPoint(x: c.x + k * 84, y: c.y - 120), control2: CGPoint(x: c.x + k * 78, y: c.y - 70))
            horns.closeSubpath()
        }
        var lit = ctx
        lit.addFilter(.shadow(color: p["cyan"].opacity(0.55), radius: 34))
        lit.fill(horns, with: .color(p["white"]))
        lit.fill(Path(ellipseIn: CGRect(x: c.x - 64, y: c.y - 76, width: 128, height: 150)), with: .color(p["white"]))
        for dx in [-28.0, 28.0] {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + dx - 18, y: c.y - 22, width: 36, height: 56)), with: .color(p["bg_dark"]))
        }
    }

    // MARK: Factorio: blueprint floor, belts with science packs, turning gears
    static func factory(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg"], p["bg_dark"]])
        var x: CGFloat = 0
        while x < s.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: s.height)), with: .color(p["blue"].opacity(x.truncatingRemainder(dividingBy: 160) == 0 ? 0.14 : 0.05))); x += 32 }
        var y: CGFloat = 0
        while y < s.height { ctx.fill(Path(CGRect(x: 0, y: y, width: s.width, height: 1)), with: .color(p["blue"].opacity(y.truncatingRemainder(dividingBy: 160) == 0 ? 0.14 : 0.05))); y += 32 }
        glow(&ctx, CGPoint(x: s.width / 2, y: s.height * 0.42), 560, p["cyan"], 0.10)
        // gears
        for (cx, cy, rad, teeth, dir) in [(s.width * 0.14, s.height * 0.3, 150.0, 14, 1.0), (s.width * 0.1, s.height * 0.6, 90.0, 9, -1.0), (s.width * 0.86, s.height * 0.28, 120.0, 12, -1.0)] {
            var gear = Path()
            let a0 = t * 1.2 * dir
            for k in 0..<(teeth * 2) {
                let a = a0 + Double(k) / Double(teeth * 2) * .pi * 2
                let rr = k % 2 == 0 ? rad : rad * 0.84
                let pt = CGPoint(x: cx + CGFloat(cos(a) * rr), y: cy + CGFloat(sin(a) * rr))
                k == 0 ? gear.move(to: pt) : gear.addLine(to: pt)
            }
            gear.closeSubpath()
            ctx.fill(gear, with: .color(p["surface"]))
            ctx.stroke(gear, with: .color(p["line"]), lineWidth: 2)
            for k in 0..<4 {
                let a = a0 + Double(k) * .pi / 2
                ctx.stroke(Path { $0.move(to: CGPoint(x: cx, y: cy)); $0.addLine(to: CGPoint(x: cx + CGFloat(cos(a) * rad * 0.7), y: cy + CGFloat(sin(a) * rad * 0.7))) },
                           with: .color(p["line"]), lineWidth: CGFloat(rad / 10))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: cx - rad * 0.22, y: cy - rad * 0.22, width: rad * 0.44, height: rad * 0.44)), with: .color(p["comment"]))
            ctx.fill(Path(ellipseIn: CGRect(x: cx - rad * 0.08, y: cy - rad * 0.08, width: rad * 0.16, height: rad * 0.16)), with: .color(p["bg_dark"]))
        }
        // assembling machines feeding the belts
        for (i, mx) in [s.width * 0.3, s.width * 0.5, s.width * 0.7].enumerated() {
            let box = CGRect(x: mx - 80, y: s.height * 0.5, width: 160, height: 160)
            ctx.fill(Path(box), with: .color(p["surface"]))
            ctx.fill(Path(CGRect(x: box.minX, y: box.minY, width: box.width, height: 3)), with: .color(.white.opacity(0.12)))
            ctx.fill(Path(CGRect(x: box.minX, y: box.maxY - 4, width: box.width, height: 4)), with: .color(.black.opacity(0.5)))
            ctx.stroke(Path(box), with: .color(p["line"]), lineWidth: 2)
            let hub = CGPoint(x: box.midX, y: box.midY - 10)
            var g = Path()
            for k in 0..<16 {
                let a = t * 3 * (i % 2 == 0 ? 1 : -1) + Double(k) / 16 * .pi * 2, rr = k % 2 == 0 ? 40.0 : 32.0
                let pt = CGPoint(x: hub.x + CGFloat(cos(a) * rr), y: hub.y + CGFloat(sin(a) * rr))
                k == 0 ? g.move(to: pt) : g.addLine(to: pt)
            }
            g.closeSubpath()
            ctx.fill(g, with: .color(p["comment"]))
            ctx.fill(Path(ellipseIn: CGRect(x: hub.x - 10, y: hub.y - 10, width: 20, height: 20)), with: .color(p["surface"]))
            let prog = (t * 1.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
            ctx.fill(Path(CGRect(x: box.minX + 16, y: box.maxY - 26, width: box.width - 32, height: 8)), with: .color(p["bg_dark"]))
            ctx.fill(Path(CGRect(x: box.minX + 16, y: box.maxY - 26, width: (box.width - 32) * CGFloat(prog), height: 8)), with: .color(p["green"]))
            // inserter arm down to the belt
            ctx.stroke(Path { $0.move(to: CGPoint(x: box.midX, y: box.maxY)); $0.addLine(to: CGPoint(x: box.midX + 18, y: box.maxY + 34)); $0.addLine(to: CGPoint(x: box.midX, y: s.height * 0.74 - 22)) },
                       with: .color(p["yellow"].opacity(0.8)), lineWidth: 4)
        }
        // belts with chevrons and science packs
        let packs = [p["red"], p["green"], p["blue"], p["magenta"], p["yellow"]]
        for (i, by) in [s.height * 0.74, s.height * 0.82, s.height * 0.9].enumerated() {
            let speed = CGFloat(140 + i * 60)
            ctx.fill(Path(CGRect(x: 0, y: by - 18, width: s.width, height: 36)), with: .color(p["surface"]))
            ctx.fill(Path(CGRect(x: 0, y: by - 18, width: s.width, height: 2)), with: .color(p["yellow"].opacity(0.6)))
            ctx.fill(Path(CGRect(x: 0, y: by + 16, width: s.width, height: 2)), with: .color(p["yellow"].opacity(0.6)))
            let off = (CGFloat(t) * speed).truncatingRemainder(dividingBy: 40)
            var cxp: CGFloat = -40 + off
            while cxp < s.width + 40 {
                ctx.stroke(Path { $0.move(to: CGPoint(x: cxp, y: by - 9)); $0.addLine(to: CGPoint(x: cxp + 8, y: by)); $0.addLine(to: CGPoint(x: cxp, y: by + 9)) },
                           with: .color(p["comment"].opacity(0.5)), lineWidth: 2)
                cxp += 40
            }
            var r = RNG(s: UInt64(31 + i))
            var px = (CGFloat(t) * speed).truncatingRemainder(dividingBy: 120) - 120
            while px < s.width + 60 {
                let c = packs[Int(r.next() * Double(packs.count))]
                ctx.fill(Path(roundedRect: CGRect(x: px, y: by - 10, width: 20, height: 20), cornerRadius: 3), with: .color(c))
                ctx.fill(Path(CGRect(x: px + 6, y: by - 14, width: 8, height: 5)), with: .color(c.opacity(0.7)))
                px += CGFloat(r.range(70, 150))
            }
        }
    }

    // MARK: New York: skyline with deco crowns over the river
    static func skyline(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["cyan"].opacity(0.25), p["bg_dark"]], [0, 0.45, 0.72, 0.74])
        glow(&ctx, CGPoint(x: s.width / 2, y: s.height * 0.72), 1000, p["cyan"], 0.12)
        let base = s.height * 0.74
        buildings(&ctx, s, seed: 12, base: base, minH: 120, maxH: 360, minW: 40, maxW: 100, body: p["surface"].opacity(0.85),
                  lit: [p["yellow"], p["fg"]], litChance: 0.25, windowAlpha: 0.45)
        buildings(&ctx, s, seed: 34, base: base, minH: 80, maxH: 260, minW: 60, maxW: 140, body: p["bg_dark"],
                  lit: [p["yellow"]], litChance: 0.18, windowAlpha: 0.6)
        // Empire-style stepped tower with spire
        let ex = s.width * 0.62
        for (w, h) in [(150.0, 380.0), (110.0, 470.0), (70.0, 540.0), (34.0, 600.0)] {
            ctx.fill(Path(CGRect(x: ex - CGFloat(w) / 2, y: base - CGFloat(h), width: CGFloat(w), height: CGFloat(h))), with: .color(p["bg_dark"]))
        }
        ctx.fill(Path(CGRect(x: ex - 3, y: base - 700, width: 6, height: 100)), with: .color(p["bg_dark"]))
        glow(&ctx, CGPoint(x: ex, y: base - 560), 70, p["cyan"], 0.5)
        // Chrysler-style arched crown
        let cx = s.width * 0.36
        ctx.fill(Path(CGRect(x: cx - 60, y: base - 430, width: 120, height: 430)), with: .color(p["bg_dark"]))
        for k in 0..<5 {
            let w = CGFloat(120 - k * 22), y0 = base - 430 - CGFloat(k) * 34
            ctx.stroke(Path { $0.addArc(center: CGPoint(x: cx, y: y0), radius: w / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false) },
                       with: .color(p["fg"].opacity(0.5)), lineWidth: 2)
        }
        ctx.fill(Path { $0.move(to: CGPoint(x: cx - 12, y: base - 560)); $0.addLine(to: CGPoint(x: cx, y: base - 660)); $0.addLine(to: CGPoint(x: cx + 12, y: base - 560)) }, with: .color(p["fg"].opacity(0.6)))
        // river with reflections
        ctx.fill(Path(CGRect(x: 0, y: base, width: s.width, height: s.height - base)), with: .color(p["bg_dark"]))
        // suspension bridge sweeping across the foreground: gothic twin-arch towers, catenary cables, suspenders
        let deck = s.height * 0.86
        let towers: [CGFloat] = [s.width * 0.18, s.width * 0.56]
        var cable = Path()
        cable.move(to: CGPoint(x: -80, y: deck - 40))
        cable.addQuadCurve(to: CGPoint(x: towers[0], y: deck - 300), control: CGPoint(x: towers[0] * 0.55, y: deck - 60))
        cable.addQuadCurve(to: CGPoint(x: towers[1], y: deck - 300), control: CGPoint(x: (towers[0] + towers[1]) / 2, y: deck - 20))
        cable.addQuadCurve(to: CGPoint(x: s.width + 80, y: deck - 40), control: CGPoint(x: towers[1] + (s.width - towers[1]) * 0.45, y: deck - 60))
        var hp = Path()
        for k in stride(from: 0.0, through: Double(s.width), by: 18) { hp.move(to: CGPoint(x: CGFloat(k), y: deck)); hp.addLine(to: CGPoint(x: CGFloat(k), y: deck - 320)) }
        var under = ctx
        under.clip(to: { var a = cable; a.addLine(to: CGPoint(x: s.width + 80, y: deck)); a.addLine(to: CGPoint(x: -80, y: deck)); a.closeSubpath(); return a }())
        under.stroke(hp, with: .color(p["fg"].opacity(0.22)), lineWidth: 0.8)
        ctx.stroke(cable, with: .color(p["fg"].opacity(0.55)), lineWidth: 2.5)
        for tx in towers {
            let tower = Path { pp in
                pp.addRect(CGRect(x: tx - 44, y: deck - 330, width: 88, height: 330 + 40))
            }
            ctx.fill(tower, with: .color(.black))
            for ax in [tx - 22, tx + 22] {
                ctx.fill(Path(roundedRect: CGRect(x: ax - 11, y: deck - 260, width: 22, height: 130), cornerRadii: RectangleCornerRadii(topLeading: 11, bottomLeading: 0, bottomTrailing: 0, topTrailing: 11)),
                         with: .color(p["bg"]))
            }
        }
        ctx.fill(Path(CGRect(x: -20, y: deck, width: s.width + 40, height: 14)), with: .color(.black))
        var lamps = RNG(s: 66)
        for k in stride(from: 10.0, through: Double(s.width), by: 64) {
            glow(&ctx, CGPoint(x: CGFloat(k), y: deck - 4), 16, p["yellow"], lamps.range(0.5, 0.9))
        }
        var r = RNG(s: 8)
        for _ in 0..<160 {
            let x = CGFloat(r.range(0, Double(s.width))), y = base + CGFloat(r.range(8, Double(s.height - base)))
            let wob = CGFloat(sin(t * 4 + Double(y) * 0.05) * 6)
            ctx.fill(Path(CGRect(x: x + wob, y: y, width: CGFloat(r.range(10, 60)), height: 1.5)), with: .color(p["yellow"].opacity(r.range(0.06, 0.25))))
        }
    }

    // MARK: Kataware-doki: dusk sky, split comet, mountains and town lights
    static func dusk(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["blue"].opacity(0.55), p["magenta"].opacity(0.75), p["yellow"].opacity(0.85)], [0, 0.25, 0.5, 0.7, 0.8])
        var r = RNG(s: 51)
        for _ in 0..<260 {
            let x = CGFloat(r.range(0, Double(s.width))), y = CGFloat(r.range(0, 0.5)) * s.height
            let d = CGFloat(r.range(0.8, 2.4)), tw = 0.5 + 0.5 * sin(t * 6 + r.range(0, 6))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity((0.2 + 0.5 * tw) * (1 - Double(y / s.height) * 1.6))))
        }
        // comet splitting in two
        let head = CGPoint(x: s.width * (0.76 - 0.02 * t), y: s.height * (0.15 + 0.01 * t))
        for (dx, dy, c) in [(-980.0, -150.0, p["cyan"]), (-900.0, -40.0, p["magenta"])] {
            var tail = Path()
            tail.move(to: head)
            tail.addQuadCurve(to: CGPoint(x: head.x + dx, y: head.y + dy), control: CGPoint(x: head.x + dx * 0.4, y: head.y + dy * 0.2))
            var g = ctx
            g.addFilter(.blur(radius: 6))
            g.stroke(tail, with: .linearGradient(Gradient(colors: [c.opacity(0.9), c.opacity(0)]), startPoint: head, endPoint: CGPoint(x: head.x + dx, y: head.y + dy)), lineWidth: 8)
            ctx.stroke(tail, with: .linearGradient(Gradient(colors: [.white.opacity(0.9), c.opacity(0)]), startPoint: head, endPoint: CGPoint(x: head.x + dx, y: head.y + dy)), lineWidth: 1.5)
        }
        glow(&ctx, head, 60, .white, 0.9)
        // ridgelines, far to near, softened with haze between them
        for (layer, col, hgt, amp) in [(0, p["selection"], 0.62, 200.0), (1, p["surface"], 0.69, 150.0), (2, p["bg_dark"], 0.76, 90.0)] {
            var path = Path()
            var m = RNG(s: UInt64(60 + layer))
            var pts: [CGPoint] = []
            var x: CGFloat = -100
            while x <= s.width + 200 { pts.append(CGPoint(x: x, y: s.height * CGFloat(hgt) - CGFloat(m.range(0, amp)))); x += CGFloat(m.range(140, 300)) }
            path.move(to: CGPoint(x: -100, y: s.height))
            path.addLine(to: pts[0])
            for k in 1..<pts.count {
                let mid = CGPoint(x: (pts[k - 1].x + pts[k].x) / 2, y: (pts[k - 1].y + pts[k].y) / 2)
                path.addQuadCurve(to: mid, control: pts[k - 1])
            }
            path.addLine(to: CGPoint(x: s.width + 200, y: s.height)); path.closeSubpath()
            ctx.fill(path, with: .color(col))
            ctx.fill(Path(CGRect(x: 0, y: s.height * CGFloat(hgt) - 40, width: s.width, height: 120)),
                     with: .linearGradient(Gradient(colors: [.clear, p["magenta"].opacity(0.10), .clear]), startPoint: CGPoint(x: 0, y: s.height * CGFloat(hgt) - 40), endPoint: CGPoint(x: 0, y: s.height * CGFloat(hgt) + 80)))
        }
        // town lights + lake
        let lake = s.height * 0.84
        ctx.fill(Path(CGRect(x: 0, y: lake, width: s.width, height: s.height - lake)), with: .color(p["bg"]))
        var l = RNG(s: 70)
        for _ in 0..<140 {
            let x = CGFloat(l.range(0, Double(s.width))), y = lake - CGFloat(l.range(4, 60))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color(p["yellow"].opacity(l.range(0.4, 0.9))))
            ctx.fill(Path(CGRect(x: x, y: lake + (lake - y) * 0.6, width: 3, height: 1.5)), with: .color(p["yellow"].opacity(0.18)))
        }
    }

    // MARK: Kodama: layered forest, fireflies, little spirits among the roots
    static func forest(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["surface"]], [0, 0.55, 1])
        // god rays through the canopy
        for (x0, wdt, a) in [(0.30, 120.0, 0.07), (0.46, 70.0, 0.05), (0.62, 160.0, 0.06), (0.8, 90.0, 0.04)] {
            var ray = Path()
            let x = s.width * CGFloat(x0)
            ray.move(to: CGPoint(x: x, y: -10)); ray.addLine(to: CGPoint(x: x + CGFloat(wdt), y: -10))
            ray.addLine(to: CGPoint(x: x + CGFloat(wdt) + 300, y: s.height)); ray.addLine(to: CGPoint(x: x + 220, y: s.height)); ray.closeSubpath()
            ctx.fill(ray, with: .linearGradient(Gradient(colors: [p["yellow"].opacity(a * 1.6), p["yellow"].opacity(0)]), startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + 200, y: s.height)))
        }
        // trunks in three depths: tapered, flared roots, moss light on one side
        var r = RNG(s: 91)
        for (layer, col, wMin, wMax, gap) in [(0, p["selection"].opacity(0.45), 26.0, 50.0, 90.0), (1, p["surface"], 50.0, 90.0, 220.0), (2, p["bg_dark"], 90.0, 170.0, 420.0)] {
            var x = CGFloat(r.range(-80, 40))
            while x < s.width + 80 {
                let w = CGFloat(r.range(wMin, wMax)), lean = CGFloat(r.range(-30, 30))
                var trunk = Path()
                let foot = s.height * (0.9 + 0.03 * CGFloat(layer))
                trunk.move(to: CGPoint(x: x - w * 0.5, y: foot))
                trunk.addQuadCurve(to: CGPoint(x: x + lean, y: -20), control: CGPoint(x: x + w * 0.1, y: foot - 160))
                trunk.addLine(to: CGPoint(x: x + lean + w * 0.7, y: -20))
                trunk.addQuadCurve(to: CGPoint(x: x + w * 1.5, y: foot), control: CGPoint(x: x + w * 0.6, y: foot - 160))
                trunk.closeSubpath()
                ctx.fill(trunk, with: .color(col))
                if layer > 0 {
                    ctx.fill(Path(CGRect(x: x + w * 0.62 + lean * 0.5, y: 0, width: w * 0.08, height: foot - 120)), with: .color(p["cyan"].opacity(layer == 1 ? 0.10 : 0.06)))
                }
                x += w + CGFloat(r.range(gap * 0.5, gap * 1.3))
            }
        }
        // canopy
        for _ in 0..<30 {
            let c = CGPoint(x: r.range(-100, Double(s.width) + 100), y: r.range(-90, 90)), rad = CGFloat(r.range(140, 280))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - rad, y: c.y - rad * 0.6, width: rad * 2, height: rad * 1.2)), with: .color(p["bg_dark"].opacity(0.92)))
        }
        // mossy ground and mist
        ctx.fill(Path(CGRect(x: 0, y: s.height * 0.9, width: s.width, height: s.height * 0.1)), with: .color(p["bg_dark"]))
        ctx.fill(Path(CGRect(x: 0, y: s.height * 0.66, width: s.width, height: s.height * 0.34)),
                 with: .linearGradient(Gradient(colors: [.clear, p["fg"].opacity(0.08)]), startPoint: CGPoint(x: 0, y: s.height * 0.66), endPoint: CGPoint(x: 0, y: s.height)))
        // kodama among the roots, one rattling its head
        var k = RNG(s: 13)
        for (i, (fx, fy, sc)) in [(0.12, 0.88, 1.6), (0.2, 0.92, 1.1), (0.31, 0.86, 1.9), (0.7, 0.9, 1.4), (0.78, 0.86, 2.1), (0.88, 0.92, 1.2), (0.95, 0.88, 0.9)].enumerated() {
            var c = ctx
            c.translateBy(x: s.width * CGFloat(fx), y: s.height * CGFloat(fy))
            c.rotate(by: .degrees(k.range(-18, 18) + (i == 4 ? sin(t * 14) * 14 : 0)))
            let z = CGFloat(sc)
            c.addFilter(.shadow(color: p["white"].opacity(0.3), radius: 14))
            c.fill(Path(roundedRect: CGRect(x: -8 * z, y: 14 * z, width: 16 * z, height: 26 * z), cornerRadius: 8 * z), with: .color(p["white"].opacity(0.85)))
            c.fill(Path(ellipseIn: CGRect(x: -22 * z, y: -26 * z, width: 44 * z, height: 46 * z)), with: .color(p["white"].opacity(0.94)))
            for (ex, ey, ew, eh) in [(-12.0, -10.0, 7.0, 9.0), (6.0, -10.0, 7.0, 9.0), (-4.0, 4.0, 8.0, 10.0)] {
                c.fill(Path(ellipseIn: CGRect(x: CGFloat(ex) * z, y: CGFloat(ey) * z, width: CGFloat(ew) * z, height: CGFloat(eh) * z)), with: .color(p["bg_dark"]))
            }
        }
        // fireflies
        var f = RNG(s: 29)
        for _ in 0..<80 {
            let x = CGFloat(f.range(0, Double(s.width))) + CGFloat(sin(t * 3 + f.range(0, 6)) * 10)
            let y = CGFloat(f.range(0.2, 0.92)) * s.height + CGFloat(cos(t * 2 + f.range(0, 6)) * 8)
            let tw = 0.4 + 0.6 * abs(sin(t * 5 + f.range(0, 6)))
            glow(&ctx, CGPoint(x: x, y: y), 16, p["cyan"], 0.5 * tw)
            ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(p["yellow"].opacity(tw)))
        }
    }

    // MARK: Arasaka: monolith tower, red scan lines
    static func tower(_ ctx: inout GraphicsContext, _ s: CGSize, _ t: Double, _ p: Palette) {
        fill(&ctx, s, [p["bg_dark"], p["bg"], p["ws_active"]], [0, 0.6, 1])
        glow(&ctx, CGPoint(x: s.width / 2, y: s.height), 900, p["cyan"], 0.18)
        let w: CGFloat = 360
        var tw = Path()
        tw.move(to: CGPoint(x: s.width / 2 - w / 2, y: s.height)); tw.addLine(to: CGPoint(x: s.width / 2 - w / 3, y: 40))
        tw.addLine(to: CGPoint(x: s.width / 2 + w / 3, y: 40)); tw.addLine(to: CGPoint(x: s.width / 2 + w / 2, y: s.height)); tw.closeSubpath()
        ctx.fill(tw, with: .color(p["bg_dark"]))
        for k in 0..<7 {
            let x = s.width / 2 - w / 3 + CGFloat(k) * w * 2 / 3 / 6
            ctx.fill(Path(CGRect(x: x, y: 40, width: 1, height: s.height)), with: .color(p["cyan"].opacity(0.18)))
        }
        var y: CGFloat = 0
        while y < s.height { ctx.fill(Path(CGRect(x: 0, y: y, width: s.width, height: 1)), with: .color(p["cyan"].opacity(0.04))); y += 6 }
        let sweep = s.height * CGFloat(t)
        ctx.fill(Path(CGRect(x: 0, y: sweep, width: s.width, height: 2)), with: .color(p["cyan"].opacity(0.4)))
    }
}

// The theme's wallpaper: the splash scene alone, at full resolution.
struct WallpaperView: View {
    let p: Palette
    var body: some View {
        Canvas { ctx, size in
            SceneArt.wallpaper = true
            SceneArt.draw(p.s("scene", "neon"), ctx: &ctx, size: size, t: 0.35, p: p)
        }
        .frame(width: splashSize.width, height: splashSize.height)
    }
}

/// The splash and offscreen renders fill the main screen at its point size (2056×1329 when there is no screen).
let splashSize = NSScreen.main?.frame.size ?? CGSize(width: 2056, height: 1329)
