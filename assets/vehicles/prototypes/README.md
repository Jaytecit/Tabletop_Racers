# Buggy wheel and player-colour proof

The proof below is preserved as a historical comparison. The normal game now uses the four integrated animated vehicles; see `docs/animated-vehicles-integration.md`. Its original source assets remain unchanged.

The production `BeachBuggy.glb`, original texture, and vehicle integration scripts remain unchanged. The preserved copy and SHA-256 manifest are in `archive/buggy-before-wheel-proof-2026-10-04/`.

`BeachBuggy_wheel_proof.glb` contains the original textured triangles partitioned into one body and four wheels. `tools/build_buggy_wheel_prototype.py` reproduces it from the original. Wheels use measured axle pivots and retain their original UVs and normals. This is an opt-in prototype; the normal vehicle factory still loads the original GLB.

`scripts/vehicles/buggy_wheel_prototype.gd` creates the proof visual. `buggy_prototype_motion.gd` copies the existing motion behaviour with measured wheel radii instead of primitive-cylinder radii. `buggy_player_paint.gdshader` selectively recolours red texture pixels for red, blue, gold and green players; neutral cage, seats and tyre colours remain intact. This avoids four duplicate texture atlases. Red suspension details are included in the colour mask.

Rendered proof: `tests/evidence/buggy-wheel-proof-2026-10-04-run3/`. Assertions passed for forward travel, wheel spin, reverse travel and reverse spin, front steering and fixed rear steering. Four-colour and full-revolution frames were inspected. The renderer reported no errors or warnings, and the owned verification process exited normally. `preservation.json` confirms the original files still match the backup hashes. Failed initial runs are retained.

Run with a fresh evidence directory:

```powershell
& tools/run_tabletop_verification.ps1 -Probe res://tests/probes/buggy_wheel_proof.gd -Evidence tests/evidence/buggy-wheel-proof-new-run -MaxSeconds 90 -WaitAndCheck
```

The extraction uses cylindrical face selection, keeping all original triangles at the rest pose. Cut boundaries are not yet capped or retopologised. The inspected exterior views look suitable for a proof; inner seam cleanup and wider steering/suspension clearance inspection remain before production rollout. The animation GIF shows a controlled complete wheel revolution; the separate driving assertions exercise actual throttle and brake inputs.
