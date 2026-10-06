# Bazaar loading and staged menu acceptance — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

**Current status:** Bazaar is now registered; see [production integration evidence](bazaar-registration.md). The staged runs below describe the earlier revisions they tested.

Bazaar remains outside the production catalogue. Disposable probes compile the current catalogue with Bazaar added as ROAD / racing_car, then use the current SelectedCourse source with only its catalogue binding replaced. The fixture records original source hashes and does not preload the candidate. Menu selection emits the real OptionButton signal; asynchronous resource loading, background validation, scene transfer, preview and race starts use the game implementation. This verifies staged integration, not production registration or profile persistence of an unregistered course.

## Loading stall and implementation

`loading-development01` and `loading-profile02` fail the 250ms process-gap budget despite successful selection. Initial Bazaar load is 1.314s, warm 0.704–0.720s; Bazaar gaps reach 317ms and Roulette 404ms. Detailed timings isolate 227–267ms in vehicle configuration, versus 2–5ms in course preview. `vehicle-load-profile01` reproduces repeated racing-car PackedScene loading at 220–320ms. Releasing the source scene after instantiation permits reparsing on later switches.

`imported_visual.gd` now retains two source PackedScenes, keyed by their original/animated path, with eviction. Vehicles still instantiate separate nodes and paint materials. `SelectedCourse.request_select()` asynchronously loads an uncached assigned/Freestyle vehicle source before committing; it checks the request serial after draining the result and rejects a failed source load without replacing the course. New stage timings distinguish vehicle resource loading, vehicle configuration, camera configuration, record hashing and course preview. No car physics, source models, route coordinates, collision or record-signature inputs changed.

`measure_course_loading.ps1` accepts a development probe override, refuses existing evidence, and checks process exit, timeout, captured errors, frame warnings, shutdown errors and five expected samples before enforcing the existing budgets. Custom-probe release runs are explicitly unsupported; no release package was rebuilt in this continuation.

## Final measurements

Same machine, Summer 0.5.68 / 4.7.2 custom, Forward+, RTX 4060 Ti, 1200×800. First means first selection in the process, not an OS disk-cache cold start. `loading-final04` passes all budgets: first selection ≤6s, warm ≤2s, process gap ≤250ms, peak working set ≤1GiB.

| Selection | Ready-to-present (ms) | Worst process gap (ms) | Presented frames |
|---|---:|---:|---:|
| Bazaar first | 1,344.415 | 116.141 | 78 |
| Roulette warm 1 | 267.227 | 229.660 | 8 |
| Bazaar warm 1 | 556.676 | 106.823 | 28 |
| Roulette warm 2 | 244.756 | 197.647 | 9 |
| Bazaar warm 2 | 525.963 | 111.276 | 27 |

Peak working set is 904.9MiB. First vehicle resource loading is 216.703ms, now asynchronous; cached repeats are below 0.02ms. Bazaar vehicle configuration falls to 31.7–38.7ms. The earlier passing `loading-cached03` measured Bazaar first 1.434s / gap 129.840ms and 903.8MiB peak. These samples include scheduling variation, not an isolated GPU measurement or a seamless 60 FPS claim. The independent racing p95 gate remains open.

`vehicle-load-cached02` measures racing-car cache-hit source lookup below 0.02ms and visual builds around 1.2–1.5ms. It verifies the cache limit, equal instance bounds and independent player paint. `vehicle-cache-regression01` passes all five classes' existing movement, boost, wheel steering/rolling, clearance, reverse, pause, recovery, surface-assist, menu and profile-fixture checks. This is a focused visual/cache regression, not another full five-class three-lap race.

## Loading lifecycle and menu/Time Trial

`loading-lifecycle01` passes before the optimization; `loading-lifecycle-cached02` passes afterward. They cover Start interlock, replacement selection, Back cancellation, worker-start cancellation, stale-result rejection, invalid resources, failure recovery, bounded course cache, continued presentation and shutdown joining.

`menu-trial02` passes real Bazaar menu selection, racing-car assignment/label and route preview, four-car Quick Race start with throttle movement, pause and retry, solo Time Trial start and one clean ordered lap, results/return, and Freestyle monster-truck preservation through Roulette/Bazaar switching. The trial finishes in 27.309943s with no crash, AI recovery or gate penalty, using the sentinel profile's starting stats. It is an automated development run, not an owner benchmark. Record key includes Bazaar, racing_car, lap count, mode and stats. Read-only profile/ghost writes remain disabled. Quick-ready and Time Trial results frames were inspected.

`menu-trial01` remains failed solely because the original test expected retry to enter SETUP; the game correctly enters PREVIEW. The corrected test asserts the named phase enum. Its clean trial and other assertions remain recorded without relabelling the run.

All eleven children have exit receipts and were confirmed absent: 56884, 82784, 158128, 133604, 100392, 81688, 131984, 30212, 116252, 60100 and 142612. All exit codes are zero; budget/assertion failures above remain preserved. Final passing probes have no captured errors, frame warnings or shutdown errors. Editor diagnostics show no errors and three existing warnings in other scripts.

Final source SHA-256: imported_visual `a1fcead0d4b35f3890e17a43dffe0a2b7b904880b7d2a62fd2c65380d20a97fc`; SelectedCourse `e5e6cc1ef4ed90b6cdd5f871402593e8f8cf6f4274fd7e4e7a63918b1cd22f3e`. The preceding implementations are retained in `tests/baselines/content/bazaar/loading-code-before/`.

Remaining: starting/full-stat race balance, racing-frame performance, production registration/profile persistence, and a fresh release comparison for the loading change. Existing accepted routes and production catalogue were not edited.
