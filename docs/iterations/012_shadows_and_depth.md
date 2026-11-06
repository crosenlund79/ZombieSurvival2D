# Iteration 012 — Shadows & Depth

| Item | Value |
|---|---|
| Base | `iteration/011-world-awakens` @ `f4fba85` (verified locally and on the remote before any change) |
| Recovery reference | **`backup/pre-sideview-iteration-012` → `f4fba85`** (pushed and verified on GitHub before any change) |
| Branch | `iteration/012-shadows-and-depth` |
| Milestone checkpoints | `backup/iteration-012-milestone-a` (`3f0cd85`), `-b` (`b250640`), `-c` (`4b99d0a`), `-d`, `-e` (see the final report) |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Save schema | 4 (unchanged). New data is optional; saves load in both directions (see §5) |
| Status | Implemented and tested on Linux (unit, real multi-process, rendered). **Windows acceptance pending.** The side-view bunker is an **experiment** awaiting a creator decision. |

> Above ground, players fear what they cannot see. Below ground, they should clearly see what they have built.

## 1. Burnt Ones — never fully revealed

- **Silhouette shader** (`src/presentation/world/silhouette.gdshader`). Every Burnt One is drawn as a
  dark inked shape:
  - Only a faint trace of its drawn form survives. No colour, face or clothing detail is shown.
  - A thin outline band is kept.
  - In the shader's `light()` function, 2D lights (moonlight, the flashlight, headlights, lamps, fire)
    add only to that outline band. The interior drinks the light.
  - Lightning lifts the screen evenly, so the interior stays flat.
  - The art files are untouched and remain replaceable; this is presentation only.
- **Four body archetypes**, chosen from the creature's id, with modest ranges so they stay human:
  - *gaunt* — taller and thinner
  - *hunched* — shorter, with a forward hunch and lean
  - *heavy* — broader, with a slower gait
  - *limping* — an uneven, dragging step

  They differ in height, build, hunch, held lean, gait bounce and crawl tempo. Upright, crouching,
  crawling and bursts are unchanged.
- **No enemy indicators in ordinary play.** The `?`/`!` cues and health bars above Burnt Ones now
  appear only with the developer AI labels (F3), which also reveal the full figure. A hit flash or a
  wind-up still warms the dark shape.
- Hearing, screeches, investigation, pursuit and shelter restrictions are unchanged. No hunt trigger
  was added.

## 2. Thawed blood — an environmental warning

