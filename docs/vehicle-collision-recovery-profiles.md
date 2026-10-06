# Vehicle lighting, contact and recovery — 6 October 2026

Rear illumination follows the final paint colour, including unlocked paint and gold livery. Its energy is 0.18 (previously 1.1), with a 0.65-unit radius (previously 1.4). The separate red brake-light lenses emit at 3.5 while braking and 0.08 otherwise. Reusing the lamp rig prevents duplicated lights when changing classes or lighting presets.

The horizontal collider envelope is 94% of the vehicle definition, matching the imported model fitting scale; vertical height and slope alignment remain unchanged. Physics margin is 0.005 units. Developer tuning and race resets apply the same envelope.

Scenery contacts retain 97% of tangential velocity and return 22% of inward speed along the contact normal, capped at 3 units/s. Glancing touches therefore slide and deflect; direct hits rebound. Car contacts exchange a shared impulse based on relative closing speed. Multiple contact planes are processed in sequence. Impact feedback is limited to once per 0.25 seconds; the body leans away from contact and compresses its suspension before settling.

Recovery is an explicit arcade rescue reset, separate from ordinary impacts. Reset requests, unsupported surfaces, course-rule failures and existing AI stuck detection retain their triggers. States 1/2 stop motion and contract the model in place over 0.35 seconds; state 3 transfers it while hidden and eases it back to full size over 0.85 seconds. Both durations use the existing recovery-speed stat. This replaces the uncontrolled spinning and collision-free flight across scenery. Recovery anchors remain behind legal progress and surface-compatible. A body-volume physics query rejects scenery obstruction, and traffic spacing is checked every frame during arrival. A newly blocked target cancels arrival and waits for another clear anchor. Progress is rebased only after arrival; existing immunity is retained.

Portraits 4–7 are additional selectable profile identities. They reuse the starting skill allocations of portraits 0–3 respectively and have their own catalogue names/bios. Saved identities support all eight portraits; the four legacy stat-build choices remain mapped by modulo four. AI portraits use successive IDs after the player, wrapping at eight, so up to eight racers have different faces. Portrait names/bios and explicit palettes come from the [character catalogue](character-roster-and-colours.md). Podium faces use these same identities.

## Generated portrait assets

Built-in image generation produced `assets/arcade/driver_4.png` through `driver_7.png`, using `assets/arcade/drivers.png` as the style reference. The original cast was preserved.

## Verification

`tests/probes/vehicle_collision_profiles_verification.gd` exercises real wall contacts, direct and glancing deflections, impact motion, recovery departure/arrival and blocked landings, all eight picker signals, unique racer identities, stat reuse, and new-profile creation/reload in disposable fixtures. Personal profiles remain read-only and hardware input is isolated.

Passing evidence: `tests/evidence/vehicle-collision-profiles-04`. Glancing contact changed velocity from `(9,0,3)` to `(8.73,0,-0.66)`; direct contact from `(0,0,9)` to `(0,0,-1.98)`. No runtime or shutdown errors; the exact child process exited.

Race evidence: `tests/evidence/vehicle-collision-hard-race/buggy`. One three-lap Beach Buggy race on Hard at Game Table passed. All four cars finished in 129.06–132.02 seconds with no penalties. The player had zero crashes/recoveries; one AI triggered one recovery during the race and finished. Runtime and shutdown diagnostics were clean, and PID 76896 exited normally. These checks cover this shared-mechanic change, not an additional per-course rollout or mode matrix.

Earlier failures are preserved: `-01` caught the developer reset restoring the original collider; `-02` caught test audio resources retained at shutdown; `-03` enabled verbose Vulkan diagnostics and exposed missing external Epic overlay manifests and hardware texture-format warnings. The collider reset and test cleanup were corrected; `-04` uses the normal renderer configuration.
