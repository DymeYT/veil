"""Self-check for veil-theme. Run: python3 ~/.config/veil/test_theme.py"""
import importlib.machinery, importlib.util, os, plistlib, re, subprocess, sys, tempfile, tomllib
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
TOOL = ROOT / "bin/veil-theme"
loader = importlib.machinery.SourceFileLoader("nct", str(TOOL))
nct = importlib.util.module_from_spec(importlib.util.spec_from_loader("nct", loader))
loader.exec_module(nct)

# recolor handles every form, and leaves look-alikes inside longer hex runs alone
m = {"00e5ff": "ff2a4a", "090d17": "0b0708"}
assert nct.recolor("a=#00E5FF b=0xff00e5ff c=0xf0090d17 d = 090d17", m) == "a=#ff2a4a b=0xffff2a4a c=0xf00b0708 d = 0b0708"
assert nct.recolor("sha 1200e5ff9 id_00e5ff", m) == "sha 1200e5ff9 id_00e5ff"

# keys kind: only the tool's settings change; lines the app wrote itself survive
assert nct.set_keys("#? btop v9\nfoo = 1\ncolor_theme = \"x\"\n", 'color_theme = "veil"\nupdate_ms = 2000') == '#? btop v9\nfoo = 1\ncolor_theme = "veil"\nupdate_ms = 2000\n'
assert nct.set_keys("", "a = 1") == "a = 1\n"

# every color in the templates belongs to the base palette, so every theme fully recolors them
base = {v.lower() for v in tomllib.loads((ROOT / "themes/night-city.toml").read_text())["colors"].values()}
for f in (ROOT / "templates").rglob("*"):
    if f.is_file():
        # fully transparent 0x00rrggbb values are invisible, so they need no palette role
        found = {h.lower() for h in re.findall(r"(?i)(?:#|0x(?!00)[0-9a-f]{2}|(?<![0-9a-z_x]))([0-9a-f]{6})(?![0-9a-f])", f.read_text())}
        assert found <= base, f"{f.name}: colors outside the palette {found - base}"

# themes define the same roles as the base palette, and each operating-system
# identity owns a distinct workspace vocabulary and launcher composition.
layouts, workspaces = {}, {}
base_ws = tomllib.loads((ROOT / "themes/night-city.toml").read_text())["strings"]["ws"]
for t in (ROOT / "themes").glob("*.toml"):
    theme = tomllib.loads(t.read_text())
    assert theme["colors"].keys() == tomllib.loads((ROOT / "themes/night-city.toml").read_text())["colors"].keys(), t.name
    style = theme["style"]
    layouts[t.stem] = style["l_layout"]
    workspaces[t.stem] = style.get("ws", theme.get("strings", {}).get("ws", base_ws))
assert len(set(layouts.values())) == len(layouts), f"launcher layouts are shared: {layouts}"
assert len(set(workspaces.values())) == len(workspaces), f"workspace labels are shared: {workspaces}"

def luminance(hex_):
    rgb = [int(hex_[i:i+2], 16) / 255 for i in (0, 2, 4)]
    rgb = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb]
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]

for t in (ROOT / "themes").glob("*.toml"):
    palette = tomllib.loads(t.read_text())["colors"]
    for role in ("comment", "cyan", "magenta", "yellow", "red", "green", "blue",
                 "bright_red", "bright_green", "bright_yellow", "bright_blue", "bright_magenta", "bright_cyan"):
        for background in (palette["bg"], palette["bg_float"], palette["surface"]):
            a, b = sorted((luminance(palette[role]), luminance(background)), reverse=True)
            assert (a + 0.05) / (b + 0.05) >= 4.5, f"{t.stem}: {role} contrast below 4.5:1"
    def ratio(x, y):
        a, b = sorted((luminance(x), luminance(y)), reverse=True)
        return (a + 0.05) / (b + 0.05)
    def mix(x, y, k):  # x over y at opacity k
        return "".join(f"{round(int(x[i:i+2], 16) * k + int(y[i:i+2], 16) * (1 - k)):02x}" for i in (0, 2, 4))
    assert ratio(palette["comment"], palette["bg_dark"]) >= 4.5, f"{t.stem}: comment on bg_dark below 4.5:1"
    # launcher selected-row subtitle: fg at 82% over the solid selection fill (the most opaque row style)
    sub = mix(palette["fg"], palette["selection"], 0.82)
    assert ratio(sub, palette["selection"]) >= 4.5, f"{t.stem}: selected subtitle below 4.5:1"
    # wallpapers are bring-your-own (not in git): once any is installed, every theme needs one
    if any((ROOT / "art").glob("*.jpg")):
        assert (ROOT / "art" / f"{t.stem}.jpg").is_file(), f"{t.stem}: wallpaper missing"
    assert (ROOT / "art" / f"{t.stem}.notes.md").is_file(), f"{t.stem}: wallpaper notes missing"

