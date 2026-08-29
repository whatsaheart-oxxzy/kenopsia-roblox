"""Blue-graded twin of KenopsiaSky_PS1 (E4 blue shift).

Reuses the exact face mapping + RGB555/Bayer4x4 pipeline from the 28.08 session
script (equirect_to_ps1_sky.py, session ca0bd56f), with a blue grade inserted
between equirect sampling and quantisation.
"""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\Asus\Documents\Retro\Brutal Skyboxes\Brutal Skyboxes\Textures\Skyboxes\skybox_plain_emx_13.png"
OUT = r"C:\Users\Asus\AppData\Local\Temp\claude\C--Users-Asus\f1db390b-d70d-48bf-923a-6f5fc6f10916\scratchpad\p1staging\sky"
SIZE = 256
LEVELS = 32          # RGB555: 32 levels per channel
DITHER = 1.0         # full-step ordered dither amplitude

# Verbatim from the 28.08 script (current KenopsiaSky_PS1 looks correct with it).
FACES = {
    "Rt": lambda u, v: (np.ones_like(u), -v, -u),
    "Lf": lambda u, v: (-np.ones_like(u), -v, u),
    "Up": lambda u, v: (u, np.ones_like(u), v),
    "Dn": lambda u, v: (u, -np.ones_like(u), -v),
    "Bk": lambda u, v: (u, -v, np.ones_like(u)),
    "Ft": lambda u, v: (-u, -v, -np.ones_like(u)),
}

BAYER4 = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
], dtype=np.float64) / 16.0 - 0.5


def sample_equirect(src: np.ndarray, size: int, face: str) -> np.ndarray:
    h, w, _ = src.shape
    lin = (np.arange(size) + 0.5) / size * 2.0 - 1.0
    u, v = np.meshgrid(lin, lin)
    x, y, z = FACES[face](u, v)
    norm = np.sqrt(x * x + y * y + z * z)
    lon = np.arctan2(x, -z)
    lat = np.arcsin(y / norm)
    sx = (lon / (2 * np.pi) + 0.5) * w
    sy = (0.5 - lat / np.pi) * h
    xi = np.clip(sx.astype(np.int64), 0, w - 1)
    yi = np.clip(sy.astype(np.int64), 0, h - 1)
    return src[yi, xi]


# --- E4 blue grade (float domain, pre-quantisation) -------------------------
DESAT = 0.25                        # desaturate 25% toward luminance
GAINS = (0.78, 0.88, 1.18)          # R, G, B channel gains
FLOOR = np.array([16.0, 22.0, 34.0])  # matches new FogColor (16,22,34)
LIFT_MAX = 0.10                     # 10% lerp toward FLOOR at the dark end
LIFT_KNEE = 96.0                    # lift fades to 0 as luminance reaches this


def blue_grade(px: np.ndarray) -> np.ndarray:
    f = px.astype(np.float64)
    lum = f[..., 0] * 0.299 + f[..., 1] * 0.587 + f[..., 2] * 0.114
    f = f * (1.0 - DESAT) + lum[..., None] * DESAT
    f = f * np.array(GAINS)
    f = np.clip(f, 0.0, 255.0)
    lum2 = f[..., 0] * 0.299 + f[..., 1] * 0.587 + f[..., 2] * 0.114
    w = LIFT_MAX * np.clip(1.0 - lum2 / LIFT_KNEE, 0.0, 1.0)
    f = f * (1.0 - w[..., None]) + FLOOR * w[..., None]
    return np.clip(f, 0.0, 255.0)


def retro(face_f: np.ndarray, levels: int, dither: float) -> np.ndarray:
    """Posterise + ordered dither (RGB555 when levels=32). Float input."""
    size = face_f.shape[0]
    tile = np.tile(BAYER4, (size // 4 + 1, size // 4 + 1))[:size, :size]
    step = 255.0 / (levels - 1)
    out = face_f + tile[:, :, None] * step * dither
    out = np.round(np.clip(out, 0, 255) / step) * step
    return np.clip(out, 0, 255).astype(np.uint8)


NAME = {"Up": "up", "Dn": "dn", "Lf": "lf", "Rt": "rt", "Ft": "ft", "Bk": "bk"}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    src = np.asarray(Image.open(SRC).convert("RGB"))
    print("source:", SRC, src.shape)
    for face in FACES:
        px = sample_equirect(src, SIZE, face)
        px = blue_grade(px)
        px = retro(px, LEVELS, DITHER)
        path = os.path.join(OUT, NAME[face] + ".png")
        Image.fromarray(px).save(path, optimize=True)
        print(face, "->", path, os.path.getsize(path), "bytes")
