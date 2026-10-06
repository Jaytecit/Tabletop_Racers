# Course authoring

Production entries are `tracks/<id>/entry.tres`, with external `definition.tres`, `preview.res` and a saved environment scene. Register active ID/title pairs together in `scripts/tracks/content_catalog.gd`. Keep retired resources at their original paths; presence on disk does not imply game eligibility.

## Imported courses

Read the [accepted Toys R You record](../docs/toys-r-you-integration.md), [required extraction guide](../docs/tabletop-track-extraction-guide.md), [current rollout status](../.summer/plans/2026-10-03-tabletop-glb-rollout.md) and [tool limitations](../tools/tabletop_reference/README.md).

Derive independent left/right boundaries and heights from the source model. A screenshot centreline with fixed width is insufficient. Preserve source hashes, inspected primitive/material identities, transforms, layer decisions and reviewed uncertain spans in each manifest. Keep canonical accepted measurements untouched during candidate extraction.

Rebuild with the relevant `scripts/tracks/author_<id>.gd` editor recipe. Imported models provide the visible surface and physical collision. Flatten owned meshes when saving; do not duplicate GLB descendants. Generated decks and permanent road edges are suppressed. Checkpoint flags use actual checkpoint planes, measured boundaries, supported heights and vehicle clearance. `RouteDebugOverlay.ENABLED` is currently false; diagnostic overlays are separate from gameplay flags.

Before registration, inspect source comparisons and rendered views, validate corridor topology/support/layers and ordered checkpoint cases. Run one Beach Buggy race on Hard, using Freestyle when the assigned class differs, plus relevant controls, pause/retry and course-switch/loading checks. Do not repeat the retired vehicle/stat/difficulty matrix or enable untested additional modes. Use disposable rendered instances with read-only profiles and hardware input isolation; preserve failures and confirm the exact test PID exits. See `tools/run_tabletop_verification.ps1` and `tests/probes/`.

## Procedural and preserved courses

Roulette Grand Prix remains active. Other procedural routes and the 2D build remain development content. Use their existing recipes and retained baseline reports when deliberately changing them; do not run obsolete milestone plans as current instructions.

Keep route sampling, progression, AI and recovery consistent. Scenery/support belongs under `CourseEnvironment`, outside disposable `Track/Generated`. Validate unique ordered sections, connectivity, safe recovery anchors, layer crossings and decorative clearance. Rebuild the preview from the selected route and increment its revision when changing gameplay geometry so records/ghost signatures stay meaningful. The catalogue assigns Beach Buggy to TABLETOP and Racing Car to ROAD; Freestyle permits all five classes. Mode eligibility is independently gated in `course_capabilities.gd`.
