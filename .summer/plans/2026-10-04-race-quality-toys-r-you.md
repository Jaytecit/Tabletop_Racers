# Toys R You race quality implementation plan

> Current-status notice — 6 October 2026: this document retains the original specification and dated checkpoints. Its starting-point tables, old menu/class counts and unchecked historical boxes are not current implementation status. Use [current build](../../docs/current-build.md) and [remaining work](../../docs/implementation-checklist.md) before executing any task. All five classes, named profiles, eight portraits, eleven courses and eight-car Quick/Freestyle are implemented. Tournament/Elimination expansion, solid finishers, performance and final balance remain open.
>
> Owner overrides: no preservation-only migrations for development scores/rewards; preserve identity/preferences, accepted geometry, sources/notices and failures. New tracks receive one Beach Buggy race on Hard (Freestyle if assigned class differs), not the old matrices or extra mode runs. Work inline, one course at a time. Audio/video are outside the eight-car work. The original full specification remains in the hash-verified documentation snapshot.

> Execute inline, in order, one course at a time. Mark a step complete only when its implementation and named verification have passed. Preserve intermediate and failed evidence. Do not delegate. This document plans implementation; it does not claim the work below is already implemented.

**Goal:** make a complete Toys R You race deliver the personality, clarity and satisfying impact established by the accepted opening, then carry the proven improvements across the active courses.

**Architecture:** refine the existing vehicle, camera, race presentation and session systems. Keep race rules and physics authoritative; route bounded presentation events through one feedback owner. Separate shared feedback from course-specific scenery and tuning, and extend the existing rendered verification workflow.

**Tech stack:** Summer Engine, typed GDScript, current scenes/resources, existing procedural vehicle visuals and particles, current audio and brand art, isolated rendered probes with read-only profiles and hardware-input isolation.

**Date:** 4 October 2026. **Status:** first-course implementation in progress. Buggy visual motion, bounded feedback, reduced effects, low close camera, message priorities and finish safeguards are implemented with rendered evidence. See [actual outcomes and open gates](../../docs/verification/toys-r-you-race-quality.md) and the [full requirements index](../../docs/implementation-checklist.md). Unchecked acceptance gates below still apply; the wider project is not complete.

## 1. Scope and relationship to existing work

Deliver one finished race experience first: intro → menu → Toys R You selection → grid/countdown → racing → final lap → finish → results → retry/menu. Quick Race is the first acceptance path; Time Trial must remain correct and receives its own presentation checks.

The intended result is a polished playable game in its existing miniature 3D style. The intro's illustrated imagery supplies palette, character and impact references; it does not require replacing the game renderer with illustrated video.

This plan complements the [existing rollout](2026-10-03-tabletop-glb-rollout.md). It does not reset completed milestones or import additional tracks. Five vehicle classes, new modes, broader stat balance, record benchmarks, loading work and new GLB integrations remain owned by that rollout. Where a shared camera, wheel or panel task overlaps, implement it once and link its evidence from both plans.

### Protected decisions

- Preserve the accepted Toys R You model transform, independent boundaries, elevations, route origin, collision and checkpoints. Its 58 sections, 1,392 measured cross-sections and approximately 475.02-unit route remain canonical.
- Preserve the existing handling, vehicle stats, gate/penalty rules, reward rules and record/ghost comparability. Presentation must not alter velocity, lift, traction, timers, recovery or collision shapes.
- Retain CHASE, OVERHEAD and CLOSE CHASE, their selection/persistence and the default orthographic size-14 view. The existing low-camera investigation remains a separate bounded task in the rollout.
- Preserve the 600×400 pixelated world option and crisp HUD; verify with pixelation both on and off.
- Keep imported baked scenery/material identity, numbered checkpoint flags and through-prop labels. Keep the diagnostic route overlay disabled; add no permanent generated road edges.
- Keep the top-centred start lights and the owner's removal of the Recovering panel. Recovery feedback must use the vehicle and a small HUD cue, without reinstating that panel.
- Preserve the accepted opening and its continuous menu-music transition. No extra paid video, music or model generation is required for this plan.
- Preserve Roulette and the inactive procedural content. Never restore retired courses to the menu as part of polish.

### Source of truth

