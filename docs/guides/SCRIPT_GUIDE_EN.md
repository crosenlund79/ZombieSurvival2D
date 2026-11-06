# Script Guide (English)

Plain-language description of every GDScript file. Identifiers and paths are exact. Keep this file and `SCRIPT_GUIDE_DA.md` in step; `python3 tools/check_script_guides.py` reports gaps.

## Core services (autoloads)

| Script | Depends on | What it does |
|---|---|---|
| `src/core/session_log.gd` | — | Autoload `SessionLog`. The black box: writes short structured records (category, event, data) to memory and to a JSON-lines log file, with size limits and spam throttling. Only observes. |
| `src/core/settings_service.gd` | SessionLog, Paths, Localization | Autoload `Settings`. Personal preferences on this computer: volumes, window/fullscreen, UI scale, camera zoom, language, key bindings, and the private identity token per player name. Never part of the shared world. |
| `src/core/asset_resolver.gd` | AssetCatalog, SessionLog | Autoload `Assets`. Turns an asset ID into a texture or sound: looks for the creator's external override, then the bundled override, then the template, then a visible fallback. Validates files, caches results, and fits images into their display box. |
| `src/core/audio_service.gd` | Assets, Settings | Autoload `Audio`. Plays sounds by ID through five buses: pooled one-shots (optionally positioned in the world) and named loops with fades that do not restart if already playing. |
| `src/core/game_session.gd` | Net, Saves, Settings, WorldActions, Simulation, SaveCodec | Autoload `Session`. The heart of a running game: starts single player / host / join, holds the world, registers players, runs the shared clock, and contains every network message. The host validates requests; clients only ask. |
| `src/net/net_service.gd` | SessionLog | Autoload `Net`. Opens and closes the ENet connection (host or client) and reports its status. Knows nothing about the game world. |
| `src/persistence/save_service.gd` | SafeFile, SaveCodec, Paths | Autoload `Saves`. Saves and loads world files in one folder per world, using the safe-write routine, and falls back to the backup if the main file is damaged. |

## Core helpers

| Script | Depends on | What it does |
|---|---|---|
| `src/core/build_info.gd` | SaveCodec | Game title, version, iteration, stage and protocol number; reads the commit id from `.git` if present. Used by the bottom-right label, logs and saves. |
| `src/core/paths.gd` | — | Reads `--key=value` command-line arguments and gives each `--instance` its own user folder for settings, logs and saves. |
| `src/core/safe_file.gd` | — | Protected JSON writing: temporary file, read-back check, backup of the previous file, then replace. Also safe JSON reading. |
| `src/core/localization.gd` | SafeFile | Loads `locale/strings.json` (English/Danish) into Godot's translation system. |
| `src/core/asset_catalog.gd` | SafeFile | Reads the asset manifests and works out each asset's template, bundled-override and external-override paths. Pure data, usable by editor tools. |

## World data and rules

