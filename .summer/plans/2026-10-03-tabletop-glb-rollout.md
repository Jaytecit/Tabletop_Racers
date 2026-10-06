# Development plan and complete milestone sequence

> Current-status notice — 6 October 2026: this document retains the original specification and dated checkpoints. Its starting-point tables, old menu/class counts and unchecked historical boxes are not current implementation status. Use [current build](../../docs/current-build.md) and [remaining work](../../docs/implementation-checklist.md) before executing any task. All five classes, named profiles, eight portraits, eleven courses and eight-car Quick/Freestyle are implemented. Tournament/Elimination expansion, solid finishers, performance and final balance remain open.
>
> Owner overrides: no preservation-only migrations for development scores/rewards; preserve identity/preferences, accepted geometry, sources/notices and failures. New tracks receive one Beach Buggy race on Hard (Freestyle if assigned class differs), not the old matrices or extra mode runs. Work inline, one course at a time. Audio/video are outside the eight-car work. The original full specification remains in the hash-verified documentation snapshot.

Updated 4 October 2026 to incorporate the current `C:/Users/jayte/Desktop/Requirements.txt`: additional race modes, lower chase camera and scenery investigation, track-loading performance, wheel animation and directional menu navigation. Existing milestones and completion evidence are retained. Work inline, one course at a time. Do not delegate. This record supersedes earlier unchecked milestone plans. The attachment supplies requested outcomes and questions; the user's request authorises updating this plan, not implementing its features. New gates below remain unchecked.

## Current game

| Course | Status / evidence |
|---|---|
| Roulette Grand Prix (`game_table`) | Active procedural course; user explicitly retained it during cleanup |
| Toys R You | User-accepted measured alignment; [record](../../docs/toys-r-you-integration.md), [flags](../../docs/verification/toys_r_you-checkpoint-flags.md) |
| Toys R Asleep | Integrated; [recorded verification](../../docs/verification/toys_r_asleep.md) |
| Rusty Nuts Workshop | Integrated; [recorded verification](../../docs/verification/rusty_nuts_workshop.md) |
| Moonlight Junk Heap | Integrated; [recorded verification](../../docs/verification/moonlight_junk_heap.md) |
| Firefly BBQ | Integrated; [recorded verification](../../docs/verification/firefly_bbq.md) |
| Nighttime Noodles | Integrated; [recorded verification](../../docs/verification/nighttime_noodles.md) |
| Mount Rainier | Integrated from independent asphalt boundaries; [verification](../../docs/verification/mount_rainier.md) |
| Topspeed Oval | Integrated through dedicated-road extraction; [verification](../../docs/verification/topspeed_oval.md) |
| Bazaar | Integrated as ROAD / racing_car; [production selector, stat extremes, profile and loading verification](../../docs/verification/bazaar-registration.md) |
| Town Square | Integrated as ROAD / racing_car for Quick Race, Time Trial and Freestyle; [evidence](../../docs/verification/town_square.md) |

Integration/technical verification is not a new claim of owner acceptance for every course. Read each record's failures and limitations. Checkpoint flags remain enabled; the coloured route overlay is disabled. No permanent generated road edges are requested.

## Preserved and future content

Beach Buggies was removed from play at the user's request. Its source, measurements and evidence remain available; reinstatement requires a new request. The other procedural courses, Casino Cup and 2D game are preserved but absent from the game menu.

Town Square is integrated for Quick Race, Time Trial and Freestyle; [evidence](../../docs/verification/town_square.md). The city/network models need route selection and separate layer/topology, collision and performance review; they are not completed race courses. See the [source survey](../../docs/glb-track-usability-audit.md). The new requirement schedules the remaining GLB candidates in milestone 7 below; historical plans alone do not authorise additional imports.

## Scope and implementation areas

**Goal:** finish the track catalogue and deliver consistent presentation and directional navigation, persistent setup options, balanced player stats, five vehicle types with correct wheel animation, grouped standard races, Freestyle and additional race modes, a usable low chase camera, measured loading improvements and owner-benchmark AI difficulty.

