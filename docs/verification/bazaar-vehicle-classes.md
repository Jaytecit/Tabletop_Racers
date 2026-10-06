# Bazaar five-class race coverage — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

**Current status:** Bazaar is now registered; see [production integration evidence](bazaar-registration.md). The staged runs below describe the earlier revisions they tested.

Bazaar remains staged. The staged probe now preserves the current Freestyle vehicle when validating a staged entry after a procedural-course switch, and asserts its identity. Previously the helper always chose the assigned buggy; this was a probe limitation, not evidence of a production Freestyle failure. Updated probe SHA-256: `3575079097d16e63a2a3ba77da9fe37d90db6f6d6690da6563ad3d6678a24a58`.

Final runs set `TABLETOP_VERIFY_COURSE=bazaar`, `TABLETOP_VERIFY_CLASS` as below, and current expected car/track hashes. Four neutral vehicles race three Hard laps with fixed seeds. Each run passes 2,664 authored support rays, 480 checkpoint cases, flag support/clearance, real throttle/boost, pause, reset/support recovery and staged/procedural switching with the selected vehicle retained. All sixteen racers finish without crashes, AI recoveries or penalties. Ordinary contacts are recorded below. Every result is finished/passed with no captured errors, frame warnings or shutdown errors.

| Evidence under `tests/baselines/content/bazaar` | Finish times, players 1–4 (s) | Contacts, players 1–4 | Wall-frame p95 (ms) | Exited PID |
|---|---|---|---|---|
| `classes-racing_car02` | 65.553 / 66.139 / 67.861 / 66.636 | 0 / 7 / 3 / 10 | 32.959 | 139180 |
| `classes-drift_car02` | 71.602 / 72.328 / 73.810 / 73.319 | 0 / 4 / 5 / 14 | 31.978 | 139332 |
| `classes-speedboat02` | 98.667 / 99.972 / 101.298 / 99.423 | 0 / 5 / 4 / 9 | 29.739 | 110332 |
| `classes-monster_truck02` | 77.052 / 78.492 / 77.988 / 79.114 | 0 / 14 / 1 / 8 | 29.589 | 122124 |

Close Chase recovery frames were inspected for each class. The speedboat HUD correctly labels `LAND ASSIST 50%`; this verifies land-Freestyle behavior, not a water-course assignment. The earlier `classes-monster01` passes the previous probe (PID 144120 exited), but does not verify vehicle preservation after switching. Its evidence is retained. All five disposable PIDs are confirmed absent, with exit code 0 and no forced watchdog stop. Accepted source/route/collision, vehicle handling and production catalogue were unchanged.

Together with the preceding [buggy evidence](bazaar.md), neutral-build class race coverage is complete. Starting/full-stat balance, actual loading/menu and Time Trial integration, and the independent 16.7ms wall-frame p95 gate remain open. None of these runs meets that frame-time target.
