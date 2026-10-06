# Five-class integration â€” 4 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Implementation is in progress. This record describes performed checks, not completion of the full class/course matrix. See [design decisions](../vehicle-classes.md).

## Implemented

Five class definitions and independent procedural visuals share the existing controller, race rules and progression. Freestyle exposes class selection and remembers it separately from the standard course assignment. Schema 10 retains buggy upgrades, adds independent wallets/builds and preserves replaced incompatible records in legacy history. Road assignments are separate catalogue metadata; accepted route resources remain unchanged.

Freestyle uses 55% water speed for floating land vehicles and 50% land speed for skid-assisted boats. The HUD labels the active assistance. Collision boxes, grid spacing, recovery clearance and AI traffic margins use class dimensions. Ghost meshes follow the selected class and preserve hidden-part visibility.

## Rendered evidence

All probes inject the read-only sentinel before race setup, disable the hardware controller and erase hardware action bindings. Evidence-local profile saves do not touch the owner's profile. Exact process exits are recorded alongside each run.

| Evidence under `tests/baselines/vehicles/` | Observed result |
| --- | --- |
| `classes01` | Five classes passed forward/reverse movement, stationary steering/rudder, wheel/propeller motion, pause, recovery, separate record keys and progression save/reload. All five close views inspected. |
| `classes02` | Failed before running: an incorrectly placed probe block caused an indentation parse error. Raw stderr retained. PID exited. |
| `classes03` | Corrected probe passed, 58.018 seconds, no runtime errors/warnings. Adds real boost input, conservative swept tyre/body clearance at both locks and maximum cosmetic pitch/lean/compression, Freestyle preference retention and reload. |
| `classes03` water fixtures | All five passed movement, speed cap, flotation/skid visibility, recovery, missing-support rejection and standard water permission. These change a private resource copy's surface labels on existing geometry; they do **not** verify a rendered water course. |
| `truck-race01` | Four neutral monster trucks, Hard, seeds 64/128/256/512, three Toys R You laps. All finished: 143.478 / 144.194 / 147.007 / 144.616 seconds. Zero crashes, recoveries or penalties. Impacts 3/14/10/14. Runtime clean; grid and settled results inspected. Frame p50/p95/max 9.879/33.905/69.550 ms. |
| `drift-race01` | All four finished three laps, 138.474 / 139.648 / 144.403 / 140.406 seconds, no gate penalties. One rival had 98 contacts and one stall recovery; others had 16/13/19 contacts. Runtime clean. **Race completion passed, AI quality not accepted**: incident telemetry added to investigate the pile-up before tuning. |
| `racer-race01` | Four racing cars completed three laps in 129.493 / 130.157 / 130.912 / 131.404 seconds, zero crashes, recoveries or penalties; impacts 3/9/4/21. Runtime clean. Frame p50/p95/max 10.415/33.567/64.357 ms. |
| `records01` | 6.286-second isolated fixture passed: changed rules replace an incompatible faster record without comparing times; legacy context and ghost survive save/reload, backup rotation and pruning; current ghost loads; duplicate finish does not overwrite; all five class signatures differ. Schema-6 driver stats migrate only to the buggy, leaving new classes fresh. All writes confined to this evidence directory. |
| `drift-incidents` | Repeated three-lap run finished all cars without recovery, but car 3 had a sustained low-speed contact burst at station ~129.9. Incident positions/speeds retained. The variation from the first run is not presented as exact determinism. |
| `collision01` | Eight controlled approaches at station 122, two lanes for each wheeled class. All traversed the transition; only the new classes contacted the foam-ramp entrance at station ~129.7 on the left lane. Close frames and actual collider normals/paths retained. This identified a clearance issue despite the traversal assertions passing. |
| `boat-race01`, `boat-trace` | Failed completion: timeout. The diagnostic repeat showed every boat stuck airborne at stations 373â€“379, with falling velocity accumulating despite physical slope contact. Raw failures, live progress and deadline state preserved; PIDs exited. |

The first fix raised new-class collision clearance from 0.03 to the buggy's accepted 0.07 units, aligned their collision boxes to the supporting slope, and recognized actual upward-facing static-surface contact as landing. That revision initially preserved the original buggy's collision alignment and landing condition. `collision02` passed all ten approaches (five classes, both lanes), zero impacts/crashes, 66.353 seconds, no runtime errors/warnings, process exited. The two buggy endpoints exactly matched `collision01` at that revision.

