"""Build the mood-symbol review sheet (single self-contained HTML)."""
import base64, json, pathlib, sys

D = pathlib.Path(sys.argv[1])
metrics = json.loads(pathlib.Path(sys.argv[2]).read_text())

MOODS = [  # mirrors check_in_screen.dart _moodOptions: values, order, labels unchanged
    (1, "Very Low", "mood_1_very_low.svg", "Large dense dark cloud, 9 heavy rain strokes, dark wash"),
    (2, "Low", "mood_2_low.svg", "Smaller lighter cloud, 3 sparse drizzle marks"),
    (3, "Neutral", "mood_3_neutral.svg", "Low cloud bank, 3 mist lines, no rain, no sun"),
    (4, "Good", "mood_4_good.svg", "Dominant sun (7 rays) emerging behind a small cloud, no rain"),
    (5, "Great", "mood_5_great.svg", "Large open sun, 12 full rays, gentle hill, widest glow"),
]
uri = {f: "data:image/svg+xml;base64," + base64.b64encode((D / f).read_bytes()).decode() for _, _, f, _ in MOODS}


# ---- contrast -------------------------------------------------------------------------
def rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
def lin(c): return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def lum(h): r, g, b = map(lin, rgb(h)); return 0.2126 * r + 0.7152 * g + 0.0722 * b
def blend(top, a, under):
    t, u = rgb(top), rgb(under)
    return "#" + "".join(f"{round((a * x + (1 - a) * y) * 255):02X}" for x, y in zip(t, u))
def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + 0.05) / (lb + 0.05)

P, PAPER = "#F3EBDD", "#FAF7EF"
storm_wash = blend("#C9D1CC", 0.55, P)
drizzle_wash = blend("#D2D9D4", 0.6, P)
sun_glow = blend("#F0C985", 0.5, P)
great_glow = blend("#F0C985", 0.45, blend("#F0C985", 0.4, P))
rows = [  # (element, fg, bg, bg name, threshold, kind)
    ("Ink outline (all clouds)", "#293A35", P, "parchment", 3, "graphic"),
    ("Ink outline (all clouds)", "#293A35", PAPER, "paper (selected tile)", 3, "graphic"),
    ("Very low rain strokes", "#3E6E6A", storm_wash, "storm wash", 3, "graphic"),
    ("Very low cloud mass", "#5D6E67", storm_wash, "storm wash", 3, "graphic"),
    ("Low drizzle marks", "#3E6E6A", drizzle_wash, "overcast wash", 3, "graphic"),
    ("Neutral mist lines", "#5A685F", P, "parchment", 3, "graphic"),
    ("Neutral mist lines", "#5A685F", PAPER, "paper", 3, "graphic"),
    ("Good sun ring and rays", "#8A5B14", sun_glow, "sun glow", 3, "graphic"),
    ("Good sun ring and rays", "#8A5B14", PAPER, "paper", 3, "graphic"),
    ("Great sun ring and rays", "#8A5B14", great_glow, "inner glow", 3, "graphic"),
    ("Great hill contour", "#3F6556", P, "parchment", 3, "graphic"),
    ("Selected tile border (2.5 px)", "#3F6556", PAPER, "paper", 3, "graphic"),
    ("Selected tile border vs page", "#3F6556", P, "parchment", 3, "graphic"),
    ("Check badge (forest disc)", "#3F6556", PAPER, "paper", 3, "graphic"),
    ("Check mark on badge", "#FAF7EF", "#3F6556", "forest", 3, "graphic"),
    ("Unselected tile outline (1.5 px)", "#8C7F69", P, "parchment", 3, "graphic"),
    ("Label, selected (600)", "#293A35", PAPER, "paper", 4.5, "text"),
    ("Label, unselected (500)", "#5A685F", P, "parchment", 4.5, "text"),
]
contrast_html = "".join(
    f"<tr><td>{e}</td><td><span class=sw style='background:{f}'></span>{f}</td>"
    f"<td><span class=sw style='background:{b}'></span>{bn}</td><td class=num>{cr(f, b):.2f}:1</td>"
    f"<td class=num>{t}:1 {'text' if k == 'text' else 'non-text'}</td>"
    f"<td class={'ok' if cr(f, b) >= t else 'bad'}>{'Pass' if cr(f, b) >= t else 'Fail'}</td></tr>"
    for e, f, b, bn, t, k in rows)
all_pass = all(cr(f, b) >= t for _, f, b, _, t, _ in rows)


