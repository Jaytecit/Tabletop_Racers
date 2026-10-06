# Course loading — 4 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Implemented spatial broad-phase route validation, one full validation per selection, a two-entry resource cache, asynchronous resource loading and a single background validation worker. Loading shows a status, disables Start, accepts replacement selections, and cancels on Back. Stale requests are drained without committing. Failed requests preserve the previous course and can be recovered by selecting a valid course. Shutdown joins the worker; it never accesses scene nodes.

The broad phase only removes pairs that cannot intersect or overlap. The existing exact segment, layer and height tests still run in their original order. Very large spans fall back to exhaustive candidates. Sampled geometry, collision generation, checkpoints and recovery anchors are unchanged. SelectedCourse validates and samples a staging route, then transfers its checked arrays into the active track before rebuilding art. Other build callers validate normally. All nine courses' active arrays and gate fields match independently built original sampling results (`catalogue-transfer`).

## Measurements

Summer 0.5.68 / 4.7.2 custom, Forward+, RTX 4060 Ti, 1200×800. These are isolated rendered development processes on the same computer. “First” means first selection in that process, **not** an OS disk-cache cold start.

| Selection-to-present | Before | After spatial lookup | After cache / single validation |
|---|---:|---:|---:|
| Toys R You, first | 7,411 ms | 2,376 ms | 1,322 ms |
| Toys R You, warm repeat 1 | 7,263 ms | 2,238 ms | 496 ms |
| Toys R You, warm repeat 2 | 7,312 ms | 2,250 ms | 498 ms |
| Roulette, warm repeat | 1,956 ms | 1,431 ms | 139 ms |

Before, Toys R You spent about 2 seconds in each of three route validations. With one spatial validation, the warm main-thread selection took about 441 ms: validation 369 ms, route sampling 29 ms, scene replacement/build 33 ms, preview/configuration 7 ms. Warm static memory was approximately 114 MiB for Toys R You and 117 MiB for Roulette; before it was 105 / 113 MiB. Cache capacity is two entries, not the complete catalogue.

A first asynchronous Toys selection took 1,342 ms and presented 52 frames while loading. Main-thread commit still has a measurable stall; this does not claim a 16.7 ms loading-frame budget.

### Final development / Windows release comparison

Matching installed 4.7.2 Windows templates were used, on the same machine and renderer. The dedicated benchmark export reports `release=true`, `editor=false`, `loading_benchmark=true`, and injects the read-only fixture before creating the game. These sequential samples include OS scheduling/cache variation; they are not repeated statistical estimates.

| Course / selection | Development | Release |
|---|---:|---:|
| Toys R You first | 1,352 ms | 1,380 ms |
| Toys R You warm repeats | 485 / 493 ms | 356 / 327 ms |
| Mount Rainier first | 4,608 ms | 4,216 ms |
| Mount Rainier warm repeats | 1,305 / 1,224 ms | 502 / 517 ms |
| Roulette warm, Toys run | 103 ms | 84 ms |

Release improves warm loading in these samples, but does not remove the first-load cost. Final asynchronous warm-resource selection presented 30 frames in 521 ms (development Toys), 21 in 366 ms (release Toys), 57 in 1,103 ms (development Rainier), and 27 in 494 ms (release Rainier). This proves continuing presentation, not a maximum input-latency bound. All nine active courses also passed the asynchronous selector/start regression in `catalogue-worker-final`; Rainier had the longest measured selection there (4,461 ms).

Development Rainier static memory was 117.6 MiB first / 117.7 MiB warm. Release's `MEMORY_STATIC` monitor reports zero because it is unavailable in that build; zero is not a memory measurement.

### Responsiveness and memory

`responsiveness-development` identified duplicate sampling during commit: first-load process gaps reached 253 ms, warm gaps 223–240 ms. Transferring the validated sampling result reduced the matching development measurements to 155 ms first / 125–144 ms warm (`responsiveness-transfer-development`). Release measured 99 ms first / 74–88 ms warm for Rainier and a maximum 104 ms for Roulette (`responsiveness-release`). Earlier development measurements conservatively include the final three-frame settling interval as one gap; the release probe samples every process frame individually.