**Architecture:** extend the existing shared race, vehicle definitions, course catalogue and profile persistence. Keep surface/vehicle metadata separate from measured route geometry, and use the same final vehicle stats for player physics, AI and benchmark context. Reuse the main menu's presentation language across race panels.

**Tech stack:** Summer Engine, existing GDScript scenes/resources, source-derived GLB extraction tools and isolated rendered verification.

Implementation entry points (inspect at the relevant milestone; these are responsibilities, not promises of unchanged APIs):

| Area | Existing entry points |
|---|---|
| Presentation and setup | `scenes/app.tscn`, `scripts/race/race_presentation.gd`, `scripts/race/arcade_presentation.gd`, `scripts/race/controls_setup.gd`, `showcase_race.gd` |
| Stats and vehicles | `scripts/vehicles/vehicle_definition.gd`, `scripts/vehicles/arcade_car.gd`, `scripts/vehicles/buggy_visual.gd`, `scripts/race/race_garage.gd`, `scenes/vehicles/` |
| Courses and selection | `scripts/tracks/content_catalog.gd`, `scripts/tracks/selected_course.gd`, `tracks/<id>/`, `environments/` |
| Modes, records and AI | `scripts/race/race_session.gd`, `scripts/race/time_trial.gd`, `scripts/race/race_progress.gd`, `scripts/vehicles/ai_driver.gd` |
| Menu navigation and persistence | `scripts/race/arcade_menu_flow.gd`, `scripts/race/setup_menu.gd`, `scripts/race/player_stats_menu.gd`, `scripts/profile_store.gd` |
| Camera and loading | `scripts/race/race_camera.gd`, `scripts/tracks/selected_course.gd`, `scripts/tracks/content_catalog.gd`, `showcase_race.gd` |
| Verification | `tests/probes/`, `tests/autopilot/`, `tools/run_tabletop_verification.ps1`, `tests/baselines/`, `docs/verification/` |

## Complete milestone sequence

Implementation update, 4 October: the subsequent implementation request authorises work on this scope. [First-course quality evidence](../../docs/verification/toys-r-you-race-quality.md) now covers buggy wheel/body motion, bounded effects, schema-9 reduced effects and the revised low close camera on Toys R You. Cross-course/class acceptance remains open. The [requirements index](../../docs/implementation-checklist.md) also records that current schema-8 vehicle progression supersedes milestone 4's older zero-sum driver allocation; earned upgrades are preserved.

Development started on 4 October 2026. The owner's image now identifies Mount Rainier's timing marking; milestone 1 has passed source and rendered verification. Presentation, Setup and camera implementation are ready for owner testing. See [development verification](../../docs/verification/development-panels-setup-camera.md). Unchecked gates remain pending. Milestone 7 repeats the extraction and acceptance workflow separately for each course.

### 1. Correct Mount Rainier's start/finish alignment

- [x] Locate the model's visible start/finish marking in source/world coordinates and align the gameplay timing plane, grid and associated checkpoint cues to it.
- [x] Preserve the independently measured road boundaries; update route origin/checkpoint ordering only where the corrected timing plane requires it. Record whether old records/ghosts remain comparable before changing their handling.
- [x] Verify crossing direction, no early/double lap counts, full laps and rendered agreement with the visible line; retain before/after evidence in the Mount Rainier verification record.

### 2. Match race panels to the main menu art style

- [x] Apply the main menu's typography, colours, borders, spacing and button treatment to results and in-game text panels, including staging, pause and Time Trial feedback where present. At the owner's request, replace countdown text with top-centred start lights and remove the Recovering panel entirely. Correct course-description spacing and remove cup wins from the selected driver's licence.
- [ ] Verify readability, keyboard/gamepad focus and consistent layout at supported window sizes and with pixelation both enabled and disabled.

### 2a. Make menu navigation follow the visible rows and columns

Files: `scripts/race/arcade_menu_flow.gd`, `scripts/race/arcade_presentation.gd`, `scripts/race/setup_menu.gd`, `scripts/race/player_stats_menu.gd`, `scripts/race/controls_setup.gd`; extend `tests/probes/arcade_menu_flow_verification.gd`.

