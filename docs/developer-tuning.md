# Developer baselines

Updated 6 October 2026. Open **DEVELOPER TUNING** from the main menu or a paused race. The target selector chooses the layer being edited; the group selector chooses the type of setting.

| Target | What its values mean | Scope |
| --- | --- | --- |
| All Vehicles / Shared | Multipliers of existing factory handling and vehicle surface factors; 1 means unchanged. | Every vehicle class, human and AI. |
| Individual Vehicle | Absolute handling values replacing the shared vehicle result. Recovery duration remains an additional duration multiplier. | Every driver using that vehicle, including future class selections. |
| Overall AI | Physics multipliers applied after the vehicle baseline, plus absolute AI behaviour overrides. Untouched behaviour follows the mode's difficulty. | All seven AI; excludes human physics. |
| All Characters / Shared | Handling multipliers applied after vehicle and AI physics. | All eight portrait identities, human and AI. |
| Individual Character | Overrides of shared character multipliers, plus optional AI behaviour overrides. | That portrait identity in any grid slot or vehicle. AI behaviour fields apply only when it is an AI driver. |

The effective handling order is **factory vehicle → shared vehicle scale → individual vehicle override → overall AI physics scale for AI → character modifiers → driver's vehicle upgrade build**. The accepted factory AI compensation in `tuning_defaults.gd` is retained before the shared vehicle scale. Untouched values preserve current handling. AI uses neutral upgrade points; the human uses the selected driver build, or the explicitly selected stat-test build. Character identity is independent of the garage's saved stat build.

For example, a vehicle's factory top speed of 15 m/s with a shared vehicle scale of 1.2 becomes 18 m/s. An individual vehicle override of 20 replaces that result. A character speed modifier of 1.1 makes its baseline 22 m/s. A driver build's speed modifier then applies to 22, preserving the effect of purchased upgrades.

Each row shows its inherited value, **INHERITING** or **OVERRIDE**, units, allowed range and live/reset status. Enter a value and select **APPLY**; the fine and coarse buttons adjust it by 0.01 and 0.1. **INHERIT** removes that field's override, so later parent-layer changes reach it. **RESET LAYER** removes only the selected layer. **RESET ALL LAYERS** restores factory developer settings in the current session. Save afterwards to make either reset persist. Individual character modifiers replace the shared modifier for that field; they do not multiply it a second time.

Collision dimensions, body height, traffic width and watercraft classification belong to individual vehicle layers and apply when the race resets. Surface response and tyre-effect thresholds remain individual vehicle settings; shared vehicle surface-speed/grip scales are also available. The preview shows one affected racer's applied speed, grip and acceleration including its driver build. Active/available counts distinguish racers on the current grid from the full instantiated roster. Inactive vehicle classes and all eight characters can be tuned before selecting them for a race.

**SAVE BASELINES** writes the five baseline dictionaries to `user://developer-baselines.json` for all profiles and future launches. Changes are session-only until saved. Saving does not write driver upgrades, rewards or identity. Malformed or unsupported saved data is rejected without replacing current settings; a failed save retains session changes. Non-default developer baselines remain experimental/unranked, with race records and rewards disabled. Exporting or saving does not automatically promote them to production defaults.

**EXPORT SETUP** writes schema 3 JSON with the complete baseline layers, all five vehicle baselines, all eight character identities, eight racer snapshots, inherited descriptors, requested/applied handling, pending geometry, driver builds, AI profiles, surfaces and race context. The `baseline_layers` section is the portable configuration; promotion into shipped factory defaults requires a separate accepted balance change and verification. The older slot override API remains available to diagnostic probes but is not exposed as an additional menu layer and is not saved with these baselines.

Audio/video assets, controls, reward balances and upgrade points are not edited by the tuning rows. The separate **CLEAR EARNED AND SPENT REWARDS** action keeps its existing explicit confirmation and backup workflow.

See [verification](verification/layered-developer-baselines.md) for executed scope and retained failures.
