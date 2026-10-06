# Preserved Toys R You measurement reference

## Automated dedicated-road branch (2026-10-03)

`extract_road_candidate.py` and `road_geometry.py` generalise the mountain road-ring method into a hash-bound, explicit-primitive-profile extractor. `profiles/topspeed_oval.json` is the first proved profile. It exports independently measured boundaries, paired rows, source UV overlays and retained gate results into fresh evidence directories. `test_road_geometry.py` covers geometry rejection, source transforms/hash binding and overwrite protection. `../verify_road_candidate.ps1` runs an isolated rendered import/support/runtime-corridor probe.

See [commands, limitations and Topspeed evidence](../../docs/automated-road-extraction.md). This branch handles a single non-overlapping annular driving surface. Painted tabletop routes still use the UV branch below; networks and stacked crossings need reviewed route/layer selection. Candidate generation does not automatically overwrite accepted data or register a playable course.

## Manifest-driven rollout tools (2026-10-03)

`glb_source.py` reads every primitive/material/UV association and accumulates GLB ancestor transforms. `raster_source.py`, `fit_source.py`, `finalize_source.py` and `verify_source.py` take a per-course JSON profile. The first tested profile is `profiles/toys_r_asleep.json`; its inspected surfaces, height range, seed, ambiguous intervals and manual corner anchors are specific to that model. Derive new profiles from each source, rather than changing the filename in this profile. The earlier Toys scripts below remain unchanged.

The independent source-band audit reports ambiguous intervals separately; colour thresholds cannot prove invisible paint. Review all source/rendered close-ups and record each resolution. Finalization writes candidates under the evidence directory, never the accepted Toys R You JSON. Promote a new course candidate only after inspection. Rebuild the saved game scene/resources with `author_tabletop.gd.build(course_id)` using that course's manifest. Re-save its entry from a fresh editor process after generating new resources so the UID cache has registered them.

Toys R Asleep revealed that GLB mesh compression can open tiny seams relative to raw source coordinates. Disable `meshes/force_disable_compression`'s inverse default (set it **true**) for its imported GLB, and check separated landmarks against the source. Also transform physics-probe endpoints into world space and hits back into track space; the current Race node has a slight rotation.

Run rendered, profile-read-only/controller-isolated probes with `tools/run_tabletop_verification.ps1`. Retain raw failures and verify the returned PID exits after completion. See `docs/verification/toys_r_asleep.md` for the first new-course evidence.

These are the actual Python analysis examples used during the accepted alignment correction. They are **course-specific prototypes**, not a generic importer. Do not run them against another GLB by merely changing its filename.

Read [the extraction guide](../../docs/tabletop-track-extraction-guide.md) and [the rollout plan](../../.summer/plans/2026-10-03-tabletop-glb-rollout.md) first.

## Files and dependencies

- measure_toys.py: rasterizes the selected model triangles and UV textures into upper-road and lower-floor maps.
- fit_toys_edges.py: finds two independent marking sequences using transverse searches and continuity; --refine recentres the search.
- finalize_toys_edges.py: snaps uncertain wood-corner samples, removes local correspondence folds, and samples actual triangle heights.
- toys_old_route.json: the original 1,392-span seed used in the successful investigation.
- toys_fitted_edges.json: the saved fitted boundaries before final correction. This is evidence, not the accepted final route.
- ../../tracks/toys_r_you/measured_route.json: the accepted final route. Never overwrite it automatically.

Python requires NumPy and Pillow. The bundled interpreter used here was C:/Users/jayte/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe. Discover the current bundled dependency path if this changes; SciPy/OpenCV are not required.

The scripts resolve the project root as parents[2] of their location, which is correct in tools/tabletop_reference/. Their temporary input/output paths remain tests/probes/toys_*. Running them generates about 100 MB of intermediate raster data there. Archive scratch data after inspection; do not ship it as game content.

## Reconstruct the source mesh audit

In Summer's bound project, execute this read/export script. It reads the accepted flattened environment, without modifying it:

