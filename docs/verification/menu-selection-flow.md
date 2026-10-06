# Menu selection flow — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Setup is visible only on the main mode page. Gold Livery button creation and layout/refresh references have been removed; stored cosmetic preferences remain compatible. Driver-card activation saves the character and advances automatically. Freestyle visits Vehicle then Course; assigned-class modes skip Vehicle, including on Back. Programmatic vehicle/stat refreshes do not trigger advancement.

Rendered isolated probe: `tests/probes/menu_selection_flow_verification.gd`.

Evidence: `tests/baselines/menu_selection_flow/run_02/`. Quick Race, Time Trial, Freestyle, Challenge, Elimination, Time Attack, Drift and Tournament passed character activation using injected accept input, Setup visibility, automatic forward navigation and Back sequencing. Main-menu Setup opens successfully; no GoldLivery nodes exist. Screenshots cover Setup, Freestyle Vehicle and standard Course. No gameplay errors, frame warnings or shutdown errors were recorded. PID 30572 exited normally; `process-exit.txt` retains confirmation.

`run_01/` is preserved as failed evidence. Its sole failed assertion incorrectly expected Freestyle Course → Back to land on Character rather than Vehicle. The corrected assertion passed in run_02; no production change was needed between runs.

The saved named-profile system remains planned. The current character-selection UI implements this navigation rule; the future profile UI has the same rule recorded in the 5 October implementation plan. Physical controller acceptance and a full race are outside this focused menu check.
