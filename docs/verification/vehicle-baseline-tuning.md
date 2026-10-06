# Vehicle baseline tuning

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

The developer target selector now includes all five vehicle types, even when absent from the race. Session baselines are keyed by vehicle ID and compose in this order: immutable definition, vehicle baseline, earned player upgrades (neutral for AI), racer overrides. AI behaviour remains a racer setting. Surface physics baselines apply to matching player and AI cars. Geometry/watercraft changes retain the existing race-reset requirement. Reset Target clears only the selected layer; Reset All clears both layers. Changes remain session-only and experimental/unranked. Setup export schema 2 includes overrides and composed properties for all five vehicle baselines, including absent types.

Rendered probe: `tests/probes/developer_menu_verification.gd`. Evidence: `tests/baselines/requirements_2026_10_05/vehicle_baselines_02/`.

All menu and baseline assertions passed: five selectable types, immutable source resources, baseline before earned upgrades, shared AI application, racer override priority, independent resets, class switching, deferred geometry, and export coverage. The baseline details screenshot was visually inspected. The process exited normally (PID 147048, exit 0), without a watchdog stop or shutdown errors; profiles were read-only and hardware input isolated.

The strict runner remains failed because scene loading reports an invalid existing UID for `showcase_track.gd` in `scenes/race/race.tscn:4`, falling back to its text path. This warning is preserved in raw stderr/results; this is not a clean overall verification pass. Run 01 is also retained: its assertions passed, but the baseline screenshot showed the menu closed. Run 02 corrects that capture.
