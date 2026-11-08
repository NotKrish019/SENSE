"""Compose the Phase 2 production review images from real-Chrome screenshots.

python3 compose_phase2.py <shots dir> <out dir> <mobile/assets/fonts/poppins> <mobile/web>
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



save(sheet([(SH / 'before_412_insights.png', 'Before: Insights'), (SH / 'after_412_insights.png', 'After: Insights'),
            (SH / 'before_412_detail.png', 'Before: Insight detail'), (SH / 'after_412_detail.png', 'After: Insight detail')], 4,
           'Phase 2 before and after (412 px): Insights and Insight detail',
           'Real production builds before and after Phase 2, entered through Splash > Onboarding > Consent.', 460, max_h=2200),
     'before_after_insights_412.png')

save(sheet([(SH / 'before_412_profile.png', 'Before: Profile & settings'), (SH / 'after_412_profile.png', 'After: Profile & settings'),
            (SH / 'before_412_export.png', 'Before: Export dialog'), (SH / 'after_412_export.png', 'After: Export dialog')], 4,
           'Phase 2 before and after (412 px): Profile and the honest Export message',
           'Same content and behaviour; Living Landscapes layout, index rows, forest logo and paper dialog.', 460, max_h=2200),
     'before_after_profile_412.png')

save(sheet([(SH / 'm_1280_t1_insights.png', 'Desktop 1280 px: Insights'),
            (SH / 'm_1280_t1_detail.png', 'Desktop 1280 px: Insight detail'),
            (SH / 'm_1440_t1_profile.png', 'Desktop 1440 px: Profile & settings'),
            (SH / 'm_1024_t1_insights.png', 'Desktop 1024 px: Insights')], 2,
           'Phase 2 on desktop', 'Top navigation; meadow scene spans the window; floating editorial sheet (Insights up to 880 px).', 900),
     'phase2_desktop.png')

save(sheet([(SH / 'm_768_t1_insights.png', 'Tablet 768 px: Insights'), (SH / 'm_768_t1_detail.png', 'Insight detail'),
            (SH / 'm_768_t1_profile.png', 'Profile & settings')], 3,
           'Phase 2 on tablet', 'Bottom navigation; reading column capped and centred.', 520, max_h=1400),
     'phase2_tablet_768.png')

for screen, label in [('insights', 'Insights'), ('detail', 'Insight detail'), ('profile', 'Profile & settings')]:
    items = [(SH / f'm_{w}_t{t}_{screen}.png', f'{w} px, {t}x text')
             for w in [320, 360, 412, 768, 1024, 1280, 1440] for t in [1, 2]]
    save(sheet(items, 7, f'{label} at every width, normal and 2x text',
               'Real Chrome, browser text size doubled for 2x. No horizontal overflow in any run.', 300,
               label_h=48, max_h=1700), f'responsive_{screen}.png')
