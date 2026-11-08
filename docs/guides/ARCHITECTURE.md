# Technical Architecture Guide — Aftergrowth

Engine: **Godot 4.7.2 stable**, GDScript, **Compatibility (OpenGL) renderer** (widest Windows GPU
support; also what our Linux test machine can render). Target: Windows desktop.
The source code is authoritative; this guide explains how the pieces fit.

## 1. Directory layout

| Folder | Contents |
|---|---|
| `src/core/` | Autoload services + small static helpers (build info, paths, safe file writes, localization, asset catalog) |
| `src/state/` | Plain-data world model: `WorldState`, `RegionState`, `PlayerState` |
| `src/sim/` | Rules that change the world: `Simulation` (clock), `WorldActions` (validated requests) |
| `src/content/` | `Content`: reads authored region definitions |
| `src/persistence/` | `SaveCodec` (schema, validation, migration), `SaveService` (files) |
| `src/net/` | `NetService` (ENet connection lifecycle only) |
| `src/presentation/` | Everything visible: app shell, UI panels, region view, avatars, door/prop views |
| `src/dev/` | Content check, autotest driver (test-only) |
| `content/regions/` | Region definitions (JSON): entities, positions, initial state, spawn points |
| `scenes/regions/` | Region presentation scenes (editable in the Godot editor) |
| `assets/templates/` | Original placeholder art/audio (`template_` prefix) |
| `assets/overrides/` | Creator replacements bundled with the project (never written by code) |
| `assets/manifest/` | Asset catalogues (IDs, paths, sizes, pivots, readiness) |
| `locale/strings.json` | UI text, English + Danish |
| `tests/` | Unit tests (`tests/unit`), runner scene, fixtures |
| `tools/` | Python helpers: multi-process tests, screenshot scripts, art generators |

## 2. Autoloads (one owner per responsibility)

Load order matters; each may use the ones above it.

| Autoload | Class | Owns |
|---|---|---|
| `SessionLog` | `SessionLogService` | Structured bounded diagnostics (black box) |
| `Settings` | `SettingsService` | Client-local preferences, input map, language, local identity tokens |
| `Assets` | `AssetResolver` | Asset ID → texture/stream resolution with overrides, cache |
| `Audio` | `AudioService` | Buses, pooled one-shots, named loops, fades |
| `Saves` | `SaveService` | World save files (safe writes, backup fallback) |
| `Net` | `NetService` | ENet peer create/close, connection status |
| `Session` | `GameSession` | Session mode, the `WorldState`, players, clock loop, all game RPCs |

Everything else is either plain data (`RefCounted`) or presentation (`Node`s that can be freed).

## 3. Authoritative world state

`Session.world` (`WorldState`) is the single source of truth:

- `world_id`, `world_seed`, `tick` (shared clock), `created_unix`, `content_fingerprint`
- `regions: {region_id → RegionState}` — **only changes** relative to authored content, plus a
  revision counter per changed entity
- `players: {player_id → PlayerState}` — name, region, position, facing (`online` is runtime only)

Authored content (`content/regions/*.json`) defines the **initial** world: entity IDs, types,
positions, reach and initial state. `RegionState.entity_state(id)` merges initial + changes.
This keeps "generated/authored baseline" and "player changes" separate, which is what saves store.

On the host (and in single player) `Session.world` is authoritative. On clients it is a
**replica** rebuilt from the host's welcome snapshot and updated from host messages; clients never
write to it except to display predicted own movement.

## 4. Multiplayer responsibilities

Host-authoritative co-op over ENet (`ENetMultiplayerPeer`, default port 24680, up to 7 clients).
Single player runs the identical host code path with an `OfflineMultiplayerPeer`. Authority is the
**peer**, not the host's avatar: nothing requires the host to have a rendered player, so a
dedicated server stays feasible later.

All RPCs live on `/root/Session` (same path on every peer):

| Direction | RPC | Purpose |
|---|---|---|
| client → host | `_rpc_request_join(token, name, protocol, fingerprint)` | Ask to join; host checks version, content, identity, duplicates |
| host → client | `_rpc_welcome(world_dict, player_id)` | Full world snapshot (late-join sync) |
| host → client | `_rpc_join_rejected(reason)` | Clear refusal reason |
| client → host | `_rpc_submit_move(pos, facing)` (20 Hz, unreliable) | Owner-predicted movement; host checks plausibility |
| host → all | `_rpc_snapshot(tick, rows)` (10 Hz, unreliable) | Clock + player positions |
| host → all | `_rpc_roster(rows)` | Who is online (joins/leaves) |
| host → client | `_rpc_correct_position(pos)` | Snap back after a refused move / teleport |
| client → host | `_rpc_request_interact(req, entity_id, expected_rev)` | Interaction request |
| host → all | `_rpc_entity_changed(region, entity, state, rev, cause)` | Authoritative result |
| host → client | `_rpc_action_result(req, ok, reason)` | Refusal reasons (too far, stale…) |
| client → host | `_rpc_dev_command(cmd, arg)` | Refused unless the host allows client dev commands |
| host → all | `_rpc_session_closing(reason)` | Host is leaving |

