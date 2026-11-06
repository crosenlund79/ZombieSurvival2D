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
| `visual_winter.json` | **Red Thaw** winter set: snow / frozen-mud / snowy-road tiles, pines, bare birch, frozen shrubs, dead grass, snowy stump, **hunter's cabin**, **burned shed**, woodshed, truck wreck, settlement houses (two + collapsed), sled, **starter bag** (full / emptied), thawed-blood decal, snowflake, fog |
| `visual_burnt.json` | **Burnt Ones** (down / up / side, two lunges, fallen), the frightened survivor huddled, the night silhouette |
| `audio_red_thaw.json` | cold wind, snowfall, muffled indoor wind, suppressed laughter, giggling, distant laughter, muttering, Burnt One breathing / notice / attack / hit / fall, three Burnt One screeches, blizzard loop |
| `visual_awakens.json` | **Iteration 011**: the station wagon in 16 headings (`vehicle.wagon_00` … `_15`, heading = number × 22.5° clockwise from east), the Ashgrove storefronts (`world.town_grocery`, `_pharmacy`, `_hardware`, `_clothing`, `_garage`), street lamp, town sign, road block, wolves and bears (`char.wolf_*`, `char.bear_*`: side walk frames 0/1 facing right, front, back), the flashlight in the hand (`item.flashlight`) and the light beam shape (`fx.flashlight_cone`, white = lit, pointing right from the centre; also used for headlights) |
| `audio_awakens.json` | **Iteration 011**: engine loop (pitch follows speed), engine start / stop, car door, wolf howl / huff, bear grunt / huff |
| `audio_inbox.json` | **Iteration 011**: clips selected from your `assets/audio inbox/` (see §8) |
| `visual_depth.json` | **Iteration 012**: thawed-blood marks (`fx.blood_drop_a/b/c`, keep them small) and the **side-view bunker** set in `side/`: tiles (earth strata, bedrock, dug back wall, concrete wall), strips (floorboards, ceiling beam, concrete slab), ladder, floor hatch, scaffolding (marked / building / done), storage locker, generator and purifier (off / on), hanging lamp (off / on), bedroll, timber piles, wood / metal / concrete walls, door, crate, workbench, planter. Side-view pictures are drawn in elevation (from the front); keep the same pivots (feet on the floor, lamps hang from the top) |

The older zombie, farmhouse, oak and grass entries are still listed in their manifests but are no longer
used by the scenes. They stay so nothing breaks if you have already drawn them.

All current templates are **generated placeholders** (tools/art) waiting for your tablet art.
To regenerate every visual template (graphics only, never audio, never `assets/overrides/`):
`python3 tools/art/regenerate_all.py`. Red Thaw sounds are generated separately with
`python3 tools/art/gen_red_thaw_audio.py` and `python3 tools/art/gen_awakens_audio.py` (each only writes its own files; the inbox copies come from `tools/art/import_audio_inbox.py`). Your overrides keep winning over the templates.

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
- **Construction** (iterations 006–009):
  - Surface barricades come in three tiers: `build.barricade_wood`, `_metal` and `_concrete`.
  - In the bunker the same barricade fills one 64 px excavation cell: `build.wall_*`, drawn as a 3/4
    block.
  - Door: `build.door_closed` / `_open`.
  - Spike trap: `build.spike_trap` / `_worn`.
  - Planter: `build.planter_empty` / `_growing` / `_ripe`.
  - Rain collector: `build.rain_collector` / `_full`.
  - Also `build.crate`, `build.workbench` and `build.pile` (dropped items).
  - Keep the bottom edge where the template has it, because collision is a rectangle set by the game,
    not by the picture.
- **Service station:** `world.station_*`. **Held tools:** `item.machete`, `item.hatchet` and
  `item.felling_axe`, drawn like `item.club`. **Steel hatch:** `world.hatch_steel_*`.
- **The survivor** (`char.npc*`) is a recoloured copy of the player placeholder. You can replace her
  independently of the player.
- **New sounds** (iteration 006–009): structure hit and break, upgrade clank, spike trap, the rain loop
  (`amb.rain`, seamless) and the horde warning.
- **New sounds** (iteration 003): zombie groan / alert / attack / hit / death, swing, player hurt,
  dig earth, the looping generator hum (`amb.generator`, a seamless loop), water pour, rummage and drink.

## 4. Sounds

WAV (16-bit PCM) or OGG Vorbis. Same naming rule; either extension is accepted:
`assets/templates/audio/world/template_door_open.wav` → `overrides/audio/world/door_open.ogg` (or `.wav`).
Loops (ambience) loop automatically. Volume and bus come from the manifest.

**Burnt Ones are drawn as silhouettes (iteration 012).** Your Burnt One art is still used, but in ordinary play
it is shown as a dark inked shape (only its outline and a hint of its form). Developer F3 → AI labels shows the
full picture so you can check your drawing.

## 5. Seeing your change

**Use custom graphics (iteration 011).** Settings → Assets → **Use custom graphics: ON / OFF**.
OFF shows the original art everywhere, ignoring your replacement images, without moving, changing or
deleting any file. ON uses them again. The switch applies immediately (every picture is re-resolved),
is remembered per player on this computer (settings file), falls back per picture (a picture without a
replacement is unaffected either way), and never changes gameplay. Custom **sounds** are not part of
this switch. Each player in a multiplayer game chooses for themselves.

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

