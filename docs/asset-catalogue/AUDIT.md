# Current installed asset inventory — 6 October 2026

Refreshed from the post-maintenance working tree. `inventory.csv` contains **2,245 source/support files**, **5,178,308,849 bytes** (about 4.82 GiB). This includes retained GLB sources and inactive/reference assets; it is not export size or unique-art count. There are 221 exact duplicate groups; duplication alone does not authorize source removal.

`summary.json` records source hashes, types, scope, dispositions and eleven active IDs. `manager-entries.json` is a generated machine-local Asset Manager input, excluded from Git. Run `python docs/asset-catalogue/audit_assets.py` to refresh; database registration is a separate editor action. No editor database rebuild was required for documentation cleanup.

| Disposition | Files | Meaning |
| --- | ---: | --- |
| current | 344 | Conservatively reachable from application/active-course source references |
| retain | 1414 | Original/derived game assets, authoring material and retained sources |
| tooling | 297 | Installed development support |
| defer | 190 | Optional/legacy installed material |

## Scope and reference limits

Included game resources, original/derived assets, retained GLB library and installed addons. Excluded Git/engine caches, local state/databases, builds, marketing captures/deliveries, archives, tests/replays, docs/tools and UID/import sidecars. Quoted resource parsing now preserves spaces in music filenames, avoiding false missing-audio reports.

Static references include authoring output paths and inactive branches; they do not establish execution. `summary.json` retains unresolved literal references to absent legacy 2D JSON files and procedural authoring outputs. Those are not missing eleven-course catalogue entries. Several retired courses retain recipes/baselines rather than complete active-directory resources; no restoration or fresh legacy-runtime claim is made. Dynamic paths still require relevant runtime acceptance.

## Preservation and licensing

Original models, textures, source-specific notices, source packs, canonical measured routes and failed evidence remain. Obsolete duplicates/build output were moved to a local quarantine after deletion review rejection; see [maintenance](../project-maintenance.md). Vendor native extensions held by the open editor remain intact.

The root CC0 document is historical owner context, not a blanket licence for imported models. Inventory rows retain scoped notice evidence; [credits](../credits.md) and adjacent source notices govern imported content. Existing rendered reports retain their original settings and limitations.