Read [accepted alignment](../../docs/toys-r-you-integration.md), [extraction gates](../../docs/tabletop-track-extraction-guide.md), [checkpoint evidence](../../docs/verification/toys_r_you-checkpoint-flags.md), [reference-tool limits](../../tools/tabletop_reference/README.md), [art direction](../art-bible.md), [current camera/panel work](../../docs/verification/development-panels-setup-camera.md) and [opening implementation](../../docs/opening-sequence.md) at the relevant task.

If a visual defect appears to require route changes, stop that change and diagnose it against the accepted source data. A new centreline fit or fixed-width corridor is not a polish fix.

## 2. Current implementation and file ownership

The game already contains useful systems. Improve these rather than creating parallel versions.

| Area | Existing implementation | Planned responsibility |
|---|---|---|
| App/intro | `scripts/app.gd`, `scripts/race/opening_sequence.gd` | Preserve accepted intro and shared music continuity |
| Race composition | `showcase_race.gd`, `scripts/race/race_presentation.gd` | Instantiate/reset feedback; compose HUD, audio and transitions |
| Rules | `scripts/race/race_session.gd`, `scripts/race/race_progress.gd` | Remain authoritative for phase, ranking, gates, laps and results |
| Vehicles | `scripts/vehicles/arcade_car.gd`, `scripts/vehicles/buggy_visual.gd`, `scenes/vehicles/arcade_car.tscn` | Visual motion and bounded feedback events without physics changes |
| Stats/livery | `scripts/race/race_garage.gd`, `scripts/vehicles/player_stats.gd`, `scripts/vehicles/vehicle_definition.gd` | Preserve driver identity and final composed stats |
| Camera | `scripts/race/race_camera.gd` | Keep base pose/occlusion owner; add isolated cosmetic shake |
| HUD/menu | `scripts/race/arcade_presentation.gd`, `scripts/race/arcade_menu_flow.gd`, `scripts/race/race_minimap.gd` | Shared visual language, readable racing information, focus |
| Start/finish | `scripts/race/start_lights.gd`, `scripts/race/arcade_podium.gd`, `scripts/race/victory_celebration.gd` | Refine existing lights, podium and celebration |
| AI | `scripts/vehicles/ai_driver.gd` | Shared-physics rivals with measured passing/braking decisions |
| Audio/settings | Audio helpers in `scripts/race/race_presentation.gd`, `scripts/race/setup_menu.gd`, `scripts/profile_store.gd` | One mix owner; settings remain authoritative |
| Time Trial | `scripts/race/time_trial.gd` | Preserve PB/ghost validity and mode-specific feedback |
| Course content | `tracks/toys_r_you/`, `environments/tabletop/toys_r_you.tscn` | Reference and integrity checks; no route re-authoring |

New files are limited to:

- `scripts/race/race_feedback.gd`: event throttling, cosmetic shake/flash envelopes and feedback lifecycle. Does not own physics or rank.
- `scripts/vehicles/vehicle_visual_motion.gd`: per-car wheel pivots and cosmetic suspension/body response. Does not own the CharacterBody transform.
- `tests/probes/race_quality_verification.gd`: isolated baseline, event, visual and lifecycle walkthrough.
- `tests/probes/race_quality_ai_verification.gd`: explicitly seeded competition cases and fair-physics checks.
- `tests/fixtures/race_quality_read_only.json`: newer-schema sentinel that activates the existing read-only fallback and current defaults; test settings are applied only in memory.
- `docs/verification/toys-r-you-race-quality.md`: final change/evidence record.

Reuse the existing audio helpers initially. Extract an audio module only if a concrete ownership conflict makes that necessary; do not start with a broad presentation-script rewrite. Edit scenes with the editor's scene tools, not by competing with unsaved scene state.

## 3. Design targets

### Look

Use the canonical logo, portraits, vehicle colours and arcade typography. Make vehicle silhouettes and driver identification readable at driving scale; restrained dark outlines, cream cage details, visible wheel motion and existing ground shadows take priority over adding mesh detail.

Use saturated vehicle accents against the source track's quieter surfaces. Do not recolour the entire imported course, add unrelated household props or cover its roads with effects. Keep the player identifiable by a shape/number cue as well as colour.

### Feedback

Scale feedback to the event: light tyre scrub, a clean boost onset, a weighted landing, a sharper hard collision, an unmistakable final lap and a satisfying finish. Effects should help the player understand the car. Continuous flashing, permanent shake and smoke that hides the next turn fail acceptance.

