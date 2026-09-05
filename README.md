# Elastic Explorer

A Godot 4.7.1 exploration platformer. Become a small headless creature with sticky, stretching limbs; climb through the canopy, swim beneath luminous roots, and wake three alien resonators before returning to the first hearth.

## Play

Run `builds/ElasticExplorer.exe`, or run `Launch.ps1`. Open `project.godot` in Godot to edit. The Windows release embeds its game data and can run on its own.

Start with **Movement clearing** to practice jumping, rolling, swimming, squeezing, and climbing. **Begin a new world** starts a persistent seeded expedition. Continue restores an existing expedition; starting again archives its files first.

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Move / swim | WASD | Left stick |
| Aim | Mouse | Right stick |
| Jump / swim burst | Space | A |
| Grip / climb | Hold right mouse, aim at surface | Hold LT, aim at surface |
| Tendril attack | Left mouse | RT |
| Roll | Hold Shift | Hold RB |
| Squeeze | Hold Ctrl | Hold LB |
| Interact / checkpoint | E | X |
| Cycle acquired weapons | Q | Y |
| Pause | Esc | Menu |
| Menu navigation | Arrow keys / Enter / mouse | D-pad / A |

Climbing and swimming share endurance. Rest on safe ground or float at the water surface to recover. Exhaustion releases grips or causes sinking; staying submerged without endurance damages health. A deep underwater floor does not count as rest. Checkpoints restore both meters.

Find the heavy tip and thorn lash along the route. Wake the Canopy Bell, Drowned Choir, and Root Memory. The HUD points toward the next sleeping resonator, then back to the starting hearth. Completion leaves the world open for exploration.

## Saves

Windows saves live in `%APPDATA%/ElasticExplorer/`. The primary file is `expedition.json`; `.bak` holds the previous valid state. Terrain geometry is recorded, so Continue does not regenerate a different world. Pickups, defeated enemies, discoveries, weapon state, checkpoint, and completion persist.

New World archives the previous expedition. Damaged originals are preserved when recovering a backup. Settings are separate in `settings.cfg`. Automated tests use separate test filenames and do not touch a real expedition.

## Verify and build

```powershell
./tools/test.ps1
./tools/build.ps1
```

The scripts locate the installed Godot console executable. Pass `-Godot 'C:/path/to/godot_console.exe'` to override. Tests run at real physics cadence; allow roughly 90 seconds. They check real player physics, 100 generated seeds, combat, persistence, and the expedition loop. Both exit codes and engine error output are checked.

Build output includes a SHA-256 manifest. Matching Godot 4.7.1 export templates must be installed. `-SkipTests` on the build script is intended only after the same revision has passed verification.

## Steam Deck

Build the native Linux x86-64 release and deploy through an already paired SteamOS devkit:

```powershell
./tools/build.ps1 -Target SteamDeck
python tools/deploy_deck.py --dry-run
python tools/deploy_deck.py
```

Deployment defaults to the paired Deck at `192.168.2.177`; override with `--host`.
Use `--devkit` to override the installed SteamOSDevkitClient `windows-client` directory.
The script verifies source and artifact hashes, uploads the separate `ElasticExplorer` title,
registers a native Linux Gaming Mode shortcut at 1280×800, and verifies a fresh process.
It preserves saves and other titles. The process guard is adapted from the simsim devkit workflow.
The default gamepad bindings above apply to Deck controls; no keyboard entry is required.
`--capture` runs a temporary sandbox smoke capture; deploy again without that flag to restore normal launch.
Hands-on Deck controls, battery use, and sustained frame times still require playtesting.

## Current delivery

This is a playable first slice with original procedural art and audio. The 15–20-minute duration is a design target, not a measured result. Automated input and physics tests do not establish controller comfort or human playthrough pacing. See `docs/testing/first-expedition.md` for verification evidence and remaining checks.
