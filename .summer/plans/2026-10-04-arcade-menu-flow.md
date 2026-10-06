# Arcade menu flow

> Current-status notice — 6 October 2026: this document retains the original specification and dated checkpoints. Its starting-point tables, old menu/class counts and unchecked historical boxes are not current implementation status. Use [current build](../../docs/current-build.md) and [remaining work](../../docs/implementation-checklist.md) before executing any task. All five classes, named profiles, eight portraits, eleven courses and eight-car Quick/Freestyle are implemented. Tournament/Elimination expansion, solid finishers, performance and final balance remain open.
>
> Owner overrides: no preservation-only migrations for development scores/rewards; preserve identity/preferences, accepted geometry, sources/notices and failures. New tracks receive one Beach Buggy race on Hard (Freestyle if assigned class differs), not the old matrices or extra mode runs. Work inline, one course at a time. Audio/video are outside the eight-car work. The original full specification remains in the hash-verified documentation snapshot.

Implement inline, preserving existing race settings, controls, course geometry and buggy handling.

- Restore prominent beach-buggy artwork and create matching preview art for the five planned vehicle classes.
- Add mode → driver → vehicle preview → course stages, with keyboard/gamepad focus, back/next navigation and existing settings access.
- Apply the directional navigation gate in [development milestone 2a](2026-10-03-tabletop-glb-rollout.md#2a-make-menu-navigation-follow-the-visible-rows-and-columns): up/down moves between rows; left/right stays within horizontal rows, including row ends, with explicit focus neighbours and modal focus containment.
- Extend mode selection when [development milestone 8a](2026-10-03-tabletop-glb-rollout.md#8a-add-tournament-per-track-challenges-and-three-additional-racing-modes) lands: Tournament, per-track Challenges and the proposed Elimination, Time Attack and Drift Challenge modes, alongside existing Quick Race/Time Trial and planned Freestyle. These additions are planned, not part of the current two-mode implementation claim.
- Keep future classes preview-only; loading a course and starting a race use the buggy.
- Reuse the current driver cards, course selector and setup controls so their save and selection behaviour remains intact.
- Verify the full flow, future previews, course changes, race launch, returning to menu and modal settings in an isolated rendered instance. Preserve evidence and confirm its process exits.