### Race information

Primary information is position and lap. Secondary information is boost and time. The minimap remains visible without dominating the road. Gate warnings take priority over celebratory messages. Overtake notices use settled authoritative rank, not screen position or car distance alone.

### Competition

Rivals should visibly attempt passes and recover from blocked lines. They use the same vehicle physics and available stat composition as the player. Avoid hidden speed multipliers, teleportation and position-based rubber-banding. Do not add global personality systems before demonstrating useful passing changes on Toys R You.

## 4. Ordered implementation tasks

### Task 0 — Record the playable baseline and protect accepted data

**Files:** create the read-only fixture and `race_quality_verification.gd`; use `tests/probes/toys_live.gd`, existing Toys R You probes and `tools/run_tabletop_verification.ps1` as scaffolding. Evidence root: `tests/baselines/race_quality/toys_r_you/`.

- [ ] Record hashes of `tracks/toys_r_you/measured_route.json`, `tracks/toys_r_you/definition.tres`, `tracks/toys_r_you/entry.tres`, `tracks/toys_r_you/preview.res` and `environments/tabletop/toys_r_you.tscn`. Record hashes of `scenes/vehicles/buggy_definition.tres` and effective neutral stats too.
- [ ] Capture current grid, open straight, tight bend, bridge approach, upper bridge, underpass, boost, landing, ordinary impact, recovery, final lap, finishing and results. Use actual rendered gameplay poses and record route station/layer, camera mode and settings alongside each frame.
- [ ] Record a three-lap Hard race with four cars using explicit per-AI seeds. Capture lap times, impacts, crashes, recoveries, gate penalties and stalls. Distinguish AI-driven reference laps from human driving performance.
- [ ] Measure frame-time samples and effect/node counts in open driving, dense scenery, bridge/underpass and four-car effects. Save warm course-switch time and the exact runtime, GPU, viewport and pixelation settings.
- [ ] List the largest observed quality gaps in the verification record. Historical alignment results are comparison evidence, not a fresh baseline for this implementation.

**Gate:** real frames and machine-readable results exist, the read-only fixture cannot write preferences/rewards/records, hardware input is isolated, and the exact test PID has exited. No gameplay improvement is claimed from this task.

### Task 1 — Establish the shared visual treatment on the first course

**Files:** `scripts/race/arcade_presentation.gd`, `scripts/race/race_garage.gd`, `scripts/vehicles/buggy_visual.gd`; references in `assets/brand/`, `assets/arcade/` and `assets/video/opening/`.

- [ ] Capture a comparison plate using the intro reference, current vehicle close-up and actual size-14 driving frame. Specify palette, dark-outline treatment, cage detail, player/rival cue and HUD hierarchy in the verification record.
- [ ] Reuse existing shared colour/font constants. Reconcile any racing-panel variants through `arcade_presentation.gd`, retaining legible cream/yellow text on dark backgrounds.
- [ ] Improve buggy silhouette and material contrast at the normal camera distance. Give the four existing driver liveries equally readable identification; shared source materials must not be mutated across cars.
- [ ] Use the current vehicle meshes and driver identifiers first. Keep new asset generation out of the implementation budget; document any art limitation as a separate proposed asset task.
- [ ] Compare still and moving frames with pixelation on/off at 720p and 1080p. Check tyres, roll cage, body and cue do not merge into the road or obscure checkpoint flags.

**Gate:** player and rivals remain identifiable on the straight, bend and underpass; course markings and source scenery retain their identity; protected hashes remain unchanged. Obtain owner visual feedback at the first playable checkpoint in Task 4.

### Task 2 — Make the vehicle visibly react without changing handling

**Files:** create `scripts/vehicles/vehicle_visual_motion.gd`; modify `scripts/vehicles/buggy_visual.gd` and `scripts/vehicles/arcade_car.gd`. Modify `scenes/vehicles/arcade_car.tscn` through scene tools only if wheel pivots need correction.

