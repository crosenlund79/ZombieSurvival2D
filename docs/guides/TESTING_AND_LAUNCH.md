# Testing and Launch Guide

## 1. Get the project

1. Install **Godot 4.7.2 (standard, not .NET)** from godotengine.org. Newer 4.7.x patch releases
   should work; do not open the project in an older version.
2. On GitHub choose the branch (latest: `iteration/002-bunker`; iteration 001: `iteration/001-foundation`) → **Code → Download ZIP**.
3. Extract the ZIP, start Godot, **Import** → select `project.godot` → **Import & Edit**.
   The first open imports all art (a few seconds). No other tools or steps are needed.
4. Press **F5** (Run Project).

## 2. Single player

Main menu → **Single Player** → **New World** (seed optional) or **Continue**.
Move with **WASD / arrows**, zoom with **mouse wheel / + −**, interact with **E** when a prompt
shows. **Esc** = menu (the world keeps running), **F5** = save, **F3** = developer overlay,
**F12** = screenshot. Walking behind the farmhouse or a tree fades it so you stay visible.

## 3. Two players on one computer

Easiest from the editor: **Debug → Customize Run Instances…** → enable *Enable Multiple Instances*,
set *2* instances, and give them the arguments `-- --instance=a` and `-- --instance=b`
(separate settings, logs and saves per window). Press F5: two windows open.

- Window 1: **Host Game** → name e.g. *Anna* → **New World**.
- Window 2: **Join Game** → name *Bo*, address `127.0.0.1`, port `24680` → **Connect**.

Without `--instance` both windows share settings; then just type **different player names**
(the same name on the same computer is refused as a duplicate identity).

**Two computers (LAN):** the host shares its local IP address (e.g. `192.168.1.20`); the joining
player types it. Windows Firewall may ask to allow Godot — allow it on private networks.
Internet play needs port forwarding of UDP 24680 on the host's router (no relay/matchmaking exists).

Things to try: walk both players, open/close the yard gate (south fence, at the end of the dirt
driveway) from either window (both see it), walk through it and open the farmhouse front door,
press E on the gate from both at the same moment (one wins, the other is told), leave and rejoin
(your position is remembered), host saves (F5) → host leaves → host **Continue** → client rejoins.

## 3b. The bunker loop (iteration 002)

1. Open the yard gate, walk up to the farmhouse door, open it, step right up to the doorway and press
   **E** ("Enter the farmhouse").
2. Inside, stand on the chalk-marked floorboards → **E** "Dig a shelter beneath the house". Digging
   takes 8 s of game time (progress bar); the house stays walkable.
3. **E** next to the finished hatch opens/closes it. Stand **on** the open hatch → **E** "Climb down".
4. Level −1: exposed earth with four chalk-marked spots. The ladder at the back wall climbs up.
5. Outside, stand next to a tree and press **E** repeatedly (5 chops) — it falls and you carry its wood
   (up to 30). Felled trees stay stumps.
6. Stack the wood on the timber pile inside the farmhouse (or the one underground).
7. Underground, at a chalk-marked spot → **E** "Reinforce with timber" (4 wood, 3 s).
8. **M** opens the map (your position, the farmhouse, the shelter, trees; your depth when underground).

Tip: while standing *on* a hatch or right at a doorway you get the "go through" action; step a little
aside to get "open/close" instead.

**Developer: create an underground test level.** As host (or in single player) press **F3** →
**Create underground test level**. Each press adds one concrete level below the deepest level of your
shelter (−2, −3, −4 …) and opens a ladder down to it. Clients cannot use it.

## 4. Saves

Only the host (or single player) saves. Locations (Windows):
`%APPDATA%\Aftergrowth\saves\<world_id>\world.json` (and `world.json.bak`, the previous save).
With `--instance=a`: `%APPDATA%\Aftergrowth\instances\a\saves\…`.
Autosave every 5 minutes, on leaving, and when the host closes the window.

## 5. Replace art and sound

See `docs/guides/ASSET_REPLACEMENT.md`. Quick test: copy
`tests/fixtures/overrides/characters/player/survivor_down.png` to
`%APPDATA%\Aftergrowth\overrides\characters\player\survivor_down.png`, then Settings → **Reload art & sound**.
The player turns red-jacketed. Delete it and reload to get the template back.

## 6. Logs and diagnostics

- **F3** shows build, mode, peer, authority, world id, seed, clock, players, entity states, last save,
  active overrides and the current log file path.
- Logs: `%APPDATA%\Aftergrowth\logs\session_*.jsonl` (one JSON line per event; last 5 sessions kept).
  Look for `"lvl":"ERROR"` or `"WARN"` lines when something misbehaves.
- The Godot editor's *Output* panel shows the same lines while running.

## 7. Automated tests (developer machine with Godot on PATH)

```
godot --headless --path . --import                       # refresh class cache after adding scripts
godot --headless --path . res://tests/run_tests.tscn      # unit tests + content check
python3 tools/mp_test.py                                  # real multi-process host/client tests
python3 tools/check_script_guides.py                      # docs freshness: every script documented
xvfb-run -a python3 tools/shots_phase_b.py                # rendered screenshots of the homestead (Linux)
```
Results are written to `tests/_out/` (ignored by git).
