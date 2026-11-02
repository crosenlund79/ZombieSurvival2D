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