- [x] Map explicit focus neighbours for each menu and modal. Up/down move between vertically stacked rows; left/right move only within horizontal rows. At horizontal row boundaries, left/right stay in that row and never jump vertically. Single-column controls do not move vertically in response to left/right.
- [x] Preserve focused column where the destination row supports it; otherwise select its nearest valid control. Keep directional value adjustment for sliders/selectors, and ensure one input does not both adjust a value and move focus. Rebuild neighbours when controls become hidden or disabled; restore useful focus after Back and closing modals.
- [ ] Verify every directional transition using keyboard arrows, gamepad D-pad and stick, including held input, row ends, vehicle arrows, driver cards, course controls, Setup and stats. Record focus transitions and rendered evidence; no diagonal jumps or focus escaping a modal.

Implemented and automatically verified on 4 October 2026: [directional navigation evidence](../../docs/verification/menu-navigation.md). All 828 injected keyboard/D-pad/stick transitions pass, with column restoration, held row boundaries, slider adjustment, dynamic display controls, shop state, modal close and results navigation checks. Final run has no runtime errors; all disposable processes exited. Physical controller, additional window/pixelation variants and native popup acceptance remain pending, so the final verification gate stays unchecked.

### 3. Add a persistent setup menu

- [x] Add Setup access from the main menu with master/music/effects volume, mute, available resolution/window-size choices, window/fullscreen mode and the pixelation-filter toggle. Include existing configurable control options where supported.
- [x] Use supported display modes, provide a safe display-change revert path, and persist settings through the existing profile system with sensible defaults for older profiles.
- [ ] Verify apply/revert, restart persistence, audio feedback and agreement between the menu toggle and existing pixelation shortcut.

### 3a. Add camera modes and configurable cycling (owner addition)

- [x] Keep the existing chase view and add overhead and close chase views, as selected by the owner.
- [x] Add a configurable keyboard cycle binding (default C) and gamepad stick-click selection (default right stick click); preserve selected camera mode and retain it through retry.
- [ ] Obtain owner driving feedback on visibility, camera motion and physical gamepad cycling. Rendered checks confirm keyboard cycling, stable transforms, close-chase heading, pause/retry and config persistence.

### 3b. Lower the close chase camera and investigate scenery clipping

Files: `scripts/race/race_camera.gd`, `scenes/app.tscn` camera properties through the editor, and affected environment/material resources only where investigation proves necessary; extend `tests/probes/camera_modes_verification.gd`.

- [ ] Capture the current CLOSE CHASE view on open road and beside tall scenery. Determine whether the apparent cut-through comes from camera intersection, near/far clipping, mesh culling/materials or the existing occluder transparency. Record whether any track-rendering constraint actually prevents the requested angle before recommending a change.
- [ ] Tune lower camera height, shorter trailing distance and a farther horizontal look-ahead for a conventional racing chase view. Evaluate projection and field of view together with pitch; use clearance-aware camera placement against scenery and road surfaces so the camera stays outside geometry while keeping the car and upcoming road visible.
- [ ] Verify tall props, walls, bridges/layers, slopes, tight turns, reverse driving, recovery and boost across representative imported tracks. Check near-plane clipping and distant scenery, camera cycling, retry and persistence. Preserve other camera modes and measured track geometry; obtain owner driving feedback on the revised low view.

### 4. Add balanced per-player stat settings

- [x] Define player-selectable strengths and weaknesses for grip, speed, boost capacity/duration and recovery speed, with a shared stat budget or equivalent bounded tradeoffs rather than an all-max configuration.
- [x] Compose player settings with vehicle base stats, expose the resulting values in player/garage setup, and preserve each player's selection. Explain what each stat changes.
- [ ] Verify that each stat affects gameplay, invalid allocations are rejected, and representative builds have balanced overall capability across the available surface types. Lock baseline tuning before recording reference times.

Implementation and current-buggy verification: [per-driver stats](../../docs/verification/player-stats.md). Neutral handling is preserved; nine representative runs completed cleanly. Final balance and baseline locking remain pending across the five vehicle classes and supported surfaces.

### 5. Deliver all five vehicle types

