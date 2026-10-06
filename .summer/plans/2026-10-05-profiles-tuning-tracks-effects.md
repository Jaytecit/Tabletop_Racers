# Profiles, Tuning, Tracks and Effects Implementation Plan

> Current-status notice — 6 October 2026: this document retains the original specification and dated checkpoints. Its starting-point tables, old menu/class counts and unchecked historical boxes are not current implementation status. Use [current build](../../docs/current-build.md) and [remaining work](../../docs/implementation-checklist.md) before executing any task. All five classes, named profiles, eight portraits, eleven courses and eight-car Quick/Freestyle are implemented. Tournament/Elimination expansion, solid finishers, performance and final balance remain open.
>
> Owner overrides: no preservation-only migrations for development scores/rewards; preserve identity/preferences, accepted geometry, sources/notices and failures. New tracks receive one Beach Buggy race on Hard (Freestyle if assigned class differs), not the old matrices or extra mode runs. Work inline, one course at a time. Audio/video are outside the eight-car work. The original full specification remains in the hash-verified documentation snapshot.

> **For agentic workers:** implement this plan task-by-task, in order, checking off each step as it lands. Execute inline with a review checkpoint after each task. Do not dispatch subagents. Integrate and verify one course at a time.

**Goal:** deliver the eight outcomes in the current Desktop Requirements.txt: developer tuning/export, supported Mount Rainier shoulders, live position numbers, persistent named profiles and revised HUD/minimap, a classified larger track catalogue with bedroom skybox presentation, verified shadows, improved effects, and Bazaar Drift.

**Architecture:** extend the existing profile, vehicle, race-session and lazy course systems. Separate physical ground support from racing legality; separate driver identity from slot and rank. Preserve source-derived routes and make developer overrides an explicitly unranked session layer above ordinary progression.

**Tech Stack:** Summer Engine, GDScript, existing scenes/resources, JSON persistence/export, existing Python GLB analysis tools, and isolated rendered probes.

---

## Authority and relationship to existing work

The original task requested a plan. On 5 October the user authorised implementation: saved named profiles first, then live ranks and a dot-only minimap, then continuation in the order below. Source deletion, purchases and installation are outside this implementation.

This is an addition to [the existing rollout](2026-10-03-tabletop-glb-rollout.md), not a replacement of its completed milestones or outstanding gates. Keep its evidence and owner acceptance distinctions. New tasks below are unchecked. During implementation update [the implementation checklist](../../docs/implementation-checklist.md) and relevant verification records with actual results.

Required track references:

- [Accepted Toys R You](../../docs/toys-r-you-integration.md).
- [Extraction and acceptance gates](../../docs/tabletop-track-extraction-guide.md).
- [Reference tooling and limitations](../../tools/tabletop_reference/README.md).
- [Existing GLB usability survey](../../docs/glb-track-usability-audit.md).

