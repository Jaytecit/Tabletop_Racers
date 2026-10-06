# Project guidance

For imported tabletop GLB tracks, read these before editing:

1. [Accepted Toys R You result](docs/toys-r-you-integration.md).
2. [Required extraction method and validation gates](docs/tabletop-track-extraction-guide.md).
3. [Remaining tabletop rollout plan](.summer/plans/2026-10-03-tabletop-glb-rollout.md).
4. [Preserved extraction examples and their limitations](tools/tabletop_reference/README.md).

Derive independent route boundaries and heights from the model. A screenshot-traced centreline with fixed width is not an accepted final route. Preserve the canonical Toys R You measurements and existing procedural courses.

Checkpoint flags are requested where relevant, using actual checkpoint planes and measured surface geometry. Permanent generated road edges are not requested; the current coloured route overlay is temporary.

Work inline, one course at a time. Do not use subagents or repeat unrelated checks. Keep updates concise and preserve failed verification evidence.

Use isolated rendered test instances with read-only profiles and hardware-input isolation. Stop each test instance when finished, and verify its process has exited; an offscreen game can survive an editor crash. Never stop the user's editor or another project while cleaning up a test.

## New-track race verification — owner update, 5 October 2026

For each new track, test one Beach Buggy race on Hard only. Use Freestyle when the standard assigned class differs, without changing that assignment. This replaces prior per-track vehicle, stat-build and difficulty matrices and additional mode race runs. Retain source/corridor topology, height/support, checkpoint/flag, relevant control/menu/loading checks, failure evidence and isolated-process cleanup. Untested additional mode capabilities remain disabled until separately requested.
