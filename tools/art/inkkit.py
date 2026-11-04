""""Dirty ink" illustration kit for the generated template art (v2, visual overhaul).

Everything is drawn supersampled (SS×) and downsampled. v2 aims at the approved
visual direction (hand-drawn, non-pixel, rough expressive ink over textured,
muted colour): painterly two-tone fills with paper fibre, tapered dry-brush
ink strokes, shadow-side hatching, grime and drips, moss and ivy, leaf
clusters, and a finishing pass on save() that gives every sprite a rough ink
silhouette, inner edge shading and ink grain, so all assets read as one
illustrated set. Coordinates are in output (source) pixels.
"""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SS = 2
INK = (33, 27, 21, 255)
WARM = (214, 176, 112, 255)   # faded warm light (straw/amber family)
COOL = (46, 52, 50, 255)      # cool shadow (charcoal / soot)

# Red Thaw (nuclear winter): outdoor sprites get snow settled on their upward-facing
# surfaces, frost and a cold, desaturated palette when saved. Interior and bunker
# art is left as it is. Paths are matched against these fragments.
WINTER = True
OUTDOOR = ("/env/", "/world/buildings/", "/world/fences/", "/world/doors/template_gate", "/props/",
           "/world/station/", "/world/settlement/", "/build/template_barricade", "/build/template_spike",
           "/build/template_rain_collector")
