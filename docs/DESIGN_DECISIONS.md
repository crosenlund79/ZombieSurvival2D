# Design Decision Register (gameplay)

This is the living register of **gameplay and system** decisions. Visual decisions have their own register
in [`visual_direction/README.md`](visual_direction/README.md) (VD-/VX-/VF- ids). Project-level decisions are
in [`HANDOVER.md`](HANDOVER.md) §1.2.

- **APPROVED**: the creator decided it, either directly or by commissioning it in an assignment.
- **EXPLORING**: implemented or proposed as a prototype choice. It works and can be tested, but the creator
  has **not** decided it. Every number lives in a content or tuning file so it can change without code.
- **DEFERRED**: deliberately not built yet.

Update this file whenever an iteration adds or settles a decision.

> **Iteration 010 — Red Thaw concept conversion.** The game is now *Red Thaw* (working title): a nuclear
> winter with human madness instead of zombies. Earlier zombie decisions still describe working systems.
> The simulation code keeps the name "zombie" internally, and the hostiles are presented as **Burnt Ones**.
> The protected farmhouse rule (GD-07/GD-22) now protects the **hunter's cabin** and its bunker. Automatic
> threat loops (GD-06, GD-09, GD-10, GD-28, GD-29) are kept in code but switched off by default until the
> creator decides what starts a hunt (RX-01).

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
| GD-19 | A small construction system: choose, preview, validate, check materials, host-commit, spend once, persist, dismantle, repair, synchronise | Commission 006–009 (I006) |
| GD-20 | Material progression wood → metal → concrete, with at least one structure upgraded in tiers; the hatch is upgradable | Commission (I006) |
| GD-21 | Defensive structures have condition, armour, repair cost and persistent damage; one active defensive mechanism besides barricades | Commission (I006) |
| GD-22 | GD-07 stays in force: zombies do not enter the farmhouse or the bunker; base threats target exterior defences | Commission (I006, protected farmhouse rule) |
| GD-23 | No arbitrary maximum bunker depth; deeper-level construction gameplay, load-bearing floors and collapse stay deferred | Commission (I006) |
| GD-24 | A practical inventory (stacks + gear with identity), drop/pick up, equip, shared storage, no duplication | Commission (I007) |
| GD-25 | Data-driven crafting at one workbench with a small useful recipe set; persistent jobs | Commission (I007) |
| GD-26 | Forgiving hunger with one scavenged food, one repeatable food production method and one way to eat | Commission (I007) |
| GD-27 | Progression through capabilities (tools, weapons, defences, food security, unlocks) — no XP, levels or currencies | Commission (I007) |
| GD-28 | A regional threat that responds to player activity, with quiet periods and recovery, never omniscient zombies | Commission (I008) |
| GD-29 | One configurable base-threatening defence event with cause, warning, real zombies, damage and a defined end; no fixed horde schedule; no forced house/bunker invasion | Commission (I008) |
| GD-30 | A day/night cycle and one weather condition on the shared clock that affect atmosphere and play | Commission (I008) |
| GD-31 | One additional small point of interest with scavenging, risk and a useful discovery; map integration; no fast travel | Commission (I008) |
| GD-32 | One recruitable persistent survivor who lives in the bunker and does two useful jobs with real resources; light settlement overview | Commission (I009) |

### Red Thaw (iteration 010)

