# Racing modes - implementation in progress

> Reconciled 6 October 2026. Current Quick Race/Freestyle support 1–8 cars; Tournament remains four and Elimination 2–4. Solo modes and capability gates remain intentional. Eight-car expansion/solid finishers are pending. Mode frameworks are implemented; final balance/coverage remains open. The dated evidence table below retains original counts and results. See [current build](current-build.md) and [remaining work](implementation-checklist.md).

The active menu retains Quick Race, Time Trial and Freestyle. Tournament, Challenges, Elimination, Time Attack and Drift Challenge now have integrated setup/session/results paths. Final target tuning and full catalogue acceptance remain outstanding. Profile schema 12 adds tournament, challenge, drift-score and owner-benchmark state without replacing retired Casino Cup data or existing records.

## Rules and persistence

- Tournament offers Toybox Trophy (Toys R You, Toys R Asleep, Roulette Grand Prix), After Hours Tour (Workshop, Junk Heap, BBQ, Noodles) and Road Masters (Rainier, Topspeed). All rounds use three laps, Normal AI and the course-assigned class. The selected driver stays fixed during a series. Finishers receive 10/6/4/2 points; DNFs receive zero. Ties use wins, total time including a DNF sentinel, then player slot. Each completed round retains course, class and source signature. Resume, abandon and a new series are available; a final win awards one trophy/gold unlock. Existing Casino Cup progress is retained separately.
- Challenges are solo three-lap runs for the selected driver and assigned class. Finish, clean finish and a clean target-time medal persist independently for every driver/course/vehicle/upgrade/rule context. Contact, recovery or any missed-gate warning prevents clean credit, even if the gate is recovered before its penalty. AI, stat-test builds, DNFs and invalid lap totals do not award achievements. Older contexts stay visible as old achievement sets. These runs do not write ordinary race PBs.
- Challenge targets initially use three times the midpoint of each entry's documented lap range. These are provisional designer targets, not owner benchmarks. Rule-source and target changes alter the context signature. Final targets require the planned balance and per-course runs.
- Elimination removes the last active racer at leader lap two, then each subsequent leader lap. Equal progress uses stable player-slot order. Two to four entrants require two to four leader laps. Eliminated bodies leave collision and traffic; the player immediately gets an out/result panel with retry/menu while AI continues. The final survivor wins. Elimination PBs are isolated by mode, field, course, class and upgrades.
- Time Attack is solo with three laps and a five-stage difficulty roadmap. Ordered valid checkpoint events extend its countdown once per gate/lap. The clock pauses with gameplay; missed-gate penalties subtract five seconds. An interpolated crossing within a tick may beat its deadline. Expiry is a DNF; valid finishes use a separate mode PB. Initial start/extension values derive from each course's documented lap range and gate count; actual course tuning remains open.

- Drift Challenge now enables only Bazaar; Topspeed scores remain valid historical records. See [Bazaar selection, history and physical verification](verification/bazaar-drift.md). It assigns the drift car and runs for 90 seconds. Forward slip of 12-65 degrees must persist for 0.3 seconds at >=3.5 units/s, with valid grounded support and new route progress. Score is capped by actual travel distance. Straightening for 0.5 seconds banks the combo; contact, recovery, unsafe support, spinning or backwards/repeated movement drops it. The five roadmap targets are 700 / 1000 / 1300 / 1600 / 1900 points, as confirmed by the owner. Scores retain driver/class/upgrade/route/rule context; automated/stat-test scores do not persist.

## Evidence

All evidence is under `tests/baselines/modes`. Tests inject the sentinel profile before setup and isolate hardware input. Save/reload fixtures write only inside their own evidence directory. Confirmed exits are recorded per child.

