# Red Thaw — Setting-Specific Art Direction (exclude or adapt)

Everything here belongs to **Red Thaw's setting**: nuclear winter, northern pine wilderness, burned
ruins, cold fog, human-madness horror. It is layered **on top of** the portable DNA in
[`VISUAL_DNA.md`](VISUAL_DNA.md). A project in another setting should **not** import any of it.
Each item says whether to discard it or how to adapt it.

Source branch: `iteration/010-red-thaw` @ `497d840`. Labels as in `VISUAL_DNA.md`: **[VERIFIED]**,
**[INTERPRETATION]**, **[NOT IMPLEMENTED]**.

---

## 1. The winterize layer [VERIFIED] — discard (or rewrite for your setting)

`tools/art/inkkit.py: Canvas.winterize(depth=10, cold=0.42, frost=0.6, kill_green=True)` runs on save for
any sprite whose path matches the `OUTDOOR` list. It does four things:

1. **Living green → dead straw.** Pixels where green exceeds both red and blue are blended toward
   (140, 128, 108) × brightness.
2. **Cold grade.** 42 % desaturation toward luminance, then a channel multiply of (0.93, 0.97, 1.03).
3. **Snow cap.** Every upward-facing edge (an opaque pixel with transparency 2 px above) grows a white
   cap (216, 219, 217):
   - noise-varied depth up to 10 px
   - a blue-grey shaded lower band (150, 162, 168)
   - a lumpy overhang rim above the surface
   - a thin ink line under the cap
4. **Frost speckle** on about 0.7 % of opaque pixels.

**Adapt:** this is a good *pattern*, a final "setting pass" applied uniformly to every outdoor sprite so
the whole set agrees on the environment. Replace its content with your setting:

| Setting | Replacement setting pass |
|---|---|
| Autumn | Leaf-litter tint |
| Desert | Dust film |
| Wetland | Wet darkening at the base |
| City | Soot |

Never ship the winter version outside a winter setting.

## 2. Palette [VERIFIED] — discard; keep only the *structure*

Measured from the Red Thaw generators (`tools/art/gen_winter.py`) and rendered screenshots:

| Family | Values |
|---|---|
| Snow | `#E6E8E4` light, `#D6D9D7` base, `#A7B1B6` shade, `#7D898F` deep |
| Ice | `#AEBEC5` |
| Charcoal / ash | `#1E1C1B`, `#34302D`, `#6B6865`, `#8E8B86` |
| Pine | `#18231F`, `#26352E`, `#36483E`, `#52635A` |
| Faded timber | `#3E3329`, `#5C4C3E`, `#76644F`, `#94826B` |
| Rust | `#4E2A22`, `#73392A` |
| Blood (reserved accent) | `#8A1C18`, `#4E1412`; on figures `#561814` / `#30100E` |
| Frozen mud | `#5A4F44`, `#776B5D`, `#968A7A` |

**Rendered result** (dominant colours sampled from screenshots):
- Exterior day (`r04_frozen_pine_woods`): `#A9B6C7 #9AA6B6 #8E9AA9 #575C61 #393F45 #232A2D`
- Night (`r10_settlement_night`): `#303748 #2A3140 #14171D`
- Cabin interior (`r06_cabin_interior`): `#946E48 #6F583C #3C3022`

**Keep the structure:**
- one dominant ambient family (here cold blue-grey)
- one warm family reserved for shelter and light
- one high-chroma accent reserved for meaning (here red)
- three-step ramps per material

## 3. Grade and light values [VERIFIED] — adapt

