# Iteration 001 — Foundation + First Visual Prototype

| Item | Value |
|---|---|
| Integration branch | `claude/inspiring-babbage-5nip1g` (repository default; the only branch at start) |
| Starting commit | `3c5433809d230c27f828b9a62654f0b8a165ee1a` |
| Iteration branch | `iteration/001-foundation` |
| Engine | Godot 4.7.2 stable (official build, SHA-512 verified), GDScript, Compatibility renderer |
| Target | Windows desktop |

## Phase A — technical foundation

Status categories: **Implemented** (code exists) · **Tested** (automated or runtime test ran and passed
in the Linux test environment) · **Windows acceptance pending** (not yet run by the creator on Windows).

| Area | Status | Evidence |
|---|---|---|
| Project opens, imports, runs without errors | Tested | headless import + runs; rendered runs under Xvfb |
| Single player on the host code path | Tested | `mp_test.py single` (11 checks) |
| Host / join (ENet, address + port) | Tested | `mp_test.py multiplayer` with 3 real processes |
| Independent control, replicated movement, own cameras | Tested | host/client movement checks |
| Shared authoritative interaction (yard gate) | Tested | client request → host validate → all peers agree |
| Range / staleness validation, simultaneous requests | Tested | unit + multi-process (exactly one of two simultaneous toggles applies) |
| Late join, clean disconnect, rejoin running session | Tested | multi-process |
| Host shutdown handling, restart from save, client rejoin | Tested | host process quit + restart, positions & gate restored |
| Connection failure reporting (10 s connect timeout) | Tested | `mp_test.py netfail` |
| Save schema v1, validation, migration hook, safe write, backup fallback | Tested | unit tests (`test_save.gd`) + restart tests |
| Scene independence (view rebuilt from data) | Tested | rebuilt view is a new instance and shows persisted state |
| Sprite override (external), fallback, corrupt/oversize rejection | Tested | unit + runtime (`mp_test.py assets`) |
| Sound override + fallback | Tested | unit + runtime |
| Settings persist across restart, volumes applied | Tested | `mp_test.py settings` |
| Developer overlay, build label, structured logs | Implemented + rendered inspection | screenshots `a1`–`a6` |
| Ultrawide layout (2560×1080) | Rendered inspection | `a6_ultrawide_21x9.png` |
| Exported Windows build, external overrides in export | **Not tested** — no export templates in test environment | pending |
| Everything on Windows | **Windows acceptance pending** | — |

Bugs found by rendered inspection and fixed before the checkpoint: full-screen panels collapsed to
zero size (anchor preset call), and the notice list froze the game when a sixth notice arrived.

Known limitations: client movement collision is not re-simulated on the host (only speed is
validated); one region only; snapshots are not yet filtered by region; no export preset committed.

## Backup checkpoint (mandatory, before Phase B)

| Item | Value |
|---|---|
| Technical baseline commit | `20a736688a65bda47e64ac5ecd1a951febdf841d` |
| Remote backup reference | `refs/heads/backup/pre-visual-prototype` (name was free; created new) |
| Remote SHA (queried with `git ls-remote origin` after the push) | `20a736688a65bda47e64ac5ecd1a951febdf841d` |
| Verification | **Succeeded**: the remote SHA matches the baseline. Phase B began only after this. |

Recover the functioning technical baseline at any time by checking out `backup/pre-visual-prototype`.
Do not move or force-update this branch.

## Phase B — visual prototype (rural homestead)

Content: abandoned farmhouse (separate interactive front door), tool shed, fenced dirt yard with a
shared gate, dirt driveway, cracked overgrown road, abandoned sedan, bunker entrance (hatch set in a
grassy mound with sandbags, a vent and a warm lamp), broadleaf trees and birches, shrubs, grass and
wildflower dressing. Storytelling props: dropped suitcase, overturned wheelbarrow, rusty barrel, a
hand-painted "GONE NORTH" sign. Ambience: generated wind/leaves/distant-birds loop on the Ambience bus.

| Decision | Choice (provisional) | Why |
|---|---|---|
| Perspective | 3/4 top-down (oblique) | Shows building facades and a readable bunker entrance. Free 8-direction movement. The data stays a plain ground plane, so the view can change later. |
| Scale | Survivor 52 × 84 display px. Doors about 2 m. Farmhouse about 10 m wide | Characters stay readable at zoom 1 while buildings feel substantial. |
| Depth | Y-sort by ground-contact point. Tall props fade to 42 % when the player is behind them | Simple and predictable: the player is never hidden. |
| Lighting | Baked soft shadows, warm global tint, paper grain + vignette. No dynamic lights | Natural daylight that matches the moodboard and keeps gameplay readable. Cheap. |
| Motion | Wind sway shader on vegetation, drifting seed fluff | Subtle life. Presentation only. |
| Art production | Every visual is a replaceable template with a manifest entry | One person can redraw it piece by piece: 31 visuals plus 4 sounds. |

The assignment mentions "Dirty Ink Horror" rendering characteristics. That project is not available
here, so they were interpreted as irregular ink outlines, hatched shadows, textured fills and paper grain.
Its Gothic period content was not copied.

| Verification | Result |
|---|---|
| Unit tests + content check after Phase B | 21/21 PASS. Content check 0 FAIL / 0 WARN |
| Real multi-process tests after Phase B | 61/61 PASS (single, multiplayer, net failure, assets, settings). Includes the second door entity and persistence across restart |
| Rendered inspection (Xvfb + llvmpipe) | Screenshots `b1`–`b9` inspected. Fixed fence overshoot, over-dense grass tufts, faceted canopies, door not fading with house, and road hidden by trees |
| Two-player rendered capture | `b9_two_players_host_view.png` / `b9_two_players_client_view.png` |
| Performance | See `docs/PERFORMANCE_REGISTER.md`. Windows measurement pending |
| Windows run, exported build | **Pending creator acceptance**. No export templates in the test environment |

Observations for bunker integration: an entrance inside the farmyard reads clearly as "home base"
and keeps the bunker close to the surface loop. The 3/4 view, however, gives no natural way to show
underground space beneath the surface. A walkable interior would most likely be a separate region
(already supported by `region_id`), or a side-view cutaway. This is the main open question.
