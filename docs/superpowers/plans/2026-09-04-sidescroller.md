# Stretch Creature Sidescroller Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking. Read the approved design before implementation.

**Goal:** Deliver a complete playable expedition featuring elastic traversal, shared climbing/swimming endurance, directional tendril combat, and a persistent procedural world.

**Architecture:** A typed kinematic controller owns movement and contact state. Procedural limbs express that state; combat uses available limbs. A route-first generator consumes controller capabilities and persistence records stable world changes.

**Tech Stack:** Godot 4, typed GDScript, Godot 2D physics and rendering, headless GDScript test runner.

**Spec:** `../specs/2026-09-04-sidescroller-design.md`

## Global constraints

- Several similarly prominent limbs meet at a small flexible junction. There is no head or dominant torso.
- There is no separate oxygen meter.
- Pause must stop gameplay, endurance consumption, and damage.
- Do not place required progress behind optional weapon pickups.
- Windows desktop and controller are the initial validation targets; additional platforms require their own measured export and input checks.
- Always read existing files before editing. Use typed GDScript and focused components. Run applicable tests after changes.
- Rust and Go checks apply only if those languages are introduced; do not add unrelated toolchains to this Godot project.

## Implementation sequence

### 1. Prove locomotion in a fixed playground

Create `project.godot`, `game/player/player.tscn`, `game/player/player_controller.gd`, `game/player/player_input.gd`, `game/player/movement_config.gd`, `game/player/vitals.gd`, `game/player/limb_rig.gd`, `game/player/grip_solver.gd`, `game/world/water_volume.gd`, and `game/playgrounds/movement.tscn`.

Responsibilities: input translates devices into actions; controller resolves one locomotion state; grip solver validates anchors; limb rig renders contacts and transitions; vitals owns health/endurance; water volumes expose surface height and immersion. Movement tuning exposes the dimensions, speeds, reach, drains, and recovery used by later generation.

- [ ] Pin the installed Godot version in project documentation and add action mappings and a minimal headless test runner at `tests/run_tests.gd`.
- [ ] Build a fixed course containing slopes, gaps, ceilings, narrow tunnels, climbable walls, a pool, a submerged passage, and an exit requiring a swimming-to-climbing transition.
- [ ] Implement walk/jump with buffering and grace time; test maximum jumps using the real controller.
- [ ] Add grip/release, reach limits, endurance drain, warning, and exhaustion release.
- [ ] Add safe squeeze transitions and rolling with slope momentum.
- [ ] Add swim, burst, surface recovery, sinking, delayed health loss, and clean water transitions.
- [ ] Add procedural limb poses and camera tracking without changing physical traversal capabilities.
- [ ] Test held squeeze under a low ceiling, loss of the last grip, partial immersion, zero-endurance water exit, pause during drowning, and repeated device switching.
- [ ] Play the course with both input schemes and record movement tuning before proceeding.

Acceptance: every requested movement mode works in one connected course, without getting trapped by a collision-shape transition. Treat locomotion feel as a review gate before expanding content.

### 2. Add combat, damage, and upgrades

Create `game/combat/attack_controller.gd`, `game/combat/weapon_definition.gd`, `game/combat/hurtbox.gd`, `game/creatures/hostile.tscn`, `game/pickups/weapon_pickup.tscn`, and `game/playgrounds/combat.tscn`.

- [ ] Implement aimed free-limb selection, windup, swing, recovery, and one hit per target per swing.
- [ ] Preserve necessary grip support; verify blocked or unavailable limbs cannot attack through terrain.
- [ ] Implement damage, recoil, temporary hit protection, death signals, and health presentation.
- [ ] Add base club, heavy tip, and thorned lash as typed weapon resources with visibly distinct reach/timing/impact.
- [ ] Add slap audio, brief hit-stop, and adjustable camera shake.
- [ ] Test multiple hurtboxes on one target, multiple targets per swing, an enemy behind a wall, attacks while climbing, and underwater attacks.

Acceptance: all three weapon forms function with both aim devices; damage is predictable and support contacts remain coherent.

### 3. Generate traversable persistent terrain

Create `game/world/generation/world_generator.gd`, `game/world/generation/route_graph.gd`, `game/world/generation/route_validator.gd`, `game/world/generation/traversal_profile.gd`, `game/world/generation/terrain_module.gd`, and `tests/world_generation_test.gd`.

