# Iteration 015 — The World Reborn

| Item | Value |
|---|---|
| Base | `iteration/014-five-settlements` @ `b3c7554` (verified locally and on the remote before any change) |
| Recovery reference | **`backup/pre-world-reborn` → `b3c7554`** (pushed and verified before any change) |
| Branch | `iteration/015-world-reborn` |
| Milestone checkpoints | `backup/iteration-015-milestone-a` (`0c5d414`), `-b` (`c61805f`), `-c` (`b3872c0`), `-d` (`47240a2`), `-e` (`4b8c32b`), `-f` (`7ec5f49`); the final state is the branch head |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Build | Red Thaw 0.7.0 · iteration 015 · network protocol 11 · save schema 4 (unchanged, see §10) |
| Status | Implemented and tested on Linux (unit, real two-process multiplayer, rendered). **Windows acceptance pending.** |

Screenshots: [`../screenshots/iteration_015/`](../screenshots/iteration_015/) (`tools/shots_world_reborn.py`).

## 1. World scale (milestone A)

- **One world coordinate system.** `tools/world_layout.py` places every outdoor region at an offset; the main road
  runs at world y = 1395. Five generated **wilderness regions** (Birchwater, the Corran Forest, the Greyhollow
  Pass, the Stillwater Road, the Halden Coast) now lie between the five settlements — forest roads and tracks,
  clearings, frozen lakes, 15+ isolated cabins (several enterable), landmarks (radio masts, a hunting stand,
  buried cars), power lines.
- **Size.** The world is about 64 000 × 16 000 px. Driving the road end to end takes several minutes (measured:
  station → Ashgrove 21 s, Ashgrove → Junction 41–47 s, Junction → Greyhollow 37 s, Junction → Stillwater 36 s,
  Stillwater → Harbor 36 s, and back 33–37 s per leg).
- **Hybrid regional model with streaming.** Each region is still its own simulation space; wilderness scatter
  (thousands of trees, rocks, cabins) is streamed by `WildTerrain` in 1024 px chunks around the camera; navigation
  for the host comes from data (`obstacles`), never from nodes.
- **Off-road edge traversal** (`WorldGeo`): walk or drive off any outdoor edge and you continue in the neighbour at
  the same world point; arrival is moved to a free spot (never inside an obstacle), direction is kept, a vehicle and
  everyone in it cross together. Boundary walls stop you only where no neighbour exists.
- **Greyhollow's south entrance fixed**; every entrance audited by a test (`_road_graph`, `_edge_neighbours`).
- **Geographic world map** (M): world vs local mode, zoom/pan, Tab/C, forests, roads and tracks, cabins and points
  of interest (hidden until found), player and vehicle markers, shelters, fog of war from exploration memory
  (600 px cells, migrated from discoveries for older saves), non-overlapping labels, night tint.

## 2. Atmosphere (milestone B)

- **Timber architecture.** Rural and residential buildings are log cabins in varied forms (small, porch, large
  two-storey, weathered, ruin, workshop, lean-to, outhouse): every former house in the six outdoor scenes was
  swapped; industrial, civic and harbour buildings keep their own materials.
- **Exterior dressing** in every settlement and cabin clearing (woodpiles, broken fences, porches, bicycles,
  barrels, crates, signs, buried cars, footpaths, belongings, snow) and **interior dressing** (32 side-view props:
  floor and wall furnishings, lamps, cobwebs, curtains, damage) applied by theme to every interior.
- **Stillwater Outfitters** reworked as a two-storey timber shop; container ids kept.
- **Player visibility** (`PlayerSight`): a view polygon cast against buildings/rocks/wrecks — far ahead, less to
  the sides, little behind; shorter at night, in fog and blizzards, pushed out by the flashlight; unseen areas are
  drawn as a dimmed memory; Burnt Ones, animals and hostile people you cannot see are not drawn; adjustable vignette
  (Settings → Display) and a zoom-out limit (0.8). Local to each window (independent per player). Dev: F3 → Sight,
  Vignette.

## 3. UI overhaul (milestone C)

A dirty-ink design system (`UITheme`): 45 ui.* textures (panels, paper, buttons, tooltip, slots, pointer, keycap,
34 icons) with flat fallbacks; heading font; redesigned HUD (region/time, vitals gauges, status chips, hint line,
prompt panel, toasts), inventory grid with detail pane, settings vignette slider. **Object-anchored contextual
panels** (`MachinePanel`, `LockpickPanel`): placed beside the object with a pointer, follow the camera, flip at the
screen edges and move aside so they never cover the player.

