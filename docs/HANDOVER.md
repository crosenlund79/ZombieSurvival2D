# Project Handover — 2D Zombie Survival & Bunker Management

**Little Captain's Hat — Architecture, Systems & Development Knowledge Transfer**

- **Document type:** Comprehensive project inception and technical handover
- **Source project:** ⭐⛵ Little Captain's Hat (LCH), including Next Harbor, Between Horizons and Real Horizon development
- **Destination:** New ChatGPT project and game-development thread
- **Status:** Foundational requirements and design intentions — **not an implementation commission**

> This file is the creator's handover, stored verbatim in substance as project context.
> It describes intentions and inherited lessons. It does **not** mean any system below exists in this repository.

---

## 1. The new game

### 1.1 Vision

We are beginning a new dream game.

The ambition is to combine the appeal of 7 Days to Die, reimagined in 2D, with a meaningful underground bunker-management game.

The player should experience the dangerous world above ground while developing a place of refuge and long-term survival below it.

Potential gameplay directions include:

- Exploring a post-apocalyptic world.
- Encountering zombies and other dangers.
- Scavenging buildings and abandoned locations.
- Gathering resources.
- Crafting and constructing.
- Improving weapons and equipment.
- Fortifying structures.
- Developing underground bunkers.
- Operating machinery and infrastructure.
- Managing food, water and supplies.
- Encountering or recruiting survivors.
- Defending against attacks.
- Cooperating with other human players.

These are candidate mechanics, not a finalized design specification.

The defining ambition is the relationship between surface survival and underground management. **The bunker should matter to expeditions. Expeditions should matter to the bunker.**

We do not yet know how much direct control, automation, management, combat or simulation complexity each part should contain. That is for the new design thread to establish.

### 1.2 Confirmed requirements

- **2D presentation.** The exact perspective (top-down, side-on, angled or hybrid) is not yet decided.
- **Multiplayer.** A required part of the game, not a speculative future feature. The foundation must support cooperating players and a persistent shared world.
- **Godot development.** Godot with GDScript, continuing the established workflow. Confirm the exact engine version when the project begins.
- **Creator-controlled audiovisual assets.** Placeholder graphics and sounds must be replaceable without modifying gameplay code.
- **Persistent progression.** The world and its important changes must survive saving, loading and restarting.
- **Creative freedom.** A personal passion project. Commercial release and profitability are not primary objectives. We value experimentation, satisfying gameplay and the joy of making an idea real.

### 1.3 The experience we want to discover

> **Danger above. Security below. But security must be earned and can be threatened.**

Surface exploration could create tension, risk and discovery. The bunker could provide relief, ownership, planning and satisfying improvement. Eventually, the two experiences should form a cycle worth repeating.

Do not force this interpretation into a rigid design before discussing alternatives. The game should not become a collection of chores merely because survival and management systems permit them.

## 2. What we learned from Little Captain's Hat

LCH developed from a relatively small Godot sailing project into a substantial interconnected simulation. It established useful approaches to: authoritative game state; centralized simulation time; scene transitions; contextual interactions; persistent save files and migrations; audio routing and sound management; replaceable artwork; data-driven content; environmental simulation; equipment condition; companion behaviour; achievements and event history; settings and UI scaling; localization; diagnostics; automated tests; developer documentation; GitHub release management; human acceptance testing.

Some were verified directly in project architecture documentation. Others were reported as delivered in development reports. A historical LCH assignment does not, by itself, prove that its corresponding implementation was completed.

Three categories of inherited knowledge must remain distinct:

- **Established LCH patterns:** architecture and workflows documented or reported as implemented.
- **Adapted patterns:** existing approaches that require changes to work with survival, construction, bunkers or multiplayer.
- **New requirements:** systems LCH did not necessarily contain, such as multiplayer networking and persistent destructible world regions.

We are not copying the LCH source tree. We reuse its best engineering and design decisions.

## 3. Architectural principles

### 3.1 State must not live inside presentation scenes

**Game state lives in plain data. Scenes display it and request changes.** LCH used `GameSession` and `SessionState` rather than depending on the currently displayed scene. Adopt this.

The survival world must remain coherent whether a player is exploring a building, fighting zombies, crafting, inside the bunker, viewing a management interface, transitioning between areas, or temporarily disconnected. Deleting or changing a visual scene must not delete authoritative world state.

### 3.2 One owner for each responsibility

