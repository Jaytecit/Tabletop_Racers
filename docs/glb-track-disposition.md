# GLB source disposition register

> Reconciled 6 October 2026. The current register has 42 files / 41 source hashes and ten active imported sources plus procedural Roulette: eleven courses. Town Square is integrated for Quick/Trial/Freestyle; Raceway is next proposed candidate. No original source deletion is requested. Mode/field expansion does not override capability gates. See [current build](current-build.md) and [remaining work](implementation-checklist.md).

Reconciled 5 October 2026: 42 files, 41 unique sources. All original 37 hashes match; only the five added sources received targeted geometry/texture surveys. Original failures and reruns remain preserved.

The [machine-readable register](glb-track-disposition.json) contains complete hashes, credits, cost estimates, topology evidence, sampled widths, capability metadata and reasons. Unknown width/layers are explicit null values; they are not assumed flat or playable. Decoded RGBA costs exclude mipmaps/compression/deduplication and are not measured resident memory.

`needs-repair` means classification, seams or layers need work; it does not assert a damaged or unusable model. `authored-route-required` needs an explicit circuit choice. Town Square is integrated for Quick Race, Time Trial and Freestyle; other mode trials remain pending. Beach Buggies is owner-retired and retained inactive, not rejected geometry.

No new source is confirmed unusable. No sources moved or deleted. The duplicate Silverstone file stays recoverable and both names resolve to one identity. Source GLBs already sit outside catalogue dependencies and are excluded by the Windows export preset. Sources, metadata and failed audit evidence remain intact.

Mode capability is independent of category. Only accepted routes enter the runtime capability table; current mode availability is preserved. Full per-course mode balance/physical coverage remains pending. Task 10 uses bedroom framing selected by each course entry's `presentation` metadata; the old `loft: false` register fields refer to the superseded loft proposal. Procedural Roulette is active separately and has no GLB source row.

## Task 10 bedroom asset

The owner supplied six skybox GLBs in `environments/`. The two room candidates are enclosing textured spheres. `skybox_stylized_room.glb` (960 triangles) supplies the selected bedroom panorama; the pink hotel-room alternative (360 triangles) remains unused. Other supplied skyboxes remain unchanged and inactive. Source metadata and hashes are retained in `tests/baselines/presentation/bedroom/source/skybox_inventory.json`.

Selected source: “Skybox Stylized Room” by Van_Twinkle, https://sketchfab.com/Van_Twinkle, https://sketchfab.com/3d-models/skybox-stylized-room-41f386740dbb4de7af2724734f98151f, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Extracted the embedded 1024×512 panorama, flipped vertically to match the sky renderer and added mipmaps. The original GLB is preserved; `tools/author_bedroom_panorama.gd` rebuilds the runtime `.res`. Attribution is in-game and in `environments/bedroom/SKYBOX_CREDITS.md`. No new pack was acquired.

`bedroom_display.gd` adds only a panorama sky. On 5 October the owner removed the table/legs requirement and accepted all centrally framed courses without further test runs. The translation-invariant sky keeps every camera at its centre without moving accepted course geometry. Source geometry, accepted transforms, route data, checkpoint flags, vehicle assignments and mode eligibility are preserved. The sky uses a 65° FOV override to prevent orthographic stretching and is restored on course switches. The same presentation appears in the course-selection flyover. Enabled for the four active ROAD courses: Town Square, Bazaar, Mount Rainier and Topspeed Oval. Earlier prototype evidence and failures are retained in [verification](verification/bedroom-presentation.md).