- [ ] Inspect each wheel's actual mesh axis and existing `wheel.rotation.z` animation. Correct the visual pivot/spin axis and add front-wheel steering pivots where needed. This satisfies the overlapping wheel-animation milestone only for the current buggy; other classes remain pending.
- [ ] Derive spin from signed longitudinal travel and the visible tyre radius. Reverse travel reverses spin; a stationary car does not creep. Keep steering, spin and suspension transforms on separate pivots.
- [ ] Replace duplicated cosmetic body/wheel writers with the visual-motion owner. Compose its response with current ground-normal tilt and recovery animation; recovery owns the visual while the car is in a recovery state.
- [ ] Add restrained acceleration/braking pitch, cornering roll and a short landing compression/rebound. Suggested initial bounds: roll ≤0.08 radians, added pitch ≤0.06 radians, suspension displacement ≤0.05 world units, settle within 0.30 seconds. These are visual tuning limits, not suspension physics.
- [ ] On reset, restore recorded local transforms and envelope state. Repeated retry must not accumulate offsets or rotations.

**Gate:** forward/reverse/steering/landing look correct; identical seeded input with visual motion enabled/disabled produces matching physical transforms, velocity, effective stats and race progression within numeric tolerance. No collision shape, collision response or recovery duration changes.

### Task 3 — Give feedback one bounded event owner

**Files:** create `scripts/race/race_feedback.gd`; wire it in `scripts/race/race_presentation.gd` and at existing event points in `scripts/vehicles/arcade_car.gd`. Use current smoke/sparks/debris emitters and `controller.gd` rumble API.

Use this interface contract; implementations must maintain the distinction between one-shot events and continuous vehicle state:

| Planned public method | Required behaviour |
|---|---|
| `configure(race: Node3D) -> void` | Bind existing camera/audio/settings owners and initialize event state |
| `handle_event(kind: StringName, car: CharacterBody3D, strength: float, world_position: Vector3) -> void` | Validate kind/car, clamp strength to 0–1, debounce by racer/kind, dispatch cosmetic responses at the captured position |
| `tick(delta: float) -> void` | Decay envelopes using the gameplay clock; freeze while the race is paused |
| `clear() -> void` | Clear envelopes and owned emitters and restore base presentation state; safe to call repeatedly |
| `diagnostic_state() -> Dictionary` | Return emitted/suppressed event counts by kind, current envelopes, active burst/voice counts and configured capacity |

Implement these methods in this task before integrating consumers; this table defines the API contract rather than claiming a completed implementation.

- [ ] Emit `boost_start` only on the existing `boost_was_on` rising edge. Continuous boost uses the existing state/emitter, not one burst every physics frame.
- [ ] Emit `landing` once at the actual airborne→supported transition. Measure impact strength from the downward lift velocity before the existing code zeroes it. Normal road-height corrections must not trigger landings.
- [ ] Emit `impact` from an accepted side contact, respecting the existing 0.25-second collision cooldown. Use closing speed and contact position; do not emit independently from both the car and race presentation for the same contact.
- [ ] Emit recovery start/end cues from the actual state transitions; keep the authoritative recovery location and timing untouched.
- [ ] Connect existing session phase/lap/finish signals once. Add disconnect/cleanup guards so retry/course switching does not multiply listeners.
- [ ] Use existing per-car emitter capacity. Pool any new one-shot emitters, capped at eight active shared bursts and 512 additional particles total. Reuse/drop the oldest lowest-priority burst at capacity; never allocate an unbounded stream of nodes.
- [ ] Give the player full local feedback. Nearby rivals may contribute bounded particles/audio; distant AI events never shake the player's camera or vibrate their controller.

**Gate:** boost/landing/impact/recovery events have correct counts and intensities in real movement cases. Paused/retrying/finishing cars cannot leave stuck effects. Ten controlled impacts and repeated boosts do not grow node counts after settling.

### Task 4 — Add restrained camera impact and close the first playable checkpoint

**Files:** `scripts/race/race_camera.gd`, `scripts/race/race_feedback.gd`, `scripts/race/setup_menu.gd`, `scripts/profile_store.gd`.

