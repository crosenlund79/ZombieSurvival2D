# Iterations 006–009 — A World Worth Surviving (integrated vertical slice)

| Item | Value |
|---|---|
| Base | `iteration/003-survival-slice` @ `19b3330` |
| Branch | `iteration/006-world-worth-surviving` |
| Recovery references | `backup/pre-iteration-006` (`19b3330`), `backup/iteration-006-milestone` (`f12f85d`), `backup/iteration-007-milestone` (`7164b21`), `backup/iteration-008-milestone` (`aa8e50e`), `backup/iteration-009-milestone` (`10d605c`) |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Save schema | 4 (migrations 1→2→3→4; older worlds load) · network protocol 5 |
| Status | Implemented and tested on Linux (unit, real multi-process, rendered). **Windows acceptance pending.** |

Design authority: everything the commission required is listed as APPROVED (GD-19 … GD-32) in
[`../DESIGN_DECISIONS.md`](../DESIGN_DECISIONS.md). Every concrete number and layout chosen to make it
playable is EXPLORING (GX-15 … GX-26). Later mechanics are DEFERRED (GF-03 … GF-12).

## I006 — Build to survive

- **Construction framework** (`Build`, `RegionState.objects`):
  - You choose what to build from a menu (B). A placement preview turns green, or red with the reason.
  - The host validates the placement:
    - build zones on the surface; dug cells underground
    - no overlapping, and nothing next to doors, ladders or machines
    - no structure that would cut off part of the bunker
  - Building is timed. Materials are paid exactly once, from your bag and then from shelter storage when
    you are underground.
  - Structures have persistent ids and are replicated per object. You can repair (R), upgrade and
    dismantle them; dismantling refunds half. Crates keep their contents, and so do ground piles of
    dropped items.
- **Content:**
  - barricade (wood → metal → concrete)
  - reinforced door
  - spike trap
  - storage crate
  - workbench
  - hydroponic planter
  - rain collector
  - timber support (the existing terrain support)
- **Materials:** wood, scrap metal and cement. They come from scavenging: the car, shed and a new
  tractor wreck at home, and later the service station.
- **Hatch upgrade:** wooden to steel. The steel hatch looks different and leaks far less bunker noise to
  the surface, so fewer hordes are drawn home.
- **Condition and repair:** every structure has condition and armour, and damage persists. The yard
  gate is now damageable: when broken it stays open until you repair it.
- **Defence:** zombies break through structures that block their way. Spike traps hurt, slow and wear.
  The protected-farmhouse rule (zombies never enter interiors or the bunker) is unchanged.

## I007 — The survival cycle

- **Inventory:**
  - Stackable items, plus gear with ids and condition.
  - Equip in the hand and body slots; drop, pick up and use (eat, drink, bandage, read).
  - 30 slots; anything that doesn't fit lands in a ground pile.
  - Inventory panel (I).
- **Crafting:** one workbench and 9 data-driven recipes covering:
  - weapons and tools: club, hatchet, machete, felling axe
  - clothing: padded jacket
  - parts: timber frame, spike kit, grow light
  - supplies: bandage

  How jobs work:
  - Jobs are timed and paid when they start.
  - Anyone can collect the result.
  - Jobs survive a save and finish exactly once.
  - The felling axe needs the workshop manual (an unlock shared by the world).
- **Equipment that changes play:**
  - The machete hits harder.
  - The hatchet and felling axe fell trees faster; the felling axe also yields more wood.
  - The padded jacket takes 35 % off zombie hits.
  - Gear wears gently and is repaired at the bench.
- **Food:**
  - Hunger falls slowly. Below 25 there is no regeneration; at 0 health drains down to a floor.
  - Canned food comes from the farmhouse pantry and the station shop.
  - The hydroponic planter grows potatoes from clean water while the bunker has power.
  - Eat with X.

## I008 — A world that reacts

- **Regional threat heat:**
  - Rises with noise and kills, and decays over time.
  - Adds roaming zombies.
  - Noise from inside buildings and the bunker leaks to the surface (the hatch tier matters).
  - Zombies never learn where players are; they only hear noise.
- **Homestead defence event:**
  - Started by heat near home, after a grace period and outside a cooldown.
  - A 60 s warning, then a real horde walks in.
  - The horde goes for exposed structures and the gate, pathing around obstacles.
  - It ends repelled or dispersed; damage persists.
  - An active event resumes once after loading, never duplicated.
- **Day/night and rain:** both run on the shared clock and are the same for every player.
  - Nights are dark, so each player carries a small torch.
  - At night zombie sight is shorter and more zombies roam.
  - Rain masks noise and fills rain collectors.
  - The weather history is seeded, saved and replicated.
- **Service station (new region and art):** reached by following the road east.
  - Supplies: fuel pumps, shop shelves (food, cloth), storeroom (cement), wreck and workshop (metal,
    electrical parts).
  - Five resident zombies.
  - A one-time tool locker: the **tuned carburetor** halves generator fuel use, and the **workshop
    manual** unlocks the felling axe.
- **World map and persistence:** the map shows both regions and the road, with an "unexplored" hint
  until you discover the station. Discoveries, looted spots, damage and upgrades all persist.

## I009 — Life underground