LCH's documented services included `GameSession`, `Simulation`, `SaveManager`, `SettingsManager`, `AudioManager` and `SessionLog`. Adopt equivalent responsibilities where appropriate. Avoid duplicate managers maintaining separate versions of inventory, time, resources or character state. Use clear ownership boundaries and signals/events. Do not create an autoload for every minor concept.

### 3.3 Separate simulation and presentation

A zombie animation does not decide whether the zombie has attacked. A wall sprite does not determine structural strength. A fuel-gauge animation does not determine fuel consumption. Presentation reflects authoritative data — especially important when multiplayer clients render the same state differently.

### 3.4 Build the foundation without overengineering

Do not create elaborate universal frameworks merely because they might be useful years later. Build small, understandable foundations with clear extension points. The objective is maintainability, not maximum abstraction.

## 4. Multiplayer — a foundational requirement

LCH was principally single-player. Its authoritative-state principles transfer well; its single-player implementation must not be copied unchanged.

### 4.1 Authoritative simulation

Design initially around **host-authoritative cooperative multiplayer**. The host owns authoritative gameplay state; other players request actions and receive validated outcomes — taking items, building, damaging zombies, repairing, consuming resources, opening shared containers, operating bunker machinery.

Clients may predict local presentation and movement but must not independently commit authoritative shared-world changes. Select precise Godot networking APIs and transport once the engine version and connectivity requirements are confirmed.

### 4.2 Independent player activity

Players must not be required to remain in the same room or scene (one scavenging, one underground, two in different locations, one building while another fights, different interfaces open). World simulation and persistence must not depend on which scene the host has on screen.

### 4.3 Network lifecycle

Plan for: hosting, joining, spawning and identity, ownership, disconnecting, reconnecting, rejoining an existing world, late-join synchronization, session shutdown, graceful connection failures, compatible game versions and content definitions. The first prototype need not implement a complete online service, but the architecture must not prevent these.

### 4.4 World synchronization

- **Authoritative changes:** building placement, damage, inventories, resource totals, world time, zombie state, construction progress.
- **Replicated presentation:** animation, particles, sounds, local camera effects, nonessential visuals.

Use stable network identifiers for persistent entities. Plan how newly joined players receive the current state of relevant regions. Avoid broadcasting the entire world every frame.

### 4.5 Shared resources and simultaneous actions

Transactions must prevent duplicating items, spending materials twice, looting an emptied container, conflicting construction updates, and repeated rewards after reconnecting. These requirements shape inventory, crafting and construction from their first implementations.

### 4.6 Multiplayer pause and time

LCH could pause its whole tree for a modal. That cannot transfer to a shared session. Local menus ordinarily affect only the local player's input and interface; the shared simulation continues. Sleeping, skipping time, global pausing and accelerated simulation require deliberate multiplayer rules (to be discussed later).

### 4.7 Hosting and persistence

Initial target can be player-hosted co-op, keeping dedicated servers feasible. The authoritative host owns shared-world saving. Represent player-specific and shared-world progression separately where necessary. Clients must never independently overwrite the same world save.

### 4.8 Multiplayer testing

Test with actual concurrent game instances. Scenarios: two players with one container; one building while another watches; one inside the bunker and one outside; disconnect during combat; reconnect after world changes; save and restart a shared game; join after significant construction; host shutdown and recovery. **Do not claim functional multiplayer merely because two clients can connect.**

## 5. The world and its persistence

### 5.1 World representation

Design world data so regions can be loaded, simulated and persisted independently. A chunk-based or similarly partitioned model is a strong candidate, but do not commit to chunk size or terrain representation before perspective and building model are decided.

### 5.2 Permanent world changes

Broken windows, opened doors, looted containers, destroyed walls, constructed defenses, excavated terrain, repaired structures, placed machinery, modified underground rooms. The save system preserves the changes the game actually supports.

### 5.3 World identity and deterministic content

Use stable world seeds. Distinguish generated baseline content from player-created changes. The same world must not regenerate differently after restart. Track persistent entity identities independently of graphics.

### 5.4 Multiple active regions

The server simulates relevant regions by explicit rules; regions without players may use simplified simulation for approved background systems. The bunker must not stop functioning because everyone goes above ground, and an active attack must not vanish because nobody has that scene visible.

### 5.5 Construction and destruction architecture

Construction objects may eventually have: stable type and instance IDs; position and orientation; condition; ownership/permissions; construction state; required materials; collision/occupancy footprint; visual definition; persistent state. Do not assume every tile is destructible until the building model is designed. Separating construction data from art is essential for sprite replacement.

## 6. Unified simulation and game time

