# Task 10 — bedroom skybox presentation

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Completed 5 October 2026 following the owner's updated scope: no drawn table or legs; centrally framed tracks are accepted without further tests. Enabled in course-entry metadata for Town Square, Bazaar, Mount Rainier and Topspeed Oval. Other existing tabletop/procedural presentations are preserved.

The supplied `skybox_stylized_room.glb` provides the 1024×512 bedroom panorama. Its source sphere UV orientation requires a vertical flip for `PanoramaSkyMaterial`; `tools/author_bedroom_panorama.gd` rebuilds the mipmapped runtime texture. Credits are recorded in-game and in `environments/bedroom/SKYBOX_CREDITS.md`. The sky uses a 65° FOV override to avoid orthographic stretching. Because it is translation invariant, every camera is centred in the sky regardless of course bounds, without changing accepted course transforms. The shared runtime helper adds no meshes or colliders, preserves existing lighting settings, restores the original environment on course switches and also configures the course-selection flyover.

## Retained prototype evidence

These results precede removal of the prototype table; they are evidence for the earlier implementation, not new test results for the final scope.

- `tests/baselines/presentation/bedroom/town_square_01`: interrupted failed harness run. The profile picker blocked setup and covered screenshots. Explicit child-process exit confirmation retained.
- `town_square_02`: four Beach Buggies finished three Hard Freestyle laps in 77.969–81.615 seconds, with zero crashes, recoveries or penalties. Raw `passed` is false solely for outdated car/track hash expectations; both actual hashes match the accepted Town Square `full01` and `race01` records. Orthographic sky stretching was subsequently corrected. Raw evidence remains unchanged.
- `town_square_visual_03` and `town_square_final`: clean passing rendered probes, including corrected projection, source bounds/collision preservation, camera views, restored environment and (final) production-menu framing. Same-view p95 comparison in visual_03: 30.942 ms original / 31.583 ms prototype presentation.
- `bazaar_01`: interrupted failed resource opt-in; the presentation property preceded script attachment and was ignored. Runtime errors and child-exit evidence retained.
- `bazaar_02`: all report assertions pass; four Beach Buggies finished three Hard Freestyle laps in 72.011–73.961 seconds, zero crashes/recoveries/penalties. Strict wrapper fails for an existing UID fallback warning, which remains in raw evidence. Same-view p95: 31.098 / 32.497 ms.
- `bazaar_final`: clean passing rendered/menu/switch-restoration probe.
- `mount_rainier_01`: stopped before racing on the generic flat-road 0.02 support tolerance. Nine samples differed by 0.0205–0.0230 units; its established banked-road helper uses 0.10. Source geometry was not changed. Flags, 480 gate cases and presentation checks passed; raw support failure retained.
- `mount_rainier_02`: rerun using the established helper; race intentionally interrupted when the owner accepted all centrally framed courses and removed the table requirement. No completed race is claimed. UID fallback warnings, partial progress and explicit PID exit confirmation are retained.
- Topspeed Oval and the final sky-only implementation are accepted under the owner's updated instruction; no additional rendered/race tests were run.

All launched test instances used read-only profiles and hardware-input isolation. Each completed or interrupted child has process-exit evidence. No user editor was stopped. Source/corridor/height/manifest hashes are preserved in `tests/baselines/presentation/bedroom/source/preserved_hashes.json`. Failed evidence was not overwritten. The earlier shared 16.7 ms p95 target remains outside this task's acceptance; prototype figures above do not establish it.
