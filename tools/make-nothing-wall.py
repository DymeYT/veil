#!/usr/bin/env python3
"""Deterministic Nothing / Glyph Matrix wallpaper (black + faint dots + halftone). Not AI art."""
from __future__ import annotations

import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H, STEP = 3456, 2234, 28
# Glyph-home field: large faint ring on the left third (clock plane), not a scenic photo.
CX, CY = int(W * 0.28), int(H * 0.48)
R_OUTER, R_INNER = int(min(W, H) * 0.42), int(min(W, H) * 0.18)


def tone(x: int, y: int) -> tuple[int, int, int]:
    """Lattice dots on pure black; denser/brighter along a left-plane halftone ring."""
    on_lattice = x % STEP == 0 and y % STEP == 0
    soft = x % STEP <= 1 and y % STEP <= 1 and ((x // STEP + y // STEP) % 2 == 0)
    if not on_lattice and not soft:
        return (0, 0, 0)

    dx, dy = x - CX, y - CY
    dist = math.hypot(dx, dy)
    ring = 0.0
    if R_INNER <= dist <= R_OUTER:
        # Peaks mid-ring, fades at edges — reads as a Glyph matrix disc, not a photo.
        t = (dist - R_INNER) / max(1, R_OUTER - R_INNER)
        ring = math.sin(t * math.pi) ** 2

    if on_lattice:
        base = 38 + int(28 * ring)
        return (base, base, base)
    # Soft sub-dots only near the ring so the field stays mostly empty.
    if ring > 0.15:
        v = 18 + int(14 * ring)
        return (v, v, v)
    return (22, 22, 22) if soft else (0, 0, 0)


def main() -> None:
    ppm = ROOT / "art" / "nothing.ppm"
    jpg = ROOT / "art" / "nothing.jpg"
    with ppm.open("wb") as f:
        f.write(f"P6\n{W} {H}\n255\n".encode())
        row = bytearray()
        for y in range(H):
            row.clear()
            for x in range(W):
                row += bytes(tone(x, y))
            f.write(row)
    subprocess.run(
        ["sips", "-s", "format", "jpeg", str(ppm), "--out", str(jpg)],
        check=True,
    )
    ppm.unlink(missing_ok=True)
    print(jpg)


if __name__ == "__main__":
    main()