~~~gdscript
func run(ctx):
    var root = load("res://environments/tabletop/toys_r_you.tscn").instantiate()
    var result = []
    for node in root.get_children():
        if node is MeshInstance3D:
            var arrays = node.mesh.surface_get_arrays(0)
            var vertices = []
            var uvs = []
            for vertex in arrays[Mesh.ARRAY_VERTEX]:
                var p = node.transform * vertex
                vertices.append([p.x, p.y, p.z])
            if arrays[Mesh.ARRAY_TEX_UV] != null:
                for uv in arrays[Mesh.ARRAY_TEX_UV]:
                    uvs.append([uv.x, uv.y])
            result.append({
                "name": str(node.name), "vertices": vertices, "uvs": uvs,
                "indices": Array(arrays[Mesh.ARRAY_INDEX])
            })
    var output = FileAccess.open("res://tests/probes/toys_mesh_audit.json", FileAccess.WRITE)
    output.store_string(JSON.stringify(result))
    ctx.report("exported", result.size())
    root.free()
~~~

Expected: 12 meshes. This exporter relies on Toys' already-flattened hierarchy and one surface per mesh. For another model, explicitly recurse transforms and export every surface with its material identity.

## Reproduce the final correction from the saved fit

From the project directory, with the editor bound if exporting:

~~~powershell
$python = 'C:/Users/jayte/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
Copy-Item tools/tabletop_reference/toys_old_route.json tests/probes/toys_old_route.json
Copy-Item tools/tabletop_reference/toys_fitted_edges.json tests/probes/toys_fitted_edges.json
& $python tools/tabletop_reference/measure_toys.py
& $python tools/tabletop_reference/finalize_toys_edges.py
~~~

Before copying, preserve any scratch files already at those destinations. The mesh audit must exist from the previous step, and the imported toys_r_you_0.png through toys_r_you_4.png textures must be present.

Inspect tests/probes/toys_alignment_final.png and compare tests/probes/toys_measured_route.json with the canonical measured_route.json. This documentation task preserved the sources and checked syntax; it did not rerun the full image-processing pipeline or overwrite accepted measurements.

## Original fitting sequence

The successful investigation first ran a narrower candidate scan (distance 1.0 through 6.5, spacing 0.025), then expanded it and used --refine once. The preserved fitter reflects the final expanded scan (0.5 through 9.0). Therefore, running its current defaults from scratch is an experiment and is not guaranteed to reproduce the saved intermediate fit exactly.

Use the saved fit above for the finalization reference. For a new course, derive its search parameters from its own scale and markings. Treat every fit as a candidate until independent image/model inspection passes.

## Known assumptions to replace for every new course

| Prototype assumption | Required adaptation |
|---|---|
| First six meshes and texture IDs [0,1,2,3,4,4] | Explicit inspected surface/material mapping |
| Flat hierarchy, surface 0 | Accumulate hierarchy transforms and export all primitives |
| 2600x2600, origin (-65,-65), 20 px/unit | Bounds/resolution computed for that course |
| UV clamping | Respect that material's UV transform and wrap mode |
| White ridge thresholds | Measured marking colours/contrast, especially night scenes |
| Sections 36–37 use floor-only map | An inspected surface/layer map |
| Ground-only snapping and Y<4 height ceiling | Layer-aware support limits for the model |
| Linear DP pass | Explicit seam closure and confidence review |
| Local fold removal | Topology review so genuine turns/overpasses are preserved |
| 58 sections implied by seed | Course-specific count, retaining 24 spans per section |

The reference finalizer reports local fold removals; those reports are not proof that every legal-road polygon is valid. Always run the topology, source-alignment and gameplay gates in the guide.

## Regenerate accepted resources only when intentionally requested

To rebuild the accepted Toys route from canonical measurements, use Summer's editor scripting tool:

~~~gdscript
func run(ctx):
    ctx.report("alignment", load("res://scripts/tracks/align_toys_r_you.gd").apply_measurement())
~~~

Expected: errors=[], length approximately 475.023. This writes definition.tres, entry.tres and preview.res. It does not fit new boundaries. Do not invoke it merely to read documentation.