`boat-race02` verifies the fix through three complete land-assisted laps for all four boats: 188.674 / 189.490 / 190.922 / 190.013 seconds. Zero crashes, recoveries or penalties; contacts 0/3/3/22. Runtime clean, 199.896 seconds total, PID 87908 exited. Frame p50/p95/max 10.116/33.470/64.198 ms. The settled results image was inspected, including the new mode/class/course label. The final retests below supersede this intermediate controller revision.

The `classes03` main menu, Freestyle garage and boat-assistance HUD were inspected at 1200Ã—800. Labels are readable and the three modes are exposed. This does not replace directional navigation or other-resolution checks.

`classes04` reran controls, water rules and the added collision-envelope checks successfully for the revised physics. It failed the new layout acceptance: Laps overlapped TrackSelect at 1280Ã—720, 1920Ã—1080 and 1600Ã—720. Screenshots preserve the defect. Shortening the difficulty/Solo labels and correcting the three control widths resolves it. The focused `layout01` rerun passes all visible-button bounds and pairwise spacing checks on all four setup pages at those three sizes, using the longest Nightmare/three-rival labels; runtime clean, 7.093 seconds, PID exited. The corrected 1280Ã—720 course page and 1920Ã—1080 garage were inspected.

`navigation01` passes 840 synthetic keyboard/D-pad/stick directional transitions with zero failures, including visible Freestyle vehicle controls, setup/stats/shop modals, row boundaries, held input and focus return. The subsequent flow checks real class changes, wrapping/reverse browsing, standard assignment, retained Freestyle selection, loading, start, driving, results and menu return. Runtime clean, 54.135 seconds, PID exited. This does not certify physical controller hardware.

`slow-slope01` is retained as a failed fixture: starting at station 350 with a start-line checkpoint index triggered missed-gate recovery during the eight-second observation window. The corrected fixture seeds the next checkpoint for its mid-route approach and records penalties explicitly; it is a transition test, not evidence of a completed lap.

Manual review rejected `slow-slope02`'s automatic pass: the new classes reached stations 396â€“398, but both original buggy approaches only reached ~375.51. Its threshold at 373 was too short to prove crossing the whole slope. The final criterion now requires station >390 and retains airborne/lift-speed diagnostics. The slope-alignment/contact-landing fix is now shared with the buggy, correcting an existing low-speed problem rather than preserving it. Canonical buggy tuning and route resources remain unchanged, but controller behaviour on slopes has changed; full-race comparison is required and old record signatures are retained as legacy rather than claimed equivalent.

`slow-slope03` uses the corrected >390-station acceptance: all ten approaches reach stations 396–398 with zero impacts, crashes or penalties and no airborne/lift state remaining. Runtime clean; PID 108816 exited. Physical support normals were subsequently converted from world space to Race-local space, matching route queries and heading; the final full-race runs below include that correction.

## Final shared slope revision

`toys-final` runs all five neutral classes sequentially, four cars each, Hard, seeds 64/128/256/512, three laps. Every car finished with zero crashes, recoveries and gate penalties. Each child has a confirmed exit receipt, no errors/frame warnings and empty stderr.

| Class | Finish times, player slots 1–4 (s) | Impacts |
| --- | --- | --- |
| Buggy | 135.522 / 131.295 / 136.952 / 136.208 | 1 / 0 / 2 / 3 |
| Monster truck | 140.815 / 141.531 / 142.818 / 141.954 | 0 / 18 / 3 / 13 |
| Racing car | 126.676 / 127.314 / 128.641 / 127.743 | 0 / 5 / 2 / 8 |
| Drift car | 133.392 / 134.115 / 135.521 / 134.501 | 0 / 5 / 5 / 9 |
| Speedboat (land assist) | 188.674 / 190.043 / 190.856 / 189.454 | 0 / 8 / 4 / 17 |

The final boat results frame was inspected: all four finish cards, class/course/mode context and Retry/Menu are readable. The read-only sentinel's saving-disabled notice is expected. `protected-hashes.json` confirms all six protected canonical files remain unchanged. Buggy times improve by roughly 1.1–1.4 seconds against the earlier cosmetic-only checkpoint; this is an intentional controller change, not exact physical parity. Handling version `classes-1` and source signatures retire incompatible comparisons while retaining legacy records.

## Still open

Class balance across surfaces and progression extremes, actual water-course integration, all active course/class combinations and broader rollout requirements. Navigation, layout and legacy replay checks listed above are performed; physical controller acceptance has not been inferred from synthetic inputs. No new class is declared balanced from a single neutral AI reference.
