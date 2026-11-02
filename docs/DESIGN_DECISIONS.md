# Design Decision Register (gameplay)

This is the living register of **gameplay and system** decisions. Visual decisions have their own register
in [`visual_direction/README.md`](visual_direction/README.md) (VD-/VX-/VF- ids). Project-level decisions are
in [`HANDOVER.md`](HANDOVER.md) §1.2.

- **APPROVED**: the creator decided it, either directly or by commissioning it in an assignment.
- **EXPLORING**: implemented or proposed as a prototype choice. It works and can be tested, but the creator
  has **not** decided it. Every number lives in a content or tuning file so it can change without code.
- **DEFERRED**: deliberately not built yet.

Update this file whenever an iteration adds or settles a decision.

## APPROVED

| ID | Decision | Source |
|---|---|---|
| GD-01 | Danger above, security below: surface exploration is risky, the shelter is safe but must be earned | Handover §1.1 |
| GD-02 | Host-authoritative co-op: clients request, the host validates and commits all shared-world changes | Handover, CLAUDE.md |
| GD-03 | Persistent worlds with versioned saves; the world keeps running when menus are open | Handover, CLAUDE.md |
| GD-04 | The shelter is dug beneath the farmhouse; the bunker is entered from that building | Iteration 002 assignment |
| GD-05 | Bunker depth is unlimited; there is a developer command to create test levels | Iteration 002/003 assignments |
| GD-06 | Zombies are a surface threat: one zombie type that wanders, investigates, detects, chases, attacks, loses its target, takes damage and dies | Iteration 003 assignment (A) |
| GD-07 | Zombies never enter the farmhouse interior or the bunker, and never attack through walls | Iteration 003 assignment (A) |
| GD-08 | One melee weapon with a way to obtain it; player health, defeat and a forgiving respawn | Iteration 003 assignment (A) |
| GD-09 | A host-authoritative world noise system: chopping, running, melee and interactions make noise, and zombies go to where they heard it | Iteration 003 assignment (A) |
| GD-10 | Escalating hordes driven by accumulated attention that decays, with caps, cooldowns and off-screen reinforcements | Iteration 003 assignment (A) |
| GD-11 | Grid-based, timed, persistent excavation inside the bunker | Iteration 003 assignment (B) |
| GD-12 | A structural support rule: a safe starting area, supports extend the diggable range, clear feedback when refused | Iteration 003 assignment (B) |
| GD-13 | A minimal item system with shared storage (deposit/withdraw, no duplication), integrated with the timber stockpile | Iteration 003 assignment (C) |
| GD-14 | Surface scavenging that is persistent and renews, so the loop cannot soft-lock | Iteration 003 assignment (C) |
| GD-15 | A generator with fuel, start/stop, status and consumption over simulated time | Iteration 003 assignment (C) |
| GD-16 | Logical power for lights and the water purifier; losing power must never give a black screen | Iteration 003 assignment (C) |
| GD-17 | A water chain: dirty water → purifier (needs power, takes time) → clean water → drink | Iteration 003 assignment (C) |
| GD-18 | A mild hydration mechanic | Iteration 003 assignment (C) |

## EXPLORING (prototype choices awaiting a creator decision)

| ID | Topic | Current prototype | Where to tune |
|---|---|---|---|
| GX-01 | Gameplay perspective | 3/4 oblique top-down (see VX-01) | — |
| GX-02 | Zombie behaviour numbers | 100 hp; speeds 32 / 62 / 92 px/s (wander / investigate / chase); sight 300 px in a 140° cone, 110 px all round; 0.7 s wind-up; 10 damage every 1.7 s | `content/tuning/zombies.json` |
| GX-03 | Base population and spawning | 6 persistent zombies at the map edges, replenished after 60 s; reinforcements are transient | `zombies.json`, `content/regions/homestead.json` |
| GX-04 | Noise radii and attention | chop 460 px, fell 560, melee 260, sprint 190, door 180, dig 260, generator 300; attention half-life 18 s; escalation at 1.2 / 3.5 / 6.5 → 2 / 4 / 7 zombies; max 8 reinforcements, 16 active | `zombies.json` |
| GX-05 | Combat | Club: 34 damage, 74 px reach. Bare hands: 12 damage, 54 px. Melee arc ≈ 130°, needs line of sight | `WorldActions.WEAPONS` |
| GX-06 | Defeat and respawn | Respawn inside the farmhouse after 5 s with 70 health; items kept; no other penalty | `SurvivalSim` |
| GX-07 | Excavation numbers | 64 px cells; dig 2 s; support 3 s and 4 wood; safe margin 1 cell; support radius 3.2 cells; minimum 2 cells between supports | `content/bunker_levels/bunker_earth.json` (`excavation`) |
| GX-08 | Carrying | 30 slots, one unit per slot, any item | `content/items.json` |
| GX-09 | Scavenge spots | Car trunk (2 fuel, 1 dirty water, 15 min), shed shelf (1 + 1, 20 min), rain barrel (2 dirty water, 4 min), fixed contents | `homestead.json` (`loot`, `restock_minutes`) |
| GX-10 | Generator | Tank of 4 fuel; 180 s of game time per fuel; registers quiet noise while running (it stays underground: bunker regions have no zombies) | `content/tuning/infrastructure.json` |
| GX-11 | Power model | Bunker-wide: any running generator powers every consumer in that bunker; no wiring, capacity or load | `InfraSim.is_powered` |
| GX-12 | Purifier | 20 s per unit, holds 6 in / 6 out, needs power; also a "drink from the tap" option | `infrastructure.json` |
| GX-13 | Hydration | −2.5 per minute; +40 per drink; thirsty below 25 (no health regeneration); at 0, −3 health per minute down to a floor of 25 | `infrastructure.json` |
| GX-14 | Storage | One shared store per bunker, reachable from the locker and the timber piles; no per-player storage | `BunkerState.resources` |

## DEFERRED

| ID | Item | Notes |
|---|---|---|
| GF-01 | Zombie visual design and further zombie types | Visual design deferred (VF-01); one placeholder figure exists |
| GF-02 | Rogue AI / drones as an antagonist | Open design question (visual register C-3) |
| GF-03 | Threats to the bunker itself (raids, breaches, cave-ins) | The handover says security "can be threatened"; there is no collapse or raid simulation |
| GF-04 | Hunger, food, cooking, sickness | Only hydration exists |
| GF-05 | Crafting, tools, weapon durability, ranged weapons | One club only |
| GF-06 | Power wiring, capacity, multiple machine loads | The power model is logical (GX-11) |
| GF-07 | Day/night, weather, seasons | The clock is raw simulated seconds |
| GF-08 | Inventory UI beyond panels and the HUD line (drag and drop, item art) | Items have no icons yet |
| GF-09 | More surface regions, travel, biomes | Only the homestead exists |
| GF-10 | Dedicated server, relay/matchmaking | LAN/IP only |
