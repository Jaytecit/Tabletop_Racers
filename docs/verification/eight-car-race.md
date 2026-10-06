# Eight-car Moonlight race — 6 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Select **8 CAR RACE / MOONLIGHT** on the main mode menu after selecting a driver. It prepares Quick Race, Moonlight Junk Heap, Beach Buggy, Hard, seven AI rivals and three laps. Press Start, then confirm the race preview as usual. The normal rival selector also supports seven AI in Quick Race and Freestyle. Player skills and custom names remain intact; each of the seven rivals receives a distinct catalogue portrait, name and palette.

Four extra neutral-reference AI bodies are instantiated before race configuration. Standings, minimap clearance, all-car lighting and two-row results presentation support eight. Profile schema 17 saves seven rivals and accepts corresponding record keys. Nightmare retains a minimum of three rivals while permitting seven. Cup, tournament and elimination retain their existing four-car limits and scoring rules; solo modes remain solo.

## Course selection

`tests/evidence/eight-car-survey-01` compares all eleven production courses sequentially with eight neutral Beach Buggies, Hard AI, the same seeds, 120 warm-up physics ticks and 360 measured rendered frames per course. Forward+, RTX 4060 Ti, 1200×800 viewport, existing world pixel filter, uncapped rendering and disabled VSync. Engine viewport GPU timing is enabled. No test processes overlap.

| Course | Wall-frame p95 ms | Viewport GPU p95 ms |
| --- | ---: | ---: |
| Moonlight Junk Heap | 18.097 | 2.267 |
| Mount Rainier | 17.584 | 2.259 |
| Nighttime Noodles | 17.556 | 1.930 |
| Firefly BBQ | 16.654 | 2.213 |
| Town Square | 15.436 | 1.921 |
| Rusty Nuts Workshop | 14.528 | 3.484 |
| Bazaar | 13.257 | 3.737 |
| Topspeed Oval | 13.245 | 1.516 |
| Toys R Asleep | 13.182 | 1.504 |
| Toys R You | 10.566 | 1.313 |
| Roulette Grand Prix | 8.503 | 1.712 |

Moonlight is selected by the largest measured overall wall-frame tail. Bazaar has the highest GPU p95 in this sample. These are short early-race samples, not an exhaustive ranking of every camera position or a release benchmark. CPU monitor values, wall intervals and GPU values overlap in collection timing and must not be summed. Raw measurements preserve CPU, physics, draw-call and primitive counts as well as these timings.

## Full-race verification

`tests/evidence/eight-car-moonlight-02` passes an ordinary Quick Race at a 60 FPS cap, with the human slot driven by a verification-only AI helper. All eight complete three laps in 71.54–76.40 seconds, with zero crashes or checkpoint penalties. Ordinary contact counts are 24/34/29/25/19/22/21/30. Actual human input is checked separately by the setup probe. Results contain eight ranked portraits. Returning to four cars or solo disables extra bodies and collisions; an eight-car retry restores the ordinary human-controlled first slot. Four-car tournament configuration and seven-rival profile/record validation pass.

Full-race wall-frame p50/p95/worst: 16.754 / 22.860 / 138.040 ms. Physics monitor p50/p95: 15.534 / 27.030 ms. Viewport GPU p50/p95: 2.201 / 6.522 ms. These development measurements do not meet a sustained 16.7 ms p95 target. The GPU has headroom while CPU/frame pacing needs further tuning; no stable 60 FPS claim is made.

The first full run's evidence remains in `eight-car-moonlight-01`: all eight finished, but the probe forgot to undo its own AI helper before testing human retry. That fixture was corrected. The initial screenshot also exposed standings/minimap overlap, now fixed. Final run has no runtime, frame-capture or shutdown errors; process 72852 exited normally. Survey process 74948 and initial setup process 87792 also exited normally. Personal profiles remain read-only throughout, hardware input bindings are erased in disposable tests, and the user's editor is untouched.

Setup probe: `tests/probes/eight_car_setup_verification.gd` exercises the real shortcut, ordinary human throttle, pause, grid resizing, Nightmare selection, profile validation, recovery of the eighth car in traffic and all result-tile bounds. Final evidence is `tests/evidence/eight-car-setup-02`; no captured or shutdown errors, process 134416 exited normally.
