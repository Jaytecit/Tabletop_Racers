# Nighttime Noodles integration verification

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Verified from its own source GLB, UV textures and named driving triangles. All source sections, rendered depth-tested sections, the loop seam and checkpoint views were reviewed.

- Source: [Nighttime Noodles](https://sketchfab.com/3d-models/table-top-racing-nighttime-noodles-1f8a8a8856cd4f2a95ef29cac4c9f9b7), amogusstrikesback2, CC BY 4.0.
- Source SHA-256: `686450782c91dd0f731eb6192c1509de2d95204bd64104e7302776fae04fdf1e`.
- Transform: authored scale 40, offset [43, 0, -8], with every GLB ancestor transform accumulated.
- 64 sections, 1536 spans; measured independent boundaries, width 5.860–9.799. Centre height 0.00004–1.34859.
- Heights: exact barycentric support on ['bake_01_tex_bake_01_0', 'bake_02_tex_bake_02_0', 'bake_03_tex_bake_03_0', 'bake_06_tex_bake_06_0', 'bake_05_tex_bake_05_0']; centre sampled independently. Layer selection: [-0.06, 1.4]. Props are excluded from measurement support.
- Raster spacing 0.05 units. 3072 independent source paint-band checks, zero failures; tolerance 0.125. This checks proximity to finite texture markings, not a universal geometric error bound. Ambiguous intervals: 0 reviewed samples.
- Zero self-intersections or folded runtime quads. Compression disabled to preserve source vertices; three separated imported/source landmarks recorded in `alignment/landmark_checks.json`.

All 64 source and rendered sections align, including the bamboo mats, serving-board heights, top connecting plank in mixed bake_05 geometry and all S-bends. Four initial paint-band failures at the tight concave corner were corrected with source UV/world paint anchors (samples 650–700); initial failed audit is preserved. Larger transverse correspondence folds were reviewed at the actual white-line turning points and do not erase real S-bends. START cloth in bake_07 is mapped to Z -8.27168 to -8.24520, and gate station 330.37456 aligns to it. Original arch reused; other gates have clear supported or same-plane elevated cues. No stacked route crossings. Initial gameplay run passed its race but failed four outer-lane gate cases due to centreline projection jumps. Finite measured checkpoint planes and physical displacement now validate the crossings; 480 cases pass after the shared fix. Toys R You full regression (toys_finite_plane_regression) passes all 480 gates and three Hard laps for four cars with no crashes, recoveries or penalties.

Runtime verification: 7680 corridor cases, 4608 physical support rays and 480 actual checkpoint-plane cases; all pass. Four AI cars completed three Hard laps in 94.971–97.167 seconds, with zero crashes, recovery resets or penalties. Ordinary car impacts are recorded separately. Movement, boost, intentional recovery, pause/resume and course switching pass. Time trial and flag rebuilding/switching pass.

Performance: race FPS 59–62; cold selection 12205 ms. Final monitor sample: {"draw_calls": 134.0, "static_memory_mb": 96.1106452941895, "triangles": 110498.0}. Single samples are not a percentile benchmark. Same local runtime and settings as the accepted course; hardware details are in the probe/runtime evidence.

Evidence:

- [Source validation](../../tests/baselines/content/nighttime_noodles/alignment/source_validation.json), [measurement corrections](../../tests/baselines/content/nighttime_noodles/alignment/measurement_evidence.json), [source overlay](../../tests/baselines/content/nighttime_noodles/alignment/measured_overlay.png).
- [Race results](../../tests/baselines/content/nighttime_noodles/verification_02/results.json), [rendered route and time trial](../../tests/baselines/content/nighttime_noodles/visual_01/results.json), [final checkpoint cues](../../tests/baselines/content/nighttime_noodles/visual_01/results.json).
- All earlier attempts and raw stdout/stderr are preserved. Successful probes have no recorded runtime errors. Each disposable PID was checked exited. Profiles were read-only and hardware input isolated.

Raw stderr findings: []. Probe error capture ends before engine teardown; shutdown ResourceCache/ObjectDB warnings are recorded separately and are not relabelled as a clean shutdown.

The canonical Toys R You data and existing procedural courses are preserved. Shared checkpoint-plane progress changes were regression-tested on Toys R You. Temporary diagnostic coloured boundaries remain enabled; no permanent road edges were generated.
