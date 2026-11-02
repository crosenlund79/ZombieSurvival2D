# Iterations 003–005 — The Survival Slice

| Item | Value |
|---|---|
| Base | `iteration/002-bunker` @ `3d69475` |
| Branch | `iteration/003-survival-slice` |
| Recovery references | `backup/pre-iteration-003` (`3d69475`), `backup/iteration-003-milestone-a` (`e7a998c`), `backup/iteration-003-milestone-b` (`825e27e`), `backup/iteration-003-milestone-c` (the milestone C commit) |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Save schema | 3 (migrations 1→2→3; iteration 001/002 worlds load) · Network protocol 4 |

The assignment had three milestones, delivered in sequence on one branch. Each milestone was
implemented, tested, committed, pushed and given a recovery branch. Decisions are listed in
[`../DESIGN_DECISIONS.md`](../DESIGN_DECISIONS.md), and every prototype number there is marked EXPLORING.

## Milestone A — Danger (`e7a998c`)

- **Zombie** (one type; `ZombieState`, `ZombieSim`, `ZombieView`). State machine: wander → investigate →
  chase → wind-up → recover, plus stagger and dead. Detection uses proximity, a sight cone with line of
  sight, hearing, and the last known position followed by a search. Paths use A* on a navigation grid built
  from the scene's authored collision, trees and closed doors.
- **Safety boundary.** Zombies exist only in the homestead surface region. The farmhouse interior and the
  bunker have none, and attacks need reach and line of sight.
- **Club.** Take it from the rack inside the farmhouse. Every player can take one and it never runs out.
  Melee swing on F / left mouse. The host resolves the hit arc.
- **Health, defeat, respawn.** Zombies give a visible red wind-up before they strike. At 0 health the player
  goes down and respawns in the farmhouse after 5 s with 70 health, keeping everything they carry.
  Health regenerates slowly.
- **Noise system** (host-authoritative). Chopping, a falling tree, melee, sprinting, doors, digging and the
  generator queue noise events with a category radius and weight. Zombies go to the location they heard,
  not to the player.
- **Hordes.** Attention builds per zone and decays (half-life 18 s). Thresholds recruit nearby zombies and
  spawn capped reinforcements off-screen with cooldowns. The base population is persistent.
  Reinforcements and attention are transient, so a reload starts calm.
- **HUD and multiplayer.** Health bar, threat line (Quiet / Restless / Hunted / Sheltered), hurt flash.
  Zombies, combat events and vitals are replicated, and clients only display them.

## Milestone B — Expansion (`825e27e`)

- **Excavation grid** on level −1 (`bunker_earth`): 40 × 30 cells of 64 px, an initial chamber, and a
  permanent ladder shaft. Digging takes 2 s, is validated by the host, persists, and is replicated by
  `_rpc_terrain`. `TerrainView` redraws walls and rebuilds collision live.
- **Structural rule.** You may dig one cell beyond the original chamber's edge (safe margin). Beyond that,
  a reinforced timber support (4 wood from storage, 3 s) makes cells within about 3 cells diggable.
  Supports need at least 2 cells between them. Refusals say why: "needs a support nearby", "too close to
  another support" and so on. A green or red target outline shows the result before you press anything.
- Unlimited levels and the developer level command are unchanged.

## Milestone C — Living Underground

- **Items and shared storage.** There are four items: wood, fuel, dirty water and clean water. A player
  carries 30 slots. The bunker has one shared store; the storage locker and the timber piles are both
  views of it. Every transfer moves items between two bags in one host step, so racing players cannot
  duplicate items.
- **Scavenging** on the surface: a car trunk, a shed shelf and a rain barrel. Each search succeeds once,
  then the spot refills after 15 / 20 / 4 minutes of game time, so the loop cannot run dry. A full bag
  leaves the loot in place.
- **Generator.** Add fuel (from your hands, otherwise from storage), start or stop it, and read the panel
  status (fuel %, minutes of running left). It burns fuel on the shared clock, stops when empty, hums
  while running, and registers a quiet `machine` noise. That noise stays underground for now (question 2).
- **Power** is logical and covers the whole bunker. Ceiling lamps light up and the room brightens. With
  the power off the bunker is dim, but the lanterns and ladder shaft stay lit, so it is never black.
- **Water chain.** Dirty water goes into the purifier. With power, it makes one clean water every 20 s.
  Collect it, or drink from the tap.
- **Hydration.** The water bar drops about 2.5 per minute. Below 25 you are thirsty: health stops
  regenerating and the HUD warns you. **Q** drinks carried clean water (+40). At 0, health drains slowly
  down to a floor of 25, which is mild by design.