- [ ] Create distinct buggies, monster trucks, racing cars, drift cars and speedboats, each with visuals, collision, handling and base stats suited to its intended environment.
- [ ] Tune buggy versatility, monster-truck rough-surface capability, racing-car road speed/grip, drift-car controlled sliding and speedboat water handling without making one class universally strongest.
- [ ] Define and implement how every vehicle traverses land/water surfaces in Freestyle, including off-environment speedboats and land vehicles; unrestricted selection must result in a playable race. Document these fallback rules before final tuning.
- [ ] Verify steering, acceleration, braking, boost, collisions, recovery, camera and AI control for each class, including water traversal. Confirm existing routes accommodate vehicle dimensions without altering accepted measurements to hide failures.

### 5a. Animate wheels without body penetration

Files: `scripts/vehicles/buggy_visual.gd`, `scripts/vehicles/arcade_car.gd`, relevant `scenes/vehicles/` visuals and future class definitions.

- [ ] Give wheeled vehicles separate steering and rolling pivots with correctly oriented local axes. Drive roll from signed distance travelled and visual tyre radius; steer front wheels from actual steering input/state. Support reverse travel and pause; reset safely after recovery so teleports do not create an artificial spin.
- [ ] Check tyre/body clearance through full steering and rolling ranges, including any suspension motion. Adjust wheel placement, arches or vehicle body design where needed; recheck collision dimensions and track fit after redesign. Speedboats use their own propulsion visuals rather than road wheels.
- [ ] Verify forward/reverse rolling direction, stationary steering, braking, full lock, boost, pause/retry and recovery in rendered close views. Check every wheeled class before marking it complete; retain clearance and motion evidence without changing handling merely to suit the animation.

### 6. Group tracks and assign standard vehicles

- [ ] Add explicit track type/surface and assigned vehicle metadata. Inspect each course before assigning it; group the selector by meaningful environments such as road, rough terrain, drift-oriented and water.
- [ ] Make standard race setup use the course's assigned vehicle, show that assignment in the menu, and retain Quick Race/Time Trial selection and retired-course fallbacks.
- [ ] Make records and ghosts distinguish mode, vehicle and relevant stat configuration so unlike runs are not silently compared. Preserve historical records with their original context or mark them as legacy.
- [ ] Verify catalogue completeness, selection, vehicle instantiation, switching and record isolation; use the same metadata when adding courses in milestone 7.

### 6a. Measure and improve track-selection loading

Files: `scripts/tracks/selected_course.gd`, `scripts/tracks/content_catalog.gd`, `showcase_race.gd`, `scripts/race/arcade_menu_flow.gd`, affected environment resources; add a focused loading probe under `tests/probes/` and retain timings under `docs/verification/`.

- [ ] Measure selection-to-visible-course and selection-to-race-ready times for a small course and the slowest imported courses. Separate cold first load from warm repeat/switch loads; record hardware, engine/export configuration, resource loading, scene instantiation, collision/setup and first-frame shader costs.
- [x] Compare the same courses on the same hardware in editor/development and release export builds. Answer whether release improves the reported delay using those results; do not assume exporting alone removes runtime loading costs. If an export cannot be tested, leave the release comparison explicitly unverified.
- [x] Optimise measured bottlenecks: remove redundant loads/rebuilds, evaluate bounded resource caching and threaded resource loading, and stage expensive main-thread setup where appropriate. Provide visible loading feedback and prevent duplicate selections or races starting before readiness; safely discard stale loads when switching/backing out.
- [ ] Record before/after cold and warm timings, peak memory and a responsiveness budget based on the baseline. Verify rapid course switching, return-to-menu, failed loads and geometry/collision/checkpoint parity. Include loading regression checks as remaining courses are integrated and confirm the final release comparison before acceptance.

Loading implementation and same-machine release evidence: [course-loading verification](../../docs/verification/course-loading.md). Peak memory and worst-process-gap budgets now pass for the measured largest active course. Initial resource loads still take seconds; shader compilation is included in first presentation rather than isolated as its own GPU timer. New-course regressions remain required.

### 7. Integrate the remaining GLB candidates, one course at a time

