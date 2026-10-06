# Vehicle classes — implementation decisions

Current 6 October 2026: all five classes are implemented with imported visuals, animated wheels for four wheeled classes, controls, progression, Freestyle and recovery. Class/surface balance and owner benchmarks remain open. See [current animation](animated-vehicles-integration.md), [accepted exported defaults](verification/exported-tuning-defaults.md), [contact/recovery](vehicle-collision-recovery-profiles.md) and [eight-car scope](eight-car-experience-audit.md). The original implementation chronology below retains its evidence; the owner has replaced broad new-course class matrices with one Beach Buggy/Hard race.

- Use the currently accepted exported vehicle defaults and preserve canonical source geometry. Reuse its controller, recovery, progression and feedback owners; separate class definitions and visual construction.

- Monster truck: raised narrow body, large exposed tyres, stronger rough-surface traction, lower road speed. Racing car: low open-wheel silhouette, faster road pace, reduced rough-surface pace. Drift car: enclosed coupe, lower powered lateral grip with stronger coast grip for controllable slides. Speedboat: hull, cockpit, rudder/propeller and no road wheels.

- Standard races use a course's inspected assigned class. Course classification lives separately from canonical measured route resources. Freestyle exposes all five classes and all active courses.

- The selected class applies to all racers in a race. The player keeps that class's earned build; rivals use neutral tuning. This retains the existing difficulty model while keeping the class choice visible and comparable.

- Freestyle fallback is automatic and visibly labelled: land vehicles use underbody flotation on water at 55% of class speed; boats use powered skid assistance on land at 50%. These retain steering, braking, boost, ordered gates and recovery. They do not gain permission to cross missing physical support or skip checkpoints. Standard land vehicles still cannot drive water; standard boats require water.

- Collision and traffic clearance use class dimensions. New visuals must fit their collision envelope and clear their swept wheels; accepted route boundaries must never be widened to fit a vehicle.

- Ground support carries the wheels/skids while the collision box clears small surface seams. Use the buggy's accepted 0.07-unit clearance for the other classes: initial 0.03 clearance caught the physical foam-ramp entrance on Toys R You. Keep the full horizontal vehicle envelope and verify traversal after changing this value.

- Unspent points/Bling belong to each named profile wallet; purchased upgrades/cosmetics remain per vehicle. Driver identity/palette is independent of class. Current profile schema is 17.

- Records and ghosts include mode, actual class, stats and rules. Development records/rewards may reset or invalidate under the owner's policy; preservation-only migrations are not required. Session-only test builds remain session-only.

Historical archive review: the retained archive contains a motorcycle and four truck colours, with separate wheel meshes and a colormap. Its root EmacArt licence belongs to the water pack, and the Morbidember MIT notice does not establish the truck models' provenance. The new class visuals will use the existing procedural toy style and opening silhouettes rather than assuming these unscoped notices cover the archived models. No paid asset generation is needed.


## Supplied GLB vehicle integration (4 October 2026)

The five user-supplied files now provide the actual race and garage meshes: BeachBuggy = buggy, MonsterTruck = monster truck, RacingCar = racing car, DriftCar = drift car, and Sppedboat = speedboat (filename preserved). `imported_visual.gd` preserves textures and proportions, rotates their rendered front toward gameplay +X, centres each footprint and fits it within 94% of the class collision footprint. Handling/collision definitions are unchanged. Driver numbers, earned paint, brake feedback and Freestyle flotation/skids remain connected. Ghosts copy the imported hierarchy.

The original files contain fused meshes and approximately 484,000–500,000 triangles. Production now uses separately derived wheel meshes for the four wheeled classes, with independent steering/rolling. The speedboat remains a jet boat. Imports generate automatic LODs and shadow meshes. Original GLBs are preserved; see [animation integration](animated-vehicles-integration.md).

Rendered inspection: `tests/baselines/vehicles/imported03` captures both sides of all five models and checks footprint, ground placement, switching and garage paint. The child exited normally without runtime/shutdown errors. `imported01` retained an obscured capture fixture; `imported02` exposed reversed orientation and an intermittent shutdown resource warning. Failed evidence is preserved; corrected orientation is demonstrated by `imported03`.

All five classes subsequently passed four-car, one-lap neutral Hard races on Toys R You, with zero crashes, recoveries or penalties and clean child exits. Evidence: buggy in `imported-races01`; other four classes in `imported-races03`; consolidated `imported03/race-summary.json`. Contact counts remain comparable to the earlier handling runs. Initial monster truck runs in `imported-races01` and `imported-races02` completed gameplay but retained shutdown warnings. The dedicated drive probe now frees its disposable app and drains rendered frames before quitting. These tests do not establish independent wheel animation or meet the outstanding 16.7 ms frame-time target.