## 4. Scavenging and locks (milestone D)

- **Progressive discovery grid.** A search reveals one slot at a time (the container's finds + 1–3 empty slots,
  3–10 in all); each slot takes the kind's search time × 1.4 ÷ slots, scaled by Scavenging level (diminishing
  returns, never under 0.45 s, no loot-quality boost). Revealed finds appear in the grid with icon and quantity
  and can be taken at once; what is not yet revealed is never stored or sent. Stop (E or the button) or get
  interrupted and the revealed slots stay; resume continues where it stopped; XP once, on completion only.
- **Locks.** 15 locked containers (police armoury and evidence, clinic drugs, council cabinet, tool chests,
  lockers, a wardrobe, the hardware store's case…) and 4 locked doors (Greyhollow storage shed, the Port Halden net
  shed, two isolated cabins). Keys: `keys` (a ring of building keys) and `keycard`, found first in a few nearby
  containers; keys are never used up. Lockpicks were added to toolbox, worker-locker, hunter-cabin, attic and parts
  loot (and one guaranteed in the Ashgrove garage tool chest).
- **Lockpicking** (`LockSim`, `LockpickPanel`): pins = level + 1; each pin has a hidden sweet angle (seeded); aim with
  the mouse across the dial or ← / → (Shift = fine), turn with click or Space. Every turn is a host request: inside
  the window the pin sets (click, green pin light); a miss rattles, shows how close you were (text + colour + a mark
  where you tried) and wears the pick in proportion to how far off; a worn-out pick snaps and the pins drop. Opening
  unlocks the real object and persists. No lockpicking XP skill.

## 5. Threats (milestone E)

- **Roaming hordes** (`HordeSim`): form out of sight (≥ 980 px from every player, gathering ~1250 px from their
  goal) in outdoor regions where players are; chance per 90 s check by day/night and loudness; 4–6 + 1 per day
  (+3 when loud), capped at 12; at most two at once, one per region, 10 min cooldown, break up after 7 min or when
  mostly dead; global ceiling. They drift to the loudest noise or the players and regroup every 12 s. Transient.
- **AI level of detail**: full rate within 1400 px of a player (always when fighting), every 3rd tick to 3000 px,
  every 8th beyond — with a matching longer step so they still cover the same ground.
- **Hideouts**: Stillwater quiet house, Port Halden cottage, Greyhollow row house. Dev: Reset hideouts, Go to
  hideout 1/2/3.
- **Wolves** hunt in packs (stalk, circle, dart in to bite, back off), escapable (give up after 25 s, far from
  their ground, at distance, in a vehicle). **Bears** warn when you enter their territory, charge if you stay or come
  close, then return home. Both can be fought off and killed; "peaceful" makes them harmless. Packs and bears were
  added to the wilderness.
- **Test assault rifle**: `--test-rifle`, Settings `dev/test_rifle_start`, or F3 → "Test rifle in starter bag" —
  the starter bag then also holds a loaded military rifle and 60 rounds. Off by default.

## 6. Factions (milestone F)

| Faction | Kind | Place | What it does |
|---|---|---|---|
| **The Cinder Crew** | permanently hostile | armed encampment (tents, fire, barricades) in the Greyhollow Pass | 5 raiders patrol and shoot on sight (accuracy falls with range; gunshots draw Burnt Ones); killable; dead raiders stay dead for 2 game days; a locked cache |
| **Hearth Gate** | friendly community | corrugated-fence compound on the Stillwater Road: guarded gate, two watchtowers, four cabins, stall, workbench, fire | trader (credit; shared, persistent stock that restocks daily; prices by standing), mechanic (paid repairs), elder (missions: deliver 5 tins, kill 3 raiders, scout the pass — host-checked, rewarded), community law |
| **The Lantern Circle** | reputation faction | radio shack under the Halden coast mast | keeper's missions; tiers: *known* marks wilderness regions on your map, *trusted* gives a radio and batteries |

