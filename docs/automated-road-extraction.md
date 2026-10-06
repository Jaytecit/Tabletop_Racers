# Automated road boundary extraction

Implemented and proved on Topspeed Oval on 2026-10-03. This completes the first geometry-automation stage: source-selected road meshes become independently measured 3D boundaries and a candidate gameplay corridor. Playable-course authoring and race/checkpoint acceptance remain separate gates.

## Run it

From this project in PowerShell:

```powershell
$roadPython = 'C:/Users/jayte/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$candidateRun = & $roadPython tools/tabletop_reference/extract_road_candidate.py tools/tabletop_reference/profiles/topspeed_oval.json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Extraction failed; inspect the preserved result.json' }
$candidateRun.output
$renderRun = 'tests/baselines/content/topspeed_oval/rendered_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
& tools/verify_road_candidate.ps1 -Candidate $candidateRun.output -Evidence $renderRun
```

The Python command uses a new timestamped evidence directory by default. `--out <new-directory>` chooses another. Existing directories and accepted `tracks/`, `assets/`, `environments/`, `scripts/` and `.summer/` output locations are refused. Exit 0 and `result.json.passed=true` mean source-candidate gates passed, not that the course is accepted for racing. Exit 2 preserves a failed result and any intermediate attempts.

The rendered runner returns its isolated test PID. Read `<renderRun>/results.json`, check `finished`, `reports.passed`, `errors_seen`, and inspect the images. Confirm that exact PID has exited; never clean up the user's editor or other projects. The probe disables hardware input, makes the profile read-only, removes the boot course from its test world, and saves no game resources.

## What is automatic

`extract_road_candidate.py` uses the existing cumulative-transform GLB reader. The profile binds to a source SHA-256 and selects exact node/primitive identities; optional triangle masks narrow mixed meshes. It extracts the original outer/inner rings and their individual source-triangle heights, pairs their traversal monotonically, derives the centre X/Z and independently samples its height. It exports the runtime's 24-span/25-sample section format without fitting a fixed-width road.

The geometry gates reject unsupported samples, vertical/degenerate selected faces, disconnected or non-annular footprints, conflicting overlapping road heights, incorrect side identity, folded or overlapping corridor polygons, insufficient width and excessive sampled boundary residuals. Every span checks three interior and two exterior cross-section fractions both at the span start and midpoint. Refinement keeps earlier attempts; source edges are never smoothed into a new outline. A configured pairing-cell limit bounds memory use.

Files in each successful candidate folder:

- `profile_snapshot.json`: exact inputs used for reproducibility.
- `road_boundaries.json`: independently extracted original boundary vertices, each with its own height.
- `measured_candidate.json`: ordered left/right/centre rows, with row count divisible by 24.
- `measurement_manifest_candidate.json`: source identity, transform, selection, tolerances, layer/surface compatibility data and remaining uncertainty.
- `geometry_checks.json`, `geometry_checks_<attempt>.json`, `measured_attempt_<attempt>.json`: passing or failing evidence.
- `source_road.png`, `candidate_overlay.png`, `preview_transform.json`: correct source UV textures with the measured corridor overlaid.
- `road_union.geojson`, `result.json`: footprint and authoritative command outcome.

The generic rendered probe constructs an in-memory route using the current runtime, compares three widely separated imported source landmarks, checks actual road collision support and corridor containment, and captures depth-tested, X-ray and per-section views. Overview framing derives from candidate bounds. Its currently verified import mapping is one selected surface per road node; masked or multi-surface mappings require a reviewed engine mapping before this probe will accept them.

## Add another course profile

Copy `tools/tabletop_reference/profiles/topspeed_oval.json` to a new profile and derive these fields from that model:

1. Stable course ID, source path and SHA-256; exact road node names plus primitive surface indices, and triangle masks where necessary.
2. Boundary definition: road-mesh perimeter, visible paint or a barrier-facing edge. Road names are only hints; inspect collision walls, scenery, paved plazas, pit lanes and alternate routes.
3. One explicit uniform `transform`, or a reviewed `scale_to_median_width` target. The latter measures supported native clearance chords and centres the road bounds. Keep current vehicle dimensions in mind.
4. Source X/Z start anchor and traversal direction. Initial extraction seams may be provisional; map actual START artwork before final checkpoint authoring.
5. Native/game height tolerances, minimum width, boundary residual tolerance, pairing/sample spacings, search/memory budgets and preview resolution.
6. Existing handling preset and a clear note explaining the choice. Topspeed uses the existing neutral `wood` preset for schema compatibility; no asphalt handling was invented.

