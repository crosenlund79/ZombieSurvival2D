# Godot 4.x Reproduction Guide — the "dirty ink" look

This guide reproduces the visual language described in [`VISUAL_DNA.md`](VISUAL_DNA.md) in a **fresh
Godot 4.x project**, in **any setting**. It does not depend on Red Thaw's gameplay, world systems or
content.

- Values marked **(RT)** are the exact values used in Red Thaw.
- Items marked **NEW RECOMMENDATION** are mine. They are not settings that exist in Red Thaw.

The look has two halves, and you need both:

1. **Offline sprite pipeline:** the "ink" lives in the image files.
2. **Runtime presentation:** sorting, a screen grade, a global light colour, soft glows, sway and
   drifting particles.

---

## 1. Project settings

| Setting | Value | |
|---|---|---|
| Renderer | `gl_compatibility` (RT). Forward+ also works; nothing here needs it | |
| `rendering/textures/canvas_textures/default_texture_filter` | **Linear** (1) (RT). Never Nearest | |
| Viewport | 1280×720, stretch mode `canvas_items`, aspect `expand` (RT) | |
| `rendering/environment/defaults/default_clear_color` | a dark neutral of your palette; RT uses (0.16, 0.17, 0.13) | |
| Mipmaps on sprite imports | off (RT default import) | NEW RECOMMENDATION: enable mipmaps only on ground tiles if you zoom out below 0.5 and see shimmer |
| Physics gravity (2D) | 0 for top-down | |

Do **not** add `WorldEnvironment` glow or HDR 2D. The look does not use them.

---

## 2. Scene layering (copy this structure)

```
Main (Node2D)
├── World (Node2D)
│   ├── Ground (Node2D, z_index = -10)       ← Polygon2D patches with repeating tiles
│   ├── FloorDecals (Node2D, z_index = -1)   ← rugs, hatches, stains (never sorted)
│   ├── YSort (Node2D, y_sort_enabled = true)← EVERY standing thing: props, trees, actors
│   ├── DriftParticles (CPUParticles2D, z_index = 20)
│   ├── CanvasModulate                       ← global light colour (time of day / room)
│   ├── CanvasLayer (layer 4)  → weather overlay (optional)
│   └── CanvasLayer (layer 5)  → full-screen grade ColorRect (shader below)
└── UI (CanvasLayer, layer 10)               ← never graded
```

**Rule:** every standing object's node origin is its **ground-contact point**. The sprite is offset
upward so the art's foot sits on the origin, which makes y-sorting correct.

### Sprite fitting (RT `asset_resolver.gd: apply_to_sprite`)

Each asset has three values:
- `display_size`: the in-game box
- `pivot`: the ground point as a fraction of the box
- `source_size`: about 2 × display, for drawing

```gdscript
func fit(sprite: Sprite2D, tex: Texture2D, box: Vector2, pivot: Vector2) -> void:
	sprite.texture = tex
	sprite.centered = false
	var s := minf(box.x / tex.get_size().x, box.y / tex.get_size().y)
	sprite.scale = Vector2(s, s)
	var drawn := tex.get_size() * s
	sprite.position = -box * pivot + Vector2((box.x - drawn.x) * 0.5, box.y - drawn.y)
```

This lets an artist replace any image at any resolution without breaking placement or collision.
Collision is a separate rectangle "footprint" at the base, never derived from art.

### Occlusion fade (RT `prop.gd`)

When the player stands behind a tall object, fade it to **alpha 0.42** at 3 units/s.

"Behind" means both:
- the player's position (in the object's local space) is above its base: `local.y < -4`
- `local + (0, -30)` is inside the art rectangle, inset 8 px on the left and right

### Camera (RT `player_avatar.gd`)

- `Camera2D` set to `top_level`, target = player + (0, −24)
- position follows with `lerp(target, 1 - exp(-6 * delta))`
- zoom: default 1.0, range 0.5–2.5, ×1.1 per step
- an area smaller than the view is centred; a larger one is clamped to its bounds

---

## 3. The screen grade shader (RT, verbatim logic)

Put a full-rect `ColorRect` (mouse filter ignore) on `CanvasLayer` 5 with this shader:

```glsl
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D grain : repeat_enable, filter_linear;   // 256² grey noise, see §5.4
uniform sampler2D fog : repeat_enable, filter_linear;     // 512² tileable alpha noise (optional)
uniform float grain_strength = 0.07;
uniform float vignette_strength = 0.3;
uniform float contrast = 1.08;
uniform float saturation = 0.7;
uniform float fog_strength = 0.0;
uniform vec3 shadow_tone = vec3(0.84, 0.9, 0.98);
uniform vec3 highlight_tone = vec3(0.98, 1.0, 1.04);
uniform vec3 vignette_tone = vec3(0.42, 0.45, 0.5);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec2 world_origin = vec2(0.0);
uniform float world_scale = 1.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = clamp((c - 0.5) * contrast + 0.5, 0.0, 1.0);
	c *= mix(shadow_tone, highlight_tone, smoothstep(0.12, 0.8, l));
	if (fog_strength > 0.0) {
		vec2 wp = (uv * screen_size - world_origin) / world_scale;
		float f1 = texture(fog, wp / 900.0 + vec2(TIME * 0.006, TIME * 0.002)).a;
		float f2 = texture(fog, wp / 1500.0 + vec2(-TIME * 0.004, TIME * 0.003)).a;
		float f = clamp(f1 * 0.6 + f2 * 0.6, 0.0, 1.0) * fog_strength;
		c = mix(c, vec3(0.80, 0.83, 0.86) * (0.55 + 0.45 * smoothstep(0.0, 0.6, l + 0.3)), f);
	}
	float g = texture(grain, uv * screen_size / 256.0).r;
	vec2 d = uv - 0.5;
	float v = smoothstep(0.32, 0.85, length(d * vec2(1.0, 0.8)));
	c = mix(c, c * vignette_tone, clamp(v * vignette_strength * 1.8, 0.0, 1.0));
	c *= 1.0 + (g - 0.5) * grain_strength * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
```

Each frame, upload these (RT `atmosphere.gd:_process`):

```gdscript
mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
var ct := get_viewport().get_canvas_transform()
mat.set_shader_parameter("world_origin", ct.origin)   # keeps fog anchored to the world
mat.set_shader_parameter("world_scale", ct.x.x)
```

### Grade presets

| Preset | saturation | contrast | shadow_tone | highlight_tone | vignette_tone | vignette | grain | fog |
|---|---|---|---|---|---|---|---|---|
| **Neutral-warm (portable default)** (RT, earlier build) | 0.88 | 1.10 | (0.88, 0.94, 0.96) | (1.05, 1.00, 0.90) | (0.50, 0.45, 0.38) | 0.28 | 0.07 | 0 |
| Cold exterior (RT current) | 0.70 | 1.08 | (0.84, 0.90, 0.98) | (0.98, 1.00, 1.04) | (0.42, 0.45, 0.50) | 0.30 | 0.07 | 0.22 |
| Warm interior (RT current) | 0.85 | 1.08 | (0.88, 0.92, 0.96) | (1.08, 1.00, 0.86) | (0.50, 0.44, 0.36) | 0.40–0.50 | 0.07–0.09 | 0 |

**NEW RECOMMENDATION:** start every new project on *neutral-warm*, then push saturation and tones toward
your setting. Keep saturation ≤ 0.9 and contrast between 1.05 and 1.12. Outside those ranges the
hand-inked texture either goes muddy or looks digital.

---

## 4. Light recipe (RT)

1. **`CanvasModulate`** sets the time of day or the room. Lerp toward the target at
   `1 - exp(-1.5 * delta)`.

   | Case | Colour |
   |---|---|
   | Exterior day (RT, cold setting) | (0.86, 0.90, 0.96) |
   | Exterior day (earlier neutral build) | (1.0, 0.97, 0.90) |
   | Exterior night | (0.20, 0.24, 0.36) |
   | Bad weather | colour × (0.80, 0.84, 0.90) |
   | Warm room | (0.72, 0.66, 0.58) |
   | Dark cellar | (0.38, 0.34, 0.30) |
   | Dark cellar, powered | (0.56, 0.53, 0.48) |

