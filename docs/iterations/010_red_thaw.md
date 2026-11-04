# Iteration 010 — Red Thaw (concept and visual rebirth)

| Item | Value |
|---|---|
| Base | `art/visual-overhaul` @ `8347b40` (latest work; contains iterations 001–009 and the visual overhaul) |
| Branch | `iteration/010-red-thaw` |
| Recovery reference | `backup/pre-red-thaw` (`8347b40`) — verified on the remote before any change |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Save schema | 4 (unchanged; old worlds load) · network protocol 6 · visible title **Red Thaw** 0.2.0 |
| Status | Implemented and tested on Linux (unit, real multi-process, rendered). **Windows acceptance pending.** |

Design authority: [`../DESIGN_DECISIONS.md`](../DESIGN_DECISIONS.md) (RD-01 … RD-11 APPROVED, RX-01 … RX-07
EXPLORING, RF-01 … RF-06 DEFERRED) and the visual register
[`../visual_direction/README.md`](../visual_direction/README.md) (RT-01 … RT-07, RTX-01 … RTX-04, RTF-01).

## 1. Identity

- The visible title is **Red Thaw** (window, main menu, build label, problem report, documentation).
- Unchanged on purpose, so saves and the user folder keep working:
  - `project.godot` name `Aftergrowth`
  - `custom_user_dir_name` (`%APPDATA%\Aftergrowth`)
  - the save game id
  - the repository name
- English and Danish text were rewritten for the setting: no zombies, a cabin instead of a farmhouse, snow
  instead of rain, and meltwater collectors. The simulation keeps the internal name "zombie"; players
  only ever see **Burnt Ones**.

## 2. Opening — waking in the woods

- New players spawn on the forest floor beside the **burned shed**, west of the cabin clearing.
- A **bag** lies within reach (`homestead.starter_bag`, entity type `starter_bag`). It gives each player
  one personal kit, exactly once:
  - a large bottle of water (drink: +70)
  - a pack of crackers (eat: +25)
  - a field map (Read: opens the world map; never used up)
- Claims are stored per player in the bag's own entity state, so they are saved, replicated, never
  duplicated and survive a reload. Players who join later get their own kit, and no shared-world loot
  is touched.
- The drink key (Q) uses the bottle when you have no clean water.
- There is no cinematic and no explanation.

## 3. Nuclear-winter visual remake

- **Hand-composed templates (`tools/art/gen_winter.py`):**
  - ground tiles: snow over the forest floor, frozen mud with ice and ruts, snowy cracked road
  - two snow-laden pines, a bare birch, frozen shrubs, three dead-grass clumps, a snowy stump
  - the **hunter's cabin**: log walls, a heavy snow roof with icicles, frosted windows, a stovepipe,
    antlers, firewood and snowshoes. It keeps the farmhouse's canvas, base line and door opening, so the
    door, entry and collision are unchanged.
  - the **burned shed**, a woodshed and an abandoned pickup truck
  - the settlement: two houses (blocked doors, frosted and boarded windows, a collapsed porch, a chair
    buried on the step) and a **collapsed house** with a sheltered corner
  - a child's sled, the starter bag (full / emptied) and a thawed-blood decal
  - snowflake and fog effects, field-map paper, and the cabin's log-wall interior (empty rifle pegs)
- **inkkit winter pass:** every other outdoor template (fences, gate, car, sign, barrels, station
  buildings, outdoor structures) gets snow settled on its upward surfaces, frost, dead vegetation instead
  of green, and a cold grade when it is generated. Interior and bunker art is left warm.
- **Characters (`tools/art/gen_figures.py`):**
  - The survivor wears a faded blue-grey parka and a knit hat.
  - **Burnt Ones** (all views, lunges and a fallen pose): damaged coats with tatters, burns with raw
    rims, dried blood rimed with frost, and a hood shadow over the eyes.
  - The frightened survivor has a huddled pose, and there is a night silhouette figure.
