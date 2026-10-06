# Bazaar production integration — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Bazaar is registered in the production course selector as **ROAD · BAZAAR**, assigned to the racing car. It is available through the shared Quick Race, Time Trial and Freestyle catalogue. Its measured route, original scenery/collision, timing stripe, checkpoint cues and existing CC BY 4.0 credits are retained. No permanent generated road edges were added.

`content_catalog.gd` adds the course ID/title, road classification and tabletop environment path. `profile_store.gd` accepts Bazaar record keys and historical record data. The existing profile schema does not change. The course catalogue now contains ten entries. The staged test helper detects registration and leaves the production selector untouched; final probes assert its actual script identity.

## Assigned-vehicle stat coverage

Both final runs use four racing cars, three Hard laps and seeds 64/128/256/512. Starting/full upgrades apply to the player; rivals retain the game's neutral reference stats. Both pass 2,664 physical support rays, 480 gate cases, flag plane/support/clearance, complete race classification, throttle/boost, pause, recovery and procedural/Bazaar switching. Every racer finishes without crashes, AI recoveries or gate penalties. Ordinary contacts occur.

| Evidence under `tests/baselines/content/bazaar` | Finish times, players 1–4 (s) | Contacts, players 1–4 | Wall-frame p95 (ms) | Exited PID |
|---|---|---|---|---|
| `registered-starting01` | 81.884 / 82.035 / 82.855 / 67.669 | 1 / 48 / 26 / 15 | 32.569 | 107744 |
| `registered-full01` | 53.975 / 64.019 / 67.257 / 64.786 | 0 / 6 / 3 / 4 | 30.442 | 118496 |

The full player build is faster than the starting build in these deterministic reference races. This verifies playable upgrade extremes, not owner-calibrated AI or a statistically complete balance study. Earlier [five-class neutral coverage](bazaar-vehicle-classes.md) remains valid evidence for those revisions. Results frames were inspected.

## Production selector, records and loading

`registered-menu01` and final `registered-menu02` pass actual selector signals, assigned racing-car label/preview, Quick Race motion/pause/retry, one clean solo Time Trial lap, results/return and Freestyle truck preservation through Roulette/Bazaar switching. The fixture receipt reports `production_registered=true`, and the active selector is the unmodified production script. An evidence-local profile file saves and reloads Bazaar selection, racing-car assignment, Time Trial mode and the course-specific record key. The game profile remains read-only; no user profile or ghost file is changed. Final selection signatures equal independently refreshed signatures in both Quick Race and Time Trial.

`registered-loading01` retains a failed budget result: Bazaar loading passes, but Roulette return-switch gaps reach 328/317ms. Vehicle selection already calls `garage.select()` → `apply_stats()` → `trial.refresh_signature()` using the committed route, entry, vehicle and stats; SelectedCourse then hashed the same signature again. Removing only that duplicate refresh preserves signature inputs and is covered by the independent signature checks. Signature cost remains included in vehicle configuration; the separate `record_signature_ms` stage now records essentially zero additional work.

Final `registered-loading02` passes all unchanged development budgets. First Bazaar selection is 1,408.204ms; warm repeats 517.299/509.152ms. Bazaar worst process gap is 114.188ms; the complete alternating-course run's worst gap is 155.160ms. OS peak working set is 901.6MiB. These are same-machine rendered development measurements, not a release benchmark or isolated GPU timer.

All six disposable children exited with code 0 and were confirmed absent: 107744, 118496, 109228, 12792, 58440 and 101620. The failing loading run is retained. Passing probes have finished/passed results, no captured errors, no frame warnings and no shutdown errors. The user's editor was not stopped.

Production source SHA-256: catalogue `bef43b43f1a9a695d4352b38734380fbe0f303068c50060155314e49bc0bf020`; profile store `7b671a279f2d8f3a437fb44a28ce9f0f32fc976dc7a82c3d9727262982ab0899`; selector `1e15e34c9223cc5dd51bb50a2768cc54725b32611689ab8a22df83e4d0c6e52e`.

## Remaining project targets

Bazaar integration and selector registration are complete. The shared 16.7ms racing wall-frame p95 target is still unmet (30.442–32.569ms in these runs), as already recorded for other active courses. Further race-performance work and a fresh release-loading comparison remain tracked; no performance target is marked passed. Owner benchmark collection and AI calibration remain separate project milestones. Town Square is the next course in the rollout queue.