| ID | Decision | Source |
|---|---|---|
| RD-01 | Nuclear-winter survival setting in a northern pine wilderness; civilisation has collapsed | Red Thaw commission |
| RD-02 | Human madness instead of zombies: the hostiles are surviving people, notably the Burnt Ones. They stay human in presentation (no demons, no supernatural) | Red Thaw commission |
| RD-03 | *Red Thaw* is the working title. It is shown in the window, menu, build label and documentation. The repository, project folder and save ids are not renamed | Red Thaw commission |
| RD-04 | Opening: you wake on the forest floor by a burned shed with a small bag: one large bottle of water, a pack of crackers and a field map. No tools, weapons or bunker, and no cinematic or exposition. Joining players get their own kit, and shared loot is never duplicated | Red Thaw commission |
| RD-05 | Winter / pine-forest visual direction in the dirty-ink style (see visual register RT-xx) | Red Thaw commission |
| RD-06 | The farmhouse is presented as a remote **hunter's cabin**. Its gameplay (entry, hatch, ladder, bunker, excavation, construction) is unchanged, and so is the protected boundary | Red Thaw commission |
| RD-07 | One small abandoned settlement with intermittent, spatial, daytime laughter. No source is ever shown, and investigating reveals nothing | Red Thaw commission |
| RD-08 | Occasional night-time human silhouettes. They are atmospheric, not encounters, and are coherent for nearby players without synchronised camera effects | Red Thaw commission |
| RD-09 | One frightened, persistent, non-hostile survivor huddled in a sheltered corner. She trembles, mutters and gives short fragmented lines, with no explanation of the catastrophe. The existing NPC architecture (and recruitment) is reused | Red Thaw commission |
| RD-10 | The existing bunker, survival, construction, crafting, infrastructure, multiplayer, persistence and map systems are preserved | Red Thaw commission |
| RD-11 | One Burnt One can detect, pursue, navigate, attack, lose and reacquire a target, consistently in multiplayer under host authority. What starts a hunt is undecided: there is only a developer trigger plus diagnostics | Red Thaw commission |

### The World Awakens (iteration 011)

| ID | Decision | Source |
|---|---|---|
| WD-01 | Burnt Ones walk upright, crouch and crawl (with bursts), differ individually, listen and screech; a screech alerts a few others, with cooldowns, a responder limit and no chains; restrained signs (tracks, blood, snow), no blood-tracking simulation | World Awakens commission (A) |
| WD-02 | Simple, persistent, host-authoritative cold exposure with clothing, shelters and heat sources, warnings and mild penalties | World Awakens commission (B) |
| WD-03 | Dynamic shared weather: fog, heavy rain, blizzards, thunderstorms with lightning (no lightning damage) and calm periods; regional variation | World Awakens commission (B) |
| WD-04 | Communal sleeping: immediate alone; in multiplayer everyone in the same shelter and a unanimous vote; an inner monologue from real events when someone is outside; sleep advances the real simulation | World Awakens commission (B) |
| WD-05 | One drivable station wagon, key in the ignition (no repair or fuel quest); driver and passengers in multiplayer; persistent; extensible for keys and locks | World Awakens commission (C) |
| WD-06 | Hybrid regional world: road exits with defined connections and entry points; the vehicle, its occupants and cargo transfer together; prepared for 4–5 settlements; no fast travel | World Awakens commission (C) |
| WD-07 | One new major settlement (Ashgrove) with grocery, clothing, hardware, pharmacy, garage and houses, type-matched loot and scavenged-empty spots; one house with an upgradeable basement base | World Awakens commission (C) |
| WD-08 | Non-aggressive wolves and bears; interactable highlighting; corrected held-weapon alignment; a toggleable flashlight without batteries | World Awakens commission (D) |
| WD-09 | Selected clips from the creator's audio inbox are used through the replacement system; a client-local "Use custom graphics" switch | World Awakens commission (E) |

### Shadows & Depth (iteration 012)

| ID | Decision | Source |
|---|---|---|
| SD-01 | Burnt Ones remain unidentified silhouettes in ordinary play: light may reveal outline, posture and movement, never their full appearance; distinct silhouettes per variation; no enemy indicators; full reveal only in developer debug | Shadows & Depth commission (1) |
| SD-02 | Frozen blood in Burnt Ones' clothing thaws near real warmth and occasionally drips into small refreezing marks; weather fades, buries and washes them and limits how readable they are; no HUD warnings | Shadows & Depth commission (2) |
| SD-03 | The surface stays top-down; bunker areas use a 2D side view / cross-section on this experimental branch, consuming the same authoritative state, with the original top-down bunker kept and comparable (reversible) | Shadows & Depth commission (3) |

### The Scavenger's Circuit (iteration 013)