2. **Soft glows:** `PointLight2D` with one shared radial gradient texture:

   ```gdscript
   var g := Gradient.new()
   g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.45, Color(1, 1, 1, 0.55))
   var t := GradientTexture2D.new(); t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
   t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(0.5, 0.0); t.width = 256; t.height = 256
   ```

   | Light | Colour | texture_scale | energy |
   |---|---|---|---|
   | Warm lantern / fire | (1.0, 0.78, 0.45) | 3.4 | 1.0 |
   | Electric bulb | (1.0, 0.95, 0.82) | 3.6 | 0.42 |
   | Carried light at night | (1.0, 0.88, 0.66) | 1.6 × 2.2 | (1 − daylight) × 0.85 |

3. **Shadows are baked:** a blurred ellipse under each sprite (§5.3). Do not add `LightOccluder2D`; it
   fights the illustrated shadows.

**Rule (RT):** warm light is rare. Most of the screen sits in the neutral or cool modulate, and a few warm
pools carry meaning.

---

## 5. Sprite production standard (the "ink" half)

Draw by hand (tablet), **or** generate placeholders with the reference kit below. Either way, every
sprite must show these properties:

| # | Property | Hand-drawing instruction | Kit function |
|---|---|---|---|
| 1 | Mottled painterly fill | Lay flat colour, then a soft low-contrast value texture; push the lit side slightly warmer and the shadow side cooler | `fill(..., tex 0.25–0.4, light=(-1,-1,0.3))` |
| 2 | Light from the upper left | Every object | |
| 3 | Shadow-side hatching | Fine diagonal ink lines about 4–6 px apart at −55°, on the lower-right shadow area only, ~35 % opacity | `shade()` |
| 4 | Brush-pen linework | Warm near-black ink `#211B15`; contours 2.2–3.6 px, inner forms 1.4–2, texture 0.8–1.4 at lower opacity; wobbly, width-varying, tapered ends; allow a faint offset ghost | `ink()` |
| 5 | Weathering | Stains and vertical drips, sparse | `grime()` |
| 6 | Baked contact shadow | Soft dark ellipse under the base, alpha 0.35–0.55 | `soft_shadow()` |
| 7 | Finishing silhouette | Rough, slightly broken outer ink contour; darken the inner rim of each shape; very light grain | `finish()` |
| 8 | Draw at 2× display | Draw at source = 2× display, plus 2× supersampling when generating | `SS = 2` |
| 9 | Ground tiles | Seamless, lower contrast, no outer contour; inked small marks only | `tile` recipe |

### 5.1 Reference kit (condensed from RT `tools/art/inkkit.py`, Python 3 + Pillow + numpy)