**Identity.** Each game install keeps a random token per player name (`Settings.player_token`).
The token is the `player_id` in the world, so a reconnecting player gets their saved position.
Two copies on one computer need different player names *or* `--instance=<name>` folders.

**Movement.** The local avatar moves itself with collision (responsive), and reports positions.
The host accepts a position only if it is reachable at `MAX_PLAYER_SPEED` (+ slack) since the last
accepted one; otherwise it sends a correction. Known limitation: static collision is checked only on
the moving client — the host does not simulate physics yet.

**Shared actions.** `WorldActions.request_interact` validates: player registered and online,
entity exists in the player's region, distance ≤ reach + 24 px, `expected_rev` equals the current
revision. The last check makes simultaneous/repeated requests safe: if two players toggle the gate
at the same moment from the same revision, exactly one applies and the other gets "Someone else
changed it first" instead of silently undoing it.

**Lifecycle.** Connect timeout 10 s; join-handshake timeout 10 s; peer disconnect marks the player
offline and updates everyone's roster; host leaving saves, notifies clients, then closes; clients
return to the menu with a reason. Closing the window as host saves synchronously.

## 5. Replication boundaries

Replicated (authoritative): world identity, clock tick, roster, player positions, entity state +
revision. **Not** replicated (local presentation): animation bob, sprite flip, camera, zoom, UI,
interaction focus, sounds. Sounds are played on every peer *in response to* the authoritative
`entity_changed` event (cause `action`), never on key press — so prediction cannot double-play.

## 6. World and regions

One authored region (`homestead`) exists. Every player has a `region_id`; `Session.players_in_region()`
and `RegionView` only show players of the view's region, so two players in different regions is
already representable. Future work (not built): per-region snapshot filtering, region
loading/unloading, background simulation of unoccupied regions.

## 7. Simulation lifecycle

`Session._physics_process` on the authority accumulates real time and calls
`Simulation.advance(world, ticks)` at `TICK_RATE` = 10 ticks/s. The clock is raw simulated seconds;
no day length or time scale has been decided. Future timed systems must hang off `advance()`.
Gameplay randomness must use `world.make_rng("<purpose>")` (seeded from the world seed) so results
are reproducible and identical on every peer. Opening any menu never pauses this loop.

## 8. Save architecture

- Files: `user://[instances/<name>/]saves/<world_id>/world.json` (+ `world.json.bak`).
  On Windows `user://` = `%APPDATA%\Aftergrowth\`.
- Layout and schema version: see `SaveCodec` header. World block and players block are separate.
- **Validate before apply** (`SaveCodec.validate`), migrations via `SaveCodec.MIGRATIONS[from] = Callable`,
  safe defaults for optional fields, unknown content dropped with warnings.
- **Safe write** (`SafeFile.write_json`): write `.tmp` → read back + validate → move current to `.bak`
  → rename `.tmp`. Failed writes leave the last good save untouched; a corrupt main save loads the backup.
- Only the authority saves (manual F5 / pause menu / dev overlay, autosave every 5 min, on leave,
  on window close). Clients are refused.
- Saved: world id, seed, tick, entity changes + revisions, players (identity, name, region, position).
  Never saved: scene tree, images, sounds, online flags.

## 9. Asset resolution (Sprite Workshop)

See `docs/guides/ASSET_REPLACEMENT.md` for the creator workflow. Technically:
`AssetCatalog` (static) reads manifests and derives override paths; `AssetResolver` (`Assets`)
resolves **external → bundled → template → diagnostic fallback**, validates (readable PNG/WAV/OGG,
4–4096 px, ≤16 MB, path safety, aspect warning) and caches. `Assets.apply_to_sprite()` fits any image
into the manifest **display size** at the manifest **pivot**, so art never changes collision or rules.
`Assets.reload()` clears caches and emits `reloaded`; views re-apply their art.

## 10. Audio architecture

Buses Master/Music/Ambience/SFX/UI are created at startup if missing. `Audio.play(id, pos?)` uses
pooled `AudioStreamPlayer`/`AudioStreamPlayer2D`; `Audio.play_loop(name, id)` fades in a named loop
and ignores repeat calls with the same id; `stop_loop` fades out and frees. Volumes are client
settings. Missing sounds are logged once and stay silent.

## 11. Interaction architecture

`Interactable` (focus point, reach from content, prompt key, priority) → `InteractionSensor` on the
local avatar picks exactly one target (priority, then distance) → HUD shows the prompt → the
interact key calls `Session.request_interact()` → host validates → `entity_changed` → `DoorView`
updates sprite, blocker collision and plays the sound.

## 12. UI

`UIRoot` applies the shared `UITheme` and the UI scale (independent of camera zoom) and always fills
the viewport. Stretch mode `canvas_items` + aspect `expand`: wider screens see more world, nothing is
distorted. Panels: `MainMenu`, `Hud`, `PauseMenu` (does not pause), `SettingsPanel`, `DevOverlay` (F3),
bottom-right build label. All text goes through translation keys in `locale/strings.json`.

## 13. Region presentation (visual prototype)

The homestead scene (`scenes/regions/homestead/homestead.tscn`) is pure presentation, editable in the
Godot editor. **Provisional view: 3/4 top-down (oblique).** The ground is a plain 2D plane; standing
objects are drawn front-facing with height. World data stores only ground-plane positions, so the
same data works for pure top-down or another 2D view later — nothing in state, saves, networking or
interaction depends on the camera.

Layers (back to front):
1. `Ground` (z −10): `GroundPatch` polygons with tiling textures (meadow, road, driveway, yard).
2. `YSort` (y-sort on): every standing thing — `Prop`s, `FenceLine`s, `Scatter` dressing, `DoorView`s
   and player avatars — sorted by its ground-contact point (node origin = manifest pivot).
3. `Atmosphere`: warm `CanvasModulate`, drifting seed particles (z 20), and a screen overlay
   (CanvasLayer 5) with paper grain + soft vignette. The UI (CanvasLayer 10) is never graded.

Building blocks (`src/presentation/world/`):
- `Prop` — art by asset ID + **independent** collision `footprint` at the base; `occlude` fades the art
  to 42 % while the local player stands behind it; `sway` applies `sway.gdshader` (wind).
- `FenceLine` — fits a whole number of fence segments between two points + one collision strip.
- `GroundPatch` — textured polygon; tile size comes from the manifest display size.
- `Scatter` — seeded decorative dressing within an area, avoiding rectangles (same for every player).
- `Atmosphere` — mood only; never hides interactables.
- `DoorView.fade_with` — a door set into a building copies that building's occlusion fade.

Occlusion rule (simple on purpose): a tall prop fades when the local player's position is above its
base line and inside its art rectangle. No per-pixel masks.

## 14. Testing and diagnostics

- **Unit + content check**: `godot --headless --path . res://tests/run_tests.tscn`.
- **Real multi-process tests**: `python3 tools/mp_test.py` starts separate game processes
  (`--instance=…` `--autotest`) that connect over ENet and drives them via `AutotestDriver`.