| Source | Status | Triangles / source MB | Route/support and next gate |
|---|---|---|---|
| `033_racetrack.glb` | needs-repair | 25,057 / 1.76 | New source: select driving primitives, review topology/layers/start cue, and measure width before extraction. |
| `3ds_wuhu_loop.glb` | needs-repair | 12,136 / 1.8 | Named `Wi_Road` and `Wi_CheckPtRoad`. Initial projection has 41 components; review genuine gaps, jumps, ancillary pieces and traversal before stitching. |
| `asphalt_injection_-_chamonixalps.glb` | needs-repair | 180,096 / 45.03 | Explicit road groups; main footprint plus four minor components. Shortcuts/wood transitions, many projected holes and large source coordinates need surface and layer review. |
| `asphalt_injection_-_shanghai.glb` | needs-repair | 233,152 / 41.28 | Named road segments, crossings and branches. Main footprint plus four minor components; select one circuit and separate stacked surfaces. |
| `bazaar_track.glb` | active | 16,246 / 13.09 | Dedicated 106-triangle driving collision mesh gives one valid polygon with one hole. Compare collision edge with UV-mapped visible road; exclude wall collision. |
| `blitzway_gp_main_course.glb` | needs-repair | 122,736 / 12.89 | New source: select driving primitives, review topology/layers/start cue, and measure width before extraction. |
| `cartoon_race_track_-_oval.glb` | needs-repair | 1,778,838 / 179.02 | New source: select driving primitives, review topology/layers/start cue, and measure width before extraction. |
| `chicken-gun-fruzer-city.glb` | authored-route-required | 309,042 / 25.47 | Modular road network; choose a closed route and define junction boundaries. Road meshes and signs must be separated. No unique automatic racing loop. |
| `chicken_gun_fruzer_-_encampment.glb` | authored-route-required | 156,918 / 32.18 | Generic/merged environment geometry; no clearly named race corridor. 101 embedded images; surface selection and performance work required. |
| `chicken_gun_fruzer_cyberpunk.glb` | authored-route-required | 404,758 / 44.25 | Named road pieces and markings form a network. Route choice, intersection clipping and collision/prop review required. |
| `chiostro_ex_convento_di_civitaretenga_laquila.glb` | authored-route-required | 250,000 / 20.77 | Three generic textured meshes, 250,000 triangles. No dedicated road identity found. Needs a designed supported course. Embedded licence differs; see metadata note below. |
| `circuit_de_spa-francorchamps_1939_layout.glb` | needs-repair | 720,698 / 70.95 | Road-like pieces exist, but broad name matching includes scenery/signs. Requires explicit surface selection and exclusion of alternate/ancillary roads. |
| `cnr_ds_-_death_rally.glb` | needs-repair | 4,161 / 0.55 | Named bend/start/split pieces. Five substantial disconnected projected parts; do not claim a complete circuit until gaps/route branches are resolved. |
| `free_fire_burmuda_map_the_circuit_3d_model.glb` | needs-repair | 140,212 / 16.41 | Triangle read succeeds after skipping a line helper. Generic materials/nodes need surface segmentation and course selection. Embedded licence is Sketchfab Standard, not CC BY. |
| `gt_racing_2_-_barcelona.glb` | authored-route-required | 141,484 / 61.27 | Dedicated road groups, but initial union has 16 components and road junctions. Select the intended loop. Embedded licence differs; see below. |
| `gt_racing_2_-_glen_canyon_dam.glb` | needs-repair | 113,607 / 40.54 | Named road groups; two substantial projected areas plus tiny fragments. The provisional selection does not prove a closed drivable route. |
| `gt_racing_2_-_lake_como.glb` | needs-repair | 115,966 / 81.71 | Road/causeway groups include broad filled areas in projection. Select actual driving triangles within these groups; whole-node selection is insufficient. |
| `gt_racing_2_-_montreal.glb` | needs-repair | 96,178 / 42.24 | Named road groups include broad areas and branches; nine projected parts. Inspect UV/material regions and select the circuit. |
| `gt_racing_2_-_mount_rainier.glb` | active | 105,407 / 47.63 | Existing independent asphalt rings, monotonic pairing and barycentric heights. Reference selection again gives one polygon with one hole. Preserve canonical measurements. |
| `gt_racing_2_-_sunrise_ruins.glb` | needs-repair | 91,417 / 42.65 | Road-named groups include broad ground geometry; two substantial projected areas with many holes. Use triangle/texture selection and explicit surface transitions. |
| `gt_racing_2_-_topspeed_oval.glb` | active | 94,580 / 32.56 | Two `ringoval_road` primitives give one valid polygon with one hole. Exclude separately named drag strips; inspect banking and sample each boundary/centre height independently. |
| `low_poly_race_track.glb` | needs-repair | 6,352 / 0.43 | New source: select driving primitives, review topology/layers/start cue, and measure width before extraction. |
| `low_poly_room.glb` | authored-route-required | 15,626 / 5.16 | Furniture/floor environment without a named racing corridor. Author a route using supported surfaces and props; boundaries are a design decision. |
| `marina_bay_street_circuit.glb` | needs-repair | 813,533 / 59.5 | Generic `Object_*` nodes and 99 images; manual road classification first. Material/node count warrants batching and rendered performance review. |
| `monza_circuit_1998_layout.glb` | needs-repair | 151,548 / 48.77 | Generic nodes and 99 images. Select road versus terrain/barriers and distinguish intended layout/pit road before perimeter extraction. |
| `nurburgring_gp_2016_layout.glb` | needs-repair | 310,377 / 91.68 | Generic node/material identities; inspect road surfaces and layout choices. Image dimensions imply about 295 MB for one RGBA level across image entries, before compression/deduplication. |
| `pool.glb` | authored-route-required | 305,624 / 21.21 | 305,624 triangles in 3,213 mesh entries. No named road corridor; author a supported poolside route and review batching/collision. Mesh entries are not a measured draw-call count. |
| `race_game_environment.glb` | authored-route-required | 470,867 / 36.48 | 470,867 triangles split across generic meshes, shared material and sky image. Filename alone does not establish a usable road; needs triangle/UV or vertex-attribute segmentation. |
| `race_track.glb` | needs-repair | 473,037 / 26.32 | New source: select driving primitives, review topology/layers/start cue, and measure width before extraction. |
| `race_track_map.glb` | needs-repair | 607,261 / 72.41 | Explicit `ROAD` material yields three disjoint annular polygons. Select intended component(s), confirm visible start/finish connection and exclude kerbs/lines/fences. |
| `raceway_map.glb` | needs-repair | 18,580 / 9.0 | Dedicated 363-triangle driving collision mesh and explicit bridge node. Projection has three holes; avoid flattening the bridge crossing. Review extra hidden collision mesh separately. |
| `silverstone_circuit_2024_layout.glb` | needs-repair | 1,197,030 / 165.82 | Numerous generic nodes; classify road and alternative layouts, exclude surroundings, review geometry/material batching and performance. |
| `suzuka_circuit_2001_layout.glb` | needs-repair | 351,143 / 61.99 | Generic node/material names. Establish actual road surfaces and crossing layers before union; require separate source heights at crossings. |
| `table_top_racing_-_firefly_bbq.glb` | active | 13,907 / 14.1 | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_moonlight_junk_heap.glb` | active | 17,576 / 13.59 | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_nighttime_noodles.glb` | active | 21,611 / 14.23 | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_rusty_nuts_workshop.glb` | active | 22,339 / 17.81 | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_toys_r_asleep.glb` | active | 16,710 / 14.92 | Existing per-course UV/paint extraction and saved measurements. |
| `table_top_racing_-_toys_r_you.glb` | active | 17,161 / 11.74 | Accepted canonical UV/paint-derived route; preserve it. |
| `table_top_racing_beach_buggies.glb` | archived-unusable | 14,651 / 20.3 | Owner-retired, not geometrically unusable. Retained inactive; reinstatement requires a new request. |
| `town_square_track.glb` | active | 15,879 / 18.09 | Independent source boundaries/heights, support/gates, clean Hard races, five-class Freestyle and production selector/loading verified. [Evidence](verification/town_square.md); other modes pending. |
| `silverstone_circuit_2024_layout (1).glb` | duplicate | 1,197,030 / 165.82 | Identical hash to the other Silverstone file; one integration only. Do not delete either source automatically. |
