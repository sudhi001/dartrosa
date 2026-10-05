# Copyright 2026 The DartRosa Authors
# SPDX-License-Identifier: Apache-2.0

"""Turns the frames recorded by gifs_test.dart into small GIFs.

Usage: python3 make_gifs.py <frames directory> <output directory> [max width]
(needs Pillow). Each subdirectory of frames (NNNN.png and durations.json)
becomes <name>.gif: frames of different sizes are placed on one canvas,
repeated frames are merged, and all frames share one palette of at most
96 colors (flat UI colors survive this; text stays sharp without
dithering).
"""
import json
import pathlib
import sys

from PIL import Image, ImageChops

BACKGROUND = (226, 226, 230)


def load(folder):
    durations = json.loads((folder / "durations.json").read_text())
    frames = [Image.open(p).convert("RGB") for p in sorted(folder.glob("*.png"))]
    return frames, durations


def on_canvas(frames, max_width):
    width = max(f.width for f in frames)
    height = max(f.height for f in frames)
    scale = min(1.0, max_width / width)
    size = (round(width * scale), round(height * scale))
    out = []
    for frame in frames:
        canvas = Image.new("RGB", (width, height), BACKGROUND)
        canvas.paste(frame, (0, 0))
        if scale < 1:
            canvas = canvas.resize(size, Image.Resampling.LANCZOS)
        out.append(canvas)
    return out


def merge_repeats(frames, durations):
    merged, times = [], []
    for frame, ms in zip(frames, durations):
        if merged and ImageChops.difference(merged[-1], frame).getbbox() is None:
            times[-1] += ms
        else:
            merged.append(frame)
            times.append(ms)
    return merged, times


def palette_for(frames):
    # A palette from a strip of evenly spaced frames, so colors that only
    # some frames have (dialogs, errors) get entries.
    sample = frames[:: max(1, len(frames) // 12)]
    strip = Image.new("RGB", (sample[0].width, sample[0].height * len(sample)))
    for i, frame in enumerate(sample):
        strip.paste(frame, (0, i * sample[0].height))
    return strip.quantize(colors=96, method=Image.Quantize.MEDIANCUT)


def main():
    source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    max_width = int(sys.argv[3]) if len(sys.argv) > 3 else 720
    target.mkdir(parents=True, exist_ok=True)
    for folder in sorted(p for p in source.iterdir() if p.is_dir()):
        frames, durations = load(folder)
        frames, durations = merge_repeats(on_canvas(frames, max_width), durations)
        palette = palette_for(frames)
        quantized = [
            f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames
        ]
        out = target / f"{folder.name}.gif"
        quantized[0].save(
            out,
            save_all=True,
            append_images=quantized[1:],
            duration=durations,
            loop=0,
            optimize=True,
            disposal=1,
        )
        size = out.stat().st_size // 1024
        print(f"{out.name}: {len(frames)} frames, {frames[0].size}, {size} KB")


main()
