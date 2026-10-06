# Project maintenance — 6 October 2026

Reconciled project documentation with the inspected v2.22.23 build: eleven courses, five implemented classes, eight identities, schema 17, and eight-car Quick Race/Freestyle. [Current build](current-build.md), [implementation coverage](implementation-checklist.md) and [eight-car audit](eight-car-experience-audit.md) distinguish implemented features from tournament/elimination expansion, solid finishers, performance and balance work.

## Documentation reconciliation

- Updated the root overview, index, course catalogue/authoring, menu flow, opening chronology, class/progression/identity notes and art direction. Corrected the eight-car audit to follow the owner's development reset policy rather than requiring preservation-only migrations.
- Retained dated plans and their complete detailed requirements, adding current-status/owner-policy overrides. Historical verification reports preserve their original counts, settings, failures and measurements, with links to current status.
- Classified all documentation in [the audit CSV](documentation-audit.csv). The [audit summary](documentation-audit-summary.json) checks current local links, eleven catalogue rows, schema and eight-car/pending-finisher claims. Source attribution, vendor documents and study material retain their original meaning.
- Hash-verified 93 pre-maintenance Markdown documents in `archive/documentation-before-maintenance-20261006.zip` with its adjacent manifest. The original earlier cleanup archive is retained separately.

## Workspace cleanup

[The cleanup manifest](maintenance-cleanup-20261006.json) records 72 obsolete files totalling **1,962,702,380 bytes** (about 1.83 GiB): disposable loading export, Python bytecode caches, duplicate settings backup, an unpacked clip-package copy and two byte-identical promo aliases. Every duplicate/package entry was verified against its retained canonical source or ZIP before moving.

Automatic approval review rejected both bulk and explicit-path deletion commands with `blocked by policy`. Therefore files were **archived, not permanently deleted**, under `archive/maintenance-quarantine-20261006/`. Active folders are tidied; no disk space was reclaimed. Permanent removal remains a manual follow-up. No alternative deletion mechanism was used.

Original source models/textures/audio/video, accepted geometry, canonical promo, packaged clips, reusable raw captures, all failed evidence and prior archives remain. The owner's editor and interactive eight-car game were not stopped. Runtime code/scenes/resources and audio/video contents were not changed by this maintenance.

## Repository

Configured `origin` to [Jaytecit/Tabletop_Racers](https://github.com/Jaytecit/Tabletop_Racers), with Git LFS for binary sources/resources. [Repository workflow](repository-workflow.md) documents source versioning and local-only caches, raw evidence, archive packs and marketing material. Documentation snapshots are explicit archive exceptions. LFS is required to obtain complete assets after cloning.

The existing export preset is a machine-specific loading benchmark. Several retired procedural entries and old 2D JSON circuits are absent from the active tracks directory; preserved recipes/baselines do not prove those legacy builds are runnable. No restoration was performed. The active catalogue remains eleven courses.

## Verification scope

This task performs documentation/build-constant consistency, local link checks, asset/reference inventory, duplicate/source-package hash verification and repository/LFS checks. It does not repeat gameplay acceptance or manufacture clean results for historical failures. No new race or release-performance claim is made.

Method discovery consulted skills.sh documentation-audit and cleanup guidance: compare claims with code, inventory before mutation, and retain source/evidence distinctions. No external skills or subagents were installed/run.

## Historical cleanup record — 3 October 2026

The record below describes the then-nine-course build and its actual checks. Later current status above takes precedence.


The game now exposes nine courses: Roulette Grand Prix plus the six active imported Tabletop Racing courses, Mount Rainier and Topspeed Oval. Other procedural courses, Beach Buggies, Casino Cup and the 2D build are preserved in the project but unavailable from the game menu.

## Changes

- The catalogue supplies both IDs and titles to the menu. Removed courses fail catalogue loading.
- Profile validation accepts current GLB selections and records. Retired selections fall back to Roulette, and saved Cup mode falls back to Quick Race. Historical records, cup progress, trophies and earned gold livery remain valid data.
- Casino Cup and the 2D return button are absent from the production menu. Cup rules and the original 2D scene remain development material.
- Replaced the unrelated vendor root README with the project overview; consolidated current instructions into the documentation index and course-status record. Superseded plans/art briefs and pre-cleanup documentation are verified in `archive/documentation-before-cleanup.zip`.
- Unused imported demo packs, vehicle simulation scripts and disabled addons are preserved in `archive/source-packs/unused-imports.zip`. Its manifest records all 2,217 original files, byte sizes and SHA-256 hashes; every archived entry was verified before source removal. Rapier2D and Terrain3D remain complete on disk because their native extensions are loaded by the open editor. The manifest distinguishes retained from removed roots.
- Archives and test baselines are excluded from engine scanning to keep historical script/resource copies out of the working filesystem.
- Moved macOS extraction metadata and the stale root settings backup into `archive/extraction-metadata/` after automatic approval review blocked shell deletion. No editor was stopped.
- Relocated unused vendor scenes to `archive/source-packs/scene-demos/`, preserving hashes and original relative paths. This also removes their stale references to archived demo dependencies and a case-mismatched `Scenes/world.gd` warning from the working scene hierarchy.
- Retained source-specific licences, canonical measured routes, source GLBs, retired course resources and raw failed verification evidence. Root runtime scripts and saved resource paths remain stable.

## Verification

The disposable rendered probe `tests/probes/catalogue_cleanup_verification.gd` checks nine menu entries/titles, selection through menu signals, route validation, Quick Race and Time Trial starts on every course, retired-ID rejection, legacy profile migration, preserved historical records/rewards and an evidence-only profile save/reload.

Result: `passed=true`, `finished=true`, no failed assertions, captured errors or frame warnings. Ten rendered menu frames are retained in `tests/baselines/maintenance/2026-10-03-catalogue-cleanup/`, alongside raw results/logs. Test PID 22404 exited; the user's editor was not stopped. Engine diagnostics recorded zero observed errors/warnings.

The final asset database rebuild verified 2,016 files and exited with code 0, no boot warnings and no script errors. The earlier case-mismatch warning and final clean rebuild results are preserved beside the rendered probe evidence. Current-document link checks found no broken local links; static application/active-course tracing found no missing literal resource paths.

This cleanup did not change driving geometry/physics and did not repeat full-lap acceptance races. Existing per-course gameplay evidence remains linked from [the documentation index](README.md). Historical reports describe their original versions/settings, including then-active overlays and menus.

The [documentation audit CSV](documentation-audit.csv) classifies current project documentation, source attribution, vendor documentation and historical evidence. `python tools/project_audit.py` refreshes it and checks local links in current documents. Asset inventory and source notices are refreshed under [asset-catalogue](asset-catalogue/AUDIT.md).