- **Community law**: assault on a member, theft from the community store and gunfire inside the fence are crimes —
  only when a member sees it (520 px + line of sight). 1st: warning; 2nd: fine (20 credit); 3rd: banished for a
  game day (gate barred, guards shoot). One strike is forgiven per quiet day.
- **Reputation is per player** (each player has their own standing, credit, mission progress and law record);
  the trader's stock is shared. Stored in `world.meta["factions"]`, saved and replicated.
- **UI**: talk to a person (E) → anchored panel (trade / sell / repairs / missions); Factions screen (J).
  Dev (F3): go to camp / Hearth Gate / radio shack, +20 standing, +50 credit, clear my law strikes.

## 7. Multiplayer

All new systems are host-authoritative: search reveals, lock turns (the requester alone gets the closeness
feedback), hordes, wildlife, faction people, trade, repairs, missions and law. Clients see mirrored rows (zombies,
animals, people) and world meta. Verified with two real instances (§12).

## 8. Asset templates (all replaceable)

New manifests: `visual_wilderness.json` (26), `visual_interior_dressing.json` (32), `visual_ui_015.json` (45),
`visual_factions.json` (32). Every picture is a template under `assets/templates/…/template_<name>.png` and is
overridden by `assets/overrides/…/<name>.png`; generators: `tools/art/gen_wilderness.py`,
`gen_interior_dressing.py`, `gen_ui.py`, `gen_factions.py`. No creator-owned art or audio was touched.

## 9. Content pipeline

`python3 tools/build_world.py --all` regenerates settlements, wilderness (with faction sites and
`content/factions.json`), hand-made scene patches, dressing and locks, and checks the layout. Idempotent.

## 10. Saves and migration

Save schema stays 4. Additions are optional fields with safe defaults: entity states (`revealed`, `total`,
`locked`), world meta (`explored`, `factions`, `test_rifle`). Older saves load: exploration is seeded from their
discoveries; containers already searched before they had a lock count as open; locked doors simply start locked
(no stored items are affected). Bases, vehicles, loot and progress are never deleted. Hordes, wildlife and faction
people are transient (rebuilt on start; dead raiders are remembered). Rollback: check out
`backup/pre-world-reborn`; a 015 save opened there ignores the new fields.

## 11. Known limitations

- Keys are generic (`keys` opens every "keys" lock); per-door keys need catalogue items.
- Paid repairs cover gear, not vehicles.
- Faction people walk straight paths (no path-finding); they stand at posts in regions nobody is in.
- Hostile people are hidden by PlayerSight like Burnt Ones; raiders behind tents cannot see you either.
- Wildlife and faction people respawn on world start (killed raiders are remembered; animals are not).
- Credit is per faction-less pool used at Hearth Gate only.
- Windows acceptance pending for 001–015.

## 12. Tests

See §13 for the full regression. New: `tests/unit/test_world_reborn.gd` (A–F), mp_test scenarios `locks_multi`,
`threats_multi`, `factions_multi`; rendered checks in `tools/shots_world_reborn.py`.

## 13. Full regression (milestone G)

| Suite | Result |
|---|---|
| Unit tests + content check (`tests/run_tests.tscn`) | **204 / 204**, content check PASS |
| Full multiplayer regression (all 34 `mp_test.py` scenarios, real separate processes) | 525 / 530 on the first full pass. Fixed after: 4 slice failures (the homestead wolf pack now only hunts at night) and 1 `danger_single` failure (reinforcement caps were world-wide, so the new wilderness populations had used them up; now per region). Re-runs: `slice` + `danger_single` 46 / 46 after the wolf fix except the cap issue, then `danger_single`, `danger_multi`, `perf_multi`, `threats_multi` all passing (threats needed a test-sampling margin: 9 / 9) |
| Milestone scenarios | `locks_multi` 11 / 11, `threats_multi` 9 / 9, `factions_multi` 11 / 11, `circuit_multi` 21 / 21, `progression_multi` 20 / 20 |
| Performance (`perf_multi`) | 57 Burnt Ones with two players: host simulation **1.34 ms / frame** (budget 8 ms); the client mirrors all 57. AI level of detail counted per tick in F3 |
| Rendered checks (`tools/shots_world_reborn.py`) | all CHECK lines PASS; 20 screenshots in `docs/screenshots/iteration_015/` |
| Script guides | EN / DA 136 / 136 |

Windows acceptance pending: none of this has been run on Windows.