| ID | Decision | Source |
|---|---|---|
| SC-01 | Ashgrove's grocery, clothing, hardware, pharmacy and garage plus 2–3 houses are enterable interiors (top-down 3/4; side view stays for bunkers and cellars); one house connects to the cellar | Scavenger's Circuit commission (A) |
| SC-02 | Physical containers searched over time, host-authoritative, location-typed loot, some already empty, never regenerating (re-entry, region change, restart) | Scavenger's Circuit commission (B) |
| SC-03 | Individual skill framework; only Scavenging is active; its only effect is search speed (5 s at level 1, 1.5–2 s at the top, never instant) with diminishing returns; XP only for legitimate first searches | Scavenger's Circuit commission (B) |
| SC-04 | Developer menu in World / Player / Progression categories with a skill XP multiplier (default 1×, 0–25×, applies to new XP for all skills, host only, unavailable in release builds) and grant / set / reset | Scavenger's Circuit commission (C) |
| SC-05 | The trunk is a usable cargo hold (12 slots); at least one shelter improvement needs scavenged materials (wood stove: improved heating) | Scavenger's Circuit commission (C/D) |

### The Five Settlements (iteration 014)

| ID | Decision | Source |
|---|---|---|
| FS-01 | Outdoors stays top-down; every building interior, bunker, cellar and the mine is a side-view cross-section on one shared grid model, with no duplicated world state | Five Settlements commission (A) |
| FS-02 | Construction progress bars are anchored to the object being built, in both views, never duplicated | Five Settlements commission (A) |
| FS-03 | Five settlements on one road network (Ashgrove, Corran Junction, Greyhollow, Stillwater, Port Halden) with real interiors, contextual loot, landmarks and audio; no fast travel; map discovery | Five Settlements commission (B) |
| FS-04 | An explorable, handcrafted mine (no depth limit in the rules) and a four-level building (basement + three floors) | Five Settlements commission (C) |
| FS-05 | The disturbed Burnt One hideout is an approved situational hunt trigger: an ordinary house, 1–2 Burnt Ones, once, persistent, following outside; the cabin and bunker stay safe | Five Settlements commission (D) |
| FS-06 | Firearms through one shared host-authoritative framework (handgun first): rare, ammunition and reloading, loud | Five Settlements commission (D) |
| FS-07 | Time acceleration (pause/1/2/5/10×) is a single-player developer tool only; clients and hosted games can never alter shared time | Five Settlements commission (D) |
| FS-08 | One complete item catalogue (shared ids, no duplicates) and contextual weighted loot pools; firearms rare; some containers empty or junk-only; every item obtainable | Five Settlements commission (E/F) |

## EXPLORING (prototype choices awaiting a creator decision)

### The Five Settlements (iteration 014)

| ID | Topic | Current prototype | Where to tune |
|---|---|---|---|
| WX-21 | Hideout threshold | Disturbance ≥ 0.9 (noise attention adds up; a gunshot is 2.5) | `stillwater.quiet_house.hideout` (`tools/build_settlements.py`) |
| WX-22 | Firearm numbers | Handgun 70 dmg / 8 rds / 640 px; revolver 95 / 6; shotgun 150 over 3 pellets / 4; hunting rifle 160 / 5 / 1000 px; military rifle 85 / 20; falloff 40 % at full range | `content/items.json` (`firearm`), `tools/build_catalogue.py` |
| WX-23 | Gunshot noise | `gunshot` radius 1300, attention 2.5; `gunshot_heavy` 1700, 3.2 | `content/tuning/zombies.json` |
| WX-24 | Stack limits and carrying | 30 base slots, backpack +10; stack limits per item (ammo 20–30, most bulky things 1); weight shown only | `content/items.json` (`stack_limit`, `carry`) |
| WX-25 | Loot weights | 69 pools; empty 5–45 %, junk-only 0–45 %; firearms weights 0.15–3 (armory) | `tools/build_loot_pools.py` |
| WX-26 | Insulation | Sum of everything worn, capped at 0.85 (coat 0.6, padded jacket 0.35, layers 0.02–0.12) | `content/items.json` (`insulation`) |
| WX-27 | Lights | Glow stick 10 min, flare 4 min (used up); lamps never run out | `content/items.json` (`burn_seconds`) |

