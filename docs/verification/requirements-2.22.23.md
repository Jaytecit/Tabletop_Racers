# Requirements 2.22.23

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Implemented the requests in `C:/Users/jayte/Desktop/Requirements.txt`:

- Main menu Quit button with confirmation; Change Profile in Setup.
- Small Asset Credits button at the top left with a translucent background.
- Bottom-right `(C) JAYLABS 2026 / v2.22.23` footer. The arcade font lacks the
  copyright glyph, so the text uses `(C)` to avoid a missing-glyph box.
- Results offer Retry, Select Course and Main Menu.
- WRONG WAY appears after 0.6 seconds of reverse motion, clears on forward motion,
  stopping, pause, recovery or leaving racing, and plays no sound.
- Lap, missed-gate and finish notices play no sound. Race music keeps its selected
  volume during notices and impact feedback; countdown and vehicle sounds remain.
- Schema 15 migrates unspent vehicle points/Bling into the saved driver's wallet.
  Earnings and spending use that wallet; purchased vehicle stats/paint are retained.
- Oval uses the original `fence_ALPHAat_0` mesh for baked, double-sided collision.
  Road boundaries, heights and timing stations were not refitted.
- Imported checkpoint validation uses the measured lane height rather than the
  centre height. Flags do not define checkpoint width.

Evidence is in `tests/baselines/requirements/`. The corrected pre-fix Oval probe
reproduced eight missed crossings out of 40 on gates 2 and 6. The same probe passed
all 40 after the height fix. Fence verification passed 96 ray locations from both
sides, 96 car sweeps following the banked surface, 3,456 road support samples and
480 ordered gate cases (forward, reverse, wrong height, repeat and skip).

`features_complete` passed wallet migration/idempotence, independent profiles,
earnings, paint purchases, upgrade spending, menu navigation, quit cancellation,
wrong-way states and notification audio checks, with rendered frames.

Failed initial probe runs are preserved. The fence ray probe initially sampled
above the source mesh's top and used local coordinates in a world query; these
test errors were corrected. The original flat car sweep also skipped the bank's
descent; the corrected sweep follows the measured road height.

The existing `race.tscn` warning about the `showcase_track.gd` UID is present in
verification logs; Summer successfully falls back to its text path. No runtime
script errors occurred in the passing runs.

`oval_race_corrected` passed the rendered three-lap race: four finishers, zero
crashes, recoveries or checkpoint penalties. It also passed throttle/boost,
manual recovery, pause/resume, course switching, rebuilt flags and time trial.
The existing probe needed explicit disposable profile confirmation after the
profile startup flow changed; the stalled first attempt is retained.

`player_stats_complete` passed the full upgrade suite, including caps, budgets,
input, cosmetic equip/purchase, reward duplication, migration and disk persistence
in an evidence-only profile. Its previous assertions referenced retired vehicle
nodes/materials and assumed base rival tuning rather than the loaded tuning;
these probe assumptions were updated. Earlier failure evidence is retained.
The verbose run also reports hardware RGB8-to-RGBA8 conversion warnings.
Its Vulkan startup log reports missing Epic overlay manifests and a failing
ReShade DLL on this machine; rendering continued and all probe assertions passed.
These machine-level loader messages were retained, not reported as clean logs.

All owned rendered test PIDs were confirmed absent after completion; individual
`process-exit.txt` records and `summary.json` preserve the checks. The user's editor
was not stopped. Generated Oval resources were backed up before regeneration in
`oval_resource_before`.
