# Iteration 011 — The World Awakens

| Item | Value |
|---|---|
| Base | `iteration/010-red-thaw` (with the creator's audio inbox, `eb4dede`) |
| Branch | `iteration/011-world-awakens` |
| Recovery references | `backup/iteration-011-milestone-a`, `-b`, `-c` (`370b599`), `-d` (`a073bd4`) — each verified on the remote |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Save schema | 4 (unchanged; new fields are optional, old worlds load) · network protocol 7 · Red Thaw 0.3.0 |
| Status | Implemented and tested on Linux (unit, real multi-process, rendered). **Windows acceptance pending.** |

An expansion, not a rewrite: every system from iterations 001–010 is kept. All new shared systems are
host-authoritative; clients request and the host validates, commits and replicates.

## A. Living horror — the Burnt Ones

- **Postures.** A Burnt One walks upright, crouches or drops to all fours and crawls, with short
  crawling bursts and natural transitions. Each has its own temperament (pace and crawl tendency,
  derived from its id), so they do not move identically. Lunges always stand them up.
- **Hearing.** A loud enough noise makes it stop, turn toward the sound and listen (the "?" cue). A
  significant disturbance makes it **screech**, then investigate the place, never the player.
- **Screech as a world noise.** A screech is heard spatially by players and draws at most three of the
  nearest Burnt Ones (`screech_max_responders`). Responders investigate and never screech in turn (no
  chains). There is a 50 s cooldown per creature and 14 s per region. Attention decays as before. No
  creature ever appears in view.
- **Losing the target.** It searches ahead along the last direction, then a few random spots around,
  then gives up.
- **Signs, kept restrained.** Fading boot, hand and blood marks behind them, and snow puffs on a burst.
  There is no blood-tracking simulation.
- Kept: the developer hunt trigger, no lore trigger, and the cabin/bunker boundaries.

## B. Winter survival

- **Cold exposure.** Warmth is 100 (warm) to 0. Outside, it falls with the region's exposure, the night
  and the weather; clothing insulates (padded jacket 35 %, **winter coat** 60 %). Shelters, bunkers,
  power, heaters and a running car heater warm you. Messages warn at *chilled* and *freezing*, the
  screen frosts, and freezing costs health slowly down to a floor (never kills by itself) and stops
  regeneration. Host-simulated, replicated with the vitals, saved.
- **Dynamic weather.** Clear spells alternate with fog, snow, heavy rain, blizzards and thunderstorms
  (weighted, seeded, shared, saved, with regional fog and exposure). Lightning flashes are
  deterministic per world, followed by delayed near or far thunder; lightning never hurts anyone. Fog
  and storms cut Burnt One sight and hearing. Developer: `dev weather <kind>`.
- **Communal sleeping.** Use a bed (cabin bed, bunker bedroll, the town house bed and the cellar
  bedroll) in the evening or at night. Alone: you sleep at once. With others: everyone online must be
  inside the same shelter group; otherwise you get an inner monologue built only from what really
  happened (a recent screech nearby, a storm, the dark). Then a replicated **"Ready to sleep?"** vote
  starts: one "not yet", a timeout, anyone leaving or disconnecting cancels it, and there are no
  duplicate votes. A unanimous yes advances the real simulation to 07:00 in 50 s chunks (fuel, crops,
  crafting, construction, survivors and needs progress exactly once), and everyone wakes rested and warm.

## C. Vehicles and a larger world

- **The station wagon.** Parked at the abandoned settlement, its key in the ignition. Press **E** to
  get in (the first person in takes the wheel; up to four seats). **G** starts or stops the engine,
  **W/S** accelerate, brake and reverse, **A/D** steer, and **E** gets out (only when the car has
  stopped; you stand beside it, never inside a wall). The car is solid, bumps off obstacles (with a
  metal thud from the audio inbox) and has a driving camera that looks ahead and pulls back. It has
  headlights and a tail light at night, exhaust in the cold, an engine loop whose pitch follows the
  speed, and start, stop and door sounds.
- **Trunk:** press R beside the car. Twelve slots, the same store/take panel as a locker.
- **Network.** The driver's client predicts the car and sends poses at 20 Hz. The host validates speed,
  bounds and engine state (and snaps the car back if needed), keeps the passengers on the car and
  broadcasts it. Seats, engine and trunk are reliable full-state updates.
- **Burnt Ones and cars.** Nobody inside a closed vehicle is seen, but starting and running the engine
  is loud.
- **Persistence.** The car's region, position, heading, engine state, seats and trunk are saved.
  Players who are not online are taken out of their seat when the world starts; a disconnecting
  player is taken out at once. Locks and keys are reserved fields for later.
- **Road exits.** Driving the front bumper into a region's road exit moves the car, everyone inside it
  and its trunk to the defined entry point of the next region, together. Players outside the car are
  never moved. There are no duplicates and no lost passengers (tested). Walking links exist both ways
  too. Homestead ⇄ settlement ⇄ **Ashgrove**. The road east of Ashgrove is blocked for now (a
  jackknifed trailer), ready for the next settlements.
- **Ashgrove, a new town.** A main street with a **grocery** (canned food, crackers), **pharmacy**
  (bandages, water), **hardware store** (metal, electrical parts, cement; a locked case with a
  flashlight and a hatchet), **clothing store** (cloth; a winter coat in the stockroom) and a
  **garage** (metal, fuel). Several spots are already picked clean (storeroom, dispensary, service bay,
  a collapsed house). There are houses, street lamps, a parked car, the town sign and Red Thaw art.
- **A second base.** The house on Main Street has a **cellar that exists from the start**: its own
  bunker (`town.house.cellar`, concrete level template `town_cellar`) with storage, a bedroll, lamps,
  a timber pile upstairs and build zones. It uses the same construction, storage, sleeping and
  persistence as the cabin bunker, and the hatch can be upgraded to steel.
- **Regional map.** All discovered regions on one field map: the region you are in outlined in red,
  roads leading to undiscovered places marked "Unexplored road", shelters, the car and players. At
  night the paper darkens while labels and markers stay readable. There is no fast travel.

## D. Wildlife, highlighting, the club, the flashlight

- **Wolves and bears.** They roam their home area, idle, notice a player and stop to watch, back away
  or bolt when you come close, and call out (howls, grunts; more often at night). They never attack.
  The host simulates a handful of animals; clients mirror compact rows. They are rebuilt from
  `content/tuning/wildlife.json` when a world starts and are not saved. Wolves live on the open snow
  east of the cabin, a bear south of the settlement, and wolves and a bear around Ashgrove.
- **Interactable highlighting.** The one thing **E** would use gets a soft warm rim, through the
  existing focus system, so only valid targets are highlighted. It can be turned off under
  Settings → Display.
- **Club alignment.** Held weapons keep their grip in the hand and point the right way in all four
  facings (in front of the body, or behind it when facing away), checked in rendered screenshots.
  Combat is unchanged.
- **Flashlight.** **L** (rebindable), or Use in the inventory. The host checks that you carry one; the
  state is replicated, so others see your beam. The beam follows your facing. No batteries. It
  switches off if you drop it or store it. Each player can take one flashlight from the cabin table,
  and there is one in the Ashgrove hardware case. The beam shape (`fx.flashlight_cone`) and the
  in-hand picture (`item.flashlight`) are replaceable.

## E. Audio inbox and custom graphics

- **Audio inbox.** The originals in `assets/audio inbox/` are untouched. The selected clips are copied
  (processed where useful) into templates, so they follow the normal replacement rules. Full table:
  [`../guides/ASSET_REPLACEMENT.md`](../guides/ASSET_REPLACEMENT.md) §8. In use: heavy-rain and storm
  beds, near and far thunder, the cabin stove, the Burnt One body drop, the swing, the metal hit (car),
  two mocking laughs among the settlement laughter, the survivor's whispered "Can I trust you?", the
  menu click and error sounds, and the main-menu theme.
- **Use custom graphics: ON / OFF** (Settings → Assets). OFF ignores replacement images without
  touching any file. The switch applies immediately, is saved per player, falls back per picture and
  never affects gameplay or sounds. In multiplayer each player chooses for themselves.

## Controls added

| Key | Action |
|---|---|
| G | engine on / off (driver) |
| E (in a car) | get out |
| R (beside the car) | trunk |
| L | flashlight on / off |

## Developer commands added (F3 / host)

`dev weather <clear|snow|fog|heavy_rain|blizzard|thunderstorm>`, `dev warmth <0-100>`,
`dev goto <region>` (walk into a region at its spawn, records the discovery), `dev vehicle_here` (park
the wagon beside you, if nobody is in it). Existing: `dev hunt`, `dev time`, `dev noise`, `dev grant`.

## Tests

- **Unit** (`tests/unit/test_world_awakens.gd`, `test_assets.gd`): 122 tests. They cover hearing,
  screeches and limits, postures, target loss; weather, cold, exposure, lightning, sleep and votes;
  vehicles (placement, seats, engine, pose validation, road exit with occupants and trunk,
  persistence and seat consistency, hiding inside and engine noise); the town cellar as a pre-built
  base; typed and picked-clean loot; map exits; wildlife; the flashlight; the custom-graphics switch.
- **Real multi-process** (`tools/mp_test.py`): new scenarios `winter_multi`, `vehicle_multi` (24
  checks: shared car, passenger replica, road exit to Ashgrove together, trunk, getting out, restart),
  `wild_multi` (11), `custom_graphics` (10: host OFF / client ON, persistence, menu music), plus the
  full regression of the earlier scenarios.
- **Rendered** (`tools/shots_world_awakens.py`): screenshots in
  [`../screenshots/iteration_011/`](../screenshots/iteration_011/). They show a crawling Burnt One,
  four weathers, the flashlight at night, the car parked, driving, arriving and with headlights,
  Ashgrove, the house and the cellar, wolves and a bear, the night map, and custom versus original
  graphics.

## Known limitations and open decisions

- Windows acceptance is pending for everything in this iteration. Exported builds were not tested.
- All new art and the vehicle and animal sounds are generated placeholders, waiting for tablet art and
  recorded sounds. The inbox clip selection was made without listening (see the asset guide).
- Wildlife is transient and purely atmospheric (no hunting, no danger). Bears and wolves pass through
  player-built walls they did not see when choosing a goal (they use the static navigation grid).
- One vehicle. No fuel, damage, keys or locks yet (fields reserved). Burnt Ones do not attack cars.
- Ashgrove's stores are searched from the street; there are no store interiors.
- The car can be left anywhere; if a region is removed from content, the car returns to its placement.
- Balance values (cold rates, weather weights, car handling, animal radii) are EXPLORING prototype
  values (see `../DESIGN_DECISIONS.md`).