| Evidence | Observed scope |
| --- | --- |
| `rules01`, `rules03` | Series lengths, active assignments, resume/duplicate rejection, scoring/ties, and challenge rule checks passed. Historical intermediate revisions retained. |
| `tournament-flow01` | 16.923s, runtime clean. Three real session-classification fixtures passed menu setup, next rounds, actual disk resume, old cup preservation, duplicate results, final award once, road assignment, abandon and new series. Setup and final results frames inspected. These are state fixtures, not physical laps. |
| `tournament-drive01/buggy` | Four neutral cars completed three Toys R You laps at Normal: 139.601 / 134.897 / 140.429 / 138.520s. Impacts 0/0/1/0; no crashes, recoveries or penalties. First series round committed; read-only profile retained. PID 6540 exited. This predates subsequent Elimination/Time Attack session additions. |
| `challenge-flow01` | Failed save/reload and historical-context checks. JSON converts numbers to floating point; the original key encoder did not canonicalize driver/lap integers. Raw failure retained. |
| `challenge-flow02` | Corrected key encoding passed actual save/reload, driver isolation, old contexts, duplicate results, pause, recovered missed gate, AI/stat-test/DNF rejection and separate records. Setup, medal results and history frames inspected. A long course-info label overlapped the trail; spacing was subsequently adjusted and passed the menu02/menu03 layout retests. |
| `rules04` | Current challenge JSON round-trip, driver isolation, clean/invalid cases and tournament rules pass with no runtime errors. PID 104384 exited. |
| `elimination-flow01` | Ordered sampled-route crossings passed safe first lap, player removal, immediate result, pause, continued AI completion, deterministic ties, once-per-leader-lap cut, retry restoration, two-car winner, separate validated PB and duplicate reward guard. Interim/final frames inspected. This isolates race rules from body collision; full driving evidence remains separate. |
| `elimination-drive01/buggy` | Four neutral cars, Toys R You, Hard: elimination at leader laps 2/3/4 removed slots 3/4/1; slot 2 won in 174.750s. Zero crashes, recoveries or penalties; contacts 1/0/2/3. Runtime clean, 186.63s, PID 18804 exited. |
| `time-attack-flow01` | Pause, interpolated deadline crossing, repeat/order rejection, missed-gate clock cost, expiry DNF, complete ordered lap, isolated validated PB and retry reset all pass. PID 91552 exited. |
| `time-attack-drive01/buggy` | Neutral solo Toys R You, three laps, 134.606s; zero impacts, crashes, recoveries or penalties. Runtime clean, 146.96s, PID 81852 exited. |
| `drift-flow01` | Scoring and integration passed except exact record reload: integer fields were not canonicalized after JSON parsing. Failure retained. |
| `drift-flow02` | Canonicalized score records pass actual disk round trip. Sustained slip, banking, loss on collision, anti-farming cases, course eligibility, class assignment, pause, target win/fail, duplicate award, retry and standard-mode restoration pass. Physical scoring is a separate run. PID 144460 exited. |
| `drift-drive01/drift_car` | Failed scoring acceptance: 90 seconds / three physical laps without crashes, contact or penalties, but zero score. Added live slip/eligibility telemetry; no target or handling change made to conceal the failure. |
| `menu01` | All eight modes start, and button bounds/spacing plus course-text clearance pass at 1280x720, 1920x1080 and 1600x720. A final fixture tried selecting Game Table while still in Drift mode and was correctly rejected; raw run remains failed. Corrected fixture switches mode first. Home and Drift setup frames inspected. |
| `drift-drive02/drift_car` | Diagnosis: all 5,401 samples had valid motion/support, but only 46 exceeded 12 degrees of slip (maximum 12.80 degrees), without sustained eligibility. Normal racing AI is not a deliberate drift input test. A command-only steering fixture now exercises purposeful slides without altering vehicle physics. |
| `menu02` | Corrected fixture passes all eight modes and all layout checks at three requested window sizes, including the long Game Table description. 16.852s, runtime clean, PID 12736 exited. |
| `drift-drive03/drift_car` | Command-only deliberate steering produced 248.578 banked points, best combo 91.740, maximum slip 22.316 degrees. The 90-second run incurred two recoveries and 10s in missed-gate penalties, with no impacts; target 1,200 was missed. Runtime clean; PID 162628 exited. This proves physical scoring, not target balance or a clean driving reference. Combo frame inspected. |
| `navigation02` | 900 synthetic keyboard/D-pad/stick transitions passed, with zero failed transitions; normal mode selection, driving, results and return flow also pass. 56.883s, runtime clean, exited. Physical-device acceptance remains separate. |
| `records02` | Legacy record/ghost replacement, backup retention and pruning pass against the expanded profile. 6.181s, runtime clean, exited. |
| `tournament-flow02` | Adds changing driver in Quick Race and restoring the saved series driver on resume; all flow/save checks pass. 17.629s, runtime clean, exited. |

| `menu03`, `rules06` | Latest benchmark integration: all eight mode pages and starts pass at three sizes (16.860s); mode rules pass (4.125s). Runtime clean; owned processes exited. |
| `owner-benchmark02` | Locked configuration, synthetic designation/history persistence plus result-button spacing, bounds and focus neighbours pass at all three sizes (6.355s). No owner time recorded. |
| `catalogue01` | All nine active courses pass selection, assigned class and retained geometry/anchor/sample parity (31.261s). |

| `shared-final-quick`, `shared-final-trial`, `shared-final-freestyle` | Latest shared session, terminal movement guard and benchmark changes: three physical Toys R You laps pass in all three modes. Four-car Quick/Freestyle times 135.522/131.295/136.952/136.208s, impacts 1/0/2/3; solo Trial 134.606s, no impacts. All zero crashes/recoveries/penalties; runtime clean, owned processes exited. |

## Outstanding acceptance

Full physical races for the new modes on each applicable course; actual human challenge driving/audio feedback; challenge/Time Attack target tuning; complete catalogue coverage and AI calibration. No fixture above is presented as owner benchmark data or proof of balanced difficulty.


Challenge and Time Attack now have five-stage per-track/profile roadmaps: target-time and countdown budgets scale through 130%, 115%, 100%, 90% and 80% of course baselines. Completed stages can be replayed; later stages unlock sequentially. These scales need driving balance. [Current rules and verification](verification/challenge-roadmaps.md).