| Script | Depends on | What it does |
|---|---|---|
| `src/content/content.gd` | SafeFile | Reads authored region files (`content/regions/*.json`): entities, positions, reach, initial state, spawn points; computes a content fingerprint so host and client can confirm they match. |
| `src/state/npc_state.gd` | — | One survivor as plain data: identity, name, location, recruitment state, health, job, activity, status and settlement. Everything is saved. |
| `src/state/zombie_state.gd` | — | One zombie as plain data: identity, region, position, health, AI state and short-term memory. Only the base population's identity/position/health is saved. |
| `src/state/vehicle_state.gd` | — | One vehicle as plain data: type, region, position, heading, engine, seats (index 0 = driver), trunk, and reserved key/lock fields. Saved (except the driver-reported speed). |
| `src/state/animal_state.gd` | — | One wild animal as plain data (species, region, position, facing, activity, home area, timers). Transient: wildlife is rebuilt from content when a world starts. |
| `src/state/threat_state.gd` | — | World noise queue and attention per coarse zone (transient: never saved, so a reloaded world starts calm). |
| `src/state/world_state.gd` | Content, RegionState, PlayerState, Simulation | The whole shared world as plain data: id, seed, clock tick, regions, players. Also gives seeded random number streams. |
| `src/state/region_state.gd` | Content | Player-made changes to one region, stored only where they differ from the authored content, with a revision number per object. |
| `src/state/bunker_state.gd` | — | One shelter as plain data: its entrance identity, levels by signed depth (no maximum) and the shared stockpile. Builds and parses level region ids. |
| `src/state/player_state.gd` | Content | One player's saved record: identity, name, region, position, facing. |
| `src/sim/nav_grid.gd` | Content, Prop, FenceLine | Host-side walkability grid built from the region scene's authored collision data, plus live trees/gates; A* paths and line-of-sight checks for zombies and attacks. |
| `src/sim/zombie_sim.gd` | NavGrid, ThreatState, WorldState | Host-only simulation of the Burnt Ones (still called zombies in code): hearing, attention escalation/decay, the AI state machine, movement, attacks and corpses; developer-started hunts (start_hunt, scent re-acquire, give up, hunt diagnostics). Populations and reinforcements only run with the automatic loop switched on (ThreatState.ambient). |
| `src/sim/sleep_sim.gd` | WorldState, EnvSim, WorldActions | Communal sleeping (host): shelter groups (cabin + its bunker), evening-only sleep, inner-monologue refusals from real events when someone is outside, a unanimous replicated vote (cancel on no / timeout / leaving), the sleep result that GameSession turns into a chunked clock jump, and waking rested and warm. |
| `src/sim/vehicle_sim.gd` | WorldState, VehicleState, ZombieSim, Inv | Host-authoritative vehicles: authored placements (created once), enter / exit (beside the car, only when stopped), engine (driver only, noise), validated driver poses with occupants carried along, road exits that move the car with everyone in it and its trunk to the next region, trunk store / take, ejecting downed or disconnected occupants, engine noise, heater for warmth, save encode / decode and seat validation. |
| `src/sim/wildlife_sim.gd` | WorldState, AnimalState, NavGrid, EnvSim | Non-aggressive wolves and bears (host): placement from `content/tuning/wildlife.json`, idling and wandering on walkable ground near home, noticing players (watch), backing off or bolting, calls (more at night) as sound events, compact rows for clients. Never attacks. |
| `src/sim/blood_sim.gd` | WorldState, EnvSim, VehicleSim | Thawed blood (host): heat sources (authored region `heat_sources`, running engines, developer heat), Burnt One thaw / refreeze, occasional small drips that refreeze into marks, weather erasure (fade, snow cover, rain wash), visibility for presentation, save encode / decode. |
| `src/sim/side_section.gd` | Terrain, RegionState, Content | Iteration 012 (experimental): the cross-section reading of a bunker level shared by host and side view — floors, ceilings and open runs from the excavation grid (or the room of a grid-less level), resting / hanging positions, side-view walking (one-row steps, walls, no jumping), climbable ladders and supports, side-view reach, and the presentation projection (rows drawn shorter). |
| `src/sim/scavenge_sim.gd` | WorldActions, SkillSim, Inv, ZombieSim | Iteration 013: physical containers (host) — one searcher at a time, timed searches from the shared clock, cancel / interrupt (walking away, leaving, vehicle, death, disconnect), completion reveals the authored contents once (never regenerates), Scavenging XP once, search noise by container kind, taking what is left, save stripping of searches in progress. |
| `src/sim/skill_sim.gd` | PlayerState, content/tuning/skills.json | Iteration 013: per-player skills (only Scavenging active) — XP to level curve, level cap, search-time effect (never instant), XP awards scaled by the developer XP multiplier, set / reset, save sanitising. |
| `src/sim/omen_sim.gd` | WorldState, EnvSim | Red Thaw atmospheric omens as pure functions of the world seed and clock: daytime laughter at authored settlement spots and night-time silhouettes along authored paths. Nothing stored or sent, so every player experiences the same event. |
| `src/sim/survival_sim.gd` | WorldActions | Host-only player vitals: slow health recovery and the forgiving respawn rule (keep everything, wake in the farmhouse). |
| `src/content/items.gd` | SafeFile | Item catalogue (`content/items.json`): stable item ids, name keys, carrying slots, and `move()` which transfers between two bags in one step so nothing duplicates. |
| `src/sim/infra_sim.gd` | Simulation, WorldActions, ZombieSim, Content | Host-only infrastructure on the shared clock: generator fuel burn and auto-stop, logical bunker power (`is_powered`), purifier conversion over time when powered, hydration decay and mild dehydration. |
| `src/sim/inventory.gd` | Items, WorldState | Inventory transactions: carrying slots, which bags pay (your bag, then shelter storage underground), paying, gear records, giving items (overflow lands in a ground pile), container transfers. |
| `src/sim/build.gd` | Content, Terrain, Inv, NavGrid, ZombieSim | Construction rules: definitions, footprints, placement checks (zones, open bunker floor, occupancy, keep-clear, never trap a bunker area), building, upgrade, repair, dismantle, piles and crates, structure damage, breach targets for zombies. |
| `src/sim/farm_sim.gd` | Build, InfraSim, EnvSim, Inv | Production by built objects on the shared clock: the rain collector (faster in rain) and the hydroponic planter (needs clean water and power). Collect, water and harvest actions. |
| `src/sim/env_sim.gd` | WorldState | Day/night and weather from the shared clock: time of day, daylight, seeded rain/clear spells, and the effects on zombie sight and hearing. |
| `src/sim/craft.gd` | Build, Inv, Items, WorldState | Workbench crafting rules: recipes (content/recipes.json), unlocks shared by the world, one timed job per bench paid at start, output held until collected, gear repair. Jobs survive saving and finish once. |
| `src/sim/event_sim.gd` | ZombieSim, Build, EnvSim | Regional threat heat (noise, kills, decay, extra wanderers), bunker/building noise leaking to the surface, and the homestead defence event (warning, horde, structure attacks, outcome, cooldown, resume after load). |
| `src/sim/npc_sim.gd` | NpcState, Inv, FarmSim, InfraSim, Terrain | Survivor simulation: recruitment, travelling home, life in the bunker on the cell grid, water and farm jobs using shared storage and real machines, daily upkeep, sheltering during a horde, replication rows. |
| `src/sim/terrain.gd` | Content, RegionState | Excavation rules for a region's earth-cell grid: open/solid cells, permanent cells, the support rule (safe margin + reinforced supports' radius), validation reasons. |
| `src/sim/simulation.gd` | WorldState | The one shared clock (10 ticks per second). Future timed systems attach here. |
| `src/sim/world_actions.gd` | WorldState, Content | Host-side rules: checks an interaction request (who, where, how far, which revision) and applies it; checks that reported movement is physically possible. |
| `src/persistence/save_codec.gd` | WorldState, Content, BuildInfo | Converts the world to/from the save format, validates it, fills safe defaults, drops removed content with warnings, and runs migrations for old schema versions. |