### The Scavenger's Circuit (iteration 013)

| ID | Topic | Current prototype | Where to tune |
|---|---|---|---|
| WX-16 | Search times | Base seconds: drawer/fridge 4, rack 4.5, shelf/cupboard/medical 5, locker 5.5, crate/garage 6, tool chest 6.5; minimum 1.2 s | `content/tuning/skills.json` (`base_seconds`, `min_seconds`) |
| WX-17 | Scavenging curve | 10 levels; cumulative XP 0/30/75/135/210/300/405/525/660/810; search factor 1.0 → 0.36; XP 12 + 2 per item found (max 5), 6 for an empty container | `content/tuning/skills.json` |
| WX-18 | Ashgrove supplies | 47 containers, 13 already empty; one player searching all of them earns 546 XP = level 8 of 10 (nothing regenerates; two players split it) | `tools/build_interiors.py` (layout specs), then re-run it |
| WX-19 | Wood stove | Scrap metal 3, stovepipe 1, cement 1; +12 warmth per minute on its level; burns nothing | `content/buildables.json` (`stove`), `environment.json` (`stove_per_minute`) |
| WX-20 | Interior mood | Daylight through the front windows follows the clock; backrooms unlit; unheated buildings keep out 65 % of the cold (`shelter` 0.35) | `tools/build_interiors.py` (tint, windows), region `climate.shelter` |

### Shadows & Depth (iteration 012)

| ID | Topic | Current prototype | Where to tune |
|---|---|---|---|
| WX-11 | **Bunker perspective** | Side view is the default on this branch; F7 (developer) switches to the original top-down. Final choice open | `SettingsService.bunker_view()`, `[dev] bunker_view` |
| WX-12 | Silhouette look | Form 0.12, outline 3 px (0.14 in the dark, +0.6 under light); archetypes gaunt / hunched / heavy / limping (±12 %) | `silhouette.gdshader`, `ZombieView.ARCHETYPES` |
| WX-13 | Thaw numbers | Full thaw in 20 s at full warmth, refreeze 55 s; drips above 0.3, ≤ 1 per 5 s, 0.35 × thaw per second; 120 marks max; cabin stove radius 330, engine 170 | `content/tuning/blood.json`, homestead `heat_sources` |
| WX-14 | Weather on marks | Erase per minute: clear/fog 0.07 (fade), snow 0.28, blizzard 0.6 (cover), rain/storm 0.8 (wash); readable range clear 1400, fog 380, blizzard 300 px; sound masking −1 … −9 dB | `content/tuning/blood.json`, `environment.json` (`sound_mask_db`) |
| WX-15 | Side-view movement | Walk 220/320 px/s, one-row steps, step off any ledge, climb ladders and reinforced supports at 150 px/s, rows drawn at 62.5 % height | `SideSection`, `PlayerAvatar` |


### The World Awakens (iteration 011) — numbers and open choices

