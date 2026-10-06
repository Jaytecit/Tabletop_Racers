# Toys R You race quality — implementation and evidence

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

4 October 2026. **Partial roadmap delivery; not final project acceptance.** See the [coverage checklist](../implementation-checklist.md) for every outstanding area. The first-course presentation implementation is playable; remaining human review and wider-course gates stay open.

## Changes

- Buggy tyres now have independent steering and rolling pivots, visible hub spokes and signed travel divided by the actual 0.19-unit tyre radius. The narrower visual chassis/body clears steered tyres; physical collision dimensions and handling remain unchanged. Per-driver numbers supplement livery colour. Small cosmetic pitch/roll and landing compression reset through recovery/retry.
- One feedback owner handles actual boost edges, supported landings, accepted contact cooldowns and recovery transitions. Existing one-shot emitters are reused: four bursts, at most 80 particles, and four prioritised audio voices. Only player events shake/rumble locally. Landing and contact sounds differ, with intensity-scaled level and a bounded 2.5 dB impact duck through the existing music owner.
- Schema 9 adds `setup.reduced_effects` (default false for older profiles). Setup exposes it with normal directional navigation. It disables new shake and reduces burst density; no additional screen flashes were introduced.
- Start lights have a short stage pulse. Lap/position are the primary HUD line, with smaller time/boost readouts. A bounded message queue prioritises warnings over lap/rank notices; rank must settle for 0.35 seconds, with a 1.5-second notification cooldown. The authoritative missed-gate deadline always overrides queued messages.
- Results emphasise the player and reveal the existing podium briefly. Engine layers stop on player finish. Held Accept/Start cannot immediately activate Retry; controls unlock after release and a 0.15-second guard. Existing rewards, DNF classification and victory-only confetti remain authoritative.
- Separate source review found a pre-existing fall-through from camera cycling during countdown into the legacy 2D scene. The failing isolated reproduction is retained; the 2D fallback is now correctly contained in `return_to_2d()`, and all three countdown camera cycles keep the race intact.
- CLOSE CHASE changes from orthographic height 4.5/trail 8.5 to perspective FOV 65°, height 1.8/trail 4.8, with 3.8-unit horizontal look-ahead. A 0.24-unit sphere sweep keeps the camera off physical scenery/road. Near/far are 0.05/400. The close view no longer fades whole source meshes based on their broad bounding boxes. CHASE size 14 and OVERHEAD size 20 remain; staging retains its orthographic flight.
- Cosmetic shake is applied after the base camera pose and removed before the next pose. Local ray/volume clearance suppresses unsafe offsets.
- Time Trial previously hashed the entire car source, so cosmetic changes would have retired compatible records. A narrowly scoped exact SHA-256 alias maps this verified presentation-only revision to its pre-change hash. Any later car-source change falls back to its real hash and invalidates comparisons as before. No profile records or ghosts were rewritten.

## Evidence

All paths below are under `tests/baselines/race_quality/toys_r_you/`. Tests use the newer-schema read-only sentinel before scene setup, disable controller polling and remove hardware bindings. Synthetic controls remain available. Every completed run has its exact PID exit recorded; the user's editor was not stopped.

