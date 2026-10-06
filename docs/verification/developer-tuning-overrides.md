# Developer tuning override model

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Implemented session-only overrides in `scripts/vehicles/developer_tuning.gd`. Menu/direct-entry controls and setup export belong to Task 6 and are not implemented yet.

## Contract and inventory

`descriptors(base, difficulty)` supplies 59 fields with types, stock references, units, bounds, targets, live/restart classification and fine/coarse increments. `set_value(target, field, value)` validates an entire target batch before editing. Targets are `player`, `all_ai`, and `ai_1` through `ai_3`. `values()` reports resolved numeric values, mixed AI values and pending restart changes. `reset_target()` and `reset_all()` restore earned tuning; applied geometry is restored at the next reset.

- Physics: top speed, acceleration, braking, reverse, grip/coast grip, low/high steering, drag.
- Boost: drain, recharge, speed multiplier, acceleration multiplier. Zero drain permits unlimited boost even with an empty reserve.
- Recovery: duration multiplier above earned recovery speed and immunity duration. Base crash/fall/return timing remains 0.7/1.0/0.85 seconds divided by effective recovery speed. Recovery animation/gravity constants are unchanged.
- Vehicle geometry: collision size XYZ, collision height, traffic half width; watercraft toggle. These apply at reset, with a fresh collision shape.
- Surfaces: vehicle speed/grip factors and preset grip/drag for all eight supported surfaces. Preset colour and surface identity are presentation metadata.
- AI: speed, look, margin, passing preference, steering error and boost toggle from the selected difficulty profile. Difficulty, seed and fixed decision/attack rules remain race configuration/code.
- Vehicle ID, source resource path and handling version are immutable metadata. Recovery speed is derived from the earned build and developer duration multiplier.

Composition is base resource → earned/stat-test build → overrides → effective physics. Dictionaries and surface resources are independent per racer. Overrides never enter profile persistence. Steering at zero top speed and AI preview at zero braking use a small denominator floor; stored zero values are preserved. Checkpoint/recovery/drift speed limits use the effective boost multiplier.

An override marks the active run experimental until the next fresh run. Resetting during a race cannot re-enable records or rewards. Records/replays, upgrade rewards, cup scoring, challenge awards, drift records, owner benchmark designation and tournament rounds are guarded. The HUD and vehicle status label experimental runs.

## Verification

Probe: `tests/probes/developer_overrides_verification.gd`, launched through `tools/run_tabletop_verification.ps1` in an isolated rendered process with read-only profiles and hardware input removed.

Retained evidence under `tests/baselines/development/developer_overrides/`:

- `initial`: obsolete stat-toggle probe failed the newer profile selection flow; no script errors.
- `model_1`: 175 descriptor boundary drives and isolation/reward assertions passed; audio playback objects leaked at shutdown.
- `model_2`: failed launch after a CP1252 middle dot entered a script; encoding corrected, exact owned process stopped and exit retained.
- `model_3`: assertions passed; verbose Vulkan validation exposed unavailable machine overlay manifests and confirmed leaked objects were audio streams/playbacks.
- `model_4`: 175 cases passed with clean error log and shutdown after explicitly stopping and draining test audio. Unlimited boost was driven, geometry/reset parity and reward guards verified.
- `final`: five-vehicle boundary sweep plus empty-reserve unlimited boost, visible unranked label, reset, resource independence and progression guards. 875 cases passed in 121.938 seconds with no failures, script errors, frame warnings or shutdown leaks; owned PID 152376 exited normally.

No track route, imported GLB or procedural course geometry was edited.

The retained `visual` smoke run exposed missing saved-course assets and a probe latch setup error. `visual_2` passed assertions but the context label was obscured by start lights. The corrected `visual_final` asserts actual visibility, shows EXPERIMENTAL / UNRANKED over a rendered Game Table race, and passes all guards with clean shutdown (PID 145024 exited normally). Earlier failures remain intact.

Visual inspection found the start-light panel physically covered the prefix despite Label visibility. The context label now moves below the lights during experiments. `visible_label` passes and its rendered frame visibly shows the full EXPERIMENTAL / UNRANKED text; owned PID 32708 exited normally with clean shutdown.
