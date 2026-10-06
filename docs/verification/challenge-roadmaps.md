# Five-stage challenge roadmaps — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Owner-confirmed scope: Drift Challenge, per-track Challenge and Time Attack. Tournament and Elimination retain their existing rules. The owner resolved the initial numerical conflict in favour of drift targets **700, 1,000, 1,300, 1,600, 1,900**.

The course screen shows five stage buttons, completed stages, the playable next stage, locked future stages and the selected target. Earned stages can be replayed. One valid run earns its selected next stage; it does not skip later stages. Completing all five leaves all stages available. Progress belongs to the selected named profile, mode, course and route revision. A different profile or track starts independently. Schema 14 validates the bounded progress map; older saves default to an empty roadmap without preservation-only migration.

| Stage | Drift score, 90 seconds | Challenge clean-finish time | Time Attack start and gate extension |
|---|---:|---:|---:|
| 1 | 700 | 130% of course baseline | 130% of course baseline |
| 2 | 1,000 | 115% | 115% |
| 3 | 1,300 | 100% | 100% |
| 4 | 1,600 | 90% | 90% |
| 5 | 1,900 | 80% | 80% |

Challenge uses three ordered clean laps: no contact, recovery, missed gates or penalties, finishing at or below the selected target. Its baseline remains three times the course entry's lap-range midpoint. Time Attack now fixes three laps for comparable stages; both initial budget and ordered checkpoint extensions use the selected factor. Countdown, pause, penalty deductions, expiry and retry use the effective budget. Drift retains its physical scoring rules and duration. Stage/target are captured before a run; changing setup cannot redirect an award to another course. AI and developer/stat experiments cannot advance roadmaps. Reward clearing also clears challenge roadmaps.

## Verification

- `roadmap_05`: strict rendered pass, 12.083 seconds, zero assertion/runtime/frame/shutdown failures. All 15 stage result fixtures, locked selection, failure thresholds, duplicate awards, keyboard replay, profile disk reload, fresh-profile and track isolation, dirty Challenge rejection and AI/experimental guards pass. Progression fixtures seed result/timer data; they do not prove all targets are physically attainable.
- `roadmap_countdown_01`: strict rendered pass, 8.243 seconds. Real short physics runs verify countdown/HUD, extensions, penalties, pause, expiry, retry and untimed elapsed-time regression after integration.
- Inspected [Drift progress](../../tests/baselines/requirements_2026_10_05/roadmap_05/drift_stage_1.jpg) and [complete Time Attack roadmap](../../tests/baselines/requirements_2026_10_05/roadmap_05/time_attack_stage_5.jpg); buttons and target text fit the existing course layout.
- Evidence and raw failures remain under `tests/baselines/requirements_2026_10_05/`. PIDs 85356, 121328, 39796, 40572, 17828 and 59884 were independently checked absent. Tests use sandboxed profile/control files and read-only owner/machine settings, with isolated hardware input.

Earlier `roadmap_01` passed progression assertions but failed on the recurring script UID warning. `roadmap_02` additionally recorded shutdown resource warnings. `roadmap_03` captured verbose external Vulkan-layer warnings and replay assertions sampled before input release was dispatched. `roadmap_04` retained those replay assertion failures plus UID/shutdown warnings. Final probe drains injected input frames and releases its temporary loaded profile before quitting; a fresh Summer scene load/save refreshed resource registration. These failures are not relabelled as passes, and no permanent UID-cache fix is claimed.

The non-drift factors are provisional designer scales. Further course/vehicle driving tests and owner feedback are needed to establish enjoyable balance and attainability, especially the final stages. Canonical geometry and vehicle handling were not changed for this feature. Development record/reward preservation remains unnecessary under the owner's policy.
