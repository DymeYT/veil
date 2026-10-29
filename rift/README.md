# Veil's Rift patch

`veil.patch` applies to [Rift](https://github.com/acsandmann/rift) at commit
`3114cc5eb3eb6858a3495690312065fe9d95c609`. `install.sh` clones that commit, applies the patch and builds `rift`
and `rift-cli`.

Rift is licensed under the Apache License 2.0 (copyright tmandry and acsandmann). As required by section 4 of
that license, this patch is a modification of Rift, and the patched files are changed by Veil:

| File | Change |
| --- | --- |
| `src/actor/reactor/animation.rs` | Timing curves: Hyprland's `myBezier` overshoot for window moves, Hyprland's default curve for workspace slides; workspace switches slide the new windows in from the side you move toward (single display only); old windows park instantly, because macOS will not keep a window fully off screen |
| `src/actor/reactor/managers.rs` | Remembers each space's workspace index so a switch knows which way to slide |
| `src/actor/reactor/tests.rs` | Updated for the new `workspace_switch_layout` argument |
| `src/layout_engine/systems/traditional.rs` (tests) | Test for directional resize and the edge-tile fallback |
| `crates/rift-protocol/src/layout.rs` | `ResizeOrientation` gains `left`, `right`, `up`, `down` |
| `src/layout_engine/systems/traditional.rs`, `bsp.rs` | Directional resize: an edge moves in the pressed direction; edge tiles move their opposite edge instead |
| `src/layout_engine/systems/scrolling.rs` | Treats directional resizes as their axis |
| `src/bin/rift-cli.rs`, `src/ui/settings/commands.rs` | Expose the new directions |

The rest of Rift is unchanged. Veil's config (`templates/rift.toml`) uses the new resize directions, so it needs
the patched build.
