# Iteration 002 — A Place to Hide

| Item | Value |
|---|---|
| Base | `iteration/001-foundation` @ `a465382` (latest integrated work; iteration 001 not yet merged into the default branch) |
| Branch | `iteration/002-bunker` |
| Recovery references kept | `backup/pre-visual-prototype` (`20a73668`), `iteration/001-foundation` (`a465382`) — untouched |
| Engine | Godot 4.7.2 stable, Compatibility renderer |
| Save schema | 2 (migration from 1; iteration-001 worlds load) · Network protocol 2 |

## Implemented

**Shelter beneath the farmhouse.** The farmhouse is now enterable: step up to the open front door to get
the doorway prompt, which takes you into a separate interior region. Inside, a `shelter_site` entity
(`homestead.farmhouse.shelter`) starts a timed dig (8 s of shared game time, configurable per site) with a
progress bar. When finished it becomes a wooden floor hatch that opens and closes, with a ladder down.
The site's id is the bunker's persistent identity, so the entrance belongs to that building. Eligibility is
data: any region can declare a `shelter_site` with a `level_template`. Only the farmhouse has one.
A `tier` field ("wood") is stored for future hatch upgrades; no upgrade gameplay exists.

**Level −1.** A freshly dug earthen chamber: exposed soil wall with strata, roots and stones, a rough
floor edge, a ladder up through a lit shaft, lanterns, a shovel and bucket, warm lantern light plus a
small carried light, and underground ambience. Four chalk-marked spots show where timber can go.

**Timber.** Seven surface trees are harvestable `tree` entities. Each press of E is one chop
(0.3 s host cooldown). The felling blow drops the tree with a fall animation and leaves a stump; its wood
(4 for broadleaf, 3 for birch) goes once to whoever landed that blow. Players carry up to 30 wood. Timber
piles (inside the farmhouse and on level −1) deposit everything you carry into the bunker's shared stockpile.

**Reinforcement.** `support_site` entities: unreinforced earth → building (3 s) → timber frame
(reinforced earth). The wood (4) leaves the stockpile in the same host step that starts the build, so it
can never be spent twice. The HUD shows "Reinforced earth n/4". Future excavation can check the
reinforced state. No collapse simulation exists.

**Vertical bunkers.** `BunkerState`: levels keyed by signed depth with no maximum. Each level is a region
created from a template (`bunker_earth`, `bunker_concrete`). Adjacent levels connect through ladders that
every template must contain. Levels load only when someone is in them; nothing is pre-created.

**Developer: Create underground test level** (F3, host only). Adds one concrete level below the deepest
level, enables the ladder down from the level above (shown as a concrete slab with an opening), persists
the change and replicates it. Repeated use gave levels −1 … −5 in testing; existing depths are never
re-created.

**World map (M).** Drawn from the surface region's `map` data (woods, yard, road, driveway, farmhouse,
shed, car, sign) plus live state: standing and felled trees, the shelter and its level count, and every
player's surface position. Players indoors are shown at the building; players underground at the shelter
entrance, with their depth. The map is local per player and never pauses the shared world.

**Multiplayer.** The host owns construction timing, hatch state, bunkers, levels, trees, carried wood,
the stockpile and reinforcement. Region changes move only that player. Each client rebuilds only its own
view, so players can be on the surface and on level −2 at the same time with independent cameras and
interactions.

## Verification

| Kind | Result |
|---|---|
| Unit tests + content check | 30/30 PASS (9 new in `test_bunker.gd`); content check 0 FAIL / 0 WARN, now also checks level templates, portals and scene entity ids |
| Real separate processes (`tools/mp_test.py`) | **124/124 PASS**, including every iteration-001 scenario (no regressions) |
| — `bunker_single` (35 checks) | Full 16-step acceptance sequence: enter, dig, wait, open, descend, explore, climb up, chop ×2, deposit, descend, reinforce ×2, map underground, create −2, descend, create −3/−4/−5, save, quit, restart, everything intact, climb from −2 to −1 |
| — `bunker_multi` (28 checks) | Host builds; late joiner receives bunker and levels; client descends; host chops and deposits while client waits underground; client reinforces while host chops at the same time; stockpile spent exactly once; refusal with empty stockpile; host on the surface while client on −2 with independent control and views; host creates −3 while client is on −2 (client sees the ladder appear live); client dev command refused; save, host quit, restart, client rejoins directly on −2 and descends to −3 |
| Rendered inspection | `docs/screenshots/iteration_002/` inspected. Fixed: rooms cropped by the camera (now framed), map label overlap, and an art-toolkit bug where translucent strokes punched see-through holes (also affected iteration-001 tiles; all generated art regenerated) |
| Windows / exported build | **Not tested — Windows acceptance pending** |

## Known limitations

- Collision is still checked only on the moving player's machine; the host validates speed and distances.
- Portal "go through" vs "open/close" on hatches and doors is decided by how close you stand (smaller
  reach for going through). This works but needs explaining; a second interact key may read better.
- The farmhouse interior is a separate small region, not seamlessly connected to the exterior.
- Developer test levels use one fixed concrete room; the earthen −1 template has four fixed support spots.
- All art and sounds are generated placeholders, replaceable through the manifests.
- Position snapshots are not yet filtered by region (fine at this player count).
