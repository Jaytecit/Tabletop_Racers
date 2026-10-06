# Eight-car CPU tuning and interactive launch — 6 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Route projection dominated the correctly instrumented eight-AI sample: 6.312 seconds inclusive out of 12.145 seconds in vehicle physics callbacks. Method timers are inclusive and overlapping, not additive CPU totals. Physical support rays accounted for only 0.193 seconds, so their collision/support checks remain unchanged.

Changes in `showcase_track.gd`:

- Binary searches replace linear walks when finding the bounded projection window. They retain the previous wrapped-distance comparisons, strict upper boundary and outside lower span.
- Precomputed span AABBs reject candidates whose conservative planar lower bound exceeds the best projection score, retaining traversal/tie order and a rounding allowance.
- An exact-station, per-physics-tick surface cache reuses repeated queries. It is bounded to 1,024 entries, cleared on rebuild or resource replacement, and returns dictionary copies so callers cannot mutate cached support/height data.

SelectedCourse transfers the new immutable span bounds with the sampled route. Geometry, measured heights, support rays, physics tick rate, AI decisions, skills, collision shapes, vehicle lighting and effects are unchanged. The exact tested track-source hash maps to the previous compatible record hash; future untested source edits still invalidate records normally.

## Evidence

`eight-car-projection-parity-02` passes 86,184 exact query comparisons across all active routes, boundaries, layers, wrapped hints, varied search windows, rebuilds, staging transfers and cache mutation. Canonical Toys R You boundary error remains zero. A repeated Bazaar numerical query benchmark takes 0.941 versus 1.141 seconds (about 18% less); this is not a rendered race benchmark.

Correctly instrumented `eight-car-cpu-before02` / `eight-car-cpu-after04`: same eight AI identities, neutral Beach Buggies, Hard, seeds, Moonlight, 60 FPS cap, 120 warm-up physics ticks and 900 rendered samples. Inclusive projection mean falls 181.84 to 158.96 microseconds/call (12.6% less). Short-sample wall p95 falls 26.677 to 23.547 ms. Different rendered scheduling produces different physics sample counts; per-call averages are used for method cost comparisons.

Full ordinary Quick Race comparison uses the previously passing `eight-car-moonlight-02` and final `eight-car-moonlight-tuned-01`:

| Metric | Before | Tuned |
| --- | ---: | ---: |
| Wall-frame p50 | 16.754 ms | 16.684 ms |
| Wall-frame p95 | 22.860 ms | 21.768 ms |
| Worst sampled wall frame | 138.040 ms | 80.397 ms |
| Physics monitor p50 | 15.534 ms | 14.266 ms |
| Physics monitor p95 | 27.030 ms | 22.863 ms |
| Viewport GPU p95 | 6.522 ms | 6.059 ms |

All eight finish three laps in 71.18–76.42 seconds with zero crashes/checkpoint penalties. Contact counts and finish times differ from the earlier run; wall-clock-paced physics/rendering is not a claim of identical deterministic contact trajectories. Overall p95 improves about 4.8%; physics p95 improves about 15.4%. The 16.7 ms p95 target remains unmet. These are development observations, not a universal performance guarantee.

## Interactive test

`tools/playtests/eight_car_playtest.tscn` loads the last selected saved driver, configures eight Beach Buggies on Moonlight/Hard/three laps, and stops at the normal preview prompt. The first slot uses real keyboard/gamepad input. Press the normal select/start control to begin. Personal profile, directory and machine-setting writes are disabled for this practice launch. Normal main-menu launches retain ordinary saving behaviour.

`eight-car-interactive-launch-01` passes the actual launcher scene, preview/grid configuration, human throttle and read-only checks with hardware input isolated only in the disposable verification child. All final probes have empty runtime/shutdown error lists and their owned processes exited normally.

Failure evidence is preserved. Initial CPU instrumentation reset inherited car identity/AI properties; `eight-car-cpu-before`, `eight-car-cpu-after` and failed `eight-car-cpu-after02` are excluded from the accepted comparison. The fixture now preserves exports and asserts every identity/AI flag. `eight-car-projection-parity-01` has zero numerical mismatches but renderer material errors when retiring scenery after its long numerical batch. Final numerical verification uses detached staging transfer; actual rendered course loading/racing and the interactive launch pass separately. No user editor/game is stopped during cleanup.
