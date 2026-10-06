# Implementation coverage and remaining work — 6 October 2026

This is the current checkpoint. [Current build](current-build.md) defines the inspected implementation. Dated specifications retain original requirements, but their starting-point tables and unchecked historical boxes are not current status. Existing evidence establishes only its named courses/settings; this reconciliation runs no new races.

## Implemented

| Area | Current status / evidence |
| --- | --- |
| Catalogue | Eleven active courses; Town Square limited to Quick/Trial/Freestyle. [Catalogue](../tracks/README.md), [Town Square](verification/town_square.md), [source dispositions](glb-track-disposition.md). |
| Vehicles | All five classes, Freestyle fallback rules, animated wheels for four classes, original assets retained. [Classes](vehicle-classes.md), [animation](animated-vehicles-integration.md). |
| Handling defaults/contact/recovery | Accepted exported defaults and surface rules; contact deflection and bounded rescue reset implemented. [Defaults](verification/exported-tuning-defaults.md), [contact/recovery](vehicle-collision-recovery-profiles.md). |
| Profiles/progression | Named isolated profiles, eight portraits and palettes, wallet/per-vehicle upgrades, machine settings, gamepad name keyboard. Schema 17. [Profiles](verification/saved-player-profiles.md), [identity](character-roster-and-colours.md), [progression](vehicle-progression.md). |
| Eight-car circuit racing | Quick/Freestyle, seven AI selector, Moonlight Hard shortcut, rank/minimap/results/lighting and profile/record support. Owner says the eight-player race works perfectly (6 October). [Race](verification/eight-car-race.md), [tuning](verification/eight-car-tuning.md). |
| Modes | Tournament, Challenge, Elimination, Time Attack, Drift and solo PB ghost paths implemented with specific evidence. Tournament/Elimination still four-car. [Rules](racing-modes.md), [roadmaps](verification/challenge-roadmaps.md). |
| Development tools | Overrides, reset rewards, descriptor-driven export, accepted base defaults; individual menu targets currently stop at AI 3. [Override evidence](verification/developer-tuning-overrides.md), [menu/export](verification/developer-menu-export.md). |
| Presentation/loading | Mode-dependent menu flow, panels, live ranks, dot minimap, camera/reduced-effects, preview flyovers, async loading/projection optimisation and road-course panorama implemented. [Index](README.md) links evidence. |
| Audio/video | Current full-theme opening, music and existing effects remain implemented. No alteration is required for the eight-car work. [Opening](opening-sequence.md). |

## Required next work

1. **Eight-car competitive modes:** shared field policy, tournament field/scoring/state/standings, Elimination setup, AI 4–7 developer targets and relevant copy. [Detailed audit](eight-car-experience-audit.md).
2. **Solid finishers:** separate result accounting from physical run-out/parking; keep traffic avoidance/recovery aware of them. Validate exits/parking per course and vehicle footprint; do not just enable collision on stationary finish-line cars.
3. **Targeted expansion acceptance:** relevant state/persistence/layout tests and isolated rendered checks for changed modes/finisher behaviour. Preserve failures and confirm each owned PID exits.
4. **Performance:** current tuned eight-car Moonlight wall p95 is 21.768 ms; the 16.7 ms target remains unmet. Profile before further optimisation; retain measured support and route parity.
5. **Balance/benchmarks:** final class/surface and non-drift roadmap targets, practical human driving feedback, actual clean owner benchmark times and repeated compatible AI calibration. Synthetic fixtures/AI laps are not owner records.
6. **Remaining source courses:** Raceway next proposed candidate, then source-register priorities. No candidate is automatically accepted. Use independent model boundaries/heights and explicit layer/topology review; keep Beach Buggies inactive unless requested.
7. **Outstanding visual/control/release gates:** follow the specific unresolved gates in existing camera/effects/shadow/loading records; physical device and release evidence must be claimed only when actually available. Owner-accepted bedroom framing does not require repeating its removed table/legs task.

## Owner policy takes precedence

- Development scores, times, ghosts, rewards, currencies and upgrades may reset/invalidate when useful. Preservation-only migrations are not required. Named identity/preferences, accepted geometry, source assets/notices and failed evidence remain protected. This does not request an immediate wipe.
- Each new course receives one Beach Buggy race on Hard, in Freestyle when needed to preserve its assigned standard class. Replace prior vehicle/stat/difficulty matrices and extra mode race runs with that rule; retain topology, support, gates/flags, menu/loading/control checks. Keep additional untested modes disabled.
- Work inline, one course at a time, without subagents. Audio/video changes are outside the current eight-car task. Source cleanup does not authorize gameplay changes or further course imports.

Original detailed specs remain in the [rollout](../.summer/plans/2026-10-03-tabletop-glb-rollout.md), [quality plan](../.summer/plans/2026-10-04-race-quality-toys-r-you.md), [menu plan](../.summer/plans/2026-10-04-arcade-menu-flow.md) and [profiles/effects plan](../.summer/plans/2026-10-05-profiles-tuning-tracks-effects.md), with the complete pre-maintenance snapshot in `archive/documentation-before-maintenance-20261006.zip`.