| ID | Topic | Current prototype | Where to tune |
|---|---|---|---|
| WX-01 | Hearing and screech numbers | Listen at attention ≥ 0.4 for 0.9–1.6 s; screech at ≥ 0.9; 50 s per creature, 14 s per region; at most 3 responders; screech noise radius 680 | `content/tuning/zombies.json` |
| WX-02 | Posture numbers | Crouch 70 %, crawl 80 % speed, bursts ×1.55 for 1.4 s (6 s cooldown, 35 % chance); temperament pace 0.85–1.15 | `content/tuning/zombies.json` |
| WX-03 | Cold numbers | Loss 6/min outside at full exposure; chilled < 40, freezing < 18; 2 health/min down to 25; shelter +10/min, bunker +7, power +18, heater +10; jacket 35 %, winter coat 60 % insulation | `content/tuning/environment.json` (`exposure`), `content/items.json` |
| WX-04 | Weather table | Weights snow .34, fog .24, thunderstorm .15, heavy rain .14, blizzard .13; spells alternate with clear; lightning slot 9 s, chance 40 % in storms | `content/tuning/environment.json` |
| WX-05 | Sleep rules | Sleep from 17:00 to 06:00, wake at 07:00, +35 health; vote lasts 45 s | `content/tuning/environment.json`, `SleepSim` |
| WX-06 | Car handling | 430 px/s top speed, 150 reverse, accel 300, brake 560, coast 240, turn 2.1 rad/s; 4 seats, 12-slot trunk; get out below 45 px/s; engine noise every 3 s (radius 520), start noise 600 | `content/vehicles.json`, `zombies.json` noise |
| WX-07 | Cars and Burnt Ones | Occupants of a closed car are not seen; Burnt Ones do not attack cars (undecided) | `ZombieSim._look` |
| WX-08 | Wildlife | 3 wolves at the homestead, 1 bear at the settlement, 2 wolves + 1 bear around Ashgrove; notice 460–520 px, flee 260–300 px; transient (not saved); no hunting | `content/tuning/wildlife.json` |
| WX-09 | Flashlight availability | One per player from the cabin table; one in the Ashgrove hardware case; no batteries | `homestead_farmhouse.json`, `town.json` |
| WX-10 | Ashgrove loot | Restock 30–50 min for ordinary spots; unique cases (flashlight + hatchet, winter coat); 4 picked-clean spots | `content/regions/town.json` |


| ID | Topic | Current prototype (Red Thaw) | Where to tune |
|---|---|---|---|
| RX-01 | What starts a Burnt One hunt | Undecided. There is no permanent trigger. `dev hunt` / F3 "Start a Burnt One hunt" starts one against the caller. Noise, attention and heat still run and can steer an existing hunter later | `ZombieSim.start_hunt` |
| RX-02 | Hunt behaviour numbers | Spawns about 760 px away (at least 480 px from every player) at an authored map entry. It is told the target position at the start, catches the scent again every 12 s while searching, and gives up after 240 s and walks off. Combat uses the existing Burnt One numbers (GX-02) | `content/tuning/zombies.json` (`hunt_*`) |
| RX-03 | Automatic threat loop | Off by default (`ThreatState.ambient = false`): no base population, noise reinforcements, night/heat wanderers or automatic cabin attacks. `dev ambient 1` restores the old loop for testing | `ThreatState.ambient` |
| RX-04 | Omen frequency | Laughter: a 35 s slot with a 30 % chance, by day only, heard within 650 px of one of six building spots. Shadows: a 45 s slot with a 32 % chance, at night only, a 3.5–6 s walk along one of six authored paths. Both are seeded from the world seed and clock | `content/tuning/omens.json`, region `omens` |
| RX-05 | Frozen blood / thaw motif | Cosmetic only: dried and frozen blood on Burnt One art, one thawed-blood decal in the settlement, and blood soaking the snow under a fallen Burnt One. No temperature, bleeding or tracking system | art only |
| RX-06 | Deeper psychological horror (sanity, hallucination, voices) | Not built | — |
| RX-07 | Starter kit numbers | Large bottle +70 water, crackers +25 food, map never used up. The drink key uses the bottle when there is no clean water | `content/items.json`, homestead `starter_bag` |

### Earlier prototype choices (still valid unless noted)

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

