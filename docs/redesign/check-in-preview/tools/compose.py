"""Compose the check-in prototype review images from browser screenshots."""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont

SH = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2]); OUT.mkdir(parents=True, exist_ok=True)
FONT = sys.argv[3]
BG = (243, 235, 221)
INK = (41, 58, 53)
MUTED = (90, 104, 95)


def font(size, weight="Medium"):
    return ImageFont.truetype(f"{FONT}/Poppins-{weight}.ttf", size)


def trim(im, keep=48):
    """Cut empty page below the content: keep up to the last row with ink."""
    g = im.convert("L")
    w, h = g.size
    for y in range(h - 1, 0, -3):
        if min(g.getpixel((x, y)) for x in range(8, w - 8, 3)) < 160:
            return im.crop((0, 0, w, min(h, y + keep)))
    return im


def sheet(items, cols, title, sub, width_each, pad=36, label_h=64):
    ims = []
    for path, label in items:
        im = trim(Image.open(path)) if isinstance(path, (str, pathlib.Path)) else path
        s = width_each / im.width
        ims.append((im.resize((width_each, int(im.height * s)), Image.LANCZOS), label))
    rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]
    head = 150
    H = head + sum(max(i.height for i, _ in r) + label_h + pad for r in rows) + pad
    W = pad + cols * (width_each + pad)
    out = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(out)
    d.text((pad, 34), title, font=font(40), fill=INK)
    d.text((pad, 90), sub, font=font(22, "Regular"), fill=MUTED)
    y = head
    for r in rows:
        x = pad
        for im, label in r:
            d.text((x, y + 14), label, font=font(24), fill=INK)
            out.paste(im, (x, y + label_h))
            d.rectangle((x - 1, y + label_h - 1, x + im.width, y + label_h + im.height), outline=(216, 204, 182))
            x += width_each + pad
        y += max(i.height for i, _ in r) + label_h + pad
    return out


def save(im, name):
    im.save(OUT / name, optimize=True)
    print("wrote", name, im.size)


save(sheet([(SH / "before_360_step1.png", "Before: production, step 1"),
            (SH / "w360_t1_step1.png", "After: prototype, step 1"),
            (SH / "before_360_step2.png", "Before: production, step 2"),
            (SH / "w360_t1_step2.png", "After: prototype, step 2")], 4,
           "Check-in: before and after (360 px phone)",
           "Same questions, values, scales, defaults and step sequence. Emoji replaced by the approved symbols.", 520),
     "before_after_360.png")

save(sheet([(SH / "w360_t1_step1.png", "Step 1: mood, motivation"),
            (SH / "w360_t1_step2.png", "Step 2: perceived stress"),
            (SH / "w360_t1_done.png", "Finished: not saved")], 3,
           "Living Landscapes check-in, mobile (360 px)",
           "Real Chrome, bundled Poppins. Good was selected on step 1 before continuing.", 560),
     "mobile_360_flow.png")

save(sheet([(SH / "w320_t1_step1.png", "320 px: ordered list"),
            (SH / "w360_t1_step1.png", "360 px: five across"),
            (SH / "w412_t1_step1.png", "412 px: five across"),
            (SH / "w360_t2_step1.png", "360 px at 2x text: list")], 4,
           "Mood scale at phone widths",
           "Five across whenever every word fits whole; otherwise an ordered list, never a broken grid.", 480),
     "mobile_widths_and_large_text.png")

for name, src in [("tablet_768_step1.png", "w768_t1_step1.png"),
                  ("desktop_1024_step2.png", "w1024_t1_step2.png"),
                  ("desktop_1280_step1.png", "w1280_t1_step1.png"),
                  ("desktop_1440_step1.png", "w1440_t1_step1.png"),
                  ("desktop_1280_done.png", "w1280_t1_done.png")]:
    save(trim(Image.open(SH / src)), name)

labels = ["Very Low", "Low", "Neutral", "Good", "Great"]
crops = [(Image.open(SH / f"sel{v}.png").crop((0, 740, 824, 1090)), f"{labels[v - 1]} selected (value {v})")
         for v in range(1, 6)]
crops.append((Image.open(SH / "kb_great_focused_unselected.png").crop((0, 740, 824, 1090)),
              "Keyboard focus on Great, not selected"))
crops.append((Image.open(SH / "kb_great_focused_selected.png").crop((0, 740, 824, 1090)),
              "Great focused and selected (Enter)"))
save(sheet(crops, 2, "Selected, unselected and focused states (412 px, real Chrome)",
           "Selected: thicker forest outline, check, paper and ochre print, heavier label. Focus ring 4 px outside.", 640),
     "states_selected_unselected_focus.png")

items = []
for w in [320, 360, 412, 768, 1024, 1280, 1440]:
    for t in [1, 2]:
        items.append((SH / f"w{w}_t{t}_step1.png", f"{w} px, text {t}x"))
save(sheet(items, 7, "Responsive check: step 1 at every width, normal and 2x text",
           "Real Chrome with the browser text size doubled for 2x. No horizontal overflow in any run.", 300,
           label_h=50),
     "responsive_matrix.png")
