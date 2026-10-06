# Mount Rainier road geometry and vehicle scale

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

The original geometry extraction and scaled asset are saved. The subsequent playable-course integration is recorded below.

- Source: `C:/Users/jayte/Downloads/gt_racing_2_-_mount_rainier.glb`; hash and embedded attribution are in `tracks/mount_rainier/measurement_manifest.json`.
- Selected asphalt: `road_road_PIVOT.001_road_0`, `road_road_PIVOT.002_road_marking_0`, `road_road_PIVOT.003_road_clean_0`. Their projected triangle union forms one valid polygon with one hole. Tyre-track overlays, roadside pavement and scenery are excluded.
- Independent outer/inner loops have 742/772 vertices; each vertex's height is sampled barycentrically from source triangles. No missing boundary support or conflicting road layers were found. Both loops retain the source corners.
- Uniform scale: 0.3351188922100969; translation: (80.9524777411073, 0.057935893948907816, 84.92932520283094). Applied equally to the entire model and the measured boundaries. Road footprint is approximately 286.37 by 209.71 units, with 12.52 units of elevation change.
- Summer measured the built buggy's visual AABB as 1.05637 long, 0.82 wide, 0.771 high. Its collision box is (0.85, 0.4, 0.54).
- At one-source-unit stations on the inner edge, supported chords to the nearest outer edge give widths of 3.91 minimum, 6.00 median and 11.54 maximum game units. This is a clearance statistic, not a paired gameplay route. Narrowest sampled clearance is approximately 4.77 visual buggy widths.
- The scaled GLB preserves the original binary geometry/textures byte-for-byte. All 51 primitive transforms match the manifest to a maximum residual of 1.71e-13 source-analysis units. The engine subsequently loaded all 51 meshes successfully.
- First engine load failed before filesystem discovery/import. A filesystem scan resolved it; the initial failure is retained in the evidence directory. No project scene was changed by these inspection scripts.

Evidence: `tests/baselines/content/mount_rainier/` contains the original inventory, UV-rasterized source road, topology overlay, native boundary coordinates, geometry checks, vehicle audit and engine-import audit. Game-space boundaries and manifest are under `tracks/mount_rainier/`; scaled model is `assets/imported/racing/mount_rainier.glb`.

Reproduce with the bundled Python interpreter: `python tools/tabletop_reference/inspect_mount_rainier.py`. Requires NumPy, Pillow and Shapely. The script writes only Mount Rainier outputs.

At the original geometry-only stage, ordered cross-section pairing, collision, checkpoints and gameplay verification were pending. These boundaries define the asphalt perimeter, rather than lane markings or a barrier's road-facing edge. Existing accepted track resources and shared runtime code were not edited.

## Playable-course follow-up — 2026-10-03

Mount Rainier has been added to Quick Race and Time Trial using the original GLB and the same recorded transform. The paired route has 3,048 spans in 127 sections and a 971.50-unit loop. Monotonic dynamic-time-warping pairs the independent asphalt rings; each edge stays on its source ring, while centre heights are sampled independently from the road triangles. The source comparison found no folded/exterior polygons, a maximum boundary-span residual of 0.07442 units and a 99th-percentile residual of 0.00784 units, within the 0.16756-unit source analysis pixel spacing. Three separated imported landmarks agree within 0.000031 units (0.001 tolerance).

The environment contains 50 flattened visible meshes, excluding the remote lens-flare mesh, with selected road, shoulder and barrier collision. Mesh compression is disabled. The existing neutral wood handling preset is used for asphalt, with no shared vehicle-handling changes. Eight ordered checkpoints get generated numbered/FINISH flags, with physical shoulder support or clear same-plane elevated placement. The shipping route overlay stays disabled. Asset credits have been added to the game and imported-asset documentation.

Verification evidence under `tests/baselines/content/mount_rainier/`:

