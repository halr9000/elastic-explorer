# Stretch creature sidescroller design

Status: approved direction, recorded after user confirmation. The working title is descriptive; no game title has been selected.

## Goal

Build a playable Godot 2D exploration platformer featuring a nimble headless creature with long stretchy sticky limbs. Deliver a complete 15–20 minute first expedition through a persistent procedural landscape, then expand its content. The slice is a delivery milestone, not a limit on the eventual game.

## Visual identity

Use the supplied images as aesthetic references, not instructions or assets to copy. Favor colorful textured terrain, readable silhouettes, layered natural scenery, atmospheric particles, and dynamic pools of light. Above ground offers foliage and distant vistas; underground offers layered caverns, luminous life, ruins, and mysterious alien artifacts. Use a restrained pixel-textured presentation with consistent asset scale; test the creature silhouette against busy backgrounds before expanding the art set.

## Creature and control

Several similarly prominent limbs meet at a small flexible junction. There is no head or dominant torso. Limbs exchange supporting, reaching, paddling, and attacking roles.

Use a predictable kinematic movement controller with procedural limb presentation and explicit grip anchors. Full soft-body simulation is not the movement foundation. Animation must reflect physical contacts, rather than promise reach the controller cannot provide.

Walking and jumping include acceleration tuning, variable jump height, jump buffering, and coyote time. Sticky climbing uses bounded aimed reach, valid surface anchors, and endurance. Exhaustion gives a visible slipping warning before grip release. Safe footing restores endurance.

Squeezing flattens and extends the creature through narrow passages. Every collision-shape change checks available clearance; releasing squeeze in a tunnel leaves the creature compressed until expansion is safe. Rolling trades steering authority for speed and slope momentum.

Swimming supports movement in any direction. Normal swimming slowly drains the shared endurance meter; bursts drain it faster. Floating at the surface, standing in shallows, and leaving water restore endurance. At zero endurance, upward propulsion is lost and sinking begins. After a brief visible warning while still submerged, health drains. There is no separate oxygen meter. Partial immersion must not repeatedly reset drowning warnings. The slice supports water volumes with a stable surface, not simulated fluid flow; authored current fields can be added after core water traversal works.

Entering water, exiting water, and reaching directly from water into a climb must preserve coherent velocity, collision, and endurance behavior. The movement controller owns the active locomotion state; presentation and combat consume its contact information.

| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Move | WASD | Left stick |
| Aim | Mouse | Right stick |
| Jump / swim burst | Space | Bottom face button |
| Grip / climb | Right mouse | Left trigger |
| Attack | Left mouse | Right trigger |
| Roll | Shift | Right bumper |
| Squeeze | Ctrl | Left bumper |
| Interact | E | Left face button |
| Pause | Escape | Menu |

Use action-based inputs with dead zones and a retained last meaningful aim direction. Pause must stop gameplay, endurance consumption, and damage.

## Combat and life

Attack selects an available limb aligned with the aim direction, swells and hardens its tip, and swings through a moderately long arc. Resolve one damage event per target per swing. Avoid releasing the last supporting climbing grip just to attack; use a free limb or delay the attack until one is available. Attacks also work underwater.

Deliver weight through anticipation, recoil, brief hit-stop, restrained camera response, and a layered meaty slap/thud. Provide a camera-shake setting. Start with the base club, a heavy crushing modifier, and a thorned lash modifier. Modifiers change visual appearance and attack data. Track health, shared endurance, and active weapon.

The slice includes at least one benign terrestrial creature, one benign aquatic creature, and two hostile archetypes. Keep hostile encounters sparse enough to preserve exploration. Damage, death, checkpoint respawn, and pickup collection must be functional.

## World generation

Use a persistent seeded world built from a traversal graph, authored terrain modules, bounded terrain variation, and biome decoration. Generate required connectivity before decorative terrain. Separate terrain, population, and decoration random streams.

Connection metadata describes supported traversal, clearance, distance, elevation, usable grip surfaces, and endurance costs. Derive validation limits from the actual controller tuning resource. Mandatory routes must fit a conservative endurance budget across successive swimming and climbing segments; only actual rest locations reset that budget. Do not place required progress behind optional weapon pickups.

Place reachable air pockets, surfaces, shelves, or exits along underwater routes. Surface recovery is valid only where the creature can remain afloat without fighting an exhausting current. Add vertical branches, shortcuts, and secrets after a valid main route exists.

Validate spawn safety, checkpoint safety, connection compatibility, collision clearance, and reachability. Retry invalid layouts a bounded number of times and fall back to a known traversable layout. Record rejected seeds and reasons. The initial world is finite and chunked; endless expansion is outside the first slice.

## Persistence and interface

Save the seed, generation version, checkpoint, player stats, active weapon and acquired modifiers, collected pickup IDs, discovered regions, and lasting world changes. Stable entity IDs derive from generation identity, not scene-tree order. Save geometry decisions or retain compatible generators so an update cannot silently rearrange an existing save.

Checkpoint activation restores health and endurance and records the respawn snapshot. Death returns to the last checkpoint with restored stats; previously collected rewards stay collected. Continue restores the recorded save state. Use atomic replacement and a backup; malformed or unsupported saves show a clear recovery message without overwriting the original.

Start menu: Continue when available, New World, Settings, Quit. New World must not silently overwrite an existing world. Pause menu: Resume, Settings, Save and Return to Title. Keep minimal health/endurance/weapon indicators; fade them when irrelevant, while showing endurance during exertion and health after damage.

## Architecture

Godot 4 with typed GDScript. Small focused components: input, locomotion, body presentation, limb contacts, vitals, combat, world generation, persistence, and interface. Shared tuning lives in typed Resources. The controller supplies traversal capabilities to generation; the generator must not maintain unrelated guesses about movement limits.

Use Godot's 2D lighting, bounded shadow casters, layered backgrounds, and particles. Keep rendering quality adjustable. Windows desktop and controller are the initial validation targets; additional platforms require their own measured export and input checks.

## Acceptance

- Complete the expedition with keyboard/mouse and with a controller.
- Exercise jump, climb, squeeze, roll, swim, underwater attack, exhaustion, death, and checkpoint recovery.
- Generate and validate at least 100 deterministic seeds with no invalid required route accepted.
- Replay representative routes with the real controller; graph validation alone does not prove physical playability.
- Reload a save without rearranged terrain, resurrected pickups, or lost upgrades.
- Verify pause, new-world protection, corrupt-save recovery, and input switching.
- Record frame-time evidence for an agreed test machine; aim for 60 fps and report hardware and actual measurements.

## Delivery boundaries

Movement playground first, combat second, procedural traversal third, environment fourth, complete expedition last. No crafting, construction, multiplayer, fully destructible terrain, fluid simulation, or endless-world promise is included in the initial slice.