| Run | Observed result |
|---|---|
| `baseline01` | Before-change four-car, three-lap Hard reference, RNG seeds 64/128/256/512. All finished, no crashes/recoveries/penalties. No player boost/recovery occurred; those are covered by explicit input tests instead |
| `motion-feedback01` | First paired run: exactly the same four finish times and impact counts; no captured gameplay errors |
| `ai-final01` | Updated visual/event/HUD-message build: same finish times, zero crashes/recoveries/penalties; five debounced contact cues and fifteen real landing cues; no active burst/voice/shake/duck at results |
| `quality01` | Preserved failure: reverse-wheel assertion incorrectly assumed positive stored angles after a full revolution |
| `quality02` | Corrected reverse test passed: -1.111593 travel, wrapped angle -0.432694, residual 0.000000212 radians. Input boost/pause/recovery, physical parity, bounds, settings roundtrip and window/filter cases passed |
| `quality03` | Added full Time Trial, PB feedback, missed-gate penalty/recovery, DNF fixture, single reward and held Accept checks passed; camera clearance volumes empty at stations 80/165/306 |
| `quality04` | Preserved startup failure: HUD CanvasLayer passed to a Control-only label helper. Exact test PID stopped after logs were retained |
| `quality05` | Corrected helper plus final HUD hierarchy passed all then-present assertions; no gameplay errors/frame warnings. Separate finish-voice priority check passed |
| `quality-final` | Expanded run passed with no captured gameplay errors/frame warnings: real camera cycling, saved close mode, five retries with identical 878-node counts and unchanged signal counts, plus the complete focused gameplay suite |
| `navigation01`, `navigation02` | Individual transitions passed; obsolete two-row column-return assumption failed. Trace shows the second Down clamped at the bottom, so the second Up correctly moved above the cards. No production navigation rewrite was needed |
| `navigation-final` | Passed all 828 keyboard/D-pad/stick transitions, corrected column return, modal/slider/held-input and results focus checks; no captured errors/frame warnings; PID 47680 exited |
| `countdown-before` / `countdown-after` | Reproduced the legacy-scene fall-through with captured errors; corrected run passed all three countdown camera cycles, kept the scene/profile intact, and had empty error/warning arrays and stderr. Both PIDs exited |
| `opening-final` | Opening/music continuity, held Start and pointer/controller start regressions passed; empty stderr; PID 131560 exited |
| `quality-layout` | Independent visual review found overlapping long Time Trial notices and stale camera labels in `quality-final`. Corrected results spacing and coalesced camera notices pass new assertions and rendered review; PID 33160 exited |
| `course01` | All 96 forward/reverse close-camera placements clear physical geometry; five away/back switches retain 878 nodes and signal counts; PID 89408 exited |
| `passing01`, `passing02`, `passing-final` | Six actual overtakes (Normal/Hard, seeds 128/256/512) pass with zero impacts/crashes/side reversals. Initial blocked-section fixture was too wide; the final fixture fills all candidate lanes and confirms waiting plus one sustained-stall recovery request. Final run clean; PID 90592 exited |
| `walkthrough01` | One uninterrupted 197-second opening → menu buttons → async selection → preview/countdown → input acceleration/boost/pause/camera → three-lap four-car race → held-Accept results guard → retry → main menu passes; empty stderr/errors/frame warnings; PID 65244 exited. Results/menu frames reviewed. The final-lap capture precedes the next 10Hz HUD update and is not evidence of the updated lap label; capture timing corrected for subsequent runs |
| `walkthrough-final` | Corrected fresh final-lap capture and explicit LAP 3/3 assertion pass, together with every uninterrupted flow check; empty stderr/errors/frame warnings; PID 132612 exited |

The final focused run (`quality-final`, PID 73792) and navigation run both have empty stderr, empty captured errors and no frame warnings. Earlier results remain immutable. Editor diagnostics retain two pre-existing shadowing warnings and report no errors.

### Precision and preservation

Baseline and paired reference finish times are 136.653635, 132.734296, 138.100332 and 137.342699 seconds for slots 1–4. These are AI reference results, not owner benchmarks. Impact counts remain 1/0/2/3. No AI parameters, race rules, vehicle stats, collision shapes or route data were changed.

The enabled/disabled visual-motion input replay measured **zero** positional/velocity deviation. The swept tyre envelope leaves approximately 0.01482 units after a conservative 0.035 allowance for body motion. This analytic check covers the visual body/chassis; the intentional suspension mounting is inspected separately in close-up frames.

`protected-hashes-final.json` confirms unchanged canonical measured JSON, route definition, entry, preview, saved environment and buggy base definition. `before/scripts.zip` preserves the initial implementation sources covered by the baseline.

### Rendering and performance

Summer 0.5.68 / runtime 4.7.2 custom build, Forward+, NVIDIA RTX 4060 Ti, 1200×800, pixelation enabled. Before p50/p95/worst wall frame intervals: **10.671 / 33.886 / 70.103 ms**. Paired motion/event run: **10.628 / 34.036 / 59.810 ms**. Later first-course run: **12.086 / 34.073 / 53.239 ms**. P95 regression is about 0.55%, but the 16.7 ms goal is **not met**. Offscreen scheduling is included; these are not isolated GPU timings or a release-build comparison.