- **Rendered screenshots**: `tools/shots_*.py` under a real display (or `xvfb-run`).
- **Black box**: `SessionLog` JSON-lines in `user://…/logs/`, 5 files kept, 1 MB cap each,
  repeated events throttled. Dev overlay shows the live state and the log path.
- **Build identity**: `BuildInfo.label()` (bottom-right). Commit is read from `.git` if present;
  a GitHub ZIP download shows `commit n/a` (git is never executed).

## 15. Regions, buildings and bunkers (iteration 002)

**Region definitions.** A region's content comes from a *definition* (`def_id`):
- static regions — `content/regions/*.json` (`homestead`, `homestead.farmhouse`), present in every world;
- level templates — `content/bunker_levels/*.json`, addressed as `level:<template>` (`bunker_earth`,
  `bunker_concrete`). Bunker levels are regions created at runtime from a template.

`RegionState.def_id` records which definition a region uses; for static regions it equals the region id.
`WorldState.region_def(region_id)` returns the right definition either way. Entity ids only need to be
unique inside one definition (every bunker level has its own `ladder_up`, `support_1` …).

**Bunkers.** `WorldState.bunkers[bunker_id] → BunkerState`. The bunker id is the persistent id of the
shelter entrance (`homestead.farmhouse.shelter`), so the entrance belongs to a specific building.
A bunker stores its entrance region/entity, `levels: {depth → template}` with signed depths (−1, −2, …,
**no maximum**; only created levels exist), and shared `resources` (the timber stockpile). Level regions
are named `bunker:<bunker_id>:<depth>`. Adjacent levels connect through the `ladder_up` / `ladder_down`
portals that every level template must contain (the content check enforces this).

**Portals** (`type: portal`) move a player between regions. The host resolves the destination:
`{region, position}` (doorways), `{bunker_of: site, depth}` (the hatch ladder), or `{bunker: "up"|"down"}`
(relative to the level the portal is in). A portal can require another entity to be open
(`requires_open`) and can be disabled (`ladder_down` stays disabled until a deeper level exists).
Only the moving player's `region_id` changes. The host resets their movement check, sends them a
correction that names the new region, and updates the roster. That player's app shell rebuilds *its own*
view; nobody else's view or simulation changes.

**Entity types and host rules** (`WorldActions.request_interact`):