- [ ] Preserve `focus`, `lead`, current base camera placement and occluder transparency logic. Apply a temporary cosmetic offset after base pose calculation; reset it before calculating the next pose, rather than accumulating onto last frame's transform.
- [ ] Start with deterministic decaying shake envelopes: light landing approximately 0.08 units/0.10 seconds; hard impact up to 0.18 units/0.18 seconds. Cap summed motion and avoid rotation/zoom pulses during normal driving. Final values require rendered and owner driving review.
- [ ] Cosmetic shake must not move the camera through nearby props. Clamp the additional offset against local clearance or suppress it when clearance is insufficient. Do not solve an underlying CLOSE CHASE intersection by fading the whole environment.
- [ ] Add a persisted reduced-effects toggle through the existing Setup/profile schema conventions. It disables added shake and flashes and reduces additional burst density. Missing fields in older profiles use the documented normal-effects default. Respect current mute and rumble preferences.
- [ ] Clear offsets/envelopes on retry, menu, camera cycle, recovery reset and course switch. Compare all three camera modes at the bridge/underpass and adjacent tall props.
- [ ] Present a playable Toys R You lap with the baseline comparison frames for owner feedback. Record any requested amplitude/readability changes before extending the same treatment to other courses.

**Gate:** base camera selection and persistence are unchanged; reduced effects work; no camera drift or new geometry intersection occurs; owner feedback on this first playable treatment has been addressed. The broader low-camera investigation is still tracked in the existing rollout.

### Task 5 — Refine countdown and the racing HUD

**Files:** `scripts/race/start_lights.gd`, `scripts/race/arcade_presentation.gd`, `scripts/race/race_presentation.gd`, `scripts/race/race_minimap.gd`.

- [ ] Keep the existing three red lights and green GO stage driven by `RaceSession.Phase.COUNTDOWN`/`RACING`. Add a short bounded scale/glow response to each actual stage change, with one cue per transition. Do not change countdown duration or the moment physics unlocks.
- [ ] Arrange lap and position as the primary compact cluster; give boost a clear bar plus numeric value. Keep timer, minimap and rival order subordinate and in safe areas. Reuse the existing HUD update cadence for ordinary text; critical start/finish transitions use signals.
- [ ] Replace intrusive transient text with a small message queue: gate warning first, final-lap/lap message next, settled overtake last. Never suppress or shorten an active missed-gate deadline to show a celebration.
- [ ] Detect player rank changes using session progress and completed checkpoint order. Require a new rank to remain stable for 0.35 seconds before a short overtake/lost-position cue; impose a 1.5-second notification cooldown to prevent rank jitter spam.
- [ ] Final-lap feedback triggers once per valid lap event. Time Trial shows PB/lap information instead of rival/overtake messaging.
- [ ] Keep the course name/driver introduction brief on staging. Do not reinstate recovery modal text. Protect keyboard/controller focus through pause, results and return to menu.

**Gate:** countdown stages align with actual control unlock; all HUD elements fit 1280×720, 1920×1080 and 1600×720; rank/lap/boost match authoritative data; no duplicate final-lap/overtake messages; gate warnings remain readable in all supported camera modes.

### Task 6 — Improve audio weight while preserving settings and music behaviour

**Files:** audio setup/tick/`play_sound()` in `scripts/race/race_presentation.gd`, `scripts/race/race_feedback.gd`, `scripts/race/setup_menu.gd`, existing `audio/` notices. Inspect runtime-created Music/Effects buses before changing `default_bus_layout.tres`.

- [ ] Reuse the current engine layers, surface tyre loops and countdown/lap/finish cues as the baseline. Refine envelopes, pitch range and levels before introducing replacement recordings.
- [ ] Ensure landing and collision cues differ audibly in weight. Scale ordinary impact level by measured intensity; debounce contact chatter. Boost receives one onset and a controlled sustained layer/state.
- [ ] Establish one owner for ducking. Existing `message_time`/`cue_duck` logic and new impact envelopes must compose through that owner, not repeatedly overwrite one another or the saved Master/Music/Effects settings.
- [ ] Start with a maximum 2.5 dB brief race-impact duck, approximately 20 ms attack/120 ms return, for substantial player impacts only. Repeated events extend the envelope without stacking attenuation indefinitely. Mute remains authoritative; pause freezes/restores appropriate voices.
- [ ] Retain the current difficulty music and final-lap transition behaviour. Add no new music stems and do not replay the opening or restart shared menu music on intro completion.
- [ ] Cap new simultaneous effect voices; prioritize player warning/finish cues over distant rival bumps. Check a four-car contact cannot clip Master or create an inaudible warning.
- [ ] Capture bus peaks/voice state in the isolated probe. Audition the actual mix separately: Dummy-driver measurements prove mixing/state, not subjective sound quality.

