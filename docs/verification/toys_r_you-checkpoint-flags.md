# Toys R You checkpoint flags — 2026-10-03

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Rollout Task 2A adds runtime checkpoint cues without changing the accepted measurements, route resources, lap rules or imported scenery. The temporary route overlay remains enabled by default; flags have their own node and survive hiding that overlay.

## Placement

`track_builder.gd` shares the existing numbered pennant construction. Procedural placement and artwork remain unchanged. Imported courses use `imported_checkpoint_flags.gd`, which waits for physics registration, intersects each authoritative gate plane with the nearby measured boundary segments on its route layer, then checks local support and prop clearance.

The support ray is limited to 0.5 units above/below the measured edge height, so a lower checkpoint cannot attach to the bridge above it. Supported poles use the actual physics-hit height. Marker meshes have no collision. Pennants tilt toward the overhead camera; imported billboard numbers remain visible through scenery, including the lower deck.

- Gate 0 reuses the original castle START arch. The gameplay station is unchanged; the source artwork is a nearby visual cue, not an exact measurement of that station.
- Gates 1, 3, 4, 5 and 6 have paired flags on clear supported shoulders.
- Gate 2 uses one supported flag because the other shoulder is obstructed.
- Gate 7 uses one floating pennant/number at its own checkpoint plane below the ramp. No unsupported pole is drawn. The candidate must pass a separate collision-clearance check.

The shoulder offsets (0.45, 0.7, 1.0 units) are searched rather than unconditionally accepted. A floating fallback searches both sides at the same plane and records an error if no clear location exists. Each future course still requires its own rendered placement review and explicit decisions about existing source cues.

## Evidence

The rendered `tests/probes/toys_flags_verification.gd` checks station-plane alignment, numbering, layer identity, support height, prop clearance, absence of collision obstacles, all-gate coverage, three rebuilds, switching away/back, and labels with the temporary overlay hidden. It also exercises temporary bridge-deck gates in the disposable instance; those gates are never saved to the course resources.

Evidence directories under `tests/baselines/content/toys_r_you/`:

- `flags_run1/`: preserved failed probe. A reporting-key collision overwrote `switch_back` with marker records; the final assertion raised an error and the runner timed out. Earlier checks and frames remain available. This is not a passing run.
- `flags_run2/`: reporting fix and reuse of original start artwork; passed, but later visual review improved the shoulderless fallback.
- `flags_run3/`: floating-cue collision clearance passed.
- `flags_final/`: placement checks, 480 checkpoint cases, 6,960 containment cases, 456 Game Table and 192 Practice Patch polygon comparisons; Game Table also passed 912 inside and 912 outside edge cases. Includes a layer-1 approach ramp and layer-0 underpass test. Shutdown reported two ObjectDB leaks; no gameplay errors were captured.

- `flags_visibility/`: final code, passed with `finished=true`, no timeout, no captured gameplay errors or shutdown warnings. All marker checks above passed. The upper-deck test uses section 45 at approximately Y=2.844, while the underpass markers remain approximately Y=0. No collision bodies are introduced. All eight checkpoint close-ups, a bridge view, an overview with the overlay hidden, and a driving frame were inspected. Numbers remain readable when the flag mesh itself is behind source scenery; this is deliberate through-prop label rendering, not relocation to another deck.
- `flags_gameplay/`: four cars completed three laps on Hard in 132.69–138.47 seconds with zero crashes, recovery resets or penalties (ordinary impacts occurred). All 714 physical support samples and 480 checkpoint cases passed. Real throttle/boost moved the car about 7.4 units over 45 physics frames; recovery, pause/resume and switching away/back passed. Sampled FPS was 58–61 (mean 59.98), with 388 draw calls and 106,429 rendered triangles at the recorded driving sample. `finished=true`, `passed=true`, and no captured gameplay errors. Shutdown logged four ObjectDB leaks and one resource still in use, consistent with the previously documented probe shutdown issue. This run precedes only the final through-prop label visibility change; `flags_visibility` verifies that final presentation change separately.

All disposable test PIDs (60492, 26680, 103572, 85452, 66616 and 17892) exited. Failed and intermediate evidence remains intact. At this checkpoint Task 2A was complete for Toys R You and subsequent imports were pending. Current integration status is maintained in .summer/plans/2026-10-03-tabletop-glb-rollout.md. Its source file exists and its embedded attribution was inspected, but shared geometry has not been proven and no measurements were reused.

The baseline builder and SHA-256 hashes of Toys R You's accepted JSON, definition, entry and preview are preserved in `archive/checkpoint-flags-baseline/`. All four accepted resource hashes remained unchanged during implementation.

Runtime: Summer 4.7.2 stable Mono custom build, Vulkan Forward+, RTX 4060 Ti, 1200×800 project viewport. The editor MCP was unavailable (no API token); verification uses separate rendered `--summer-verify` processes with profile writes disabled and hardware controller input isolated. The user's editor is never stopped.