## Presentation — app and interface

| Script | Depends on | What it does |
|---|---|---|
| `src/presentation/app/main.gd` | Session, all UI panels, RegionView | App shell: switches between menu and the region view, routes keys (menu, save, F3, F12), can rebuild the view from world data, takes screenshots. Holds no game state. |
| `src/presentation/ui/ui_theme.gd` | — | The single shared interface theme (palette from the visual direction) and small text helpers. |
| `src/presentation/ui/ui_root.gd` | Settings, UITheme | Root of all panels: applies the theme and UI scale and always fills the window at any aspect ratio. |
| `src/presentation/ui/main_menu.gd` | Session, Saves, Settings | Start menu: Single Player, Host, Join, Settings, Quit; world continue/new; join address and port; shows errors in plain words. |
| `src/presentation/ui/settings_panel.gd` | Settings, Assets | Settings window: volumes, display, UI scale, language, key rebinding, override folder and reload. Saves immediately; never pauses the world. |
| `src/presentation/ui/map_panel.gd` | Session, Assets, Hud | World map (M): roads, areas, landmarks from content; trees, shelters and players from live state; depth when underground. |
| `src/presentation/ui/hud.gd` | Session, InteractionSensor | In-game overlay: status line, the interaction prompt, short notices. |
| `src/presentation/ui/machine_panel.gd` | UITheme, Session | Small in-world panel for one machine (storage, generator, purifier): title, status lines and buttons built by the machine view; refreshes from world data, closes when out of reach or on Esc. Buttons only send requests to the host. |
| `src/presentation/ui/build_mode.gd` | Build, Inv, Session | The build menu (B) and placement preview: green/red ghost that follows the mouse using the same rules as the host, the reason when refused, and placing. |
| `src/presentation/ui/craft_panel.gd` | Craft, Session, MachinePanel | The workbench panel: recipes with materials and time, crafting jobs, collecting output, repairing worn gear. |
| `src/presentation/ui/inventory_panel.gd` | Session, Items, Inv | Inventory panel (I/Tab): equipped hand and body slots, gear with condition and stats, stacks with descriptions; Use, Equip, Put away and Drop buttons send requests to the host. |
| `src/presentation/ui/guide.gd` | Session, Settings, EventSim | Player guidance: one-time contextual tips (shown once per installation, can be switched off) and the survival guide (H) with every topic and a progress overview read from the shared world. |
| `src/presentation/ui/settlement_panel.gd` | Session, NpcSim, InfraSim | Settlement overview (N): inhabitants, jobs and what blocks them, supplies in shared storage, power and needs; job assignment buttons send requests. Also builds the survivor's own panel. |
| `src/presentation/ui/pause_menu.gd` | Session | Esc menu: resume, save (host), settings, leave. The shared world keeps running. |
| `src/presentation/ui/dev_overlay.gd` | Session, Net, Assets, Audio, SessionLog | F3 developer panel: build, network and world state, players, entity states, save status, overrides, log path, and a few host-checked commands. |