| GX-15 | Construction set and numbers | Barricade tiers 3 wood (120 hp) / 3 metal (260 hp, armour 3) / 2 cement + 1 metal (480 hp, armour 6); door, spike trap (16 dmg/s, slows, wears), crate (20 slots), workbench, planter, rain collector; build 2–4 s; dismantle refunds half | `content/buildables.json` |
| GX-16 | Where you may build | Homestead build zone around the yard; bunker levels on dug cells (one structure per cell; never wall off dug floor); not inside the farmhouse; nothing at the service station | region `build_zones`, `Build` |
| GX-17 | Paying | Your bag first, then shelter storage when you are underground or in the farmhouse; on the open surface only what you carry | `Inv.sources` |
| GX-18 | Hatch upgrade value | Steel hatch (4 metal + 1 cement) lets far less bunker noise reach the surface (leak 0.08 vs 0.3 closed) — i.e. fewer hordes drawn home | `content/tuning/threat.json` |
| GX-19 | Recipes | 9 recipes (bandage, club, hatchet, machete, felling axe [needs the manual], padded jacket, timber frame, spike kit, grow light), 3–12 s | `content/recipes.json` |
| GX-20 | Equipment | Machete 55 dmg; hatchet chop ×2; felling axe chop ×4 +2 wood; jacket −35 % zombie damage; ~120–220 uses before repair | `content/items.json` |
| GX-21 | Hunger | −1.4 per minute; hungry below 25 (no regeneration); at 0, −3 health/min down to 20 | `content/tuning/infrastructure.json` |
| GX-22 | Planter | 1 clean water starts a 150 s crop, needs power while growing, yields 3 potatoes | `content/tuning/farming.json` |
| GX-23 | Threat heat | Heat from noise attention and kills, half-life 10 min, levels 15/40/70 add 1/3/5 roaming zombies; home heat ≥ 55 (after 15 min of play, 25 min cooldown) starts the defence event | `content/tuning/threat.json` |
| GX-24 | Defence event | 60 s warning, horde of 6 (+2 per extra player) for up to 180 s, targets exposed structures and the gate, ends repelled/dispersed | `content/tuning/threat.json` |
| GX-25 | Day/night and weather | 24 min days starting 08:00; night cuts zombie sight to 60 % and adds 2 wanderers; rain spells 3–6 min between 10–18 min clear, rain masks noise (75 %) and fills collectors fast | `content/tuning/environment.json` |
| GX-26 | Service station | Pumps (fuel, 12 min), shop shelves (food, cloth), storeroom (cement), wreck and workshop (metal, electrical parts), a one-time tool locker with the tuned carburetor (halves generator fuel use) and the workshop manual; 5 resident zombies | `content/regions/service_station.json` |

## DEFERRED

| ID | Item | Notes |
|---|---|---|
| RF-01 | Elaborate catastrophe lore; where the Burnt Ones come from | The mystery is intentional |
| RF-02 | Full blood-tracking gameplay (temperature-driven thawing, trails, tracking) | The motif exists only as art (RX-05) |
| RF-03 | Large settlements and factions | The settlement and Ashgrove (iteration 011); the road east is blocked, prepared for 4–5 settlements |
| RF-04 | Narrative campaign | Sandbox only |
| RF-05 | New major biome systems | Pine woods and the settlement only |
| RF-06 | Fast travel, route planning and ambush travel | The map shows and never moves you |
| GF-01 | Zombie visual design and further zombie types | Visual design deferred (VF-01); one placeholder figure exists |
| GF-02 | Rogue AI / drones as an antagonist | Open design question (visual register C-3) |
| GF-03 | Zombies entering the farmhouse or bunker, raids, cave-ins | Defence events stay outside (GD-22); no collapse simulation |
| GF-04 | Cooking, nutrition, sickness, food spoilage | Only simple hunger exists |
| GF-05 | Ranged weapons, item rarities, skill trees | Small fixed equipment set |
| GF-06 | Power wiring, capacity, multiple machine loads | The power model is logical (GX-11) |
| GF-07 | Seasons | Weather kinds and cold exposure exist since iteration 011; no seasons |
| GF-08 | Item icons, drag-and-drop inventory | Text-based inventory panel |
| GF-09 | More regions, biomes, fast travel (incl. ambushes) | Homestead + service station only |
| GF-11 | Lower-level construction gameplay, load-bearing floors | Developer levels only |
| GF-12 | Survivor relationships, morale, schedules, more survivors and jobs | One survivor, two jobs |
| GF-10 | Dedicated server, relay/matchmaking | LAN/IP only |
| WF-01 | Vehicle fuel, damage, repair, keys and locks; more vehicles | One wagon with the key in the ignition (fields reserved) |
| WF-02 | Store interiors in Ashgrove | Stores are searched from the street |
| WF-03 | Hunting, dangerous or persistent wildlife | Wildlife is atmospheric and transient |
| WF-04 | Player-facing "dig down to a new level"; separate floor/ceiling building actions | Levels still come from the developer command (GD-05); floors and ceilings are drawn from the level type |
