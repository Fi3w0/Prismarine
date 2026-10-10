#!/usr/bin/env python3
"""Render the desktop SVG using librsvg and Pillow (PNG, Windows ICO, macOS ICNS)."""
from pathlib import Path
import subprocess

from PIL import Image

root = Path(__file__).resolve().parent.parent
icons = root / "assets/logos/icons"
icons.mkdir(exist_ok=True)
for size in (16, 24, 32, 48, 64, 128, 256, 512, 1024):
    subprocess.run([
        "rsvg-convert", "--width", str(size), "--height", str(size),
        "--output", str(icons / f"prismarine-{size}.png"),
        str(root / "assets/logos/desktop.svg"),
    ], check=True)
with Image.open(icons / "prismarine-1024.png") as icon:
    icon.save(icons / "prismarine.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    icon.save(icons / "prismarine.icns")