# every theme fills every @@placeholder@@ in every template
for t in (ROOT / "themes").glob("*.toml"):
    theme = nct.load_theme(t.stem)
    strings = nct.strings_for(theme)
    assert strings["term_blink"].lower() == "false", f"{t.stem}: recurring terminal cursor animation is not battery-checked"
    for f in (ROOT / "templates").rglob("*"):
        if f.is_file():
            out = nct.fill(f.read_text(), strings, f.name)
            assert "@@" not in out, f"{t.stem}: unfilled placeholder in {f.name}"

# Compare all pairs on real effective categorical settings; neither unique names,
# palette, art, spacing nor launcher layout IDs can satisfy this gate.
comparison_spec = importlib.util.spec_from_file_location("compare_profiles", ROOT / "tools/compare_themes.py")
comparison = importlib.util.module_from_spec(comparison_spec)
comparison_spec.loader.exec_module(comparison)
pairs = comparison.compare()
assert len(pairs) == len(layouts) * (len(layouts)-1) // 2
for pair in pairs:
    assert len(pair["surfaces"]) >= 4, f"too similar: {pair}"

assert nct.load_theme("Eclipse")["id"] == "eclipse"

# New names work in commands while historical saved IDs remain valid.
for label, identity in {"Guidance": "elden-ring", "Cinder": "dark-souls-3", "Ashina": "sekiro", "The Cabin": "inscryption", "Foundry": "factorio"}.items():
    assert nct.load_theme(label)["id"] == identity
    assert nct.load_theme(label.lower().replace(" ", "-"))["id"] == identity
for path in (ROOT / "themes").glob("*.toml"):
    nct.plan(path.stem)

# Palette colors and frame controls must never share JSON keys. Verify actual rendered data.
for path in (ROOT / "themes").glob("*.toml"):
    theme = nct.load_theme(path.stem)
    values = nct.strings_for(theme)
    raw = nct.fill(nct.recolor((ROOT / "templates/launcher.json").read_text(),
                   {v.lower(): theme["colors"][k].lower() for k,v in nct.load_theme("night-city")["colors"].items()}), values, "launcher.json")
    config = __import__("json").loads(raw)
    assert config["border"] == theme["colors"]["border"], path.stem
    assert config["line"] == theme["colors"]["line"], path.stem
    assert float(config["border_width"]) >= 0
    assert config["line_style"] in {"none", "solid", "double", "gradient"}
    rendered_border = nct.fill((ROOT / "templates/bordersrc").read_text(), values, "bordersrc")
    assert "style=round" in rendered_border and "inactive_color=0x00000000" in rendered_border
    assert "order=below" in rendered_border and "background_color=0x00000000" in rendered_border

symbol = __import__("json").loads((ROOT / "art/symbols/brand-of-sacrifice.json").read_text())
assert symbol["viewBox"] == [200, 320] and len(symbol["contours"]) == 3
assert nct.strings_for(nct.load_theme("eclipse"))["search_symbol"] == "brand-of-sacrifice"
assert nct.strings_for(nct.load_theme("eclipse"))["search_chip"] == ""
# A failed GUI reload must remain visible even when files deployed successfully.
with tempfile.TemporaryDirectory() as tmp:
    with patch.object(nct, "GEN", Path(tmp)), patch.object(nct.subprocess, "run", return_value=subprocess.CompletedProcess(["mock"], 1, "", "service unavailable")):
        result = nct.reload_configs([(Path("border-fixture"), ["mock"])], "eclipse")
        assert result[0]["returncode"] == 1
        report = __import__("json").loads((Path(tmp) / "reload-status.json").read_text())
        assert report["outcomes"][0]["stderr"] == "service unavailable"