SNOW = (216, 219, 217, 255)       # dirty white
SNOW_SHADE = (150, 162, 168, 255)  # blue-grey snow shadow


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
        """Painterly textured fill: brightness noise plus a warm-light / cool-shadow
        hue drift, fine paper fibre and an optional directional light
        light=(dx, dy, strength) that brightens toward one side and cools the other."""
        m = mask if mask is not None else self.mask(poly)
        bbox = m.getbbox()
        if not bbox:
            return m
        W, H = self.img.size
        x0, y0, x1, y1 = bbox
        w, h = x1 - x0, y1 - y0
        seed = self.rng.randint(0, 1 << 30)
        n = value_noise(w, h, cell * SS, seed)
        n2 = value_noise(w, h, max(4, cell * SS * 3), seed + 7, octaves=2)
        g = np.random.default_rng(seed + 3).random((h, w)).astype(np.float32)
        fib = value_noise(w, h, 3, seed + 11, octaves=1)
        shade = 1.0 + (n - 0.5) * 1.3 * tex + (g - 0.5) * 1.6 * grain + (fib - 0.5) * 0.07
        lit = np.zeros((h, w), dtype=np.float32)
        if light:
            yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
            dx, dy, st = light
            lit = st * (-(xx / max(1, w) - 0.5) * dx - (yy / max(1, h) - 0.5) * dy)
            shade *= 1.0 + lit
        warmth = np.clip((n2 - 0.5) * 0.9 + lit * 1.0, -1, 1)
        base = np.array(color[:3], dtype=np.float32)
        warm = base * 0.82 + np.array(WARM[:3], dtype=np.float32) * 0.18
        cool = base * 0.80 + np.array(COOL[:3], dtype=np.float32) * 0.20
        wpos = np.clip(warmth, 0, 1)[..., None]
        wneg = np.clip(-warmth, 0, 1)[..., None]
        rgb = base * (1 - wpos * 0.45 - wneg * 0.55) + warm * wpos * 0.45 + cool * wneg * 0.55
        rgb = np.clip(rgb * shade[..., None], 0, 255)
        arr = np.zeros((h, w, 4), dtype=np.uint8)
        arr[..., :3] = rgb.astype(np.uint8)
        arr[..., 3] = color[3] if len(color) > 3 else 255
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        layer.paste(Image.fromarray(arr, "RGBA"), (x0, y0), m.crop(bbox))
        self.img = Image.alpha_composite(self.img, layer)
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
            wv = width * (0.7 + 0.55 * (math.sin(phase * 1.7 + i * 0.35) * 0.5 + 0.5)) * self.rng.uniform(0.85, 1.12)
            if not closed and len(path) > 6:  # tapered ends like a brush pen
                t = i / max(1, len(path) - 1)
                wv *= 0.45 + 0.55 * min(1.0, min(t, 1 - t) * 5.0)
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
        # dry-brush ghost: a broken, thinner second pass slightly off the line
        if width >= 1.6 and alpha >= 150 and len(placed) > 3:
            ga = c[:3] + (int(alpha * 0.38),)
            k0 = self.rng.randint(0, max(0, len(placed) // 3))
            k1 = min(len(placed), k0 + self.rng.randint(len(placed) // 3, len(placed)))
            gp = None
            for px, py, w in placed[k0:k1]:
                q = (px - x0 + 0.9 * SS, py - y0 + 0.7 * SS)
                if gp and self.rng.random() > 0.12:
                    d.line([gp, q], fill=ga, width=max(1, int(w * 0.45)))
                gp = q
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

    # ---- illustration helpers (v2) ----
    def shade(self, mask, dx=1.0, dy=0.6, spacing=4.5, alpha=95, angle=-55, cross=False, reach=0.55):
        """Hatch only the shadow side of a shape (light comes from -dx, -dy)."""
        bbox = mask.getbbox()
        if not bbox:
            return
        W, H = self.img.size
        x0, y0, x1, y1 = bbox
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        u = ((xx - x0) / max(1, x1 - x0) - 0.5) * dx + ((yy - y0) / max(1, y1 - y0) - 0.5) * dy
        side = np.clip((u + 0.5 - (1 - reach)) / max(0.05, reach), 0, 1)
        m2 = (np.asarray(mask, dtype=np.float32) * side).astype(np.uint8)
        sm = Image.fromarray(m2, "L")
        self.hatch(sm, spacing=spacing, angle=angle, alpha=alpha, width=1.0)
        if cross:
            m3 = Image.fromarray((np.asarray(mask, dtype=np.float32) * np.clip(side * 2 - 1, 0, 1)).astype(np.uint8), "L")
            self.hatch(m3, spacing=spacing * 1.2, angle=angle + 85, alpha=int(alpha * 0.8), width=1.0)

    def grime(self, mask, amount=0.35, drips=True, color=None):
        """Dirt, stains and rain drips inside a shape (weathering)."""
        bbox = mask.getbbox()
        if not bbox:
            return
        col = color or mix(INK, (80, 62, 40, 255), 0.4)
        W, H = self.img.size
        x0, y0, x1, y1 = bbox
        w, h = x1 - x0, y1 - y0
        n = value_noise(w, h, max(6, int(min(w, h) / 5)), self.rng.randint(0, 1 << 30), octaves=4)
        a = np.clip((n - (0.62 - amount * 0.35)) * 3.2, 0, 1) * 0.55
        if drips:
            for _ in range(int(w / (14 * SS)) + 1):
                cx = self.rng.randint(0, max(1, w - 1))
                top = self.rng.randint(0, max(1, h // 2))
                ln = self.rng.randint(h // 6, max(h // 6 + 1, h // 2))
                wd = self.rng.randint(1, 2 * SS)
                ys = np.arange(top, min(h, top + ln))
                fade = np.linspace(0.45, 0.0, len(ys)) if len(ys) else ys
                for k, yv in enumerate(ys):
                    a[yv, max(0, cx - wd):cx + wd] = np.maximum(a[yv, max(0, cx - wd):cx + wd], fade[k] * amount)
        m = np.asarray(mask.crop(bbox), dtype=np.float32) / 255.0
        alpha = np.clip(a * m * 255, 0, 255).astype(np.uint8)
        layer = Image.new("RGBA", (w, h), col[:3] + (0,))
        layer.putalpha(Image.fromarray(alpha, "L"))
        self.img.alpha_composite(layer, dest=(x0, y0))

    def moss(self, mask, amount=0.4, colors=None):
        """Patchy moss and lichen: clumps biased toward the top of a shape."""
        bbox = mask.getbbox()
        if not bbox:
            return
        cols = colors or [(82, 98, 44, 255), (110, 122, 56, 255), (150, 152, 82, 255)]
        x0, y0, x1, y1 = bbox
        w, h = x1 - x0, y1 - y0
        n = value_noise(w, h, max(5, int(min(w, h) / 6)), self.rng.randint(0, 1 << 30), octaves=3)
        yy = np.linspace(1.0, 0.25, h)[:, None]
        a = np.clip((n * yy - (0.55 - amount * 0.3)) * 4.0, 0, 1)
        m = np.asarray(mask.crop(bbox), dtype=np.float32) / 255.0
        g = np.random.default_rng(self.rng.randint(0, 1 << 30)).random((h, w))
        idx = np.clip((n * 3).astype(int), 0, 2)
        rgb = np.array([c[:3] for c in cols], dtype=np.float32)[idx] * (0.85 + 0.3 * g[..., None])
        arr = np.zeros((h, w, 4), dtype=np.uint8)
        arr[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        arr[..., 3] = np.clip(a * m * 235 * (g > 0.18), 0, 255).astype(np.uint8)
        self.img.alpha_composite(Image.fromarray(arr, "RGBA"), dest=(x0, y0))

    def leaf(self, x, y, size, angle, color, ink_alpha=170):
        """One almond-shaped leaf with an inked edge and a midrib."""
        a = math.radians(angle)
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx
        L, Wd = size, size * 0.42
        pts = [(x, y), (x + dx * L * 0.5 + nx * Wd, y + dy * L * 0.5 + ny * Wd), (x + dx * L, y + dy * L),
               (x + dx * L * 0.5 - nx * Wd, y + dy * L * 0.5 - ny * Wd)]
        d = ImageDraw.Draw(self.img)
        d.polygon(self.S(pts), fill=color[:3] + (255,))
        self.ink([pts[0], pts[1], pts[2]], width=max(0.8, size * 0.09), alpha=ink_alpha, wobble=0.25, seg=3)
        if size > 7:
            self.ink([(x + dx * L * 0.15, y + dy * L * 0.15), (x + dx * L * 0.8, y + dy * L * 0.8)], width=0.7,
                     color=mix(color, INK, 0.5), alpha=140, wobble=0.1, seg=4)

    def ivy(self, x, y, length, direction=-90, colors=None, leaves=12, size=7):
        """A creeping vine with leaves (overgrowth on walls, posts, wrecks)."""
        cols = colors or [(70, 86, 40, 255), (102, 117, 56, 255), (138, 146, 74, 255)]
        pts = [(x, y)]
        a = math.radians(direction)
        for i in range(int(length / 8)):
            a += self.rng.uniform(-0.45, 0.45)
            x += math.cos(a) * 8; y += math.sin(a) * 8
            pts.append((x, y))
        self.ink(pts, width=1.6, color=(64, 58, 36, 255), alpha=220, wobble=0.4, seg=4)
        for _ in range(leaves):
            px, py = pts[self.rng.randint(0, len(pts) - 1)]
            self.leaf(px, py, size * self.rng.uniform(0.7, 1.3), self.rng.uniform(0, 360), self.rng.choice(cols))

    def finish(self, outline=2.6, burn=0.32, grain=0.05):
        """Unifying finish: rough ink silhouette around the whole sprite, inner
        edge shading (form) and ink grain. Applied by save() to every sprite."""
        a = self.img.split()[3]
        A = np.asarray(a, dtype=np.float32) / 255.0
        if A.max() <= 0 or A.min() >= 0.99:
            return
        k_thin = max(3, int(outline * SS * 0.7) | 1)
        k_thick = max(3, int(outline * SS * 1.5) | 1)
        thin = np.asarray(a.filter(ImageFilter.MaxFilter(k_thin)), dtype=np.float32) / 255.0
        thick = np.asarray(a.filter(ImageFilter.MaxFilter(k_thick)), dtype=np.float32) / 255.0
        H, W = A.shape
        n = value_noise(W, H, 9 * SS, self.seed + 991, octaves=3)
        ring = np.clip(np.where(n > 0.5, thick, thin) - A, 0, 1)
        ring *= (0.7 + 0.3 * (np.random.default_rng(self.seed).random((H, W)) > 0.08))
        rgb = np.asarray(self.img, dtype=np.float32)[..., :3]
        blur = np.asarray(a.filter(ImageFilter.GaussianBlur(5 * SS)), dtype=np.float32) / 255.0
        edge = np.clip((A - blur) * 2.2, 0, 1)
        top = np.linspace(0.9, 1.06, H)[:, None]  # sprites read slightly darker toward their base
        top = top[::-1]
        g = 1.0 + (n - 0.5) * 2 * grain
        rgb = rgb * (1 - edge[..., None] * burn) * top[..., None] * g[..., None]
        ink = np.array(INK[:3], dtype=np.float32)
        tot = np.clip(A + ring, 0, 1)
        safe = np.maximum(tot, 1e-6)[..., None]
        out = np.zeros((H, W, 4), dtype=np.float32)
        out[..., :3] = (rgb * A[..., None] + ink * ring[..., None]) / safe
        out[..., 3] = tot * 255
        self.img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")

    def winterize(self, depth=10.0, cold=0.42, frost=0.6, kill_green=True):
        """Snow resting on every upward-facing surface (thicker on flat tops, thin on
        slopes, nothing on vertical faces), a soft overhang, frost speckle and a cold
        desaturated grade. Works on any sprite so all outdoor art shares one winter."""
        rgba = np.asarray(self.img, dtype=np.float32)
        A = rgba[..., 3] / 255.0
        if A.max() <= 0 or A.min() >= 0.99:
            return
        H, W = A.shape
        solid = A > 0.5
        above = np.zeros_like(solid); above[2:] = solid[:-2]
        top = solid & ~above
        n = value_noise(W, H, 7 * SS, self.seed + 4242, octaves=3)
        d = (depth * SS * (0.45 + 0.9 * n)).astype(np.int32)
        cap = np.zeros_like(solid)
        sh = np.zeros_like(solid)
        acc = top.copy()
        dmax = int(depth * SS * 1.4)
        for k in range(1, dmax):
            acc2 = np.zeros_like(acc); acc2[1:] = acc[:-1]
            acc = acc2 & solid
            cap |= acc & (k < d)
            sh |= acc & (k >= d * 0.65) & (k < d)
        cap |= top
        # overhang: a lumpy rim rising just above the surface
        up = np.zeros_like(cap); up[:-SS] = top[SS:]
        rim = up & ~solid & (n > 0.38)
        cap_all = cap | rim
        rgb = rgba[..., :3].copy()
        if kill_green:
            # living green -> dead, brittle straw and bark browns (nothing grows here any more)
            r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
            green = np.clip((g_ - np.maximum(r_, b_) + 4) / 30.0, 0, 1)[..., None]
            lum0 = (rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32))[..., None] / 255.0
            dead = np.array([140, 128, 108], dtype=np.float32) * (0.55 + 0.75 * lum0)
            rgb = rgb * (1 - green) + dead * green
        # cold grade first (whole sprite), then snow on top
        lum = (rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32))[..., None]
        rgb = rgb * (1 - cold) + lum * cold
        rgb = rgb * np.array([0.93, 0.97, 1.03], dtype=np.float32)
        g = np.random.default_rng(self.seed + 77).random((H, W)).astype(np.float32)
        fr = (g > 1 - 0.012 * frost) & solid
        rgb[fr] = rgb[fr] * 0.4 + np.array(SNOW[:3], dtype=np.float32) * 0.6
        snow = np.array(SNOW[:3], dtype=np.float32) * (0.96 + 0.08 * n[..., None])
        snow_sh = np.array(SNOW_SHADE[:3], dtype=np.float32)
        col = np.where(sh[..., None], snow_sh * 0.55 + snow * 0.45, snow)
        rgb = np.where(cap_all[..., None], col, rgb)
        alpha = np.where(rim, 235.0, rgba[..., 3])
        # a thin ink line under the snow edge
        below = np.zeros_like(cap); below[1:] = cap[:-1]
        line = below & ~cap & solid
        rgb[line] = rgb[line] * 0.45 + np.array(INK[:3], dtype=np.float32) * 0.55
        out = np.dstack([np.clip(rgb, 0, 255), alpha]).astype(np.uint8)
        self.img = Image.fromarray(out, "RGBA")

    def save(self, path, size=None, finish=True, winter=None):
        if winter is None:
            winter = WINTER and any(f in str(path).replace("\\", "/") for f in OUTDOOR)
        if winter:
            self.winterize()
        if finish:
            self.finish()
        out = self.img.resize(size or (self.w, self.h), Image.LANCZOS)
        out.save(path, optimize=True)
        return out