- **Mara, the survivor:** she waits at the service station.
  - Talk to her and hand over 1 canned food and 1 clean water.
  - She walks home and appears in the bunker about a minute of game time later.
  - She moves on the cell grid, idles and rests at night, and shelters during a horde.
- **Jobs:**
  - **water:** fills the purifier from storage and collects the clean water into storage.
  - **farm:** waters the planters from storage and harvests into storage.

  She uses only real resources and machines. When blocked she says why (no power, no dirty or clean
  water, no planter).
- **Upkeep:** once per game day she takes 1 food and 1 clean water from storage. If she gets nothing she
  works at half speed.
- **Settlement overview (N):** shows inhabitants, jobs, status, supplies, power and needs. You can
  assign, change or cancel jobs there or by talking to her.
- **Simulation:** the host simulates her. Clients receive compact rows. Work continues while nobody is
  in the bunker.

## Integration

- **Guidance:** contextual tips (shown once each, can be switched off) and a survival guide (H) with
  every topic and a progress checklist read from the world.
- **HUD:** health, water and food bars; what you hold; eat and drink hints; day, time and weather; area
  threat; a horde banner. Panels for build, inventory, craft, machines and settlement all work the same
  way: they read the world, send requests, and never pause.
- **Developer tools (F3, host only):**
  - world: time, rain
  - threat: heat, start a horde
  - player: hunger
  - materials: a construction kit
  - structures: damage all, repair all
  - survivor: recruit, assign jobs
  - diagnostics: a **problem report** (build, location, systems, recent log) and inspection lines for
    inventory, machines, objects, threat and the survivor
- **Start options:** **Developer Test World** is a prepared world, marked on screen. **New World** is the
  normal game.
- **Balance found while playing the loop:** two trees could not pay for a support plus a workbench. The
  workbench now costs 5 wood + 2 metal.
- **AI fix found during integration:** horde zombies now path around buildings to reach barricades
  instead of giving up.

## Verification

| Kind | Result |
|---|---|
| Unit tests + content check | **89/89 PASS**; 43 new across `test_build` (12), `test_survival_cycle` (10), `test_world_events` (8), `test_settlement` (6) and others updated; content check also validates buildables, recipes, loot items and every translation key used by data |
| Real separate processes (`tools/mp_test.py`) | See the final run in the commit message of the final commit (all scenarios incl. 001–005 regressions) |
| — `slice` (29 checks) | The integrated 19-step loop in one real game with zombies active, ending in a save/quit/resume that keeps everything (dev commands used only to compress waiting, trigger the horde immediately, add timber, and heal as a safety net) |
| — `build_multi` (22) | Concurrent placement, spend once, upgrade/damage/repair seen by both, collision, crates and piles between players, shared-storage builds underground, persistence after restart |
| — `craft_multi` (16) | Concurrent crafting at one bench, collection, drop/pick-up keeping the item identity, needs replication, a crafting job surviving a host restart exactly once |
| — `world_multi` (18) | Shared weather and clock, players in different regions, discovery and unique loot, unlocks for everyone, a horde seen by a remote player, defined outcome, persistence without the event returning |
| — `settlement_multi` (15) | Host recruits remotely, client assigns work, work continues with nobody in the bunker (water conserved), survivor and job persist, no duplicate |
| — `perf_multi` (2) | 27 zombies around two connected players: host simulation ≤ 0.75 ms per frame; client mirrors the horde |
| Rendered screenshots | `docs/screenshots/iteration_006/` (h: construction, i: crafting/inventory/guide, j: station/map/night/horde, k: survivor/settlement/dev world, l: two players) — inspected; fixes from inspection listed in the commit history |
| Windows / exported build | **Not tested — no Windows machine or export templates in the test environment. Windows acceptance pending.** |

## Known limitations

- All art and sound are generated placeholders. Zombie design and the survivor's own art are deferred
  (she is a recoloured player figure).
- Movement collision is only checked on each player's machine. The host validates speed, reach and
  placement.
- Horde zombies that cannot reach any exposed structure mill around the yard; they do not climb or
  breach fences. Fences are permanent scenery.
- On the surface, building is limited to the homestead build zone. The service station cannot be
  fortified.
- There is one survivor with two jobs, one point of interest, one weather type and one defence event
  type.
- The inventory is text-based (no icons or drag-and-drop).
- Zombie rows are sent for all regions; region filtering will matter only at higher player counts.

## Balance concerns (for playtesting)

- **Early timber is tight:** support 4, workbench 5 and hatchet 2 need about three trees. With bare hands
  that is noisy, slow chopping.
- **Defence event:**
  - Home heat 55 with a 15 min grace period may come too early for slow builders, or too late for
    noisy ones.
  - 6 zombies (+2 per extra player) may be too few to threaten concrete barricades.
- **Hunger and thirst together** (−1.4 and −2.5 per minute) may feel like chores in long sessions.
- **Survivor upkeep is cheap:** 1 food and 1 water per 24-minute day. The planter feeds her easily.
- **The carburetor is strong:** halving fuel use makes fuel scavenging rarely urgent afterwards.

## Open design questions

1. Should hordes ever be able to break fences or enter the farmhouse (currently forbidden, GD-22)?
2. Should the service station (or other places) be fortifiable as forward bases?
3. Should survivors have their own needs, or stay on shared settlement upkeep?
4. Day length and the night danger level: is 24 minutes a good rhythm?
5. Which second weather type, if any (storm, fog)?
