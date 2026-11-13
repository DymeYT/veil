#!/usr/bin/env python3
"""Deterministic Nothing / Glyph Matrix wallpaper (black + faint dots). Not AI art."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
W, H, STEP = 3456, 2234, 28


def main():
    ppm = ROOT / "art" / "nothing.ppm"
    jpg = ROOT / "art" / "nothing.jpg"
    with ppm.open("wb") as f:
        f.write(f"P6\n{W} {H}\n255\n".encode())
        row = bytearray()
        for y in range(H):
            row.clear()
            for x in range(W):
                if x % STEP == 0 and y % STEP == 0:
                    row += bytes((38, 38, 38))
                elif x % STEP <= 1 and y % STEP <= 1 and ((x // STEP + y // STEP) % 2 == 0):
                    row += bytes((22, 22, 22))
                else:
                    row += bytes((0, 0, 0))
            f.write(row)
    import subprocess
    subprocess.run(["sips", "-s", "format", "jpeg", str(ppm), "--out", str(jpg)], check=True)
    ppm.unlink(missing_ok=True)
    print(jpg)


if __name__ == "__main__":
    main()