**Gate:** saved volume/mute settings survive every transition; ducking returns to the configured level; no stuck engine/skid loops after results/menu; race cues remain distinct and the accepted intro/menu continuity still passes.

### Task 7 — Make rivals worth racing through measured decisions

**Files:** `scripts/vehicles/ai_driver.gd`, `scripts/race/race_progress.gd` (read-only ranking source), new `tests/probes/race_quality_ai_verification.gd`.

- [ ] First collect current passing, blocked-line and braking failures on Toys R You with four cars and explicit per-car seeds 128, 256 and 512. Use the same effective vehicle stats and route conditions in before/after runs. Only rerun variants when decision changes require it.
- [ ] Add lane-choice hysteresis: retain a chosen passing side long enough to avoid frame-to-frame weaving. Re-evaluate when the line becomes blocked or unsafe, with boundary margin and measured lane width as constraints.
- [ ] Evaluate braking/look-ahead around tight turns, ramp approaches and the bridge. Respect route layer and local surface speed/grip. Do not route rivals onto the wrong deck to shorten a path.
- [ ] Avoid impossible overtakes in narrow sections. When both options are blocked, follow/brake and retry later rather than shoving indefinitely. Preserve existing stall recovery and Nightmare attacker behaviour unless a recorded defect requires a bounded correction.
- [ ] Confirm difficulty affects commands, timing and risk rather than privately changing acceleration/top speed/grip. Inspect composed stat values for every racer.
- [ ] Verify full three-lap races plus controlled pass/stall cases. Targets: every healthy car finishes before the normal finishing deadline or reports an honest DNF; no indefinite stall; no new missed-gate penalties or recovery regression against the paired baseline; controlled safe passes complete without repeated side oscillation.
- [ ] Record an owner lap/race on the finished presentation for difficulty feedback. Do not declare Easy/Normal/Hard globally balanced from three AI seeds; owner-benchmark difficulty remains a wider-rollout gate.

**Gate:** reproducible passing/braking improvements and unchanged shared physics are evidenced. Human race feedback is captured. Keep new AI parameters local and small; if the baseline passes already, retain it rather than inventing an AI rewrite.

### Task 8 — Give the finish and retry a satisfying, correct ending

**Files:** `scripts/race/race_presentation.gd`, `scripts/race/arcade_podium.gd`, `scripts/race/victory_celebration.gd`, `scripts/race/time_trial.gd`; session rules remain authoritative.

- [ ] Trigger the player's finish emphasis once from `racer_finished`; show their valid time/position while rivals continue through the existing FINISHING window. Never announce the final classification before `results_ready`.
- [ ] Refine the current podium's spacing, driver emphasis and reveal animation. Finished racers, penalties and DNF rows remain legible; a finish effect must not turn a DNF into a win.
- [ ] Reserve the current confetti/victory treatment for an actual player victory. Other finishes receive a short positive finish cue and clear result, with no false winner animation.
- [ ] Keep Time Trial's PB/ghost and invalid-run messaging mode-specific. Preserve record writes and the existing one-award guard; do not introduce new currencies, reward multipliers or automatic unlocks.
- [ ] Keep Retry/Menu available promptly with directional focus matching visual layout. Holding the finishing/accept input cannot also activate a result action.
- [ ] Retry from results and from pause, return to menu, and switch away/back. Verify HUD/message queues, emitter pools, camera offsets, voice states and signal counts return to baseline.

**Gate:** one finish cue/classification/reward transaction per valid run; correct loss/DNF/PB outcomes; no blocked retry, sticky input or accumulating celebration nodes.

### Task 9 — Complete Toys R You acceptance and performance work

**Files:** both new quality probes; extend existing probes only where this work changes their covered behaviour. Write `docs/verification/toys-r-you-race-quality.md` and link its evidence here.

