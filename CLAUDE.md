# CLAUDE.md — ZombieSurvival2D

Single source of permanent project rules. Full design context: `docs/HANDOVER.md`.

## Status
Visible working title **Red Thaw**; latest work is iteration 014 "The Five Settlements" (side-view building
interiors, four new settlements on one road network, the Greyhollow mine, the four-level Stillwater Civic Hall,
the disturbed Burnt One hideout, a firearms framework with the handgun, single-player time controls, a
175-item catalogue with icons and tooltips, contextual weighted loot pools) on `iteration/014-five-settlements`
(recovery branch `backup/pre-five-settlements`), built on iteration 013 "The Scavenger's Circuit" and 012
"Shadows & Depth". Internal project name and save id remain `Aftergrowth`. Systems from iterations 001–013 are
preserved. Windows acceptance pending for 001–014.
Gameplay decision register: `docs/DESIGN_DECISIONS.md` (keep it updated each iteration).
Do not implement anything that has not been explicitly approved as an assignment by the
creator. Brainstorms are not feature requests.

## Mandatory repository verification (every implementation task)
Before modifying any file — including after context compaction or a new session — verify:
local repo path, Git remote (`github.com/crosenlund79/ZombieSurvival2D`), active branch,
`project.godot` name (`Aftergrowth`) and the relevant project files. If anything is wrong,
ambiguous or unverifiable, STOP and ask. Never modify files belonging to another project.

## Stack
Godot **4.7.2 stable**, GDScript, Compatibility renderer, target Windows desktop.
Do not upgrade the engine version silently.
Creator tests on Windows: GitHub → branch → Download ZIP → open `project.godot` → run.
Architecture: `docs/guides/ARCHITECTURE.md`. Tests/launch: `docs/guides/TESTING_AND_LAUNCH.md`.

## Checks before pushing
- `godot --headless --path . --import` (refreshes class cache after new `class_name` scripts)
- `godot --headless --path . res://tests/run_tests.tscn` (unit tests + content check)
- `python3 tools/mp_test.py` when networking, saves, sessions or interactions change
- `python3 tools/check_script_guides.py`; update EN + DA script guides for new/removed scripts

## Architecture rules
- Game state lives in plain data; scenes display it and request changes. Never store
  authoritative state in presentation nodes.
- One owner per responsibility (session, simulation/clock, save, settings, audio, log).
  No duplicate managers; no autoload for every minor concept.
- Multiplayer is host-authoritative. Clients request; the host validates and commits.
  Shared-world changes (items, building, damage, resources) are never committed client-side.
- World simulation must not depend on which scene any player (including the host) is viewing.
- Local menus never pause the shared simulation.
- One authoritative world clock; seeded, reproducible randomness; nothing important tied to frame timing.
- Saves: versioned schema, stable IDs, validate-before-apply, migrations, safe write
  (temp → validate → backup → replace). Never serialize the scene tree or asset binaries.
- Assets: `assets/templates/.../template_<name>` overridden by `assets/overrides/.../<name>`
  (same relative path, prefix removed). Missing/invalid overrides fall back safely. Never
  overwrite creator-owned art or audio.
- Build small, understandable foundations. No speculative frameworks.

## Visual direction
- Source of truth: `docs/visual_direction/` (spec v0.1 + moodboard; README holds the
  APPROVED / EXPLORING / DEFERRED register).
- Adopt palette, hand-drawn non-pixel illustration, lighting contrast and atmosphere.
  Never infer camera perspective, composition, proportions or content from the moodboard.
- Gameplay perspective and surface/bunker presentation are undecided. Red Thaw winter direction and the
  Burnt One concept are APPROVED (register RT-xx); exact Burnt One design is EXPLORING.

## Workflow
- Small fixes stay small. Major iterations: verify base branch + SHA, numbered iteration
  branch, meaningful commits, relevant tests, docs updated, verified push.
- Never force-push or rewrite release references.
- Reports distinguish: Proposed / Implemented / Tested / Remotely verified / Deferred /
  Known limitation / Windows acceptance pending. Never claim completion from source alone,
  and never claim multiplayer works merely because two clients connect.
