# Rusty Nuts Workshop integration verification

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Verified from its own source GLB, UV textures and named driving triangles. All source sections, rendered depth-tested sections, the loop seam and checkpoint views were reviewed.

- Source: [Rusty Nuts Workshop](https://sketchfab.com/3d-models/table-top-racing-rusty-nuts-workshop-8ac8eef11e404195985dee59dabd5eb7), amogusstrikesback2, CC BY 4.0.
- Source SHA-256: `52fe3012c9089159634a4db101b3b5993c315f343ba841e9fb492c927657c6e4`.
- Transform: authored scale 40, offset [12, 0, -8], with every GLB ancestor transform accumulated.
- 60 sections, 1440 spans; measured independent boundaries, width 5.170–8.421. Centre height 0.00004–1.13401.
- Heights: exact barycentric support on ['BAKE_01_tex_DIFF_BAKE_01_0', 'BAKE_02_tex_DIFF_BAKE_02_0', 'BAKE_03_tex_DIFF_BAKE_03_0']; centre sampled independently. Layer selection: [-0.06, 1.15]. Props are excluded from measurement support.
- Raster spacing 0.05 units. 2880 independent source paint-band checks, zero failures; tolerance 0.125. This checks proximity to finite texture markings, not a universal geometric error bound. Ambiguous intervals: 0 reviewed samples.
- Zero self-intersections or folded runtime quads. Compression disabled to preserve source vertices; three separated imported/source landmarks recorded in `alignment/landmark_checks.json`.

All 60 source and rendered views align, including reviewed correspondence folds at samples 1260–1270, 1356–1358 and 1410–1429. Six weak samples on the connector corner were resolved by paint proximity and visual review. Initial overhead cue review missed the hanging START banner. Texture-atlas review and UV-to-vertex mapping locate it in BAKE_06 at Z -5.190 to -5.146; final gate zero uses station 14.7964 on that plane and reuses the banner. The previous generated FINISH cue is removed. Final race and all final gate views were rechecked after this correction. No road layers cross; the jack is a prop excluded from driving-height selection.

Runtime verification: 7200 corridor cases, 4320 physical support rays and 480 actual checkpoint-plane cases; all pass. Four AI cars completed three Hard laps in 100.614–102.974 seconds, with zero crashes, recovery resets or penalties. Ordinary car impacts are recorded separately. Movement, boost, intentional recovery, pause/resume and course switching pass. Time trial and flag rebuilding/switching pass.

Performance: race FPS 58–62; cold selection 10925 ms. Final monitor sample: {"draw_calls": 366.0, "static_memory_mb": 96.3940544128418, "triangles": 70245.0}. Single samples are not a percentile benchmark. Same local runtime and settings as the accepted course; hardware details are in the probe/runtime evidence.

Evidence:

- [Source validation](../../tests/baselines/content/rusty_nuts_workshop/alignment/source_validation.json), [measurement corrections](../../tests/baselines/content/rusty_nuts_workshop/alignment/measurement_evidence.json), [source overlay](../../tests/baselines/content/rusty_nuts_workshop/alignment/measured_overlay.png).
- [Race results](../../tests/baselines/content/rusty_nuts_workshop/verification_02/results.json), [rendered route and time trial](../../tests/baselines/content/rusty_nuts_workshop/visual_01/results.json), [final checkpoint cues](../../tests/baselines/content/rusty_nuts_workshop/flags_final_02/results.json).
- All earlier attempts and raw stdout/stderr are preserved. Successful probes have no recorded runtime errors. Each disposable PID was checked exited. Profiles were read-only and hardware input isolated.

Raw stderr findings: ["flags_final_02: WARNING: 10 ObjectDB instances were leaked at exit (run with `--verbose` for details).    at: ObjectDB::cleanup (core\\object\\object.cpp:2536) ERROR: 1 resources still in use at exit (run with --verbose for details).    at: ResourceCache::clear (core\\io\\resource.cpp:822)", "verification_02: WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).    at: ObjectDB::cleanup (core\\object\\object.cpp:2536) ERROR: 1 resources still in use at exit (run with --verbose for details).    at: ResourceCache::clear (core\\io\\resource.cpp:822)"]. Probe error capture ends before engine teardown; shutdown ResourceCache/ObjectDB warnings are recorded separately and are not relabelled as a clean shutdown.

The canonical Toys R You data and existing procedural courses are preserved. Shared checkpoint-plane progress changes were regression-tested on Toys R You. Temporary diagnostic coloured boundaries remain enabled; no permanent road edges were generated.