- **Lighting (`Atmosphere`):**
  - Outdoors: a cold desaturated grade with cool split toning, world-anchored drifting fog, slow
    snowfall, and a cold ink vignette.
  - The cabin interior and the powered bunker use a warm grade, so warmth stands out.
  - Nights are dark but readable, and the carried torch light remains.
- **Scenes:**
  - the pine woods: 70 seeded decorative pines inside the mapped forest areas; the burned-shed clearing
    and the walk to the cabin gate are kept open
  - the settlement: three houses, the collapsed house, 21 pines, the sled and the blood decal
- **Burnt One motion:** a held, slightly wrong lean, an uneven gait and sudden jerks (presentation only).
- **Placeholder audio (`tools/art/gen_red_thaw_audio.py`):** cold wind, snowfall wind, muffled indoor
  wind, four laughter/giggle variants, two mutters, and Burnt One breathing, notice, attack, hit and
  fall. Existing sounds were not changed.

## 4. Hunter's cabin

- The farmhouse building, door, entry, interior, hatch, ladder, bunker, excavation, construction,
  storage and infrastructure all work unchanged; only their presentation is the cabin.
- The protected boundary still applies: Burnt Ones never enter the cabin or the bunker.
- The yard is now the cabin clearing (frozen mud). The tractor became an old truck, and the shed became a
  woodshed (the same loot spots).

## 5. World map

- The map panel is redrawn as a weathered, inked field map:
  - pine symbols stamped across the real forest polygons, and pale snowy clearings
  - faint contour hints
  - cased roads and dashed woodland tracks
  - hatched buildings, a ruin mark (the collapsed house) and a burn mark (the burned shed)
  - region names in small capitals, a compass, a 500-pace scale bar and a border graticule
- It is drawn only from the real region data and is unchanged in behaviour:
  - player markers (red ring for you, blue for others), "⌂" when inside and the depth when underground
  - shelter markers (a hatch square with a ladder)
  - the discovery of the settlement, and "unexplored" before that
- No fast travel and no route planning.

## 6. Abandoned settlement and omens

- The former service-station region is now the settlement. The old fuel shop, workshop, pumps and tool
  locker stay as part of it, and all their loot and the unique finds are unchanged.
- New: three houses, a collapsed house and two searchable houses (a pantry with food and cloth, a
  wardrobe with cloth).
