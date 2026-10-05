# Copyright 2026 The DartRosa Authors
# SPDX-License-Identifier: Apache-2.0

"""Shrinks the screenshot PNGs: a 256-colour palette and maximum compression.

Usage: python3 optimize_pngs.py <directory>   (needs Pillow)
"""
import pathlib
import sys

from PIL import Image

for path in sorted(pathlib.Path(sys.argv[1]).glob("*.png")):
    before = path.stat().st_size
    image = Image.open(path).convert("RGB")
    image.quantize(
        colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE
    ).save(path, optimize=True)
    print(f"{path.name}: {before // 1024} KB -> {path.stat().st_size // 1024} KB")
