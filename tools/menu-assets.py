#!/usr/bin/env python3
"""Generate the five MAIN MENU image assets.

All five are WHITE ON TRANSPARENT so the client tints them with ImageColor3
(the same way the grunge wash and the grid tiles are tinted), and all five are
authored SMALL and magnified on screen -- with ResamplerMode.Pixelated a
magnified low-res source gives hard pixel edges (the PS1 look), while a
minified one just aliases.

The KENOPSIA wordmark is drawn from geometry defined in this file: rectangles
and perpendicular-offset parallelograms in a 100 x 140 per-letter box. No font
file is read, embedded or shipped -- the letterforms are original work, which
keeps docs/assets/ASSET-LEDGER.md clean (a release gate).

Output: docs/assets/menu_*.png
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "assets")
SEED = 20260825

# ---------------------------------------------------------------- helpers ---


def thick(p0, p1, w):
    """Parallelogram of width w around the segment p0->p1, with SQUARE ends.

    PIL's line caps are blunt and inconsistent at large widths; offsetting the
    segment perpendicular by w/2 and returning the quad gives exact flat
    terminals, which is what a heavy grotesque needs.
    """
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    if length == 0:
        return []
    nx, ny = -dy / length * w / 2, dx / length * w / 2
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


# Per-letter geometry in a 100 wide x 140 tall box. S = stroke weight.
S = 26
H = 140
W = 100


def _rect(x, y, w, h):
    return ("rect", (x, y, x + w, y + h))


def _poly(pts):
    return ("poly", pts)


def _cut(x, y, w, h):
    """A hole punched out of the letter after everything else is drawn."""
    return ("cut", (x, y, x + w, y + h))


LETTERS = {
    "K": [
        _rect(0, 0, S, H),
        _poly(thick((18, 72), (100, 4), S)),
        _poly(thick((18, 68), (100, 136), S)),
    ],
    "E": [
        _rect(0, 0, S, H),
        _rect(0, 0, 88, S),
        _rect(0, 57, 74, S),
        _rect(0, H - S, 88, S),
    ],
    "N": [
        _rect(0, 0, S, H),
        _rect(W - S, 0, S, H),
        _poly([(S, 0), (W - S, 88), (W - S, H), (S, 52)]),
    ],
    # A rectangular ring with two chamfered corners -- industrial, not round.
    "O": [
        _rect(0, 0, W, S),
        _rect(0, H - S, W, S),
        _rect(0, 0, S, H),
        _rect(W - S, 0, S, H),
        _cut(-4, -4, 14, 14),
        _cut(W - 10, H - 10, 14, 14),
    ],
    "P": [
        _rect(0, 0, S, H),
        _rect(0, 0, 78, S),
        _rect(W - S - 4, 0, S, 76),
        _rect(0, 76 - S, 78, S),
    ],
    "S": [
        _rect(0, 0, W, S),
        _rect(0, S, S, 57 - S + S),
        _rect(0, 57, W, S),
        _rect(W - S, 83, S, H - S - 83),
        _rect(0, H - S, W, S),
    ],
    # Drawn at x=0: its advance box is only S wide, so centring it inside the
    # full 100-unit box would push it into the next letter and leave a hole
    # before it ("KENOPS  IA").
    "I": [
        _rect(0, 0, S, H),
    ],
    # Inset legs: at full spread the left leg bled past x=0 and collided with
    # the preceding I, so "IA" fused into one glyph.
    "A": [
        _poly(thick((52, 4), (20, H), S)),
        _poly(thick((52, 4), (84, H), S)),
        _rect(24, 90, 54, 22),
    ],
}

# Per-letter ink width. `I` is a single stem and must not reserve a full box,
# or the word gets a hole in the middle; everything else is full width.
INK_W = {"K": 100, "E": 88, "N": 100, "O": 100, "P": 100, "S": 100, "I": 26, "A": 100}
GAP = 13  # tight, condensed -- but the stems must never touch


def draw_word(word, scale):
    """Render `word` at `scale` px per geometry unit; returns an L-mode mask."""
    pad = 8 * scale
    advances = [INK_W[c] + GAP for c in word]
    span = sum(advances) - GAP
    img = Image.new("L", (int(span * scale + 2 * pad), int(H * scale + 2 * pad)), 0)
    d = ImageDraw.Draw(img)
    cuts = []
    ox = pad
    for i, ch in enumerate(word):
        oy = pad
        for kind, data in LETTERS[ch]:
            if kind == "rect":
                x0, y0, x1, y1 = data
                d.rectangle([ox + x0 * scale, oy + y0 * scale, ox + x1 * scale, oy + y1 * scale], fill=255)
            elif kind == "poly":
                d.polygon([(ox + x * scale, oy + y * scale) for x, y in data], fill=255)
            else:
                x0, y0, x1, y1 = data
                cuts.append([ox + x0 * scale, oy + y0 * scale, ox + x1 * scale, oy + y1 * scale])
        ox += advances[i] * scale
    for c in cuts:
        d.rectangle(c, fill=0)
    return img


def distress(mask, rng, blotches=42, tears=4, kills=1):
    """Erode the mark: soft blotches eaten out, horizontal tear offsets, and a
    couple of 1-2 px scan cuts. This is what turns clean geometry into
    something that looks stamped on failing hardware."""
    w, h = mask.size
    eat = Image.new("L", (w, h), 0)
    ed = ImageDraw.Draw(eat)
    for _ in range(blotches):
        cx, cy = rng.randrange(w), rng.randrange(h)
        r = rng.randint(3, 16)
        ed.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rng.randint(120, 255))
    eat = eat.filter(ImageFilter.GaussianBlur(3))
    out = Image.new("L", (w, h), 0)
    op, ep = mask.load(), eat.load()
    o = out.load()
    for y in range(h):
        for x in range(w):
            v = op[x, y]
            if v:
                e = ep[x, y]
                o[x, y] = 0 if e > 228 else v
    # horizontal tears: whole bands displaced sideways
    for _ in range(tears):
        y0 = rng.randrange(h)
        band = rng.randint(3, 9)
        dx = rng.choice([-3, -2, 2, 3])
        region = out.crop((0, y0, w, min(h, y0 + band)))
        out.paste(0, (0, y0, w, min(h, y0 + band)))
        out.paste(region, (dx, y0))
    # dead scanlines straight through the mark
    for _ in range(kills):
        y0 = rng.randrange(h)
        ImageDraw.Draw(out).rectangle([0, y0, w, y0 + rng.randint(0, 1)], fill=0)
    return out


def to_white_rgba(mask):
    """White pixels, alpha from the mask."""
    rgba = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    rgba.putalpha(mask)
    return rgba


def crunch(rgba, size):
    """Downsample to the authored (small) size, then harden the alpha ramp so
    the magnified result has crisp blocky edges instead of a soft halo."""
    small = rgba.resize(size, Image.LANCZOS)
    a = small.getchannel("A").point(lambda v: 0 if v < 96 else (168 if v < 176 else 255))
    small.putalpha(a)
    small = small.convert("RGBA")
    px = small.load()
    for y in range(size[1]):
        for x in range(size[0]):
            r, g, b, al = px[x, y]
            px[x, y] = (255, 255, 255, al)
    return small


# ------------------------------------------------------------- the assets ---


def wordmark(path, out_w=512):
    rng = random.Random(SEED)
    mask = draw_word("KENOPSIA", scale=4)
    mask = distress(mask, rng)
    out_h = int(round(out_w * mask.size[1] / mask.size[0]))
    img = crunch(to_white_rgba(mask), (out_w, out_h))
    img.save(path)
    return img.size


def streak(path):
    """The selection bar: a SOLID white slab that fills the row, with jagged
    torn ends, diagonal shard cuts and overshoot lines running past both ends.
    The single most important shape in the menu -- it has to read as light
    burning through the panel, not as a scratch."""
    rng = random.Random(SEED + 1)
    w, h = 1024, 128
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    mid = h / 2
    full = h * 0.40  # half-height of the solid body

    def taper(t):
        """1 across the body, stepping down to 0 at the ends. ASYMMETRIC (the
        left end runs out over a long tail, the right end is nearly chopped) so
        the bar never reads as a capsule, and STEPPED so the ends look torn off
        rather than airbrushed."""
        run = 0.13 if t < 0.5 else 0.055
        edge = min(t, 1 - t)
        if edge > run:
            return 1.0
        steps = 3  # few, chunky steps -- a blocky break, not a point
        return math.floor((edge / run) * steps) / steps

    for x in range(w):
        t = x / (w - 1)
        k = taper(t)
        if k <= 0:
            continue
        # slow undulation so the body is not a perfect rectangle
        wave = 0.86 + 0.14 * math.sin(t * 7.5 + 1.1)
        jag = rng.choice([0, 0, 0, 2, 3, -2, -3]) if rng.random() < 0.30 else 0
        half = full * k * wave + jag
        if half <= 0:
            continue
        v = 255 if k >= 1.0 else int(150 + 105 * k)
        d.rectangle([x, mid - half, x, mid + half], fill=v)
    # Diagonal shard cuts, kept OUT of the label zone. The row's text sits over
    # roughly t = 0.10 .. 0.88 of the bar; a cut crossing that zone reads as a
    # slash through the letters and the entry stops being readable (measured on
    # the first proof). So the cuts live in the head and the tail only.
    for i in range(4):
        if i < 2:
            cx = rng.randrange(int(w * 0.89), int(w * 0.99))
        else:
            cx = rng.randrange(int(w * 0.01), int(w * 0.08))
        wid = rng.randint(6, 14)
        lean = rng.choice([-58, -44, 44, 58])
        d.polygon(thick((cx, -20), (cx + lean, h + 20), wid), fill=0)
    # sparks riding just off the body
    for _ in range(5):
        y = mid + rng.choice([-1, 1]) * rng.randint(int(full * 1.05), int(full * 1.35))
        x0 = rng.randrange(int(w * 0.1), int(w * 0.85))
        d.rectangle([x0, y, x0 + rng.randint(10, 70), y + rng.randint(1, 2)], fill=rng.randint(180, 255))
    # a bright hairline riding the centre, and overshoots past both ends
    d.rectangle([int(w * 0.06), mid - 1, int(w * 0.94), mid + 1], fill=255)
    for _ in range(4):
        y = mid + rng.choice([-1, 1]) * rng.randint(int(full * 1.1), int(full * 1.6))
        x0 = rng.randrange(-60, 40)
        x1 = rng.randrange(w - 40, w + 60)
        d.rectangle([x0, y, x1, y + rng.randint(1, 2)], fill=rng.randint(150, 235))
    out = crunch(to_white_rgba(img), (256, 32))
    out.save(path)
    return out.size


def shards(path):
    """The debris layer: long diagonal light streaks with a glow edge, the
    black-and-white shard plate rebuilt as a tintable alpha sheet."""
    rng = random.Random(SEED + 2)
    w, h = 2048, 1536
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    # one shared diagonal direction, like the reference plate
    ang = math.radians(-24)
    dx, dy = math.cos(ang), math.sin(ang)
    for _ in range(90):
        cx = rng.randrange(-int(w * 0.3), int(w * 1.2))
        cy = rng.randrange(-int(h * 0.2), int(h * 1.2))
        length = rng.randint(240, 1500)
        width = rng.choice([2, 2, 3, 4, 6, 9, 14])
        v = rng.randint(70, 255)
        p0 = (cx - dx * length / 2, cy - dy * length / 2)
        p1 = (cx + dx * length / 2, cy + dy * length / 2)
        d.polygon(thick(p0, p1, width), fill=v)
    glow = img.filter(ImageFilter.GaussianBlur(14)).point(lambda v: min(255, int(v * 1.5)))
    img = Image.composite(img, glow, img.point(lambda v: 255 if v > 40 else 0))
    # fade toward the top-left so the streaks read as coming from one corner
    fade = Image.new("L", (w, h), 0)
    fp = fade.load()
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            t = ((x / w) * 0.65 + (y / h) * 0.35)
            v = int(255 * max(0.0, min(1.0, t * 1.35)))
            for yy in range(y, min(h, y + 4)):
                for xx in range(x, min(w, x + 4)):
                    fp[xx, yy] = v
    img = Image.composite(img, Image.new("L", (w, h), 0), fade)
    out = to_white_rgba(img.resize((512, 384), Image.LANCZOS))
    out.save(path)
    return out.size


def rain(path):
    """The rain-on-glass / static plate, TILEABLE at 256: droplet points and
    horizontal smears. Wrapped writes keep the seams invisible."""
    rng = random.Random(SEED + 3)
    n = 256
    img = Image.new("L", (n, n), 0)
    p = img.load()

    def put(x, y, v):
        p[x % n, y % n] = max(p[x % n, y % n], v)

    for _ in range(2600):  # droplets
        x, y = rng.randrange(n), rng.randrange(n)
        v = rng.randint(60, 255)
        put(x, y, v)
        if rng.random() < 0.35:
            put(x + 1, y, int(v * 0.7))
        if rng.random() < 0.2:
            put(x, y + 1, int(v * 0.6))
    for _ in range(150):  # horizontal smears
        y = rng.randrange(n)
        x0 = rng.randrange(n)
        length = rng.randint(6, 60)
        v = rng.randint(40, 170)
        for i in range(length):
            put(x0 + i, y, int(v * (1 - i / length)))
    for _ in range(14):  # bright runs, the blown-out streaks of the plate
        y = rng.randrange(n)
        v = rng.randint(150, 240)
        for x in range(n):
            put(x, y, int(v * (0.4 + 0.6 * abs(math.sin(x / 19.0)))))
    img = img.point(lambda v: int(v * 0.85))
    to_white_rgba(img).save(path)
    return img.size


def dots(path):
    """The dot matrix behind everything: 2x2 dots every 16 px, tileable at 128,
    with a slightly brighter dot every fourth crossing (the reference's
    coarse-over-fine grid)."""
    n, step = 128, 16
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for gy in range(0, n, step):
        for gx in range(0, n, step):
            major = (gx // step) % 4 == 0 and (gy // step) % 4 == 0
            d.rectangle([gx, gy, gx + 1, gy + 1], fill=200 if major else 110)
    to_white_rgba(img).save(path)
    return img.size


def background(path):
    """The menu's background PLATE: a cold facility corridor.

    Unlike the other four this one is opaque and in colour -- it replaces the
    live 3D view behind the landing, so it carries the whole mood on its own.
    Authored at 960x540 and shown with ScaleType.Crop + Pixelated: exactly 2x
    at 1080p, which keeps the grain crisp and blocky instead of resampled to
    mush.
    """
    rng = random.Random(SEED + 4)
    W_, H_ = 960, 540
    horizon = int(H_ * 0.56)
    img = Image.new("RGB", (W_, H_), (4, 9, 13))
    d = ImageDraw.Draw(img)

    # --- back wall: vertical concrete panels with seams -----------------------
    panel = 38
    for x in range(-panel, W_ + panel, panel):
        shade = rng.randint(16, 26)
        d.rectangle([x, 0, x + panel - 3, horizon], fill=(shade, shade + 7, shade + 12))
        d.rectangle([x + panel - 3, 0, x + panel, horizon], fill=(6, 11, 15))  # seam
    # horizontal courses, like the stage's stacked slabs
    for y in (int(horizon * 0.34), int(horizon * 0.67)):
        d.rectangle([0, y, W_, y + 3], fill=(8, 14, 19))

    # --- floor: brighter at the wall, falling away toward the viewer ---------
    for y in range(horizon, H_):
        t = (y - horizon) / max(1, H_ - horizon)
        v = int(30 * (1 - t) ** 1.6) + 6
        d.rectangle([0, y, W_, y], fill=(v, v + 5, v + 8))

    # Perspective. A flat gradient reads as a seam between two rectangles, not
    # as a room -- the depth has to be drawn. Slab joints fan out from a
    # vanishing point on the horizon, and the courses across them compress as
    # they recede, which is what actually sells the distance.
    vpx, vpy = int(W_ * 0.55), horizon
    for i in range(-9, 10):
        fx = vpx + i * int(W_ * 0.135)
        # extend each joint from the vanishing point out through the bottom edge
        ex = vpx + (fx - vpx) * 6
        d.line([(vpx, vpy), (ex, H_ + 40)], fill=(10, 17, 22), width=2)
    for k in range(1, 9):
        # geometric spacing: each course is closer to the last as depth grows
        y = horizon + int((H_ - horizon) * (k / 9.0) ** 2.1)
        d.rectangle([0, y, W_, y], fill=(11, 19, 24))
    # contact edge where the wall meets the floor, plus its shadow
    d.rectangle([0, horizon - 1, W_, horizon], fill=(46, 70, 82))
    for k in range(10):
        a = int(14 * (1 - k / 10.0))
        d.rectangle([0, horizon + 1 + k, W_, horizon + 1 + k], fill=(a, a + 3, a + 5))

    # --- two lamp washes on the wall + a pool on the floor -------------------
    glow = Image.new("RGB", (W_, H_), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for cx, cy, rx, ry, col in (
        (int(W_ * 0.66), int(horizon * 0.50), 230, 165, (66, 108, 126)),
        (int(W_ * 0.28), int(horizon * 0.62), 165, 120, (42, 70, 84)),
        (int(W_ * 0.62), horizon + 80, 330, 105, (52, 86, 102)),
    ):
        gd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=col)
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.blend(img, Image.blend(img, glow, 0.55), 1.0)

    # --- diagonal shafts from the upper right --------------------------------
    shaft = Image.new("L", (W_, H_), 0)
    sd = ImageDraw.Draw(shaft)
    ang = math.radians(-26)
    dx, dy = math.cos(ang), math.sin(ang)
    for _ in range(18):
        cx = rng.randrange(int(W_ * 0.2), int(W_ * 1.4))
        cy = rng.randrange(-120, H_)
        length = rng.randint(300, 900)
        width = rng.choice([2, 3, 5, 8, 13])
        p0 = (cx - dx * length / 2, cy - dy * length / 2)
        p1 = (cx + dx * length / 2, cy + dy * length / 2)
        sd.polygon(thick(p0, p1, width), fill=rng.randint(40, 130))
    shaft = shaft.filter(ImageFilter.GaussianBlur(3))
    img = Image.composite(Image.new("RGB", (W_, H_), (150, 200, 220)), img,
                          shaft.point(lambda v: int(v * 0.55)))

    # --- grain, scan banding, vignette ---------------------------------------
    px = img.load()
    for y in range(H_):
        band = -4 if (y % 4 < 2) else 0
        for x in range(W_):
            r, g, b = px[x, y]
            n = rng.randint(-9, 9) + band
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    vig = Image.new("L", (W_, H_), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-int(W_ * 0.22), -int(H_ * 0.30), int(W_ * 1.22), int(H_ * 1.30)], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(110))
    img = Image.composite(img, Image.new("RGB", (W_, H_), (2, 5, 8)), vig)

    img.save(path)
    return img.size


if __name__ == "__main__":
    jobs = [
        ("menu_wordmark_512.png", wordmark),
        ("menu_streak_256.png", streak),
        ("menu_shards_512.png", shards),
        ("menu_rain_256.png", rain),
        ("menu_dots_128.png", dots),
        ("menu_bg_960.png", background),
    ]
    for name, fn in jobs:
        path = os.path.join(OUT, name)
        size = fn(path)
        print("%-24s %sx%s  %6d bytes" % (name, size[0], size[1], os.path.getsize(path)))