| type | state | rule |
|---|---|---|
| `door` | open | toggle (revision-checked) |
| `shelter_site` | stage none→building→built, open, tier | start a timed dig; when built, toggle the hatch. Completing it creates the bunker and level −1 |
| `portal` | enabled | move the player (see above) |
| `tree` | chops, felled | one chop per request (0.3 s cooldown). The felling blow gives its wood once, to that player (carry limit 30) |
| `stockpile` | — | deposit all carried wood into the bunker's resources |
| `support_site` | stage exposed→building→reinforced | wood is spent from the stockpile in the same step that starts the build, so a second request is refused |

**Timed construction.** Builds store `started`, `ticks` and stage `building` in entity state.
`WorldState.jobs` is rebuilt from that state on load. `Simulation.advance` completes due jobs
(`WorldActions.complete_construction`), and `GameSession._advance` publishes the results. Progress bars
read the replicated clock, so no extra network traffic is needed. A save made mid-construction
finishes after reload, exactly once.

**Replication added:** `_rpc_bunker` (bunker records, which may add regions on clients),
`_rpc_player_carried`, and `_rpc_notice`. `_rpc_correct_position` and `_rpc_submit_move` now carry
a region. `_publish_result` sends the changes in a fixed order: bunkers → entities → carried → region moves.
Protocol version 2. Save schema 2, with a migration from 1.

**Developer level command** (`create_level`, host only): finds the player's bunker, creates the next
depth below the deepest level from the `bunker_concrete` template, enables the ladder down above it,
and publishes the result. Depth is computed from existing levels, so it can never duplicate one.

**Views.** `EntityView` is the base for `PortalView`, `ShelterSiteView`, `StockpileView`, `TreeView` and
`SupportView`. Each one reads its definition and state, shows art from asset ids, and owns one
`Interactable`. Bunker level scenes are shared per template; the app shell sets
`region_id`/`def_id` before adding them. The camera frames the region bounds: rooms smaller than
the view stay centred.

**World map** (`MapPanel`, M): drawn from the surface region's `map` block (areas, roads, landmarks)
plus live state (trees, bunkers, players). `MapPanel.surface_point()` walks interiors (`surface` anchor)
and bunker levels (entrance → anchor) to a surface position and depth. The map is local and never pauses.

## 16. The survival slice (iteration 003)

Three host-only simulations were added. All of them hang off `Simulation.advance`, in this order:
construction/terrain jobs → `ZombieSim.step` → `SurvivalSim.step` → `InfraSim.step`. Each returns
`WorldActions`-style result dictionaries, and `GameSession._publish_result` sends them in a fixed order:
bunkers → terrain → entities → carried → vitals → events → region moves. Clients never run these
simulations. They only display what the host publishes.

### 16.1 Danger: zombies, noise, attention, combat, health

- **State.** `WorldState.zombies: {id → ZombieState}` holds the region, position, facing, AI state, health,
  target, last known position and a `persistent` flag. `WorldState.threat` (`ThreatState`) holds the noise
  queue, the per-zone attention values, reinforcement cooldowns and `enabled` (the developer's peaceful
  switch). Threat state is transient and never saved.
- **AI** (`ZombieSim`, tuning in `content/tuning/zombies.json`): `WANDER → INVESTIGATE → CHASE → WINDUP
  → RECOVER`, plus `STAGGER` when hit and `DEAD`. A zombie detects a player by proximity (omni radius),
  by sight cone with line of sight (`NavGrid.clear_line`), or by hearing. Hearing sends it to the noise
  position, not to the player. After losing sight it searches the last known position and then wanders
  again. Movement uses A* on a `NavGrid` (24 px cells) built from authored collision plus trees and
  closed doors, with a per-tick path budget.
- **Safety boundary.** Zombies exist only in surface regions that have a `zombies` content block.
  Interiors and bunker levels have none, and attacks need line of sight and reach, so nothing hits
  through walls or across regions.
- **Noise and hordes.** `ZombieSim.make_noise(world, region, pos, category)` queues a noise event.
  The categories (chop, fell, melee, run, door, dig, machine, dev) set the radius and the attention
  weight. Attention builds per zone, decays with a half-life, and crosses escalation thresholds that
  recruit nearby zombies and spawn capped reinforcements off-screen (minimum spawn distance, cooldown,
  per-wave and total caps, maximum active zombies).
- **Combat and health.** `WorldActions.request_attack(aim)` resolves a melee arc against zombies on the
  host (weapon table: bare hands, club). Zombies use a visible wind-up, so a player can step out of
  reach. `SurvivalSim` handles health regeneration (blocked while thirsty), defeat, and a forgiving
  respawn inside the farmhouse. Health, hydration, dead and weapon are replicated by `_rpc_vitals`.
- **Persistence.** The base population (id, region, position, health) and `next_zombie` are saved.
  Reinforcements and attention are deliberately dropped, so a reload starts calm without duplicating a horde.

### 16.2 Expansion: excavation grid and supports

- `RegionState.terrain` (optional; saved; schema 3) holds `dug` cells, in-progress `digging` cells and
  `supports`. The rules live in `Terrain` and the grid comes from the level template's `excavation` block:
  origin, cell size 64, size, `initial_open`, `permanent` and the support parameters.
