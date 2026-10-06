# Repository workflow

Canonical remote: [Jaytecit/Tabletop_Racers](https://github.com/Jaytecit/Tabletop_Racers), configured locally as `origin`. Use this repository for future changes. The initial snapshot preserves the current build; subsequent work should use focused `codex/` branches and reviewable commits.

## Clone and open

Install Git and Git LFS, then:

```powershell
git lfs install
git clone https://github.com/Jaytecit/Tabletop_Racers.git
Set-Location Tabletop_Racers
git lfs pull
```

Open `project.godot` in Summer Engine and run the application scene. Binary assets use LFS pointers in Git; a source ZIP downloaded from GitHub may require separate LFS retrieval. Do not commit generated `.godot` caches, `.import` sidecars, local engine state, private profile data or export credentials. `.gd.uid` sidecars are source identity and remain versioned. The existing Windows export preset is a loading benchmark, not a general release pipeline; its custom-template paths are machine-specific.

## What is versioned

Runtime code/scenes/resources, original and derived game assets, retained GLB source library, installed addon files/notices, extraction and verification tools/probes, current documentation, and documentation snapshots. Large binary assets are tracked through `.gitattributes` using Git LFS. Source-specific notices still apply; the root CC0 file does not replace imported asset licences.

## Local-only material

`tests/baselines/`, `tests/evidence/`, marketing captures/deliveries, archive packs/backups, builds, Asset Manager's local database and local Summer state are excluded from ordinary Git commits. They remain on disk, including failures. Documentation history ZIPs are explicit exceptions under `archive/`.

Historical evidence links refer to this working machine's retained directories; cloning alone does not recreate those reports/media or historical rendering inputs. Back these directories up separately before moving machines or deleting a checkout. Git is the source-of-truth for future source changes, not a replacement for the local evidence/source-pack archive. Reusable probes and instructions remain in Git.

Absolute-path Asset Manager entries are generated locally by `python docs/asset-catalogue/audit_assets.py` and are excluded from Git. Rebuild engine imports locally. Do not regenerate or delete caches belonging to a running editor during routine cleanup.

## Working and verification

Read `AGENTS.md`, [current build](current-build.md) and [implementation checklist](implementation-checklist.md). Work inline and one course at a time. Update affected current documentation when code changes; retain historical test measurements rather than rewriting them as fresh passes.

Run `python tools/project_audit.py` for documentation classification, local links and current-build consistency. Refresh the asset inventory when sources/resources change. Run only relevant gameplay tests: isolated rendered instances, read-only profiles and hardware-input isolation; preserve failed results and confirm owned PIDs exit. Never stop the owner's editor/game as cleanup.