# Wallpapers are always the theme's real art; no third-party live-wallpaper provider is managed.
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    (root / "art").mkdir()
    (root / "art/nyc.jpg").touch()
    with patch.object(nct, "ROOT", root), patch.object(nct.subprocess, "run") as run:
        run.return_value.returncode = 0
        nct.set_wallpaper({"id": "nyc"})
        assert "app.veil.search.desktop" in run.call_args_list[0].args[0][-1]
    uninstall = (ROOT / "uninstall.sh").read_text()
    with patch.object(nct, "ROOT", root), patch.object(nct, "plan", return_value=({"name": "New York"}, [])), patch.object(nct, "system_accents") as accents, patch.object(nct, "reload_configs"), patch.dict(os.environ, {}, clear=True):
        nct.apply("nyc")
        accents.assert_called_once()
        accents.reset_mock()
        with patch.dict(os.environ, VEIL_NO_RELOAD="1"):
            nct.apply("nyc")
        accents.assert_not_called()

# backups: the newest 20 applies stay restorable, `original` (the pre-Veil baseline) is never pruned
with tempfile.TemporaryDirectory() as tmp:
    b = Path(tmp)
    (b / "original").mkdir()
    for i in range(25):
        (b / f"20261029-0000{i:02d}-000000000").mkdir()
        (b / f"20261029-0000{i:02d}-000000000/manifest.json").write_text("{}")
    with patch.object(nct, "BACKUPS", b):
        nct.prune_backups()
    left = sorted(p.name for p in b.iterdir())
    assert len(left) == 21 and "original" in left and "20261029-000005-000000000" in left and "20261029-000004-000000000" not in left

# restore reloads every app apply reloads (Ghostty included), not just the bar and borders
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    (root / "backups/20261029-000000-000000000").mkdir(parents=True)
    (root / "backups/20261029-000000-000000000/manifest.json").write_text('{"previous": "nyc", "files": []}')
    with patch.object(nct, "ROOT", root), patch.object(nct, "BACKUPS", root / "backups"), patch.object(nct, "reload_configs") as reloads, \
         patch.object(nct, "system_accents"), patch.dict(os.environ, {}, clear=True):
        nct.main(["restore"])
        commands = [c for _, c in reloads.call_args.args[0] if isinstance(c, list)]
        assert any("reload_config" in " ".join(c) for c in commands), "restore must reload Ghostty"

# fastfetch: every theme renders valid JSON with its own readings and order, and every module is a real fastfetch module
ff_layouts = {}
for t in (ROOT / "themes").glob("*.toml"):
    values = nct.strings_for(nct.load_theme(t.stem))
    config = __import__("json").loads(nct.fill((ROOT / "templates/fastfetch.jsonc").read_text(), values, "fastfetch.jsonc"))
    for module in config["modules"]:
        kind = module if isinstance(module, str) else module["type"]
        assert kind in nct.FF_TYPES | {"title", "separator", "break", "colors"}, (t.stem, kind)
        assert isinstance(module, str) or kind == "colors" or module["key"], (t.stem, module)
    assert config["logo"]["source"] == values["logo"]
    ff_layouts[t.stem] = values["ff_layout"]
assert len(set(ff_layouts.values())) == len(ff_layouts), f"fastfetch layouts are shared: {ff_layouts}"
try:
    nct.fastfetch_modules({"ff_layout": "title colors:sparkles"}); raise AssertionError("bad swatch accepted")
except ValueError:
    pass

# Neovim statusline: every theme names a form the template defines (an unknown name would silently fall back to LazyVim's)
nvim_template = (ROOT / "templates/nvim.lua").read_text()
status_layouts = {t.stem: nct.strings_for(nct.load_theme(t.stem))["editor_status_layout"] for t in (ROOT / "themes").glob("*.toml")}
for theme_id, form in status_layouts.items():
    assert form == "hud" or f"        {form} = {{" in nvim_template, f"{theme_id}: no statusline form {form!r} in nvim.lua"
assert len(set(status_layouts.values())) == len(status_layouts), f"statusline forms are shared: {status_layouts}"

# JankyBorders draws a square "ghost box" ~10pt outside windows for fractional widths (issue #173)
for t in (ROOT / "themes").glob("*.toml"):
    w = float(nct.strings_for(nct.load_theme(t.stem)).get("border_width", "1"))
    assert w == int(w), f"{t.stem}: border_width {w} must be a whole number"

