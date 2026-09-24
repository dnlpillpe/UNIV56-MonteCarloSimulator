#!/usr/bin/env python3
"""Genera el icono de Monte Carlo Simulator.

Reproduce en Pillow el mismo dibujo que `BrandPainter` (lib/presentation/
painters/brand_painter.dart): lluvia de puntos sobre el cuarto de círculo
—la estimación de π, el experimento fundacional del método— con los
colores-concepto de la app (cian = muestras dentro, naranja = fuera,
verde menta = el modelo, dorado = la estimación: el último dardo).

Los puntos salen de xoshiro128** con la semilla 2026, igual que en Dart.

Uso:  python3 tool/generate_icon.py
Salida: assets/icon/icon.png (1024 px) y assets/icon/icon_foreground.png
"""
from pathlib import Path

from PIL import Image, ImageDraw

M32 = 0xFFFFFFFF


def rotl(x, k):
    return ((x << k) | (x >> (32 - k))) & M32


class SplitMix32:
    def __init__(self, seed):
        self.s = seed & M32

    def next(self):
        self.s = (self.s + 0x9E3779B9) & M32
        z = self.s
        z = ((z ^ (z >> 16)) * 0x85EBCA6B) & M32
        z = ((z ^ (z >> 13)) * 0xC2B2AE35) & M32
        return (z ^ (z >> 16)) & M32


class Xoshiro128:
    def __init__(self, seed):
        sm = SplitMix32(seed)
        self.s = [sm.next() for _ in range(4)]
        if not any(self.s):
            self.s[0] = 1

    def next_u32(self):
        s0, s1, s2, s3 = self.s
        result = (rotl((s1 * 5) & M32, 7) * 9) & M32
        t = (s1 << 9) & M32
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = rotl(s3, 11)
        self.s = [s0, s1, s2, s3]
        return result

    def next_double(self):
        return (self.next_u32() + 0.5) / 4294967296.0


# ---------------------------------------------------------------- geometría
DOTS = 80
SEED = 2026
NIGHT = (11, 37, 33)
FELT_TOP = (21, 92, 76)
FELT_BOTTOM = (8, 28, 25)
MODEL = (61, 220, 151)
SAMPLE = (69, 196, 224)
RISK = (255, 138, 76)
GOLD = (245, 184, 61)
OUTLINE = (44, 90, 81)
GOLD_DART = (0.56, 0.52)


def brand_dots():
    rng = Xoshiro128(SEED)
    pts = []
    for _ in range(DOTS):
        x, y = rng.next_double(), rng.next_double()
        pts.append((x, y, x * x + y * y <= 1))
    return pts


def draw_mark(img, left, top, side, scale):
    """Dibuja el cuadrado de la estimación: puntos, arco y el dardo dorado."""
    d = ImageDraw.Draw(img)
    ox, oy = left, top + side  # origen abajo a la izquierda

    def P(x, y):
        return (ox + x * side, oy - y * side)

    d.rectangle([left, top, left + side, top + side], outline=OUTLINE, width=max(2, int(0.010 * scale)))
    r = 0.021 * scale
    for x, y, inside in brand_dots():
        cx, cy = P(x, y)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SAMPLE if inside else RISK)
    # cuarto de círculo (el modelo)
    w = int(0.030 * scale)
    d.arc([ox - side, oy - side, ox + side, oy + side], start=270, end=360, fill=MODEL, width=w)
    # el último dardo: la estimación (dorado, con halo)
    gx, gy = P(GOLD_DART[0], GOLD_DART[1])
    R = 0.046 * scale
    d.ellipse([gx - R * 1.55, gy - R * 1.55, gx + R * 1.55, gy + R * 1.55], outline=GOLD, width=max(2, int(0.012 * scale)))
    d.ellipse([gx - R, gy - R, gx + R, gy + R], fill=GOLD)


def make_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg = Image.new("RGBA", (size, size))
    bd = ImageDraw.Draw(bg)
    for yy in range(size):
        t = yy / (size - 1)
        col = tuple(int(FELT_TOP[k] * (1 - t) + FELT_BOTTOM[k] * t) for k in range(3))
        bd.line([(0, yy), (size, yy)], fill=col + (255,))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(0.22 * size), fill=255)
    img.paste(bg, (0, 0), mask)
    side = 0.64 * size
    draw_mark(img, 0.18 * size, 0.18 * size, side, size)
    return img


def make_foreground(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    side = 0.46 * size
    draw_mark(img, (size - side) / 2, (size - side) / 2, side, size * 0.74)
    return img


def main():
    out = Path(__file__).resolve().parent.parent / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    make_icon().convert("RGBA").save(out / "icon.png")
    make_foreground().save(out / "icon_foreground.png")
    print("Iconos generados en", out)


if __name__ == "__main__":
    main()
