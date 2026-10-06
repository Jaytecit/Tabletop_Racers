# Owner benchmarks

> Reconciled 6 October 2026. The benchmark capture framework is implemented. Actual final owner times and compatible repeated AI calibration remain outstanding. Development time/history preservation is optional under the owner policy; no immediate wipe is requested. See [current build](current-build.md) and [remaining work](implementation-checklist.md).

Implemented in Time Trial through the Owner Benchmark button on the course page. Turning it on locks three solo laps, the course-assigned class and neutral vehicle stats. Earned upgrades are preserved and restored when leaving the benchmark configuration. Upgrade rewards are disabled for these runs.

A completed ordered run is eligible only with human control, no contact, recovery, missed-gate warning or time penalty, and no stat-test build. The results offer an explicit Designate Owner Benchmark button after the held-input guard. No run becomes an owner benchmark automatically. A slower time cannot replace a faster compatible benchmark. Replacing a time preserves the previous record in history; changed route, environment collision, handling or rules produce a stale marker and a new comparison context. Driver, course, class, three-lap count, neutral stat code, timing, source signature and UTC designation data are stored in schema 12.

Current AI tuning remains provisional. No owner times have been collected during this implementation. Development AI and synthetic test times are not owner records. Owner driving should be requested after the final class/course balance is stable.

## Verification

`tests/baselines/modes/owner-benchmark01`: 6.158 seconds, all assertions passed, no runtime errors/frame warnings, PID 96400 exited. The fixture injects the read-only sentinel before setup, isolates hardware input, then writes only its own `synthetic-profile.json` inside the evidence directory. It verifies locked stats/laps/field, no upgrade rewards, explicit designation, held-input protection, actual disk reload, faster/slower replacement, retained history, stale context, AI/contact/recovery/gate/DNF rejection and restored earned stats outside benchmark mode. Locked setup and candidate-results frames were inspected. These synthetic fixtures are never calibration evidence.

`owner-benchmark02` adds three-size result layout/focus checks. `owner-benchmark03/04` passed functional assertions, including two distinct saved collision changes retiring a benchmark and restoration recovering the original signature, but leaked two instances/one resource at shutdown. The verbose diagnostic `05` did not reproduce that leak; it exposed existing external Vulkan overlay loader errors instead. `06` adds a render-frame drain before teardown and passes the same assertions with empty stderr (7.241s, PID 132784 exited). All failed raw evidence remains. Timing signatures now include the actual authored environment and stat-composition source; prior incompatible PBs remain preserved as legacy.

## Calibration acceptance still required

Before tuning, collect clean owner runs on each final course in this exact neutral three-lap configuration. Proposed finish-time bands are Easy 3-8% slower, Normal within 2%, and Hard 3-8% faster than the compatible owner benchmark. Confirm these margins against actual course/vehicle capabilities when owner data is available. Require repeated completed races, no invalid shortcuts, recorded recoveries/penalties and an observed finish-time spread no greater than 4% of the benchmark; failure requires further driving-rule work, not silently changing player physics. Freestyle combinations and Nightmare remain explicitly provisional unless independently covered.
