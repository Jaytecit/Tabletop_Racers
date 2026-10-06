# Bazaar route projection cache — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Continues Bazaar's performance gate; this does not register the staged course or close final acceptance.

`showcase_track.gd` now caches each sampled segment's X/Z origin, vector and squared-length denominator, plus each corridor polygon's triangulation and edge heights. Queries retain the same candidate order, station window, layer checks, containment and interpolation arithmetic. Section-neighbour values are calculated once per query. Rebuilds replace all cached inputs; `SelectedCourse` transfers them with the validated route. An already running instance can lazily populate new fields after a script reload. The caches scale with route samples and retain no query history.

The original implementation is retained at `tests/fixtures/track_projection_before_cache.gd` (SHA-256 `d5baafd5741dfc7b3ff6626e7d214f6609054f76f88d091a33c07c57e08d51bf`). No source model, measured boundary, route resource, collision or vehicle tuning was edited. Time Trial maps only the exact verified cache revision to this preceding source hash; later edits still invalidate comparisons.

## Numerical evidence

`tests/probes/route_projection_parity.gd` compares all returned query fields exactly against the saved implementation. It covers every sampled span at five across-road fractions, seeded off-road and wrong-height points, broad searches, varied station windows, route wrapping, all nine active courses and staged Bazaar, plus rebuilds and staged/procedural selection transfer. The second run also clears caches to simulate an existing instance reloading the script.

Both `projection-parity01` and `projection-parity02` pass 74,508 comparisons with no captured errors, frame warnings or shutdown errors. Toys R You additionally passes 6,960 canonical alignment checks with zero boundary discrepancy. Final benchmark: 8,880 Bazaar queries take 1.541139s original / 1.180046s cached (23.4% less). This is a CPU query benchmark, not an FPS claim. PIDs 21840 and 119368 exited with code 0 and no forced stop.

## Preserved intermediate race evidence

All paths are under `tests/baselines/content/bazaar/`. Instances use the read-only sentinel and hardware-input isolation. The user's editor was not stopped.

- `projection-before04`: four Hard/three-lap buggies repeat the previous finish times exactly (73.194097 / 70.938217 / 74.800090 / 73.853366s), with contacts 3/0/2/6 and no crashes/recoveries/penalties. The run is failed because its default expected source hashes predate the current vehicle/track implementation, and MP3 playback leaks at shutdown. Query cost is 7.276920s / 35,451 calls; wall-frame p50/p95/max 12.652/29.223/53.080ms. PID 87488 exited.
- `projection-after04`: initial cache repeats the same finish times and contacts, and all gameplay assertions pass. Query cost is 5.663021s / 35,451 calls (22.2% less); measured-height cost falls from 0.530452s to 0.164202s. Wall-frame p50/p95/max 13.765/29.109/48.266ms; physics p50/p95 4.732/17.854ms. This run remains failed: verbose Vulkan validation reports missing installed Epic overlay manifests, and shutdown retains the MP3 leak. Verbose output identifies `menu_pulsing.mp3` and its playback object. PID 92736 exited.

The staged probe now stops audio and settles before shutdown, matching existing numerical probes. No system Vulkan configuration was changed. Final verification uses current expected source hashes and ordinary engine logging. Intermediate failures remain intact. Overview and Close Chase recovery frames were inspected; the course retains the source barriers, timing artwork and supported road without generated edge artwork.

Final race evidence and remaining acceptance are recorded in [Bazaar verification](bazaar.md). The independent 16.7ms wall-frame p95 goal, other classes, loading/menu integration and catalogue registration remain separate gates.
