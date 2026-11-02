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
| `src/state/world_state.gd` | Content, RegionState, PlayerState, Simulation | The whole shared world as plain data: id, seed, clock tick, regions, players. Also gives seeded random number streams. |
| `src/state/region_state.gd` | Content | Player-made changes to one region, stored only where they differ from the authored content, with a revision number per object. |
| `src/state/player_state.gd` | Content | One player's saved record: identity, name, region, position, facing. |
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
| `src/presentation/world/placeholder_block.gd` | — | Phase A geometric placeholder: a coloured rectangle with matching collision (editor-visible). |
| `src/presentation/world/placeholder_ground.gd` | — | Phase A placeholder ground with a 100 px grid. |

## Developer and tests

| Script | Depends on | What it does |
|---|---|---|
| `src/dev/content_check.gd` | Content, AssetCatalog, Localization | Content integrity inspection (PASS/WARN/FAIL): regions, region scenes, manifests, asset IDs used in code, translations. Never changes anything. |
| `src/dev/autotest_driver.gd` | Session, Saves, Assets, Audio | Test-only remote control (only with `--autotest`): reads commands from a file and writes state reports, so `tools/mp_test.py` can drive real separate game processes. |
| `tests/test_case.gd` | — | Tiny base class for unit tests (`check`, `eq`). |
| `tests/test_runner.gd` | TestCase, ContentCheck | Runs every test file in tests/unit and the content check, writes results, exits with an error code on failure. |
| `tests/unit/test_world.gd` | WorldState, WorldActions, Simulation | Tests world creation, change storage, seeded randomness, the clock, interaction validation, simultaneous requests, movement plausibility. |
| `tests/unit/test_save.gd` | SaveCodec, SafeFile, Saves | Tests save round-trip, validation, defaults, removed content, the historical v1 fixture, migrations, safe writes and backup fallback. |
| `tests/unit/test_assets.gd` | AssetCatalog, AssetResolver | Tests override naming, priority, corrupt/oversized rejection, fallback, sound overrides, and display-box fitting. |