One authoritative world clock. Surface and bunker agree about elapsed time. Potential consumers: day/night, zombie activity, resource consumption, crafting, construction, machinery, survivor schedules, environment, defensive events, recovery and injuries. Only approved systems are implemented.

- **6.1 Consistent advancement.** Time-consuming actions advance the same simulation; no free production while another system is paused. Deterministic and testable where practical.
- **6.2 Important events.** One coherent scheduling approach with clear eligibility, timing, identity and persistence. No repeated rewards, duplicated attacks or skipped events across save/load.
- **6.3 Randomness.** Controlled seeds; reproducible for tests and coherent across clients. Never tie important outcomes to render-frame timing.

## 7. Saving, loading and recovery

- **7.1 Architecture.** Versioned schemas, stable identifiers, separate slots/worlds, validation before applying, explicit migrations, safe defaults for new fields, clear error reporting. Serialize independently of scenes; scenes reconstruct presentation from loaded state.
- **7.2 Safe writes.** Temporary save → validate → backup → replace (or equivalent). An interrupted save must not destroy the previous valid world.
- **7.3 Multiplayer saves.** Shared world belongs to the authoritative session; player-owned data separated where appropriate; identities preserved across reconnects; no conflicting client snapshots.
- **7.4 Compatibility.** Don't invalidate old saves unnecessarily. Keep historical save fixtures. Test migrations and restarts. Loading must never grant duplicate loot, resources, rewards or construction.
- **7.5 What must not be saved.** Not the scene tree; not audio/image binaries. Store the stable IDs and state needed to reconstruct the world.

## 8. Visual asset replacement — the Sprite Workshop

LCH's Sprite Workshop reportedly catalogued 202 artworks (124 confirmed replacement pathways, 42 needing adapters, 36 for planning). Its key achievement: the creator replaces artwork without changing GDScript.

### 8.1 Core convention

Placeholder and replacement share the same relative folder structure; the replacement drops the `template_` prefix:

```
assets/templates/characters/zombies/walker/template_idle_01.png
assets/overrides/characters/zombies/walker/idle_01.png
```

### 8.2 Resolution priority

1. Valid external user-installed replacement, if supported.
2. Valid replacement bundled inside the project.
3. Original template asset.
4. Safe diagnostic fallback for genuinely missing required content.

Respect Godot's distinction between editor resources and exported builds: packaged `res://` is not a writable mod directory. If replacements must work in an exported Windows build, provide a documented external override location and runtime file loading. Do not claim exported-build replacement works until tested.

### 8.3 Supported visual content

Eventually: player sprites, zombies, survivors, animation frames, weapons, equipment, items/loot, furniture, building components, bunker machinery, props, UI icons, VFX, backgrounds. Integrate progressively.

### 8.4 Animation replacement

Allow partial replacement (replace 3 of 8 frames; the other 5 keep templates). Preserve timing, frame size, orientation, pivot, layers, collision geometry and gameplay state.

### 8.5 Artwork requirements

~2× source-art resolution where suitable. Document displayed and source dimensions. Preserve aspect ratios. Avoid unnecessarily large textures. Allow piece-by-piece replacement.

### 8.6 Asset manifests

Simple, readable per-category manifests with: stable asset ID, expected relative path, display name, source asset, display size, recommended source size, pivot/origin, transparency, directional views, complexity, replacement readiness, notes. Honest statuses: **READY**, **ADAPTER_REQUIRED**, **REFERENCE_ONLY**. A manifest entry does not mean the replacement path works.

### 8.7 Fallback and validation

Invalid images must not crash gameplay. Validate dimensions, formats, path safety, resource sizes. Cache replacements; never rescan every frame. Document whether restart is needed.

### 8.8 Creator ownership

Never overwrite creator artwork. Treat user-owned assets as protected. Never silently replace approved art with generated material.

## 9. Audio management and replacement

LCH had an AudioManager with bus routing (Master, Music, Ambience, SFX, UI), ambience, named loops, fades and pooled one-shots. Adapt it. The mirrored `template_` audio override system is a **new requirement** unless a reusable implementation is verified.

