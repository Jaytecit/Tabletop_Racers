# Toys R You — accepted integration

The user accepted the corrected model alignment on 3 October 2026. It remains the canonical reference for imported tabletop courses. See the [required extraction guide](tabletop-track-extraction-guide.md), [current course status](../.summer/plans/2026-10-03-tabletop-glb-rollout.md) and [preserved tooling](../tools/tabletop_reference/README.md).

## Current state

Toys R You is selectable in Quick Race and Time Trial. Its GLB supplies visible roads, white markings, scenery and collision. Generated decks, rails and start stripes are suppressed. Checkpoint cues, minimap and ordered progression remain active. `RouteDebugOverlay.ENABLED` is false; earlier coloured-overlay screenshots are historical verification views.

- Source: `assets/imported/tabletop/toys_r_you.glb`; adjacent `CREDITS.md` and in-game credits record attribution.
- Environment: `environments/tabletop/toys_r_you.tscn`; route/menu resources: `tracks/toys_r_you/`.
- Recipe: `scripts/tracks/author_toys_r_you.gd.build()`; accepted measurements: `tracks/toys_r_you/measured_route.json`. `align_toys_r_you.gd.apply_measurement()` rebuilds resources from that canonical file, not a new fit.
- Scale 40; offset (-44, 0, -7.2). The 58 sections contain 1,392 measured cross-sections, approximately 475.02 units long, with independently measured widths around 6.4–10.4 units.
- UV/texture-derived boundaries use 0.05-world-unit analysis spacing. Heights come from source triangles with explicit lower-layer handling beneath the bridge. White-on-white spans use reviewed continuity fitting. Sampling resolution is not a guaranteed maximum geometric error.
- Meshes are flattened into an owned saved environment to avoid duplicating GLB descendants. Existing procedural route polygons are preserved.

## Accepted alignment evidence

The former fixed-width approximation rejected 2,588 of 6,960 model-corridor samples. Corrected alignment passed all 6,960, plus 714 physical support samples and 480 checkpoint cases. Four cars completed three laps in 132.69–138.47 seconds with zero crashes, recoveries or penalties; ordinary car impacts occurred.

Pause/resume, switching and recovery passed. The combined probe's boost assertion failed because a connected controller drove the hidden instance; its raw `aligned_verification/results.json` remains unchanged. The isolated-input rerun `aligned_controls/results.json` passed throttle/boost/recovery: boost reached 74.5 and movement was 7.4 units over 45 physics frames. It emitted resource-in-use/ObjectDB shutdown warnings, with no recorded gameplay errors. Do not describe the combined run as wholly passing.

Evidence: `tests/baselines/content/toys_r_you/`, including `alignment_before.png`, `alignment_measured.png`, `aligned_verification/overview.jpg` and both raw result directories. Earlier `verification/` runs record the initial integration rather than the final accepted alignment.

## Checkpoint flags

Flags intersect actual gate planes with independent measured boundaries and use physical support/clearance. The source START arch is reused; supported numbered pennants and a floating same-plane cue at gate 7 complete coverage. Imported numbers remain readable through props. [Placement evidence](verification/toys_r_you-checkpoint-flags.md) records checks and limitations. Flags are independent of the diagnostic overlay; no permanent road-edge artwork was requested.

Embedded metadata identifies the uploader and CC BY 4.0; it does not independently verify underlying rights provenance. Subsequent integrations have their own [evidence records](README.md).
