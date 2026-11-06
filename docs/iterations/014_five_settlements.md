# Iteration 014 — The Five Settlements

| Item | Value |
|---|---|
| Base | `iteration/013-scavengers-circuit` @ `ee70789` (verified locally and on the remote before any change) |
| Recovery reference | **`backup/pre-five-settlements` → `ee70789`** (pushed and verified on GitHub before any change) |
| Branch | `iteration/014-five-settlements` |
| Milestone checkpoints | `backup/iteration-014-milestone-a` (`b9782c3`), `-b` (`644dd2b`), `-c` (`425fb78`), `-d` (`6b35e23`), `-e` (`dae4348`), `-f` (`bb35fb4`); the final state is the branch head |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Build | Red Thaw 0.6.0 · iteration 014 · network protocol 10 · save schema 4 (unchanged, see §9) |
| Status | Implemented and tested on Linux (unit, real two-process multiplayer, rendered). **Windows acceptance pending.** |

Item audit (every item, its id and where it comes from): [`014_item_audit.md`](014_item_audit.md).
Screenshots: [`../screenshots/iteration_014/`](../screenshots/iteration_014/).

## 1. Side-view interiors (milestone A)

- **Outdoors stays top-down.** Every building interior is a side-view cross-section: the cabin, all Ashgrove
  shops and houses, every new building, the civic hall and the mine. Bunkers and cellars were already side view.
