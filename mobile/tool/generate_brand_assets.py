#!/usr/bin/env python3
"""Generates the SENSE logo SVGs (source of truth) and the web PNG icons.

The mark: a geometric "S" drawn as two circular signal paths that meet at a
central node, with a node at each end - "networked signals converging on one
person". The geometry below is mirrored exactly by
`lib/presentation/widgets/sense_logo.dart` (keep the two in sync).

Usage (from mobile/):
    python3 tool/generate_brand_assets.py           # write SVGs only
    python3 tool/generate_brand_assets.py --png     # also render web PNGs
PNG rendering uses a locally installed Google Chrome in headless mode, so
the PNGs are pixel renders of the same SVGs.

The horizontal lockup's wordmark is written as vector outlines taken from the
bundled Poppins SemiBold (assets/fonts/poppins/), so the SVG renders the same
on systems without Poppins. This needs the `fonttools` Python package
(`python3 -m pip install fonttools`); the other SVGs need no packages.
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE = os.path.dirname(HERE)
BRAND = os.path.join(MOBILE, 'assets', 'branding')
WEB = os.path.join(MOBILE, 'web')

# ---- Palette (design.md) ----------------------------------------------------
NAVY = '#012F5F'
OCEAN = '#02549B'
ELECTRIC = '#059BE0'
SOFT_CYAN = '#58E2F9'
WHITE = '#FFFFFF'

# Living Landscapes app-icon palette (Phase 1, approved): deep forest tile,
# parchment mark, restrained ochre centre node. Same mark geometry.
FOREST = '#3F6556'
PARCHMENT = '#F3EBDD'
OCHRE = '#E5AE56'

# ---- Mark geometry, in a 100 x 100 box ---------------------------------------
R = 15.5            # radius of both signal arcs
C1 = (50.0, 34.5)   # upper arc centre
C2 = (50.0, 65.5)   # lower arc centre (arcs touch at the centre node 50,50)
START_DEG = -15.0   # upper terminal, measured clockwise from +x (y down)
END_DEG = 165.0     # lower terminal (point-symmetric to the upper one)
STROKE = 9.0
TERMINAL_R = 7.0
CENTRE_R = 8.5
CENTRE_GAP = 3.0    # ring separating the centre node from the paths


def _pt(c, deg):
    a = math.radians(deg)
    return (c[0] + R * math.cos(a), c[1] + R * math.sin(a))


def mark_elements(stroke, centre, gap_colour=None, transform=''):
    """SVG elements for the mark. `gap_colour` draws the separating ring."""
    s = _pt(C1, START_DEG)
    e = _pt(C2, END_DEG)
    path = (f'M {s[0]:.3f} {s[1]:.3f} '
            f'A {R} {R} 0 1 0 50 50 '
            f'A {R} {R} 0 1 1 {e[0]:.3f} {e[1]:.3f}')
    out = [f'<g{(" transform=%r" % transform) if transform else ""}>'.replace("'", '"'),
           f'  <path d="{path}" fill="none" stroke="{stroke}" '
           f'stroke-width="{STROKE}" stroke-linecap="round"/>',
           f'  <circle cx="{s[0]:.3f}" cy="{s[1]:.3f}" r="{TERMINAL_R}" fill="{stroke}"/>',
           f'  <circle cx="{e[0]:.3f}" cy="{e[1]:.3f}" r="{TERMINAL_R}" fill="{stroke}"/>']
    if gap_colour:
        out.append(f'  <circle cx="50" cy="50" r="{CENTRE_R + CENTRE_GAP}" fill="{gap_colour}"/>')
    out.append(f'  <circle cx="50" cy="50" r="{CENTRE_R}" fill="{centre}"/>')
    out.append('</g>')
    return '\n'.join(out)


GRADIENT = (f'<linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{ELECTRIC}"/>'
            f'<stop offset="1" stop-color="{OCEAN}"/></linearGradient>')


def svg(body, w=100, h=100, defs=''):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
            f'width="{w}" height="{h}">\n'
            + (f'<defs>{defs}</defs>\n' if defs else '') + body + '\n</svg>\n')


def badge_body(mark_scale=0.84, radius=22.0, full_bleed=False, forest=False):
    """Rounded-square app badge.

    Default: gradient tile, white mark, cyan centre node (the original badge,
    still used by the horizontal lockup). `forest=True`: the Living
    Landscapes app icon - deep forest tile, parchment mark, ochre centre."""
    t = 50 * (1 - mark_scale)
    fill = FOREST if forest else 'url(#g)'
    tile = (f'<rect width="100" height="100" fill="{fill}"/>' if full_bleed else
            f'<rect width="100" height="100" rx="{radius}" fill="{fill}"/>')
    transform = f'translate({t:.2f} {t:.2f}) scale({mark_scale})'
    if forest:
        # The separating ring takes the tile colour, as on the original badge.
        return tile + '\n' + mark_elements(PARCHMENT, OCHRE, gap_colour=FOREST, transform=transform)
    # The separating ring takes the tile colour at the centre (gradient midpoint).
    return tile + '\n' + mark_elements(WHITE, SOFT_CYAN, gap_colour='#047CB3', transform=transform)


def badge(forest=False, **kw):
    return svg(badge_body(forest=forest, **kw), defs='' if forest else GRADIENT)


# ---- Wordmark: "SENSE" in Poppins SemiBold, outlined -------------------------
WORDMARK = 'SENSE'
WORDMARK_FONT = os.path.join(MOBILE, 'assets', 'fonts', 'poppins', 'Poppins-SemiBold.ttf')
WORDMARK_X = 122.0          # left edge of the first glyph's advance box
WORDMARK_BASELINE = 68.0
WORDMARK_SIZE = 46.0        # font size in SVG units
WORDMARK_TRACKING = 7.0     # extra space after each glyph (CSS letter-spacing)


def wordmark_paths(fill):
    """SVG <path> for the wordmark, laid out as a browser lays out
    `<text letter-spacing=...>`: advance width + tracking per glyph. Poppins
    has no kerning between S, E and N, so this matches text rendering."""
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.svgPathPen import SVGPathPen
        from fontTools.pens.transformPen import TransformPen
    except ImportError:
        sys.exit('fonttools is required to outline the wordmark: '
                 'python3 -m pip install fonttools')
    font = TTFont(WORDMARK_FONT)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = WORDMARK_SIZE / font['head'].unitsPerEm
    x = WORDMARK_X
    parts = []
    for ch in WORDMARK:
        name = cmap[ord(ch)]
        pen = SVGPathPen(glyphs)
        # Font units (y up) -> SVG units (y down), placed on the baseline.
        glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x, WORDMARK_BASELINE)))
        parts.append(pen.getCommands())
        x += glyphs[name].width * scale + WORDMARK_TRACKING
    return (f'<path aria-label="{WORDMARK}" fill="{fill}" d="'
            + ' '.join(parts) + '"/>')


def write_svgs():
    os.makedirs(BRAND, exist_ok=True)
    files = {
        # Symbol for light backgrounds: Ocean Blue paths, Electric Blue centre.
        'sense_mark.svg': svg(mark_elements(OCEAN, ELECTRIC, gap_colour=WHITE)),
        # Single-colour symbol (Navy); recolour freely for one-colour printing.
        'sense_mark_mono.svg': svg(mark_elements(NAVY, NAVY)),
        # Symbol for dark backgrounds.
        'sense_mark_white.svg': svg(mark_elements(WHITE, SOFT_CYAN, gap_colour=NAVY)),
        # App icon / badge (rounded square), Living Landscapes palette.
        'sense_app_icon.svg': badge(forest=True),
        # Maskable icon: full-bleed tile, mark kept inside the 80 % safe zone.
        'sense_app_icon_maskable.svg': badge(forest=True, mark_scale=0.72, full_bleed=True),
        # Primary horizontal lockup: badge + SENSE wordmark (Poppins SemiBold,
        # outlined to paths so it does not depend on an installed font).
        'sense_logo_horizontal.svg': svg(
            '<title>SENSE</title>\n' + badge_body() + '\n' + wordmark_paths(NAVY),
            w=330, h=100, defs=GRADIENT),
        # The same lockup in the Living Landscapes identity (forest badge,
        # forest wordmark) for the redesigned app and its documents.
        'sense_logo_horizontal_forest.svg': svg(
            '<title>SENSE</title>\n' + badge_body(forest=True) + '\n' + wordmark_paths(FOREST),
            w=330, h=100),
    }
    for name, content in files.items():
        with open(os.path.join(BRAND, name), 'w') as f:
            f.write(content)
    return files


CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'


def render_png(svg_path, out_path, size):
    html = (f'<html><body style="margin:0;background:transparent">'
            f'<img src="file://{svg_path}" width="{size}" height="{size}" style="display:block">'
            f'</body></html>')
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, 'p.html')
        with open(page, 'w') as f:
            f.write(html)
        subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                        '--default-background-color=00000000', '--force-device-scale-factor=1',
                        f'--window-size={size},{size}', f'--user-data-dir={tmp}/u',
                        f'--screenshot={out_path}', f'file://{page}'],
                       check=True, capture_output=True)


def write_pngs():
    icon = os.path.join(BRAND, 'sense_app_icon.svg')
    mask = os.path.join(BRAND, 'sense_app_icon_maskable.svg')
    jobs = [(icon, os.path.join(WEB, 'favicon.png'), 32),
            (icon, os.path.join(WEB, 'icons', 'Icon-192.png'), 192),
            (icon, os.path.join(WEB, 'icons', 'Icon-512.png'), 512),
            (mask, os.path.join(WEB, 'icons', 'Icon-maskable-192.png'), 192),
            (mask, os.path.join(WEB, 'icons', 'Icon-maskable-512.png'), 512)]
    for src, out, size in jobs:
        render_png(src, out, size)
        print('rendered', os.path.relpath(out, MOBILE), size)


if __name__ == '__main__':
    for n in write_svgs():
        print('wrote assets/branding/' + n)
    if '--png' in sys.argv:
        if not os.path.exists(CHROME):
            sys.exit('Google Chrome not found; PNGs not rendered.')
        write_pngs()