## Presentation — world

| Script | Depends on | What it does |
|---|---|---|
| `src/presentation/world/region_view.gd` | Session, Content, PlayerAvatar, Audio | Shows one region for the local player: creates/removes avatars of players in that region, starts the region ambience. Can be freed and rebuilt freely. |
| `src/presentation/world/player_avatar.gd` | Session, Assets, Settings, InteractionSensor | A player's figure. Local: reads input, moves with collision, sends positions, owns the camera and zoom. Remote: glides to host positions. Walking bob and flip are visual only. |
| `src/presentation/world/door_view.gd` | Session, Content, Assets, Audio, Interactable | Shows a door/gate entity from world data: picture for open/closed, a blocker while closed, prompt text, and the sound when the host reports a change. |
| `src/presentation/world/interactable.gd` | Content, Session, Settings | A focusable interaction point with reach and priority from content; activating it only sends a request to the host. |
| `src/presentation/world/interaction_sensor.gd` | Interactable, PlayerAvatar | On the local avatar: picks the single best target (priority, then nearest) and triggers it on the interact key. |
| `src/presentation/world/prop.gd` | Assets, AssetCatalog | A standing world object: shows art by asset ID, adds a collision footprint that is independent of the art, fades when the local player is behind it, optional wind sway. Previews template art in the editor. |
| `src/presentation/world/fence_line.gd` | Prop, AssetCatalog | A straight fence between two points: fits a whole number of segments and adds one collision strip. |
| `src/presentation/world/ground_patch.gd` | Assets, AssetCatalog | A ground surface polygon (grass, dirt, road) filled with a tiling texture; edit its shape in the editor. |
| `src/presentation/world/scatter.gd` | Prop | Seeded decorative dressing (grass, flowers) inside an area, avoiding given rectangles — identical for every player. |
| `src/presentation/world/atmosphere.gd` | Assets | Mood layer: warm colour grade, drifting seed fluff, paper grain and vignette. Presentation only. |
| `src/presentation/world/entity_view.gd` | Session, Content, Assets, Interactable | Base for world-object views: position and reach from content, state from the world, art from asset ids, one Interactable; subclasses refresh on changes. |
| `src/presentation/world/portal_view.gd` | EntityView | Doorways and ladders between regions; hidden/unusable while disabled or while the required hatch/door is closed. |
| `src/presentation/world/shelter_site_view.gd` | EntityView, ProgressMarker, Audio | Shelter site in a building: marked → digging (progress bar) → wooden hatch that opens and closes. |
| `src/presentation/world/stockpile_view.gd` | EntityView | The shared timber pile; art grows with the bunker's stock; deposit prompt shows what you carry. |
| `src/presentation/world/tree_view.gd` | EntityView, Prop | Harvestable tree: chop feedback (shake, chips, sound), fall animation, stump; trunk collision only while standing. |
| `src/presentation/world/support_view.gd` | EntityView, ProgressMarker | Reinforcement spot: unreinforced earth → building → timber frame; prompt shows cost and stock. |
| `src/presentation/world/progress_marker.gd` | — | Small inked progress bar drawn above something being built. |
| `src/presentation/world/light_factory.gd` | — | Generates the soft radial texture for 2D lights and builds lantern lights. |
| `src/presentation/world/light_spot.gd` | LightFactory | A scene light (lantern, window, ladder shaft) using the shared radial texture. |
| `src/presentation/world/zombie_view.gd` | Session, Assets, Audio | Shows one zombie from world data: interpolation, shamble, ?/! cues, red wind-up pose, hit flash, health bar, fall on death, local groans. |
| `src/presentation/world/vehicle_view.gd` | Session, VehicleSim, Assets, LightFactory | Shows one vehicle (16-heading art, oblique collision footprint, headlights, tail light, exhaust, engine loop pitched by speed); when the local player drives it, predicts the car with top-down physics and reports poses to the host. Enter / trunk interaction and the trunk panel. |
| `src/presentation/world/animal_view.gd` | Session, Assets | Shows one wild animal from world data: interpolation, side art with a two-frame walk (flipped for left), front and back art, an alert lift and a running bob. |
| `src/presentation/world/blood_view.gd` | Session, BloodSim, Assets | Draws a region's thawed-blood marks: small drops, whitened under fresh snow, paler after rain, faint or hidden in fog, blizzards and at a distance (from the local player's view). No markers or HUD. |
| `src/presentation/world/side_art.gd` | SideSection, AssetCatalog | Iteration 012: which side-view picture stands in for a top-down one, and where entities and objects sit in the cross-section (floor or ceiling, stretched floor-to-ceiling for scaffolding, through the ceiling for the ladder). |
| `src/presentation/world/side_bunker_view.gd` | RegionView, SideSection, SideTerrain | Iteration 012 (experimental): a bunker level drawn as a 2D side view, built in code from the same region data (entities, objects, terrain, players, survivors) with side-view art. Default for bunker levels; F7 switches to the original top-down scenes. |
| `src/presentation/world/container_view.gd` | EntityView, ScavengeSim, MachinePanel | Iteration 013: a searchable container — art by state (authored / searched), a progress bar while anyone searches it, E to search / stop, then a small panel to take what is left. |
| `src/presentation/world/side_terrain.gd` | SideSection, Terrain, Session | Iteration 012: draws the cross-section (earth strata, bedrock, dug rooms, floorboards, ceiling beams, concrete slabs, the shaft, digging progress, supports as scaffolding) and offers the side-view dig / support prompt for the cell you face. |
| `src/presentation/world/weapon_rack_view.gd` | EntityView | The club rack in the farmhouse; taking a club equips the player (one each, never runs out). |
| `src/presentation/world/machine_view.gd` | EntityView, MachinePanel, InfraSim, Items, Audio | Storage locker, generator, water purifier and surface scavenge spots: art for on/off/empty, the machine panel contents, direct searching of loot spots, generator hum loop while running. |
| `src/presentation/world/lamp_view.gd` | EntityView, InfraSim, LightSpot | Electric bunker lamp: lit with a light while the bunker has power, dark otherwise. Only reads the logical power state. |
| `src/presentation/world/structure_view.gd` | Session, Build, Assets, MachinePanel | Shows one built structure or ground pile: art by state, collision while it blocks, condition/progress bar, hit feedback; the panel with repair, upgrade, dismantle and container/production actions. |
| `src/presentation/world/npc_view.gd` | Session, NpcSim, Assets, MachinePanel | Shows one survivor from replicated data with a talk interaction. Before they trust you, the frightened survivor is huddled in a corner: trembling, occasional muttering with fragmented lines, flinching and answering when spoken to (local presentation). |
| `src/presentation/world/starter_bag_view.gd` | EntityView, Session, Audio | The bag beside the burned shed: full or emptied for the local player; the host hands each player one starter kit (WorldActions._starter_bag). |
| `src/presentation/world/bed_view.gd` | EntityView | A bed or bedroll: the sleep interaction (and bedroll art in bunkers). |
| `src/presentation/world/omen_view.gd` | OmenSim, Assets, Audio | Plays a region's omens for the local player: positional laughter when near the spot (never shown), and a brief depth-sorted silhouette walking its path at night. Keeps a short diagnostics list. |
| `src/presentation/world/terrain_view.gd` | Terrain, Session, Assets | Draws dug floor, solid earth, 3/4 wall faces and inked edges from the grid; rebuilds collision on changes; places support posts; the contextual dig/support prompt with a coloured target outline. |
| `src/presentation/world/placeholder_block.gd` | — | Greybox helper (used in Phase A, kept for blocking out new areas): a coloured rectangle with matching collision. |
| `src/presentation/world/placeholder_ground.gd` | — | Greybox ground with a 100 px grid (unused in the current scene). |

