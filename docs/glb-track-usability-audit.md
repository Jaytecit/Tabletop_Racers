# GLB Tracks suitability and extraction automation

> Reconciled 6 October 2026. This is the original 3 October source survey (37 files / 36 hashes), not the current playable count. Bazaar and Town Square are now integrated. The current source register covers 42 files / 41 hashes, and the catalogue has eleven courses. Use the disposition register and current rollout for next work; preserve original survey measurements below. See [current build](current-build.md) and [remaining work](implementation-checklist.md).

Source survey: 2026-10-03. Folder: `tracks/GLB Tracks`.

**Implementation follow-up:** the dedicated-road boundary extractor is now implemented and proved on Topspeed Oval, including rendered import alignment, physical support and runtime corridor checks. See [the automation guide and evidence](automated-road-extraction.md). Topspeed is now a selectable, verified course; see [playable acceptance](verification/topspeed_oval.md).

**37 files, 36 unique SHA-256 hashes. All unique files yielded triangle geometry and embedded images with the survey reader. This establishes source readability, not engine compatibility or playable-course acceptance.** The initial Free Fire failure is retained; its rerun explicitly excludes one line helper. Seven files are exact matches to currently selectable imported courses; Beach Buggies matches the retained, removed course. The two Silverstone files are byte-identical.

The remaining straightforward candidates are **Bazaar and Town Square**; **Topspeed Oval is already integrated**. Each provisionally selected driving mesh union is a valid connected X/Z polygon with one hole. This is the same useful topology as Mount Rainier. Raceway is also promising, but its bridge requires a layer-aware extraction. Other racing models generally need manual surface selection, seam review or route choices before automation can be trusted. Room/world models need a designed course, rather than detection of an existing racing boundary.

## Evidence and limits

- `tests/baselines/content/glb_folder_audit/inventory.json`: hashes, embedded metadata, triangle counts, transformed primitive bounds, geometry/UV hashes, materials and image dimensions for all 37 files. Includes the original Free Fire failure.
- `free_fire_triangle_rerun/inventory.json` in that directory: successful 140,212-triangle read, explicitly recording the skipped `Object_7` line primitive (mode 1).
- `duplicates.json`: the Silverstone pair.
- `road_topology.json`: projected unions of 12 provisional road selections, including the Mount Rainier reference.
- `road_topology_baked.json`: the three small baked racing environments' dedicated driving collision meshes.
- `*_road.geojson`, `*_road.png`, `road_plans_1.jpg`, `road_plans_baked_1.jpg`: source-derived provisional road footprints and independent perimeter rings.
- `*_texture_*.jpg`, `selected_atlases.jpg`, `plans_*.jpg`: texture thumbnails and geometry diagnostics. Name-based cyan highlighting is a candidate aid, not road classification. Some full-model plans are obscured by skyboxes or large floors; use isolated road plans and UV/material inspection instead.

No new course was authored, no existing route was remeasured, and no new rendered gameplay acceptance was performed. Existing integration status comes from the current catalogue and saved manifests/verification records. Raw source topology diagnostics must not be interpreted as physical support tests. Triangle unions in X/Z can merge unrelated vertical layers; no automatic seam snapping was applied.

## Per-file assessment

“Candidate” means technically plausible from inspected source data. New candidates still require selected-surface visual correspondence, correct heights/collision, checkpoint placement, vehicle scaling, performance review and the repository's gameplay gates.

