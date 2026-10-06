# Eight-car experience audit — 6 October 2026

Scope: one human and zero to seven AI, at most eight cars total. Audio and video assets/presentation are excluded. This is a source audit and implementation checklist, not a new runtime acceptance report. No gameplay code changed. Existing owner acceptance of the eight-car race is retained.

> Policy correction, 6 October: the owner's 5 October development-persistence override removes preservation-only migrations for scores, series/rewards and upgrades. This audit now follows that policy. No immediate wipe or gameplay implementation is requested by the documentation cleanup.

## Conclusion

Quick Race and Freestyle already support eight cars. Making the whole competitive experience support eight requires expanding tournament rules/persistence, enabling larger elimination fields, completing development controls, and replacing stationary ghost finishers with a separate physical post-finish state. Solo modes should retain their intended rules. Named identity/preferences must remain valid. The owner permits development series, records and rewards to reset/invalidate; preservation-only migrations are not required.

## Required changes

| Area | Current evidence | Required work |
| --- | --- | --- |
| Shared field configuration | `scripts/race/race_presentation.gd:879–884` permits seven rivals only in Quick/Freestyle, caps other modes at three and forces tournaments/cups to four cars. | Define the maximum field once and mode-specific field policies. Allow 2–8 in Elimination and the chosen tournament field policy. Preserve solo/practice modes and Nightmare's minimum of three rivals. Do not blindly replace every literal four. |
| Tournament field | `scripts/race/tournament_rules.gd` saves driver and rounds, but no field size or entrant roster; validates round rows through the legacy four-car cup rules. | Store a stable field size and roster for the entire series. If variable-size tournaments are offered, lock the selection on series start/resume. Instantiate/configure that field instead of forcing four. Keep saved-series identity consistent across rounds and reloads. |
| Tournament scoring | `scripts/race/cup_rules.gd:8,16,23,37` has four scores, exactly four rows, IDs 1–4 and four totals. Active tournament rules delegate here. | Introduce field-aware active tournament validation and standings; check unique IDs, complete roster, rank order and DNF handling. Adopt an explicit eight-place scoring table. The session currently uses 10/6/4/2/1/0/0/0, which could preserve old top-four values, but is not an approved tournament balance decision. |
| Save compatibility | Tournament version is `tour-v1`; retained Casino Cup uses `casino_v1`. | Version the expanded tournament state and validate field/roster. Old four-car development series may reset/invalidate with clear UI rather than requiring preservation-only migration. Retain legacy cup code/source separately; do not expand its validator globally just to serve active tournaments. Preserve named identity/preferences; change the profile schema only when the new fields need it. |
| Tournament menus/results | `tournament_controller.gd:79–80` advertises four scores; its totals are concatenated into a single text line. Its course page hides the QuickRace selector. | Show selected/locked entrant count, scoring and series standings for up to eight; provide a field control if variable sizes are desired. Check long names, summary/banner wrapping, gamepad focus, resume, abandonment, final rewards and duplicate-award protection. Ordinary eight-tile race results already exist. |
| Elimination setup | `race_presentation.gd:879,936–940` caps three rivals and disables higher options. | Permit 1–7 rivals. Existing lap count derives from field size and `elimination_rules.gd` works over dynamic IDs; retain elimination at leader laps 2 onward, yielding a winner at lap eight for an eight-car field. Verify rather than rewrite the core rule. |
| Development controls | `scripts/race/developer_menu.gd:6` exposes only `ai_1`, `ai_2`, `ai_3`; `developer_tuning.gd:90–93` already resolves any valid AI slot. | Expose AI 4–7, preferably from the instantiated roster. Verify targeting, tuning/reset/export and navigation for all seven AI. All-AI targeting already uses the full roster. |
| Finished-car lifecycle | `race_session.gd:119–122` sets both collision fields to zero; `arcade_car.gd:220–223,240` stops finishers. | Add non-scoring run-out/parking states with active physical collision and support. Freeze authoritative finish time, rank, lap/legal progress, penalties, PB/ghost/rewards at the crossing. Continue movement independently of race-progress observation. See design below. |
| Traffic and recovery | `ai_driver.gd:74,99` and `race_recovery.gd:5` explicitly ignore finished cars. | Make physically present run-out/parked cars visible to obstacle avoidance and recovery occupancy, while excluding them from competitive targeting. Recovery must never place a car inside a solid finisher. Keep layer/height separation. |
| Copy and documentation | Nightmare tooltip says exactly three rivals (`arcade_presentation.gd:156`); AI comment describes only the fourth car; mode documentation describes 2–4 elimination entrants. | Update to minimum-three/seven-maximum rivals, two Nightmare attackers with the remaining AI racing normally, expanded modes, save/scoring rules and post-finish behaviour. Update implementation/evidence documents only after verification. |

## Finished AI: keep solid and clear the racing line

The reported penetration is intentional current logic, not a collision-shape failure: finishing clears collision and terminal guards stop the car at the crossing. Re-enabling collision alone would make a stationary obstacle on the finish line.

Recommended behaviour:

1. Record the result once at the actual finish-plane crossing. Transition to **run-out**, retaining velocity, surface support and normal solid collision.
2. Use a dedicated gentle driving policy: no boost, attacks, competitive overtakes or checkpoint accounting. Continue beyond the line and follow a validated route to an allocated parking slot outside the active racing corridor.
3. Brake only when clear of the line and approach; park as a solid obstacle. Give every entrant its own slot, sized for the actual vehicle collision footprint. Track occupied/reserved slots.
4. Use measured support heights and normals plus collision clearance for both the route and slot. Do not use a fixed lateral offset from the centreline: shoulders may be unsupported, walls may intervene, and raised decks or water require different handling.
5. If no safe exit/slot is available, keep the finisher driving the circuit with collision and non-scoring progress until one becomes available. This avoids stopping on the line, but does **not** guarantee zero traffic interference; guaranteed clearance requires a course-specific exit/parking provision.