5 October: Bazaar is integrated into the production selector as ROAD / racing_car. [Registration evidence](../../docs/verification/bazaar-registration.md) passes starting/full player-stat four-car/three-lap Hard races, support/gates/flags/controls/recovery, actual menu and Time Trial flow, Freestyle switching, profile selection/record round-trip and production development loading budgets. Earlier [projection-cache](../../docs/verification/bazaar-projection-cache.md), [five-class](../../docs/verification/bazaar-vehicle-classes.md) and [loading/menu](../../docs/verification/bazaar-loading-menu.md) evidence and failures remain preserved. The shared 16.7ms racing p95 target is still unmet; fresh release-loading comparison and owner-calibrated balance remain project follow-ups. All disposable processes exited. Town Square is next.

- [ ] Reconcile all 37 surveyed source files / 36 unique hashes with the active and retained catalogue. Integrate each remaining usable unique candidate; keep the Silverstone duplicate as one integration and retain Beach Buggies inactive. Record any candidate that cannot pass a gate with its evidence and remediation rather than silently dropping it or marking it complete.
- [ ] Work through this ordered queue. Each entry gets its own selected route, independent source boundaries/heights, collision, actual checkpoint planes/flags, preview, vehicle/type assignment, attribution and full acceptance evidence before registration:

| Stage | Sequential course queue | Main gate |
|---|---|---|
| 7a | Bazaar and Town Square (integrated) | Dedicated collision-road edges must match the visible road |
| 7b | Raceway; Race Track Map | Select intended road component and preserve bridge/layer separation |
| 7c | 3DS Wuhu Loop; CNR DS Death Rally; Chamonix Alps; Shanghai; Barcelona; Glen Canyon Dam; Lake Como; Montreal; Sunrise Ruins | Resolve disconnected pieces, branches, genuine jumps and mixed surfaces per source |
| 7d | Spa-Francorchamps 1939; Monza 1998; Nurburgring GP 2016; Suzuka 2001; Marina Bay; Silverstone 2024 | Explicit road/layout classification, crossings and rendered performance |
| 7e | Chicken Gun Fruzer City; Cyberpunk; Encampment; Low Poly Room; Pool; Race Game Environment; Chiostro; Free Fire Bermuda | Author a supported closed route where none exists; source permission/attribution and performance review |

- [ ] Evaluate Pool for a water course and speedboat assignment from actual geometry. If no retained source supports a viable water race, provide a supported water course as part of the five-vehicle requirement rather than assigning boats to an unsuitable standard track.
- [ ] Apply the required workflow below to every course. Never substitute a fixed-width screenshot trace, flatten stacked roads, overwrite accepted Toys R You data, add permanent generated road edges or discard failed verification evidence.

### 8. Add Freestyle mode

- [ ] Add Freestyle to the main menu, allowing any of the five vehicles on any playable track, with player stats and existing lap/rival/difficulty options.
- [ ] Apply milestone 5's off-environment handling rules, label the selected combination, and keep Freestyle records/ghosts separate from standard assigned-vehicle records.
- [ ] Verify every track/vehicle combination can load, move, traverse required surfaces, cross checkpoints, recover and finish; inspect rendered examples for all five classes and each surface type.

### 8a. Add Tournament, per-track Challenges and three additional racing modes

Files: `scripts/race/arcade_menu_flow.gd`, `scripts/race/race_session.gd`, `scripts/race/race_progress.gd`, `scripts/race/cup_rules.gd`, `scripts/race/time_trial.gd`, `scripts/profile_store.gd`, `scripts/tracks/content_catalog.gd`. Add focused mode controllers under `scripts/race/` and corresponding probes under `tests/probes/` rather than putting every rule in the shared session.

Tournament and Challenge are requested. The following three additional modes are proposed implementation choices for the requested two or three typical racing modes; Quick Race, existing Time Trial and planned Freestyle remain available and are not counted as new modes.