- **9.1 Folder convention:** `assets/templates/audio/zombies/walker/template_growl_01.wav` → `assets/overrides/audio/zombies/walker/growl_01.wav`.
- **9.2 Categories:** menu music, surface music, combat music, bunker ambience, environmental ambience, zombie vocalizations, weapons, movement/footsteps, construction/repairs, machinery, notifications, UI, voices if introduced.
- **9.3 Playback:** centralized ownership, separate buses, independent volumes, pooled one-shots, named loops, fades, don't restart unchanged ambient loops, proper cleanup, stable sound IDs; 2D spatial playback when useful.
- **9.4 Contextual audio:** e.g. gunshots underground, zombies through bunker walls, generator hum tracking machine state, rain from shelter. Derived from game state and sound rules, not UI logic.
- **9.5 Multiplayer audio:** replicate sound-triggering events, not files. Avoid double playback between prediction and confirmation. Volume is client-local. Audio replacement is cosmetic.
- **9.6 Handling:** WAV/OGG workflows, variant naming, fallbacks for missing audio, test external overrides in exported Windows builds when promised, no external tools required.

## 10. Contextual interaction system

LCH origin: `Interactable`, `InteractionSensor`, interaction priorities and `SceneRouter`. Support doors/gates, loot containers, bodies, workbenches, storage, generators, defensive equipment, medical facilities, survivor conversations, bunker controls, environmental objects.

- **10.1 Focus and targeting:** one clearly focused target; priorities resolve overlaps (storage stays reachable near a survivor; close a door rather than loot nearby; clear machine control areas).
- **10.2 Feedback:** understandable prompts, visible focus indicators, no obscure essential actions.
- **10.3 Multiplayer validation:** local sensor proposes; host validates range, permissions, resources, object state.
- **10.4 Transitions:** must work with independently located players. Do not copy LCH's single-active-world-screen assumption. Player-local presentation transitions; world simulation preserved.

## 11. Survival Chronicle, objectives and progression

LCH origin: Captain's Log, achievements, objectives, renown.

- **11.1 Chronicle:** record meaningful events from authoritative state (first night, first bunker, first dangerous expedition, first horde repelled, first recruit, first loss, major upgrade, section destroyed and rebuilt, long survival). Bounded; no limitless trivia.
- **11.2 Achievements:** stable IDs, data-driven, repeatable vs one-time, no duplicate rewards, personal and shared co-op accomplishments.
- **11.3 Progression philosophy:** no automatic renown/XP/levels/currency. Progression emerges from approved mechanics; don't add an economy without knowing what it improves.

## 12. Environmental simulation and exposure

Potential threats: storms, temperature extremes, contamination, radiation, toxic air, smoke, fire, ventilation, visibility, underground hazards — not all need exist.

- **12.1** Shared authoritative conditions; clients render, never decide.
- **12.2** Pattern: current conditions → accumulated exposure → protection → thresholds → warnings → consequences → recovery. Only where it creates worthwhile gameplay.
- **12.3** Readable and fair; hidden unavoidable punishment is not the default.
- **12.4** Calculations separate from sound, lighting, overlays and animation.

## 13. Equipment, wear, repair and readiness

Potential: weapons, protective gear, generators, doors, defensive machinery, water purification, medical equipment, workstations, power, structural components.

- **13.1** Definitions separate from owned instances (condition, upgrades, functional state).
- **13.2** Maintenance must serve meaningful decisions; no endless trivial repairs.
- **13.3** Readiness (from LCH passage readiness): expedition prep, defensive readiness, missing supplies before an attack, whether a bunker system can function. Prefer information over artificial restrictions.

## 14. Survivors, companions and encounters

Behaviours: resting, working, walking between facilities, reacting to danger, interacting with objects, conversing, encounters.

- **14.1** Persistent state (identity, location, role, condition, relationships) vs presentation state (pose, frame, breathing, reactions). Don't save animation details.
- **14.2** Routines use world time and task states; no independent NPC clocks.
- **14.3** Encounters, rescues and events are possibilities, not mandatory initial content.
- **14.4** NPC authority belongs to the host; clients receive updates.

## 15. Bunker management — special considerations

Possible systems: rooms and construction, storage, production, work assignments, power, food, water, medical care, defenses, survivors, maintenance. Scope undecided.

- **15.1 Connection to surface:** scavenging supplies construction; production improves expedition readiness; defenses respond to surface threats; inhabitants change operations; discoveries unlock possibilities. To evaluate, not compulsory.
- **15.2 No disconnected simulations:** not a separate management game opened as a menu. Same world and progression; interfaces may differ.
- **15.3 No management overload:** not every machine needs a fuel meter; not every survivor needs a psychological model; not every facility needs a five-step routine.

## 16. UI architecture

