# Firefly BBQ integration verification

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Verified from its own source GLB, UV textures and named driving triangles. All source sections, rendered depth-tested sections, the loop seam and checkpoint views were reviewed.

- Source: [Firefly BBQ](https://sketchfab.com/3d-models/table-top-racing-firefly-bbq-2fc12d167b8848ce8f1c8a02ee13b6d7), amogusstrikesback2, CC BY 4.0.
- Source SHA-256: `59c8aa23122438ef3662b00878ac22d81351b066560e25022359ff66937548b3`.
- Transform: authored scale 40, offset [-2, 0, 9], with every GLB ancestor transform accumulated.
- 68 sections, 1632 spans; measured independent boundaries, width 6.500–8.150. Centre height -0.05128–0.99585.
- Heights: exact barycentric support on ['bake_01_tex_bake_01.002_0', 'bake_02_tex_bake_02.002_0', 'bake_02a_tex_default.007_0', 'bake_03_tex_bake_03.002_0', 'bake_03a_tex_default.008_0', 'bake_04_tex_bake_04.002_0', 'bake_04a_tex_default.009_0']; centre sampled independently. Layer selection: [-0.06, 1.2]. Props are excluded from measurement support.
- Raster spacing 0.05 units. 2976 independent source paint-band checks, zero failures; tolerance 0.12000000000000001. This checks proximity to finite texture markings, not a universal geometric error bound. Ambiguous intervals: 288 reviewed samples.
- Zero self-intersections or folded runtime quads. Compression disabled to preserve source vertices; three separated imported/source landmarks recorded in `alignment/landmark_checks.json`.

All 68 source and rendered sections align. White-on-white napkin sections 21–23 and 26–28 were individually reviewed against faint paint ridges, both adjoining wooden paint bands and selected triangle topology. They are explicitly excluded from automatic colour-mask claims. Cloth ramps and grill pan have measured heights; there is no road self-crossing. Original START cloth in bake_07 lies at Z 8.978, matched by gate station 8.10825 and reused. Checkpoint cues remain clear without overlay. Initial verification_01 failed all support checks because imported names had dots sanitized to underscores; its empty-scene images and results are preserved. Explicit verified aliases now retain all 13 meshes, with three separated landmarks passing. The author rejects missing selected meshes instead of saving an empty environment.

Runtime verification: 8160 corridor cases, 4896 physical support rays and 480 actual checkpoint-plane cases; all pass. Four AI cars completed three Hard laps in 85.738–87.797 seconds, with zero crashes, recovery resets or penalties. Ordinary car impacts are recorded separately. Movement, boost, intentional recovery, pause/resume and course switching pass. Time trial and flag rebuilding/switching pass.

Performance: race FPS 58–62; cold selection 13534 ms. Final monitor sample: {"draw_calls": 140.0, "static_memory_mb": 95.460542678833, "triangles": 64635.0}. Single samples are not a percentile benchmark. Same local runtime and settings as the accepted course; hardware details are in the probe/runtime evidence.

Evidence:

- [Source validation](../../tests/baselines/content/firefly_bbq/alignment/source_validation.json), [measurement corrections](../../tests/baselines/content/firefly_bbq/alignment/measurement_evidence.json), [source overlay](../../tests/baselines/content/firefly_bbq/alignment/measured_overlay.png).
- [Race results](../../tests/baselines/content/firefly_bbq/verification_02/results.json), [rendered route and time trial](../../tests/baselines/content/firefly_bbq/visual_02/results.json), [final checkpoint cues](../../tests/baselines/content/firefly_bbq/visual_02/results.json).
- All earlier attempts and raw stdout/stderr are preserved. Successful probes have no recorded runtime errors. Each disposable PID was checked exited. Profiles were read-only and hardware input isolated.

Raw stderr findings: ["visual_02: WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).    at: ObjectDB::cleanup (core\\object\\object.cpp:2536) ERROR: 1 resources still in use at exit (run with --verbose for details).    at: ResourceCache::clear (core\\io\\resource.cpp:822)"]. Probe error capture ends before engine teardown; shutdown ResourceCache/ObjectDB warnings are recorded separately and are not relabelled as a clean shutdown.

The canonical Toys R You data and existing procedural courses are preserved. Shared checkpoint-plane progress changes were regression-tested on Toys R You. Temporary diagnostic coloured boundaries remain enabled; no permanent road edges were generated.
