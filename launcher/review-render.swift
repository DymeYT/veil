// Deterministic, offscreen fixtures for independent visual review. No search, app
// launching, notifications, keyboard capture or live wallpaper. Uses a hidden offscreen
// AppKit host window to render native controls; it is never ordered onscreen or made key.
import AppKit
import SwiftUI
import CoreText

func renderReviewFixtureIfRequested() -> Bool {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--render-review"), args.count > i + 2 else { return false }
    let state = args.count > i + 3 ? args[i + 3] : "results"
    guard ["results", "long", "empty", "idle", "last"].contains(state) else { return false }
    MainActor.assumeIsolated {
        _ = NSApplication.shared
        let model = Model()
        model.renderingFixture = true
        model.palette = Palette.load(args[i + 1])
        // Equal capture setup for both variants: make existing user fonts visible
        // in this isolated process. Does not modify system/global font registration.
        let normalize = { (value: String) in value.lowercased().filter { $0.isLetter || $0.isNumber } }
        let wanted = [uiFamily, monoFamily].map(normalize)
        let fonts = (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: home + "/Library/Fonts"), includingPropertiesForKeys: nil)) ?? []
        for file in fonts where wanted.contains(where: { normalize(file.lastPathComponent).hasPrefix($0) }) {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
        model.query = state == "idle" ? "" : "Search"
        if state != "empty" && state != "idle" {
            model.items = [
                Item(kind: .app, title: "Calendar", subtitle: "Applications", symbol: "calendar", action: .open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))),
                Item(kind: .app, title: "System Settings", subtitle: "Applications", symbol: "gearshape", action: .open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))),
                Item(kind: .app, title: "Terminal", subtitle: "Applications", symbol: "terminal", action: .open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))),
                Item(kind: .file, title: state == "long" ? "Quarterly reference notes — exceptionally long descriptive document title.md" : "Reference notes.md", subtitle: "Documents / Reference / Design", symbol: "doc.text", action: .open(URL(fileURLWithPath: "/fixture/Reference notes.md"))),
                Item(kind: .nc, title: "Workspace 2", subtitle: "Switch workspace", symbol: "square.grid.2x2", action: .copy("Workspace")),
                Item(kind: .nc, title: "Appearance", subtitle: "Desktop settings", symbol: "paintpalette", action: .copy("Appearance"))
            ]
        }
        model.selected = state == "last" ? max(model.items.count - 1, 0) : state == "long" ? 3 : 0
        model.shown = true
        let view = LauncherView(m: model).frame(width: model.palette.num("width", 860) + 80, height: 600)
        // NSHostingView renders AppKit-backed TextField and ScrollView content too;
        // SwiftUI ImageRenderer substitutes warning tiles/omits these subviews.
        let size = NSSize(width: model.palette.num("width", 860) + 80, height: 600)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.appearance = NSAppearance(named: .darkAqua)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            fputs("review fixture bitmap allocation failed\n", stderr); exit(1)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fputs("review fixture rendering failed\n", stderr); exit(1)
        }
        do {
            let output = URL(fileURLWithPath: args[i + 2])
            try png.write(to: output)
            let fontName = { (family: String) in
                NSFontManager.shared.font(withFamily: family, traits: [], weight: 6, size: 14)?.fontName ?? "UNRESOLVED"
            }
            let metadata: [String: Any] = [
                "capture": "offscreen NSHostingView fixture; not a live desktop screenshot",
                "state": state, "logical_width": size.width, "logical_height": size.height,
                "pixels_width": bitmap.pixelsWide, "pixels_height": bitmap.pixelsHigh,
                "ui_font_requested": uiFamily, "ui_font_available_face": fontName(uiFamily),
                "mono_font_requested": monoFamily, "mono_font_available_face": fontName(monoFamily),
                "limitations": "No actual desktop vibrancy, external window borders, keyboard interactions, or live services. Existing user fonts registered equally for both fixture variants."
            ]
            let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output.deletingPathExtension().appendingPathExtension("render.json"))
        }
        catch { fputs("review fixture write failed: \(error)\n", stderr); exit(1) }
    }
    return true
}