- **Developer tools** (F3): peaceful toggle, grant timber, grant fuel and dirty water, make thirsty,
  advance the clock, spawn zombies or a group, make noise, hurt, heal.

## Verification

| Kind | Result |
|---|---|
| Unit tests + content check | **53/53 PASS** (7 new in `test_infra.gd`, plus `test_threat.gd` and `test_terrain.gd` from A/B); content check 0 FAIL / 0 WARN |
| Real separate processes (`tools/mp_test.py`) | **219/219 PASS**, including every iteration-001/002 scenario |
| — `accept` (35 checks) | The full 25-step acceptance run with zombies active: new world → farmhouse → shelter construction → club → chop → zombies investigate → more converge → fight → scavenge → retreat → descend → deposit → excavate → refused unsupported cell → support from stored wood → dig further → supplies in storage → fuel and start the generator → lamps on and hum → fill the purifier → clean water over time → collect → drink with Q → save → quit → reload (everything intact, lamps lit) → second process joins as a guest on the surface while the host is underground → identical storage, machines, terrain and zombies |
| — `infra_multi` (19 checks) | Client scavenges on the surface while the host fuels and starts the generator below; the client sees it running; the client descends and sees the lamps lit; client deposits are visible to the host; **concurrent withdrawals from both processes never duplicate**; inventories agree; the client fills the purifier; the host goes to the surface and the bunker keeps purifying and burning fuel; the purifier is identical on both peers; the client drinks and the host agrees; save → host restart → the client rejoins underground with storage, inventory and machines intact |
| — `danger_single` / `danger_multi` (17 / 10) | Investigation, escalation, caps, authoritative melee, retreat indoors, zombies give up, calm reload; client noise draws zombies; client damage and hits agree on host and client; rejoin |
| — `dig_multi` (14) | Concurrent dig gives one job; collision updates; unsupported refusal; support wood spent once; digging inside the support radius; host on the surface sees changes made below; persistence after restart |
| Rendered screenshots | `docs/screenshots/iteration_003/`, inspected. Fixed during inspection: lamp lighting overexposed the powered bunker (toned down), a "6.0" capacity format in the purifier panel, and earlier lethal zombie numbers and a prompt priority conflict (A/B) |
| Windows / exported build | **Not tested. Windows acceptance pending.** |

Screenshots: `d1`–`d4` danger and combat; `e1`–`e3` excavation and supports; `f1` unpowered bunker,
`f2` storage panel, `f3` generator panel, `f4` powered bunker with lamps, `f5` purifier panel,
`f6` HUD while thirsty with inventory and drink hint, `f7` HUD after drinking; `g1`/`g2` two real
processes: host underground with power, guest scavenging on the surface.

## Known limitations

- All art and sounds are generated placeholders. The zombie figure is a stand-in (zombie design deferred).
- The host does not simulate player collision. It validates speed, reach and line of sight for actions,
  but movement collision is still checked on the moving client.
- Zombies use a coarse grid. They can look stiff around fence corners, and reinforcement spawn points are
  fixed at the map edges.
- Purifier progress is published in 10 % steps, so a client's progress readout can trail the host by up to
  one step. Contents (in/out) are always exact.
- On the surface the HUD shows "Shelter storage: —". Storage figures appear once you are inside a bunker
  region.
- Items have no icons. Inventory is a HUD line plus machine panels.
- Excavation exists only on the earthen level −1. Developer concrete levels have no grid.
- Position snapshots are not filtered by region (fine at this player count).
- Linux software-rendering frame rates do not represent Windows. Performance on Windows is unmeasured.

## Open design questions for the creator

1. Respawn rules: is "wake in the farmhouse, keep everything" the right forgiveness, or should defeat
   cost something (dropped items, time, health)?
2. Should underground noise (digging, a running generator) carry to the surface and draw zombies to the
   farmhouse? Right now it is registered in the bunker region, where there are no zombies, so it has no
   effect.
3. Power model: keep it bunker-wide and logical, or move towards wiring and capacity later?
4. Hydration strength: is −2.5 per minute with a health floor the right mildness? Should dirty water be
   drinkable with a penalty?
5. Scavenging: fixed spots that restock, or randomised loot tables and more locations?
6. Excavation: should supports have an upkeep, decay, or a collapse risk (bunker threats, GF-03)?
7. Antagonist mix: zombies only, or zombies plus rogue AI (visual register C-3)?
