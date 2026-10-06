# Bazaar Drift Challenge — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Drift Challenge now selects only Bazaar and assigns the drift car. Main-menu mode changes, initial saved-mode fallback and profile activation use the catalogue's eligible course. Topspeed remains selectable for ordinary racing. Saved Topspeed drift scores validate as historical records through a separate `RECORD_COURSES` list; changing challenge eligibility no longer deletes them on profile load.

The 90-second timer, scoring/combo rules and provisional 1,200-point target are retained. The controller already includes the course/route/stat context and rule/controller source hashes in record signatures, so Bazaar scores cannot replace Topspeed history. No route, geometry or handling tuning was changed.

## Fresh verification

Command: `./tools/run_tabletop_verification.ps1 -Probe res://tests/probes/drift_flow_verification.gd -Evidence tests/baselines/content/bazaar/drift_03 -MaxSeconds 240 -WaitAndCheck`.

Final [raw results](../../tests/baselines/content/bazaar/drift_03/results.json) pass with no errors, frame warnings or shutdown errors; duration 100.32 seconds. PID 143260 exited normally and was independently checked absent. The probe isolates controller/hardware input and redirects profile-directory, payload and controls paths into its evidence folder. Machine settings remain read-only; no owner save is made writable.

- Stale saved Topspeed Drift activation, direct menu selection, only-Bazaar selector eligibility, drift-car assignment, failed-load blocking/retry and ordinary Topspeed selection pass.
- Pause, seeded win/failure, duplicate-result guard, retry/reset, return to ordinary racing, disk score reload and historical score preservation pass. The seeded 1,500-point win tests result/persistence integration, not physical player performance.
- A real command-only steering run completes 90.0167 simulated seconds with 486.810 points, maximum combo 284.281, 5,399 safe frames and 2,543 safe slip frames. No pose, velocity, score or elapsed-time injection occurs during this run. It has zero crashes and recoveries. Automated score saving is disabled and records remain unchanged.
- Rule fixtures reject stationary spinning, reverse/old-patch farming, collision, off-road and teleport motion. A separate controller fixture moves outside model support and verifies an existing pending combo is lost with no score.
- [Physical drift frame](../../tests/baselines/content/bazaar/drift_03/physical_drift.jpg) and [physical results](../../tests/baselines/content/bazaar/drift_03/physical_results.jpg) were inspected; results identify Bazaar/drift car and the missed target correctly.

## Retained failures and limits

`drift_01` failed before gameplay because the probe assigned a nonexistent profile-directory `data` member. It was corrected to `index`; the raw script error and process-exit record remain. That owned child was explicitly stopped; no results file was generated.

`drift_02` passed every gameplay assertion but failed strict verification on an existing `showcase_track.gd` UID warning. A fresh Summer headless editor loaded/re-saved `scenes/race/race.tscn`, refreshing saved resource registration; final `drift_03` starts without that warning. The original warning/results remain. PIDs 125708 and 31680 were checked absent alongside the final PID.

The 1,200 target remains provisional. The deliberate alternating steering fixture earns 486 points; this establishes scoring and clean completion, not human skill balance or attainability of the target. Owner driving/control feedback remains required. Editor diagnostics show zero errors and existing compiler/live-session warnings; final disposable-run logs are clean. No all-course gameplay acceptance is claimed by this focused mode check.

## Timed HUD verification — 5 October 2026

The main HUD race timer now uses Time Attack's authoritative remaining deadline budget and Drift Challenge's remaining 90-second duration. Other modes continue showing elapsed time plus applicable penalties. Compact formatting avoids overflowing the existing panel.

`tests/probes/countdown_timer_verification.gd` passes countdown, exact HUD values, Time Attack extensions/penalties, pause, expiry-to-zero, retry budget restoration and untimed elapsed-time regression. Isolated rendered evidence: `tests/baselines/requirements_2026_10_05/countdown_03/`; strict runner passed in 8.703 seconds with no errors, frame warnings or shutdown errors. Drift HUD frame inspected. PIDs 3340, 13912 and 12260 exited and were independently checked absent.

Earlier runs remain unchanged: countdown_01 passed gameplay checks but had the recurring script UID warning; countdown_02 also had shutdown resource/ObjectDB warnings. Final probe returns to menu and drains pending work before shutdown; a fresh Summer editor load/save refreshed resource registration before countdown_03. This does not establish a permanent fix for the pre-existing intermittent UID warning.