- **16.1** Interfaces remain dismissible when opening conditions change; transitions don't strand panels; no invisible overlays stealing input.
- **16.2** Local menus don't pause the shared simulation; distinguish player menu from session pause.
- **16.3** Centralized theme.
- **16.4** Multiple resolutions, ultrawide, independent UI scale; no fixed 16:9 assumption.
- **16.5** Immersive in-world interfaces (console, switchboard, lockers, journal, workstations, status displays) where they help — never at the expense of usability.

## 17. Settings and localization

- **17.1 Settings:** centralized ownership; audio, display mode, resolution, UI scale, input mapping, language, accessibility. Separate client-local preferences from shared-world settings.
- **17.2 Localization:** localization-ready. If English and Danish are approved, support both consistently. Translation keys, validated placeholders, terminology conventions. Never mix translated text into persistent IDs.

## 18. Tutorials and player guidance

Lightweight, expandable, teaching actual gameplay (movement, interaction, looting, combat, crafting, construction, bunker operation, defense, co-op). Short contextual guidance, revisitable, not interrupting experienced players. Completion may be player-specific. Tutorials have no authority over world state. Maintain a player-facing guide alongside developer docs.

## 19. The Engine Room — development documentation

- **19.1 English Script Guide:** each relevant script's purpose, dependencies and behaviour.
- **19.2 Danish Script Guide:** equivalent; identifiers and paths unchanged.
- **19.3 Technical Architecture Guide:** project structure, scenes, autoloads, dependency direction, signals/events, state ownership, multiplayer authority, replication boundaries, simulation lifecycle, persistence, asset resolution, audio routing, performance-sensitive systems, testing architecture.
- **19.4 Freshness checking:** lightweight script inventory detecting missing, duplicated, renamed and modified entries. Changes trigger review, not auto-generated misleading docs.
- **19.5 Scope:** no lengthy docs for trivial edits. Source is authoritative.

## 20. GitHub and development workflow

- **20.1** Concise `CLAUDE.md`; a single source of permanent project rules.
- **20.2 Major iterations:** verify integration branch and starting SHA; dedicated numbered iteration branch; meaningful commits; appropriate tests; required docs; verified remote push; immutable completed recovery reference.
- **20.3** Small fixes stay small.
- **20.4** Never casually force-push or rewrite release references. Never report unpushed checkpoints as backups.
- **20.5 Creator testing workflow:** GitHub → select branch → Download ZIP → extract → open `project.godot` → run on Windows.

## 21. Build identity

Development builds show: game version, iteration, build stage, dev/test status, commit identifier where available, save-format version — as a small bottom-right label. No Git required on the player's machine. Screenshots and bug reports traceable to a build.

## 22. Automated testing

- **22.1** Focused suites for small changes.
- **22.2** Broad regression for major iterations and critical shared systems.
- **22.3** Priority areas as the game grows: networking, synchronization, inventory transactions, construction, entity state, time, save/load, migration, interactions, content integrity, art replacement, audio fallback, UI state, performance. No tests for nonexistent systems.
- **22.4** Separate-process restart tests; host restart and client rejoin.
- **22.5** Screenshot/rendered inspection for visible features. Headless passes don't prove usability.
- **22.6** Controlled seeds and time. Investigate flaky tests.

## 23. Black box and diagnostics

Structured, bounded `SessionLog`-style records: session start, world load, join/disconnect, save success/failure, region load/unload, significant errors, invalid transitions, sync warnings, important world events. No per-frame movement logging. Diagnostics observe; they never change the simulation.

## 24. Developer test tools

Developer-only interface as systems appear: spawn zombie, grant items, advance time, teleport, trigger raid, damage structure, repair machinery, inspect inventories/entities/simulation values/sync state. Shared-state commands go through the authoritative host and are not ordinary multiplayer cheats.

## 25. Performance management

Performance Opportunity Register: measured concern, evidence, likely cause, regression risk, possible improvement. Sensitive areas: zombie counts, pathfinding, world generation, active regions, construction, lighting, physics, audio, replication, production, long-session memory, saves. Profile first; separate simulation from rendering cost; focused repairs over speculative rewrites; Linux software-renderer numbers ≠ Windows GPU performance.

## 26. Content integrity

"Harbourmaster's Inspection"-style validation: unique IDs, valid references, missing resources, animation definitions, recipe dependencies, construction definitions, entity definitions, translation keys, asset manifests, save schema compatibility. Report **PASS / WARN / FAIL**. Never delete user assets or fabricate missing content.

## 27. Development and QA roles

