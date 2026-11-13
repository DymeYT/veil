#!/usr/bin/env python3
"""Publish the current appearance for the sandboxed macOS screen saver host."""

import argparse
import base64
import json
import os
from pathlib import Path
import re
import stat
import tempfile


def sync(root, directory):
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError(f"expected a private directory owned by the current user at {directory}")

    config = json.loads((root / "generated/launcher.json").read_text())
    theme_id = config.get("theme_id", "")
    if not re.fullmatch(r"[a-z0-9-]+", theme_id):
        raise ValueError("invalid screen saver theme identifier")
    snapshot = {"palette": config}
    artwork = root / "art" / f"{theme_id}.jpg"
    if artwork.is_file():
        snapshot["jpeg"] = base64.b64encode(artwork.read_bytes()).decode("ascii")

    with tempfile.NamedTemporaryFile(mode="w", dir=directory, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            json.dump(snapshot, handle, separators=(",", ":"))
            handle.close()
            temporary.replace(directory / "appearance.json")
        finally:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("veil_root", type=Path)
    parser.add_argument("--remove", action="store_true", help="remove the published appearance")
    args = parser.parse_args()
    directory = Path("/Users/Shared") / f"Veil-{os.getuid()}"
    try:
        if args.remove:
            if directory.is_dir() and not directory.is_symlink() and directory.stat().st_uid == os.getuid():
                (directory / "appearance.json").unlink(missing_ok=True)
                directory.rmdir()
        else:
            sync(args.veil_root, directory)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Veil screen saver: {error}\n")


if __name__ == "__main__":
    main()
