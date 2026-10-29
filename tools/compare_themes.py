#!/usr/bin/env python3
"""Pairwise config evidence, not a substitute for native-size visual judgment."""
import importlib.machinery, importlib.util, itertools, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('theme_compare', str(ROOT / 'bin/veil-theme'))
nct = importlib.util.module_from_spec(importlib.util.spec_from_loader('theme_compare', loader))
loader.exec_module(nct)
# Ignore palette, artwork, labels, spacing, radii, timing, sounds and layout IDs.
# Two categorical differences are required to count a group (window mode is structural alone).
GROUPS = {
    'bar': ('bar_layout','bar_position','bar_compose','ws_style','chip_style','tag_mode'),
    'windows': ('window_mode',),
    'terminal': ('term_font','term_titlebar','term_quick_position','term_cursor','prompt_format','prompt_right_format'),
    'editor': ('cursor_sidebar','cursor_show_tabs','cursor_breadcrumbs','cursor_sticky','cursor_numbers','cursor_wrap','cursor_highlight','cursor_minimap','cursor_activity'),
    'notes': ('note_font','note_heading_align','note_rule_style','note_heading_case','note_quote_style','note_quote_font_style'),
    'tools': ('btop_boxes','btop_proc_tree','btop_proc_left','btop_proc_graphs','btop_mem_graphs','fzf_layout','fzf_border'),
}
def compare():
    themes = [(nct.load_theme(p.stem), nct.strings_for(nct.load_theme(p.stem))) for p in sorted((ROOT / 'themes').glob('*.toml'))]
    pairs=[]
    for (a,sa),(b,sb) in itertools.combinations(themes,2):
        diff={g:[k for k in keys if sa[k] != sb[k]] for g,keys in GROUPS.items()}
        substantial=[g for g,keys in diff.items() if len(keys) >= (1 if g=='windows' else 2)]
        pairs.append({'a':a['name'],'b':b['name'],'surfaces':substantial,'differences':diff})
    return sorted(pairs,key=lambda p:(len(p['surfaces']),p['a'],p['b']))
if __name__=='__main__':
    pairs=compare()
    print(json.dumps({'scope':'Static effective settings only; live review required','pairs':len(pairs),'minimum_surface_groups':min(len(p['surfaces']) for p in pairs),'comparisons':pairs},indent=2))
