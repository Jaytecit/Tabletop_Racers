# Course preview and Start layout — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

The Start button now shares the track selector's 474-unit width and horizontal centre, beneath the course description. This accommodates the longer Elimination and Tournament labels inside the main panel. Time Trial's owner benchmark toggle occupies the left column above the footer, avoiding the widened Start button.

The track preview no longer creates or recolours a duplicate vehicle. The separate vehicle artwork remains in the vehicle column. Its camera frames a supported section near the selected course's start, using the local road width and direction, rather than fitting the entire model. The miniature route map remains visible. Imported model geometry, route measurements, collision and vehicle handling are unchanged.

`tests/probes/course_preview_layout_verification.gd` checks all eight mode layouts, Start/selector centring, control containment and overlap, clearance beneath course text, absence of preview vehicles and driver labels, close framing and actual Start Elimination activation. It checks Mount Rainier at 960x640, 1280x720 and 1920x1080 with pixelation both enabled and disabled. Captures include Mount Rainier, Toys R You and Roulette Grand Prix; Tournament and Drift retain their automatic course-selection rules.

Evidence is in `tests/baselines/development/`:

- `course-preview-layout01`: failed; revealed the benchmark-toggle overlap and test selections rejected after Drift restricted the course. Retained intact.
- `course-preview-layout02`: assertions passed, but Tournament changed the course behind some course-labelled captures. Retained; the final probe explicitly restores free-selection courses after mode changes.
- `course-preview-layout03`: final run passed with no captured errors, frame warnings or shutdown errors. Final course captures were inspected. PID 41412 exited with code 0; PIDs 65164 and 15456 also exited. Profiles were read-only and hardware input isolated throughout.

Summer diagnostics report zero errors and three pre-existing warnings. Legacy vehicle probes now expect no track-preview vehicle; driving-car livery checks remain. This is menu verification, not a new claim about race physics or course acceptance.