```python
import math, random, numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
SS = 2; INK = (33, 27, 21); WARM = (214, 176, 112); COOL = (46, 52, 50)

def value_noise(w, h, cell, seed, octaves=3):
    rng = np.random.default_rng(seed); out = np.zeros((h, w), np.float32); amp = tot = 1.0; tot = 0
    for _ in range(octaves):
        gw, gh = max(2, math.ceil(w / cell)), max(2, math.ceil(h / cell))
        layer = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(layer, np.float32) / 255 * amp; tot += amp; amp *= 0.5; cell = max(2, cell // 2)
    return out / tot

class Canvas:
    def __init__(s, w, h, seed=1):
        s.w, s.h, s.seed, s.rng = w, h, seed, random.Random(seed)
        s.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    def mask(s, poly):
        m = Image.new("L", s.img.size, 0); ImageDraw.Draw(m).polygon([(x*SS, y*SS) for x, y in poly], fill=255); return m
    def fill(s, poly, col, tex=0.25, cell=10, grain=0.06, light=(-1, -1, 0.3)):
        m = s.mask(poly); x0, y0, x1, y1 = m.getbbox(); w, h = x1-x0, y1-y0; sd = s.rng.randint(0, 1 << 30)
        n = value_noise(w, h, cell*SS, sd); n2 = value_noise(w, h, max(4, cell*SS*3), sd+7, 2)
        g = np.random.default_rng(sd+3).random((h, w)); fib = value_noise(w, h, 3, sd+11, 1)
        shade = 1 + (n-.5)*1.3*tex + (g-.5)*1.6*grain + (fib-.5)*.07
        yy, xx = np.mgrid[0:h, 0:w]; dx, dy, st = light
        lit = st*(-(xx/max(1, w)-.5)*dx - (yy/max(1, h)-.5)*dy); shade *= 1 + lit
        wm = np.clip((n2-.5)*.9 + lit, -1, 1); wp, wn = np.clip(wm, 0, 1)[..., None], np.clip(-wm, 0, 1)[..., None]
        b = np.array(col[:3], np.float32); warm = b*.82 + np.array(WARM)*.18; cool = b*.8 + np.array(COOL)*.2
        rgb = np.clip((b*(1-.45*wp-.55*wn) + warm*.45*wp + cool*.55*wn)*shade[..., None], 0, 255)
        layer = Image.new("RGBA", s.img.size); tile = np.dstack([rgb, np.full((h, w), 255)]).astype(np.uint8)
        layer.paste(Image.fromarray(tile, "RGBA"), (x0, y0), m.crop((x0, y0, x1, y1))); s.img = Image.alpha_composite(s.img, layer)
        return m
    def ink(s, pts, width=2.0, wobble=0.9, alpha=235, seg=6, color=INK):
        path = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            L = math.hypot(bx-ax, by-ay); n = max(1, int(L/seg))
            path += [(ax+(bx-ax)*i/n, ay+(by-ay)*i/n, (bx-ax)/max(L, 1e-6), (by-ay)/max(L, 1e-6)) for i in range(n)]
        path.append((*pts[-1], 0, 0)); ph = s.rng.uniform(0, 100); P = []
        for i, (x, y, tx, ty) in enumerate(path):
            off = (math.sin(ph+i*.7)*.5 + s.rng.uniform(-.5, .5))*wobble
            w = width*(.7+.55*(math.sin(ph*1.7+i*.35)*.5+.5))*s.rng.uniform(.85, 1.12)
            t = i/max(1, len(path)-1); w *= .45 + .55*min(1, min(t, 1-t)*5) if len(path) > 6 else 1
            P.append(((x-ty*off)*SS, (y+tx*off)*SS, w*SS))
        layer = Image.new("RGBA", s.img.size); d = ImageDraw.Draw(layer); c = color + (alpha,); prev = None
        for x, y, w in P:
            if prev: d.line([prev, (x, y)], fill=c, width=max(1, int(w)))
            d.ellipse((x-w/2, y-w/2, x+w/2, y+w/2), fill=c); prev = (x, y)
        if width >= 1.6 and alpha >= 150 and len(P) > 3:      # dry-brush ghost
            k0 = s.rng.randint(0, len(P)//3); k1 = min(len(P), k0 + s.rng.randint(len(P)//3, len(P))); gp = None
            for x, y, w in P[k0:k1]:
                q = (x+.9*SS, y+.7*SS)
                if gp and s.rng.random() > .12: d.line([gp, q], fill=color+(int(alpha*.38),), width=max(1, int(w*.45)))
                gp = q
        s.img = Image.alpha_composite(s.img, layer)
    def ink_poly(s, poly, width=2.2, **kw): s.ink(list(poly)+[poly[0]], width, **kw)
    def shade(s, m, dx=1.0, dy=0.6, spacing=4.5, alpha=95, angle=-55, reach=0.55):
        x0, y0, x1, y1 = m.getbbox(); W, H = s.img.size; yy, xx = np.mgrid[0:H, 0:W]
        u = ((xx-x0)/max(1, x1-x0)-.5)*dx + ((yy-y0)/max(1, y1-y0)-.5)*dy
        side = np.clip((u+.5-(1-reach))/max(.05, reach), 0, 1)
        sm = Image.fromarray((np.asarray(m, np.float32)*side).astype(np.uint8), "L")
        layer = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(layer); a = math.radians(angle)
        ddx, ddy = math.cos(a), math.sin(a); L = W + H; k = -L
        while k < L:
            o = k + s.rng.uniform(-.6, .6)*SS; cx, cy = W/2 - ddy*o, H/2 + ddx*o
            d.line([(cx-ddx*L, cy-ddy*L), (cx+ddx*L, cy+ddy*L)], fill=INK+(alpha,), width=SS); k += spacing*SS
        clip = Image.new("RGBA", (W, H)); clip.paste(layer, (0, 0), ImageChops.multiply(sm, layer.split()[3]))
        s.img = Image.alpha_composite(s.img, clip)
    def soft_shadow(s, box, alpha=120, blur=8):
        m = Image.new("L", s.img.size, 0); ImageDraw.Draw(m).ellipse([v*SS for v in box], fill=alpha)
        layer = Image.new("RGBA", s.img.size, (20, 18, 12, 0)); layer.putalpha(m.filter(ImageFilter.GaussianBlur(blur*SS)))
        s.img = Image.alpha_composite(s.img, layer)
    def finish(s, outline=2.6, burn=0.32, grain=0.05):
        a = s.img.split()[3]; A = np.asarray(a, np.float32)/255; H, W = A.shape
        thin = np.asarray(a.filter(ImageFilter.MaxFilter(max(3, int(outline*SS*.7) | 1))), np.float32)/255
        thick = np.asarray(a.filter(ImageFilter.MaxFilter(max(3, int(outline*SS*1.5) | 1))), np.float32)/255
        n = value_noise(W, H, 9*SS, s.seed+991)
        ring = np.clip(np.where(n > .5, thick, thin) - A, 0, 1)*(.7 + .3*(np.random.default_rng(s.seed).random((H, W)) > .08))
        blur = np.asarray(a.filter(ImageFilter.GaussianBlur(5*SS)), np.float32)/255
        edge = np.clip((A-blur)*2.2, 0, 1); topd = np.linspace(.9, 1.06, H)[::-1][:, None]
        rgb = np.asarray(s.img, np.float32)[..., :3]*(1-edge[..., None]*burn)*topd[..., None]*(1+(n-.5)*2*grain)[..., None]
        tot = np.clip(A+ring, 0, 1); out = (rgb*A[..., None] + np.array(INK)*ring[..., None])/np.maximum(tot, 1e-6)[..., None]
        s.img = Image.fromarray(np.dstack([np.clip(out, 0, 255), tot*255]).astype(np.uint8), "RGBA")
    def save(s, path, finish=True):
        if finish: s.finish()
        s.img.resize((s.w, s.h), Image.LANCZOS).save(path)
```