- **Support rule.** A cell can be dug if it touches open space and lies within the safe margin of the
  original chamber, or within `support_radius_cells` of a reinforced support. Supports must keep
  `support_min_gap` cells between them. Refusals carry a reason key such as `ACTION_DIG_UNSUPPORTED`.
- `WorldActions.request_terrain` validates reach and the rule, then schedules a job
  (`terrain:dig:c,r` / `terrain:support:c,r`). Wood for a support is spent from the bunker's storage in the
  same step. `_rpc_terrain` replicates the region's terrain block, and `TerrainView` redraws and rebuilds
  collision from it.

### 16.3 Living underground: items, storage, scavenging, power, water, hydration

- **Items** (`content/items.json`, `Items`): `wood`, `fuel`, `water_dirty`, `water_clean`. A bag is a plain
  `{item_id: amount}` dictionary. `PlayerState.carried` is the player's bag (30 slots, one unit per slot)
  and `BunkerState.resources` is the bunker's **shared storage**. The timber stockpile and the storage
  locker are two views of that one store. `Items.move` changes both bags in the same step, and the host
  applies requests one at a time, so concurrent withdrawals can never duplicate items.
- **Scavenging** (`type: loot`, homestead car trunk, shed shelf and rain barrel): a search gives the
  authored `loot` once and records `looted_at`. The spot restocks after `restock_minutes` of simulated time,
  so the loop cannot soft-lock. A full bag refuses the search and leaves the loot in place.
- **Machines** (`WorldActions.request_entity_action(eid, action, arg)`, `_rpc_request_entity_action`):
  - `storage:store|take <item>`
  - `generator:fuel` (uses fuel from your hands first, then from storage; capacity 4) and `generator:toggle`
  - `purifier:fill` (dirty water from your hands, then from storage), `purifier:collect` and
    `purifier:drink_tap`

  All of these are range-checked, validated and committed by the host. The results go out as normal
  `entity_changed` / `bunker` / `carried` / `vitals` messages.
- **Generator and power** (`InfraSim`, tuning in `content/tuning/infrastructure.json`): while running, a
  generator burns fuel at `generator_seconds_per_fuel` and stops itself at zero. It also makes periodic
  `machine` noise. Power is logical: `InfraSim.is_powered(world, region)` is true while any generator in
  that bunker runs with fuel. Nothing stores a "powered" flag, so power is always consistent after a load
  or rejoin. Consumers: `LampView` (lights) and the purifier. The bunker never goes black when power is
  off: warm lanterns and the ladder shaft stay lit, and `Atmosphere.powered_tint` only brightens the scene.
- **Water.** The purifier turns one dirty unit into one clean unit every `purifier_seconds_per_unit` while
  powered. It has input and output capacities, and `progress` is published in 10 % steps.
- **Hydration.** Hydration falls at `hydration_loss_per_minute` for online, living players. Below
  `thirsty_below` the player is thirsty and health regeneration stops. At zero, health drains slowly but
  never below `dehydrated_health_floor`. Drinking clean water (Q, `_rpc_request_drink`) restores
  `hydration_per_drink`. Large clock jumps use elapsed time, not per-tick loops.
- **Persistence.** Machine state is ordinary entity state (fuel, running, input, output, progress,
  looted_at), so it is saved with the region changes. Bags and hydration are saved with players. This
  needed no schema change (schema 3; new fields are optional with safe defaults).
- **Presentation.** `MachineView` (storage, generator, purifier, loot spots) opens a `MachinePanel` that is
  built from world data. Panel buttons only send requests. `LampView` reads `is_powered`. The HUD shows the
  bag, the shared storage, power, the water bar, a thirsty warning and the drink hint.

Protocol version 4 (adds `_rpc_request_entity_action` and `_rpc_request_drink`).

## 17. The vertical slice (iterations 006–009)

Every new system follows the same pattern as before: plain data in `WorldState`, host-only rules in a
`src/sim/*` module, result dictionaries published by `GameSession._publish_result`, and views that only
read data and send requests. `Simulation.advance` now runs, in order: job completion → `ZombieSim` →
`SurvivalSim` → `InfraSim` (machines, hydration, hunger) → `FarmSim` → `EnvSim` → `EventSim` → `NpcSim`.

**State added (save schema 4, migration 3→4):**

| Where | What |
|---|---|
| `RegionState.objects` | Built structures and ground piles: `{oid: {def, tier, x, y, hp, stage, open, items, gear, job, output, crop, water, stored…}}` |
| `WorldState.next_uid` | Counter for object (`o…`) and gear (`g…`) ids; never reused |
| `WorldState.env` | Weather `{weather, until, seq}` (time of day is derived from the tick) |
| `WorldState.meta` | `heat`, `home_heat`, `siege`, `discoveries`, `unlocks` |
| `WorldState.npcs` | `NpcState` survivors |
| `PlayerState` | `gear` `[{uid, item, cond}]`, `equipped {hand, body}`, `hunger`; `weapon` is now derived from the equipped hand item |
| `BunkerState.resources` | Still the one shared store (stacks); crates hold their own `items`/`gear` |

