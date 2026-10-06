# Mount Rainier ground — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

## Dirt sidings and source barriers — owner correction

The owner identified the light brown `road_road_PIVOT_road_tracks_0` surface as solid dirt siding, superseding the earlier artwork exclusion below. It now supplies source triangle collision and terrain normals. Asphalt remains the full-speed route; the existing shoulder handling progressively brakes to half speed and disables road boost. Four source barrier primitives now all have double-sided collision, including the three previously omitted meshes. The incremental environment updater and full authoring manifest preserve these selections. No route measurements or model transforms changed.

`tests/baselines/ground/sidings_02` verifies 898 siding triangle centres, eight slow/fast player/AI drives in both directions (zero crashes, slowdown and boost restriction), 27,568 barrier ray checks from both sides, 20 blocked vehicle sweeps, and 9,144 asphalt support samples. Runtime and shutdown logs are clean; both owned test PIDs were confirmed exited. Narrow backups are in `sidings_before`; texture identification evidence is `siding-textures.png`.

The initial combined `sidings_01` result remains failed: eight checkpoint assertions fail at gate 5's two outer banked lanes. `sidings_02` disables only the newly added colliders and repeats the checkpoint fixture: all eight failures are identical, establishing no checkpoint regression from this change. Its passed status means the siding/barrier/support checks pass and checkpoint results match baseline, **not** that all checkpoint assertions pass. No full-race rerun was performed for this collision-only correction.

Added source-derived collision for five grass/soil/rock terrain primitives and three road-side primitives, identified in `measurement_manifest.json`. Four reversed grass faces require double-sided triangle collision. Supported terrain supplies its measured hit height/normal; existing slower off-road handling and road-boost restrictions remain. No infinite catch floor, legal-route widening or generated road edges were added.

`author_mount_rainier.add_ground_collision()` saves only the environment under the recorded source hash. The full authoring recipe preserves the same selection. Source GLB, Mount Rainier measured route/definition, canonical Toys R You route/definition and procedural Game Table definition remain byte-identical to the protected hashes. Narrow pre-change backups are in `tests/baselines/ground/source_before`.

## Passed checks

- `mount_rainier_final`: 2,757 actual terrain support samples, 40 player/AI drives over selected ground in both directions at slow/fast speeds, 9,144 asphalt support checks and 480 checkpoint checks. No gameplay errors, frame warnings or shutdown errors. Ground drives retain slowdown, boost restriction and finite supported motion.
- `edge_regression`: 288 Toys R You bridge-layer support checks and 57 procedural-course support checks, no failures. Their colliders do not receive the terrain-normal override.
- All four cars complete the Hard three-lap race in approximately 271–273 simulated seconds, without checkpoint penalties or AI stall recoveries.

## Preserved initial race failure (resolved below)

The strict zero-crash race assertion **fails**. `mount_rainier_race_trace` repeats the current collision run: cars 2 and 4 each fall once, at `(68.26649, 5.879245, 92.55347)` and `(69.60031, 5.889303, 92.0068)`. Both are classified shoulder with no physical ray hit. `mount_rainier_race_original` swaps only the evidence-backed original environment into the isolated test: car 4 falls at the same point; car 2 does not. Thus the current change is not represented as a clean full-race pass.

Source-triangle inspection at car 4's point finds only `road_road_PIVOT_road_tracks_0`, height 5.891107: tyre-track artwork, excluded from the accepted asphalt extraction. This requires further source/topology review before any collision or driving adjustment; do not promote that artwork into a new legal corridor or hide the failure with a catch floor. This was the outstanding gate at the initial checkpoint; the source and footprint investigation below resolves it without adding collision to tyre-track artwork.

All test instances exited and their exit records remain. Failed missing-collision, reversed-face, unsuitable-drive-path and overlapping-height fixtures are preserved, including earlier shutdown/UID warnings; final focused checks have clean logs. Task 4 was partially complete at that checkpoint. Tasks 5–12 have not been implemented.

## Completed footprint support gate — 5 October 2026

Source triangle inspection under the canonical transform places the two failed origins only 0.01629 and 0.00162 units outside asphalt. Nearby terrain is 0.75–0.93 units away; the tyre-track artwork is the only mesh containing those centre points. The car still overlaps real asphalt. The failure was centre-only support treating this partial contact as total loss of floor. [Source audit](../../tests/baselines/ground/footprint-source-audit.json) preserves the measurements.

`arcade_car.driving_support()` retains the original centre ray and, only when it misses on an imported shoulder, tries front/rear contacts on the same side within the vehicle collision footprint. Both must hit upward-facing physical surfaces within 0.12 units of the route height; their measured plane supplies height/normal. Raised and guarded edges retain point-support rules. This does not change legal boundaries, source geometry, collision selection or off-road slowdown/boost rules. Tyre-track artwork remains excluded.

Fresh rendered evidence under `tests/baselines/ground/`:

- `footprint_03`: both original failure points resolve to real asphalt contact within 0.002 units of their recorded height. Raised/guarded variants and absent floor reject fallback. All 15,240 alignment, 9,144 road-support and 480 checkpoint checks pass; the reviewed overhead frame shows the partial asphalt contact.
- `footprint_race_03`: four cars complete three Hard laps with seed 3098, finish times 270.913–271.950 simulated seconds, zero crashes, recoveries or checkpoint penalties. Ordinary impacts are 0/50/33/40. The isolated runner uses 180 ticks/second and time scale 3, retaining a 1/60-second simulation delta, with rendering capped at 60 to avoid the engine's frame-count exit ceiling. This accelerated run is correctness evidence, not a performance benchmark.
- `footprint_ground`: all 2,757 terrain samples, 40 slow/fast player/AI drives in both directions, 9,144 road-support and 480 checkpoint checks pass. Slower shoulders and disabled road boost remain verified.
- `footprint_edges`: 288 Toys bridge-layer and 57 procedural support checks pass.
- Final runs have `finished=true`, `passed=true`, no recorded runtime/frame/shutdown errors and process-exit records. Exact owned PIDs were checked absent.

The initial `footprint_01` abort exposed an existing indentation error in `author_tabletop.gd`'s terrain collision loop; it is corrected. That owned child was explicitly stopped and its exit recorded. `footprint_02` passes gameplay assertions but retains a stale UID warning. Re-saving the race scene through a fresh editor refreshed resource discovery; scene bytes stayed unchanged. `footprint_race_01` and `02` retain incomplete results caused by uncapped rendering exhausting the engine's frame ceiling. Intro cleanup now restores the disposable opening before freeing it. None of these runs is relabelled as passing.

Protected Mount Rainier/Toys measured routes and definitions, Game Table definition and Mount Rainier source GLB remain byte-identical to pre-change hashes in `footprint_source_before/protected-hashes.json`. Narrow code/scene backups are alongside them. Editor diagnostics report zero errors and five pre-existing warnings; disposable final runs have clean logs.

Task 4 is complete. The next implementation phase is Task 5 developer overrides, followed by Task 6 menu/export.