Usage pattern (from RT generators): `m = c.fill(poly, colour)` → `c.shade(m, 1, 0.6, 4.5, 85)` →
details with `c.ink(...)` → `c.ink_poly(poly, 2.2)` → `c.soft_shadow(...)` (call this first so it sits
underneath) → `c.save(path)`.

### 5.2 Figures

- Build bodies from tapered capsules along joint paths (shoulder → elbow → wrist with widths like
  13 → 11 → 9 px at source scale) and Catmull-Rom spline torsos.
- About 5.5 heads tall. Minimal faces.
- One illustration per facing: down, up, side (flip for left). Animate procedurally (§7).

### 5.3 Contact shadow

Ellipse under the base, alpha 110–140, blur 4–16 px (source scale), colour (20, 18, 12).

### 5.4 Grain and fog textures

- **grain:** 256² seamless value noise (cell 8, 3 octaves), `v = 128 + (n − .5)·70 + (white − .5)·60`,
  greyscale.
- **fog:** 512² seamless value noise (cell 180, 4 octaves, plus a cell-60 layer);
  `alpha = clamp((n·0.8 + n2·0.4 − 0.45)·2.2)·200`, RGB a pale neutral.
- Both must tile (wrap the noise grid).

### 5.5 Ground tiles

- 512² seamless value noise, 4–5 octaves, mapped through **three colours** (dark → mid → light) of one
  material, × (0.94–1.06) white noise.
- Add 50–300 tiny inked marks drawn at all 9 wrap offsets: blades, stones with a light edge, cracks,
  twigs.
- Optional soft-edged patches of a second material: threshold the noise at about 0.6 with a 0.06–0.1
  feather.
- No `finish()`. Display size 384–512 px.

---

## 6. Wind sway shader (RT `sway.gdshader`, verbatim)

```glsl
shader_type canvas_item;
uniform float strength = 2.2;
uniform float speed = 1.3;
void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float phase = world.x * 0.013 + world.y * 0.007;
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + phase) * strength * top * top * 3.0;
}
```

Apply it to vegetation only, with one shared `ShaderMaterial`. The base stays planted.

---

## 7. Motion recipes (RT)