# ---- components -----------------------------------------------------------------------
CHECK = ('<svg class=check viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="9" '
         'fill="#3F6556" stroke="#FAF7EF" stroke-width="2"/><path d="M6 10.4 l2.7 2.6 L14.2 7.4" '
         'fill="none" stroke="#FAF7EF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>')

def tile(v, label, f, sel, size=40):
    name = f"{label}, {v} of 5" + (", selected" if sel else "")
    return (f"<div class='tile{' sel' if sel else ''}' role=radio aria-checked={'true' if sel else 'false'} "
            f"aria-label='{name}' title='Screen reader: “{name}”'>"
            f"{CHECK if sel else ''}<img src='{uri[f]}' width={size} height={size} alt=''>"
            f"<span>{label}</span></div>")

def row(selected, cls=""):
    return (f"<div class='mood-row {cls}' role=radiogroup aria-label='How are you feeling right now?'>"
            + "".join(tile(v, l, f, v == selected) for v, l, f, _ in MOODS) + "</div>")

def phone(selected, cls="", cap=""):
    return (f"<figure class=phone><div class='screen {cls}'><p class=q>How are you feeling right now?</p>"
            f"{row(selected)}</div><figcaption>{cap}</figcaption></figure>")

hero = "".join(
    f"<div class=hero-card><img src='{uri[f]}' width=128 height=128 alt='{l}'>"
    f"<div><b>{v} · {l}</b><p>{d}</p></div></div>" for v, l, f, d in MOODS)

states = "".join(
    f"<div class=state-pair><div class=state-lbl>{l}</div>{tile(v, l, f, False)}{tile(v, l, f, True)}</div>"
    for v, l, f, _ in MOODS)

def strip(size, cls=""):
    return f"<div class='strip {cls}'>" + "".join(
        f"<div><img src='{uri[f]}' width={size} height={size} alt='{l}'><small>{l}</small></div>"
        for v, l, f, _ in MOODS) + "</div>"

m40, m24 = metrics["40"], metrics["24"]
def metric_rows(m):
    return "".join(f"<tr><td>{n}</td><td class=num>{d['marked_pct']}%</td><td class=num>{d['dark_ink_pct']}%</td>"
                   f"<td class=num>{d['mean_lum']}</td></tr>" for n, d in m["per_symbol"].items())
def pair_rows(m):
    items = sorted(m["pairwise_mean_abs_diff"].items(), key=lambda x: x[1])
    return "".join(f"<tr{' class=hl' if k == 'Low vs Good' else ''}><td>{k}</td><td class=num>{v}</td></tr>" for k, v in items)