| File | Current use / suitability | Extraction approach and remaining work |
|---|---|---|
| `3ds_wuhu_loop.glb` | Candidate; 12,136 triangles | Named `Wi_Road` and `Wi_CheckPtRoad`. Initial projection has 41 components; review genuine gaps, jumps, ancillary pieces and traversal before stitching. |
| `asphalt_injection_-_chamonixalps.glb` | Candidate | Explicit road groups; main footprint plus four minor components. Shortcuts/wood transitions, many projected holes and large source coordinates need surface and layer review. |
| `asphalt_injection_-_shanghai.glb` | Candidate | Named road segments, crossings and branches. Main footprint plus four minor components; select one circuit and separate stacked surfaces. |
| `bazaar_track.glb` | Strong candidate; 16,246 triangles total | Dedicated 106-triangle driving collision mesh gives one valid polygon with one hole. Compare collision edge with UV-mapped visible road; exclude wall collision. |
| `chicken-gun-fruzer-city.glb` | Custom-course environment | Modular road network; choose a closed route and define junction boundaries. Road meshes and signs must be separated. No unique automatic racing loop. |
| `chicken_gun_fruzer_-_encampment.glb` | Environment; suitability needs authored route | Generic/merged environment geometry; no clearly named race corridor. 101 embedded images; surface selection and performance work required. |
| `chicken_gun_fruzer_cyberpunk.glb` | Custom-course environment | Named road pieces and markings form a network. Route choice, intersection clipping and collision/prop review required. |
| `chiostro_ex_convento_di_civitaretenga_laquila.glb` | Scanned environment; poor fit for automatic circuit extraction | Three generic textured meshes, 250,000 triangles. No dedicated road identity found. Needs a designed supported course. Embedded licence differs; see metadata note below. |
| `circuit_de_spa-francorchamps_1939_layout.glb` | Circuit candidate; 720,698 triangles | Road-like pieces exist, but broad name matching includes scenery/signs. Requires explicit surface selection and exclusion of alternate/ancillary roads. |
| `cnr_ds_-_death_rally.glb` | Lightweight candidate; 4,161 triangles | Named bend/start/split pieces. Five substantial disconnected projected parts; do not claim a complete circuit until gaps/route branches are resolved. |
| `free_fire_burmuda_map_the_circuit_3d_model.glb` | Conditional map candidate | Triangle read succeeds after skipping a line helper. Generic materials/nodes need surface segmentation and course selection. Embedded licence is Sketchfab Standard, not CC BY. |
| `gt_racing_2_-_barcelona.glb` | Conditional road-network candidate | Dedicated road groups, but initial union has 16 components and road junctions. Select the intended loop. Embedded licence differs; see below. |
| `gt_racing_2_-_glen_canyon_dam.glb` | Candidate requiring route/surface review | Named road groups; two substantial projected areas plus tiny fragments. The provisional selection does not prove a closed drivable route. |
| `gt_racing_2_-_lake_como.glb` | Candidate requiring finer road classification | Road/causeway groups include broad filled areas in projection. Select actual driving triangles within these groups; whole-node selection is insufficient. |
| `gt_racing_2_-_montreal.glb` | Candidate requiring finer road classification | Named road groups include broad areas and branches; nine projected parts. Inspect UV/material regions and select the circuit. |
| `gt_racing_2_-_mount_rainier.glb` | Exact match to active Mount Rainier | Existing independent asphalt rings, monotonic pairing and barycentric heights. Reference selection again gives one polygon with one hole. Preserve canonical measurements. |
| `gt_racing_2_-_sunrise_ruins.glb` | Candidate requiring mixed-surface classification | Road-named groups include broad ground geometry; two substantial projected areas with many holes. Use triangle/texture selection and explicit surface transitions. |
| `gt_racing_2_-_topspeed_oval.glb` | Strong candidate | Two `ringoval_road` primitives give one valid polygon with one hole. Exclude separately named drag strips; inspect banking and sample each boundary/centre height independently. |
| `low_poly_room.glb` | Custom miniature-course environment; 15,626 triangles | Furniture/floor environment without a named racing corridor. Author a route using supported surfaces and props; boundaries are a design decision. |
| `marina_bay_street_circuit.glb` | Circuit candidate; 813,533 triangles | Generic `Object_*` nodes and 99 images; manual road classification first. Material/node count warrants batching and rendered performance review. |
| `monza_circuit_1998_layout.glb` | Circuit candidate; 151,548 triangles | Generic nodes and 99 images. Select road versus terrain/barriers and distinguish intended layout/pit road before perimeter extraction. |
| `nurburgring_gp_2016_layout.glb` | Circuit candidate; 310,377 triangles | Generic node/material identities; inspect road surfaces and layout choices. Image dimensions imply about 295 MB for one RGBA level across image entries, before compression/deduplication. |
| `pool.glb` | Custom-course environment | 305,624 triangles in 3,213 mesh entries. No named road corridor; author a supported poolside route and review batching/collision. Mesh entries are not a measured draw-call count. |
| `race_game_environment.glb` | Unresolved environment/circuit candidate | 470,867 triangles split across generic meshes, shared material and sky image. Filename alone does not establish a usable road; needs triangle/UV or vertex-attribute segmentation. |
| `race_track_map.glb` | Promising road candidate; 607,261 triangles total | Explicit `ROAD` material yields three disjoint annular polygons. Select intended component(s), confirm visible start/finish connection and exclude kerbs/lines/fences. |
| `raceway_map.glb` | Strong layered candidate; 18,580 triangles total | Dedicated 363-triangle driving collision mesh and explicit bridge node. Projection has three holes; avoid flattening the bridge crossing. Review extra hidden collision mesh separately. |
| `silverstone_circuit_2024_layout (1).glb` | Duplicate | Identical hash to the other Silverstone file; one integration only. Do not delete either source automatically. |
| `silverstone_circuit_2024_layout.glb` | Circuit candidate; 1,197,030 triangles, 165.82 MB | Numerous generic nodes; classify road and alternative layouts, exclude surroundings, review geometry/material batching and performance. |
| `suzuka_circuit_2001_layout.glb` | Layered circuit candidate; 351,143 triangles | Generic node/material names. Establish actual road surfaces and crossing layers before union; require separate source heights at crossings. |
| `table_top_racing_-_firefly_bbq.glb` | Exact match to active Firefly BBQ | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_moonlight_junk_heap.glb` | Exact match to active Moonlight Junk Heap | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_nighttime_noodles.glb` | Exact match to active Nighttime Noodles | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_rusty_nuts_workshop.glb` | Exact match to active Rusty Nuts Workshop | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_toys_r_asleep.glb` | Exact match to active Toys R Asleep | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_toys_r_you.glb` | Exact match to active Toys R You | Accepted canonical UV/paint-derived route; preserve it. |
| `table_top_racing_beach_buggies.glb` | Exact match to retained Beach Buggies asset | Removed from playable catalogue at user request; source measurements remain available. No reinstatement in this survey. |
| `town_square_track.glb` | Strong candidate; 15,879 triangles total | Dedicated 293-triangle driving collision mesh gives one valid polygon with one hole. Compare perimeter with visible baked road and exclude wall collision. |

## What automation can reliably do

Mount Rainier's procedure is largely automatic **after the correct road surface and route are identified**: accumulate node transforms, union selected driving triangles, extract independent perimeter rings, pair their traversal monotonically, and sample left/right/centre heights from the correct source triangles. A fixed-width traced centreline is not involved.

The folder survey demonstrates that names alone are insufficient: some road groups also contain plazas/ground, sign meshes contain “road”, crossings lose height in a flat projection, and generic object names hide useful roads. Small disconnected parts may be import seams, helpers or real route breaks. Do not automatically merge them with an arbitrary tolerance.

Use a review-assisted importer with three extraction branches:

1. **Dedicated road or driving collision mesh:** use 3D boundary topology, retaining separate layer identities. For a single non-overlapping annular road, the mountain X/Z union and monotonic ring pairing are appropriate. Validate visual and collision perimeter agreement.
2. **Painted or baked road on a broader mesh:** reuse `raster_source.py`, `fit_source.py`, `finalize_source.py` and `verify_source.py`. UV-map the correct texture, fit both edges independently, record confidence, and review missing/ambiguous spans. A collision mesh can provide support or candidate limits without replacing painted legal-road boundaries.
3. **Branched network or open environment:** select/design the route first. Represent traversed road pieces as an ordered layer-aware graph, clip junction corridors, then extract boundaries along that selected route. An automatic graph can suggest loops, but cannot infer the intended race or rule on shortcuts.

A practical front end should ask for the driving surfaces, initial start/direction and branch choices only where necessary. It should then generate a candidate manifest, both 3D boundaries, ordered cross-sections, a source comparison report and confidence/uncertainty overlays. Use source hashes plus node and primitive identities; materials are useful hints, not sole truth. Source and game coordinates must share one recorded transform. Choose scale from supported width and current vehicle dimensions, rather than copying Mount Rainier's scale or its six-unit median-width target blindly.

Pairing should preserve both measured boundaries and avoid hairpin jumps. Store each centre height from its own intended triangle hit. Reject unsupported points and conflicting layers. Export the existing 24-span/25-sample section format only after cyclic seam, polygon fold, joins and layer-transition checks pass. Candidates stay in evidence folders until accepted.

Once approved geometry is available, reuse `author_tabletop.gd` for scene flattening, collision and resources. Place checkpoint cues on actual gate planes with measured shoulders/clearance, recognising original START artwork. Run the existing isolated, read-only-profile, hardware-input-isolated rendered verification. Successful boundary extraction alone must not automatically register a playable course.

## Reusable survey commands

Requires the existing bundled Python with NumPy, Pillow and Shapely. These commands write source-analysis evidence only:

```powershell
$auditPython = 'C:/Users/jayte/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
& $auditPython tools/tabletop_reference/audit_glb_folder.py
& $auditPython tools/tabletop_reference/survey_road_topology.py
```

`audit_glb_folder.py` supports `--folder`, `--output` and `--only <exact filename>`. `survey_road_topology.py` supports `--only <filenames...>` and `--label <evidence suffix>`. Its current surface selectors are explicit provisional rules for this surveyed set, not a universal road detector. The new helpers do not invoke engine authoring or alter the older mountain/tabletop extraction code.

The manifest-driven annular-road extractor is implemented and proved through Topspeed's source, rendered geometry and playable acceptance. Next candidates are Bazaar and Town Square. Connecting the UV extraction branch and layered bridge handling remains future work; each course requires independent acceptance. Keep each course's acceptance inline and independent.

## Metadata and performance considerations

Embedded metadata labels 33 unique assets CC BY 4.0, Barcelona and the Civitaretenga scan CC BY-NC-ND 4.0, and Free Fire Sketchfab Standard. These are metadata findings, not verification of uploader rights or permission for the intended game distribution. The two differing Creative Commons labels and Standard licence require separate rights review before integration/distribution. Source URLs and author names are preserved in inventory.json.

Triangle/material counts and image dimensions identify likely costs, but do not establish frame rate, memory use or load time. Decoded RGBA image estimates exclude mipmaps and can overcount shared content; engine compression changes resident cost. Inspect one selected course at a time and compare rendered performance at the same settings as Mount Rainier. Exclude skyboxes/lens flares/helper geometry deliberately, batch scenery where useful, and build collision from reviewed driving/obstacle surfaces rather than every decorative triangle.

A requested skills.sh method search found general glTF-loading guidance rather than a ready-made racing-boundary extractor: https://www.skills.sh/gamedev-skills/awesome-gamedev-agent-skills/threejs-gltf-loading . Its relevant takeaway is to inspect hierarchy and compression/texture variants. The local survey reports extensions, preserves cumulative transforms and handles explicit non-triangle helpers; no browser rendering stack or new dependency installation is needed here.