- [ ] Derive the traversal profile from movement tuning and conservative measurements from the fixed course.
- [ ] Build module definitions with compatible exits, collision bounds, rest locations, water data, and traversal requirements.
- [ ] Generate a finite main route between safe spawn and an artifact destination, with surface, cave, and aquatic segments.
- [ ] Validate geometry and accumulated endurance between rests, including consecutive swimming and climbing.
- [ ] Add optional loops, secrets, and population sockets only after required connectivity passes.
- [ ] Split seeded random streams; assign stable IDs; add bounded retries and a known-safe fallback.
- [ ] Validate 100 seeds, identical outputs for repeated seeds, independence from decoration changes, and deterministic failure diagnostics.
- [ ] Traverse representative generated routes with the actual player controller, including near-limit water/climb combinations.

Acceptance: no invalid required route is accepted, and real-controller traversal confirms representative graph predictions.

### 4. Save world progress and checkpoint recovery

Create `game/save/save_service.gd`, `game/save/save_data.gd`, `game/world/checkpoint.tscn`, and `tests/save_test.gd`.

- [ ] Define a versioned save format containing seed, generator version, geometry decisions, stable changes, checkpoint, discoveries, vitals, and weapon state.
- [ ] Implement atomic save replacement and backup restoration, explicitly handling file and parse failures.
- [ ] Implement checkpoint activation, death respawn, and Continue behavior according to the spec.
- [ ] Persist pickup consumption and upgrades without serializing fragile scene-node paths.
- [ ] Test round trips, truncated saves, unsupported versions, backup recovery, no duplicate pickups, and unchanged geometry on reload.

Acceptance: quit/relaunch preserves the expedition, and failed loads preserve the original file and explain recovery.

### 5. Establish the living visual world

Create `game/biomes/surface.tres`, `game/biomes/cave.tres`, `game/environment/parallax_environment.tscn`, `game/creatures/benign_land.tscn`, `game/creatures/benign_water.tscn`, and `game/creatures/second_hostile.tscn`; store original assets under `assets/` with provenance recorded in `assets/README.md`.

- [ ] Produce one representative surface scene and one cave scene using consistent textured art scale and readable creature contrast.
- [ ] Add layered parallax, ambient particles, bounded 2D lights and shadows, and reduced-effects settings.
- [ ] Populate flora and benign terrestrial/aquatic fauna, plus the second hostile archetype.
- [ ] Place ruins and alien artifacts as readable discoveries, using generation sockets that cannot obstruct validated routes.
- [ ] Add environmental and movement audio with separate music/effects volume settings.
- [ ] Check foreground occlusion, underwater aim visibility, lighting cost, and busy-scene frame times on the recorded test machine.

Acceptance: the same slice supports natural surface, cave, and underwater scenery, with readable movement and sparse threats.

### 6. Package a complete expedition

Create `game/ui/start_menu.tscn`, `game/ui/pause_menu.tscn`, `game/ui/hud.tscn`, `game/ui/settings.tscn`, `game/main.tscn`, `export_presets.cfg`, and `docs/testing/first-expedition.md`.

- [ ] Connect New World, Continue, Settings, Quit, Resume, and Save and Return to Title; protect existing worlds from accidental replacement.
- [ ] Add controller focus navigation and minimal fading health/endurance/weapon indicators.
- [ ] Connect a safe opening, traversal discoveries, an artifact destination, and a return/checkpoint route into a 15–20-minute expedition.
- [ ] Run headless tests and a project import/parse check; export a Windows build and launch that build.
- [ ] Play through with keyboard/mouse and controller, including death, pause, exhaustion, weapon pickups, save/quit/continue, and the artifact destination.
- [ ] Record seed, Godot version, export identity, test-machine specifications, frame times, playthrough evidence, and remaining limitations.

Acceptance: a launchable build completes the full loop; documentation or editor-only checks do not count as delivery.

## Verification commands

After the project and test runner exist, run from the project root:

```powershell
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/run_tests.gd
```

The test runner must exit nonzero on failure. Use automated checks for endurance accounting, attack hit deduplication, generation determinism/reachability, and persistence. Use real play for controller comfort, animation, impact audio, and route traversal. Pin export templates to the engine version before producing the Windows build.

## Status

Planning complete. No game implementation, project initialization, or runtime tests have been performed yet.