| Value | Red Thaw | What to do |
|---|---|---|
| Exterior grade | saturation 0.70, shadow tone (0.84, 0.90, 0.98), highlight tone (0.98, 1.0, 1.04), vignette tone (0.42, 0.45, 0.50) | Cold split tone is setting-specific. Use the neutral-warm preset from the guide as your start |
| Exterior day modulate | (0.86, 0.90, 0.96), blue-shifted | A neutral day (1.0, 0.97, 0.90) was used before the winter conversion |
| Fog | strength 0.22, colour (0.80, 0.83, 0.86) | The fog *technique* is portable (world-anchored, two-scale drift). Strength and colour are setting choices; use 0 for clear settings |
| Weather overlay | 220 drawn snow circles, depth-banded | Technique portable (screen-space drawn particles); swap to rain streaks, ash or dust |
| Drift particles | snowflakes, direction (0.35, 1), gravity (3, 6) | Swap texture and direction: seeds, pollen, embers |
| Warm interior | saturation 0.85, highlight (1.08, 1.0, 0.86) | The warm-shelter contrast is a good general device; tune it to your setting |

## 4. Subject matter [VERIFIED] — discard

- **Environment:**
  - snow, frozen-mud and snowy-road tiles
  - snow-laden pines; bare birch; frozen shrubs; dead grass; snowy stump
  - icicles; snow drifts at bases; frosted windows (frost creeping from the corners)
- **Buildings:**
  - hunter's cabin (logs, round log ends, heavy snow roof, antlers, snowshoes, firewood, stovepipe)
  - burned shed (charred planks with alligatored cracks, fallen beams, ash ring)
  - woodshed; boarded houses with blocked doors; collapsed house
- **Props:** snowed-in pickup and sedan; child's sled; starter bag; thawed-blood decal.
- **Characters:**
  - the survivor in a faded blue-grey parka and knit hat
  - the frightened survivor's huddled pose
  - the night silhouette (a blurred flat-black human shape)
- **Map:** cold-grey field-map paper with pine-tree symbols.

**Adapt only the composition lessons:**
- a landmark building with a fixed door opening so the door sprite and collision align
- a contact shadow plus a base-clutter fringe on every building
- a setting-pass layer (§1)

## 5. Horror presentation [VERIFIED] — discard unless you make horror

- **Hostile figures ("Burnt Ones"):**
  - damaged dark coats with jagged tatters
  - burn patches (a charred core inside a raw red rim)
  - dried / frozen blood blots with drips and rime dots
  - a hood with an elliptical shadow hiding the eyes (`tools/art/gen_figures.py: burnt()`)
- **Body language** (`zombie_view.gd`):
  - a held wrong lean
  - occasional sudden jerks
  - a red-tinted wind-up before attacking
- **Atmospheric omens** (`omen_sim.gd`, `omen_view.gd`):
  - unseen positional laughter by day
  - a brief silhouette crossing paths at night, depth-sorted so buildings hide it
- **Frightened NPC:** a trembling huddled pose and fragmented whispered lines.
- **Red Thaw motif:** red reserved for blood and thawed traces; everything else desaturated.

**Portable lesson** **[INTERPRETATION]:** the *restraint* is the transferable part:
- small, rare, desynchronised motion
- one reserved accent colour
- hidden faces rather than gore

## 6. What is NOT setting-specific (keep)

These stay, whatever the setting. All are in `VISUAL_DNA.md` and the guide:
- the brush-pen ink and the warm near-black colour
- mottled painterly fills with warm/cool drift
- shadow-side hatching, grime and drips
- the `finish()` silhouette, edge burn and grain
- the 2× source convention, pivots and fit-to-box
- 3/4 top-down with y-sorting by ground point; occlusion fade
- the full-screen grade structure (saturation, contrast, split tone, tinted vignette, grain)
- global `CanvasModulate` plus soft radial point lights
- the sway shader; slow drifting particles
- the calm flat UI on an ungraded layer

## 7. Not to be confused with the moodboard

The original moodboard (`docs/visual_direction/ZS2D_Moodboard_v01.png`) predates Red Thaw and shows a
lush, warm, overgrown, painterly-perspective world. **It is neither the delivered Red Thaw look nor the
portable DNA.** Do not reproduce its composition, camera or saturation.