- **Creator** — vision, gameplay design, artwork, final acceptance.
- **Atlas (ChatGPT)** — design, architecture, priorities, concise implementation assignments.
- **Monsieur Claude** — implements approved assignments.
- **Skipper** — independent QA, playtesting observations, verification.

Brainstorms are not automatically feature requests.

- **27.1 Prompt discipline:** refined scope, reference conventions, no boilerplate, preserve every approved requirement, concise, don't repeat permanent instructions.
- **27.2 Honest delivery:** distinguish Proposed / Implemented / Tested / Remotely verified / Deferred / Known limitation / Windows acceptance pending. Never claim completion from source alone.
- **27.3 Playtesting:** collect observations without redesigning mid-session; consolidate afterwards into bugs, design preferences and feature ideas.

## 28. Critical decisions still open

- **Perspective:** top-down, side view, angled 2D, other?
- **Bunker representation:** directly explorable, management cutaway, separate scene, hybrid?
- **Multiplayer scale:** initial concurrent player target?
- **Connectivity:** LAN, direct internet, platform integration, other?
- **Cooperative structure:** shared bunker, individual ownership, combination?
- **World model:** hand-designed, procedural, hybrid?
- **Construction model:** tiles, grid blocks, freeform, other?
- **Destruction:** how extensive?
- **Bunker management depth:** player-driven vs automated?
- **Zombie threats:** wandering, periodic attacks, escalation, other?
- **Death and recovery:** respawn and lost items?
- **Atmosphere:** grounded horror, grim survival, stylized adventure, dark humour, mixture?
- **Progression:** equipment-, character-, settlement-driven, combination?

Explore gradually according to impact on the first playable prototype. Not an enormous questionnaire.

## 29. Implementation priorities

Avoid months of general infrastructure before finding the fun.

- **Level A — decide from the beginning:** multiplayer authority, persistent state, shared simulation, world representation, scene and player ownership, asset replacement, save schema, basic interaction, resource identity.
- **Level B — small working implementations** only as the prototype needs. Illustrative technical slice (not an approved design spec): two players connecting; moving independently; one zombie; one lootable container; one simple construction interaction; one underground space; saving and restarting; replacing one sprite and one sound.
- **Level C — introduced when gameplay is approved:** advanced survival, enemy variety, complex construction, full bunker management, recruitment, equipment upgrades, elaborate progression, environmental hazards, extensive crafting, large-scale world generation. Do not implement merely because it appears here.

## 30. Architectural acceptance criteria (future)

- **Multiplayer:** two concurrent instances connect and interact with the same authoritative state.
- **Persistence:** host saves and restarts without losing shared changes.
- **Independent locations:** players can be in different areas.
- **Interactions:** authority-validated, no duplicate resources.
- **World modification:** at least one persistent change synchronized and restored.
- **Visual replacement:** replacing an art file changes the visual without code changes.
- **Audio replacement:** replacing a sound changes audio without changing its trigger.
- **Fallback:** removing optional replacements restores originals.
- **Documentation:** creator understands the architecture and can replace demo assets.
- **Testing:** automated checks and real multiplayer launch tests are distinguished.
- **Recovery:** source committed and available on a verified GitHub branch.

These are future criteria, not a command to implement everything immediately.

## 31. Scope and design philosophy

Complexity should create interesting decisions. Maintenance should not exist merely to consume time. Realism should inspire mechanics, not dictate them. Progression should change what the player can do or how they approach problems. The game should offer a reason to venture outside the bunker and a reason to return. Co-op should allow dividing responsibilities without forcing rigid roles. Preserve room for discovery through playtesting.

## 32. Instructions to the receiving thread

Treat this as project context and foundational direction. Do not assume the new game contains these systems or that LCH sources are accessible. Do not begin implementation merely because this handover describes implementation requirements.

1. Understand the confirmed vision and multiplayer requirement.
2. Preserve the useful LCH architectural lessons.
3. Recognize which gameplay ideas remain undecided.
4. Help establish the core survival/bunker relationship.
5. Identify architectural decisions that must precede the first implementation.
6. Encourage focused experimentation and early playability.
7. Keep future Claude assignments compact and self-contained.

When an implementation assignment is authorized, translate only the approved scope into requirements.

---

## Final project principle

> **Create a world worth exploring, a bunker worth building and a reason to survive together.**

We want LCH's technical reliability adapted to a more demanding multiplayer survival game: replaceable artwork, replaceable audio, persistent worlds, understandable architecture, reliable testing and recoverable development. But those foundations exist to support a game — not to become the game.

*A dangerous world above. A home beneath. A shared struggle to survive.*