- `verification_initial/results.json`: all 9,144 physical support checks, 15,240 containment checks, 480 checkpoint cases and initial flag checks pass. The combined run hit the runner ceiling before completion; its `finished=false` remains preserved.
- `race_verification/results.json`: soft timeout after more than two clean laps; preserved without relabelling as passing.
- `race_final/results.json`: hard rendered-frame ceiling after more than two clean laps; preserved without relabelling as passing.
- `race_completed/results.json`: four cars complete three laps on Hard in 254.76–258.67 seconds, with zero crashes, AI recovery resets or penalties. Ordinary car impacts occurred. Physics remains at 60 Hz; fixed simulated rendering at 30 FPS avoids the verification frame ceiling. Rendering is uncapped in this isolated probe to finish efficiently; this run is not a normal-settings FPS benchmark.
- `visual_verification/`: initial visual helper failure because the shipping debug overlay is disabled and therefore absent. The exact owned process was stopped and confirmed exited; its error logs are retained.
- `visual_final/results.json`: passes all eight checkpoint placements initially, after rebuild and after switching courses; Time Trial; actual player throttle/boost/recovery; pause/resume. No gameplay errors or frame warnings. Reviewed X-ray/depth overviews, every one of the 127 section frames and all gate close-ups. The temporary overlay exists only in this disposable probe. Normal-settings sample on the RTX 4060 Ti: 60 FPS, 18.14 ms process time, 271 draw calls, 504,985 rendered triangles and 100.16 MiB static memory. This matches the accepted course's previously recorded 58–62 FPS range; it is not a fresh simultaneous baseline comparison. Selection took 34.02 seconds, largely from the current route-validation path; load-time optimization remains a limitation.

All isolated test PIDs were confirmed exited. Some incomplete race runs emitted the existing resource-in-use/ObjectDB shutdown warning; their stderr is retained. The completed race and final visual probe recorded no gameplay errors. Original Toys measurements and existing procedural course data remain untouched; shared containment, handling, checkpoint and rendering algorithms were not changed. Catalogue/menu additions append the new ID and title.

Rebuild the accepted course with `author_mount_rainier.gd.build()` via Summer editor scripting; this reapplies the saved route. Intentional remeasurement uses `prepare_mount_rainier.py --replace`, followed by a full rebuild and verification; the source-only audit no longer overwrites a playable manifest.

The default playable course remains selectable through the regular menu. `scenes/mount_rainier_test.tscn` is a dedicated human-test launch that selects Mount Rainier, one lap, three Normal rivals and the existing buggy, with normal hardware controls active.

The requested human session was launched through Summer with focus enabled and left running. A live rendered probe showed the buggy driving on Mount Rainier with LAP 1/1; editor/runtime diagnostics reported zero errors and zero warnings.

## Owner-identified start/finish correction — 2026-10-04

The owner's image identifies the double transverse marking on the southwest town straight. `tools/tabletop_reference/measure_mount_rainier_start.py` measures its two continuous bright stripes from source road geometry and UV textures, rather than tracing the screenshot. The imported source hash matches the canonical manifest. Their midpoint is source-route station 949.846184, 21.65625 units behind the previous origin, at game position (-85.885205, 0.049022, 86.153646). The timing plane, grid, FINISH flags and preview now derive from that station; route revision is 2.

`measured_route.json` remains byte-identical (SHA-256 `936a43ffe17b15bdd2f2ad5077f8075c7b46f3ac6c9de0ae8ed833a8a210738f`); section geometry, source model and transform remain unchanged. The definition change gives Time Trial a new content signature: previous records/ghosts are no longer comparable. Existing profile data is not migrated or erased here; the existing incompatible-record notice appears, and normal record saving replaces an incompatible personal best after a valid new finish.

Evidence:

- `start_alignment/`: owner's images, measured source marking, numeric measurement and old/new timing-plane comparison.
- `tests/baselines/development/start_ui_initial/` and `start_ui_final/`: failed UI-layout runs preserved. `start_ui_corrected/`: finished and passed, no gameplay errors/frame warnings. All 9,144 support checks, 480 direction/repeat/skipped/width/height checkpoint cases, timing/grid alignment and eight flag placements pass. Reviewed the source agreement and all gate close-ups. The same probe verifies the new start lights and requested menu/recovery/licence corrections.
- `start_race/`: finished and passed. Four cars complete three laps in 254.52–258.41 seconds, with zero crashes, recovery resets or penalties. Ordinary impacts are 3/0/1/5. This isolated fixed-render-30-FPS, physics-60-Hz run is a completion check, not a normal-settings performance benchmark.

Owned test PIDs 45672, 164088, 141304 and 19860 were confirmed exited. Final UI/race stderr retains ObjectDB leaks and one resource-in-use shutdown warning; gameplay error and frame-warning lists are empty. Before-change resources/scripts are retained in `tests/baselines/development/start_line_before/`. Owner acceptance of the new line and light presentation remains a human test.
