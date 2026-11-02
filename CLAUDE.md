# CLAUDE.md — ZombieSurvival2D

Single source of permanent project rules. Full design context: `docs/HANDOVER.md`.

## Status
Pre-production. No game code exists yet. Do not implement anything that has not been
explicitly approved as an assignment by the creator. Brainstorms are not feature requests.

## Stack
Godot + GDScript (exact version to be confirmed and recorded here when the project is created).
Creator tests on Windows: GitHub → branch → Download ZIP → open `project.godot` → run.

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
- Gameplay perspective and surface/bunker presentation are undecided. Zombie design is deferred.

## Workflow
- Small fixes stay small. Major iterations: verify base branch + SHA, numbered iteration
  branch, meaningful commits, relevant tests, docs updated, verified push.
- Never force-push or rewrite release references.
- Reports distinguish: Proposed / Implemented / Tested / Remotely verified / Deferred /
  Known limitation / Windows acceptance pending. Never claim completion from source alone,
  and never claim multiplayer works merely because two clients connect.