Method discovery checked [skills.sh](https://www.skills.sh/) on 5 October 2026. Its skill-discovery catalogue supports checking for existing workflows first; use the already installed writing-plans skill and the project's proved extraction tools. No additional skill installation is needed for this plan.

## Observed starting point

| Area | Evidence and implication |
|---|---|
| Persistence | `scripts/profile_store.gd` uses schema 12 and one `user://profile.json`, with validation, backups, progression and records. Named save slots need migration, not a replacement of progression. |
| Driver identity | `scripts/race/race_garage.gd` has four portrait/livery choices and AI names. Portrait/livery selection must stop implicitly changing the active saved person. |
| Tuning | `tests/probes/stat_test_toggle_verification.gd` verifies zero/full stat tests without spending progression. A full tuning menu must extend beyond that bounded stat toggle. |
| Mount Rainier | `scripts/tracks/author_mount_rainier.gd` delegates to `author_tabletop.gd`; car support is queried in `arcade_car.gd`. Missing terrain collision versus recovery classification remains to be diagnosed. |
| Rank | `scripts/race/race_session.gd` already supplies `rank_of(car)`. Use it, rather than vehicle/driver indices, for overhead numbers. |
| Minimap | `scripts/race/race_minimap.gd` draws rival text and leader lines. Remove those annotations while preserving coloured dots. |
| Drift | `content_catalog.gd` and `drift_rules.gd` permit Topspeed Oval; menu and race startup also contain Topspeed fallbacks. All need a coordinated Bazaar change. |
| Lighting | `scenes/race/race.tscn` has a DirectionalLight3D with `shadow_enabled = true`. Some decorative geometry deliberately disables casting. Static configuration does not establish all-course visual quality. |
| Effects | `scenes/vehicles/arcade_car.tscn` has CPUParticles3D smoke, sparks and debris; `race_feedback.gd` owns bounded cosmetic events. Root `race_particles.gd` also exists for the preserved game; establish runtime ownership before changing it. |
| Tracks | Ten active course IDs exist, including Bazaar. The survey has candidates, environments, duplicates and conditions; these are not all verified playable tracks. Beach Buggies remains inactive. |

## Planning defaults

- Names contain 1–9 letters; initially accept A–Z/a–z, trim outer whitespace, and reject digits, punctuation, empty names and longer pasted input. This character-set choice is a proposed default, not an additional user requirement.
- Offer the existing four portraits first. Store a stable portrait ID; user image uploads and image cropping are outside this request.
- Present create/select after every intro, with the last-used profile highlighted. Selecting confirms it; skipping the intro must still reach profile selection. Return-to-menu offers Change Profile. All modes retain the selected identity until that action.
- Keep display/audio/input preferences machine-wide; keep identity, progression, records, mode choices and personal builds profile-specific. Migrate existing setup preferences once.
- Developer tuning is session-only by default, with player/all-AI/individual-AI targeting and explicit export. It does not spend upgrades or award ranked records/rewards.
- Unusable tracks are removed from playable/build selection with a recorded reason. Preserve sources and evidence in an archive first. Permanent source deletion is a distinct later action.
- Asset-pack preference is conditional on visual suitability and redistribution terms. No purchase is required to start; retain a locally authored fallback.

## File map

Existing files listed below are modification targets; new paths are proposed responsibilities, not claims of existing APIs.

| Task | Existing targets | New files |
|---|---|---|
| 1: Save identities | `scripts/profile_store.gd` | `scripts/profiles/profile_directory.gd`, `scripts/profiles/machine_settings.gd`, `tests/probes/profile_directory_verification.gd` |
| 2: Profile flow | `scripts/app.gd`, `scripts/race/opening_sequence.gd`, `scripts/race/arcade_menu_flow.gd`, `scripts/race/race_garage.gd`, `scripts/race/race_presentation.gd`, `scripts/race/controls_setup.gd`, `scripts/race/setup_menu.gd` | `scripts/profiles/profile_menu.gd`, `tests/probes/profile_flow_verification.gd` |
| 3: Identity/rank displays | `scripts/race/race_session.gd`, `scripts/race/race_presentation.gd`, `scripts/race/race_garage.gd`, `scripts/race/race_minimap.gd`, `scripts/vehicles/arcade_car.gd` | `scripts/race/racer_identity.gd`, `tests/probes/racer_identity_verification.gd` |
| 4: Ground | `scripts/tracks/author_tabletop.gd`, `scripts/tracks/author_mount_rainier.gd`, `scripts/vehicles/arcade_car.gd`, `scripts/tracks/surface_definition.gd`, Mount Rainier environment/manifest | `tests/probes/mount_rainier_ground_verification.gd` |
| 5–6: Tuning/export | `scripts/vehicles/vehicle_definition.gd`, `scripts/vehicles/arcade_car.gd`, `scripts/vehicles/ai_driver.gd`, `scripts/race/race_presentation.gd`, `scripts/race/player_stats_menu.gd`, `scripts/race/time_trial.gd`, `scripts/race/owner_benchmark.gd` | `scripts/dev/vehicle_tuning.gd`, `scripts/dev/tuning_menu.gd`, `scripts/dev/tuning_export.gd`, `tests/probes/dev_tuning_verification.gd` |
| 7: Bazaar Drift | `scripts/tracks/content_catalog.gd`, `scripts/race/drift_rules.gd`, `scripts/race/drift_controller.gd`, `scripts/race/arcade_menu_flow.gd`, `scripts/race/race_presentation.gd`, `tests/probes/drift_flow_verification.gd` | `docs/verification/bazaar-drift.md` |
| 8–10: Catalogue/bedroom | `scripts/tracks/content_catalog.gd`, `scripts/tracks/track_entry.gd`, `scripts/tracks/selected_course.gd`, existing extraction tools and per-course resources | `docs/glb-track-disposition.md`, `scripts/tracks/course_capabilities.gd`, `scripts/tracks/bedroom_display.gd`, `environments/bedroom/stylized_room_panorama.res`, `tests/probes/course_capabilities_verification.gd` |
| 11: Shadows | `scenes/race/race.tscn`, `scripts/race/race_garage.gd`, affected environment/material resources | `tests/probes/course_shadow_verification.gd`, `docs/verification/course-shadows.md` |
| 12: Effects | `scenes/vehicles/arcade_car.tscn`, `scripts/vehicles/arcade_car.gd`, `scripts/race/race_feedback.gd`, `scripts/race/setup_menu.gd`, `scripts/race/asset_credits.gd` | `scripts/vehicles/vehicle_effects.gd`, `scripts/vehicles/tyre_marks.gd`, `assets/effects/CREDITS.md`, `tests/probes/vehicle_effects_verification.gd` |

Make scene/resource changes through Summer's editor scripting and saved resources. Follow the existing runtime ownership; do not restructure large race scripts beyond extracting these focused responsibilities.

## Implementation tasks

### Task 1: Add a validated directory of named profiles

- [x] Add a manifest `user://profiles/index.json` containing schema version, last-selected ID and entries `{id, name, portrait_id}`. Use opaque generated IDs for filenames; never use entered names as paths. Profile payloads live at `user://profiles/<id>.json`, using the existing validated save and backup logic.
- [x] Define directory operations `list_profiles()`, `create_profile(name, portrait_id)`, and `select_profile(id)`. Return explicit errors for invalid names/portrait IDs, unreadable manifests, unknown selections, write failures and duplicate names under case-insensitive comparison. Never overwrite another profile. Set `profile_store.path` only after a validated selection.
- [x] Move machine preferences behind `machine_settings.gd`; update Setup and Controls callers to that store while retaining read-only verification support. A profile switch must not unexpectedly alter window/audio/controller settings.
- [x] Migrate the existing save to one preserved legacy entry with its progression, vehicles, records and history intact. Prompt for its final name/portrait in Task 2. Stage payloads before atomically publishing the index, preserve the old file/backup, and make restart after interrupted migration idempotent.
- [x] Create a probe with a directory rooted inside its evidence folder. Verify names of 1 and 9 letters, rejection of 0/10 letters, pasted punctuation, unknown portraits and traversal-like IDs; create two profiles, assign different builds/records, save/reload and assert no crossover. Include corrupted-index/backup and interrupted-migration fixtures. Check actual saved JSON, not just UI messages.

### Task 2: Gate gameplay on profile creation or selection

- [x] Connect opening completion to `profile_menu.gd`; block mode start and preference/reward writes before a person is selected. Account for the race child currently initialising before the app opening starts.
- [x] Build create/select controls with nine-letter input, portrait thumbnails, validation messages, confirm and Back. Apply existing menu style and explicit directional focus neighbours. Selecting an existing profile displays its saved name/portrait before confirmation.
- [x] After profile or character confirmation automatically advance to the next permitted screen. Freestyle includes Vehicle; modes with an assigned class go directly to Course. Back follows the same permitted sequence. Setup is available only on the main menu, and no Gold Livery buttons are created. Character-flow changes were implemented separately on 5 October; apply these rules to the future saved-profile UI as well.
- [x] Add Change Profile to the main menu. Switching reloads personal progression and mode state, clears temporary tuning, resets stale tournament/challenge controllers and binds all subsequent saves to the new file. Changing a portrait/livery during setup does not switch saved person.
- [x] Preserve active profile through retry, course changes, results and Quick Race, Time Trial, Freestyle, Tournament, Challenge, Elimination, Time Attack and Drift. Prevent any in-race switch.
- [x] Verify first launch, returning launch, intro completion/skip, legacy migration, cancelled creation, restart and two-profile switching. Snapshot both files before/after each mode action and verify only the selected file receives rewards/records. Use sandboxed writable files for persistence tests; real owner saves remain read-only.

### Task 3: Display driver names and current race position consistently

- [x] Introduce racer identity data keyed by stable racer slot: `{profile_id, display_name, portrait_id, colour}`. Player identity comes from the selected save; AI identities reuse current rival names and colours. Identity must remain independent of changing rank.
- [x] Find the active car's overhead number owner and replace its driver number with the session's authoritative rank on live updates. Preserve finish/elimination rank semantics and define a dash for an unranked ghost. Do not draw a ghost as a competing racer.

```gdscript
# Rank formatting contract; use the existing car label owner.
var rank: int = race.session.rank_of(car)
var rank_text: String = str(rank) if rank > 0 else "–"
```

- [x] Render the top-right position rows with rank plus identity name, retaining AI profile colour. Use the same identity for results wherever racer names are shown. Remove minimap text and leader lines; retain dots and the existing player visibility treatment.
- [x] Add a deterministic overtake fixture and assert each active car's label equals `str(session.rank_of(car))`, with no leading zero. Verify tied progress, lapped cars, finishes, elimination and retry. Capture long nine-letter names, coloured AI rows and a bunched minimap; confirm no text is drawn on the map.

### Task 4: Make Mount Rainier's visible terrain physically solid

- [x] Reproduce a car leaving tarmac onto each visible dirt/ground region. Save location, support ray result, collider/surface identity and the recovery branch taken. Establish whether each failure is missing collision, a wrong collision mask, a height mismatch or a false raised-edge recovery.
- [x] Inspect Mount Rainier's actual terrain primitives/materials under the recorded source transform. Generate collision from supported ground triangles; exclude sky, foliage, roofs and decorative geometry. Record selection by source hash and node/primitive identity in its manifest.
- [x] Keep legal asphalt boundaries unchanged. Supported off-road terrain slows vehicles and disables ordinary road boost while keeping them grounded. Use physical hit height/normal; do not create an infinite invisible plane or widen the legal corridor to hide failures. Remove a raised-edge classification only where source geometry proves a continuous shoulder.
- [x] Verify every reported region at slow/fast speed, across slopes and transitions, in both directions with player and AI vehicles. Assert finite height, physical support, slowdown versus the same baseline road run, no unjustified fall/recovery, and no shortcut gate advancement. Outside the finite model footprint retains existing recovery.
- [x] Run Mount Rainier alignment/gate/race probes plus a focused Toys bridge-edge and procedural-edge regression if shared car support changes. Preserve canonical measurements and before/after failing evidence.


### Task 5: Add a broad developer override model

- [x] Inventory every vehicle resource property, derived player stat, boost/recovery parameter and configurable AI decision parameter. Build one descriptor table with field, type, default, unit, range, target and apply behavior. UI and exporter consume this same table so a new setting cannot silently disappear from exports.
- [x] Compose in this order: immutable base resource → saved progression/build → developer overrides → effective car tuning. Duplicate resources before mutation; AI and player physics consume the same effective schema. Expose separate AI behaviour settings from physics.
- [x] Use initial exploratory ranges: speed/acceleration/braking/reverse 0–10× stock; grip/coast grip 0–20×; steering/drag 0–10×; boost drain 0–10×; recovery duration multiplier 0.05–20×; surface factors 0–10. Zero boost drain explicitly means unlimited boost. Positive geometry sizes use 0.05–5× and require a reset before applying. Boolean settings use toggles. These bounds are proposed starting values; validate each against its actual equation before shipping.
- [x] Permit low-grip/high-power extremes while rejecting non-finite values and unsafe zero denominators. Show numeric values, units and stock references; add fine/coarse adjustment and direct numeric entry. Do not silently clamp experiments back to progression limits. Fields without a meaningful continuous domain use explicit discrete controls.
- [x] Support player, all AI and individual AI targets; show differing AI values as mixed. Add reset target/reset all and explicitly mark experimental sessions. Apply live-safe fields immediately and clearly mark fields requiring restart.
- [x] Test each descriptor at minimum, stock and maximum using bounded short drives. Assert finite transforms/velocity, no shared-resource mutation, independent AI overrides, reset parity and no profile progression writes. Disable Time Trial records/ghost publication, benchmark saves, challenge rewards and tournament awards while experimental overrides are active.

Runtime/API implementation verified on 5 October: 59 descriptors and 875 min/stock/max cases across five vehicle classes; isolated rendered smoke confirms reset/independence, unlimited boost, unranked visibility and progression guards. See [evidence](../../docs/verification/developer-tuning-overrides.md). Numeric controls and target/reset menu presentation are implemented and verified in Task 6. Fixed recovery animation/AI decision constants remain code, as inventoried in the evidence.

### Task 6: Build the developer menu and complete setup export

- [x] Add an explicitly labelled Clear Earned and Spent Rewards action. Reset the selected profile's upgrade balances, spent upgrades, Bling, purchased/equipped paint, gold unlock, cup/tournament reward progress and challenge awards; restore its portrait's ten-point starting build for every vehicle. Preserve identity, preferences and race records. Reuse `profile_store.reset_rewards()` and issue a fresh reward-reset token so stale sessions cannot restore pre-reset rewards. Clearly show the scope before the destructive action and back up the profile. Verify persisted/reloaded reset, preservation of records, idempotence and blocked read-only writes. This action was explicitly requested on 5 October; the menu itself remains pending Task 6.

- [x] Add a developer entry in main menu and pause, preserving focus and pause state. Group Physics, Boost/Recovery, Surfaces, AI and Vehicle Details. Keep the developer overlay distinct from the player's earned upgrade menu.
- [x] Export versioned UTF-8 JSON through a file dialog with explicit success/error feedback. Include all descriptor values, base/derived/effective tuning for every racer, source vehicle IDs/resource paths and dimensions, driver identity, AI profile/seed/difficulty, course and route revision, mode, game/handling version and relevant setup settings. Include inactive settings with an active flag rather than omitting them. Include source visual resource identifiers; binary meshes need not be embedded.

```json
{
  "schema_version": 1,
  "experimental": true,
  "context": {},
  "settings": {},
  "racers": [],
  "vehicle_definitions": {}
}
```

The schema above is a structural contract. Populate context with all fields named in the preceding step; settings includes every descriptor, and racers contains each actual participant's resolved values. Do not export an empty structural example as a setup.

- [x] Convert Vector3/Color/resource references to plain numeric arrays/IDs and reject NaN/infinity. Write to a temporary sibling file before replacing the chosen output, and report failures without losing the current session setup.
- [x] Parse an exported fixture back in the verification probe and compare its descriptor key set and every resolved racer value with runtime. Verify player/all-AI/individual-AI edits, cancelled dialog, unwritable path and reset. An import UI is outside this request.

Task 6 complete on 5 October: grouped main/pause developer overlay, direct/fine/coarse/mixed controls, complete atomic JSON export and backed-up token-protected reward reset. [Rendered verification and retained failures](../../docs/verification/developer-menu-export.md) pass, including dialog input, Escape pause preservation, export parity and persisted reset/stale-session guards. Task 7 Bazaar Drift is next.

### Task 7: Move Drift Challenge to Bazaar

- [x] Set `DRIFT_COURSES` to Bazaar and replace all drift-specific Topspeed startup/menu fallbacks. Preserve Topspeed's ordinary racing selection and existing history.

```gdscript
# scripts/tracks/content_catalog.gd
const DRIFT_COURSES: Array[String] = ["bazaar"]
# scripts/race/drift_rules.gd
const COURSES: Dictionary = {"bazaar": 1200}
```

The 1200 target is a provisional baseline transferred from the current challenge. Tune it after a real 90-second Bazaar drift run; do not declare balance from this edit alone.

- [x] Retain the drift-car assignment, scoring/combo rules and countdown. Version course-specific records if target/rules change; preserve historical Topspeed entries for history without offering Topspeed as Drift Challenge.
- [x] Extend `drift_flow_verification.gd` to verify direct selection, stale saved Topspeed mode, retry, returning to menu, Bazaar loading failure and 90-second completion. Assert `track_id == "bazaar"` and correct vehicle throughout; check scoring on asphalt and loss of combo on unsafe shortcuts.

Task 7 implemented and strictly verified on 5 October: Bazaar-only Drift, stale-profile/menu fallbacks, historical Topspeed score reload, retry/load failures and a real 90-second physical run pass. The run scores 486 points with no crashes/recoveries; the 1,200 target remains provisional pending human balance. Raw failures are retained and all test PIDs exited. See [evidence](../../docs/verification/bazaar-drift.md). Task 8 disposition register is next.

### Task 8: Turn the existing GLB survey into a disposition register

- [x] Reconcile the existing survey with actual source files using hashes. Record one row per source: duplicate identity, geometry/texture cost, route type, physical support/layers, measured usable width, credits, extraction branch, status and reason. Do not repeat the entire survey where hashes still match.
- [x] Assign statuses: active, ready-for-extraction, authored-route-required, needs-repair, archived-unusable or duplicate. A filename, large triangle count or ambiguous topology alone is insufficient to call a model unusable. Save source views and specific blocking evidence for exclusions.
- [x] Add mode capabilities separately from visual category: circuit racing/time trial, drift, time attack/challenge, tournament eligibility, supported vehicle types, crossings/jumps and loft presentation. Compute readiness from accepted gates; category tags do not register unverified routes.
- [x] Exclude confirmed unusable/duplicate entries from catalogue/build dependencies; archive sources and a manifest with reasons first. Keep original source credits and failed evidence recoverable. Keep Beach Buggies inactive unless explicitly requested again.
- [x] Extend catalog validation to reject unknown capability/mode combinations with an actionable message. Test lazy loading: classification/menus do not instantiate every environment, and filtered selectors never expose unverified courses.

Task 8 complete, 5 October: 42 files / 41 hashes reconciled, five added sources surveyed, independent capability validation and lazy selectors verified by 190 strict rendered assertions. Sources and failed evidence retained; all test PIDs exited. See [evidence](../../docs/verification/course-capabilities.md). Task 9 Town Square is integrated; Raceway is next.

### Task 9: Expand courses serially using the established gates

- [ ] Start with Town Square, already identified as a strong dedicated driving-collision candidate. Then review Raceway, which needs explicit bridge-layer separation. Choose subsequent single-loop candidates from the disposition register before branched city networks or heavy real circuits.
- [ ] For each course create `tracks/<course_id>/measurement_manifest.json`, `measured_route.json`, `definition.tres`, `entry.tres`, `preview.res`, `environments/tabletop/<course_id>.tscn` and `docs/verification/<course_id>.md`. Use the existing dedicated-road or painted-road branch; network environments first require an explicitly chosen closed route and clipped junctions.
- [ ] Lock one transform; independently derive both boundaries and each height from the model; retain layer identity, uncertain intervals, seam/topology review and source start cue. Keep 24 spans/25 samples per section. Never accept a fixed-width screenshot trace as the final corridor.
- [ ] Place requested checkpoint cues at actual gate planes, intersecting measured boundaries and supported shoulders. Reuse source start artwork and keep temporary overlay disabled for final views. Add no permanent generated road edges.
- [ ] Pass every extraction-guide gate: source correspondence and uncertainty review, topology, joins, containment, support, layered crossings, full checkpoint matrix, four Hard cars/three laps, controls/recovery/switching, Quick Race/Time Trial, performance and credits. Register the course only after these pass. Proceed to the next course only after retaining results and confirming test-process exit.
- [ ] For modes beyond normal racing, run a short mode-specific trial before enabling its capability. Record loading time and frame time against an accepted course on the same hardware/settings. Keep unsupported candidates in the register rather than promising a final number of tracks before evaluation.

Town Square checkpoint, 5 October: registered ROAD / racing_car for Quick Race, Time Trial and Freestyle. Independent source geometry, support/gates/flags, Hard races, five-class coverage, production menu/profile persistence and loading pass. Canonical Toys/procedural geometry is preserved; failures and process exits retained. [Evidence](../../docs/verification/town_square.md). Other modes, owner balance, release comparison and the shared 16.7ms p95 goal remain open. Task 9 continues with Raceway; Task 10 is complete under the owner’s skybox-only acceptance; see its record below.

### Task 10: Present large realistic courses in a bedroom skybox

Owner direction, 5 October: use the supplied bedroom skybox instead of constructing a loft. Final update removes the drawn table and legs; the owner considers all centrally framed tracks accepted without further tests.

- [x] Inspect the two supplied room GLBs and select the stylized bedroom panorama; preserve all six source skyboxes and record source/credits in `docs/glb-track-disposition.md` and in-game credits. `tools/author_bedroom_panorama.gd` rebuilds the mipmapped runtime texture.
- [x] Use a translation-invariant panorama sky so every camera remains at its centre, preserving course transforms, route coordinates and miniature-car proportions. Add no table, legs or backdrop collision.
- [x] Select bedroom presentation through course-entry metadata for Town Square, Bazaar, Mount Rainier and Topspeed Oval. Reuse it in the course-selection flyover and restore the previous sky when switching to a source presentation. Standard vehicle assignments and mode eligibility are unchanged.
- [x] Retain rendered camera/menu, source-support/checkpoint/flag, controls, race and incremental-cost evidence gathered before the owner’s final update, including failures. Fix orthographic stretching with a 65° sky FOV. Stop the active test and confirm its PID exit; remaining acceptance follows the owner’s instruction, not a claim of additional executed tests.

[Completion, evidence and limitations](../../docs/verification/bedroom-presentation.md). The final scope has no drawn table geometry. Task 11 remains separate.

### Task 11: Audit shadows and fix evidenced failures

- [ ] Run a rendered audit for each active environment: effective light settings, shadow distances/cascades, mesh cast flags, material behavior and actual car/prop contact shadows. Include bright tabletop, night scenes, Mount Rainier, Bazaar and bedroom framing. Produce a per-course results table; configuration alone is insufficient.
- [ ] Inspect three views per course: car contact, a tall prop and overhead. Include chase-distance shadow coverage, slopes and crossings where applicable. Preserve deliberate non-casting overlays/flat decals; do not toggle every mesh blindly.
- [ ] Fix only evidenced gaps through the shared sun or per-environment overrides. Balance baked lighting with dynamic shadow contrast and measure the cost before enabling more shadowed lights. Verify garage preview lighting separately.
- [ ] Save before/after captures and frame-time settings to `docs/verification/course-shadows.md`. The answer to “all tracks cast shadows?” is complete only when each active course has a recorded rendered result.

### Task 12: Upgrade smoke, sparks, boost and tyre marks

- [x] Establish current 3D effect ownership and capture fixed-camera clips for drifting, braking, boost, impact and dirt driving. Keep the preserved 2D game unchanged unless it actually shares a modified resource.
- [x] Evaluate a suitable effect texture pack during implementation, recording exact source, licence, attribution and included files. Prefer smoke flipbooks, spark sprites and noise/gradient textures; keep locally authored equivalents if pack quality or terms are unsuitable. This plan does not select an unverified external pack.
- [x] Use `vehicle_effects.gd` for bounded per-car emitters: soft expanding smoke from tyre contacts, dust tinted for dirt, brief directional sparks at impact contacts, and a clear boost trail/exhaust. Drive intensity from slip/speed/event strength, with no emission while airborne where contact is required.
- [x] Use `tyre_marks.gd` for pooled, fading rubber strips following wheel contact positions and surface normals. Separate strips across recovery, teleport, course switch, bridge-layer changes and lost contact. Offset enough to avoid z-fighting; respect surface rules and leave no airborne/water skid marks.
- [x] Preserve cosmetic cooldowns, budgets and reduced-effects controls. Set explicit per-car and total caps, recycle nodes/materials, and clear old effects when switching courses. Choose CPU/GPU particle implementation after profiling the current renderer; a conversion alone does not prove improved appearance.
- [x] Verify all five vehicle classes in their permitted modes, multiple simultaneous AI effects, bright/night surfaces, banked roads and crossings. Capture comparable before/after clips; assert effect-count bounds, zero growth after repeated races, no stale strips after teleport and no changed physics/scoring.
- [x] Measure normal/reduced-effects frame time at identical settings with four cars. Keep a 60 FPS target where the baseline already meets it; record hardware and actual deltas rather than claiming universal performance.

- [x] Obtain owner visual acceptance for the revised look.

Implementation and technical verification completed 5 October: 150 assertions plus three Drift Challenge gameplay-camera checks; normal/reduced four-car measurements and comparable clips recorded in [vehicle-effects evidence](../../docs/verification/vehicle-effects.md). Median pacing remains approximately 60 FPS on the RTX 4060 Ti; the measured p95 frame-tail increase is documented. All test PIDs exited. **Task status: complete. Owner approved the revised look on 5 October 2026.**

## Verification execution and review checkpoints

Use the existing `tests/autopilot/probe_base.gd` harness. Each new probe records individual assertions, screenshots and raw results. Isolate hardware before scripted driving:

```gdscript
race.profile.read_only = true
race.controller.set_process_input(false)
race.controller.set_physics_process(false)
race.controller.device = -1
race.controller.using_pad = false
for action: StringName in InputMap.get_actions():
    InputMap.action_erase_events(action)
```

For sandbox persistence tests, additionally redirect every new profile-directory/machine-settings/control path to the evidence folder; permit writes only in that folder. Never temporarily make the owner's live save writable.

From the project root, run each named probe separately with a new evidence suffix. Example commands for the first implementation slices:

```powershell
./tools/run_tabletop_verification.ps1 -Probe 'res://tests/probes/profile_directory_verification.gd' -Evidence 'tests/baselines/requirements_2026_10_05/profiles_01' -MaxSeconds 120 -WaitAndCheck
./tools/run_tabletop_verification.ps1 -Probe 'res://tests/probes/racer_identity_verification.gd' -Evidence 'tests/baselines/requirements_2026_10_05/identity_01' -MaxSeconds 120 -WaitAndCheck
./tools/run_tabletop_verification.ps1 -Probe 'res://tests/probes/mount_rainier_ground_verification.gd' -Evidence 'tests/baselines/content/mount_rainier/ground_01' -MaxSeconds 210 -WaitAndCheck
./tools/run_tabletop_verification.ps1 -Probe 'res://tests/probes/dev_tuning_verification.gd' -Evidence 'tests/baselines/requirements_2026_10_05/tuning_01' -MaxSeconds 210 -WaitAndCheck
./tools/run_tabletop_verification.ps1 -Probe 'res://tests/probes/drift_flow_verification.gd' -Evidence 'tests/baselines/content/bazaar/drift_01' -MaxSeconds 210 -WaitAndCheck
```

Expected: `Passed=true`, every relevant assertion true, no timeout/gameplay errors, readable screenshots and a `process-exit.txt` confirming the owned child exited without forced termination. Inspect raw results and logs even when the wrapper passes. Preserve failed directories and increment the suffix on rerun. Stop only the owned test process; never stop the user's editor or another project. Do not claim headless checks provide visual proof.

After each task review the targeted changes and evidence, then save a narrow checkpoint. The current checkout reports project files as untracked; do not blanket-stage or claim Git rollback exists. Preserve targeted backups before implementation and establish intended tracked files before any requested commit. Broaden regression only when shared changes justify it.

## Completion and coverage

| Requirement | Completion gate |
|---|---|
| Developer menu, extreme sliders, export | Tasks 5–6: player/AI controls, finite extreme drives, complete parsed export and isolated normal progression. |
| Mount Rainier dirt/ground | Task 4: physically supported slower shoulders, no unjustified falls, unchanged asphalt legality and valid gates. |
| Overhead live positions without zero | Task 3: overtakes/finishes/elimination use authoritative rank and unpadded formatting. |
| Profile creation/selection, 9 letters, portrait, continuity | Tasks 1–2: migrated independent saves and all-mode flow; Task 3: names/AI colours/dot-only minimap. |
| Many usable GLBs, exclusions, categories, bedroom skybox | Tasks 8–10: disposition register, serial accepted imports, capability filters and shared bedroom presentation. Final count follows evidence and the owner’s acceptance. |
| Shadow question | Task 11: per-active-course rendered report, evidenced fixes and performance results. |
| Better particles and skid marks | Task 12: comparable visual proof, pack credits or fallback, contact-correct marks, bounded cost and owner visual acceptance. |
| Bazaar Drift | Task 7: every entry/retry selects Bazaar, challenge completes and historical records remain preserved. |

**Plan review:** all eight attachment outcomes have tasks and acceptance gates. Character set, machine/profile preference split, provisional tuning ranges, initial Drift target and archive-first removal are explicit defaults. Terrain failure cause, remaining usable-course count, final effect pack and all-course shadow quality require the stated implementation evidence; they are not reported as verified here.

**Execution order:** Tasks 1–3, then 4, then 5–7, then 8–12. The first seven deliver concrete improvements on existing content before the larger serial expansion. Execute inline when implementation is requested; this planning task does not start those changes.

## Implementation checkpoint — 5 October 2026

Tasks 1–3 implemented and rendered verification passed. The combined `saved_profiles_verification.gd` covers the proposed separate probes: migration, corruption/future/write guards, two-file isolation, eight-mode identity fixtures, keyboard flow, live ranks and results. Machine-wide bindings remain in existing `controls.cfg`; other shared preferences use `machine_settings.gd`. Root-car rank labels survive visual rebuilds and replace the old static visual numbers. See [profile evidence](../../docs/verification/saved-player-profiles.md).

Task 4 is complete after source inspection identified centre-ray misses just 0.01629 and 0.00162 units outside asphalt while the car footprint remains in contact. Bounded two-contact support applies only to imported shoulders; raised/guarded edges, artwork exclusion and legal geometry are preserved. Fresh rendered footprint, 40-drive ground, alignment/gate, Toys/procedural and strict four-car/three-lap Hard race checks pass. Protected routes and source GLB remain unchanged; failed and incomplete runs are retained and all owned processes exited. See [ground evidence](../../docs/verification/mount-rainier-ground.md). Tasks 5–7 have subsequently completed their implementation/verification checkpoints above. Task 8 is next; Tasks 8–12 remain open.


## Development persistence policy — owner update, 5 October 2026

Preservation of high scores, best times, ghosts, rewards, currencies, upgrade progress and related player records is not required while the game is in development. Development changes may reset or invalidate these values when useful; do not spend implementation effort on compatibility or migration solely to preserve them. This instruction supersedes earlier record/reward preservation requirements in this plan and the rollout. It does not request an immediate wipe or removal of normal saving, named identities or machine preferences. Preserve canonical track measurements, source assets/credits and failed verification evidence.

For every race mode that enforces a time limit, the main race timer must count down the remaining budget. Checkpoint time bonuses increase the displayed budget, penalties reduce it, pause freezes it, expiry clamps to zero, and retry restores the starting budget. Untimed races retain elapsed-time timing.

Timed HUD implemented and strictly rendered-verified: Time Attack and Drift count down; extension/penalty, pause, zero expiry, retry and untimed regression pass. See [timer evidence](../../docs/verification/bazaar-drift.md#timed-hud-verification--5-october-2026).

## Five-stage challenge difficulty — owner addition, 5 October 2026

- [x] Add per-profile, per-track roadmaps to Drift, per-track Challenge and Time Attack only; completed stages can be replayed, the next stage is available, and future stages are locked.
- [x] Use owner-confirmed Drift targets 700 / 1000 / 1300 / 1600 / 1900, each in 90 seconds. This confirmed answer supersedes the original conflicting 2300 endpoint and the old 1200 single target.
- [x] Scale Challenge clean three-lap targets and Time Attack start/checkpoint-extension budgets by 130% / 115% / 100% / 90% / 80% of existing course baselines. Fix Time Attack to three laps; capture stage at run start and reject invalid, automated or experimental progression.
- [x] Show reached stage, selected target and stage status in course setup and race/results feedback. Persist bounded progress in schema 14, isolate tracks/profiles, clear roadmaps with challenge awards on reward reset, and keep timed countdowns.
- [x] Strict rendered roadmap/state/persistence verification and short physical countdown regression pass. Raw failures retained and all owned processes exited. See [evidence](../../docs/verification/challenge-roadmaps.md).
- [ ] Balance the provisional non-drift scales and physically demonstrate each final target across courses/classes with owner driving feedback. Fixture completion is not a claim of target attainability.


## New-track race verification — owner update, 5 October 2026

For each new track, test one Beach Buggy race on Hard only. Use Freestyle when the standard assigned class differs, without changing that assignment. This replaces prior per-track vehicle, stat-build and difficulty matrices and additional mode race runs. Retain source/corridor topology, height/support, checkpoint/flag, relevant control/menu/loading checks, failure evidence and isolated-process cleanup. Untested additional mode capabilities remain disabled until separately requested.
