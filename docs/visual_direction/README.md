# Visual Direction

This folder is the single home for ZombieSurvival2D visual-direction material.

| File | Role |
|---|---|
| [`ZS2D_Visual_Direction_v01.md`](ZS2D_Visual_Direction_v01.md) | Creator's specification v0.1. **Authoritative**; preserved unchanged. |
| [`ZS2D_Moodboard_v01.png`](ZS2D_Moodboard_v01.png) | Moodboard v0.1 (1536×1024). Concept and mood art only, preserved unchanged. |
| `README.md` (this file) | Index, decision register, sampled palette reference, reconciliation notes. |

If this README and the v0.1 specification disagree, **the specification wins**. Fix this README.

## How to read the moodboard

**Take from it:** palette, illustrative texture, lighting contrast and atmosphere.

**Do not take from it:** camera perspective, framing, composition, character proportions, scale,
or any specific content (POIs, props, equipment, biomes as a content list).
The board's over-the-shoulder hero shot, cutaway bunker room and wide landscape panels are
illustrative framings. They are not evidence for any gameplay view.

## Decision register

Status meanings: **APPROVED** means the creator decided it. **EXPLORING** means a candidate is under
discussion and not yet decided. **DEFERRED** means it is deliberately postponed.

### APPROVED

| ID | Decision | Source |
|---|---|---|
| VD-01 | Overall palette direction: muted natural greens, olive and moss, faded gold and straw, earth brown, aged rust, soot and charcoal, with occasional cool machine light. Keep gentle colour variation; the surface must not turn uniformly brown or grey. | Spec §Carry forward |
| VD-02 | Overall atmosphere and visual north star: a beautiful world reclaiming itself. Handmade human shelters that are worth returning to. Precise, alien AI threats. | Spec §Visual north star |
| VD-03 | Surface mood: mostly quiet melancholy. Nature is alive. Overgrown woodland, farmland, marsh and rural outskirts. | Spec §Carry forward |
| VD-04 | Danger gradient: towards the scorched fringe and AI patrol boundaries, vegetation thins, colours turn ashen, silhouettes sharpen and the mood moves to low-grade dread. Dead zones are lethal and non-playable, not urban maps. | Spec + moodboard "Mood progression" |
| VD-05 | Bunker mood: warm amber practical lighting, improvised repairs, worn steel, concrete and wood, personal objects. Plausible and lived-in, not sleek sci-fi. | Spec §Carry forward |
| VD-06 | AI visual language: crisp utilitarian silhouettes, colder materials and light, deliberately out of place among organic growth. | Spec §Carry forward |
| VD-07 | Illustration style: hand-drawn, **non-pixel** art, with expressive irregular ink, textured surfaces and restrained illustrated shadows. It must be readable at gameplay scale and practical to draw on a tablet. | Spec §Carry forward |
| VD-08 | Lighting contrast as a mood device: warm amber shelter versus cool cyan and steel machine light, and living daylight versus ashen red-grey scorched light. | Spec palette and mood notes |
| VD-09 | Tonal exclusions: not Gothic horror, not retro pixel art, not a generic Fallout wasteland. | Spec §Do NOT infer |

Project-level decisions from [`../HANDOVER.md`](../HANDOVER.md) §1.2 stay **APPROVED** and are not
affected by this reference. These are: 2D presentation, required multiplayer, Godot/GDScript,
creator-replaceable art and audio through the `template_`/override convention, persistent progression,
and creative freedom.

### EXPLORING

| ID | Open question | Notes |
|---|---|---|
| VX-01 | Gameplay perspective | Still open. The handover lists top-down, side-on, angled and hybrid. The spec names top-down vs shallow-angle 2.5D as the options not to lock. No view is chosen. See conflict C-2. |
| VX-02 | Surface/bunker presentation and spatial relationship | Still open: same view, separate scene, cutaway or hybrid. The moodboard's bunker panel is mood only. |
| VX-03 | Exact palette values | The hex samples below are a working reference only. A formal palette with ramps per biome and per lighting state is undecided. |
| VX-04 | Biome set | The board shows forest, farmland, marsh, mountain/rocky and scorched fringe as examples, not as approved content. |
| VX-05 | Lighting pipeline | Baked into the art, painted overlays, Godot 2D lights, or a mix. Not decided (spec: "do not lock lighting pipeline"). |
| VX-06 | Sprite dimensions, tile size, line weight at gameplay scale | Not decided. The handover's ~2× source-resolution guideline (§8.5) still applies as a ratio once display sizes exist. |
| VX-07 | Day/night and weather colour treatment | Not addressed by the reference. |
| VX-08 | UI visual theme (fonts, panels, icon style) | The board's typography and paper-label panels are presentation-board styling and are not approved as UI. |
| VX-09 | Readability rules for threats and interactables against textured backgrounds | Required by the spec ("readable at gameplay scale") but not yet defined. |

### DEFERRED