- [ ] **Tournament:** reuse and audit retained cup rules/profile data without automatically restoring retired Casino Cup content. Provide a selectable series of active courses, points standings, deterministic tie-breaking, next-round progression, final results and saved resume/abandon state. Show series vehicle rules before starting and use assigned vehicles consistently across rounds.
- [ ] **Challenge:** define a persistent achievement set for every playable track, initially covering a valid finish, a clean finish without recovery/missed gates and a target-time medal. Show progress and earned achievements per driver/track; award once from validated race events and persist across restart. Store rule/route/vehicle/stat context, reject invalid runs and review timing targets after balance changes. Owner benchmarks remain owner-only records, separate from challenge target tuning.
- [ ] **Elimination:** eliminate the last active racer at each completed leader lap after the first, ending with one remaining racer. Define deterministic ties, immediate player-elimination results, AI-only completion and retry; expose enough laps/rivals for the selected field.
- [ ] **Time Attack:** offer a solo countdown race with time extensions at ordered checkpoint crossings, distinct from unrestricted Time Trial. Award each extension once per valid crossing/lap; show remaining time and end on expiry or the configured finish. Tune track-specific starting time/extensions from valid runs.
- [ ] **Drift Challenge:** add timed drift scoring on courses whose geometry supports it, using speed, slip angle and sustained controlled movement. End combos on collision/recovery and reject stationary spinning or off-route farming. Show score/combo and course targets; depends on milestone 5's drift-car handling. Label eligible courses explicitly instead of forcing unsuitable tracks into this mode.
- [ ] Integrate mode selection, setup, HUD, pause, results, retry and return flow with milestones 2/2a. Version profile additions with safe defaults; separate mode records and awards by course, vehicle, stats and rules. Preserve older Quick Race/Time Trial records and saved profiles.
- [ ] Verify each mode's win/fail conditions, ties, checkpoint order, pause/time accounting, retry/abandon, persistence and course switching. Verify Tournament resume and duplicate-award prevention, a Challenge set on every playable track, and invalid-run rejection. Retain isolated rendered evidence and regression checks for Quick Race, Time Trial and Freestyle.

Implement the rule framework against stable existing tracks, then extend challenge coverage and tune targets as milestones 5–7 settle. Final mode acceptance requires the complete catalogue and balanced vehicle rules; target times and AI-dependent tournament difficulty must be revisited after milestone 10.

### 9. Capture the owner's track benchmark times

- [ ] Provide a way to record and designate the owner's clean best time for every final playable track using its assigned vehicle and a locked stat/race configuration. Store course/route version, lap count, vehicle, stats and timing alongside each benchmark.
- [ ] Validate completed ordered laps and exclude invalid runs. Retain the previous benchmark when replacing one, and mark benchmarks stale after relevant geometry or balance changes.
- [ ] Obtain the owner's recorded times after milestones 1 and 4–7 are stable. Missing owner times remain explicitly uncalibrated; provisional development times do not count as owner benchmarks.

### 10. Calibrate Easy, Medium and Hard AI

- [ ] Interpret Easy as slightly worse performance (a longer finish time than the owner), Medium as close to the owner's time, and Hard as better performance (a shorter finish time). Use the same lap count and benchmark configuration.
- [ ] Set explicit target margins and acceptable run variance against the recorded owner times before tuning. Adjust driving pace, cornering, boost use and recovery using real vehicle capabilities; verify actual completed race times rather than only changing a speed multiplier.
- [ ] Run repeated isolated races on every track with representative rival counts and record finish-time distributions, completion rates, recoveries and checkpoint validity. Show Easy/Medium/Hard satisfy their target bands without invalid shortcuts.
- [ ] For Freestyle combinations lacking an owner benchmark, use separately labelled provisional tuning; calibrated standard-course claims apply only to the benchmarked vehicle/stat context.

### 11. Complete integrated acceptance

- [ ] Verify the final milestone requirements together: panel styling and directional navigation, persisted setup, revised low chase camera/scenery behaviour, measured release loading, balanced player stats, five vehicles and wheel clearance/animation, grouped assigned courses, all GLB dispositions, Freestyle, Tournament, per-track Challenges, the additional racing modes and benchmarked AI.
- [ ] Run relevant menu/race/Time Trial/Freestyle, controls, pause/retry, course-switching, records/ghost and performance checks; confirm accepted Toys R You measurements and existing procedural course geometry are preserved.
- [ ] Retain raw failures and final evidence, stop each disposable test instance and verify its PID exited, then update course records, documentation and this milestone checklist with actual outcomes and unresolved limitations.

