# Animated imported vehicles

The normal game now uses separate wheel meshes for the beach buggy, monster truck, racing car and drift car. The speedboat remains a jet boat with no propeller animation.

Original GLBs and external textures are unchanged. A full pre-rollout asset backup and script snapshot are preserved in `archive/vehicles-before-wheel-rollout-2026-10-04/`; the earlier buggy proof backup is also retained.

## Implementation

- `tools/build_animated_vehicle.py <vehicle_id>` generates each derived GLB under `assets/vehicles/animated/`, using individual measured axle positions, radii and tyre separation planes. All original triangles, UV coordinates and normals are retained. The drift car excludes cyan arch paint from wheel selection so the arches remain stationary.
- `scripts/vehicles/imported_visual.gd` loads the engine's imported scenes, moves each tyre beneath its axle mount, and adds opaque inner hubs over the extraction joins. The drift car uses a smaller visual steering lock to accommodate its arches.
- `vehicle_visual_motion.gd` reads measured wheel-radius metadata for these meshes. Spin follows signed travel, front wheels steer, and rear wheels stay fixed. Handling, collision definitions and tracks are unchanged.
- `player_paint.gdshader` recolours the original painted texture regions for vehicle palettes. The initial animation probe covered four original colours; [later palette coverage](character-roster-and-colours.md) covers eight. It supports the truck's two-tone body and protects the drift car's window region. Stock tyre/rim details remain original. Gold and purchased paints retain their existing overrides.
- Garage previews copy the current runtime hierarchy without reinstantiating the source scene, ensuring wheels stay separate and paint materials remain independent. Driver changes update the player's colour and rival assignments.

## Verification

`tests/probes/animated_vehicle_rollout.gd` passed in a rendered, hardware-isolated child using a read-only profile. Evidence: `tests/evidence/animated-vehicles-2026-10-04-complete/`.

Checks cover all five classes, forward and reverse travel, signed wheel spin, front/rear steering, four driver colours, driver selection, preview paint, gold/chrome paint and stock restoration, switching back to the buggy, and the jet boat's lack of a propeller. Four wheel rotation poses plus front/rear exterior views were captured and inspected. Source-preservation hashes confirm all five original GLBs and textures are unchanged.

The final child exited normally with no runtime or shutdown errors or warnings. Earlier failed evidence is preserved, including the drift arch/paint refinement, preview scene duplication correction, and the probe's explicit audio cleanup before exit. Verbose diagnostic runs also exposed unrelated Vulkan overlay-manifest warnings.

The original buggy demonstration remains an opt-in historical proof. Normal game launches now use the integrated versions.