- **Laughter (day)** and **silhouettes (night)** are `OmenSim` events. They are pure functions of the
  world seed and the shared clock (`content/tuning/omens.json`, the region's `omens` block):
  - nothing is stored or sent, so everyone in the region gets the same event at the same place
  - each player's own position decides whether they hear or see it
  - Laughter: a 30 % chance per 35 s slot, by day only, at one of six building spots. It is heard
    positionally within 650 px and is never shown. There is nothing to find and no encounter.
  - Silhouettes: a 32 % chance per 45 s slot, at night only, walking one of six authored paths (between
    houses, across the road, by the trees) for 3.5–6 s. They sit in the depth-sorted layer, so houses and
    trees hide them. Not an encounter. The pine woods have four paths of their own.

## 7. Frightened survivor

- Mara now waits huddled in the corner of the collapsed house:
  - she trembles, and now and then mutters (positional sound) with a fragmented line
  - she flinches and answers with a fragment when spoken to
  - her name is unknown until you have met
- The six lines are in English and Danish. They never explain anything.
- Her identity, location, multiplayer sync, persistence and the existing recruitment (food + water →
  she comes to your shelter, then works there) all reuse the existing `NpcSim`. The mutters are local
  presentation.
- Also fixed: the NPC sprite was drawn about 40 px below its ground point (a pre-existing presentation
  bug).
- Fixed during verification: a client's own replica row is not updated while it walks. Omens, mutters and
  the test driver now use the local avatar's real position, so a joining player hears laughter near them.

## 8. Burnt Ones and hunts

- **Automatic threats are off by default** (`ThreatState.ambient = false`): no base population, noise
  reinforcements, night/heat wanderers or automatic cabin attacks.
  - The whole loop, including noise, attention and heat, is kept and can be switched back on with
    `dev ambient 1`.
  - Base-population figures from older saves are released when such a world loads (logged).
- **Developer hunt** (`dev hunt`, F3 *Start a Burnt One hunt (on me)*):
  - Spawns one Burnt One out of sight, about 760 px away at an authored map entry.
  - It walks to where you are, then uses the normal sight / chase / wind-up / attack / lose-target AI.
  - It picks up your trail again every 12 s while searching, and gives up after 240 s and walks off.
  - It is refused against anyone inside the cabin or the bunker, and it never follows anyone inside.
  - It is transient (never saved).
- Diagnostics: an overlay line per hunt (state, target, distance, health, time left), `hunt_*` log
  events, problem-report lines and autotest state.

## 9. Verification

| Kind | Result |
|---|---|
| Unit tests + content check | **96/96 PASS**, including 7 new (`test_red_thaw`): opening spawns by the bag; one kit per player, also after a reload; kit items; no automatic threats; hunt pursuit, attack and give-up; the protected cabin; hunters never saved; deterministic day/night omens. The content check also validates the new entity type, items and assets |
| Script guides | 99/99 scripts documented (EN + DA) |
| Real separate processes (`tools/mp_test.py`, all scenarios) | Full run of all 22 scenarios: **343/344**. The one failure (`slice 16`) exposed a real bug: the decorative pines were blocking the Burnt Ones' navigation. After the fix, the affected scenarios were re-run: `slice`, `danger_single`, `danger_multi`, `accept`, `red_thaw_multi`, `perf_multi` **115/115**. The new `red_thaw_multi` scenario covers: both players wake by the bag and get one kit each (host authority); a host-started hunt finds and hurts a remote client; the client's hits are applied by the host; both peers hear the same laugh from the same spot and see the same silhouette on the same path; the frightened survivor is shared and persistent; after a host restart the kit claims persist and no hunter is restored. Older scenarios that test the automatic loop switch it on explicitly (`dev ambient 1`). Performance: host simulation of 26 Burnt Ones with two players is at most 1.08 ms per frame |
| Rendered gameplay + runtime checks (`tools/shots_red_thaw.py`) | Every scenario passed. Checks: opening by the shed; the kit; one kit only; water and crackers consumed; gate reachable on foot; cabin interior; bunker by ladder; road to the settlement; laughter heard by day with no source; survivor dialogue; a night silhouette that is not an encounter; hunt spawns, pursues, attacks and can be fought; never follows into the cabin; not restored after save and reload; two-player kits. All 17 screenshots were inspected |
| Creator overrides / replacement pipeline | `assets` scenario PASS: template by default; external image and sound overrides used; **a Red Thaw asset (the hunter's cabin) overridden**; a corrupt PNG is rejected; removing an override restores the template; gameplay is unaffected |
| Windows / exported build | **Not tested — no Windows machine or export templates in the test environment. Windows acceptance pending.** |

Screenshots: `docs/screenshots/iteration_010/`.

## 10. Known limitations

- All art and sound are generated placeholders. The laughter and muttering are synthesised voices and will
  sound artificial until replaced.
- Nothing starts a hunt on its own (RX-01 is undecided). The old automatic loop is available only through
  `dev ambient 1`.
- Mutters and the survivor's spoken lines are local to each player (different players may see different
  fragments). Laughter and silhouettes are shared.
- The settlement reuses the station region (`service_station` id) so saves stay compatible. Houses cannot be
  entered.
- Decorative pines have small trunk collisions for players. The Burnt Ones' navigation ignores them
  (`Prop.nav_block = false`) so they never wall off entry points or routes, which means a Burnt One can
  brush through a pine trunk.
- Snowfall is the old rain spell with new presentation (it masks noise and fills meltwater collectors).
- Old zombie, farmhouse and oak templates remain in the manifests (unused) so any art already drawn for
  them still loads.