## 8. The audio inbox (iteration 011)

`assets/audio inbox/` holds the creator's original sound library. It is never modified, and it carries a
`.gdignore`, so Godot does not import the originals. `tools/art/import_audio_inbox.py` (needs ffmpeg)
**copies** the selected clips into `assets/templates/audio/inbox/template_<name>` — trimmed, faded,
level-matched or low-passed where noted — and lists them in `assets/manifest/audio_inbox.json`. Like
every template they can be overridden through `overrides/audio/inbox/<name>.wav|ogg`.

| Id | Original clip | Used for |
|---|---|---|
| `amb.heavy_rain` | Ambiance/Ambiance_Storm_02.wav | heavy-rain weather loop |
| `amb.thunderstorm` | Ambiance/Ambiance_Storm_01.wav | thunderstorm loop (rain bed) |
| `sfx.thunder_near` | Impact/Impact 1.wav (low-passed, echoed) | thunder after a near flash |
| `sfx.thunder_far` | Impact/Impact Classic 2.wav (low-passed, echoed) | distant rolling thunder |
| `amb.stove_fire` | General effects/Campfire Fire Loop 3.wav | crackling stove inside the cabin |
| `sfx.body_drop` | Body drop/Body Drop 2.wav (trimmed) | a Burnt One's body hitting the snow after it dies |
| `sfx.swing` | Movement/Swing 3.wav (trimmed) | melee swing (replaces the generated swing) |
| `sfx.hit_wood` | Bullet impact/Wood Heavy 1.wav | blow on wood (listed, available) |
| `sfx.hit_metal` | Bullet impact/Metal Heavy 2.wav | blow on metal; the car bumping into something hard |
| `sfx.glass_break` | Bullet impact/Glass 3.wav | glass cracking (listed, available) |
| `sfx.laugh_mocking_m` | Hero Voice - Male/mocking laugh.wav (muffled) | settlement laughter variant |
| `sfx.laugh_mocking_f` | Hero Voice - Female/MOCKING_LAUGH.wav (muffled) | settlement laughter variant |
| `sfx.voice_trust` | Hero Voice - Female/CAN_I_TRUST_YOU.wav (whispered) | the frightened survivor, the first time you talk to her |
| `ui.click` | UI sounds/Simple Click Sound 11.wav (trimmed) | menu click (replaces the generated click) |
| `ui.error` | UI sounds/Error 11.wav (trimmed) | refused actions |
| `music.theme` | Theme/Where the Ice Once Lay.mp3 (as OGG) | main-menu theme |

Not used on purpose: gunshots, explosions, sci-fi and fantasy effects, combat voice lines and most UI
sounds (they do not fit an unarmed, quiet winter game). Tool limits: no listening was possible in the
build environment — the selection was made from file names, durations and measured levels and
spectra; volumes are first guesses (manifest `volume_db`).

## 9. Interior, container and stove art (iteration 013)

`tools/art/gen_scavengers_circuit.py` generates the placeholder art for the Ashgrove interiors (manifest
`assets/manifest/visual_circuit.json`). Replace any of them with a file of the same name, without the
`template_` prefix, under `overrides/`:

| Folder | Pictures |
|---|---|
| `world/interior/` | walls (`wall_shop`, `wall_garage`, `wall_house`, `wall_planks`), floor tiles (`floor_linoleum`, `floor_concrete`, `floor_carpet`), store fixtures (`gondola_full/sparse/empty`, `checkout`, `freezer`/`freezer_open`, `clothes_rack_full/empty`, `display_table`, `pegboard`, `metal_shelf_full/empty`, `pharm_counter`, `med_cabinet`/`_open`, `tool_chest`/`_open`, `car_lift`), household furniture (`sofa`, `armchair`, `dresser`/`_open`, `home_fridge`/`_open`, `kitchen_counter`, `bookshelf`, `meal_table`), `locker`/`_open`, `crate`/`_open`, `boxes`, `barricade`, `partition` |
| `build/` | `stove` (top-down) |
| `side/` | `stove` (side view, the pipe rises through the ceiling) |
| `items/` | `stovepipe` |

A container shows its first picture until it has been searched, then its `_open` / emptier picture (the
pairs are listed per container in the region files, `art` / `art_searched`). Collision comes from the region
data, so a new picture never changes where you can walk.

## Verified status (iteration 011)

| Check | Result |
|---|---|
| Original templates only (no overrides) | tested ✔ (unit + real game) |
| Valid replacement image used | tested ✔ |
| Missing or invalid replacement → original, per picture | tested ✔ |
| Use custom graphics OFF → originals, files untouched; ON → replacements again, immediately | tested ✔ (unit + real game process) |
| The choice survives a restart | tested ✔ (real game process) |
| Two connected players with different choices (host OFF, client ON) | tested ✔ (two processes) |
| Exported Windows build | **not tested** (no export templates in the test environment) |

## Verified status (iteration 001)

| Check | Result |
|---|---|
| External image override replaces template (Linux, editor build, real game process) | tested ✔ |
| External sound override replaces template | tested ✔ |
| Corrupt / oversized override rejected → template | tested ✔ |
| Removing override restores template | tested ✔ |
| Bundled `assets/overrides/` path | unit-tested resolution order; editor import on Windows **pending creator acceptance** |
| Exported Windows build | **not tested** (no export templates in the test environment) — pending |