The subsequent `ai-after-loading` run preserved all four finish times and impact counts exactly, with no crashes/recoveries/penalties. Its wall-frame p50/p95/worst were **10.483 / 36.559 / 60.945 ms**. That p95 is **7.9% above the original baseline**, exceeding the 5% regression gate. The gate remains open; earlier passing measurements do not override this result.

`ai-profile` then retained the same exact finishes with wall p50/p95/worst **10.578 / 32.987 / 55.390 ms**. The variation is real evidence, not a reason to discard the slower run. Engine physics monitor p50/p95 was 7.669 / 24.232 ms; process monitor 27.391 / 45.804 ms; draw calls 297 / 441. These monitor samples have different collection timing and overlapping work, so their percentiles must not be added or equated to isolated GPU time. Route-method profiling follows to locate the CPU cost before tuning.

`ai-route-profile` measured 1,151,880 direction queries consuming 18.226s cumulatively (inclusive method timers across the whole race). An exact-key cache, bounded to 1,024 entries and invalidated each physics tick, rebuild and route replacement, reduced that to 12.634s in `ai-direction-cache` (31% less). All four finish times, laps, impacts, recoveries, crashes and penalties remain exactly identical. The two instrumented wall-frame p95s were 31.703 / 30.699ms; p50 was 10.929 / 13.000ms, so this is not a uniform frame-time improvement. The 16.7ms target remains unmet.

`direction-parity-final` compares 32,535 exact direction values with the original implementation across all nine routes, negative/wrapped stations, repeated calls, cache overflow, same-resource rebuilds and route replacement without an active-node rebuild. It passes with empty stderr/errors. The exact new track source hash maps to the established compatibility hash; later unverified source changes still retire records normally.

Initial selection-to-present measurements varied from 7.3 to 11.4 seconds across these development processes. Later controlled loading comparisons are documented separately below. Memory increased from about 107.98 to 109.71 MiB; added visual nodes are bounded.

Reviewed frames show wheel clearance, readable car numbers, the lower camera on open road, the upper bridge and the tunnel, visible road/checkpoints, compact HUD, Setup and honest DNF results. The source model has a finite scenery horizon; low angles reveal its existing plain background. No route/environment modifications hide that limitation. HUD captures cover 1280×720, 1920×1080 and 1600×720, with pixelation both ways.

Earlier focused probes (`quality02`, `quality03`, `quality05`) retain two ObjectDB leak warnings and one resource-in-use error at process shutdown, despite empty captured gameplay error arrays. They are not labelled clean shutdowns. Final focused/layout, opening, traffic and three-lap AI runs have clean stderr. Audio uses the runner's Dummy driver; bus/voice assertions do not establish subjective audible balance.

The subsequent [loading work](course-loading.md) reduces warm Toys R You switching from about 7.3 seconds to 0.50 seconds while retaining identical route data. This is independently measured loading work, not a claim that racing reaches the 60 FPS target.

## Remaining work and acceptance

- On 4 October, the owner reviewed the revised Toys R You Close Chase camera and effects and replied **“it's perfect”**. This accepts that first-course camera/effects treatment. No physical-controller-specific result was supplied; that remains distinct from injected controller tests.
- Low-camera clearance needs its requested broader imported-course/slopes/reverse/recovery survey. The new view is shared; the [course rollout record](race-quality-course-rollout.md) distinguishes subsequent acceptance evidence.
- The uninterrupted intro-to-results/retry/menu input walkthrough and corrected final-lap HUD capture pass. Racing remains above the 16.7ms p95 goal despite the measured route-query CPU improvement. Controlled passing/stall cases and five course-switch cycles pass; AI decisions and physics remain unchanged.
- Additional wheeled classes, speedboat/water rules, grouped assigned tracks, Freestyle, Tournament, Challenges, Elimination, Time Attack, Drift Challenge, loading/release work and remaining GLB integrations are **not implemented by this slice**. Owner benchmarks and calibrated AI remain pending.
- Preserve all raw failures. Do not mark broader rollout requirements complete from these tests.

Method discovery checked [skills.sh's native GDScript testing guidance](https://www.skills.sh/gamedev-skills/awesome-gamedev-agent-skills/godot-gdscript-headless-testing); this project already has a rendered native probe runner, which was reused without installing another test framework.
