# Portable Visual Prompt (copy-paste into Claude Code in another Godot project)

The block below is self-contained. It encodes the verified "dirty ink" visual DNA extracted from
Red Thaw, **without** its setting, gameplay or story. If the other project can also see
`VISUAL_DNA.md` and `GODOT_REPRODUCTION_GUIDE.md`, mention them; they hold the full shader and a
runnable Python reference kit.

---

```text
Reproduce a hand-inked "dirty ink" 2D illustration style in THIS Godot 4.x project. Visual style only:
do not change gameplay, and do not introduce any setting, story or genre of your own. Keep this
project's subject matter (environment, characters, palette family) and apply the style to it. Before
editing, verify the repository and branch, and keep changes small and reversible.

LOOK IN ONE LINE: hand-drawn (never pixel) sprites in a 3/4 oblique top-down view; mottled painterly
fills; diagonal ink hatching on the shadow side; wobbly, width-varying, tapered brush-pen linework in
warm near-black; a rough, slightly broken ink silhouette around every sprite; a full-screen grade with
mild desaturation, contrast, split toning, a tinted vignette and paper grain; soft radial light glows;
gentle desynchronised motion.

1. PROJECT SETTINGS
   - Canvas texture filter: Linear (never Nearest).
   - Base viewport 1280x720, stretch mode canvas_items, aspect expand.
   - Compatibility renderer is enough.
   - No WorldEnvironment glow, no HDR 2D, no LightOccluder2D shadows.

2. SCENE STRUCTURE
   - Ground Polygon2D patches with repeating 512px tiles at z_index -10.
   - Floor decals at z_index -1.
   - ONE y_sort_enabled node holding every standing object and actor. Each node's origin is its
     GROUND-CONTACT point.
   - Drift particles at z_index 20. CanvasModulate for the global light colour.
   - Full-screen grade ColorRect on CanvasLayer 5. UI on CanvasLayer 10 (never graded).
   - Every asset has three values:
     - display_size: the in-game box
     - pivot: the ground point as a fraction of the box
     - source_size: about 2x display
   - Fit any texture into its box keeping aspect: scale = min(box/tex); centre horizontally;
     bottom-align; position = -box*pivot + ((box.x-drawn.x)/2, box.y-drawn.y).
   - Collision is a separate base rectangle ("footprint"), never derived from art.
   - Scale reference: a human is 52x84 display px (about 40-45 px per metre); a small house is
     about 440x410.

3. CAMERA
   - Camera2D (top_level) follows player + (0,-24) with lerp(1 - exp(-6*delta)).
   - Zoom default 1.0, range 0.5-2.5, x1.1 per step.
   - Areas smaller than the view are centred; larger ones are clamped to their bounds.
   - Occlusion: a tall prop fades to alpha 0.42 (move_toward at 3/s) while the local player stands
     behind it. Behind = player above the prop's base line (local.y < -4) and (player + (0,-30))
     inside the art rectangle inset 8 px on the left and right.

4. SPRITE PIPELINE (ink lives in the images; hand-drawn or generated)
   Draw at 2x display size. If you generate placeholders with Python/Pillow/numpy, also supersample
   2x and downsample with Lanczos. For every sprite:
   a) FILL: flat base colour multiplied by
        shade = 1 + (n-0.5)*1.3*tex + (white-0.5)*1.6*0.06 + (fibre3px-0.5)*0.07
      - n is value noise at cell 5-30 px; tex is 0.25-0.4.
      - Add a warm/cool hue drift from a 3x-coarser noise plus a directional light term
        (light from the UPPER LEFT, strength 0.3): lit side lighter and warmer, far side darker and
        cooler.
        warm = base*0.82 + (214,176,112)*0.18
        cool = base*0.80 + (46,52,50)*0.20
        mix weights: 0.45 warm, 0.55 cool
   b) SHADOW HATCHING: parallel ink lines, 1 px, spacing 4.5 px, angle -55 deg, alpha 95/255, only
      on the part of the shape facing lower-right (the 55% of the shape farthest from the light).
      Optional cross-hatch at +85 deg in the deepest part.
   c) LINEWORK in INK = (33,27,21):
      - Resample each path every 6 px. Perpendicular jitter = (0.5*sin(phase+0.7i) + U(-0.5,0.5))
        * 0.9. Width = base * (0.7 + 0.55*(0.5 + 0.5*sin(1.7*phase + 0.35i))) * U(0.85,1.12).
      - Open strokes taper: w *= 0.45 + 0.55*min(1, 5*min(t, 1-t)).
      - Draw round-jointed segments on their own layer and alpha-composite.
      - For width >= 1.6, add a dry-brush ghost: 38% alpha, 45% width, offset (0.9, 0.7) px, over a
        random third of the stroke, with 12% gaps.
      - Weights: silhouettes 2.2-3.6 px, inner forms 1.4-2.0, texture marks 0.8-1.4 at alpha
        110-200.
   d) WEATHERING: noise-thresholded stains (max alpha 0.55) and a few vertical drips fading
      downward, sparse.
   e) CONTACT SHADOW: blurred ellipse under the base, colour (20,18,12), alpha 110-140, blur 4-16 px.
   f) FINISH (every sprite, never ground tiles):
      - Rough silhouette ring = alpha dilated by a max-filter of size 2.6*0.7 (thin) or 2.6*1.5
        (thick) in source px (x2 supersampling), chosen per pixel by value noise > 0.5, minus the
        original alpha. Fill it with INK; 8% of ring pixels at 70% opacity.
      - Inner edge burn: rgb *= 1 - 0.32*clamp((alpha - blur(alpha, 10px))*2.2).
      - Vertical darkening from 1.06 at the top to 0.90 at the base.
      - Grain *= 1 + (noise-0.5)*0.1.
   g) FIGURES: tapered capsule limbs along joint paths and spline torsos, about 5.5 heads tall,
      minimal faces. One illustration per facing (down, up, side; flip side for left). Motion is
      procedural.
   h) GROUND TILES: seamless 512px value noise (4-5 octaves) mapped through 3 colours of one material
      (dark/mid/light), x0.94-1.06 white noise, plus small inked marks drawn at all 9 wrap offsets.
      Lower contrast than the standing sprites. No finish pass.
   Rules: one base hue per material (vary value and warm/cool, not hue); muted earthy colours; light
   always from the upper left.

5. SCREEN GRADE (canvas_item shader on the ColorRect, reading hint_screen_texture)
     l = luma(c); c = mix(vec3(l), c, saturation);
     c = clamp((c-0.5)*contrast + 0.5, 0, 1);
     c *= mix(shadow_tone, highlight_tone, smoothstep(0.12, 0.8, l));
     v = smoothstep(0.32, 0.85, length((uv-0.5)*vec2(1, 0.8)));
     c = mix(c, c*vignette_tone, clamp(v*vignette_strength*1.8, 0, 1));
     c *= 1 + (grain(uv*screen_size/256) - 0.5)*grain_strength*2;
   Starting preset (neutral-warm): saturation 0.88, contrast 1.10, shadow_tone (0.88,0.94,0.96),
   highlight_tone (1.05,1.0,0.90), vignette_tone (0.50,0.45,0.38), vignette_strength 0.28,
   grain_strength 0.07. Indoor/shelter variant: saturation 0.85, highlight_tone (1.08,1.0,0.86),
   vignette 0.4-0.5. Keep saturation <= 0.9 and contrast within 1.05-1.12.
   Grain texture: 256px seamless grey value noise (cell 8, 3 octaves), v = 128 + (n-0.5)*70
   + (white-0.5)*60.
   Optional world-anchored fog:
     - sample the alpha of a 512px seamless noise texture at world_pos/900 + TIME*(0.006,0.002)
       and world_pos/1500 + TIME*(-0.004,0.003); sum x0.6 each
     - world_pos = (uv*screen_size - canvas_transform.origin)/canvas_transform.x.x, uploaded every
       frame
     - mix toward a pale neutral at fog_strength (0 for clear settings)

6. LIGHT
   - CanvasModulate is the time of day, lerped at 1 - exp(-1.5*delta). Neutral day (1.0,0.97,0.90),
     night (0.20,0.24,0.36), warm room (0.72,0.66,0.58), dark cellar (0.38,0.34,0.30).
   - PointLight2D glows with one shared 256px radial GradientTexture2D (white -> alpha 0.55 at 0.45
     -> transparent).
     - warm lantern (1.0,0.78,0.45), texture_scale 3.4, energy 1.0
     - bulb (1.0,0.95,0.82), texture_scale 3.6, energy 0.42
   - Shadows are baked contact ellipses only.
   - Warm light is rare and meaningful.

7. MOTION
   - Vegetation sway vertex shader:
       phase = world.x*0.013 + world.y*0.007
       VERTEX.x += sin(TIME*1.3 + phase)*2.2*(1-UV.y)^2*3
     One shared material.
   - Walk bob: offset.y = -|sin(t*12)|*6 px.
   - Hit flash: modulate toward (1.9,0.55,0.5), decaying 3/s.
   - Ambient drift particles (CPUParticles2D): 70, lifetime 14, preprocess 14, emission rect over the
     area, velocity 10-26, scale 0.25-0.6, alpha 0.8, z 20. Choose the texture and direction to suit
     THIS project's setting.
   - Scatter small vegetation with a fixed seed, avoid-rects and a minimum spacing.
   - Everything moves slowly and out of sync.

8. UI
   - Flat StyleBoxFlat: charcoal panels at 94% opacity, thin warm-light border at 35%, radius 4-6.
   - One accent colour for pressed or danger states.
   - The default font is fine. In-world labels get a 4-8 px black outline.
   - Keep the illustration in the world, not in the UI.

9. VERIFY
   Build a small test scene: ground tile, one building, three swaying plants, 40 scattered small
   plants, one figure, the grade, one warm light. Pass when:
   - with the grade disabled, sprites still read as hand-inked (tapered wobbly lines, broken
     silhouettes, mottled fills, lower-right hatching)
   - with the grade enabled, the image is cohesive, slightly desaturated, edge-darkened and grainy
   - walking behind the building fades it to about 0.42
   - at night the warm glow is the focal point
   Take screenshots, inspect them, and fix what fails before applying the style to real content.
   Never overwrite human-made art. Put new art in a replaceable template/override layout.
```
