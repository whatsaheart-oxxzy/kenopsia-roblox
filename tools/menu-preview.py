#!/usr/bin/env python3
"""Composite a 1280x720 mock of the MAIN MENU from the generated assets.

Not shipped -- this is the design proof. It uses the same sizes, positions and
tints the Luau will use, so what this renders is what the screen renders.
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "..", "docs", "assets")
OUT = os.path.join(HERE, "..", "docs", "assets", "menu_preview.png")

BG = (2, 6, 9)
PLATE = (6, 18, 26)
CYAN = (191, 233, 245)
CYAN_HI = (232, 251, 255)
CYAN_DIM = (78, 124, 138)
WHITE = (255, 255, 255)
INK = (4, 18, 26)
ACCENT = (111, 216, 240)

VW, VH = 1280, 720
SCALE = VH / 710.0  # MachineLayout's authored-height scale at 720p


def tint(path, colour, alpha):
    img = Image.open(path).convert("RGBA")
    solid = Image.new("RGBA", img.size, colour + (255,))
    solid.putalpha(img.getchannel("A").point(lambda v: int(v * alpha)))
    return solid


def tile(src, size, tilepx):
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    t = src.resize((tilepx, tilepx), Image.NEAREST)
    for y in range(0, size[1], tilepx):
        for x in range(0, size[0], tilepx):
            out.alpha_composite(t, (x, y))
    return out


def font(px):
    for name in ("consola.ttf", "cour.ttf"):
        try:
            return ImageFont.truetype("C:/Windows/Fonts/" + name, px)
        except OSError:
            continue
    return ImageFont.load_default()


def spaced(s):
    return " ".join(s)


def main():
    cv = Image.new("RGBA", (VW, VH), BG + (255,))

    # --- 3D diorama stand-in (the real one is built from parts in Luau) ------
    dio = Image.new("RGBA", (VW, VH), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dio)
    dd.rectangle([0, VH * 0.62, VW, VH], fill=(9, 20, 26, 255))          # ground
    dd.rectangle([0, VH * 0.30, VW, VH * 0.62], fill=(5, 12, 17, 255))   # back wall
    for i in range(9):                                                    # fence
        x = VW * 0.52 + i * 46
        dd.rectangle([x, VH * 0.44, x + 4, VH * 0.63], fill=(16, 34, 42, 255))
    dd.rectangle([VW * 0.52, VH * 0.46, VW, VH * 0.465], fill=(16, 34, 42, 255))
    dd.rectangle([VW * 0.70, VH * 0.30, VW * 0.86, VH * 0.62], fill=(7, 16, 22, 255))  # gate
    dd.rectangle([VW * 0.76, VH * 0.33, VW * 0.80, VH * 0.35], fill=(150, 235, 255, 255))  # lamp
    dd.ellipse([VW * 0.70, VH * 0.27, VW * 0.86, VH * 0.45], fill=(30, 70, 88, 90))
    for i, c in enumerate([(0.60, 0.55), (0.66, 0.57), (0.63, 0.52)]):    # crates
        dd.rectangle([VW * c[0], VH * c[1], VW * c[0] + 44, VH * c[1] + 40], fill=(13, 28, 35, 255))
    cv.alpha_composite(dio)

    # --- plates -------------------------------------------------------------
    cv.alpha_composite(tile(Image.open(os.path.join(A, "menu_rain_256.png")).convert("RGBA"),
                            (VW, VH), 256).point(lambda v: v) if False else
                       tile(tint(os.path.join(A, "menu_rain_256.png"), ACCENT, 0.12), (VW, VH), 256))
    cv.alpha_composite(tile(tint(os.path.join(A, "menu_dots_128.png"), ACCENT, 0.18), (VW, VH), 128))

    shards = tint(os.path.join(A, "menu_shards_512.png"), CYAN_HI, 0.22)
    shards = shards.resize((int(VW * 0.68), int(VH * 0.95)), Image.NEAREST)
    cv.alpha_composite(shards, (int(VW * 0.36), int(VH * 0.05)))

    # --- vignette -----------------------------------------------------------
    vg = Image.new("RGBA", (VW, VH), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vg)
    for i in range(int(VH * 0.16)):
        a = int(150 * (1 - i / (VH * 0.16)))
        vd.rectangle([0, i, VW, i], fill=(0, 0, 0, a))
        vd.rectangle([0, VH - 1 - i, VW, VH - 1 - i], fill=(0, 0, 0, a))
    for i in range(int(VW * 0.10)):
        a = int(150 * (1 - i / (VW * 0.10)))
        vd.rectangle([i, 0, i, VH], fill=(0, 0, 0, a))
        vd.rectangle([VW - 1 - i, 0, VW - 1 - i, VH], fill=(0, 0, 0, a))
    cv.alpha_composite(vg)

    d = ImageDraw.Draw(cv)

    # --- title --------------------------------------------------------------
    _wm = Image.open(os.path.join(A, "menu_wordmark_512.png"))
    tw = int(560 * SCALE)
    th = int(tw * _wm.size[1] / _wm.size[0])  # never distort the mark
    wm = tint(os.path.join(A, "menu_wordmark_512.png"), CYAN_HI, 1.0).resize((tw, th), Image.NEAREST)
    tx, ty = int(64 * SCALE), int(96 * SCALE)
    cv.alpha_composite(tint(os.path.join(A, "menu_wordmark_512.png"), (255, 60, 60), 0.35)
                       .resize((tw, th), Image.NEAREST), (tx + 3, ty))
    cv.alpha_composite(tint(os.path.join(A, "menu_wordmark_512.png"), ACCENT, 0.35)
                       .resize((tw, th), Image.NEAREST), (tx - 3, ty))
    cv.alpha_composite(wm, (tx, ty))
    d.text((tx + 4, ty + th + 8), "SUBJECT ORIENTATION TERMINAL // REV 2.4",
           font=font(int(13 * SCALE)), fill=CYAN_DIM)

    # --- rows ---------------------------------------------------------------
    rows = ["ENTER FACILITY", "BRIEFING", "SETTINGS", "PERSONNEL FILE"]
    rx, ry = int(72 * SCALE), int(300 * SCALE)
    rh, gap = int(40 * SCALE), int(10 * SCALE)
    sel = 0
    st = tint(os.path.join(A, "menu_streak_256.png"), WHITE, 1.0)
    sh = int(rh * 1.15)  # overhangs the row so the torn edges show
    st = st.resize((int(470 * SCALE), sh), Image.NEAREST)
    cv.alpha_composite(st, (rx - int(22 * SCALE), ry + sel * (rh + gap) - (sh - rh) // 2))
    f = font(int(26 * SCALE))
    for i, label in enumerate(rows):
        y = ry + i * (rh + gap)
        if i == sel:
            d.rectangle([rx, y + rh / 2 - 4, rx + 8, y + rh / 2 + 4], fill=INK)
            d.text((rx + int(34 * SCALE), y + rh / 2), spaced(label), font=f, fill=INK, anchor="lm")
        else:
            d.text((rx + int(34 * SCALE), y + rh / 2), spaced(label), font=f,
                   fill=tuple(int(c * 0.72) for c in CYAN), anchor="lm")

    # --- detail card (right column) ----------------------------------------
    # Fills the right half the way the reference's debris does, and tells the
    # player what the highlighted entry actually is.
    dx0, dy0 = int(VW * 0.60), int(300 * SCALE)
    dw, dh = int(VW * 0.30), int(190 * SCALE)
    d.rectangle([dx0, dy0, dx0 + dw, dy0 + dh], fill=(6, 18, 26, 210), outline=CYAN_DIM)
    for k in range(0, dw, 10):
        d.rectangle([dx0 + k, dy0 - 6, dx0 + k + 4, dy0 - 2], fill=ACCENT)  # serration
    d.text((dx0 + 14, dy0 + 14), "/ / ENTER FACILITY", font=font(int(15 * SCALE)), fill=CYAN_HI)
    body = ["JOIN THE ACTIVE CYCLE.", "THE MACHINE PICKS THE", "SIMULATION, NOT YOU.", "",
            "SUBJECTS REQUIRED   2"]
    for i, line in enumerate(body):
        d.text((dx0 + 14, dy0 + int(48 * SCALE) + i * int(22 * SCALE)), line,
               font=font(int(13 * SCALE)), fill=CYAN if i < 3 else CYAN_DIM)

    # --- status cells (bottom left) ----------------------------------------
    cells = [("SUBJECTS", "2 / 4"), ("NEXT CYCLE", "ARMED"), ("SESSION", "00:04:12")]
    cw, ch = int(112 * SCALE), int(38 * SCALE)
    cy = VH - int(78 * SCALE)
    for i, (a, b) in enumerate(cells):
        cx = int(64 * SCALE) + i * (cw + int(10 * SCALE))
        d.rectangle([cx, cy, cx + cw, cy + ch], fill=PLATE, outline=CYAN_DIM)
        d.text((cx + 7, cy + 5), a, font=font(int(11 * SCALE)), fill=ACCENT)
        d.text((cx + 7, cy + 5 + int(15 * SCALE)), b, font=font(int(11 * SCALE)), fill=CYAN_DIM)

    # --- hint bar -----------------------------------------------------------
    hf = font(int(13 * SCALE))
    hint = "[W/S] NAVIGATE     [E] SELECT"
    d.text((VW / 2, VH - int(22 * SCALE)), hint, font=hf, fill=CYAN_DIM, anchor="mm")

    # --- build tag + corner ticks ------------------------------------------
    d.text((VW - int(64 * SCALE), int(34 * SCALE)), "BUILD 2026.08.25",
           font=font(int(11 * SCALE)), fill=CYAN_DIM, anchor="rm")
    t, L = int(28 * SCALE), int(14 * SCALE)
    for cx, cy2, sx, sy in ((t, t, 1, 1), (VW - t, t, -1, 1), (t, VH - t, 1, -1), (VW - t, VH - t, -1, -1)):
        d.rectangle([min(cx, cx + sx * L), cy2, max(cx, cx + sx * L), cy2 + 2], fill=CYAN_DIM)
        d.rectangle([cx, min(cy2, cy2 + sy * L), cx + 2, max(cy2, cy2 + sy * L)], fill=CYAN_DIM)

    # --- scanlines ----------------------------------------------------------
    sl = Image.new("RGBA", (VW, VH), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sl)
    for y in range(0, VH, 4):
        sd.rectangle([0, y, VW, y + 1], fill=(0, 0, 0, 60))
    cv.alpha_composite(sl)

    cv.convert("RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
