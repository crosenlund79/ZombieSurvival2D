# Creator Asset Replacement Guide

You can replace any listed picture or sound **without touching code**. The game looks for your file
first and falls back to the built-in placeholder if your file is missing or unusable.

## 1. Find the asset you want to replace

Open the manifest for its category in `assets/manifest/`:

| File | Contains |
|---|---|
| `visual_characters.json` | survivor (down / up / side views) |
| `visual_world.json` | farmhouse, shed, farmhouse door, yard gate, fence segments |
| `visual_environment.json` | trees, shrubs, grass tufts, ground tiles, paper grain, drift particle |
| `visual_props.json` | car, bunker entrance, suitcase, wheelbarrow, sign, barrel |
| `visual_interior.json` | farmhouse floor, back wall, furniture, rug, exit mat |
| `visual_shelter.json` | shelter site (marked / digging), wooden hatch (closed / open), timber piles (empty → large) |
| `visual_bunker.json` | earth floor/wall, reinforcement (exposed / building / done), ladders, lantern, tools, concrete test level |
| `visual_ui.json` | world map paper |
| `audio.json` | door/gate, menu click, ambience loops (countryside, underground), chop, tree fall, wood stacking, digging, hammering, build done, hatch, ladder |

All current templates are **generated placeholders** (tools/art) waiting for your tablet art.

Each entry tells you: `template` (the placeholder file), `display_size` (how big it appears in game,
in game pixels), `source_size` (recommended drawing size — about 2× display), `pivot` (which point
touches the ground: `[0.5, 1.0]` = bottom centre), `transparency`, `directions`, and `status`.

Status meanings: **READY** = replacement tested and working · **ADAPTER_REQUIRED** = needs code
support before replacing works · **REFERENCE_ONLY** = listed for planning, not used in game yet.

## 2. Name and place your file

Take the template path, change `templates` to `overrides`, and remove `template_` from the file name.

    template:  assets/templates/characters/player/template_survivor_down.png
    yours:     assets/overrides/characters/player/survivor_down.png

Two places are searched, in this order:

1. **External folder (recommended while drawing)** — works in the editor *and* in an exported game:
   `%APPDATA%\Aftergrowth\overrides\` on Windows
   (Settings → **Open overrides folder** opens it; on Linux `~/.local/share/Aftergrowth/overrides/`). Mirror the same sub-folders there:
   `%APPDATA%\Aftergrowth\overrides\characters\player\survivor_down.png`
2. **Inside the project** — `assets/overrides/...` (ships with the project/branch).
3. Otherwise the original template is used.
4. If even the template is missing, a magenta checkerboard appears and the log names the asset.

## 3. Drawing guidelines

- PNG with transparency (RGBA). Non-pixel, hand-drawn art; draw at about **2× the display size**
  (`source_size`). Keep the same **proportions** as the display box — if the shape differs, the image
  is fitted inside the box without stretching (a warning is logged).
- The **pivot** is where the object stands on the ground; for most objects draw the ground contact
  at the bottom centre of the canvas.
- Size limits: 4–4096 px per side, at most 16 MB per file.
- Collision, interaction reach and all rules are defined separately — changing a picture can never
  change gameplay.

Special cases:
- **Ground tiles** (`env.ground_*`) repeat across the map — keep them seamless (left edge continues
  into right edge, top into bottom). No transparency needed.
- **Farmhouse door** art must fit the dark door opening drawn in the farmhouse picture
  (40 × 83 display px). If you redraw the farmhouse, keep the opening in the same place or tell the
  developer so the door position can be moved (one number in the scene).
- **Side views** (`char.player_side`) face right; the game mirrors them for walking left.
- **Paper grain** is a greyscale texture used by the screen overlay (subtle).
- **Floor-level art** (hatches, the ladder-down slab, the exit mat) is drawn *under* characters; the
  hatch picture's opening should stay centred where the manifest pivot says.
- **Trees** that can be chopped use the same tree pictures as decoration, plus `env.tree_stump`.
- **Lantern light** is a separate light, not part of the lantern picture.
- **Zombies** (`char.zombie*`, iteration 003) are placeholder figures only: zombie visual design is
  deferred. Front, back and side poses, two lunge (wind-up) poses and a fallen pose. The red wind-up
  tint and the hit flash are applied by the game, so don't paint them in.
- **Machines** come in pairs where the state is visible: `world.generator_off` / `_on`,
  `world.purifier_off` / `_on` and `world.lamp_off` / `_on`, plus `world.storage_locker`. The lamp's glow is
  a separate game light, so `lamp_on` only needs the lit bulb. Keep the machine's footprint (its bottom
  edge) where the template has it, because collision is set in the scene, not taken from the art.
- **New sounds** (iteration 003): zombie groan / alert / attack / hit / death, swing, player hurt,
  dig earth, the looping generator hum (`amb.generator`, a seamless loop), water pour, rummage and drink.

## 4. Sounds

WAV (16-bit PCM) or OGG Vorbis. Same naming rule; either extension is accepted:
`assets/templates/audio/world/template_door_open.wav` → `overrides/audio/world/door_open.ogg` (or `.wav`).
Loops (ambience) loop automatically. Volume and bus come from the manifest.

## 5. Seeing your change

- Start the game, or press **Settings → Reload art & sound** (also in the F3 developer overlay)
  while playing. Folders are only scanned at those moments, not every frame.
- In the Godot editor, files you put inside `assets/overrides/` are imported automatically when the
  editor window gets focus; external-folder files are read directly.
- F3 shows "art/sound overrides active: N". Rejected files are explained in the log
  (`%APPDATA%\Aftergrowth\logs\`, look for `override_rejected`).

## 6. Going back

Delete (or rename) your file and reload — the template returns. Nothing in the game ever writes to
`assets/overrides/` or the external folder, and the original templates are never modified.

## 7. Multiplayer

Replacements are personal and cosmetic: each player sees their own art/sound files. They are not
sent over the network and do not need to match between players.

## Verified status (iteration 001)

| Check | Result |
|---|---|
| External image override replaces template (Linux, editor build, real game process) | tested ✔ |
| External sound override replaces template | tested ✔ |
| Corrupt / oversized override rejected → template | tested ✔ |
| Removing override restores template | tested ✔ |
| Bundled `assets/overrides/` path | unit-tested resolution order; editor import on Windows **pending creator acceptance** |
| Exported Windows build | **not tested** (no export templates in the test environment) — pending |