html = f"""<!doctype html><html lang=en><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Mood Symbols Review</title>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&display=swap" rel=stylesheet>
<style>
:root{{--parchment:#F3EBDD;--paper:#FAF7EF;--ink:#293A35;--muted:#5A685F;--forest:#3F6556;--ochre:#E5AE56;
--line:#D8CCB6;--strong:#8C7F69;--sage:#DFE7D9;color-scheme:light}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--parchment);color:var(--ink);font:15px/1.55 Poppins,system-ui,sans-serif}}
main{{max-width:1080px;margin:0 auto;padding:32px 16px 64px}}
h1{{font-weight:500;font-size:28px;margin:0 0 4px}} h2{{font-weight:600;font-size:19px;margin:44px 0 6px}}
.lede{{color:var(--muted);max-width:720px;margin:0}} .note{{color:var(--muted);font-size:13.5px;max-width:760px}}
.tag{{display:inline-block;border:1.5px solid var(--strong);border-radius:8px;padding:1px 8px;font-size:12.5px;color:var(--muted);margin-bottom:10px}}
.heroes{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:14px;margin-top:14px}}
.hero-card{{background:var(--paper);border:1px solid var(--line);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:6px}}
.hero-card img{{align-self:center;max-width:100%;height:auto}} .hero-card p{{margin:2px 0 0;font-size:13px;color:var(--muted);line-height:1.45}}
.phones{{display:flex;flex-wrap:wrap;gap:22px;margin-top:14px}}
.phone{{margin:0}} .phone figcaption{{font-size:12.5px;color:var(--muted);margin-top:6px;max-width:360px}}
.screen{{width:360px;max-width:calc(100vw - 32px);background:var(--parchment);border:1px solid var(--line);border-radius:22px;padding:18px 20px 22px;box-shadow:0 1px 0 #fff8 inset}}
.q{{margin:0 0 12px;font-weight:500;font-size:17px}}
.mood-row{{display:flex;gap:6px}}
.tile{{position:relative;flex:1 1 0;min-width:0;min-height:96px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;
border:1.5px solid var(--strong);border-radius:12px;padding:10px 2px 8px;background:transparent;font-size:12px;line-height:1.2;font-weight:500;color:var(--muted);text-align:center}}
.tile.sel{{background:var(--paper);border:2.5px solid var(--forest);color:var(--ink);font-weight:600;box-shadow:3px 3px 0 var(--ochre)}}
.tile .check{{position:absolute;top:-8px;right:-8px;width:22px;height:22px}}
.states{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:14px;margin-top:14px}}
.state-pair{{display:grid;grid-template-columns:1fr 1fr;gap:10px;background:var(--paper);border:1px solid var(--line);border-radius:14px;padding:12px 14px 14px}}
.state-pair .tile{{width:auto}} .state-lbl{{grid-column:1/-1;font-size:13px;font-weight:600}}
.state-pair .tile.sel{{background:#fff}}
.strip{{display:flex;gap:18px;align-items:flex-end;flex-wrap:wrap;margin-top:10px}}
.strip div{{display:flex;flex-direction:column;align-items:center;gap:4px}} .strip small{{font-size:11.5px;color:var(--muted)}}
.gray{{filter:grayscale(1)}} .protan{{filter:url(#protan)}} .deutan{{filter:url(#deutan)}} .tritan{{filter:url(#tritan)}}
.cvd{{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr));gap:14px;margin-top:12px}}
.cvd > div{{background:var(--paper);border:1px solid var(--line);border-radius:14px;padding:12px 14px}}
.cvd b{{font-size:13px}}
table{{border-collapse:collapse;width:100%;font-size:13.5px;margin-top:10px;background:var(--paper);border-radius:12px;overflow:hidden}}
th,td{{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:middle}}
th{{font-weight:600;font-size:12.5px;color:var(--muted)}} .num{{font-variant-numeric:tabular-nums;white-space:nowrap}}
.ok{{color:var(--forest);font-weight:600}} .bad{{color:#9A4A3F;font-weight:600}}
.sw{{display:inline-block;width:12px;height:12px;border-radius:3px;border:1px solid #0003;margin-right:6px;vertical-align:-1px}}
tr.hl td{{background:#F0E3C6}}
.scroll{{overflow-x:auto}}
.two{{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(300px,100%),1fr));gap:18px}}
ul.checks{{padding-left:18px;margin:8px 0}} ul.checks li{{margin:3px 0}}
@media (max-width:420px){{.screen{{padding:16px 12px 20px}} .mood-row{{gap:4px}} .tile{{font-size:11px}}}}
</style></head><body>
<svg width=0 height=0 style=position:absolute aria-hidden=true><defs>
<filter id=protan color-interpolation-filters=linearRGB><feColorMatrix type=matrix values="0.152 1.053 -0.205 0 0  0.115 0.786 0.099 0 0  -0.004 -0.048 1.052 0 0  0 0 0 1 0"/></filter>
<filter id=deutan color-interpolation-filters=linearRGB><feColorMatrix type=matrix values="0.367 0.861 -0.228 0 0  0.280 0.673 0.047 0 0  -0.012 0.043 0.969 0 0  0 0 0 1 0"/></filter>
<filter id=tritan color-interpolation-filters=linearRGB><feColorMatrix type=matrix values="1.256 -0.077 -0.179 0 0  -0.078 0.931 0.148 0 0  0.005 0.691 0.304 0 0  0 0 0 1 0"/></filter>
</defs></svg>
<main>
<span class=tag>For review · not integrated · prototype data unchanged</span>
<h1>Mood symbols, refined set</h1>
<p class=lede>Five original Living Landscapes illustrations for the check-in mood scale. Values, order and labels are exactly those in
<code>check_in_screen.dart</code>: 1 Very Low, 2 Low, 3 Neutral, 4 Good, 5 Great. The progression is carried by
<b>rain quantity</b> (9 → 3 → 0), <b>cloud size and weight</b>, and <b>sun presence</b> (none → partial → full), so it does not depend on colour.</p>

<div class=heroes>{hero}</div>

<h2>Actual mobile size</h2>
<p class=note>360 px phone width, 20 px gutters, 40 px symbols in five equal tiles (about 59 × 96 px each). Viewed at 1× this is true size.</p>
<div class=phones>
{phone(3, cap="Default state: Neutral selected (prototype default is 3).")}
{phone(2, cap="Low selected: grey cloud, three drizzle marks.")}
{phone(4, cap="Good selected: sun with rays, small cloud, no rain.")}
</div>

<h2>Selected and unselected states</h2>
<p class=note>Selection is shown by four cues, none of them colour alone: border weight (1.5 → 2.5 px), a check badge,
a paper fill with an offset print shadow, and label weight (500 → 600). Screen readers announce each tile as a radio,
for example “Low, 2 of 5, selected”.</p>
<div class=states>{states}</div>

<h2>Grayscale</h2>
<div class=phones>{phone(2, "gray", "Low selected, grayscale.")}{phone(4, "gray", "Good selected, grayscale.")}</div>
<div class=two>
<div><p class=note style="margin-top:16px">40 px, grayscale</p>{strip(40, "gray")}</div>
<div><p class=note style="margin-top:16px">24 px, grayscale (smallest stress test)</p>{strip(24, "gray")}</div>
</div>

<h2>Colour-vision simulations</h2>
<p class=note>Approximate simulations (Machado 2009 matrices, severity 1.0). Low and Good stay distinct through rain marks vs sun disc and rays.</p>
<div class=cvd>
<div><b>Protanopia</b>{strip(40, "protan")}</div>
<div><b>Deuteranopia</b>{strip(40, "deutan")}</div>
<div><b>Tritanopia</b>{strip(40, "tritan")}</div>
<div><b>Full colour (reference)</b>{strip(40)}</div>
</div>

<h2>Contrast verification</h2>
<p class=note>WCAG 2.2: 3:1 for meaningful graphics and control boundaries (1.4.11), 4.5:1 for label text (1.4.3).
Semi-transparent washes are blended over the page colour before measuring. Fills (ochre sun, cream clouds, meadow) are
supplementary; every meaningful shape has an ink, ochre-ink or forest contour that carries the contrast.
Result: <b class={'ok' if all_pass else 'bad'}>{'all ' + str(len(rows)) + ' pairs pass' if all_pass else 'some pairs fail'}</b>.</p>
<div class=scroll><table><tr><th>Element</th><th>Foreground</th><th>Background</th><th>Ratio</th><th>Required</th><th></th></tr>{contrast_html}</table></div>

<h2>Measured distinctness (grayscale render)</h2>
<p class=note>Each symbol rendered by Chrome at 1×, converted to grayscale, measured per pixel. “Marked” is any pixel
noticeably different from parchment; “dark ink” is luminance under 110. Pairwise difference is the mean absolute luminance
difference (0 to 255). This is a coarse, shape-blind measure. Low vs Good is still the lowest-scoring pair, because both
are light symbols of similar overall weight. Their difference is in kind (drizzle marks vs a ringed sun with rays), which
this number does not capture, so judge that pair by eye in the grayscale rows above.</p>
<div class=two>
<div class=scroll><table><tr><th>40 px</th><th>Marked</th><th>Dark ink</th><th>Mean lum.</th></tr>{metric_rows(m40)}</table>
<table><tr><th>40 px pair</th><th>Mean diff</th></tr>{pair_rows(m40)}</table></div>
<div class=scroll><table><tr><th>24 px</th><th>Marked</th><th>Dark ink</th><th>Mean lum.</th></tr>{metric_rows(m24)}</table>
<table><tr><th>24 px pair</th><th>Mean diff</th></tr>{pair_rows(m24)}</table></div>
</div>

<h2>Accessibility checklist</h2>
<ul class=checks>
<li>Written labels kept under every symbol; symbols are decorative to screen readers (empty alt), the tile carries the name.</li>
<li>Accessible names: “Very Low, 1 of 5”, “Low, 2 of 5”, “Neutral, 3 of 5”, “Good, 4 of 5”, “Great, 5 of 5”, plus “selected”.</li>
<li>Touch targets about 59 × 96 px at 360 px width and about 51 × 96 px at 320 px (20 px gutters, 6 px gaps; minimum 48 × 48).</li>
<li>Selection is never colour-only: border weight, check badge, fill and label weight.</li>
<li>Symbols use only paths, clip paths and opacity, so <code>flutter_svg</code> can render them, with no filters, patterns or fonts.</li>
<li>Not yet done: integration, Flutter widget tests, real VoiceOver and TalkBack passes (outstanding project-wide).</li>
</ul>
</main></body></html>"""
out = D / "mood_symbols_review.html"
out.write_text(html)
print("wrote", out, "| contrast all pass:", all_pass)
for e, f, b, bn, t, k in rows:
    print(f"  {cr(f, b):5.2f}  {e} on {bn}")