- [ ] Walk the complete intro→menu→selection→three-lap race→results→retry→menu path in an isolated rendered instance. Capture real input actions and before/after frame numbers for boost, pause, recovery and retry; do not substitute direct callback calls for the input path.
- [ ] Verify Quick Race and Time Trial. Include one normal finish, one loss/DNF, one missed-gate recovery/penalty and one Time Trial invalid/PB case, using controlled fixtures without writing the owner's profile.
- [ ] Run five retries/course switches in one instance and compare live node/emitter/voice counts after settling. Explicitly seeded AI RNGs must be reset for comparable races; global engine seeds alone are insufficient.
- [ ] Compare matched baseline/after frame-time samples on the recorded hardware. Target smooth 60 FPS at 1200×800, with a 16.7 ms frame budget; report p50/p95 and worst spikes rather than average FPS alone. At 720p/1080p record results honestly against their own paired baseline.
- [ ] Investigate a sustained p95 regression above 5% or a warm-switch regression above 10%. First reduce added particle overdraw, flash area, audio/visual allocations and repeated occluder work; avoid lowering scenery quality or changing route geometry to hide a polish cost.
- [ ] Verify all protected hashes and effective neutral stats remain unchanged. If route/environment changes unexpectedly, fail this gate and inspect the diff before proceeding.
- [ ] When support/gate/camera code has changed, run the relevant accepted alignment/flag cases. Pure HUD/audio edits do not justify repeating all extraction checks. Preserve raw errors/warnings and distinguish gameplay failures from historical shutdown warnings.
- [ ] Obtain owner approval of the finished Toys R You race feel and presentation after showing a playable result and comparison frames. Record any limitations and addressed feedback in the verification record.

**Gate:** all relevant machine checks pass, rendered review confirms visual quality, owner feedback is addressed, performance costs are recorded, and every test process has exited. Only then mark the Toys R You quality slice complete.

### Task 10 — Roll out proven improvements one active course at a time

**Files:** shared presentation/feedback code, bounded per-course configuration if demonstrated necessary, and one verification record per course. Do not re-author routes.

For each course: compare identity/readability and surface feedback; check its own checkpoint planes, ramps/layers, camera occlusion and finish area; walk a complete race and Time Trial transition; measure effect cost; preserve source geometry; record limitations; close the exact test process before moving on.

- [ ] Roulette Grand Prix (`game_table`): procedural material/prop identity and surface effects remain intact; existing procedural route polygons are unchanged.
- [ ] Toys R Asleep: review night contrast and warning visibility without brightening the entire scene.
- [ ] Rusty Nuts Workshop: review dense props, narrow passing margins and metal/ground-contact treatment.
- [ ] Moonlight Junk Heap: review dark scenery, occlusion and effect contrast.
- [ ] Firefly BBQ: distinguish added effects from source illumination/ambience.
- [ ] Nighttime Noodles: verify night readability and dense scenery cost.
- [ ] Mount Rainier: preserve its independently accepted timing-line alignment and measured asphalt boundaries; review speed/terrain framing.
- [ ] Topspeed Oval: verify sustained high-speed camera/boost/engine behaviour and stable rank notifications.

**Gate per course:** shared polish helps that course without reducing source identity, correctness or performance. Do not mark the rollout complete by testing Toys R You alone. Other vehicle classes and new modes need their own subsequent evidence.

## 5. Verification procedure and evidence contract

Every probe must inject the newer-schema sentinel fixture before race setup, disable physical controller/input processing and erase hardware action bindings while retaining the synthetic actions needed for the test. Reuse the opening probe's `_enter_tree` isolation pattern. `load_profile()` resets `read_only` and only activates the fallback for a schema newer than `ProfileStore.SCHEMA_VERSION`; a normal profile under `res://tests/fixtures/` is not automatically read-only. Give the new fixture the same sentinel content as `opening_read_only.json`:

```json
{"schema_version": 9999}
```

The fallback loads current defaults with writes disabled. Apply the chosen pixelation, sound, race and driver settings to the in-memory test data, using the existing settings APIs to refresh presentation. Check `race.profile.read_only` before the first action and after retry/course switches. Never use the owner's save files as disposable fixtures.

Example evidence assertions inside the new probe:

```gdscript
var before_frame: int = Engine.get_physics_frames()
var before_position: Vector3 = race.player_car.position
Input.action_press("p1_go")
Input.action_press("boost")
await settle_physics(45)
Input.action_release("boost")
Input.action_release("p1_go")
report("boost_motion", {
    "before_frame": before_frame,
    "after_frame": Engine.get_physics_frames(),
    "moved": race.player_car.position.distance_to(before_position) > 1.0,
    "boost_used": race.player_car.boost < 95.0
})
save_frame("boost_after")
```

