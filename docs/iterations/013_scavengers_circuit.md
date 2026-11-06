# Iteration 013 — The Scavenger's Circuit

| Item | Value |
|---|---|
| Base | `iteration/012-shadows-and-depth` @ `b6914c1` (verified locally and on the remote before any change) |
| Recovery reference | **`backup/pre-iteration-013` → `b6914c1`** (pushed and verified on GitHub before any change) |
| Branch | `iteration/013-scavengers-circuit` |
| Milestone checkpoints | `backup/iteration-013-milestone-a` (`67e14be`), `-b` (`b065d9f`), `-c` (`5bfbb5c`), `-d` (`3ef5894`), `-e` (`808e62f`, final) |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Build | Red Thaw 0.5.0 · iteration 013 · network protocol 9 · save schema 4 (unchanged, see §7) |
| Status | Implemented and tested on Linux (unit, real two-process multiplayer, rendered). **Windows acceptance pending.** |

> Prepare → Drive → Explore → Scavenge → Transport → Improve Shelter → Repeat.

## 1. Explorable Ashgrove

- **Five shops and two houses can be entered**, in the same top-down 3/4 view as the cabin. Bunkers and
  cellars keep the experimental side view.

  | Building | Inside |
  |---|---|
  | Grocery | freezers, four aisles (full, sparse, bare), checkout; a storeroom with stock shelves and crates |
  | Pharmacy | aisles, pharmacist's counter, a ransacked wall cabinet; a dispensary with medicine cabinets |
  | Hardware | metal shelving, lumber and tool aisles, a pegboard, display table; a stockroom with a locked tool chest |
  | Clothing | coat racks (full and bare), a display table, a fitting-room dresser; a stockroom with crates |
  | Garage & Service | an empty car lift, tool chest, parts shelf, lockers, a scrap crate; an office behind a partition |
  | West House | kitchen (counter, fridge, a table still laid for a meal), bedroom with dresser and closet, a barricaded window |
  | East House | living room (sofa, picked-over bookshelf), bedroom, wardrobe, a packed crate, barricaded windows |

  The **House on Main Street** keeps its own interior and its cellar hatch; its pantry and linen became
  containers.
- **Entrances.** Each shop door on Main Street has an entrance; the old street-front search spots are gone.
  House doors open and close like the town house door. You come out at the building's own door.
- **Lighting and mood.**
  - Daylight comes through the front windows and follows the shared clock (dim at night, duller in heavy
    weather).
  - Backrooms have no windows, so the flashlight matters there.
  - There is no precipitation indoors. Ambience is the muffled wind loop.
  - Unheated buildings keep out about two thirds of the cold (`climate.shelter` 0.35): sheltered, but still cold.
- **Rules unchanged.** Interiors have no Burnt One population, so Burnt Ones never wander in. Sound still
  leaks to the street (§4).
- **Generated, not hand-placed.** `tools/build_interiors.py` writes the seven region files and scenes from
  layout specs and patches the street. Its art comes from `tools/art/gen_scavengers_circuit.py`: 44 new
  replaceable templates, listed in `ASSET_REPLACEMENT.md` §9.

## 2. Containers and scavenging

- **47 physical containers**, all entity type `container` and host-authoritative:
  - kinds: shelves, racks, drawers, cupboards, fridges/freezers, medicine cabinets, crates, lockers, tool chests
    and garage storage
  - **13 of them were emptied before you arrived**
- **Searching.**
  - Walk up and press **E**. A progress bar fills over the container, and every player sees it.
  - Press **E** again to stop. Walking away, changing region, getting into a car, dying or disconnecting also
    interrupts it. Nothing is gained from a stopped search.
  - One searcher per container. Two players can search different containers at the same time.
  - When the search finishes, the container reveals what is really inside and becomes a small shared box:
    take one item, or **Take everything**. Taking uses the same transfer rule as storage, so nothing duplicates.
- **Loot by location** (authored per container, reusing existing items):

  | Location | Finds |
  |---|---|
  | Grocery | canned food, crackers, bottled water |
  | Pharmacy | bandages, clean water |
  | Hardware | wood, scrap metal (fasteners), electrical parts, cement, a stovepipe, the flashlight + hatchet case |
  | Clothing | fabric (cloth), the winter coat |
  | Garage | scrap metal, electrical parts, fuel, a stovepipe |
  | Houses | a little food, water, fabric |

- **No regeneration.** Contents are written into the container state once, when it is first searched. They
  do not come back on re-entry, region change, reload or restart.
