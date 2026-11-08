"""Compose the Phase 1 production review images from real-Chrome screenshots.

python3 compose_phase1.py <shots dir> <out dir> <mobile/assets/fonts/poppins> <mobile/web>
Screenshots come from the production web build driven through the real entry
flow (Splash > Onboarding > Consent > Home) by ../../check-in-preview/tools/cdp.mjs.
"""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont

SH, OUT, FONT, WEB = (pathlib.Path(a) for a in sys.argv[1:5])
OUT.mkdir(parents=True, exist_ok=True)
BG, INK, MUTED, LINE = (243, 235, 221), (41, 58, 53), (90, 104, 95), (216, 204, 182)


def font(size, weight='Medium'):
    return ImageFont.truetype(str(FONT / f'Poppins-{weight}.ttf'), size)


def trim(im, keep=48):
    g = im.convert('L')
    w, h = g.size
    for y in range(h - 1, 0, -3):
        if min(g.getpixel((x, y)) for x in range(8, w - 8, 3)) < 160:
            return im.crop((0, 0, w, min(h, y + keep)))
    return im


def sheet(items, cols, title, sub, width_each, pad=36, label_h=60, max_h=None):
    ims = []
    for src, label in items:
        im = trim(Image.open(src)) if not isinstance(src, Image.Image) else src
        if max_h:
            im = im.crop((0, 0, im.width, min(im.height, int(max_h * im.width / width_each))))
        s = width_each / im.width
        ims.append((im.convert('RGB').resize((width_each, int(im.height * s)), Image.LANCZOS), label))
    rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]
    head = 150
    H = head + sum(max(i.height for i, _ in r) + label_h + pad for r in rows) + pad
    W = pad + cols * (width_each + pad)
    out = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(out)
    d.text((pad, 34), title, font=font(40), fill=INK)
    d.text((pad, 90), sub, font=font(22, 'Regular'), fill=MUTED)
    y = head
    for r in rows:
        x = pad
        for im, label in r:
            d.text((x, y + 12), label, font=font(23), fill=INK)
            out.paste(im, (x, y + label_h))
            d.rectangle((x - 1, y + label_h - 1, x + im.width, y + label_h + im.height), outline=LINE)
            x += width_each + pad
        y += max(i.height for i, _ in r) + label_h + pad
    return out


def save(im, name):
    im.save(OUT / name, optimize=True)
    print('wrote', name, im.size)


save(sheet([(SH / 'pm_412_t1_home.png', 'Home'),
            (SH / 'pm_412_t1_ci1.png', 'Check-in, step 1 (Good selected next)'),
            (SH / 'pm_412_t1_ci2.png', 'Check-in, step 2'),
            (SH / 'pm_412_t1_done.png', 'Finished: not saved')], 4,
           'Production app, phone (412 px)',
           'Real production web build, entered through Splash > Onboarding > Consent. Bundled Poppins.', 460),
     'production_phone_412_flow.png')

save(sheet([(SH / 'pm_1280_t1_home.png', 'Desktop 1280 px: Home with top navigation'),
            (SH / 'pm_1280_t1_ci1.png', 'Desktop 1280 px: Check-in')], 2,
           'Production app, desktop',
           'Top bar (wordmark, tabs, New check-in); landscape spans the window; floating journal sheet.', 900),
     'production_desktop_1280.png')

save(sheet([(SH / 'pm_1440_t1_home.png', 'Desktop 1440 px: Home'),
            (SH / 'pm_1280_t1_insights.png', 'Desktop 1280 px: Insights (not redesigned yet, centred)')], 2,
           'Production app, wide desktop and a transitional tab',
           'Insights and Profile keep the current design until their phase; they are centred at 760 px.', 900),
     'production_desktop_1440_and_insights.png')

save(sheet([(SH / 'pm_768_t1_home.png', 'Tablet 768 px: Home'),
            (SH / 'pm_768_t1_ci1.png', 'Tablet 768 px: Check-in'),
            (SH / 'pm_768_t1_insights.png', 'Tablet 768 px: Insights (centred)')], 3,
           'Production app, tablet',
           'Bottom navigation; reading column capped and centred instead of stretched.', 520, max_h=1300),
     'production_tablet_768.png')

items = []
for w in [320, 360, 412, 768, 1024, 1280, 1440]:
    for t in [1, 2]:
        items.append((SH / f'pm_{w}_t{t}_home.png', f'{w} px, {t}x text'))
save(sheet(items, 7, 'Production Home at every width, normal and 2x text',
           'Real Chrome, browser text size doubled for 2x. No horizontal overflow in any run.', 300,
           label_h=48, max_h=1500), 'production_responsive_home.png')

items = []
for w in [320, 360, 412, 768, 1024, 1280, 1440]:
    for t in [1, 2]:
        items.append((SH / f'pm_{w}_t{t}_ci1.png', f'{w} px, {t}x text'))
save(sheet(items, 7, 'Production Check-in at every width, normal and 2x text',
           'Five across when every word fits; an ordered list on narrow screens and large text.', 300,
           label_h=48, max_h=1500), 'production_responsive_check_in.png')

save(sheet([(SH / 'cmp_prod_home.png', 'Production Home'),
            (SH / 'cmp_preview_home.png', 'Isolated preview Home'),
            (SH / 'cmp_prod_ci.png', 'Production Check-in'),
            (SH / 'cmp_preview_ci.png', 'Isolated preview Check-in')], 4,
           'Production vs isolated preview (412 px, reduced motion)',
           'Pixel comparison: 0 differing pixels for Home and for Check-in. Production renders the approved design.', 460),
     'production_vs_preview_412.png')

icons = [Image.open(WEB / 'icons' / f).convert('RGBA') for f in ['Icon-512.png', 'Icon-maskable-512.png']]
icons += [Image.open(WEB / 'icons' / 'Icon-192.png').convert('RGBA').resize((256, 256), Image.LANCZOS),
          Image.open(WEB / 'favicon.png').convert('RGBA').resize((128, 128), Image.NEAREST)]
labels = ['Icon 512', 'Maskable 512 (full bleed)', 'Icon 192', 'Favicon 32 (enlarged)']
W = 36 + sum(i.width + 36 for i in icons)
out = Image.new('RGB', (W, 512 + 220), BG)
d = ImageDraw.Draw(out)
d.text((36, 34), 'Production web icons: forest, parchment and ochre', font=font(40), fill=INK)
d.text((36, 90), 'Same SENSE logo geometry; generated by mobile/tool/generate_brand_assets.py --png', font=font(22, 'Regular'), fill=MUTED)
x = 36
for im, lab in zip(icons, labels):
    d.text((x, 150), lab, font=font(22), fill=INK)
    out.paste(im, (x, 196), im)
    x += im.width + 36
save(out, 'production_web_icons.png')
