# Moonlight Junk Heap integration verification

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Verified from its own source GLB, UV textures and named driving triangles. All source sections, rendered depth-tested sections, the loop seam and checkpoint views were reviewed.

- Source: [Moonlight Junk Heap](https://sketchfab.com/3d-models/table-top-racing-moonlight-junk-heap-70903adf67624d2e90c2dae0d5cee467), amogusstrikesback2, CC BY 4.0.
- Source SHA-256: `e18d779405452b4bf5abedb8ac3b8168e9d5a6c73fb99f285b533e39173a9388`.
- Transform: authored scale 40, offset [-32, 0, -8], with every GLB ancestor transform accumulated.
- 60 sections, 1440 spans; measured independent boundaries, width 6.400–9.036. Centre height 0.00004–1.13395.
- Heights: exact barycentric support on ['BAKE_01_tex_BAKE_01_0', 'BAKE_02_tex_BAKE_02_0', 'BAKE_03_tex_BAKE_03_0']; centre sampled independently. Layer selection: [-0.06, 1.16]. Props are excluded from measurement support.
- Raster spacing 0.05 units. 2880 independent source paint-band checks, zero failures; tolerance 0.125. This checks proximity to finite texture markings, not a universal geometric error bound. Ambiguous intervals: 0 reviewed samples.
- Zero self-intersections or folded runtime quads. Compression disabled to preserve source vertices; three separated imported/source landmarks recorded in `alignment/landmark_checks.json`.

Distinct geometry from Rusty Nuts, independently measured. All 60 source and rendered sections align, including carton seams and both hairpins. Weak samples and the section 46–48 inner-corner fold were resolved with UV paint anchors, with initial failed source validation preserved. The measured START banner in BAKE_06 spans Z -7.999 to -7.950; gate zero is aligned at Z -7.975 (station 16.5706) and reuses it. Final gate views show clear supported cues, no duplicates and no permanent edges. One road layer, no stacked crossing; intended driving triangles exclude all props.

Runtime verification: 7200 corridor cases, 4320 physical support rays and 480 actual checkpoint-plane cases; all pass. Four AI cars completed three Hard laps in 73.818–76.077 seconds, with zero crashes, recovery resets or penalties. Ordinary car impacts are recorded separately. Movement, boost, intentional recovery, pause/resume and course switching pass. Time trial and flag rebuilding/switching pass.

Performance: race FPS 58–62; cold selection 9731 ms. Final monitor sample: {"draw_calls": 354.0, "static_memory_mb": 95.5168304443359, "triangles": 75055.0}. Single samples are not a percentile benchmark. Same local runtime and settings as the accepted course; hardware details are in the probe/runtime evidence.

Evidence:

- [Source validation](../../tests/baselines/content/moonlight_junk_heap/alignment/source_validation.json), [measurement corrections](../../tests/baselines/content/moonlight_junk_heap/alignment/measurement_evidence.json), [source overlay](../../tests/baselines/content/moonlight_junk_heap/alignment/measured_overlay.png).
- [Race results](../../tests/baselines/content/moonlight_junk_heap/verification_02/results.json), [rendered route and time trial](../../tests/baselines/content/moonlight_junk_heap/visual_01/results.json), [final checkpoint cues](../../tests/baselines/content/moonlight_junk_heap/flags_final/results.json).
- All earlier attempts and raw stdout/stderr are preserved. Successful probes have no recorded runtime errors. Each disposable PID was checked exited. Profiles were read-only and hardware input isolated.

Raw stderr findings: ["flags_final: WARNING: 8 ObjectDB instances were leaked at exit (run with `--verbose` for details).    at: ObjectDB::cleanup (core\\object\\object.cpp:2536) ERROR: 1 resources still in use at exit (run with --verbose for details).    at: ResourceCache::clear (core\\io\\resource.cpp:822)"]. Probe error capture ends before engine teardown; shutdown ResourceCache/ObjectDB warnings are recorded separately and are not relabelled as a clean shutdown.

The canonical Toys R You data and existing procedural courses are preserved. Shared checkpoint-plane progress changes were regression-tested on Toys R You. Temporary diagnostic coloured boundaries remain enabled; no permanent road edges were generated.