| ID | Item | Notes |
|---|---|---|
| VF-01 | Zombie visual design | Deliberately deferred by the spec. Infer nothing from the board. |
| VF-02 | Expanded world canon (rogue AI history, active shelters, drones) | Context for visual consistency only. Do not expand it without design discussion. |

## Sampled palette reference (EXPLORING)

These values were sampled from the centre of each swatch in the moodboard's "Palette (Directional)"
panel. They are **approximate**: JPEG-like texture and painted swatches shift values by a few points.
Use them to stay in the right family, not as locked colour values.

| Group | Swatches, left to right |
|---|---|
| Nature / Living World | `#52502C` `#7A733F` `#998A57` `#CFB88D` `#B3A177` `#827D68` |
| Human / Built | `#7B5538` `#C69464` `#BF8354` `#954C33` `#6A372C` `#61615E` |
| AI / Tech | `#A29791` `#6C6C6B` `#454949` `#2E3E45` `#346773` `#59C0C2` |
| Scorched / Contamination | `#212120` `#493E3E` `#85645F` `#9F6558` `#A75643` `#8C4334` |

The cyan `#59C0C2` is the only high-saturation accent on the board. Keeping it rare is what lets it
mark machine presence.

## Reconciliation with existing guidelines

Before this reference arrived, the repository's only visual guidance was in
[`../HANDOVER.md`](../HANDOVER.md): §8 (Sprite Workshop and asset replacement), §12.4
(environmental presentation separated from simulation), §16.3–16.5 (UI theme and in-world interfaces)
and §28 (open decisions). The handover had no palette or style rules, so most of this reference is
additive. These are the points of tension:

| ID | Topic | Existing guidance | Reference | Resolution |
|---|---|---|---|---|
| C-1 | Atmosphere | Handover §28 lists atmosphere as open: grounded horror, grim survival, stylized adventure, dark humour or a mixture. | Approves quiet melancholy that escalates to dread, and excludes Gothic horror and generic wasteland. | The reference settles the **visual** atmosphere (VD-02, VD-09). Overall game tone, including humour and narrative voice, remains a design topic. |
| C-2 | Perspective candidates | Handover §1.2 and §28: top-down, side-on, angled or hybrid. | The spec's "do not lock" list names only top-down vs shallow-angle 2.5D, and calls side-view a framing not to copy. | **Unresolved; flagged for the creator.** Nothing is excluded until the creator decides. All handover options stay EXPLORING (VX-01). |
| C-3 | Threat identity | The handover is framed around zombies (title, §1.1, §28 "Zombie threats"). | The board shows no zombies. Its active threat is a rogue AI with drones and patrols, and zombie design is deferred. | Not a contradiction. It does mean the antagonist mix (zombies, AI or both) is a **design question** that needs an answer before threat art starts. No visual direction for zombies exists yet (VF-01). |
| C-4 | World content | Handover §1.1: "scavenging buildings and abandoned locations", a "post-apocalyptic world". | Rural outskirts and biomes. Annihilated settlements are non-playable craters, not urban maps. | Compatible. Scavenge sites are rural and outskirts buildings. Any future dense-urban content would conflict with VD-04 and needs a creator decision. |
| C-5 | Environmental hazards | Handover §12 lists contamination, radiation, smoke and fire as possibilities. | Shows a "Scorched / Contamination" palette and ashen fringe zones. | Compatible. The reference gives these hazards a colour language if they are approved. It does not approve them as mechanics. |
| C-6 | Art resolution | Handover §8.5: ~2× source-art resolution. | "Do not lock sprite dimensions or tile size." | Compatible. 2× is a ratio applied once display sizes are chosen (VX-06). |
| C-7 | Earlier recommendation | In chat (not committed), I suggested side-on for the bunker and top-down for the surface. | Keep perspective and surface/bunker presentation undecided. | That was a suggestion only and was never approved. It is withdrawn as a recommendation pending the creator's perspective discussion. |

The reference does not conflict with the asset-replacement architecture (§8, §9). Hand-drawn,
non-pixel art fits the `template_`/override convention, and the ~2× source-art guideline suits
tablet-drawn work.

## Prototype findings (iteration 001)

The first playable homestead (see [`../iterations/001_foundation.md`](../iterations/001_foundation.md)
and `../screenshots/iteration_001/`) **tried** these EXPLORING options. None of them is approved yet:

| Register item | What the prototype used |
|---|---|
| VX-01 Perspective | 3/4 top-down (oblique) view. Ground-plane data model, so the view can still change. |
| VX-02 Surface/bunker | Bunker entrance shown as a hatch in an earth mound inside the farmyard. No interior. |
| VX-05 Lighting | Shadows baked into the art, warm global tint, paper-grain and vignette overlay. No 2D lights. |
| VX-06 Scale | Survivor 52 × 84 display px (about 40–45 px per metre). Farmhouse 440 × 410. Art drawn at 2×. |
| VX-09 Readability | Name labels, inked outlines, occlusion fade behind tall objects, focus tint on interactables. |

All illustrations are **generated placeholders** (`tools/art/`) in the APPROVED palette. They are
meant to judge scale and mood, not as final art.