## Developer and tests

| Script | Depends on | What it does |
|---|---|---|
| `src/dev/dev_preset.gd` | Build, Inv, NpcSim, SessionLog | Developer Test World preset (prepared shelter, machines, workbench, planter, stock, tools, survivor at home; marked in world.meta) and the F3 problem report writer (build, world, location, systems, recent log). |
| `src/dev/content_check.gd` | Content, AssetCatalog, Localization | Content integrity inspection (PASS/WARN/FAIL): regions, region scenes, manifests, asset IDs used in code, translations. Never changes anything. |
| `src/dev/autotest_driver.gd` | Session, Saves, Assets, Audio | Test-only remote control (only with `--autotest`): reads commands from a file and writes state reports, so `tools/mp_test.py` can drive real separate game processes. |
| `tests/test_case.gd` | — | Tiny base class for unit tests (`check`, `eq`). |
| `tests/test_runner.gd` | TestCase, ContentCheck | Runs every test file in tests/unit and the content check, writes results, exits with an error code on failure. |
| `tests/unit/test_threat.gd` | ZombieSim, WorldActions, NavGrid | Tests navigation, sight, hearing, attention growth/decay, escalation caps, melee authority, walls, wind-up damage, respawn, the farmhouse boundary and the persistence policy. |
| `tests/unit/test_infra.gd` | Items, InfraSim, WorldActions, SaveCodec | Tests item moves, shared storage races, scavenging and restock, generator fuel/power, purifier needing power and time, hydration/drinking and save round trip. |
| `tests/unit/test_build.gd` | Build, Inv, ZombieSim, SaveCodec | Tests placement and its rules, spend-once, concurrent placement, upgrade/damage/repair/destruction, dismantle refunds and contents, zombie breaching, spike traps, bunker rules, the hatch upgrade, persistence and the 3→4 migration. |
| `tests/unit/test_survival_cycle.gd` | Inv, Craft, Build, FarmSim, InfraSim, SaveCodec | Tests equip/drop/pick up/use, carry limits with gear, spend-once and timed crafting, unlocks, crafting across save/load, equipment effects (chopping, armour, wear), gear repair, hunger, planter food production and new loot. |
| `tests/unit/test_world_events.gd` | EventSim, EnvSim, ZombieSim, WorldActions, SaveCodec | Tests regional heat and decay, bunker noise leaking through the hatch, the defence event lifecycle (incl. save/load without duplication), hordes attacking structures, shared seeded weather and night, rain collectors, the service station's unique find and the carburetor. |
| `tests/unit/test_red_thaw.gd` | WorldActions, Inv, ZombieSim, EventSim, OmenSim, SaveCodec | Tests the opening (spawns by the bag, one kit per player incl. after reload), the kit items, no automatic threats by default, developer hunts (pursuit, attack, protected cabin, giving up, not saved) and deterministic day/night omens. |
| `tests/unit/test_world_awakens.gd` | ZombieSim, ExposureSim, SleepSim, VehicleSim, WildlifeSim, SaveCodec | Iteration 011 tests: Burnt One listening, screeches, response limits and cooldowns, postures and crawling bursts, searching after a lost target; and the later milestones' systems. |
| `tests/unit/test_shadows_depth.gd` | TestCase | Iteration 012: thawed blood (no blood without warmth, warmth thaws and drips a few small marks, refreezing stops it, engines as heat, weather erasure and visibility, persistence) and the side-view bunker. |
| `tests/unit/test_scavengers_circuit.gd` | TestCase | Iteration 013: Ashgrove interiors (entering and leaving every building, shelter, sound leaking to the street), location loot, timed searches, cancel / interrupt, one searcher per container, no duplicated loot or XP, the search-time curve, the XP multiplier, persistence. |
| `tests/unit/test_settlement.gd` | NpcSim, NpcState, Build, InfraSim, SaveCodec | Tests the survivor: encounter, recruitment conditions and travel, water and farm jobs using only stored resources and real machines, status when blocked, daily upkeep, sheltering during a horde, persistence without duplication. |
| `tests/unit/test_terrain.gd` | Terrain, WorldActions, SaveCodec | Tests the grid, dig validation and timing, concurrent digs, support spending/radius/spacing, persistence and interrupted digs. |
| `tests/unit/test_world.gd` | WorldState, WorldActions, Simulation | Tests world creation, change storage, seeded randomness, the clock, interaction validation, simultaneous requests, movement plausibility. |
| `tests/unit/test_bunker.gd` | WorldActions, Simulation, SaveCodec | Tests shelter timing, no duplicate hatch, portals, wood given once, cooldown, spend-once reinforcement, unlimited developer levels, saves, migration. |
| `tests/unit/test_save.gd` | SaveCodec, SafeFile, Saves | Tests save round-trip, validation, defaults, removed content, the historical v1 fixture, migrations, safe writes and backup fallback. |
| `tests/unit/test_assets.gd` | AssetCatalog, AssetResolver | Tests override naming, priority, corrupt/oversized rejection, fallback, sound overrides, and display-box fitting. |
