# Race quality course rollout — 4 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Shared changes are verified one active course at a time. These checks supplement the existing source-extraction, support and checkpoint acceptance records; they do not replace them or claim newly integrated tracks.

| Course | New evidence | Status |
|---|---|---|
| Toys R You | [Detailed quality record](toys-r-you-race-quality.md) | Owner camera/effects accepted; gameplay/lifecycle checks pass; 16.7ms p95 target remains open |
| Toys R Asleep | `tests/baselines/race_quality/toys_r_asleep/camera01`, `race01` | 96 camera placements, five switches and a four-car/three-lap Hard race pass; 16.7ms p95 target remains open |
| Roulette, Rusty Nuts Workshop, Moonlight Junk Heap, Firefly BBQ, Nighttime Noodles, Mount Rainier, Topspeed Oval | Existing loading/catalogue parity only | Quality rollout pending |

## Toys R Asleep

`camera01` passes with no captured errors/frame warnings and empty stderr. All 96 physical clearance volumes are empty. Five away/back cycles retain 865 nodes and identical session signal counts; memory stays approximately 116.45MiB. PID 66544 exited.

All six forward close-view captures were inspected: the castle/start arch, boxed-car corridor, foam ramp, raised exit, toy-farm straight and train bend remain readable with the car and upcoming road visible. The source's finite backdrop is visible beyond the course, as on Toys R You. These are stationary placement fixtures with the race timer held; they do not prove driving motion or recovery. No course geometry or asset was modified.

`race01` passes with empty stderr/errors/frame warnings. Four neutral buggies, Hard, three laps, seeds 64/128/256/512 finish in 91.536 / 90.908 / 92.072 / 93.157 seconds. Every car completes all three laps with zero crashes, recoveries and penalties; impacts are 1/0/1/3. These are development reference times, not owner benchmarks. Wall-frame p50/p95/worst: 10.234 / 32.944 / 60.361ms, so the 16.7ms target is not met. PID 122508 exited.

The driving bend frame shows identifiable cars and usable road/flag visibility. The results capture occurs during the staggered podium reveal; classification is proven by all four authoritative result records, not by claiming all four cards are already visible in that early frame. Future full-race probes now wait for the reveal before their results capture. Recovery and live Close Chase driving on this course still require focused acceptance; stationary clearance and a Chase-mode AI race are not substitutes.
