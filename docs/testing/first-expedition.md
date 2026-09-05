# First expedition verification

Engine: Godot 4.7.1 stable official `a13da4feb`, Windows x86-64, GL Compatibility renderer. Matching installed Windows export templates used.

Test machine: AMD Ryzen 5 5600X, NVIDIA GeForce RTX 5070, NVIDIA OpenGL driver 616.64. Viewport 1280 × 720. These observations are local desktop evidence, not a minimum-spec benchmark.

## Automated coverage

Five suites: player, world, combat, save, integration. `tools/test.ps1` runs editor import and tests, checks process exits and error output, and rejects leaked-object warnings. Test logs are local artifacts under `test-results/`.

- Shared climb/swim endurance, surface and shallow recovery, deep-bottom drowning, damage immunity, checkpoint restoration.
- Real physics jump height, faster rolling, safe squeeze expansion, controller aim retained during camera movement.
- 100 deterministic seeds, separated decoration randomness, physical seam and route validation, malformed-layout rejection, persistent geometry round trips.
- Real controller route traversal for seeds 0, 42, and 99: surface slopes, canopy climb, root squeeze passage, and underwater exit.
- Directional damage, terrain occlusion, one hit per target per swing, weapon stats frozen during a swing, hostile stable death IDs, benign wildlife protection.
- Save/load, malformed position rejection, known checkpoint membership, seed consistency, unsupported state rejection, corrupted-primary recovery, malformed-backup preservation.
- Start menu, pause, artifacts, completion at first hearth, upgrade persistence, Continue, compressed tunnel restore with a non-overlapping collider.

## Full scripted route

`tests/expedition_walkthrough.gd` runs an optimized player through seed 42 using the production controller. It moves through the entire world, climbs the canopy branch, swims down to the underwater resonator, squeezes through the root lintel, and returns to the first hearth. Rewards are activated only through proximity and line-of-sight checks. There are no route teleports or direct reward grants.

Observed result: completion true after **204.12 simulation seconds**, final position approximately `(195, 378)`. This is an automated optimal route, not a measured human playthrough. It establishes traversal and objective connectivity; it does not establish a 15–20-minute player experience.

Run it explicitly with:

```powershell
godot --headless --path . --fixed-fps 60 --script res://tests/expedition_walkthrough.gd
```

The normal test suite intentionally uses real-time cadence for audio teardown checks.

## Native rendering and export

The game has been rendered and inspected at its start menu, surface area, and underwater resonator. Native captures are generated from the viewport, not fabricated mockups. The Windows executable uses embedded game data.

After visual batching and warmup, one surface capture measured a median **10.12 ms** and 95th-percentile **13.77 ms** between frames, with the engine reporting **95 FPS**. An earlier native release capture reported median **10.59 ms**, 95th percentile **16.80 ms**, and **88 FPS**. Short stationary captures are smoke checks, not worst-case gameplay benchmarks. Final build identity is recorded by SHA-256 in `builds/build-info.json`.

## Remaining acceptance and limits

- A physical controller and hands-on keyboard/mouse playthrough have not been performed by the agent. Input wiring and simulated physics tests cannot establish comfort.
- Meaty impact audio exists and is synthesized locally; subjective listening and tuning remain unverified.
- The route is currently short when optimized. The 15–20-minute pacing target needs human testing and likely additional traversal/content tuning before it can be accepted.
- The first world is finite, using 20 terrain modules, three resonators, two weapon pickups, surface/cave/aquatic scenery, and four wildlife archetypes. It is an initial playable slice, not a finished commercial game.
- Assets are original procedural vector geometry with texture marks and atmosphere. They follow the references' layering and natural/alien direction; they are not a reproduction of their detailed raster art.
- No network publishing, remote repository push, or additional platform claim was made.
