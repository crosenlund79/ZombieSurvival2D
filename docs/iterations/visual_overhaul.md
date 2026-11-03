# Visual overhaul — "dirty ink" pass

| Item | Value |
|---|---|
| Base | `iteration/006-world-worth-surviving` @ `b2903ca` |
| Branch | `art/visual-overhaul` |
| Scope | Graphics, visual effects, lighting and presentation only |
| Status | Implemented and verified in rendered gameplay on Linux. **Windows acceptance pending.** |

## What changed

### Art pipeline (`tools/art/`)

- **`inkkit.py` (v2)** — every generated sprite now gets:
  - **Painterly fills:** value noise, a warm-light / cool-shadow hue drift and paper fibre.
  - **Ink strokes:** tapered, with a dry-brush ghost pass.
  - **Illustration helpers:** `shade` (hatching on the shadow side), `grime`, `moss`, `leaf` and `ivy`.
  - **`finish`:** applied when each sprite is saved. It adds a rough, irregular ink silhouette, an
    inner edge burn and grain.
- **`gen_overhaul.py`** — hand-composed redraws:
  - oaks, birch, shrubs, grass clumps and stump
  - grass, dirt and asphalt ground tiles; the grass gets inked tufts, straw and stones
  - the farmhouse: sagging weathered slate, broken patches with exposed battens, moss carpets, a
    creeper on the eave, and shrubs swallowing the corners
  - the shed and the fallen zombie
  - the bunker earth floor, the surrounding earth mass, and the exposed-earth reinforcement bulge
    (soil strata, hanging roots, chalk frame)
- **`gen_figures.py`** — the survivor (3 views) and zombie (3 views + 2 lunges), rebuilt with natural
  proportions from tapered limbs and curved torsos. The NPC survivor is still recoloured from the
  survivor by `gen_station.py`.
- **`gen_station.py`** — shop and workshop weathering and overgrowth, a faded fascia, and muted stains.
- **`gen_homestead.py` / `gen_bunker.py`** — wood palette moved from orange timber to weathered
  grey-brown.
- **`regenerate_all.py`** — one ordered command for every visual template. It never runs the audio
  generators.

### Presentation (`src/presentation/world/atmosphere.gd`)

- The overlay is now a **screen-space grade of the world**. The HUD sits on a higher canvas layer and
  is not graded. The grade applies:
  - S-curve contrast and slight desaturation
  - cool green-grey shadows and warm highlights
  - an ink-brown vignette and paper grain
- New exported tunables: `contrast` and `saturation`. Existing scene values for tint, vignette and grain
  still apply.

## What did not change

- Sprite canvas sizes, display sizes, pivots and file names. All manifests are byte-identical.
- Layering, occlusion fade and collision, which is defined in data and independent of the art.
- The template/override workflow. Nothing under `assets/overrides/` was touched.
- Gameplay, AI, networking, persistence, balance, world generation and audio.

## Verification

| Kind | Result |
|---|---|
| Import + unit tests + content check | `--import` clean. **89/89 unit tests passed; content check PASS** (all 144 manifest entries have valid templates; every referenced asset id exists) |
| Script guides | 95/95 scripts documented (EN + DA) |
| Rendered gameplay | 18 screenshots of the full `tools/shots_006.py` run, rendered with the new art: homestead, construction, crafting UI, station, map, night and rain, horde, bunker, survivor, two-player session. Before/after comparisons are the `compare_*.jpg` files. All in `docs/screenshots/visual_overhaul/` |
| Multiplayer (`tools/mp_test.py`) | Not re-run, because no networking, simulation or save code changed. The two-player screenshot scenario ran (host and client connected, both rendering) |
| Windows / exported build | **Not tested. Windows acceptance pending.** |

## Known limitations

- All art is still generated placeholder art, meant to be replaced piece by piece by the creator's own
  drawings.
- Zombie design is DEFERRED. The new zombie figure is a readable placeholder, not a design decision.
- Gameplay perspective is still undecided (VX-01). The overhaul kept the existing view.
- Not every asset got a hand-composed redraw: interior furniture, machines, build structures and props
  were lifted through inkkit v2 only. They are the next candidates for redraws.
