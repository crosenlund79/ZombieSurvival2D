# Testing and Launch Guide

## 1. Get the project

1. Install **Godot 4.7.2 (standard, not .NET)** from godotengine.org. Newer 4.7.x patch releases
   should work; do not open the project in an older version.
2. On GitHub choose the branch (latest: `iteration/006-world-worth-surviving`; earlier: `iteration/003-survival-slice`, `iteration/002-bunker`, `iteration/001-foundation`) → **Code → Download ZIP**.
3. Extract the ZIP, start Godot, **Import** → select `project.godot` → **Import & Edit**.
   The first open imports all art (a few seconds). No other tools or steps are needed.
4. Press **F5** (Run Project).

## 2. Single player

Main menu → **Single Player** → **New World** (seed optional) or **Continue**.
Move with **WASD / arrows**, zoom with **mouse wheel / + −**, interact with **E** when a prompt
shows. **Esc** = menu (the world keeps running), **F5** = save, **F3** = developer overlay,
**F12** = screenshot. **Shift** = sprint (noisy), **F / left mouse** = melee swing,
**Q** = drink clean water, **M** = map. Walking behind the farmhouse or a tree fades it so you stay visible.

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

## 3c. The survival slice (iteration 003)

**Danger (surface).**
1. Six zombies wander the edges of the homestead map. Inside the farmhouse and underground you are
   safe: zombies never enter, and nothing hits through walls.
2. Take the **club** from the rack inside the farmhouse (left wall, **E**).
3. Noise attracts zombies to where it was made: chopping (loud), a falling tree (louder), melee, sprinting,
   and doors. (Digging and the generator also make noise, but underground noise does not reach the
   surface yet.) The HUD threat line goes *Quiet → Restless → Hunted*.
   Keep making noise in one area and more zombies converge. Reinforcements arrive from off-screen, capped.
   Attention fades when you stop.
4. A zombie raises its arms (red wind-up) before it strikes. Step away, or swing with **F / left mouse**.
   About 3 club hits kill one.
5. At 0 health you go down and wake up inside the farmhouse after 5 s with 70 health. Carried items stay
   with you.

**Expansion (underground).**
6. In level −1, aim at an earth wall next to the open floor. The outline shows **green** when you can dig
   (**E**, 2 s) and **red** with a reason when you can't.
7. Near the original chamber you may dig one cell beyond its edge. Further out, the prompt says the cell
   needs a support. Stand on a dug cell → **E** "Place timber support" (4 wood from storage, 3 s). A support
   lets you dig within about 3 cells of it. Supports must be at least 2 cells apart.

**Living underground.**
8. Scavenge on the surface (east side of the yard): the **rain barrel** (2 dirty water), the **shed shelf**
   (1 fuel, 1 dirty water), and the **car trunk** south of the driveway (2 fuel, 1 dirty water). Searched
   spots refill after 4 / 20 / 15 minutes of game time.
9. In level −1:
   - **Storage locker** (next to the ladder, **E**) opens a panel to store or take items. Timber you store
     here is the same stock the timber pile and supports use.
   - **Generator** (right side): **Add 1 fuel** (from your hands, otherwise from storage), then **Start**.
     The three ceiling lamps light up and the room brightens. One fuel lasts 3 minutes of game time, and
     the generator stops by itself when empty. With the power off the bunker is dim but never black.
   - **Water purifier** (left side): **Pour in dirty water**. While the power is on it makes one clean
     water every 20 s. **Collect clean water**, or **Drink from the tap**.
10. The water bar falls slowly (about 2.5 per minute). Below 25 you are *thirsty* and health stops
    recovering. Press **Q** to drink carried clean water (+40). At 0 water, health drains slowly, but
    never below 25.

**Two players.** One player can scavenge or fight on the surface while the other runs the generator
or digs below. Both see the same storage, machines and terrain. The bunker keeps running even when
nobody is down there.

**Developer commands** (F3 overlay, host or single player only): peaceful (no zombies), spawn zombie /
group, make noise, hurt / heal, grant timber, grant fuel / dirty water, set thirst, advance the clock,
create a test level.

