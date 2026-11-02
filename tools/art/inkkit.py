"""Tiny "dirty ink" illustration kit for generated placeholder art.

Everything is drawn supersampled (SS×) and downsampled, giving soft, slightly
irregular ink lines over textured fills — a stand-in for tablet-drawn art.
Coordinates are in output (source) pixels.
"""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 2
INK = (38, 32, 25, 255)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(len(c1)))


def value_noise(w, h, cell, seed, octaves=3, wrap=False):
    """Fractal value noise in [0,1], shape (h, w). wrap=True -> tileable."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    c = cell
    for _ in range(octaves):
        gw, gh = max(2, int(math.ceil(w / c))), max(2, int(math.ceil(h / c)))
        grid = rng.random((gh, gw)).astype(np.float32)
        if wrap:
            ys = (np.arange(h) / h * gh)
            xs = (np.arange(w) / w * gw)
            y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
            fy = ys - y0; fx = xs - x0
            fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
            y1 = (y0 + 1) % gh; x1 = (x0 + 1) % gw; y0 %= gh; x0 %= gw
            a = grid[np.ix_(y0, x0)]; b = grid[np.ix_(y0, x1)]
            cc = grid[np.ix_(y1, x0)]; d = grid[np.ix_(y1, x1)]
            fxv = fx[None, :]; fyv = fy[:, None]
            layer = (a * (1 - fxv) + b * fxv) * (1 - fyv) + (cc * (1 - fxv) + d * fxv) * fyv
        else:
            img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
            layer = np.asarray(img, dtype=np.float32) / 255.0
        out += layer * amp
        total += amp
        amp *= 0.5
        c = max(2, c // 2)
    return out / total


class Canvas:
    def __init__(self, w, h, seed=1):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        self.rng = random.Random(seed)
        self.seed = seed

    # ---- helpers ----
    def S(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def mask(self, poly=None, ellipse=None):
        m = Image.new("L", self.img.size, 0)
        d = ImageDraw.Draw(m)
        if poly:
            d.polygon(self.S(poly), fill=255)
        if ellipse:
            x0, y0, x1, y1 = ellipse
            d.ellipse((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=255)
        return m

    def paste_layer(self, color_img, mask):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        layer.paste(color_img, (0, 0), mask)
        self.img = Image.alpha_composite(self.img, layer)

    # ---- fills ----
    def fill(self, poly, color, tex=0.18, cell=24, grain=0.06, mask=None, light=None):
        """Textured fill. light=(dx,dy,strength): gradient brightening toward a side."""
        m = mask if mask is not None else self.mask(poly)
        W, H = self.img.size
        n = value_noise(W, H, cell * SS, self.rng.randint(0, 1 << 30))
        g = np.random.default_rng(self.rng.randint(0, 1 << 30)).random((H, W)).astype(np.float32)
        shade = 1.0 + (n - 0.5) * 2 * tex + (g - 0.5) * 2 * grain
        if light:
            bbox = m.getbbox() or (0, 0, W, H)
            yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
            cx = (xx - bbox[0]) / max(1, bbox[2] - bbox[0])
            cy = (yy - bbox[1]) / max(1, bbox[3] - bbox[1])
            dx, dy, s = light
            shade *= 1.0 + s * ((cx - 0.5) * dx + (cy - 0.5) * dy)
        arr = np.zeros((H, W, 4), dtype=np.float32)
        for i in range(3):
            arr[..., i] = np.clip(color[i] * shade, 0, 255)
        arr[..., 3] = color[3] if len(color) > 3 else 255
        self.paste_layer(Image.fromarray(arr.astype(np.uint8), "RGBA"), m)
        return m

    def ellipse_fill(self, box, color, tex=0.15, cell=20, light=None):
        return self.fill(None, color, tex=tex, cell=cell, mask=self.mask(ellipse=box), light=light)

    def hatch(self, mask, spacing=6, angle=-50, color=INK, alpha=90, width=1.0, jitter=0.6):
        """Ink hatching clipped to a mask (L image at canvas size)."""
        W, H = self.img.size
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        a = math.radians(angle)
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx
        L = W + H
        step = spacing * SS
        k = -L
        while k < L:
            off = k + self.rng.uniform(-jitter, jitter) * SS
            cx, cy = W / 2 + nx * off, H / 2 + ny * off
            d.line([(cx - dx * L, cy - dy * L), (cx + dx * L, cy + dy * L)],
                   fill=color[:3] + (alpha,), width=max(1, int(width * SS)))
            k += step
        clip = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        clip.paste(layer, (0, 0), ImageChops.multiply(mask, layer.split()[3]))
        self.img = Image.alpha_composite(self.img, clip)

    def soft_shadow(self, box, alpha=90, blur=10):
        m = Image.new("L", self.img.size, 0)
        x0, y0, x1, y1 = box
        ImageDraw.Draw(m).ellipse((x0 * SS, y0 * SS, x1 * SS, y1 * SS), fill=alpha)
        m = m.filter(ImageFilter.GaussianBlur(blur * SS))
        layer = Image.new("RGBA", self.img.size, (20, 18, 12, 0))
        layer.putalpha(m)
        self.img = Image.alpha_composite(layer, self.img) if False else Image.alpha_composite(self.img, layer)

    # ---- ink ----
    def ink(self, pts, width=2.0, closed=False, color=INK, wobble=0.9, alpha=235, seg=6):
        """Irregular ink stroke: jittered path, varying width, round joints.
        Drawn on its own layer and alpha-composited, so a translucent stroke
        tints what is underneath instead of punching a see-through hole."""
        if closed:
            pts = list(pts) + [pts[0]]
        path = []
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            L = math.hypot(x1 - x0, y1 - y0)
            n = max(1, int(L / seg))
            for i in range(n):
                t = i / n
                path.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, (x1 - x0) / max(L, 1e-6), (y1 - y0) / max(L, 1e-6)))
        path.append((pts[-1][0], pts[-1][1], 0, 0))
        phase = self.rng.uniform(0, 100)
        placed = []
        for i, (x, y, tx, ty) in enumerate(path):
            off = (math.sin(phase + i * 0.7) * 0.5 + self.rng.uniform(-0.5, 0.5)) * wobble
            wv = width * (0.75 + 0.45 * (math.sin(phase * 1.7 + i * 0.35) * 0.5 + 0.5)) * self.rng.uniform(0.9, 1.1)
            placed.append(((x - ty * off) * SS, (y + tx * off) * SS, wv * SS))
        pad = max(p[2] for p in placed) + 2
        x0 = int(max(0, min(p[0] for p in placed) - pad)); y0 = int(max(0, min(p[1] for p in placed) - pad))
        x1 = int(min(self.img.size[0], max(p[0] for p in placed) + pad)); y1 = int(min(self.img.size[1], max(p[1] for p in placed) + pad))
        if x1 <= x0 or y1 <= y0:
            return
        layer = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        c = color[:3] + (alpha,)
        prev = None
        for px, py, w in placed:
            px -= x0; py -= y0
            r = w / 2
            if prev:
                d.line([prev, (px, py)], fill=c, width=max(1, int(w)))
            d.ellipse((px - r, py - r, px + r, py + r), fill=c)
            prev = (px, py)
        self.img.alpha_composite(layer, dest=(x0, y0))

    def ink_poly(self, poly, width=2.2, **kw):
        self.ink(poly, width=width, closed=True, **kw)

    def speckle(self, mask, count, color, size=(1, 2.5), alpha=(120, 220)):
        bbox = mask.getbbox()
        if not bbox:
            return
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        px = mask.load()
        for _ in range(count):
            x = self.rng.uniform(bbox[0], bbox[2] - 1); y = self.rng.uniform(bbox[1], bbox[3] - 1)
            if px[int(x), int(y)] > 0:
                r = self.rng.uniform(*size) * SS / 2
                d.ellipse((x - r, y - r, x + r, y + r), fill=color[:3] + (self.rng.randint(*alpha),))
        self.img = Image.alpha_composite(self.img, layer)

    def blob(self, cx, cy, rx, ry, n=14, irregular=0.18):
        pts = []
        ph = self.rng.uniform(0, 6.28)
        for i in range(n):
            a = i / n * 6.283
            r = 1 + irregular * (math.sin(a * 3 + ph) * 0.5 + self.rng.uniform(-0.5, 0.5))
            pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
        return pts

    def save(self, path, size=None):
        out = self.img.resize(size or (self.w, self.h), Image.LANCZOS)
        out.save(path, optimize=True)
        return out