Do not loosen a tolerance to conceal unsupported road or a wrong transform. The reported boundary error is sampled source-correspondence evidence, not a mathematical global maximum. Review every rendered section as required by the extraction guide.

This branch deliberately stops on branched networks or separate overlapping layers. Use the existing UV/paint tools for boundaries painted on broad meshes; use an explicitly selected route and layer graph for bridges, junctions or open environments. A textured preview currently requires the selected surfaces' existing supported base-colour UV/texture mapping; unsupported mappings fail visibly. It is not a universal road classifier.

## Topspeed proof

Final source candidate: `tests/baselines/content/topspeed_oval/extraction/final/`.
Final rendered evidence: `tests/baselines/content/topspeed_oval/rendered_candidate_final/`.

| Check | Result |
|---|---|
| Source identity | `6478db57e4c7687eb536bb97efb7ca368ee4e0f76afcb5aef4b9448b5a179749` |
| Selected road | `ringoval_road_road1red_0` and `ringoval_road_road2blue_0`, surface 0; 832 triangles |
| Footprint | One valid connected polygon with one hole; no conflicting selected road layers |
| Uniform transform | Scale 0.27851315418728406; offset (1.431903682068566, 0.008565070662936065, -0.05681589257821017) |
| Candidate route | 1,152 rows, 48 sections, 341.982688 units |
| Sampled width | 5.860516 minimum, 6.035809 median, 8.294491 maximum |
| Source containment checks | 11,520 passed |
| Boundary residual sampling | 6,912 samples; maximum 0.00507035 and p99 0.00253967, against a 0.05-unit tolerance |
| Runtime resource validation | No errors |
| Actual engine support | 3,456 checks passed; max sampled height difference 0.00181443, tolerance 0.02 |
| Runtime containment | 5,760 checks passed |
| Import landmarks | Three checks; maximum error 0.000001908, tolerance 0.001 |
| Rendered review | Source overview, depth overview, X-ray overview, and 48 section close-ups saved; alignment reviewed |
| Focused tooling tests | 10 passed, including a real synthetic GLB/CLI test with hierarchy transforms, hash rejection and preserved outputs |

The first rendered attempt (`rendered_candidate_initial`) failed two import-landmark checks and one support ray, and exposed a probe overlay-parent error. Preserve its raw result. Mesh compression was disabled for this source GLB (`meshes/force_disable_compression=true`) and the overlay holder corrected. The uncompressed and final runs passed. This confirms import compression caused the measured drift/support seam; the raw GLB was unchanged. Final test PID 165812 exited; earlier test PIDs 64756 and 62000 also exited.

The headless single-file reimport produced warnings about differing base-colour versus metallic/roughness UV maps. The candidate renderer uses the same unshaded baked base-colour convention as accepted imports. Existing project case-path boot warnings were also logged by the editor child; these were not changed by this task. The failed first editor-script invocation and successful reimport receipts are retained in the engine's `.godot/summer_editor_script/` logs.

The source includes other black asphalt courses/drag strips beneath and around the raised oval. They are deliberately excluded from the oval's driving corridor. The current extraction seam is on the left bend; the visible oval start stripe is on the lower straight. The playable handoff now uses start station 86.1174513 at that independently measured stripe, with verified checkpoint cues.

## Game handoff

After source/uncertainty and start-cue review, the candidate's row schema and section arrays are compatible with `author_tabletop.gd`. Prepare a new course's accepted manifest with reviewed visible/collision mesh selections, source-to-engine name mapping, credits and source cue. Promote the reviewed rows, import the source without geometry compression, and call the existing author through Summer editor scripting. Do not register a new menu course until its individual checkpoint, support, four-car/three-lap, controls, switching and performance gates pass.

Topspeed Oval is now registered and verified in Quick Race and Time Trial. See [playable acceptance](verification/topspeed_oval.md) for the clean four-car/three-lap race, checkpoint/controls checks, performance and retained probe failure. Canonical Toys R You, Mount Rainier, other measured routes and procedural algorithms remain unchanged. Bazaar and Town Square are the next candidates; each still requires its own source and gameplay acceptance.

Run focused tests:

```powershell
& $roadPython -m unittest discover -s tools/tabletop_reference -p test_road_geometry.py -v
```
