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
| `src/state/zombie_state.gd` | — | One zombie as plain data: identity, region, position, health, AI state and short-term memory. Only the base population's identity/position/health is saved. |
| `src/state/threat_state.gd` | — | World noise queue and attention per coarse zone (transient: never saved, so a reloaded world starts calm). |
| `src/state/world_state.gd` | Content, RegionState, PlayerState, Simulation | The whole shared world as plain data: id, seed, clock tick, regions, players. Also gives seeded random number streams. |
| `src/state/region_state.gd` | Content | Player-made changes to one region, stored only where they differ from the authored content, with a revision number per object. |
| `src/state/bunker_state.gd` | — | One shelter as plain data: its entrance identity, levels by signed depth (no maximum) and the shared stockpile. Builds and parses level region ids. |
| `src/state/player_state.gd` | Content | One player's saved record: identity, name, region, position, facing. |
| `src/sim/nav_grid.gd` | Content, Prop, FenceLine | Host-side walkability grid built from the region scene's authored collision data, plus live trees/gates; A* paths and line-of-sight checks for zombies and attacks. |
| `src/sim/zombie_sim.gd` | NavGrid, ThreatState, WorldState | Host-only zombie simulation: hearing, attention escalation/decay, reinforcements from map entries within caps, the AI state machine, movement, attacks, corpses and population top-up. |
| `src/sim/survival_sim.gd` | WorldActions | Host-only player vitals: slow health recovery and the forgiving respawn rule (keep everything, wake in the farmhouse). |
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
| `src/presentation/world/weapon_rack_view.gd` | EntityView | The club rack in the farmhouse; taking a club equips the player (one each, never runs out). |
| `src/presentation/world/placeholder_block.gd` | — | Greybox helper (used in Phase A, kept for blocking out new areas): a coloured rectangle with matching collision. |
| `src/presentation/world/placeholder_ground.gd` | — | Greybox ground with a 100 px grid (unused in the current scene). |

## Developer and tests

| Script | Depends on | What it does |
|---|---|---|
| `src/dev/content_check.gd` | Content, AssetCatalog, Localization | Content integrity inspection (PASS/WARN/FAIL): regions, region scenes, manifests, asset IDs used in code, translations. Never changes anything. |
| `src/dev/autotest_driver.gd` | Session, Saves, Assets, Audio | Test-only remote control (only with `--autotest`): reads commands from a file and writes state reports, so `tools/mp_test.py` can drive real separate game processes. |
| `tests/test_case.gd` | — | Tiny base class for unit tests (`check`, `eq`). |
| `tests/test_runner.gd` | TestCase, ContentCheck | Runs every test file in tests/unit and the content check, writes results, exits with an error code on failure. |
| `tests/unit/test_threat.gd` | ZombieSim, WorldActions, NavGrid | Tests navigation, sight, hearing, attention growth/decay, escalation caps, melee authority, walls, wind-up damage, respawn, the farmhouse boundary and the persistence policy. |
| `tests/unit/test_world.gd` | WorldState, WorldActions, Simulation | Tests world creation, change storage, seeded randomness, the clock, interaction validation, simultaneous requests, movement plausibility. |
| `tests/unit/test_bunker.gd` | WorldActions, Simulation, SaveCodec | Tests shelter timing, no duplicate hatch, portals, wood given once, cooldown, spend-once reinforcement, unlimited developer levels, saves, migration. |
| `tests/unit/test_save.gd` | SaveCodec, SafeFile, Saves | Tests save round-trip, validation, defaults, removed content, the historical v1 fixture, migrations, safe writes and backup fallback. |
| `tests/unit/test_assets.gd` | AssetCatalog, AssetResolver | Tests override naming, priority, corrupt/oversized rejection, fallback, sound overrides, and display-box fitting. |