## Requirement coverage and dependencies

| Retained requirements from the earlier plan | Milestone(s) |
|---|---|
| Results and in-game panels match main menu | 2 |
| Balanced strengths/weaknesses per player | 4 |
| Five environment-suited vehicle types | 5 |
| Track grouping and assigned vehicle | 6, 7 |
| Any vehicle/track in Freestyle | 5, 8 |
| Main-menu setup, audio/display and pixelation toggle | 3 |
| Owner best times and three AI difficulty levels | 9, 10 |
| Mount Rainier visual start/finish alignment | 1 |
| Remaining GLB candidates set up and used in game | 7 |

| Current Requirements.txt request (4 October 2026) | Milestone(s) |
|---|---|
| Tournament, per-track achievement Challenges and two or three other typical modes | 8a (three proposed: Elimination, Time Attack, Drift Challenge), 11 |
| Lower, more horizontal, close chase camera with scenery clearance; investigate tall-scenery cut-through | 3b, 11 |
| Long track-selection loads; determine whether release builds improve them | 6a, 7 loading regressions, 11 |
| Correct wheel rolling/steering without body penetration, redesign if necessary | 5, 5a, 11 |
| Up/down follows vertical layout; left/right stays within horizontal rows | 2a, 8a menu integration, 11 |

Benchmark collection depends on final route timing and vehicle/stat balance; AI calibration depends on those owner benchmarks. New route or handling changes after calibration require affected benchmarks and AI results to be revisited. Exact AI margins and cross-surface handling are implementation decisions to make concrete at their milestones, not established requirements from the attachment.

## Required workflow for the next requested course

1. Read the [extraction guide](../../docs/tabletop-track-extraction-guide.md), [accepted baseline](../../docs/toys-r-you-integration.md) and [tool limits](../../tools/tabletop_reference/README.md).
2. Preserve canonical files/hashes. Inventory source primitives, transforms, materials/UVs, legal surface and layers. Choose the appropriate dedicated-road, painted-route or selected-network branch.
3. Extract both boundaries independently with each edge's own height; derive the centreline. Record source-fit resolution/tolerance and every ambiguous-span decision. Candidate output must not overwrite accepted measurements.
4. Rebuild the owned environment, collision, route, preview and attribution. Place flags on actual checkpoint planes with support/clearance review; suppress generated road artwork.
5. Run source/corridor topology, physical support and checkpoint gates, full rendered races, controls, pause/retry, menu/Time Trial and switching. Isolate profile writes/hardware input. Preserve raw failures and inspect actual frames.
6. Stop only the disposable instance and verify its PID exited. Record evidence and limitations before registration. Preserve accepted Toys R You data and existing procedural route geometry.

Current sources, authors and licences are in per-course manifests, adjacent `CREDITS.md` files and the in-game credits dialog. Retain these notices when reorganising files.

## Owner policy override — 5 October 2026

Preservation of development high scores, times, ghosts, rewards, currencies and upgrade progress is not required. Reset/invalidate them when useful instead of spending effort on preservation-only migrations. This supersedes earlier score/reward preservation gates, without requesting an immediate wipe. Named identity/preferences, accepted geometry, source assets/credits and failed evidence remain protected. Timed modes now show remaining time counting down; [current policy and timer verification](2026-10-05-profiles-tuning-tracks-effects.md#development-persistence-policy--owner-update-5-october-2026).

## New-track race verification — owner update, 5 October 2026

For each new track, test one Beach Buggy race on Hard only. Use Freestyle when the standard assigned class differs, without changing that assignment. This replaces prior per-track vehicle, stat-build and difficulty matrices and additional mode race runs. Retain source/corridor topology, height/support, checkpoint/flag, relevant control/menu/loading checks, failure evidence and isolated-process cleanup. Untested additional mode capabilities remain disabled until separately requested.

5 October Town Square checkpoint: production registration and verified source/support/checkpoints/Hard races/menu/profile/loading are complete for Quick Race, Time Trial and Freestyle. Other modes remain disabled; shared frame-tail and release comparison remain open. [Evidence](../../docs/verification/town_square.md). Raceway is next, with explicit bridge-layer review.
