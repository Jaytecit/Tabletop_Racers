# Retro UI refresh — 4 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Implemented the owner-approved preview through the shared arcade skin: saturated royal blue/indigo, cyan, yellow, pink and white; rounded controls and panels; centred padded menu logo, compact eight-mode grid and existing buggy artwork. Reflowed driver, vehicle and course pages and their footer actions for the taller header. Settings, controls, upgrades/shop, tournament/benchmark controls, dropdowns, credits, opening captions, HUD, minimap, messages, pause and podium/results use the same treatment.

## Verification

- `tests/baselines/ui_retro/menu01`: rendered existing menu-flow walkthrough passed; directional keyboard/simulated gamepad navigation, modal focus, display focus, settings slider, vehicle gallery, course selection, race launch and podium/results return. 59.302s, no runtime errors, frame warnings or shutdown errors. PID 87864 exited normally.
- `layout02`: rendered layout, focus contrast, menu pages at 960×640 and 1600×900, credits/dropdown, countdown, pause, race HUD, results and return-home checks passed. PID 23776 exited normally. Captures identified remaining muted credits title/podium colours; corrected in the final pass.
- `final03`: same focused rendered checks passed after the credits window/podium changes, 6.727s; no runtime errors, frame warnings or shutdown errors. PID 159964 exited normally. Final frames inspected.
- Existing Impeccable mechanical detector returned no findings for the presentation scripts before the final native window/podium refinements. Its web-oriented result does not replace rendered inspection.

All instances used a read-only fixture profile, isolated hardware input and the existing owned-process verification runner. No user editor was stopped. Physical gamepad hardware and every monitor aspect ratio were not tested. Geometry, handling and soundtrack were unchanged.
