# Developer menu and complete setup export

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Task 6 is implemented. Developer Tuning is available in the main menu and pause screen. The overlay is independent of the earned upgrade menu and preserves pause state and focus.

## Delivered behaviour

- Physics, Boost / Recovery, Surfaces, AI and Vehicle Details groups share the 59-field descriptor table with export. Direct numeric entry, stock references, units/ranges, fine/coarse changes, boolean toggles, mixed AI values and restart labels are visible. Player, all-AI and individual-AI targets have reset controls. Keyboard focus scrolls the settings list. Invalid/non-finite or out-of-range edits are rejected without changing tuning.
- Escape closes the overlay without also resuming a paused race when Escape is bound to both Cancel and Pause. Controller gameplay shortcuts cannot change the race behind the overlay. Dynamic focus neighbours discard replaced rows before resolving node paths.
- Export Setup JSON opens a save dialog, reports cancellation/success/failure, validates finite values before writing and uses a temporary sibling followed by replacement. Existing output survives rejected non-finite data. No import UI was added.
- Clear Earned and Spent Rewards names the selected profile and shows its scope before confirmation. The reset saves a separate validated pre-reset backup, commits a fresh durable reset token, then applies the existing reset routine and persists it. Upgrade balances/builds, Bling, paint, gold, cup/tournament progress and challenge awards are reset. Every vehicle receives the portrait's ten-point starting build. Identity, preferences and race records remain. Read-only stores reject the operation before any write. Existing instances apply the marker before saving, preventing stale rewards from returning.

## Export schema

Version 1 UTF-8 JSON contains `schema_version`, `experimental`, `context`, `settings`, `racers` and `vehicle_definitions`.

`settings` includes every descriptor for every slot, with value, stock reference, type/unit/range, target/application mode, active/overridden flags and pending restart state. All four racer slots remain present; inactive racers/settings are flagged rather than omitted. Surface settings absent from the route, inactive AI behaviour, and surface-speed overrides bypassed by Freestyle assist are inactive.

Each racer contains base, earned-derived, applied effective and requested tuning (separately retaining pending geometry), earned build, identity, AI profile/difficulty/seed, surface definitions and overrides. Vehicle definitions include source definition paths, original/runtime visual IDs, collision dimensions and rendered mesh bounds. Context includes game/engine/handling/stat versions, course/route identity/revision/signature, environment/source scene references, mode, laps, rivals, difficulty/seed, selected profile/identity, setup/control/camera preferences, benchmark, tournament and time-attack settings, phase and pause state. Mesh binaries are not embedded.

## Verification evidence

Probe: `tests/probes/developer_menu_verification.gd` through the isolated rendered runner. Personal profiles, machine settings and profile directory remain read-only; hardware bindings and controller polling are isolated. Writable reset fixtures live only under the probe output directory.

Accepted evidence: `tests/baselines/development/developer_menu/accepted_input/`. Passed in 7.562 seconds with no assertion failures, script errors, frame warnings or shutdown leaks. Owned PID 98940 exited normally with code 0; see `process-exit.txt`.

Checks cover main-menu and pause entry through injected UI input; numeric/fine/coarse/all-AI/individual-AI edits and mixed-state rejection; invalid numbers; pending collision geometry; complete descriptor-key and per-racer resolved-value export parity; source/context data; inactive settings; real file-dialog Cancel and confirmation buttons; failed path; non-finite export preserving an existing fixture; atomic replacement; reset persistence/reload, records/identity/preferences preservation, portrait allocations for all five vehicles, pre-reset backup, idempotence with a fresh token, stale-session saves and read-only rejection; successful UI reset on a disposable store; keyboard scrolling/navigation; Escape pause preservation and subsequent resume.

Rendered frames were inspected for the menu entry, grouped controls, mixed AI values, scrolling, pause overlay and complete reset scope. The confirmation stays within the viewport and includes both action and Cancel.

Earlier evidence is retained: `menu_1`/`menu_2` had a pause assertion before injected release delivery and initially compared unvalidated JSON backup types; `menu_3` used a direct signal while investigating; `menu_4` revealed stale dynamic focus neighbours; `menu_5` passed checks but visual inspection found the unwrapped confirmation too wide. These were corrected and verified in later `final`, `final_controls`, `accepted` and `accepted_input` runs. The `boot` run also passes the prior tuning smoke probe.

Next planned phase: Task 7, move Drift Challenge defaults to Bazaar. No imported track, route or procedural course geometry was edited in this phase.
