# Toys R Asleep integration

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.



Status: integrated and verified on 2026-10-03. All test instances exited; the original Toys R You canonical files remain byte-identical to the targeted backup.



Source: `assets/imported/tabletop/toys_r_asleep.glb`, SHA-256 `99f7c07dac78a2cd78a401460b9b114cbb93454ac830656c0cfe3b3d562c16ef`. Original source, author and license are recorded in the manifest and CREDITS.md. This model differs from Toys R You; none of its canonical route coordinates were reused.



## Measurements and authoring



- One source transform: scale 40, offset (-37.2, 2.16, 1.5), with every GLB ancestor transform accumulated. Three separated imported/source landmarks agree within 0.000003 world units after disabling mesh compression.

- Ten flattened owned mesh instances, eight visible. Source collision-only meshes remain hidden. Baked materials are unshaded; the original model and its painted edges supply the artwork.

- 60 sections / 1,440 spans / 25 samples per section. Independently fitted boundaries range 7.52â€“12.15 units apart. X/Z route length is 336.789 units; exact centre heights range 0.01064â€“2.16472.

- Source UV/material associations, wrap modes, raster bounds (-55,-60), 0.05-unit sampling, source surfaces, seed direction, section surface labels and height selection are preserved in the manifest and analysis profile.

- Exact named-floor/ramp triangle intersections provide each edge's own height and the centre's independently sampled height. The 2.7104-unit carton rim is outside the inspected driving-deck range. Two edge points moved 0.015/0.020 units onto their intended carton-deck triangles; these adjustments are below one analysis pixel.

- There is no route self-crossing/underpass on this circuit; all progression layers are zero. Source props and ramps are not separate racing layers.

- The concave carton bend uses source-pixel anchors and monotonic boundary pairing, refined onto visible tape/dash bands. White-on-white packaging and backgammon tips use reviewed continuity. The manifest lists every reviewed interval and resolution.

- Independent source colour/ridge audit: 2,160 confident boundary checks, zero failures; zero boundary intersections and zero folded span quads. The recorded confident-interval tolerance is the approximate 0.08-unit paint half-band plus one 0.05-unit analysis pixel. This is a texture-resolution measurement, not a universal mathematical error bound. The 720 samples in reviewed ambiguous sections depend on close-up, source-part and continuity evidence rather than an invisible-paint colour assertion.



Recipe: `scripts/tracks/author_toys_r_asleep.gd.build()`, backed by `author_tabletop.gd`. It rebuilds scenery and resources directly from the manifest and canonical measured JSON, never a seed/fixed-width route. Current active ordering is defined by content_catalog.gd, with titles shared by the menu; historical menu indexes are not stable identities.



## Verification



`tests/baselines/content/toys_r_asleep/verification_06/results.json` is finished=true, passed=true, errors_seen=[]:



- 7,200 inside/outside measured-corridor checks passed.

- 4,320 centre/near-edge physics support samples passed, using the actual world transform and a 0.10-unit height agreement tolerance.

- All 480 forward/reverse/repeated/skipped/wrong-height checkpoint cases passed across 80% of usable width.

- Four cars finished three Hard laps in 90.339â€“93.225 seconds, with zero crashes, recovery resets or penalties. Ordinary car impacts occurred.

- Real throttle/boost moved the player 8.32 units over 45 physics frames. Recovery returned to supported ground; pause/resume and switching away/back passed.

- RTX 4060 Ti, Vulkan Forward+, same project/retro settings as the accepted baseline: sampled 58â€“62 FPS. Draw calls and frame/load timings are recorded by the final marker probe.



`visual_06/results.json` is finished=true, passed=true, errors_seen=[]: marker-plane alignment, layer, support, vehicle/prop clearance, numbering and rebuild/switch consistency passed. All 60 sections have rendered depth-tested close-ups; X-ray and depth overviews, all eight gates, Time Trial driving and the scrollable credits dialog were captured and inspected. Time Trial reached the running phase and advanced beyond station 10. Game Table retained all 456 polygons and passed 912 inside / 912 outside checks; Practice Patch retained all 192 polygons. Toys R You retained all 6,960 corridor checks.



The final gate-zero presentation reuses the original castle START arch, replacing the duplicated generated FINISH flags found during image inspection. Other gates retain supported paired/single flags or an elevated same-plane cue where props prevent a supported shoulder. Flags remain when the temporary route overlay is hidden.



## Preserved failures and fixes



- `verification_01` failed support and four gate cases. Its 2,732 support failures mostly came from a probe querying local coordinates in the world's rotated Race space. New probes transform both ray endpoints and returned heights.

- `checks_02` / `checks_03` retained 20 support failures: selected carton-rim heights, and one source seam opened by mesh compression. The imported/source audit measured up to 0.00144-unit displacement; the missing support point lay at that compressed seam. Uncompressed import preserves the source seam.

- `checks_04` retained five edge-height interpolation failures. Exact intended-deck selection and two sub-pixel boundary adjustments resolved them.

- Four genuine outer-lane gate cases crossed the visible plane while nearest-centre projection remained 0.005 units behind it. Imported progression now tests the actual local checkpoint planes, preserving ordered/repeated/skipped/wrong-height rules. Procedural progress remains on its previous station-based path.

- `verification_05` passed after those fixes. The final `verification_06` additionally covers the source-ridge refinement and inspected per-section floor labels.

- Initial entry loads warned about fresh generated resource UIDs; a fresh editor/resource save resolved them. Final rendered probes have no recorded warnings/errors.

- The live editor diagnostic buffer contains one unclassified FileAccess-null message while the fresh rendered runs have errors_seen=[] and no script/debugger errors. Do not describe the live editor buffer as entirely clean.



Evidence and reusable analysis live under `tests/baselines/content/toys_r_asleep/` and `tools/tabletop_reference/`. Temporary raster maps are ignored by the engine filesystem. The cyan/magenta/yellow overlay remains enabled for inspection; no permanent generated road edges were added.



Final marker evidence: `flags_final/results.json`, finished=true, passed=true, errors_seen=[]; gate zero reuses the original START arch, no duplicate flags, all other cue planes/clearances/rebuild/switch checks pass. Cold course selection took 7,544 ms; the driving sample recorded 60 FPS, 361 draw calls, 81,613 rendered primitives and 95.06 MiB static memory. The instantaneous process-time monitor was 28.68 ms; this is not a percentile frame-time benchmark.



Shared progression regression: `toys_progress_regression/results.json`, finished=true, passed=true, errors_seen=[]; 714 support and all 480 gate cases passed. Four Toys R You cars completed three Hard laps in 132.694–138.471 seconds with zero crashes, recovery resets or penalties, at 58–62 sampled FPS. Its canonical route/definition/entry/preview SHA-256 hashes match the baseline backup.
