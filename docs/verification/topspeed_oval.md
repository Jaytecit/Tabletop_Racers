# Topspeed Oval verification

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Verified on 2026-10-03. Select **Topspeed Oval** from the normal course menu in Quick Race or Time Trial. This course uses the raised stadium oval; surrounding asphalt routes and drag strips are scenery, outside its driving corridor.

## Source and measured route

- Source: `tracks/GLB Tracks/gt_racing_2_-_topspeed_oval.glb`; SHA-256 `6478db57e4c7687eb536bb97efb7ca368ee4e0f76afcb5aef4b9448b5a179749`. Imported copy matches exactly. Embedded attribution is included in the in-game credits and imported asset credits.
- Independent road boundaries and centre heights from the two selected road primitives, using the automated annular-road extractor. No screenshot trace or fixed-width corridor.
- Uniform scale 0.27851315418728406; offset (1.431903682068566, 0.008565070662936065, -0.05681589257821017). 1,152 measured rows, 48 sections, length 341.98269; width min/median/max 5.86052 / 6.03581 / 8.29449. Single road layer, no unresolved intervals.
- Separate original checker mesh `race_start_node001__4_-_Default_0` identifies the oval start, distinguished from the two drag-strip cues. Start station 86.1174513, clockwise X/Z. Actual gate-plane edge intersections lie within 0.025625 of the stripe plane, below its 0.339219 half-width. See `playable_geometry/source_start_cue.json` and `runtime_start_cue.json`.
- 267 visible meshes; sky helpers excluded. Collision uses the two oval-road nodes and reviewed cement shoulder/frame node. Geometry compression disabled on the imported source to preserve measured correspondence. Existing shared unshaded baked-colour convention retained.
- Source containment: 11,520 checks. Boundary residual: 6,912 samples, maximum 0.00507035 versus 0.05 tolerance. Candidate import landmarks max error 0.000001908; rendered candidate physical support max error 0.00181443 versus 0.02 tolerance. Source raster, X-ray/depth overview and all 48 section close-ups are retained in the extraction/candidate evidence.

## Playable acceptance

`tests/baselines/content/topspeed_oval/playable_corrected/results.json` finished and passed:

- 3,456 actual collision support checks, 0.02 height tolerance; 5,760 runtime inside/outside corridor checks; 480 checkpoint cases across four cars, three lanes and forward/reverse/wrong-height/repeated/skipped crossings.
- All eight checkpoint planes have readable, non-colliding cues outside the driving corridor. Placement/support/layer/clearance checks passed initially, after rebuild and after switching away/back. Existing finish paint retained; same-plane FINISH cue added. Elevated fallback used where shoulders cannot safely support a pole.
- Four Hard AI cars completed three laps in 73.61-76.25 seconds, with zero crashes, recoveries or checkpoint penalties. Ordinary car contacts occurred (0-4 impact counts).
- Real synthetic player throttle/boost input, manual recovery to supported driving state, pause/resume, course switching and Time Trial selection/driving passed. Recovery deliberately records one reset/crash, separate from the clean race.
- Menu, source finish stripe, all eight gate close-ups, driving, results, Time Trial and credits were rendered and reviewed. Preview/minimap match the selected oval. Normal route overlay remains disabled; no permanent generated road edges added.
- RTX 4060 Ti sample: FPS min/median/max 59/60/61; 376 draw calls, 376,384 rendered triangles, 106.38 MiB static memory. Prior Mount Rainier evidence recorded approximately 60 FPS, 271 calls, 504,985 triangles and 100.16 MiB; this is a recorded comparison, not a simultaneous benchmark.

## Retained failures and limits

`playable_initial` failed 67 height checks because the reused probe averaged both edge heights across the banked cross-section, disregarding its independently measured centre elevation. The corrected probe uses the measured centre and near-edge samples; the 0.02 tolerance was retained. Initial containment/checkpoints/flags passed. No route data was changed to satisfy this correction.

The earlier compressed candidate import failure and successful uncompressed runs remain documented in `docs/automated-road-extraction.md`. Both playable runs contain no runtime gameplay errors. The completed run emitted the existing ObjectDB/resource-in-use warning during process shutdown (4 instances, 1 resource); matching shutdown warnings exist in prior Mountain race evidence. Raw stderr is retained, rather than treating that warning as a gameplay failure or hiding it. Editor diagnostics reported no observed project errors/warnings; their scope is not full-project validation. Source material UV and existing case-path import warnings remain as documented by the geometry proof.

Test instances were separate rendered offscreen `--summer-verify` processes, profiles read-only, with controller processing disabled. PIDs 21616 and 85428 were confirmed exited. The user's editor was left running. Hash comparison confirmed all eight existing measured-route files unchanged; no shared handling, containment, checkpoint or procedural-course algorithm was modified.

## Reproduction

Stage once with `tools/tabletop_reference/stage_topspeed_oval.py` after accepted candidate evidence; it refuses to overwrite a staged course and checks the source hash. Generate resources through `scripts/tracks/author_topspeed_oval.gd` using Summer editor scripting, then re-save the entry in a fresh editor to register resource UIDs. The author does not alter other courses.

Run the isolated playable probe with a fresh evidence directory:

```powershell
& tools/run_tabletop_verification.ps1 -Probe res://tests/probes/topspeed_oval_verification.gd -Evidence tests/baselines/content/topspeed_oval/playable_recheck -MaxSeconds 210
```

Read the results and stderr, and verify that the returned exact test PID exited. Do not overwrite retained failures.