| Effect | Values |
|---|---|
| Walk bob | `sprite.offset.y = -abs(sin(t*12)) * 6 / scale.y` while moving |
| Hit flash | `modulate = WHITE.lerp(Color(1.9, .55, .5), f)`, f decays 3/s |
| Weapon swing | rotation −1.3 → +1.2 rad in 0.14 s (TRANS_QUAD) |
| Uneasy idle (for unsettling characters) | held lean ±0.09 rad + sin sway 0.02–0.06 + occasional ±0.16 rad jerk every 1.5–6 s |
| Drifting particles | `CPUParticles2D` with the values below |

Drifting particle settings:
- amount 70, lifetime 14, preprocess 14
- rect emission covering the playable area
- direction (0.35, 1), spread 20°, gravity (3, 6), velocity 10–26
- scale 0.25–0.6, colour alpha 0.8, `z_index` 20
- texture: a 24² soft dot
- Swap direction and gravity for your setting: seeds drifting sideways, dust, ash, pollen, snow.

---

## 8. UI

- Flat `StyleBoxFlat` theme, deliberately calm:
  - dark charcoal panels at 94 % opacity with a thin warm-light border at 35 %
  - radius 4–6
  - one accent colour for "pressed" or "danger"
- Use the **default Godot font** or any open-licence humanist sans. The look does not depend on a font.
- In-world labels get a 4–8 px black outline at 80–90 %.
- Keep the illustration in the world, not in the UI.
- Put the UI on `CanvasLayer` 10, above the grade, so it is never graded.

---

## 9. Performance notes (RT measurements and design)

- The grade is a single full-screen pass with 3–5 texture reads. It is cheap even on Compatibility.
- One shared sway material; per-object phase comes from world position, so there are no per-object
  materials.
- Scatter dressing is generated once from a seed; nothing is re-randomised per frame.
- `CPUParticles2D` with 70 particles is negligible.
- Occlusion checks run only on props flagged `occlude`.
- **NEW RECOMMENDATION:**
  - Keep large sprite sources ≤ 1024 px per side.
  - Mark decorative props so they do not enter pathfinding grids. In RT, 91 decorative trees once
    blocked AI routes; it was fixed with a `nav_block = false` flag.

## 10. Common pitfalls

| Pitfall | Effect | Fix |
|---|---|---|
| Nearest texture filter | Looks like pixel art | Use Linear |
| Pure black outlines | Harsh, digital | Use warm near-black `#211B15`, varying width |
| Uniform line width / no taper | Vector look | Taper and jitter every line |
| Finish pass on ground tiles | A grid of outlined squares | Never finish tiles |
| Grading the UI | Muddy, unreadable HUD | UI on a higher CanvasLayer |
| Screen-anchored fog | Fog slides with the camera | Anchor with the canvas transform |
| Saturation > 0.9 or contrast > 1.15 | The texture turns cartoonish or noisy | Stay within ranges |
| Many hues per material | Busy and noisy | One base hue; vary value and warm/cool |
| Dynamic 2D shadows | Fight the baked shadows | Bake contact shadows only |
| Sprite origin at centre | Wrong y-sort | Origin = ground contact (pivot) |

---

## 11. Minimal reference scene (acceptance test)

**NEW RECOMMENDATION:** build this before any real content.

1. A 2400×1700 area. One ground `Polygon2D` with a 512² generated ground tile (pick any material), plus
   one road or path polygon in a second material.
2. In `YSort`:
   - one small building (440×410 display, pivot ≈ 0.96) made with `fill` + `shade` + inked planks +
     `finish`
   - three trees or tall plants (sway, occlude)
   - 40 scattered small plants (seeded)
   - one human figure (52×84, pivot 0.952) with walk bob
3. `CanvasModulate` (1.0, 0.97, 0.90) by day, (0.20, 0.24, 0.36) at night.
4. The grade on `CanvasLayer` 5 with the neutral-warm preset; drift particles; one warm `PointLight2D`
   by the door.

**Pass criteria:**
- With the grade switched off, sprites still read as hand-inked: tapered wobbly lines, broken
  silhouettes, mottled fills, hatching on the lower right.
- With the grade on, the image is cohesive, slightly desaturated, edge-darkened and grainy.
- The player walking behind the building fades it to about 0.42 alpha, and walking in front draws the
  player over it.
- At night the single warm glow is the clear focal point.
- Swapping the ground palette and the plant species (another setting) keeps all of the above true.