- **Noise.** A finished search makes noise through the existing noise system: quiet for shelves, racks and
  drawers, louder for crates, lockers, tool chests and garage storage. Indoors it leaks to the street at the
  building's door. There are no forced encounters.

## 3. Skills and progression

- **Framework.** `SkillSim` with data in `content/tuning/skills.json`. Skills are per player, saved, and
  replicated with the player's inventory. Levels are derived from XP. Only **Scavenging** is active.
- **Effect: search speed only.** No rarity, quantity or perks.

  | Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | XP to reach | 0 | 30 | 75 | 135 | 210 | 300 | 405 | 525 | 660 | 810 |
  | Ordinary search (shelf, 5 s base) | 5.0 s | 4.1 s | 3.45 s | 3.0 s | 2.65 s | 2.4 s | 2.2 s | 2.05 s | 1.9 s | 1.8 s |

  - Base times per kind: drawer and fridge 4 s, rack 4.5 s, shelf, cupboard and medicine cabinet 5 s,
    locker 5.5 s, crate and garage 6 s, tool chest 6.5 s.
  - Never below 1.2 s.
- **XP.**
  - A first search earns 12 XP, plus 2 per item found (counting at most 5).
  - A container that was unsearched but turns out empty earns 6 XP, once.
  - Re-opening a searched container, taking items, a cancelled search and pre-emptied containers earn nothing.
  - Whether a container has been searched is world state, so save/reload, reconnecting and changing region
    cannot reset eligibility.
  - In multiplayer only the player who completed the search gets the XP.
- **Skills screen (K).** Shows the level, XP, XP to the next level, a progress bar, the current search time
  and the next level's search time.
- **Feedback.** A quiet "+N Scavenging XP" drifts up for the searcher only. A level-up adds one notice.
- **Ashgrove totals.** One player searching every container earns 546 XP, which is level 8. Two players
  split it. More locations later will add more.

## 4. Developer menu and XP multiplier

- **F3 categories.** **World**, **Player** and **Progression**. Every earlier command is still there.
- **Progression tab.**
  - Skill XP multiplier: a slider from 0 to 25× in steps of 0.5, quick buttons 1×, 5×, 10× and 25×, and
    **Reset 1×**.
  - The active value is shown in the menu, and in the Skills screen whenever it is not 1×.
  - The multiplier applies to XP earned from that moment on, for every present and future skill. It is never
    retroactive.
  - +25 / +100 / +500 XP, set level 1 / 5 / 10, and **Reset Scavenging**. These apply to you, or to every
    player with the checkbox ticked.
- **Authority.**
  - Progression commands are **host only**, even when the host lets clients use other developer commands
    (`dev/allow_client_dev_commands`). A client sees the tab disabled.
  - The multiplier is runtime-only: it is never written to a save, and is back at 1× after loading.
  - All developer tools are **unavailable in release builds**. `BuildInfo.dev_tools_enabled()` is true for
    the editor and debug exports, or with `--dev-tools`.
  - Player settings are separate and untouched.
- **Console equivalents.** `dev xp_multiplier 5`, `dev grant_xp 100|all`, `dev set_skill_level 5`,
  `dev reset_skill 0|all`.

## 5. Transport and shelter

- **Trunk.** Press **R** at the car.
  - **Load everything**: equipped gear stays in your hands. **Unload everything**, or single items.
  - Capacity is shown as n / 12, and buttons are disabled when the trunk is full or your hands are.
  - Correct stacking, no duplication or loss; it persists and travels across regions as before. The key stays
    in the ignition; there is no fuel and no breakdowns.
- **Shelter storage** gained **Store everything you carry**.
- **Wood stove** (new buildable, underground only).
  - Cost: scrap metal 3, **stovepipe** 1 (new item: hardware stockroom crate and garage parts shelf), cement 1.
    Everything comes from Ashgrove.
  - Once finished it glows and adds **+12 warmth per minute** on its level (an unpowered shelter goes from 7
    to 19). It burns nothing.
  - Drawn in both the side view (its pipe rises through the ceiling) and the top-down view.
  - Synchronised and saved like every built object.
  - The Ashgrove cellar is a valid place for one too.

## 6. Atmosphere

- **Indoors.** Dark backrooms, a flashlight-dependent night, cold that is reduced but present, muffled wind,
  no snowfall.