# each theme declares its own mark (no silent inheritance of Night City's emblem) and no generic glyphs remain
for t in (ROOT / "themes").glob("*.toml"):
    raw = __import__("tomllib").loads(t.read_text())
    assert "search_symbol" in raw.get("style", {}), f"{t.stem}: declare search_symbol"
    assert not any(g in t.read_text() for g in "♜✦✧◇◉忍†✝‡"), f"{t.stem}: generic glyph"
# every environment except New York (MTA typographic identity) has a researched vector search mark on disk
for t in (ROOT / "themes").glob("*.toml"):
    mark = nct.strings_for(nct.load_theme(t.stem)).get("search_symbol", "")
    if t.stem != "nyc":
        assert mark and (ROOT / "art/symbols" / f"{mark}.json").exists() and (ROOT / "art/symbols" / f"{mark}.notes.md").exists(), t.stem

# apply -> restore round trip in a throwaway HOME leaves the files exactly as they were
with tempfile.TemporaryDirectory() as home:
    env = dict(os.environ, HOME=home, VEIL_ROOT=home + "/nc", VEIL_NO_RELOAD="1")
    subprocess.run(["cp", "-R", str(ROOT), home + "/nc"], check=True)
    subprocess.run(["rm", "-rf", home + "/nc/backups", home + "/nc/current"], check=True)
    cursor = Path(home, "Library/Application Support/Cursor/User/settings.json")
    cursor.parent.mkdir(parents=True)
    cursor.write_text('{"editor.fontSize": 13, "workbench.colorCustomizations": {"editorError.foreground": "#aa0000"}}\n')
    run = lambda *a: subprocess.run([sys.executable, str(TOOL), *a], env=env, capture_output=True, text=True, check=True).stdout
    run("apply", "night-city")
    baseline = Path(home, "nc/backups/original/cursor.settings.json")
    assert __import__("json").loads(baseline.read_text()) == {"editor.fontSize": 13, "workbench.colorCustomizations": {"editorError.foreground": "#aa0000"}}
    owned = Path(home, "nc/backups/original/cursor-layout-v2.json")
    assert "editor.wordWrap" in __import__("json").loads(owned.read_text())
    rc = Path(home, ".config/sketchybar/sketchybarrc")
    assert "0xff00e5ff" in rc.read_text() and os.access(rc, os.X_OK)
    run("apply", "arasaka")
    assert "0xffff2a4a" in rc.read_text() and "00e5ff" not in rc.read_text()
    settings = __import__("json").loads(cursor.read_text())
    assert settings["editor.fontSize"] == 13 and settings["workbench.colorCustomizations"]["[*Dark*]"]["focusBorder"] == "#ff2a4a"
    assert settings["workbench.colorCustomizations"]["editorError.foreground"] == "#aa0000"
    assert settings["editor.fontFamily"].startswith("Menlo")
    assert settings["editor.cursorStyle"] == "block"
    assert settings["workbench.sideBar.location"] == "right"
    assert settings["editor.renderWhitespace"] == "boundary"
    assert run("apply", "Foundry").startswith("applied Foundry")
    assert Path(home, "nc/current").read_text() == "factorio"
    run("restore")
    run("restore")
    assert "0xff00e5ff" in rc.read_text() and Path(home, "nc/current").read_text() == "night-city"
    assert "already applied" in run("apply", "night-city")
    for identity in layouts:
        run("apply", identity)
        assert Path(home, "nc/current").read_text() == identity
        assert "all files match" in run("status")
    # Exercise the exact uninstall jq filter without running machine-level uninstall.
    uninstall_text = (ROOT / "uninstall.sh").read_text()
    jq_filter = uninstall_text.split("jq --slurpfile original \"$O/cursor.settings.json\" '", 1)[1].split("' \"$cursor\"", 1)[0]
    original = __import__("json").loads(baseline.read_text())
    restored = __import__("json").loads(subprocess.run(["jq", "--slurpfile", "original", str(baseline), jq_filter, str(cursor)], capture_output=True, text=True, check=True).stdout)
    assert restored == original, (restored, original)


print("veil-theme: all checks passed")
