"""Compose the Phase 5 production review images from real-Chrome screenshots.

python3 compose_phase5.py <shots dir> <out dir> <mobile/assets/fonts/poppins>
Screenshots come from flow.sh / matrix.sh: the production web build from its
real entry point (main.dart): Splash > Onboarding > Consent > Home, then
Profile > Review data and consent preferences. "before" shots come from a
build of the Phase 4 checkpoint commit.
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

save(sheet([(S('bsplash412_splash_1'), 'Before: Splash'), (S('splash412_splash_1'), 'After: Splash'),
            (S('before412_onboarding_1'), 'Before: Onboarding'), (S('after412_onboarding_1'), 'After: Onboarding'),
            (S('before412_consent_default'), 'Before: Consent'), (S('after412_consent_default'), 'After: Consent')],
           6, 'Phase 5: Splash, Onboarding and Consent at 412 px',
           'Real production build in Chrome. Before: Phase 4 checkpoint. After: Living Landscapes.',
           300, max_h=1600), 'before_after_412.png')

save(sheet([(S('after412_onboarding_1'), 'Step 1 of 3'), (S('after412_onboarding_2'), 'Step 2 of 3'),
            (S('after412_onboarding_3'), 'Step 3 of 3: Get Started')],
           3, 'Onboarding steps at 412 px', 'Each step keeps "In this prototype" apart from "Planned".',
           380, max_h=1400), 'onboarding_steps_412.png')

save(sheet([(S('after412_consent_default'), 'Consent: defaults (all off)'),
            (S('after412_consent_changed'), 'Consent: Journal and Voice turned on'),
            (S('after412_consent_review'), 'Profile > review: "Done" returns')],
           3, 'Consent at 412 px', 'Choices are kept in memory only; the wording of every choice is unchanged.',
           380, max_h=1700), 'consent_states_412.png')

save(sheet([(S('d1280_onboarding_1'), 'Onboarding, 1280 px'),
            (S('d1280_consent_default'), 'Consent, 1280 px'),
            (S('d1280_consent_changed'), 'Consent with changes, 1280 px')],
           3, 'Desktop, 1280 px', 'Real production build in Chrome.', 640), 'phase5_desktop_1280.png')

for k, t in (('onboarding', 'Onboarding'), ('consent', 'Consent')):
    items = []
    for w in (320, 360, 412):
        for ts, lab in (('1', '1x'), ('2', '2x')):
            items.append((S(f'm_{w}_t{ts}_{k}'), f'{w} px, text {lab}'))
    for w in (768, 1024, 1280, 1440):
        items.append((S(f'm_{w}_t1_{k}'), f'{w} px'))
    save(sheet(items, 5, f'{t}: every width', 'Real Chrome, production build; 1.5x runs are in the QA logs.',
               300, max_h=1200), f'responsive_{k}.png')
