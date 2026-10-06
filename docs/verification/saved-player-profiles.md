# Saved player profiles — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

After intro completion or skip, select a saved driver or create one with 1–9 A–Z letters and one of four portraits. The last selection is highlighted; Confirm proceeds to mode selection. Change Profile is available from the main menu. Changing vehicle livery retains the saved person.

Schema 13 retains the existing progression, builds, records and history. The original `user://profile.json` and backup remain untouched; migration stages a payload under an opaque ID before publishing `user://profiles/index.json`. Existing owners confirm their name/portrait. Each driver has an independent validated payload and backup. Directory/payload failures are shown without replacing another driver's save. Shared display/audio/effects preferences use `machine_settings.json`; input bindings retain `controls.cfg`.

Race rows and results use driver names and the saved portrait. Authoritative session ranks supply unpadded overhead numbers. Racer identity stays keyed to its slot while rank changes. Minimap racers are coloured circles, with the player's visibility ring; text and leader lines are removed and the route remains visible.

## Evidence

- `tests/baselines/profiles/run13_titles/results.json`: all 41 report fields true, no gameplay errors, frame warnings or shutdown errors. Real intro completion, keyboard confirmation, migration/restart, two profiles, independent builds/records/rewards, all eight mode save fixtures, retry/cancel/switch, rank changes/ties/lapped/finish/elimination, results portrait, livery independence and blocked in-race switching.
- `run10_skip`: separate `--skip-opening` launch reaches the picker and passes the profile suite at that revision. Subsequent changes add identity assertions and screen titles without changing the skip hook.
- Guard fixtures cover name boundaries/full pasted input, duplicate names, invalid portraits/IDs, future schema, corruption/backup recovery, interrupted migration, read-only writes and unwritable destinations. All writable fixtures are inside evidence directories; owner files are read-only.
- Rendered captures in `run13_titles`: `saved_driver_selection.jpg`, `create_driver.jpg`, `race_names_positions_dots.jpg`. Earlier `run12_final` captures were visually inspected; the final run verifies the clarified create/existing-driver titles.
- Every owned test process exited; `process-exit.txt` is retained. Failed early runs remain available: encoding/newline errors, JSON numeric portrait validation, deferred course/focus fixture timing. Those were corrected before the passing runs.

The all-mode checks verify identity and persistence boundaries through actual mode actions; they do not claim eight newly completed full physical races. Restart the existing game instance to initialise the new profile UI. The user's running editor/game was left alone.

## Player stats page correction

The former second driver/livery selector is replaced by `driver_stats_page.gd`. It uses the selected save's name/portrait and a fictional portrait-specific bio, displays current vehicle earned skill levels (0–24), current vehicle available upgrade points, total garage points, cup/tournament wins and saved record count. Existing upgrade editing remains available; saving refreshes this summary. Next proceeds to Garage for Freestyle and Course for assigned-class modes; Back from Course returns to stats. The hidden legacy cards no longer offer a second driver choice.

`tests/baselines/player_stats/run02` passes rendered JAY/Kit portrait verification, earned skill/point display, actual upgrade apply/summary refresh, all four bios fitting, nine-letter name display and navigation. No runtime/shutdown errors; owned PID 75744 exited. Real profiles remained read-only. The earlier capture exposed an overlong bio, shortened before the final capture. Different starting skills are pending the user's choices; no starting bonuses or save migrations were applied for them.

## Starting builds and authorised clean start

The user then specified eight applied upgrade points across all five skills, plus two speciality points: Roxy acceleration, Finn grip, Kit boost, Bea speed. The common split is grip 2, speed 2, boost 2, recovery 1, acceleration 1. The specialty adds two quarter-step upgrades, giving ten total applied points per vehicle; available points begin at zero. New profile creation applies this build across the five vehicle classes. Portrait-specific starting builds remain separate from subsequent earned upgrades.

At the user's explicit request, the registered Jay/Kit save was reset to this baseline: upgrade balances/spending, Bling, owned paint, gold unlock, cup/tournament wins/progress and challenge rewards cleared. Name, portrait, preferences and all 42 race records remain. Historical detached legacy saves are preserved. The prior profile/index files and backups are copied to `tests/baselines/progression_reset/backup`.

`tests/baselines/progression_reset/results.json` verifies all four valid ten-point allocations, new profile persistence across every vehicle, reset preserving records, one-time reset tokens and a stale in-memory save receiving the reset before writing. A path-local `.reward-reset` token prevents old state from undoing the reset; later earned rewards survive reload because the token is retained. Read-only and future-version stores do not apply writes. The editor-script fixture/reset passed with no parse/runtime/boot errors and child exit code zero. The Dev menu reset option is recorded in Task 6; that future menu has not yet been built.
