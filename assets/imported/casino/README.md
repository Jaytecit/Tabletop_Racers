# Casino source assets

Imported from the owner's local Sketchfab downloads on 2026-10-03.

- `casino-2.zip`: `source/casino2.fbx` and supplied textures. The owner identifies this model as CC0; the archive contains no licence document or source URL.
- `casino-chips-free-model.zip`: nested `source/chip.zip`, containing `chip.gltf`, geometry and textures. Licence/source URL were not included in the archive.

`chips/chips_gameplay.res` preserves the seven textured chip stacks with simplified triangle indices (1,924 triangles total). The original 90,000-triangle glTF remains available as the source.

The reproducible scene/course recipe is `scripts/tracks/author_roulette.gd`. It restores missing FBX material links, bakes mesh-shaped furniture support, completes the casino room, scatters chips in three distinct banks and authors the exposed route. Source coordinates are rotated and scaled by 24, with the felt at gameplay height zero. Car tuning is unchanged.
