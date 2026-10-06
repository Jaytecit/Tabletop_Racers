# Vehicle effects — Task 12

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

5 October 2026. Implementation and technical verification complete. **Owner visually approved the revised look on 5 October 2026; Task 12 complete.**

![Final effects review](vehicle-effects-media/preview.jpg)

## Changes and ownership

The active 3D car now owns `scripts/vehicles/vehicle_effects.gd`; RaceFeedback still owns event validation, proximity filtering, cooldowns, audio, shake and rumble. Existing Smoke, Sparks and Debris nodes are reused. One second tyre emitter and one dedicated blue/white boost exhaust emitter are created per car. Impact sparks use the actual collision point and normal. Smoke expands from measured rear-wheel contact points; loose/off-road terrain produces tinted dust. Braking and lateral slip control intensity. The alpha-mask smoke shader avoids dark patches from overlapping greyscale sprite RGB.

Four narrow physical tyre rays run at at most 20 Hz, only when tyre effects are needed. Each hit is checked against the measured racing corridor and surface rules. Airborne/water contact effects stop immediately. Boat boost works; a boat never gains fictional rubber tyres or marks. Dry land-assist driving remains permitted in Freestyle. No active course supplies a normal boat-only water race, so the water suppression rule is additionally verified with a controlled cosmetic surface fixture.

`scripts/vehicles/tyre_marks.gd` owns one fixed mesh/material per car, with 128 recycled strip slots (64 in reduced mode). Strips follow individual contact positions/normals, offset 12 mm, and fade over seven seconds. A sustained drift can recycle older slots before that lifetime. Lost contact, teleports, recovery, course switching and abrupt height/normal changes break connections. Settings transitions clear the previous larger allocation. Pausing freezes all emitters and the fade clock; finished/menu cars stop emission and race cleanup clears effects.

Normal capacity: **96 particles/car, 384 total**, including both one-shot channels. Reduced: **40/car, 160 total**. At most eight one-shot channels exist across four cars. Node/material counts do not grow with repeated events/races. CPU particles were retained after profiling the existing Forward+ renderer at these bounded counts; converting to GPU particles was unnecessary for this implementation. Reduced mode lowers particle/strip allocations; these short timing samples do not establish a frame-time advantage for it.

The 2D `race_particles.gd`, `car.gd` and `skids.gd` match the preserved baseline snapshot. Track sources, measured route geometry, canonical Toys R You data, handling equations and scoring were not edited. The physics replay measured **zero** position/velocity deviation, identical boost use and matching gates/laps with the effect owner enabled/disabled.

## Textures

Kenney Particle Pack, CC0: [official source](https://kenney.nl/assets/particle-pack). The supplied archive licence identifies version 1.1; the website labels its release 1.0. Exact download, retained licence, selected files and attribution are recorded in [the asset manifest](../../assets/effects/kenney/README.md). Smoke 01, Spark 05 and Light 01 are included unchanged. Smoke 04 is retained only as evaluation evidence. In-game Asset Credits now includes Kenney. Expansion/fade gradients and the mark/smoke shaders are locally authored. No external skill was installed; the skills.sh check did not improve on the project-specific Summer/GDScript guidance.

## Rendered evidence

In these fixed-camera comparison clips, **old effects are on the left; revised effects on the right**. The five controlled fixtures run real vehicle physics/input; the comparison impact is an event fixture, supplemented by a physical wall collision in the main suite. Each clip has 12 rendered samples, three physics ticks apart, played at 8 fps (2.5× slower). Full source frames are retained. Before/after travel matches exactly in all five fixtures.

- [Drifting](vehicle-effects-media/drift-before-after.mp4)
- [Braking](vehicle-effects-media/brake-before-after.mp4)
- [Boost](vehicle-effects-media/boost-before-after.mp4)
- [Impact](vehicle-effects-media/impact-before-after.mp4)
- [Loose/off-road dust](vehicle-effects-media/dirt-before-after.mp4)

[All final close-ups](../../tests/baselines/vehicle_effects/all-final-captures.jpg) cover all five classes, daylight/night, Mount Rainier surface heights/normals and Toys R You crossing/bridge samples. The forced close-angle Bazaar image is obstructed by source scenery; [the separate gameplay-camera probe](../../tests/baselines/vehicle_effects/drift-gameplay-camera/results.json) verifies and captures Drift Challenge through its real camera instead.

The final main suite passed **150 assertions** in 49.156 seconds: five classes in Freestyle, assigned tabletop/road Quick Race classes, Drift Challenge, real boost/brake/recovery/pause inputs, real collision sparks, airborne/water suppression, strip fade/discontinuities, normal/reduced transitions, three repeated runs with zero node growth, and four simultaneously emitting AI cars. [Raw result](../../tests/baselines/vehicle_effects/verification-final03/results.json). The separate Drift Challenge camera probe passed three checks in 5.48 seconds.

## Matched performance

RTX 4060 Ti; Summer 4.7.2 custom build, Forward+; reported viewport 1200×800; 600×400 world pixel effect enabled; 60 FPS cap. Four neutral-build AI cars, fixed seeds 64/128/256/512, Toys R You, 120 warm-up physics ticks and 600 measured ticks. Before uses a separate snapshot of the original owners, with the same imported scenery/resources and probe. No performance runs overlap.

| Effects | Samples | Median frame ms | p95 frame ms | p95 process ms | Median draw calls |
|---|---:|---:|---:|---:|---:|
| Before, normal | 600 | 16.651 | 17.741 | 4.051 | 120 |
| After, normal | 597 | 16.585 | 18.978 | 4.517 | 125 |
| Before, reduced | 600 | 16.659 | 17.911 | 4.052 | 120 |
| After, reduced | 600 | 16.570 | 19.133 | 4.396 | 125 |

Median pacing remains approximately 60 FPS. The normal p95 frame tail rises **1.237 ms (7.0%)**, and reduced rises **1.222 ms (6.8%)**. Normal p95 process cost rises 0.466 ms, reduced 0.344 ms. Investigation removed unnecessary contact queries on ordinary straight-line driving and kept fixed particle/strip caps. These are short, sequential development samples, not a universal performance guarantee or an owner benchmark. The remaining frame-tail increase is explicitly retained for review. [Machine-readable measurements](vehicle-effects-media/performance.json).

## Failures and cleanup

All raw runs remain under `tests/baselines/vehicle_effects/`. Initial before/after comparison runs exposed a generated UID-cache omission for the unchanged `showcase_track.gd` sidecar. The existing mapping was restored in generated cache, without editing route data or scene files. `after01` exposed marks being added while the parent was building children and feedback being read before configuration; marks now belong to the effect owner with an independent world transform. `after02`/`after03-verbose` exposed two audio objects retained on probe shutdown; the harness now stops its audio before exit. Verbose output also exposed installed Vulkan-layer warnings. `verification01` used an untyped empty test array and timed out; it was corrected. `verification02` exposed a one-frame-late live-strip count; mesh sampling now updates it immediately. `verification-final` assumed a high-grip racing car would still be smoking after it had aligned; the fixture now asserts actual smoke onset before grip settles. Earlier snapshots with dark smoke are retained; the alpha-mask shader fixes that appearance in the final captures.

`verification-final03`, `drift-gameplay-camera`, both `before-final-*` and both `after-final-*` finished with no captured errors/frame warnings or shutdown errors. Their exact owned PIDs exited. The final process inventory contained only the user's existing editor, PID 41644. No editor or other project was stopped.

The owner explicitly approved the revised look on 5 October 2026. All Task 12 checklist items are complete.
