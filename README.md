# (not) THE REAL THING

A miniature arcade racing game built in Summer Engine. Current application version: **2.22.23**. Open `project.godot` and run `scenes/app.tscn` (F5).

The game has eleven courses, five vehicle classes, eight selectable character identities and named saved profiles. Quick Race and Freestyle support one human with up to seven AI. Tournament and Elimination currently retain four-car limits; their expansion and solid post-finish run-out/parking are pending. Solo modes retain their own rules.

Courses: Roulette Grand Prix, Toys R You, Toys R Asleep, Rusty Nuts Workshop, Moonlight Junk Heap, Firefly BBQ, Nighttime Noodles, Mount Rainier, Topspeed Oval, Bazaar and Town Square. Standard races use the assigned class; Freestyle permits any class. Mode eligibility is course-specific.

Drive with WASD/arrows or a gamepad. Default pad controls: RT/RB accelerates, LT/B brakes/reverses, stick/D-pad steers, A boosts. Enter/Start starts; Escape/Start pauses; R/Y retries; F/X resets; Tab/Select returns to setup; C/right-stick click cycles cameras; M mutes; P toggles world pixelation. Saved mappings and modal profile-name entry can change button behaviour.

## Start here

- [Current build, rules and limitations](docs/current-build.md)
- [Implementation status and remaining work](docs/implementation-checklist.md)
- [Eight-car expansion and finished-car audit](docs/eight-car-experience-audit.md)
- [Documentation index and verification records](docs/README.md)
- [Course catalogue](tracks/README.md) and [authoring](tracks/AUTHORING.md)
- [Repository workflow and Git LFS](docs/repository-workflow.md)

Canonical repository: [Jaytecit/Tabletop_Racers](https://github.com/Jaytecit/Tabletop_Racers). Run `git lfs install` before cloning, then `git lfs pull`. Original game assets and derived resources are versioned; caches, raw local evidence and marketing deliveries are excluded. The repository is not a backup of those local evidence/media directories.

## Project map

| Location | Purpose |
| --- | --- |
| `scenes/app.tscn`, `showcase_3d.tscn` | Application and shared 3D race |
| `scripts/race/`, `scripts/vehicles/`, `scripts/profiles/` | Race, handling, identity and persistence systems |
| `scripts/tracks/`, `tracks/<id>/`, `environments/` | Catalogue, measured routes, scenery/collision and authoring |
| `tracks/GLB Tracks/` | Retained sources and future candidates, not automatically playable |
| `assets/`, `audio/` | Original/derived game assets and source notices |
| `tools/`, `tests/probes/`, `tests/autopilot/` | Extraction, audits and reusable isolated verification |
| `docs/`, `.summer/plans/` | Current guidance, evidence summaries and retained specifications |
| `tests/baselines/`, `tests/evidence/`, `archive/`, `marketing/` | Local evidence, backups and editorial deliveries; see repository exclusions |
| `addons/` | Installed tooling and native extension dependencies |

The 2D build, inactive procedural courses and Casino Cup remain development material at their existing paths. Runtime resource paths and source-specific [credits](docs/credits.md) are preserved. Eight-car development measurements remain above the 16.7 ms p95 target; full-catalogue balance and owner-benchmark AI calibration remain open.