The 3→4 migration turns a carried club into an equipped gear item. Everything else is optional with
safe defaults, so iteration 001–003 saves load.

**Modules:**
- `Build`: construction rules, which the placement preview also runs read-only on clients. It also covers
  structure damage, breach targets for zombies, and damageable authored gates (a content `structure` block).
- `Inv`: payment sources (your bag first, then shelter storage when underground or in the farmhouse),
  transfers, ground piles, and player inventory actions.
- `Craft`: workbench recipes and jobs (`craft:<oid>` world jobs) and the unlocks.
- `FarmSim`: the rain collector and the hydroponic planter.
- `EnvSim`: day/night and seeded weather.
- `EventSim`: regional heat, bunker/building noise leaking to the surface, extra wanderers, and the
  homestead defence event.
- `NpcSim`: the survivor's recruitment, travel, life on the bunker cell grid, jobs and upkeep.

**Zombies and structures.** Solid objects are dynamic `NavGrid` obstacles and block line of sight.
When a hunting or investigating zombie finds no path, it picks a breach target and hits it (minus
armour). Spike traps damage and slow zombies standing on them and wear out. Horde zombies (`siege`)
are steered to the homestead and go for the nearest exposed structure. Zombies still never enter
interiors or bunkers (GD-07/GD-22).

**Replication added:**
- Requests: `_rpc_request_build`, `_rpc_request_object`, `_rpc_request_inventory` and `_rpc_request_npc`.
- `_rpc_object(region, oid, data)`: one object; an empty `data` means it was removed.
- `_rpc_world_meta(env, meta)`: sent when weather, heat, the defence event, discoveries or unlocks change.
- `_rpc_npcs(rows)`: survivors, sent at the snapshot rate together with zombies.
- `_rpc_player_carried`: now carries the whole inventory (stacks, gear, equipped).
- Vitals rows also carry hunger.

Nothing broadcasts the whole world per frame. Protocol 5.

**Persistence policy (additions):**
- **Saved:** objects (including damage, tier, contents and running jobs), heat, the defence-event
  record, weather, discoveries, unlocks, survivors (identity, location, recruitment, job, activity,
  upkeep) and unique loot state (it never restocks).
- **Not saved:** horde and extra wanderer zombies. An active defence event respawns its remaining
  horde once after loading.

## 18. The World Awakens (iteration 011)

The same pattern again: plain data, host-only rules in `src/sim/*`, results published by
`GameSession._publish_result`, views that read and request. `Simulation.advance` now runs: job
completion → `ZombieSim` → `SurvivalSim` → `InfraSim` → `FarmSim` → `EnvSim` → `EventSim` → `NpcSim` →
`SleepSim` → `VehicleSim` → `WildlifeSim`.

**State added (save schema 4, all optional):**

| Where | What | Saved |
|---|---|---|
| `WorldState.vehicles` | `VehicleState`: def, region, position, rotation, engine, seats (0 = driver), trunk `{items, gear}`, key/locked (reserved) | yes |
| `WorldState.animals` | `AnimalState` wolves and bears | no (rebuilt from content) |
| `PlayerState` | `warmth`, `vehicle_id` (saved); `flashlight` (runtime, replicated in the vitals row) | partly |
| `WorldState.meta` | `sleep_vote`, `last_screech` | yes (meta) |
| `ZombieState` | posture, burst, listen, screech cooldown, search (transient) | no |

**Modules:** `SleepSim` (shelter groups, vote, chunked sleep), `VehicleSim` (seats, engine, trunk,
validated driver poses, road exits, ejecting downed or disconnected occupants, engine noise),
`WildlifeSim` (roam / watch / flee / call), `WorldActions.ensure_prebuilt_shelters` (bunkers for shelter
sites authored as already built, e.g. the Ashgrove cellar), `Inv.toggle_flashlight`.

**Network.**

| Message | Direction | Reliability |
|---|---|---|
| `_rpc_request_vehicle(id, action, arg)` | client → host | reliable |
| `_rpc_submit_vehicle_pose(id, pos, rot, speed, steer)` | driver → host, 20 Hz | unreliable ordered |
| `_rpc_vehicles(rows)` | host → all, at the snapshot rate | unreliable ordered |
| `_rpc_vehicle(id, full state)` | host → all, on seat/engine/trunk/region change | reliable |
| `_rpc_vehicle_correct(id, pos, rot)` | host → driver, when a pose is rejected | reliable |
| `_rpc_animals(rows)` | host → all, at the snapshot rate | unreliable ordered |
| `_rpc_request_sleep_vote(yes)` | client → host | reliable |

