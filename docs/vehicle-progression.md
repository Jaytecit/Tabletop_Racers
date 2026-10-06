# Vehicle progression

> Reconciled 6 October 2026. Current schema is 17. Wallet/per-vehicle behaviour below is implemented; schema numbers in the migration history name earlier releases. Development scores/rewards may reset/invalidate when useful, without preservation-only migrations. Named identities/preferences remain protected. See [current build](current-build.md) and [remaining work](implementation-checklist.md).

Earned points and Bling belong to the saved driver profile and can be spent on any
vehicle. Purchased upgrades and paint remain specific to that driver's vehicle.
New vehicles start
with all five internal stats at -2 (displayed as 0). One upgrade point adds 0.25
to one stat. The internal cap is +4, displayed as 6: 24 subdivisions per stat,
120 upgrades in total. Rival cars retain their original neutral tuning.

The five stats are grip, speed, boost, recovery and acceleration. The range
below is relative to base vehicle tuning. Steering and braking are unchanged.

| Capability | Starter | Maximum |
| --- | --- | --- |
| Top speed | 80% | 124% |
| Acceleration | 65% | 140% |
| Grip and coast grip | 70% | 140% |
| Full boost duration | 65% | 160% |
| Recovery speed multiplier | 70% | 150% |

The curve passes through base tuning at internal 0 and uses separate slopes
below and above 0, giving a weaker starter without excessively increasing the cap.

Finish a standard race of 1–3 laps to earn 1 upgrade point. Races with rivals
give 2 additional points for first place or 1 additional point for second place.
Solo races and time trials give completion points only. Multiply rewards by
ceil(laps / 3) for longer races. DNF and abandoned races earn nothing; results
pay once per race. Each upgrade point awarded also grants 10 Bling.

The vehicle upgrades menu accepts mouse clicks, keyboard and controller focus
navigation. Up/Down chooses a stat, Select/Right stages an upgrade, Left undoes
pending upgrades. Save commits spending; Cancel discards pending upgrades.
Previously purchased upgrades cannot be refunded. Each row shows the displayed
boost, subdivisions purchased and a 24-segment progress bar.

The TEST STATS button cycles Earned -> Zero -> Full -> Earned. Zero means all
stats displayed as 0 (-2 internally); Full means displayed 6 (+4 internally).
The override applies immediately and survives retry and returning to the menu,
but resets to earned upgrades when the game restarts. It never changes saved
upgrades or wallets. Test races do not award currency, records or cup progress.

The Bling shop sells Mint Pop (100), Violet Flash (200) and Chrome (300).
Purchase/equip applies to both the garage preview and player's racing car;
purchases save immediately. Re-equipping owned paint is free. Bling never
spends upgrade points or changes handling. Stock restores the driver's colour.
Cup-winning gold remains an achievement unlock and overrides purchased paint
until the player equips another finish or turns gold off.

Profile schema 15 pools previous unspent vehicle balances into one driver wallet
exactly once. Existing stats, purchased paint and equipped paint are preserved.
Saving and reloading never adds those historical balances again.

Profile schema 12 retained schema 8's progression under vehicles.<vehicle_id> and
adds independent builds for all five classes, a remembered Freestyle vehicle and
legacy record history. Old driver allocations migrate to the buggy only; newly
added classes start fresh. Schema 7 and
earlier builds preserve existing stat levels, points and cosmetics; acceleration
starts at internal 0 for migrated builds to retain their original acceleration.
Schema 6 and earlier use the selected driver's valid zero-sum stat build. Invalid
or absent old builds use the new starting stats. The revised curve applies to
existing stat levels. Legacy stats-1 and stats-2 record keys remain valid; stats-3
keys include acceleration, keeping different upgrade builds separate.

## Verification

Run `tests/probes/player_stats_verification.gd` through
`tools/run_tabletop_verification.ps1`; the probe checks input, budgets, caps,
tuning, cosmetics, race results, reward duplication, migration and persistence.
It feeds completed racers into the authoritative session classification; it
does not change route geometry or retest the course-driving pipeline.

Then run `tests/probes/player_stats_restart_verification.gd` to load the saved
`tests/baselines/development/progression_acceleration/profile.json` in a fresh process,
inject isolated controller input, and verify retry/pause retain upgrades.
Both probes isolate hardware input and keep the real profile read-only. Only
the first probe's disposable evidence profile is written for persistence tests.

Earlier evidence directories progression_initial and progression_verified are
preserved, including the initial numeric-type persistence failure and the
migration assertion corrected to compare normalized numerical values.

The restart probe initially asserted before the controller button was released;
the corrected probe checks the complete press/release, matching button behavior.
Verbose diagnostic runs also preserve machine Vulkan overlay warnings. An audio
playback warning at disposable process teardown was traced to active Ogg/WAV
playback; both probes now stop their audio and let the mixer settle
before quitting. No audio behavior in the game was changed.

The acceleration physics probe compares real car physics on the same supported
surface: after 30 fixed 1/60-second updates at full throttle, starter speed was
5.05 and full-upgrade speed was 10.88. Both were grounded and stable. The first
attempt preserved a controller-ownership flag and recorded zero throttle; that
failed evidence is kept in upgrade_feel, with the corrected isolation in
upgrade_feel_corrected. These checks measure the effect; the final driving feel
is assessed using the zero/full toggle.