- **Searching is not silent.** Crates and lockers are heard outside.
- **Burnt One rules from iteration 012 are untouched:** silhouettes, postures, screeches, blood traces, the
  weather effects, protected cabin and bunker boundaries. The hunt trigger is still undecided. There are no
  jump scares or forced encounters.

## 7. Saves and compatibility

- Save schema 4, no migration. New data is optional:
  - player `skills`
  - container entity state (`searched`, `items`, `gear`)
  - built `stove` objects
- **Older saves load.**
  - The removed street search spots are dropped with a log warning. Their stored state was only restock timers.
  - The new interiors start fresh.
  - Players start at Scavenging level 1.
- A search in progress is never saved. A save made mid-search reloads with that container unsearched.
- **Network protocol 8 → 9.** Host and clients must run the same build.

## 8. Tests

- **Unit** (`tests/unit/test_scavengers_circuit.gd`, 15 tests; **147/147** overall, content check PASS):
  - entering and leaving every building, shelter, sound leaking outside
  - location-typed loot and pre-emptied containers
  - a timed search, contents revealed, take one and take all, no second search or XP
  - cancel, walk away, disconnect
  - one searcher per container, two at once
  - empty containers, the time curve and level cap, the multiplier (0×, 5×, not retroactive, clamped)
  - persistence: searched state and XP saved, a mid-search save abandoned, multiplier not saved
  - search noise reaching the street, the Skills screen text
  - trunk load and unload all (equipped gear kept, capacity, no loss)
  - the stove (needs a stovepipe, parts used once, heats only when finished, survives a save)
  - stovepipes exist in Ashgrove
- **Real two-process multiplayer** (`tools/mp_test.py`):
  - `circuit_multi` (21 checks): independent exploration (client in the grocery, host in the pharmacy),
    simultaneous searches in two shops, individual XP, one searcher per container, taking from both sides
    without duplication, a disconnect mid-search, reconnect, save and restart without regeneration.
  - `progression_multi` (20 checks): clients refused (multiplier, grant, level) even with client dev commands
    allowed, 5×, 0×, 10×, 25×, back to 1×, reset and grant for everyone, set level, faster searches at a
    higher level, the multiplier back to 1× after a restart.
  - `expedition_multi` (22 checks), the full circuit:
    - drive into Ashgrove; the client scavenges the hardware store while the host does the garage
    - load the trunk (≤ 12, no loss), drive back through the station to the homestead
    - unload, carry it down, store everything, build the stove, both players warmer, restart
  - `vehicle_multi` 24/24 and `settings` 5/5 re-run after the street changes.
- **Full regression:** see §10.
- **Rendered** (`tools/shots_scavengers_circuit.py`, 20 screenshots in `../screenshots/iteration_013/`,
  17 CHECK lines all PASS):
  - the street entrance prompt and each shop
  - both new houses and the town house
  - the grocery backroom at night with the flashlight
  - searching with the progress bar, the result with "+XP", the contents panel, the Skills screen
  - the developer Progression tab with 5× active, and the World tab
  - the trunk panel
  - the stove preview, the stove in the side view and the stove top-down

## 9. Known limitations and open decisions

- **All new art is generated placeholder art** waiting for tablet art. Furniture is seen from the front only,
  and the garage's car lift is empty.
- **Indoor layouts are authored**, not procedural. Containers and furniture move by editing
  `tools/build_interiors.py` and re-running it.
- **Shop doors are open doorways** (an entrance prompt), not opening doors. The house doors are real doors.
- **Leaving a region by car needs the car's front at the road exit**, which is unchanged since iteration 011.
  To leave Ashgrove you turn the car around on Main Street. The expedition test re-parks the car facing
  west with the developer command.
- **Ashgrove offers a finite amount of XP** (about level 8 for one player) because nothing regenerates.
  The curve and XP values are EXPLORING (register WX-16…WX-20).
- **The stove burns nothing.** Fuel for heating was not commissioned.
- **Windows acceptance pending.** Verified on Linux with the Compatibility renderer, using the editor binary
  (a debug build, so developer tools are on). Release-build gating is implemented but was not exercised with
  an exported release build: there are no export templates in the test environment.

## 10. Full regression

**493 of 493 checks passed** across every scenario in `tools/mp_test.py` (all iterations 001–013, two real
game processes where multiplayer is involved), in one uninterrupted run on the final code. The host simulation
peaked at 1.08 ms per frame with 30 Burnt Ones and two players (budget 8 ms). Unit tests: 147/147, content check
PASS, script guides EN + DA 120/120.