- **Rule** (`src/sim/blood_sim.gd`, host, saved):
  - Every Burnt One carries frozen blood. Near real warmth its `thaw` rises: the region's authored
    `heat_sources` (today the cabin's lit stove, radiating through its walls and doorway), running car
    engines, and a developer heat command.
  - Away from warmth the blood refreezes.
  - Past a threshold it drips, at most every few seconds and only by chance. Each drop refreezes into
    one small, irregular mark.
  - So marks appear only where warmth plausibly thawed something, plus a few while it refreezes.
    There is no trail everywhere it walks, and the old random blood flecks on tracks are removed.
- **Weather erases marks systemically** (`content/tuning/blood.json`):
  - Clear and fog: old blood slowly fades into the snow.
  - Falling snow buries marks (`cover`); blizzards bury them faster.
  - Rain and storms wash them out (`wash`).
- **Readability** (`BloodView`):
  - Fresh snow whitens marks; rain makes them paler.
  - Fog and blowing snow cut the range at which a mark can be made out at all.
  - Distance always matters.
  - There are no markers, no glow and no HUD.
- **Sound as an imperfect clue.** Weather masks Burnt One sounds by a few decibels per weather kind
  (`sound_mask_db`: blizzard −9, storm −7, heavy rain −6, snow −2, fog −1).
- **Experience.** A careful player who notices fresh red specks by the cabin or around an idling car
  knows something stood there recently, and can choose another way, especially on a calm day. In fog,
  in a blizzard or after rain that knowledge is gone. Nothing is guaranteed.

## 3. Bunker — experimental 2D side view

**Decision for this branch.** The surface, settlements, driving and the map stay top-down. Bunker
levels are shown in a **side view / cross-section** by default. The original top-down bunker remains
playable and comparable at any time.

**One state, two readings.** A bunker level's excavation grid already is a cross-section: its shaft
cells run up from the room toward the hatch. `SideSection` (shared by host and view) reads the same
data that way:

- Columns run left-right and rows run up-down.
- Things rest on the floor beneath them; lamps hang from the ceiling.
- A level without a grid (concrete levels, the Ashgrove cellar) is one room (`side_room`, aligned with
  its build zone).
- Rows are drawn shorter (`ROW_SCALE` 0.625) so rooms get human proportions. Plan coordinates never
  change.

Nothing is converted or stored twice, and the top-down view keeps reading the grid as a floor plan.

| Element | Side view |
|---|---|
| Entering / leaving | Through the existing hatch and ladders. The host puts a side-view player's feet on the floor on arrival. Leaving returns you to the cabin (or the town house) in top-down |
| Moving | A/D walk along the floor, one-row steps up or down, earth and closed walls block. **No jumping** |
| Vertical | W/S climb ladders and reinforced timber supports (scaffolding). Step sideways off them onto a ledge and drop to the floor below. Levels connect by the existing ladders (E) |
| Levels | Each level is its own region, as before (developer "create level"; no maximum depth). Tested with three levels |
| Excavation | E digs the cell you face: left/right at your feet or head, the ceiling with W held, the floor with S held. Same rules (support radius, permanent cells), same host request |
| Supports | Placed where you stand, drawn as timber scaffolding from floor to ceiling, climbable once reinforced |
| Floors / ceilings | Timber floorboards on earth below open air and beams under earth above. Concrete levels have reinforced concrete slabs |
| Building | Point at a column; the object goes on that column's floor (same rules and costs). Walls, doors, crates, workbenches and planters have side-view art |
| Equipment | Storage, generator, purifier, lamps (light falls below them), bedroll, timber pile, workbench and crafting all work through the same views and panels |
| People | Players and the survivor stand on the floor; climbing players are shown on the ladder |
| Art | 34 new side-view templates (`assets/templates/side/`, manifest `visual_depth.json`), all replaceable |

**Where both views meet the host.**
- The host knows each player's perspective (`PlayerState.bunker_view`, runtime).
- Side-view moves are validated by horizontal speed and open space.
- In bunker levels, reach is either plan distance or "horizontally close, anywhere in the same open
  space", so a ladder near the ceiling is reached from its foot.
- Small hanging lamps no longer block building on the floor below them.

### Comparing and reverting

- **In game (developer): F7**, or F3 → "Bunker view: side / top". This switches *your* view between the
  side view and the original top-down scenes. It is saved per player (`[dev] bunker_view` in
  `settings.cfg`) and other players are unaffected.
- **Back to the original game completely:** check out `backup/pre-sideview-iteration-012` (`f4fba85`),
  the exact state before this iteration. All earlier branches are untouched.
- **Keep the other iteration 012 work but drop the side view:** set `bunker_view` to `top` by default in
  `SettingsService.bunker_view()`. The side-view files (`side_section.gd`, `side_bunker_view.gd`,
  `side_terrain.gd`, `side_art.gd`, the side templates) can then be removed without affecting the
  top-down bunker. The host rules added for it — lenient bunker reach and floor snapping for side-view
  players — are harmless in top-down.

## 4. Tests

- **Unit** (`tests/unit/test_shadows_depth.gd`):
  - Thawed blood: none without warmth; warmth thaws and drips a few small marks; refreezing stops
    them; engines count as heat; weather erasure and visibility; persistence.
  - Cross-section: floors, ceilings, rest positions, the grid-less room; walking steps and walls;
    reach and floor snapping on arrival (side view) versus by the ladder (top view); climbable ladders
    and supports.
- **Real multi-process** (`tools/mp_test.py`):
  - `blood_multi`: marks replicate, persist across a restart, reach a rejoining client, and rain
    erases them for everyone.
  - `side_multi` (19 checks):
    - the client goes below in the side view while the host stays on the top-down surface
    - the host then joins below and switches to the top-down view
    - the client digs and builds in the side view and the top-down host sees it
    - the host digs the same grid in top-down
    - a reconnect, then a save and restart with the dug cells and the crate intact
  - The original-bunker scenarios (`bunker_multi`, `dig_multi`) now explicitly select the top-down
    view, because they regress the original perspective.
- **Rendered:** the screenshots in `../screenshots/iteration_012/` — see the final report.

## 5. Saves and migration

- No save format change: schema 4, no migration.
- New optional data: `world.blood` (thawed-blood marks). Older builds ignore it, and older saves load
  with no marks.
- The bunker perspective is not part of the world. It is a client setting plus runtime host state. A
  world saved in either view loads in either view and in older builds: positions are plan
  coordinates in both.
- Backups: the safe-write rotation (`world.json.bak`) is unchanged, and the pre-iteration branch keeps
  the original playable game.

## 6. Known limitations and open decisions

- **Side view is an experiment** (creator decision pending, register entry WX-11).
- Templates authored for the floor plan put some entities at heights that only make sense from above.
  In the side view they simply rest on the floor or hang from the ceiling. Two objects at the same x
  but different plan depths overlap in the side view.
- Survivors' plan movement appears as walking along the floor; their vertical plan moves are not shown.
- New levels are still created only by the approved developer command (GD-05). There is no
  player-facing "dig down to a new level" yet. Floors, ceilings and concrete slabs are drawn from the
  level type, and there is no separate floor-building action (none existed before).
- Burnt One silhouettes rely on 2D lights calling the shader's `light()` function. Verified on Linux
  (Compatibility renderer); Windows acceptance pending.
- All new art is generated placeholder art waiting for tablet art.
