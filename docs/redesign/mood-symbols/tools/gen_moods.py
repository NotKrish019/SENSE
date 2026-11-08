"""Generate the five SENSE mood symbols (Living Landscapes style) as SVG.

Constraints: plain paths, clipPath and opacity only (flutter_svg / vector_graphics
safe). Off-register printmaking: colour plate offset from the ink line.
"""
import math, pathlib, sys

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

INK = "#293A35"
INK_MUTED = "#5A685F"
RAIN = "#3E6E6A"          # skyInk
SUN = "#E5AE56"           # sunOchre
SUN_GLOW = "#F0C985"
SUN_LINE = "#8A5B14"      # ochreInk
CREAM = "#F7EEDC"
MEADOW = "#7FA08A"
FOREST = "#3F6556"
STORM = "#5D6E67"
STORM_DEEP = "#3B4C46"
STORM_WASH = "#C9D1CC"
DRIZZLE_CLOUD = "#A3B2AA"
DRIZZLE_WASH = "#D2D9D4"
MIST_CLOUD = "#E9E6D8"

OFF = 'transform="translate(1.3 1.5)"'   # off-register plate


def ray(cx, cy, ang, r0, r1, w, sway=5):
    """Folk-art petal ray: curved flanks, tip swayed off-axis like a cut print."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux
    ta = math.radians(ang + sway)
    tx, ty = cx + r1 * math.cos(ta), cy + r1 * math.sin(ta)
    lx, ly = cx + r0 * ux + px * w, cy + r0 * uy + py * w
    rx, ry = cx + r0 * ux - px * w, cy + r0 * uy - py * w
    rm = (r0 + r1) / 2
    c1x, c1y = cx + rm * ux + px * w * 1.05, cy + rm * uy + py * w * 1.05
    c2x, c2y = cx + rm * ux - px * w * 0.75, cy + rm * uy - py * w * 0.75
    return (f"M{lx:.1f} {ly:.1f} Q{c1x:.1f} {c1y:.1f} {tx:.1f} {ty:.1f} "
            f"Q{c2x:.1f} {c2y:.1f} {rx:.1f} {ry:.1f} Z")


def svg(slug, title, desc, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" '
            f'role="img" aria-labelledby="{slug}-t {slug}-d">\n'
            f'  <title id="{slug}-t">{title}</title>\n'
            f'  <desc id="{slug}-d">{desc}</desc>\n'
            + (f"  <defs>{defs}</defs>\n" if defs else "")
            + body + "</svg>\n")


# 1 VERY LOW: large dense dark cloud, heavy rain, enclosed and weighted.
vl_cloud = ("M10 35 C3 35 2 25 10 24 C8 15 18 11 24 15 C27 7 41 6 44 14 "
            "C50 10 59 14 57 22 C63 24 62 35 55 35 C42 37 24 37 10 35 Z")
vl_rain = " ".join(f"M{x} 40.5 l-3 9" for x in (15, 24, 33, 42, 51)) + " " + \
          " ".join(f"M{x} 51.5 l-3 9" for x in (19.5, 28.5, 37.5, 46.5))
very_low = svg(
    "mood-1", "Very Low",
    "A large, dense, dark cloud with heavy rain falling beneath it.",
    f'''  <path d="M6 40 C2 22 14 4 33 4 C52 4 63 20 59 40 C57 54 47 62 32 62 C17 62 8 54 6 40 Z" fill="{STORM_WASH}" opacity="0.55"/>
  <path d="{vl_cloud}" fill="{STORM}" {OFF}/>
  <path d="M13 33 l5 -5 M20 34.5 l6 -6 M28 35 l6 -6 M36 35 l6 -6 M44 34.5 l6 -6 M51 33 l4 -4" stroke="{STORM_DEEP}" stroke-width="1.4" stroke-linecap="round" fill="none" clip-path="url(#vl-clip)"/>
  <path d="{vl_cloud}" fill="none" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>
  <path d="{vl_rain}" stroke="{RAIN}" stroke-width="2.6" stroke-linecap="round" fill="none"/>
''',
    defs=f'<clipPath id="vl-clip"><path d="{vl_cloud}"/></clipPath>')

# 2 LOW: smaller, lighter cloud, three sparse drizzle marks.
lo_cloud = ("M19 33 C13 33 13 25 19 25 C19 18 27 15 31 19 C34 13 44 14 44 21 "
            "C50 21 51 33 45 33 C37 34 27 34 19 33 Z")
low = svg(
    "mood-2", "Low",
    "A smaller, lighter cloud with three sparse drizzle marks.",
    f'''  <path d="M12 34 C10 21 20 11 32 11 C45 11 54 21 52 34 C51 45 43 55 32 55 C21 55 13 45 12 34 Z" fill="{DRIZZLE_WASH}" opacity="0.6"/>
  <path d="{lo_cloud}" fill="{DRIZZLE_CLOUD}" {OFF}/>
  <path d="M22 32 l3 -3 M38 32.5 l3 -3" stroke="{INK_MUTED}" stroke-width="1.2" stroke-linecap="round" fill="none"/>
  <path d="{lo_cloud}" fill="none" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M24 40 l-1.5 6 M34 46 l-1.5 6 M42.5 39 l-1.5 6" stroke="{RAIN}" stroke-width="2.3" stroke-linecap="round" fill="none"/>
''')

# 3 NEUTRAL: soft cloud bank, horizontal mist lines, no rain, no sun.
ne_cloud = ("M12 36 C6 36 6 29 12 28 C12 22 19 20 23 23 C26 17 35 16 38 21 "
            "C42 17 51 19 50 25 C56 25 58 36 51 36 C38 37 24 37 12 36 Z")
neutral = svg(
    "mood-3", "Neutral",
    "A soft, low cloud bank above calm horizontal lines of mist.",
    f'''  <path d="{ne_cloud}" fill="{MIST_CLOUD}" {OFF}/>
  <path d="{ne_cloud}" fill="none" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M9 43.5 C17 42 25 45 33 43.5 C41 42 48 45 55 43.5" stroke="{INK_MUTED}" stroke-width="2.3" stroke-linecap="round" fill="none"/>
  <path d="M15 50.5 C21 49 29 52 36 50.5 C42 49 46 51.5 50 50.5" stroke="{INK_MUTED}" stroke-width="2.3" stroke-linecap="round" fill="none"/>
  <path d="M8 57.5 C13 56.5 20 58.5 27 57.5 M34 57.5 C40 56.5 47 58.5 53 57.5" stroke="{INK_MUTED}" stroke-width="2.3" stroke-linecap="round" fill="none"/>
''')

# 4 GOOD: dominant warm sun emerging from behind a small cloud. No rain.
gcx, gcy, gr = 27, 26, 14
G_LEN = (10.0, 9.0, 11.0, 9.5, 11.5, 10.0, 9.0)
g_rays = " ".join(ray(gcx, gcy, a, gr + 3, gr + G_LEN[i], 2.6)
                  for i, a in enumerate((130, 165, 200, 235, 270, 305, 340)))
go_cloud = ("M35 51 C29 51 29 43 35 43 C35 37 43 35 46 39 C49 34 57 36 56 42 "
            "C61 43 61 51 55 51 C48 52 41 52 35 51 Z")
good = svg(
    "mood-4", "Good",
    "A large warm sun with rays, partly behind a small cloud. No rain.",
    f'''  <circle cx="{gcx}" cy="{gcy}" r="23" fill="{SUN_GLOW}" opacity="0.5"/>
  <path d="{g_rays}" fill="{SUN}" stroke="{SUN_LINE}" stroke-width="1.3" stroke-linejoin="round"/>
  <circle cx="{gcx}" cy="{gcy}" r="{gr}" fill="{SUN}" {OFF}/>
  <circle cx="{gcx}" cy="{gcy}" r="{gr}" fill="none" stroke="{SUN_LINE}" stroke-width="2.2"/>
  <path d="M19.5 23 C20.5 18 24.5 16 29 17" stroke="{SUN_LINE}" stroke-width="1.4" stroke-linecap="round" fill="none"/>
  <path d="{go_cloud}" fill="{CREAM}" {OFF}/>
  <path d="{go_cloud}" fill="{CREAM}" opacity="0.9"/>
  <path d="{go_cloud}" fill="none" stroke="{INK}" stroke-width="2.2" stroke-linejoin="round"/>
''')

# 5 GREAT: large unobstructed sun, full rays, gentle hill. Open and bright.
tcx, tcy, tr = 32, 24, 12
T_LEN = (11.5, 7.0, 10.5, 7.5, 11.0, 6.5, 11.5, 7.0, 10.0, 7.5, 11.0, 7.0)
t_rays = " ".join(ray(tcx, tcy, a, tr + 3, tr + T_LEN[i], 2.8 if i % 2 == 0 else 2.1)
                  for i, a in enumerate(range(-90, 270, 30)))
hill = ("M4 60 C11 52 23 49.5 33 51.5 C43 53.5 53 49.5 60 56 C61.5 58 61 61 57.5 61 "
        "L7 61 C4.5 61 3 61.5 4 60 Z")
great = svg(
    "mood-5", "Great",
    "A large, unobstructed sun with full rays above a gentle green hill.",
    f'''  <circle cx="{tcx}" cy="{tcy}" r="23.5" fill="{SUN_GLOW}" opacity="0.4"/>
  <circle cx="{tcx}" cy="{tcy}" r="17.5" fill="{SUN_GLOW}" opacity="0.45"/>
  <path d="{t_rays}" fill="{SUN}" stroke="{SUN_LINE}" stroke-width="1.3" stroke-linejoin="round"/>
  <circle cx="{tcx}" cy="{tcy}" r="{tr}" fill="{SUN}" {OFF}/>
  <circle cx="{tcx}" cy="{tcy}" r="{tr}" fill="none" stroke="{SUN_LINE}" stroke-width="2.2"/>
  <path d="M25.5 21 C26.5 16.5 30.5 14.8 34 15.6" stroke="{SUN_LINE}" stroke-width="1.4" stroke-linecap="round" fill="none"/>
  <path d="{hill}" fill="{MEADOW}" {OFF}/>
  <path d="M4 60 C11 52 23 49.5 33 51.5 C43 53.5 53 49.5 60 56" stroke="{FOREST}" stroke-width="2.2" stroke-linecap="round" fill="none"/>
  <path d="M16 57 l1 -3 M24 55.5 l0.6 -3 M41 56 l-0.4 -3 M49 56.5 l-1 -3" stroke="{FOREST}" stroke-width="1.3" stroke-linecap="round" fill="none"/>
''')

files = {
    "mood_1_very_low.svg": very_low,
    "mood_2_low.svg": low,
    "mood_3_neutral.svg": neutral,
    "mood_4_good.svg": good,
    "mood_5_great.svg": great,
}
for name, s in files.items():
    (OUT / name).write_text(s)
print("wrote", ", ".join(files))
