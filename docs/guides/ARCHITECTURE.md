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

## 13. Testing and diagnostics

- **Unit + content check**: `godot --headless --path . res://tests/run_tests.tscn`.
- **Real multi-process tests**: `python3 tools/mp_test.py` starts separate game processes
  (`--instance=…` `--autotest`) that connect over ENet and drives them via `AutotestDriver`.
- **Rendered screenshots**: `tools/shots_*.py` under a real display (or `xvfb-run`).
- **Black box**: `SessionLog` JSON-lines in `user://…/logs/`, 5 files kept, 1 MB cap each,
  repeated events throttled. Dev overlay shows the live state and the log path.
- **Build identity**: `BuildInfo.label()` (bottom-right). Commit is read from `.git` if present;
  a GitHub ZIP download shows `commit n/a` (git is never executed).

## 14. Dependency direction

```
presentation (main, ui, world views) ──reads/requests──▶ Session ──▶ WorldActions / Simulation ──▶ state
        │                                                  │
        └──▶ Assets / Audio / Settings                    └──▶ Saves (SaveCodec) , Net
state, sim, content, persistence never reference presentation.
```
