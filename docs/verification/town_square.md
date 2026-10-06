# Town Square integration — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Town Square is registered as ROAD / racing_car in Quick Race, Time Trial and Freestyle. It uses the original cobblestone village model, independent driving-mesh boundaries, source checker timing line and original START arch. No permanent generated road edges are added.

## Source and geometry

[Original source](https://sketchfab.com/3d-models/town-square-track-410edb9f4ce0433981e91c05e7a225dd), amogusstrikesback2, CC BY 4.0. SHA-256 `fc8a380a213968eb9d41309d8454c20a2fbac04f8af8dc5c192e06a46586a131`. Credits are retained beside the course, beside the imported models and in the game's Asset Credits.

The explicit 293-triangle `Track5_TownSquare_Collision_Track5_TownSquare_Collision_new_0` driving primitive forms one valid annulus. Wall collision is excluded from measurements; visible source meshes and the separate walls supply physical scenery collision. Every ancestor transform is accumulated. Authored scale is 100, offset `[-3.69376, 0, 0.03596]`. Three separated engine landmarks agree after disabling mesh compression. Collision transforms are baked at unit scale.

54 sections contain 1,296 spans, 25 samples per section, exact cyclic joins and independently barycentric-sampled left/right/centre heights. Length is 285.79084 units; sampled width is 7.48276–11.12937. The source is flat with no conflicting driving layers. Original outer/inner corners are retained; the monotonic boundary pairing passes 12,960 source checks and 7,776 boundary-residual samples. Numerical residual to selected mesh boundaries is near machine precision; this does not imply that textures agree to machine precision.

Source UV raster spacing is 0.04 game units for the route review and 0.05 for the checker review. Every depth-tested section, seam and overview was inspected. The boundary is the dedicated road-facing kerb/barrier perimeter, including raised kerb width where selected by the source collision. Decorative white inset lines are not treated as the road edge. Side-road exits are excluded by the source driving perimeter. There are no unresolved route intervals or invented bridges.

The checker band is located from a reviewed source-UV mask and a fitted band midplane. Timing station is 285.64942; centre position X/Z is `[27.72760, 1.85667]`. Actual gameplay direction uses samples ±0.25 units, matching the runtime. The timing-plane residuals at the measured boundaries are 0.14040 / 0.14063 units within the measured 0.24194 checker half-width. The source START arch and stripe remain visible; gate zero reuses them. Gates 1–7 use supported, clearance-checked cues at the actual planes. The diagnostic overlay is disabled in normal play.

Source evidence: `tests/baselines/content/town_square/source01`, `extraction01` and `candidate02`. Candidate02 passes 3,888 physical support rays, 6,480 containment cases, runtime validation, landmark checks and rendered section capture. Source extraction profiles and cue measurement scripts remain under `tools/tabletop_reference/`.

## Gameplay

`race01` passes four racing cars, three Hard laps, seeds 64/128/256/512: finish times 79.515 / 79.847 / 79.620 / 80.278 seconds, zero crashes, AI recoveries or gate penalties. Ordinary contacts occur. It also passes 3,888 authored support checks, 480 forward/reverse/repeat/skipped/wrong-height gate cases, flags, real throttle/boost/reset, pause and switching. This first run still has generated finish flags; `full01` verifies the final source-cue reuse.

`full01` passes the final geometry, flags, controls and a full player upgrade build. All four finish three Hard laps in 67.286 / 70.291 / 73.151 / 70.891 seconds without crashes, recoveries or gate penalties. Its regression checks pass 6,960 canonical Toys samples with zero boundary error and procedural polygons/containment/markers. All ten previously measured route hashes match the pre-staging snapshot.

`menu01` passes actual course-selector signals, assigned racing-car preview/label, Quick Race motion/pause/retry, one clean Time Trial lap and return, plus Freestyle truck retention through procedural/course switching. It exercises a process-local staged catalogue; production checks remain required.

`classes01` completes clean solo Freestyle laps in all five classes: buggy 26.875s, monster truck 27.774s, racing car 24.233s, drift car 27.497s and speedboat 37.488s. All have zero crashes/recoveries/penalties, using the existing off-environment rules. Its strict wrapper fails on a startup UID warning; `classes02` passes the same results with clean startup/shutdown. These races do not establish owner balance or a water-course claim. The owner's subsequent instruction reduces future new-track race verification to one Beach Buggy race on Hard; this completed evidence is retained, and no further vehicle/difficulty matrix is required.

`registered-menu01` passes the unmodified production selector, assigned label/preview, Quick Race movement/pause/retry, clean Time Trial finish, Freestyle switching, and evidence-local selection/record save and reload. All three enabled capabilities pass; the five untested modes remain unavailable. The fixture reports `production_registered=true`.

`registered-lifecycle02` passes rapid switching, stale worker cancellation, Back, failed/invalid loads, recovery and the bounded cache. `registered-loading01` passes cold/warm asynchronous presentation and Start-readiness checks. Read-only profiles and hardware-input isolation remain active.

## Performance and remaining acceptance

RTX 4060 Ti; Summer 4.7.2 custom build; Forward+; reported viewport 1200×800; world pixel filter disabled. Four neutral reference rivals use the same seeds; only the player's full build differs in `full01`. No performance tests overlap. Neutral racing frame p50/p95 is 14.048 / 28.042ms; full-player run is 12.873 / 29.707ms. The same-machine accepted Toys R You comparison (`toys-performance01`) records 12.098 / 33.837ms, with 156 median draw calls; Town Square's full-player race records 92 median draw calls. The comparison uses each course's assigned class (buggy versus racing car), one Toys lap versus three Town Square laps, and is descriptive rather than an identical-physics benchmark. The shared 16.7ms p95 target remains unmet. Release loading and human driving/AI calibration are not claimed.

Production cold selection is ready in 1.603s, visible in 1.667s; warm repeats are ready in 0.685–0.887s, visible in 0.738–0.938s. Town Square's worst sampled process gap is 124.618ms cold and 116.624ms warm; its measured static memory is about 130.27MiB. Procedural switching peaks at 219.231ms and 132.98MiB. These remain below the existing 250ms/220MiB development budgets. Resource loading, background validation, instantiation and first presentation breakdowns are retained in the raw JSON; first presentation includes shader work rather than a separate GPU timer. The earlier staged loading results remain in `loading01`.

Only modes with recorded coverage will be enabled. Town Square Challenge, Time Attack, Elimination, Tournament and Drift remain disabled pending separate course-specific trials and target review.

## Failures and cleanup

`candidate01` retains a 0.001321-unit compression-induced landmark error and a stale existing script UID warning. Compression was disabled and the candidate rerun passed. `starting01` completes the same starting-build three-lap race and both geometry regressions, but its strict wrapper fails on stale script/new-resource UID warnings. A fresh editor entry save registers the new resource identities. `classes01` retains one script UID warning despite passing every gameplay assertion. The existing `showcase_track.gd.uid` is correct; only its generated cache mapping was restored. No gameplay source or accepted geometry was changed to suppress those warnings. An authoring helper attempted an unavailable `ResourceUID.update_cache()` method and failed to compile before execution; its result is preserved in `source01/editor-script-failure.json`. The reimport used the supported live editor filesystem API instead.

`registered-lifecycle01` fails only its outdated expectation that Back always returns to Vehicle. The owner-requested menu flow returns assigned-vehicle modes directly to Character. The shared probe now derives the expected step from the mode; production code did not change. `registered-lifecycle02` passes.

All evidence and failures are preserved. Every owned rendered test has a non-forced exit receipt and its PID is absent. Final inventory retains the user's editor (41644) and its user-launched game (3800); neither was stopped. Final passing runs have no captured errors, frame warnings or shutdown errors. All existing measured-route hashes remain unchanged. Town Square's technical integration is complete for the three enabled modes; owner driving acceptance, other mode trials, the shared frame-tail target and a release loading comparison remain open.

Live editor diagnostics at handover report zero observed project/debugger errors, eight compiler warnings and four unclassified Unicode parsing messages. Those messages are distinct from the final disposable probes, which are clean.
