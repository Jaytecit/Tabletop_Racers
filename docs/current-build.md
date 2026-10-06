# Current build — 6 October 2026

Game: **(not) THE REAL THING**, application version **2.22.23**. Production entry point: `scenes/app.tscn`. Current course IDs, assignments and eligibility come from `scripts/tracks/content_catalog.gd` and `course_capabilities.gd`; this page describes the inspected build, not new runtime acceptance.

## Courses and modes

Eleven courses are selectable: Roulette Grand Prix, Toys R You, Toys R Asleep, Rusty Nuts Workshop, Moonlight Junk Heap, Firefly BBQ, Nighttime Noodles, Mount Rainier, Topspeed Oval, Bazaar and Town Square. The first seven use Beach Buggy in standard races; the four ROAD courses use Racing Car. Freestyle permits all five classes. Drift uses Drift Car on Bazaar only.

| Mode | Current field/rules | Remaining distinction |
| --- | --- | --- |
| Quick Race / Freestyle | One human plus 0–7 AI; 1–9 laps; four difficulty presets. Nightmare requires at least three AI and retains two designated attackers. | Eight-car Moonlight race accepted by owner on 6 October. Full-catalogue eight-car balance/performance is not established. |
| Tournament | Four cars; saved assigned-class series; three laps; provisional Normal AI; points 10/6/4/2. | Eight-car field, scoring, series state and standings expansion pending. |
| Elimination | 2–4 cars; remove last active at leader lap two and subsequent laps; final survivor wins. | Setup expansion and eight-car acceptance pending. |
| Time Trial | Solo with personal-best ghost and optional locked owner benchmark. | Owner benchmark times and calibrated AI remain pending. |
| Challenge / Time Attack | Solo; per-course five-stage roadmaps. Time Attack extends its countdown at ordered gates. | Provisional non-drift target balance and owner driving acceptance remain pending. |
| Drift Challenge | Solo Bazaar timed drift scoring and roadmap. | Existing evidence must not be read as full cross-course balance. |

Town Square enables Quick Race, Time Trial and Freestyle only. Bazaar is excluded from tournaments; tournament series cover selected other courses, not every eligible course. Capability gates remain authoritative. Casino Cup, other procedural courses, Beach Buggies and the 2D build are retained development content and absent from the production menu.

Retention does not mean every retired build is directly runnable: several old procedural entries and 2D JSON circuits are absent from the active `tracks/` directory. Authoring recipes and historical baselines remain. Restoring retired content is a separate request; the production eleven-course catalogue is unaffected.

## Identity, vehicles and presentation

- Named profiles have custom 1–9-letter names, eight selectable portraits, distinct biographies and palettes. Hardware keyboard and modal gamepad name entry are implemented. Identity and settings are separate from rank and stat-build selection.
- All five vehicle classes are implemented: Beach Buggy, Monster Truck, Racing Car, Drift Car and Speedboat. Derived wheeled GLBs provide independent wheel steering/rolling for four classes; Speedboat is a jet boat. Original models/textures remain source assets.
- The chosen class applies to the field. Earned vehicle upgrades compose on exported base tuning; AI uses neutral tuning plus factory defaults. Freestyle offers explicit underbody flotation/skid fallbacks without permitting unsupported shortcuts.
- Profile schema is 17. Unspent upgrade points and Bling belong to the profile wallet; purchased stats/paint remain per vehicle. Machine display/audio/controller preferences are separate.
- Eight-car identity assignment, rank labels, coloured standings, dot-only minimap, two-row race results and all-car lighting are implemented. Developer overrides/export exist, but individual menu targets currently expose only the first three AI.
- Camera modes are Chase, Overhead and Close Chase. High Chase is the default; road-course bedroom panorama framing uses the current perspective settings. Optional world pixelation and Reduced Effects remain available.
- Contact response and shrink/hidden-transfer/grow recovery are implemented. Finishers currently stop at the line and disable collision; solid run-out/parking is pending.
- The live opening uses `theme-opening.ogv` and the shared full-theme audio mix, with interactive logo cues at 176.433 seconds and successive four-beat intervals. The old 45-second montage is historical. Current audio/video are outside the eight-car change scope.

## Authority and outstanding work

The owner's 5 October update allows development times, ghosts, scores, currencies and rewards to reset/invalidate when useful. Do not build preservation-only migrations for those values. Preserve named identity/preferences, accepted geometry, source assets/notices and failed evidence. Normal saving remains in place; no immediate wipe is requested.

For each newly integrated course, run one Beach Buggy race on Hard; use Freestyle where necessary to preserve the standard assignment. This replaces older vehicle/stat/difficulty matrices and extra mode races. Retain topology, support/height, gate/flag, relevant menu/control/loading checks and process cleanup. Keep untested additional modes disabled.

Current priorities are in [implementation coverage](implementation-checklist.md), with the detailed [eight-car audit](eight-car-experience-audit.md). Raceway is the next proposed course, subject to a separate implementation request and bridge-layer extraction review.

Performance remains a limitation: the tuned Moonlight eight-car full-race wall-frame p95 was 21.768 ms on the development machine, above the 16.7 ms target. Source inspection and successful owner play do not establish universal 60 FPS. See [race evidence](verification/eight-car-race.md) and [CPU tuning](verification/eight-car-tuning.md).

Repository: [Jaytecit/Tabletop_Racers](https://github.com/Jaytecit/Tabletop_Racers). See [repository workflow](repository-workflow.md) for LFS and local-only evidence/media. Historical reports retain their original measurements, settings and failed runs.