This needs a controller/state boundary in the vehicle physics, not just a new AI command: the current terminal guards prevent all movement after finishing. Handle the tick in which the finish is detected as well as subsequent ticks. Parked-body impact handling needs an explicit policy because `resolve_impact()` currently applies velocity to any CharacterBody3D. Prevent impacts from pushing parked cars back onto the track or creating misleading hidden velocity.

Apply the same lifecycle to the human car under automatic control after finishing; otherwise it remains a separate stationary ghost. Keep elimination's hidden removed bodies separate from ordinary finishers. No new audio/video is necessary.

Reset/resume requirements: clear allocations and post-finish state on retry, menu return, course/vehicle change and roster shrink; restore normal collision/input on restart. Pause must freeze run-out movement. Results may arrive before parking completes, so choose whether movement continues behind results or freezes only after cars are clear. Preserve results timing, the existing 20-second human-finish window, PB capture, camera behaviour and celebration placement. Test missed-gate timers at finish: `session.tick()` currently iterates all records, so pending penalties/crash callbacks must not change a classified finisher or strand its run-out.

## Already supports eight; preserve and verify

- Four extra cars are instantiated in `race_presentation.gd:107–116`; names are resized to the roster. Active/inactive bodies are configured separately.
- Eight distinct portraits, names and colours exist in `scripts/profiles/character_catalog.gd`. Identity, paint, labels and lighting iterate the full roster.
- Grid reset uses dynamic car count and vehicle dimensions. Progress/rank records are keyed by entrant ID, not a four-element array.
- HUD standings iterate all cars; minimap iterates the active field; `arcade_podium.gd` provides two rows for fields above four.
- Profile schema 17 accepts 0–7 rivals; record namespaces include rival count and validate it through seven. Ordinary record separation needs no broad rewrite.
- Player input and camera intentionally serve one human. No split-screen, networking, extra device binding or eight-profile management is required.
- The four garage stat-build choices, four difficulty presets, four feedback messages, four confetti emitters and four wheels are not entrant limits. Character selection already offers all eight portraits; saved `driver` 0–3 is a stat-build choice, not portrait count.
- Time Trial, Challenge, Time Attack, Drift and practice remain solo by design. Expanding them into pack racing would be a different rules change.
- Course capability restrictions must remain intact; field expansion does not authorize untested modes on courses such as Town Square.

## Verification and remaining acceptance work

Existing evidence: `docs/verification/eight-car-race.md` and `eight-car-tuning.md` cover the eight-car Moonlight full race, setup/retry, result bounds, profile/record validation and an eleven-course early-race performance survey. The survey is not full-race acceptance of every course/vehicle/mode. The tuned full-race wall-frame p95 was 21.768 ms; a sustained 60 FPS p95 target remains unmet. The owner's successful interactive race is additional acceptance, not a reason to repeat the accepted baseline unnecessarily.

Required targeted verification after implementation:

- Configuration at field sizes 1–8 where legal; eight-to-four-to-solo-to-eight transitions; pause/retry/menu/loading and input restoration. Test smallest and largest fields plus intermediate sizes for layout/configuration; avoid multiplying full-race matrices.
- Tournament rule tests: 2–8 entrants if supported, scoring/ties/DNFs, invalid/duplicate IDs, incomplete roster, unchanged field across rounds, actual save/reload, safe old-series reset/invalidation or optional migration, identity/preferences preservation, and winner/reward idempotence.
- Elimination rule tests: dynamic ordering and exactly seven removals for eight entrants; early human removal/spectating; final-survivor results, lap count, isolated record keys and retry.
- Developer target tests for all seven AI; ensure all-AI and vehicle-class exports cover extra bodies.
- Finished-car reproduction before/after: crossing fixes time once; cars move clear, stay solid, avoid one another, never count further laps/penalties, never obstruct recovery spawns, respect pause, and restart with normal input/collision. Exercise staggered and near-simultaneous finishes, human first/last/DNF, blocked parking and unsupported exits. Verify actual contact against run-out and parked cars, not merely collision flags.
- Validate all course parking/run-out geometry and class-dependent footprint/support, including raised/narrow sections and speedboat water. Course-specific geometry work must follow the tabletop extraction guidance and preserve canonical Toys R You measurements.
- For any new-track acceptance, follow the owner's current rule: one Beach Buggy race on Hard, Freestyle only when needed to preserve the assigned class. Keep separately untested additional modes disabled. Eight-car tournament/elimination coverage is a separate expansion acceptance task, not permission to repeat the retired vehicle/difficulty matrices.
- Rendered layout acceptance at supported window sizes with eight long names, DNF/penalty tiles and tournament summaries. Compare performance using the same settings/field, including post-finish movement; optimize only measured remaining costs.
- All rendered tests use owned isolated processes, read-only profiles and hardware-input isolation. Preserve failures and confirm each owned process exits without touching the user's editor.

## Suggested implementation order

1. Shared field policy and development targets; keep existing accepted Quick/Freestyle behaviour.
2. Tournament state/scoring versioning and menus, then Elimination setup/rule acceptance.
3. Physical post-finish lifecycle and traffic/recovery integration; author safe course exits/parking one course at a time.
4. Targeted mode, persistence, rendered and performance acceptance; update release-facing documentation.

Method: targeted reads/searches of active app/race/vehicle/profile/course-capability code and existing eight-car evidence. Legacy demos, archived copies, third-party addons, audio and video were excluded. A skills.sh method search reinforced targeted subsystem inspection and distinguishing source evidence from executed verification; no external skill or delegated review was installed/run.
