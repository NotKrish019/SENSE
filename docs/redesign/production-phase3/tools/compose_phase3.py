"""Compose the Phase 3 production review images from real-Chrome screenshots.

python3 compose_phase3.py <shots dir> <out dir> <mobile/assets/fonts/poppins>
Screenshots come from flow.sh / matrix.sh: the production web build driven
through the real entry flow (Splash > Onboarding > Consent > Home) and the
Home "Ways to reflect" rows. "before" shots come from a build of the last
commit (Phase 2 checkpoint).
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
names = [('journal', 'Journal'), ('sleep', 'Sleep'), ('workload', 'Workload')]

save(sheet([(S(f'before412_{k}'), f'Before: {t}') for k, t in names] +
           [(S(f'after412_{k}'), f'After: {t}') for k, t in names],
           3, 'Phase 3: Journal, Sleep and Workload at 412 px',
           'Real production build in Chrome. Top: last commit (Phase 2). Bottom: Living Landscapes.',
           420, max_h=1500), 'before_after_412.png')

save(sheet([(S('after412_journal'), 'Empty: Save, Clear disabled'),
            (S('after412_journal_text'), 'Writing: support shown'),
            (S('short412_journal_saved'), 'After Save (915 px tall)')],
           3, 'Journal states at 412 px',
           'Text typed in Chrome. The on-device phrase check shows support; Save says it was not saved.',
           420, max_h=1400),
     'journal_states_412.png')

save(sheet([(S('d1280_journal_text'), 'Journal'), (S('d1280_sleep'), 'Sleep'), (S('d1280_workload'), 'Workload')],
           3, 'Desktop, 1280 px', 'Each page floats over its own landscape.', 760), 'phase3_desktop_1280.png')

for k, t in names:
    items = []
    for w in (320, 360, 412):
        for ts, lab in (('1', '1x'), ('2', '2x')):
            items.append((S(f'm_{w}_t{ts}_{k}'), f'{w} px, text {lab}'))
    for w in (768, 1024, 1280, 1440):
        items.append((S(f'm_{w}_t1_{k}'), f'{w} px'))
    save(sheet(items, 5, f'{t}: every width', 'Real Chrome, production build; 1.5x runs are in the QA logs.',
               300, max_h=1200), f'responsive_{k}.png')