- **One model, no duplicated state.** Interiors reuse the bunker's excavation grid (region keys `"view": "side"`,
  `"style": "building" | "mine"`, `excavation.fixed: true`).
  - A fixed grid can never be dug and needs no supports.
  - Storeys are 4 open rows plus a 1-row floor slab.
  - Stair landings are grid `platforms`: walkers stand on them, climbers pass through.
  - Stairs (and the mine's ladders) are entity type `stairs` with a `top`.
  - Entity ids and their saved state are the ones the top-down interiors had, so searched containers and
    open hatches survive the change of perspective.
- **Doors, floors, ceilings, furniture.** Rooms, walls, floor and ceiling strips, dividers, windows (some
  boarded), exterior walls in the building's material, furniture props, wall labels.
- **Entering and leaving.** Arriving through a door places your feet on the floor. Leaving returns you to the
  building's street door. Old saves with top-down positions inside a building are settled onto the floor on load.
- **Light and weather.**
  - Daylight comes through the windows and follows the shared clock and the weather.
  - Indoors there is no precipitation, and the cold is reduced.
  - Each region can set its own ambience, tint and warmth.
- **Interaction, inventory, crafting and construction** work as before.
  - The cabin's shelter site and hatch are drawn as a trapdoor in the floor.
  - Dig prompts are off in fixed grids.
- **Construction progress bar.** Anchored to the object's own sprite (above its top edge, centred) in both
  views. It is drawn by that object only, so there is never a duplicate.
- **Houses come in three layouts** (kitchen by the door / mirrored with the stairs on the left / a wider flat).
  Exteriors are logs, siding or brick by settlement.

## 2. The five settlements (milestone B)

The world is one road network: no fast travel. You go on foot through road portals or drive (vehicle exits),
and the map reveals each place when you first arrive.

| Settlement | Region | Map offset | Character | Interiors |
|---|---|---|---|---|
| **Ashgrove** (existing) | `town` | 4640, 385 | small commercial town | grocery, pharmacy, hardware, clothing, garage, West / East House, House on Main Street (+ cellar) |
| **Corran Junction** | `junction` | 7840, 285 | industrial / service crossroads: rail-side warehouse, machine shop, power & water building, fuel depot, substation, water tower | Machine Shop, Rail-side Warehouse, Corner Store, Worker's House, Power & Water Building |
| **Greyhollow** | `greyhollow` | 8240, −2215 | mining settlement under the hill: headframe, ore hopper, slag heaps, miners' rows | **Mine (Adit No. 3)**, Mining Co. office, General Store, Mine Supply, Miners' Row House, Storage Shed |
| **Stillwater** | `stillwater` | 10840, 185 | the larger town: commercial centre, civic square, church, memorial | Market, Outfitters, **Civic Hall (4 levels)**, Clinic, Police Station, Apartment Block, House on Mill Road, **A Quiet House** (hideout) |
| **Port Halden** | `harbor` | 14440, 85 | frozen harbour: quays, piers, warehouses, cannery, crane, lighthouse, an iced-in trawler, open channels with drifting icebergs | Harbor Cottage, Ship Chandlery, Harbor Master's Office, Northsea Cannery, Pier 4 Warehouse, Net Shed |

- **Roads.** Ashgrove's east road (the roadblock was moved aside) → Corran Junction. From the junction, north
  → Greyhollow, east → Stillwater → Port Halden. Every link works on foot and by car, in both directions.
- **Region map** (world map, M):

  ```
                         Greyhollow (mine)
                               |
  Homestead — Service station — Ashgrove — Corran Junction — Stillwater — Port Halden (sea)
  ```

- **Icebergs move.** Bergs and floes drift along the open channels. Their position is a pure function of the
  shared world clock (`IceDrift`), so every player sees the same berg in the same place. The quays and piers
  have collision; the water does not let you walk on it.
- **Audio.**
  - New ambiences: `amb.harbor_ice` (creaking ice, water) and `amb.mine_drip`.
  - Gun sounds: pistol, revolver, shotgun, rifle, magazine out/in, dry click. They come from the creator's
    audio inbox where present.
  - Every other region keeps its ambience routing.
- **Containers.** 155 pooled containers in the new and existing buildings, plus outdoor caches (snowed-in
  sleds, hunting camps) and searchable car, truck and police-car wrecks.

## 3. The mine and the civic hall (milestone C)

- **Greyhollow Mine, Adit No. 3** (`greyhollow.mine`): a fixed 64 × 30 cell grid, handcrafted.
  - **Level 1** is the entrance gallery from the hillside, with a lamp locker, tool crate and powder box.
  - A **ladder shaft** goes down to **level 2**, the long haulage drift. It has a supply cache, a shift locker
    and the old **pump room** (a taller side chamber with a tool chest).
  - A **winze** goes down to **level 3**, the deep workings, with a deep cache and the "last shift" drawers.
  - **Two collapsed passages**: rubble you cannot pass.
  - Dressing: timber sets, rails, ore veins, carts and hanging lamps that still burn.
  - **Darkness.** Away from the lamps it is dark, so the flashlight or headlamp matters.
  - **No depth limit** in the rules: the grid can grow in any direction.
- **Stillwater Civic Hall** (`stillwater.civic_hall`): **basement + three floors**.
  - −1: boiler room and emergency stores
  - 0: lobby and records
  - 1: council offices
  - 2: archive and attic
  - Three stair flights alternate sides, so you walk the building floor by floor. There are 15 containers in all.

## 4. The Burnt One hideout (milestone D)

- **A Quiet House** in Stillwater looks like any other home. It is the approved situational hunt trigger and
  nothing more: the cabin and the bunkers stay safe.
- **Disturbance.** Noise made inside adds up: searching, running, fighting, and gunshots most of all. Past
  the threshold, **one or two Burnt Ones emerge once**, at their hiding places upstairs and downstairs. They
  screech and hunt the nearest player inside.
- **Pursuit.**
  - Inside the house they follow floors and take the stairs.
  - If you flee outside, they make for the door and follow you through it.
  - Outside they use the ordinary AI: sight, hearing, losing you, giving up.
- **No regeneration.** The hideout is *cleared* when they are dead. `triggered`, `cleared`, the disturbance and
  the Burnt Ones themselves are saved.
- **Silhouettes only.** Burnt Ones keep the iteration 012 silhouette rules and are never fully revealed, even
  in a flashlight beam.

## 5. Firearms (milestone D)

- **Controls.**

  | Action | Key |
  |---|---|
  | Equip | Inventory (I) → Equip |
  | Aim | the mouse direction |
  | Fire | left mouse or F (the attack key) |
  | Reload | **T** (rebindable) |
  | Rounds | shown on the HUD ("Rounds 6/8 (+12)") |

  The empty gun clicks.
- **Authority.** The host decides who fires, what is hit, the damage, rounds in the weapon and reloading. The
  rounds live in the gear item (`loaded`), so they travel with the gun through drops, trunks and saves.
- **Noise.** Every shot is a loud noise through the ordinary noise system (`gunshot` radius 1300,
  `gunshot_heavy` 1700). Burnt Ones hear it from far away, and from the street when the shot is indoors.
- **The framework** (`Firearms`, `firearm` block in `content/items.json`):

  | Gun | Ammo | Rounds | Damage | Range | Notes |
  |---|---|---|---|---|---|
  | Handgun | pistol rounds (or a loaded magazine, swapped at once) | 8 | 70 | 640 | rare: bedrooms, police, a mine cache |
  | Revolver | revolver rounds | 6 | 95 | 620 | the mayor's desk, evidence |
  | Shotgun | shotgun shells | 4 | 150 over 3 pellets | 380 | hits several in a line |
  | Hunting rifle | rifle rounds | 5 | 160 | 1000 | the hunter's camp, miners' homes |
  | Military rifle | rifle rounds | 20 | 85 | 900 | police armory only, rare |

  - Damage falls off with distance.
  - Line of sight follows walls top-down and floors in the side view.
  - Guns wear and can jam when worn out. Gun oil and the cleaning kit restore them.
- **Rarity.** Firearms are rare in loot (§7) and are sometimes found with a few rounds in them.

## 6. Time controls (milestone D)

- **F3 → World:** Pause, 1×, 2×, 5× and 10×. The HUD shows "Time ×5 (dev)" or "TIME PAUSED (dev)" while it is not 1×.
- **Every timed system follows the one clock:** survival, weather, day and night, crafting jobs,
  construction, searching, the hideout and drifting ice.
- **Single player only.** In a hosted game the command is refused for the host and for every client, and the
  clock keeps its normal pace. The scale is runtime-only: it is never saved, and is 1× after loading.

## 7. Items and loot (milestones E and F)

- **The complete catalogue: 175 items.**
  - Every item has a stable id, a name and description (EN + DA), category, weight, stack limit and icon.
  - Where relevant it also has durability, nutrition, hydration, healing, warmth, insulation, slot, weapon
    stats, ammo type, fuel or crafting use.
  - Categories: food, drinks, medical, fire and warmth, clothing, weapons, ammunition, tools, materials,
    mechanical parts, electronics, fuel, utilities, frozen-world survival, household and junk, parts.
  - Items listed under several headings share one id (e.g. the hammer, crowbar and shovel are tools and
    weapons; heat packs are the hand warmers).
  - Source: `tools/build_catalogue.py`.
- **Carrying.**
  - A slot holds up to an item's **stack limit**: 30 pistol rounds, 10 matches, 1 coat.
  - A worn **backpack** adds 10 slots.
  - Weight is shown, but it does not slow you down.
- **Clothing slots:** hand, body, head, face, hands, legs, feet, back. Insulation from everything worn adds up,
  to a cap of 0.85.
- **New uses.**
  - Heat packs (used up), the thermal blanket (kept) and the portable stove (burns stove fuel) warm you.
  - Gun oil, the cleaning kit and the whetstone restore the held weapon of the right kind.
  - Glow sticks and flares light the dark and burn out (10 and 4 minutes). The headlamp, lantern and crank
    flashlight are lamps.
  - Food and drink can warm, chill or sicken you: coffee, frozen food, spoiled food, alcohol.
- **Inventory (I).**
  - An icon for every item.
  - A category filter.
  - Every equipment slot in use.
  - Slots used out of capacity, and total weight.
  - Tooltips with the description, category, weight, stack, condition, nutrition, hydration, healing,
    warmth, insulation, weapon and ammunition stats, rounds loaded, "ammunition for", and crafting uses.
- **Contextual weighted loot** (`content/loot_pools.json`, 69 pools, `tools/build_loot_pools.py`).
  - **Pool types:** homes (Ashgrove, miners', harbour), the hunter's camp, frozen wilderness, grocery,
    general store, clothing, clinic and pharmacy, offices, the civic hall, police (desk, files, storage,
    evidence, armory), workshops, industry, utility, the fuel depot, the mine (office, lamps, tools, stores,
    deep workings), marine, cannery, and vehicles.
  - **When it rolls.** A pooled container rolls **once, on its first search**, from the world seed + its id.
    The same world always holds the same things, on every peer, whoever searches first.
  - **What a roll can give.** A container may be empty or hold only household junk. Firearms are rare.
    Gear is found worn.
  - The Ashgrove containers and the cabin keep their handcrafted contents.
  - **Scavenging XP** comes only from first searches; the XP multiplier is unchanged.
  - **Every item has an acquisition route.** A unit test proves it, and the audit lists them.

## 8. Multiplayer

- **Host authority** for everything new: searching and rolling, taking, firing and reloading, the hideout,
  the time scale (refused), items and uses.
- **Real two-process scenario `five_multi`** (21 checks):
  - A pooled cannery container is searched by the client; both peers show the same contents, take-all moves
    everything once, and searching again gives no XP.
  - Time acceleration is refused for the host and the client.
  - The client reloads and fires the handgun; the host and the client agree on the rounds.
  - The client is down the mine; the host places it there.
  - Noise wakes the hideout once; one or two Burnt Ones emerge, and never again.
  - After save, restart and rejoin, everything is where it was: the client's region, the rounds in the gun,
    the emptied container, the triggered hideout.

## 9. Saves and migration

- **Save schema 4, no structural migration.** New data is optional:
  - `loaded` rounds on firearm gear
  - new equipment slots
  - hideout entity state
  - rolled container contents
  - new regions start fresh
- **Older saves load.**
  - Containers kept their ids across the switch to side view, so searched state carries over.
  - Players saved inside a building with an old top-down position are placed on its floor on load
    (`SideSection.settle`).
  - Stacks are counted with the new slot rule. Old items keep a stack limit of 1, so nothing overflows.
  - Nothing is deleted.
- **Runtime only:** the time scale and a burning glow stick's timer.
- **Network protocol 9 → 10.** Host and clients must run the same build.

## 10. Asset templates (all replaceable)

| Set | Generator | Templates | Manifest |
|---|---|---|---|
| Side-view walls, floors, exteriors, windows, doors, stairs, trapdoors, mine dressing (30) | `tools/art/gen_side_interiors.py` | `assets/templates/side/` | `visual_side_interiors.json` |
| Settlement buildings, landmarks, harbour, ice, tiles (49) | `tools/art/gen_five_settlements.py` | `assets/templates/world/settlements/` | `visual_settlements.json` |
| Held firearms (5) | `tools/art/gen_firearms.py` | `assets/templates/items/` | `visual_firearms.json` |
| Held melee weapons (11) | `tools/art/gen_item_icons.py` | `assets/templates/items/` | `visual_melee_014.json` |
| Inventory icons (175) | `tools/art/gen_item_icons.py` | `assets/templates/ui/icons/` | `visual_item_icons.json` |
| Ambience (harbour ice, mine drip) | `tools/art/gen_five_audio.py` | `assets/templates/audio/five/` | `audio_five.json` |

- **Overriding.** Put a file at the same path under `assets/overrides/` without the `template_` prefix, e.g.
  `assets/overrides/ui/icons/handgun.png`.
- **Creator files are never overwritten.** The gun sounds were taken from the creator's audio inbox
  (`tools/art/import_audio_inbox.py`) without changing the originals.

## 11. Tests

- **Unit** (`tests/unit/test_five_settlements.gd`, 25 tests; **171/171** overall, content check PASS):
  - side views and their ids, floors, stairs, entering and leaving, old positions settled
  - every settlement reachable by road; every entrance in and out
  - the drifting ice; the civic hall's four floors; the mine's three levels and its way out
  - handgun reload, fire, ammo and noise; the shotgun and the rifle
  - the hideout waking once and following outside
  - the catalogue record of every item; stack slots and the backpack; insulation; the new uses; tooltips
  - the acquisition audit; pools resolving; seeded, contextual and balanced rolls; roll once with no repeat XP
  - a save round trip of all of it
- **Multiplayer:** `five_multi` 21/21, plus the full regression (§13).
- **Rendered** (`tools/shots_five_settlements.py`, 24 screenshots in `../screenshots/iteration_014/`, every CHECK line PASS):
  - the cabin and five interiors in the side view; climbing to an upper floor
  - the progress bar in the side view and top-down
  - Corran Junction, Greyhollow, Stillwater, Port Halden and its icebergs; the world map with all five
  - the civic hall's four storeys; the mine's entrance in the dark and its second level by flashlight
  - Burnt Ones emerging from the hideout; the handgun firing; time controls at 5×
  - the inventory with icons; searching a pooled container and its result

## 12. Known limitations

- **Placeholder art.** All new art is generated and waits for tablet art: buildings, interiors, icons, held
  weapons. Furniture is seen from the front only.
- **Layouts are authored.** Interiors and settlements are authored by generators (`tools/build_side_interiors.py`,
  `tools/build_settlements.py`, `tools/build_landmarks.py`). Changing a layout means editing those and re-running them.
- **No ambient Burnt One population in the new towns.** Ambient population is off by default (unchanged rule),
  so in the new towns Burnt Ones appear through hunts, gunfire attention and the hideout.
- **Flashlight cone in the side view.** It points downward until you first turn.
- **Map labels crowd** at the widest zoom.
- **Weight is informational** (no encumbrance). This was not commissioned.
- **Some catalogue items are materials or trade goods with no use yet** (e.g. electronics, jewellery, keycards,
  padlocks, radios). Their descriptions say so.
- **Firearms balance is EXPLORING.** So are the loot weights.
- **Some containers roll empty.** On a given seed several in a row can be empty (by design, about one in four).
- **Windows acceptance pending.** Verified on Linux with the Compatibility renderer, using the editor (debug)
  binary.

## 13. Full regression

- **Full run: 513 of 514 checks passed.** Every scenario in `tools/mp_test.py` (iterations 001–014, two real
  game processes where multiplayer is involved) ran in one uninterrupted pass on the final code.
- **The one failure** was `danger: more zombies converge (horde developing)`. That check depends on timing: wandering
  Burnt Ones must turn toward the players within a fixed window. **Re-running `danger_multi` on its own passed
  10/10, twice.** It is recorded as an intermittent timing check, not as a regression.
- **Performance.** The host simulation peaked at 1.18 ms per frame with 47 Burnt Ones and two players
  (budget 8 ms).
- **Also on the final code:** unit tests 171/171, content check PASS, script guides EN + DA 125/125.