A result can now carry `transitions` (several players changing region together, e.g. a car and its
occupants), `roster`, `vehicles`, `broadcast_notice`, `private_notice` and `sleep_ticks`. The local
driver predicts the car (`VehicleView`, CharacterBody2D with an oblique footprint); the seated avatar
hides, stops sending moves and follows the car's view; the host keeps occupant positions on the car.

**Regions and roads.** A region can list `vehicles` (authored placements, created once by
`VehicleSim.ensure`) and `vehicle_exits` (`{rect, target: {region, position, rotation}}`); the front
bumper entering an exit transfers the car. The map draws every discovered region at its `map.offset`
and marks exits whose target is undiscovered (`MapPanel.unexplored_exits`).

**Assets.** `AssetResolver.custom_graphics` (setting `assets/use_custom_graphics`) skips image
overrides when OFF; `set_custom_graphics()` saves the choice and reloads, so every view re-resolves
through `Assets.reloaded`. The focus highlight is a shared ShaderMaterial put on the focused target's
own sprites by `Interactable._highlight`.

## 19. Shadows & Depth (iteration 012)

- **Silhouettes (presentation only).** `ZombieView` puts a `ShaderMaterial` (`silhouette.gdshader`) on
  every Burnt One. Its `light()` function adds 2D light only to the outline band, so lights cannot
  reveal the interior. Archetypes come from the creature's id. The developer AI labels remove the
  material.
- **Thawed blood.** `BloodSim` is host-side and runs after `WildlifeSim` in `Simulation.advance`.
  - Heat sources: region `heat_sources`, running vehicles and `WorldState.dev_heat`.
  - `ZombieState.thaw` and `drip_cd` are transient; marks live in `WorldState.blood`, which is saved.
  - Results carry `blood`, and `GameSession` replicates the whole list with `_rpc_blood` (reliable).
  - `BloodView` draws the marks, judging readability from the local player's viewpoint.
- **Side-view bunker (experimental).** `SideSection` (in `src/sim`) is the shared cross-section
  reading of a level. `main.gd` builds a `SideBunkerView` (a `RegionView` with `side = true`) instead
  of the level scene when the client's bunker view is "side".
  - The ordinary entity, structure and NPC views and `PlayerAvatar` check `RegionView.side` to place
    themselves in the cross-section, using `SideArt` for side pictures.
  - `SideTerrain` draws the level and handles side-view digging.
  - `PlayerState.bunker_view` (runtime) is set by `request_bunker_view` / `_rpc_request_bunker_view`.
    The host uses it to put feet on the floor on arrival and to validate side-view moves.
  - Bunker reach (`SideSection.in_reach`) also accepts "horizontally close within the same open space"
    for interactions, entity actions, digging, supports, building, built objects and talking to
    survivors.
  - No data is converted: both views read plan coordinates.

## 20. The Scavenger's Circuit (iteration 013)

- **Interiors are ordinary regions.** `tools/build_interiors.py` generates seven interior regions
  (`content/regions/town_<name>.json`) and their scenes from layout specs, and patches the Ashgrove street
  (entrance portals; house doors work like the town house). Interiors have no `zombies` block, so Burnt Ones
  never enter and no precipitation is drawn; their `surface` makes noise leak to the street (`EventSim.leak_target`).
  `climate.shelter` (new, `EnvSim.cold`) scales the cold of an unheated building. `Atmosphere.follow_daylight`
  and `LightSpot.daylight` make window light follow the shared clock.
- **Containers.** Entity type `container`; host rules in `ScavengeSim` (called from `request_interact`,
  `request_entity_action` and `Simulation.advance`). The search in progress lives in the container's entity
  state (`by`, `from`, `until`), so it replicates like any entity change; `SaveService` strips it before
  writing (`ScavengeSim.strip_searches`). On completion the state gets `searched`, `items`, `gear` once;
  taking uses `Inv.transfer`. `ContainerView` draws art by state and a progress bar for everyone.
- **Skills.** `SkillSim` (data in `content/tuning/skills.json`) owns every skill calculation. XP lives in
  `PlayerState.skills` (saved, and replicated in `inventory_dict` with the `players` result key); levels are
  derived. The developer XP multiplier is `world.meta.xp_multiplier` (replicated with `meta`, removed by
  `SaveService` before writing). Search results carry a `search_done` event for the HUD feedback.
- **Developer tools.** `BuildInfo.dev_tools_enabled()` gates the F3 menu and every dev command (debug builds,
  or `--dev-tools`). Progression commands (`xp_multiplier`, `grant_xp`, `set_skill_level`, `reset_skill`) are
  refused for clients even when `allow_client_dev_commands` is on.
- **Shelter improvement.** The `stove` buildable has `heater: true`; `Build.heated` feeds
  `SurvivalSim.warmth_rate`. The trunk and shelter storage gained `store_all` / `take_all` actions.

## 21. The Five Settlements (iteration 014)