The final first asynchronous Rainier load took 4.29s development / 3.83s release and presented 247 / 225 frames. Warm asynchronous repeats took 1.13–1.26s development / 0.54–0.55s release. OS peak working set, sampled from the exact child Process object at 100ms intervals, was 847.5 MiB development / 774.7 MiB release. These OS values include native/render allocations and are not comparable to the engine's static allocator counter. The earlier pre-transfer development peak was 851.0 MiB; a pre-optimisation OS peak was not captured.

The same-machine regression budget is first selection ≤6s, warm selections ≤2s, longest process gap ≤250ms, peak working set ≤1GiB. This replaces multi-second blocking with a bounded commit; it is not a promise of seamless 60 FPS while loading. `tools/measure_course_loading.ps1` enforces these limits and retains process samples, exit confirmation and failures. Additional future courses must meet the budget or retain an explicit failing record.

The final budget-enforced pair (`responsiveness-final-development` / `responsiveness-final-release`) passes all four limits with frame-by-frame sampling. Rainier first: 4.600s / 3.912s; warm: 1.119–1.144s / 0.512–0.516s; worst process gap: 176 / 90ms; OS peak working set: 846.4 / 778.8MiB. First resource loading accounts for 3.287 / 3.392s, background validation 1.000 / 0.364s. Resource time includes threaded dependency loading; warm cache hits take less than 0.01ms. This explains why export mostly helps warm CPU work while the initial resource cost remains. Both PIDs exited with code 0. Later route-query caching is a separate race-performance change; this exported loading pair predates that change.

The benchmark preset preserves text resources and scripts because record signatures hash their exact source bytes. All five signature samples in each development/release pair match. The feature-specific bootstrap requires an explicit absolute evidence directory and is not the ordinary game entry point. This is a local benchmark package, not a finished distributable.

## Evidence

Raw outputs are in `tests/baselines/loading/`:

- `before01`: unchanged-loading baseline with per-step timings.
- `validator-parity01`, `validator-parity02`: all nine active routes and 80 seeded crossing/layer/height/width fixtures return exactly the original exhaustive validator's errors.
- `after-spatial01`: first paired improvement. Assertions passed; ObjectDB/resource shutdown warnings remain in raw stderr.
- `after-cache-threaded01`: bounded cache, loading interlock, latest-selection wins, Back cancellation, failure/recovery and continued rendered frames passed.
- `validator-parity-final`: preserved failure from a typed-array conditional assignment during duplicate-validation removal.
- `validator-parity-corrected`: repaired run passed the same 89 cases and exact comparisons of every sampled route field on all nine active courses. No captured errors or stderr output.
- `after-validation-once`, `verified-ui`: final loading/selection checks pass with empty stderr; the latter waits for fresh presented frames before capturing the ready state.
- `catalogue-final`: all nine selections through actual selector signals, Quick Race/Time Trial starts, retirement rules, legacy records/profile validation and evidence-local save/reload pass. No captured errors or stderr output.
- `worker-final`, `catalogue-worker-final`: background validation, cancellation after worker start, stale result rejection, shutdown join and all nine catalogue selections pass.
- `catalogue-transfer`: all nine active routes' transferred sampling/gate data match original independently built results, and Quick Race/Time Trial starts pass; no captured errors/frame warnings or stderr.
- `development-final`, `mount-rainier-development-final`, `release-final`, `mount-rainier-release-final`: final lifecycle checks include invalid Resource rejection, recovery, bounded cache, read-only profile and shutdown. All pass with no captured errors/frame warnings. Development stderr is empty. Release retains the bundled Rust extension's `register-docs` warning.
- `export01`: failed because unused addon C# sources required a missing solution; excluded those sources from this benchmark. `release01`: unsupported CLI bootstrap did not produce probe evidence and was stopped; it is not a verified benchmark. Later exports use the dedicated bootstrap scene. Export shutdown warnings remain in raw logs.

Every completed process has a separate exit record. Original failures were retained. The actual route resources and accepted environment assets were not edited. Time Trial uses an exact-source-hash compatibility alias for the sampling change, backed by identical route fields; later source edits fall back to their real hashes.

## Still required

Continue the loading regression for newly integrated courses. Human menu responsiveness remains unreviewed. Resource loading, validation, sampling, scene setup and ready-to-present wait are reported separately; the latter includes rendering/scheduling and does not isolate shader compilation alone. Loading measurements do not close the independent racing frame-time gate.
