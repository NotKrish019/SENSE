"""Compose the Phase 4 production review images from real-Chrome screenshots.

python3 compose_phase4.py <shots dir> <out dir> <mobile/assets/fonts/poppins>
Screenshots come from flow.sh / matrix.sh: the production web build driven
through the real entry flow (Splash > Onboarding > Consent > Home) and the
Home "Ways to reflect" rows. "before" shots come from a build of the Phase 3
checkpoint commit.
"""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont

SH, OUT, FONT = (pathlib.Path(a) for a in sys.argv[1:4])
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
        im = Image.open(src)
        im = trim(im) if im.height > 2 * im.width else im
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


S = lambda n: SH / f'{n}.png'
names = [('voice', 'Voice'), ('activity', 'Activity')]

save(sheet([(S('before412_voice'), 'Before: Voice (demo recorder)'), (S('after412_voice'), 'After: Voice'),
            (S('before412_activity'), 'Before: Activity'), (S('after412_activity'), 'After: Activity')],
           4, 'Phase 4: Voice and Activity at 412 px',
           'Real production build in Chrome. Before: Phase 3 checkpoint. After: Living Landscapes.',
           400, max_h=1500), 'before_after_412.png')

save(sheet([(S('short412_voice_consent'), 'Voice: consent link opens preferences'),
            (S('short412_activity_saved'), 'Activity: Save says not saved')],
           2, 'Interaction states at 412 px', 'Phone-height window (915 px).', 420),
     'states_412.png')

save(sheet([(S('d1280_voice'), 'Voice'), (S('d1280_activity'), 'Activity')],
           2, 'Desktop, 1280 px', 'Each page floats over its own landscape.', 900), 'phase4_desktop_1280.png')

for k, t in names:
    items = []
    for w in (320, 360, 412):
        for ts, lab in (('1', '1x'), ('2', '2x')):
            items.append((S(f'm_{w}_t{ts}_{k}'), f'{w} px, text {lab}'))
    for w in (768, 1024, 1280, 1440):
        items.append((S(f'm_{w}_t1_{k}'), f'{w} px'))
    save(sheet(items, 5, f'{t}: every width', 'Real Chrome, production build; 1.5x runs are in the QA logs.',
               300, max_h=1200), f'responsive_{k}.png')
