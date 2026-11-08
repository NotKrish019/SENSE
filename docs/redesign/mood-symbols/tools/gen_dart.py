"""Convert the approved mood SVGs into Dart drawing data for the Flutter prototype.

The SVG files in docs/redesign/mood-symbols/ stay the editable source of truth.
This script copies their shapes, unchanged, into
mobile/lib/presentation/nature/mood_glyph_data.dart (production), because the app draws all
artwork in code (no image assets, no SVG package).

    python3 docs/redesign/mood-symbols/tools/gen_dart.py

Supported subset (all the symbols use): <path> and <circle> with fill, stroke,
stroke-width, stroke-linecap, stroke-linejoin, opacity, transform="translate(x y)"
and clip-path="url(#id)" referring to a <clipPath> holding one <path>.
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[4]
SRC = ROOT / "docs/redesign/mood-symbols"
OUT = ROOT / "mobile/lib/presentation/nature/mood_glyph_data.dart"
FILES = ["mood_1_very_low.svg", "mood_2_low.svg", "mood_3_neutral.svg",
         "mood_4_good.svg", "mood_5_great.svg"]

ATTR = re.compile(r'([a-z-]+)="([^"]*)"')


def color(v):
    if not v or v == "none":
        return "null"
    return f"Color(0xFF{v.lstrip('#').upper()})"


def layer(tag, attrs, clips):
    a = dict(ATTR.findall(attrs))
    if tag == "circle":
        cx, cy, r = (float(a[k]) for k in ("cx", "cy", "r"))
        d = f"circle:{cx:g},{cy:g},{r:g}"
    else:
        d = a["d"]
    dx = dy = 0.0
    if "transform" in a:
        m = re.fullmatch(r"translate\(([-\d.]+)[ ,]+([-\d.]+)\)", a["transform"])
        assert m, a["transform"]
        dx, dy = float(m.group(1)), float(m.group(2))
    clip = None
    if "clip-path" in a:
        clip = clips[re.fullmatch(r"url\(#(.+)\)", a["clip-path"]).group(1)]
    fill = a.get("fill", "#000000")
    return ("    MoodLayer(\n"
            f"      '{d}',\n"
            f"      fill: {color(fill)},\n"
            f"      stroke: {color(a.get('stroke'))},\n"
            f"      strokeWidth: {float(a.get('stroke-width', 1)):g},\n"
            f"      roundCap: {'true' if a.get('stroke-linecap') == 'round' else 'false'},\n"
            f"      roundJoin: {'true' if a.get('stroke-linejoin') == 'round' else 'false'},\n"
            f"      opacity: {float(a.get('opacity', 1)):g},\n"
            f"      dx: {dx:g},\n      dy: {dy:g},\n"
            + (f"      clip: '{clip}',\n" if clip else "")
            + "    ),\n")


def convert(name):
    svg = (SRC / name).read_text()
    clips = {m.group(1): m.group(2) for m in
             re.finditer(r'<clipPath id="([^"]+)"><path d="([^"]+)"/></clipPath>', svg)}
    body = re.sub(r"<defs>.*?</defs>", "", svg, flags=re.S)
    title = re.search(r"<title[^>]*>(.*?)</title>", svg).group(1)
    desc = re.search(r"<desc[^>]*>(.*?)</desc>", svg).group(1)
    layers = "".join(layer(t, at, clips) for t, at in
                     re.findall(r"<(path|circle)\s([^>]*?)/>", body))
    return title, desc, layers


parts = []
for i, f in enumerate(FILES, start=1):
    title, desc, layers = convert(f)
    parts.append(f"  // {f}: {title}. {desc}\n  {i}: [\n{layers}  ],\n")

OUT.write_text(f"""// GENERATED FILE. Do not edit by hand.
// Source: docs/redesign/mood-symbols/mood_*.svg (the editable originals).
// Regenerate: python3 docs/redesign/mood-symbols/tools/gen_dart.py
//
// Shapes of the five approved Living Landscapes mood symbols, in a 64 x 64
// design space, keyed by the existing mood value (1 Very Low ... 5 Great).

import 'package:flutter/painting.dart';

/// One drawn layer of a mood symbol, copied from the SVG source.
///
/// [path] is SVG path data (M, L, l, C, Q, Z) or `circle:cx,cy,r`.
class MoodLayer {{
  final String path;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final bool roundCap;
  final bool roundJoin;
  final double opacity;
  final double dx, dy; // off-register print offset (SVG translate)
  final String? clip; // SVG path data of a clip region
  const MoodLayer(this.path,
      {{this.fill,
      this.stroke,
      this.strokeWidth = 1,
      this.roundCap = false,
      this.roundJoin = false,
      this.opacity = 1,
      this.dx = 0,
      this.dy = 0,
      this.clip}});
}}

const Map<int, List<MoodLayer>> moodGlyphLayers = {{
{''.join(parts)}}};
""")
print("wrote", OUT.relative_to(ROOT))
