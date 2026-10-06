# Per-driver stats — 4 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Historical schema-6 verification. Current earned per-vehicle progression supersedes these zero-sum allocations; see [vehicle progression](../vehicle-progression.md) and [class verification](vehicle-classes.md).

Milestone 4 adds a DRIVER STATS button to driver selection and the garage. Each of the four saved drivers has its own build, including the drivers assigned to AI slots. The modal uses the menu theme, isolates keyboard focus, and supports Save, Reset to Neutral, Cancel and Escape. Final values also appear on the buggy garage page.

The four integer allocations range from -2 to +2 and must sum to zero. Grip changes both powered and coasting lateral damping by 8% per point; speed changes the top-speed cap by 4%; boost changes normalized tank duration by 10%; recovery changes crash/fall and return speed by 8%. Acceleration, steering, brake strength, boost power, collision immunity and checkpoint penalties are unchanged. Neutral values preserve the base vehicle resource. Every composition starts from that resource, so repeated selection does not compound multipliers. Water traversal remains a milestone 5 requirement.

Profile schema 6 saves allocations by driver ID. Missing/invalid historical allocations receive neutral defaults; JSON numeric points are normalized to integers on load. Invalid builds cannot be applied in the UI. Stat context extends record keys and replay signatures, retaining old six-part records rather than overwriting them with a different build. Existing records may be retired by the handling signature change. Final class/surface tuning and benchmark locking remain pending.

## Verification

Evidence is in `tests/baselines/development/stats_*`. Disposable rendered instances disable hardware input and redirect profile/replay writes into their evidence folders. The user's editor is not stopped.

- `stats_initial`: aborted after a probe used nonexistent `p1_boost` instead of the actual `boost` action; raw errors and frames retained. PID 124472 exit confirmed.
- `stats_final`: superseded while adding the actual speed-cap measurement and garage summary; partial evidence retained. PID 131136 exit confirmed.
- `stats_verified`: failed persistence equality and selected inactive procedural IDs; the soft timer expired. Saved points were numerically correct but JSON types needed normalization. The corrected probe explicitly checks active catalogue selection. PID 70060 exit confirmed.
- `tests/stats_parse.log`: preserve the unsuccessful headless editor check; extension library copies failed because this approach conflicts with loaded editor libraries. Rendered probes provide the actual parse/runtime evidence.

Representative race tests run at time_scale 4 and 240 physics ticks per second, preserving the regular 1/60-second simulation delta. Results are development observations with the current AI, not owner benchmarks or calibrated difficulty. The validation checks live speed limiting, lateral damping, boost consumption, recovery timing, independent driver assignment, persistence, invalid allocations, record context and ordered lap completion. Neutral, grip and speed/boost builds are compared on Roulette Grand Prix, Toys R You and Mount Rainier. Nine single-lap samples cannot establish final balance across all future classes and environments.

`stats_corrected` finished and passed with no gameplay errors or frame warnings. PID 18320 exited. Actual velocity caps were 15.444 and 13.156; residual lateral velocities were 1.857 and 1.806. A 0.1-second boost consumed 4.25 versus 2.833 tank units, and crash returns took 1.35 versus 1.85 seconds. Allocation rejection, disk reload, driver/AI assignment and record-key validation passed.

All nine one-lap runs finished with zero crashes and checkpoint penalties:

| Course | Neutral | Grip +2 / speed -1 / boost -1 | Grip -1 / speed +1 / boost +1 / recovery -1 |
|---|---:|---:|---:|
| Roulette Grand Prix | 45.94s | 47.41s | 46.52s |
| Toys R You | 46.97s | 47.17s | 47.86s |
| Mount Rainier | 85.92s | 88.28s | 86.50s |

These runs show the representative builds remain capable of clean completion, with a maximum time spread of about 3.2%. They do not measure human optimal driving or prove all 85 valid allocations equally capable. Final tuning remains open until the five vehicle classes and surface rules are present.

`stats_restart` loaded the evidence-local saved allocation in a fresh rendered process. Restart persistence, neutral defaults for schema 5 profiles, isolated modal focus, Escape cancellation, pause and retry all passed. Garage and stats frames at 960x640 were reviewed. Gameplay errors and frame warnings were empty; shutdown stderr retains 12 ObjectDB leaks and one resource-in-use error. This is a remaining teardown limitation, not a clean-shutdown claim. PID 164260 exited. No disposable test processes remain from this task.