## 3d. The vertical slice (iterations 006–009)

The human-facing walkthrough of everything new is in [`../PLAYTEST_GUIDE.md`](../PLAYTEST_GUIDE.md):
- building and defences (B, R)
- the inventory (I), crafting at the workbench, food (X)
- the service station east along the road and its discovery
- day/night, rain and horde events at the homestead
- the survivor and the settlement overview (N)
- the survival guide (H)

**Single Player → Developer Test World** starts a prepared world for quick checks. It marks itself
"DEVELOPER TEST WORLD" on screen. **New World** is the normal game.

## 3e. The World Awakens (iteration 011)

What is new and how to reach it quickly is in [`../iterations/011_world_awakens.md`](../iterations/011_world_awakens.md)
and the playtest guide. Developer shortcuts (F3 console commands, host or single player):
`dev goto service_station` / `dev goto town`, `dev vehicle_here`, `dev weather blizzard`, `dev time 23`,
`dev warmth 20`, `dev hunt`. Two players on one computer can share the car: the second player presses
**E** at the car after the first one got in.

## 3f. Shadows & Depth (iteration 012)

Report: [`../iterations/012_shadows_and_depth.md`](../iterations/012_shadows_and_depth.md). Bunker levels open in the
experimental **side view**; **F7** (or F3 → "Bunker view") switches you to the original top-down bunker and back
(saved per player, other players unaffected). Developer helpers: `dev heat` (a temporary heat source where you
stand, `dev heat off` clears), `dev blood` (one mark beside you), `dev create_level` (more bunker levels).

## 3g. The Scavenger's Circuit (iteration 013)

Report: [`../iterations/013_scavengers_circuit.md`](../iterations/013_scavengers_circuit.md). Developer helpers:
`dev xp_multiplier <0..25>`, `dev grant_xp <n>[|all]`, `dev set_skill_level <n>[|all]`, `dev reset_skill 0[|all]`
(host only), `dev goto town.grocery` (or `town.pharmacy`, `town.hardware`, `town.clothing`, `town.garage`,
`town.house_west`, `town.house_east`), `dev vehicle_here [heading]`. Interiors are regenerated with
`python3 tools/build_interiors.py`; container contents and positions are in its layout specs.

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
python3 tools/mp_test.py slice                            # the integrated vertical-slice loop (19 steps, one real game)
python3 tools/mp_test.py build_multi craft_multi world_multi settlement_multi   # 006-009 two-process scenarios
xvfb-run -a -s "-screen 0 1700x1000x24" python3 tools/shots_006.py   # 006-009 screenshots
xvfb-run -a -s "-screen 0 1700x1000x24" python3 tools/shots_red_thaw.py   # 010 Red Thaw screenshots + runtime checks (CHECK lines)
python3 tools/mp_test.py accept                           # the 25-step survival-slice acceptance run
python3 tools/mp_test.py infra_multi dig_multi danger_multi   # iteration 003 two-process scenarios
python3 tools/mp_test.py winter_multi vehicle_multi wild_multi custom_graphics   # iteration 011 two-process scenarios
python3 tools/mp_test.py side_multi blood_multi           # iteration 012: side-view bunker with two instances, thawed blood
python3 tools/mp_test.py circuit_multi progression_multi expedition_multi   # iteration 013: interiors + containers, progression + dev tools, the full expedition loop
xvfb-run -a -s "-screen 0 1600x900x24" python3 tools/shots_scavengers_circuit.py   # iteration 013 screenshots + CHECK lines
xvfb-run -a -s "-screen 0 1700x1000x24" python3 tools/shots_shadows_depth.py   # iteration 012 screenshots + CHECK lines
xvfb-run -a -s "-screen 0 1700x1000x24" python3 tools/shots_world_awakens.py   # iteration 011 screenshots + CHECK lines
xvfb-run -a -s "-screen 0 1700x1000x24" python3 tools/shots_003.py   # iteration 003 screenshots
```
Results are written to `tests/_out/` (ignored by git).
