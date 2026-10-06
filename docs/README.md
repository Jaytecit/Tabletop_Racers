# Documentation index

Reconciled **6 October 2026** against the inspected build. Start with [current build](current-build.md) and [remaining work](implementation-checklist.md). Source inspection is not a new gameplay pass. Historical reports keep their original settings, measurements and failures.

## Current guidance

- [Project overview](../README.md), [repository workflow](repository-workflow.md) and [maintenance record](project-maintenance.md)
- [Eight-car expansion and solid finishers](eight-car-experience-audit.md)
- [Developer baseline layers and tuning workflow](developer-tuning.md), [rendered verification](verification/layered-developer-baselines.md)
- [Course catalogue](../tracks/README.md), [rollout priorities](../.summer/plans/2026-10-03-tabletop-glb-rollout.md), [authoring](../tracks/AUTHORING.md)
- [Extraction gates](tabletop-track-extraction-guide.md), [dedicated-road extraction](automated-road-extraction.md), [reference-tool limits](../tools/tabletop_reference/README.md)
- [Source survey](glb-track-usability-audit.md), [disposition register](glb-track-disposition.md), [asset inventory](asset-catalogue/AUDIT.md), [credits](credits.md)
- [Vehicle classes](vehicle-classes.md), [animated wheels](animated-vehicles-integration.md), [progression](vehicle-progression.md), [contact/recovery](vehicle-collision-recovery-profiles.md)
- [Character roster and palettes](character-roster-and-colours.md), [gamepad name entry](gamepad-driver-name-entry.md), [menu flow](arcade-menu-flow.md), [mode rules](racing-modes.md)
- [Opening](opening-sequence.md), [brand](game-brand.md), [art direction](../.summer/art-bible.md), [study references](art-reference/README.md), [owner benchmarks](owner-benchmarks.md)

## Shared implementation evidence

- [Eight-car race](verification/eight-car-race.md) and [CPU tuning](verification/eight-car-tuning.md)
- [Saved profiles](verification/saved-player-profiles.md), [selection flow](verification/menu-selection-flow.md), [navigation](verification/menu-navigation.md)
- [Player stats](verification/player-stats.md), [developer overrides](verification/developer-tuning-overrides.md), [menu/export](verification/developer-menu-export.md), [accepted defaults](verification/exported-tuning-defaults.md)
- [Requirements 2.22.23](verification/requirements-2.22.23.md), [challenge roadmaps](verification/challenge-roadmaps.md), [capability gates](verification/course-capabilities.md)
- [Vehicle classes](verification/vehicle-classes.md), [vehicle effects](verification/vehicle-effects.md), [baseline tuning](verification/vehicle-baseline-tuning.md)
- [Camera/setup/panels](verification/development-panels-setup-camera.md), [quality rollout](verification/race-quality-course-rollout.md), [loading](verification/course-loading.md), [preview layout](verification/course-preview-layout.md), [bedroom framing](verification/bedroom-presentation.md)
- [Theme opening](verification/theme-opening.md), [Jaylabs ident](verification/jaylabs-opening.md), [menu music](verification/menu-music.md), [retro UI](verification/retro-ui.md)

## Course evidence

- [Toys R You canonical alignment](toys-r-you-integration.md), [flags](verification/toys_r_you-checkpoint-flags.md), [race quality](verification/toys-r-you-race-quality.md)
- [Toys R Asleep](verification/toys_r_asleep.md), [Rusty Nuts Workshop](verification/rusty_nuts_workshop.md), [Moonlight Junk Heap](verification/moonlight_junk_heap.md)
- [Firefly BBQ](verification/firefly_bbq.md), [Nighttime Noodles](verification/nighttime_noodles.md), [Mount Rainier](verification/mount_rainier.md), [Rainier ground](verification/mount-rainier-ground.md), [Topspeed Oval](verification/topspeed_oval.md)
- [Bazaar](verification/bazaar.md), [registration](verification/bazaar-registration.md), [classes](verification/bazaar-vehicle-classes.md), [loading](verification/bazaar-loading-menu.md), [projection cache](verification/bazaar-projection-cache.md), [Drift](verification/bazaar-drift.md)
- [Town Square](verification/town_square.md)

## Retained specifications and audit

The dated [quality](../.summer/plans/2026-10-04-race-quality-toys-r-you.md), [menu](../.summer/plans/2026-10-04-arcade-menu-flow.md) and [profiles/tuning/tracks/effects](../.summer/plans/2026-10-05-profiles-tuning-tracks-effects.md) documents retain original requirements and historical checkboxes. Their current-status notices and the implementation checklist take precedence over stale starting-point descriptions. Owner policy overrides replace old preservation-only migrations and broad new-track race matrices.

[Documentation audit CSV](documentation-audit.csv) records per-file disposition; `python tools/project_audit.py` checks local links and build consistency. Raw runs remain local under `tests/baselines/` and `tests/evidence/`, including failures. Vendor documentation, licences and study references retain their source meaning. Pre-maintenance documents are hash-verified in `archive/documentation-before-maintenance-20261006.zip`; the earlier cleanup snapshot remains separate.