## Visual overhaul findings ("dirty ink" pass)

The visual overhaul (branch `art/visual-overhaul`, see
[`../iterations/visual_overhaul.md`](../iterations/visual_overhaul.md) and
`../screenshots/visual_overhaul/`) redrew the placeholder art toward VD-01 to VD-07. Gameplay
perspective, sprite sizes, pivots, layering and collision did not change. It **tried** these EXPLORING
treatments. None of them is approved yet:

| Register item | What the overhaul used |
|---|---|
| Line | Rough, noise-modulated ink silhouette ring and inner edge burn on every sprite. Tapered, dry-brush strokes. |
| Colour / material | Painterly fills: value noise, warm-light / cool-shadow hue drift, paper fibre. Weathered grey-brown wood instead of orange timber. |
| Shading | Ink hatching on the shadow side only, plus grime, rain streaks and moss. |
| Nature reclaiming | Moss carpets, ivy, corner shrubs and weeds on the farmhouse, shed and station buildings. Inked grass tufts and straw patches in the meadow. |
| Figures | Survivor and zombie rebuilt with natural proportions (about 5.5 heads, tapered limbs, curved torsos). The zombie look is a placeholder only, because zombie design is DEFERRED. |
| VX-05 Lighting | Screen-space world grade: S-curve contrast, slight desaturation, cool shadows, warm highlights, an ink-brown vignette and paper grain. The HUD is not graded. |

## Red Thaw visual direction (iteration 010)

The concept changed to **Red Thaw**: a nuclear winter in a northern pine wilderness, with human madness
instead of zombies. The dirty-ink illustration language carries over: hand-drawn non-pixel art,
expressive irregular ink, strong silhouettes, muted colour, deliberate shadow shapes, controlled texture
and readability at gameplay scale. The setting palette and mood replace the overgrown, living-nature
direction.

| Status | ID | Item |
|---|---|---|
| APPROVED | RT-01 | Nuclear-winter northern pine wilderness: frost-covered ground, snow-laden pines, snowy forest floor, frozen mud and slush, dead brittle grass, charred timber, weathered buildings, frosted vehicles, blackened ruins, cold washed-out daylight, cold fog. It replaces VD-01 to VD-03 (lush greens, nature reclaiming) |
| APPROVED | RT-02 | Restrained palette: icy blue-grey, dirty white, charcoal, muted pine green, faded timber brown, dark rust. Stronger red is kept for meaningful details (blood, the local player's map ring) |
| APPROVED | RT-03 | Warm light is rare and meaningful: the cabin interior, the stove and the powered bunker are graded warm, and everything outside is cold. It refines VD-05 and VD-08 |
| APPROVED | RT-04 | Burnt Ones: human survivors in damaged winter clothing, with scarred or burned skin, dried and frozen blood, ragged silhouettes and unnatural but plausible body language. Faces are restrained (a hood shadow hides the eyes). No demons, no supernatural. This settles the old VF-01 at concept level |
| APPROVED | RT-05 | Hunter's cabin instead of the farmhouse: timber, modest, weathered, snow on the roof, sparse interior, quiet traces of past occupation (antlers, empty rifle pegs, snowshoes) |
| APPROVED | RT-06 | The burned shed is the opening landmark: charred, partly collapsed, ash and frost, blackened debris, snow drifting around it, a fire long out |
| APPROVED | RT-07 | World map as a weathered, hand-inked field map: pine-symbol forests, pale clearings, contour hints, tracks, sparse buildings, ruin marks, restrained typography |
| EXPLORING | RTX-01 | Winter treatment of generated templates. inkkit's winter pass settles snow on the upward-facing surfaces of every outdoor sprite, adds frost, turns living green dead and cools the palette. Key assets are hand-composed (gen_winter, gen_figures) |
| EXPLORING | RTX-02 | Lighting. Outdoors: a screen-space cold grade (desaturation, cool split toning), world-anchored drifting fog, slow snowfall and a cold ink vignette. Snowfall replaces the old rain spell. Indoors and in the bunker: a warm grade. No 2D light pipeline yet |
| EXPLORING | RTX-03 | Burnt One exact design. The placeholder is built on the earlier figure body; it is not a final character design |
| EXPLORING | RTX-04 | The frozen-blood "red thaw" motif appears only as small cosmetic illustration (RX-05 in the gameplay register) |
| DEFERRED | RTF-01 | VD-06 (AI visual language) and VF-02 (rogue-AI canon) are on hold. Red Thaw has no AI antagonist |

## Rules for future visual work

- Make new mockups in the APPROVED palette and material language, translated into whatever perspective
  is eventually chosen. Each perspective mockup is EXPLORING until the creator approves it.
- Placeholder (`template_`) art should follow VD-01 to VD-07 closely enough that replacing it
  piece by piece does not produce jarring mixes.
- Never overwrite or "correct" creator-made art to match this document.
- Bump the version for any revision (e.g. `ZS2D_Visual_Direction_v02.md`) and keep the earlier file.