- **Side-view regions.** A region with `"view": "side"` is a cross-section on the excavation grid
  (`excavation.fixed: true` → `Terrain.is_permanent`, no digging, no supports; `platforms` = stair landings).
  `SideSection` owns the side-view rules (`always_side`, `side_for`, `settle`, `floor_y`/`run_of` with
  `climb`, `climbable` for ladders and `stairs` entities, `same_floor`, `chase_step`). `main.gd` builds a
  `SideBunkerView` for any side region; `SideTerrain` draws building (`_draw_building`) and mine styles.
  Regions are generated by `tools/build_side_interiors.py` (Ashgrove + cabin), `tools/build_settlements.py`
  (new towns, interiors) and `tools/build_landmarks.py` (civic hall, mine). Ids are stable.
- **Settlements** are generated top-down scenes (`scenes/regions/settlements/*.tscn`) plus region JSON with
  road portals, `vehicle_exits`, `map.offset`, `map_areas` and landmarks. `IceDrift` positions are a pure
  function of the world clock, so nothing about the ice is stored or sent.
- **Hideout.** `HideoutSim` (host): `ZombieSim.make_noise` → `HideoutSim.noted` (disturbance in entity state);
  `step` triggers once (persistent Burnt Ones) and marks it cleared; `door_goal` / `follow_out` take
  pursuers to the street. `ZombieSim` uses `SideSection.same_floor` / `chase_step` in side regions.
- **Firearms.** `Firearms` (host): `WorldActions.request_attack` → `Firearms.fire` when a firearm is held;
  `Inv.request("reload")` → `reload_held`. Rounds live in the gear dict (`loaded`), saved by `PlayerState`.
  Shots publish `shot` / `dry_fire` / `reload` events (muzzle flash, tracer, sound in `RegionView`).
- **Time scale.** `GameSession.time_scale` scales only the single-player tick accumulator; the `time_scale`
  dev command is refused unless `mode == SINGLE`. Runtime only.
- **Items.** `Items` (catalogue, stack limits → `slots`, `room_for`), `Inv.capacity` (base + worn `carry`),
  `Inv.room_for` used by every pickup path. `SurvivalSim.insulation` sums worn clothing.
  `Inv._use` handles eat/drink side effects, `warm`, `repair_hand`, and light sources (`toggle_flashlight`:
  lamps toggle, glow sticks and flares are consumed with `PlayerState.light_until`, runtime).
  `InventoryPanel.describe` builds tooltips (also used for crafting uses).
- **Loot.** `LootPools.roll(world, pool, container_id)` uses `world.make_rng("loot:" + id)` and is called once
  by `ScavengeSim._finish` for containers with a `pool` and no authored contents.

## 21b. The World Reborn (iteration 015)

- **World geography.** `tools/world_layout.py` gives every outdoor region a world offset; `WorldGeo` (pure, no
  state) answers `is_outdoor`, `world_rect`, `region_at`, `crossing` (edge travel with a free arrival spot) and
  `walls`; `WorldActions.edge_travel` (from `GameSession._host_handle_move`) and `VehicleSim.submit_pose` move
  players / vehicles across. Exploration memory lives in `world.meta["explored"]` (`WorldGeo.step`).
- **Wilderness regions** are data (`wild` block + `obstacles`) generated by `tools/build_wilderness.py`;
  `WildTerrain` streams the scatter in chunks and creates portal / container / door views.
- **PlayerSight** (presentation only): view polygon → SubViewport mask → full-screen shader; `visibility(pos)`
  fades `ZombieView`, `AnimalView`, hostile `PersonView`.
- **UI.** `UITheme` (textures + fallbacks), object-anchored `MachinePanel` (`grid`, `progress`, request callable),
  `LockpickPanel`, `FactionsPanel`.
- **Scavenging.** `ScavengeSim` reveals slot by slot (`finds` deterministic from authored loot / `extra` /
  `LootPools.roll_list`; state `revealed`/`total`); `LockSim` (host) for locks; `GameSession.lock_feedback` carries
  the private turn result.
- **Threats.** `HordeSim` (transient hordes in `ThreatState.hordes`), `ZombieSim` level of detail (`_dt` per
  stride), `HideoutSim.all/reset`, `WildlifeSim._danger` (packs, territory), `WildlifeSim.damage/target_for`
  (melee + `Firearms`).
- **Factions.** `FactionSim` (host): people (`PersonState`, `world.people`, rows like animals), persistent per-player
  state in `world.meta["factions"]` (rep, credit, stock, missions, law, dead, kills); `request_faction` RPC for
  trade / repair / missions; crimes hooked from `Firearms.fire`, `WorldActions.request_attack`, `ScavengeSim.take`;
  `gate_denied` in `request_interact`. Content: `content/factions.json` (written by the wilderness builder).

## 22. Dependency direction

```
presentation (main, ui, world views) ──reads/requests──▶ Session ──▶ WorldActions / Simulation ──▶ state
        │                                                  │
        └──▶ Assets / Audio / Settings                    └──▶ Saves (SaveCodec) , Net
state, sim, content, persistence never reference presentation.
```