Supplement real-action tests with controlled state setup for rare cases, labelled as such. Synthetic visual events test routing/capacity; they do not prove physics generated the correct event. Record actual input and event counters as separate evidence.

Run from the project root in PowerShell after the named probe has been implemented:

```powershell
./tools/run_tabletop_verification.ps1 `
  -Probe res://tests/probes/race_quality_verification.gd `
  -Evidence tests/baselines/race_quality/toys_r_you/quality01 `
  -MaxSeconds 240

./tools/run_tabletop_verification.ps1 `
  -Probe res://tests/probes/race_quality_ai_verification.gd `
  -Evidence tests/baselines/race_quality/toys_r_you/ai01 `
  -MaxSeconds 480
```

Run these separately; finish and confirm the first process exited before launching the next. Commands dispatch tests rather than waiting for results. Check progress in bounded intervals and communicate meaningful findings during long runs.

Expected results: `finished=true`, no `_timeout`, explicit `passed=true`, no captured gameplay errors, no frame warnings, all named assertions successful, readable captured frames and recorded timing/performance context. An empty or partial report is a failure.

For each output directory:

1. Read `results.json`, `stderr.log` and `stdout.log` without overwriting them.
2. Review the actual screenshots, including motion before/after and both bridge layers where relevant.
3. Confirm the PID from that directory's `pid.txt` has exited. If still running, verify its executable and command line belong to this exact project/verification output before terminating that specific process. Never stop the user's editor or another project.
4. Save a separate `visual-review.txt` and `process-exit.txt`. Keep failed runs; choose a new directory for each correction.

Reuse existing `opening_sequence_verification.gd`, `camera_modes_verification.gd`, `driver_livery_camera_verification.gd`, `race_panels_verification.gd`, `arcade_menu_flow_verification.gd`, `toys_controls_verification.gd` and `toys_flags_verification.gd` according to the touched systems. Update old probe isolation/fixtures where needed before trusting a rerun. Do not repeat unrelated checks after a passing gate unless a new change or concern requires it.

## 6. Risks, tuning decisions and checkpoints

| Risk | Implementation response | Acceptance evidence |
|---|---|---|
| Intro art promises more than current small 3D cars show | Prioritize silhouette, livery and visual motion; preserve renderer identity | Real driving-size comparison and owner play |
| Duplicate transform/audio writers | One visual-motion owner, one feedback owner, one mix owner | Toggle comparison, retry and pause traces |
| Shake obscures road or intersects props | Bounded post-pose offset, clearance clamp, reduced-effects option | Bridge/underpass/tall-prop frames in all modes |
| Smoke/flash hides checkpoints | Local small effects, capacity caps, warning priority | Four-car effects and gate approach captures |
| Passing tuning damages reliable lap completion | Pair seeded before/after races; keep shared physics/stat values | Full laps, penalties/recovery/stall counters |
| Frequent presentation feedback adds load | Reuse emitter/voice pools and event edges; avoid per-frame allocation | p95 frame cost and five-reset node counts |
| Results/celebration double-awards or traps input | Authoritative session signals and current reward guard; release/focus checks | Finish/DNF/PB and held-accept tests |
| Historical evidence mistaken for current validation | Versioned new run directories and explicit limitations | New record with hashes, runtime and exited PIDs |

Playable checkpoints are: after Task 4 (look/vehicle response), after Task 6 (complete race presentation/audio), and after Task 9 (competition/finish and final acceptance). These are concrete review builds; do not interrupt each routine reversible edit with a new approval request.

## 7. Completion and handoff

- [ ] Tasks 0–9 have evidence links and their individual acceptance gates met.
- [ ] Final record explains what changed, why, how it was verified and remaining limitations. It distinguishes human feedback from automated checks.
- [ ] The broader rollout references completed shared camera/panel/wheel work without claiming other classes/modes finished.
- [ ] Save a scoped recoverable checkpoint of the implementation and documentation using the established repository workflow. Inspect repository state first; never stage the entire currently untracked project as part of a polish commit.
- [ ] Tasks in the course rollout remain unchecked until individually verified.

Start implementation with **Task 0**, then complete Tasks 1–4 as the first playable improvement. Build the smallest convincing Toys R You race before expanding the treatment across the catalogue.
