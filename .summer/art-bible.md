# Art direction — (not) THE REAL THING

Reconciled 6 October 2026; see [current build](../docs/current-build.md). The game combines miniature arcade driving, a pixelated 3D world and crisp, readable HUD/menu artwork. Current course scope is [recorded here](plans/2026-10-03-tabletop-glb-rollout.md).

## Presentation

Preserve current Chase/Overhead/Close Chase selection, high Chase default, road-course panorama perspective framing, accepted handling defaults and the 600×400 world pixel option. Historical size-14 orthographic descriptions are not a requirement to undo the current camera implementation. The effect changes presentation, not underlying render cost. Keep HUD text legible at 720p and 1080p. The owner-approved 4 October menu treatment uses saturated royal blue/indigo panels, cyan outlines, yellow selections, pink focus accents and white lettering. Buttons and panels have rounded corners. The main menu has a centred, padded logo, compact two-column mode buttons and the existing buggy artwork. Settings, controls, upgrades, credits and race overlays share these tokens. Original driver portraits and vehicle cards remain game art; course previews must represent their actual selected environment.

Imported GLBs provide the scenery, baked materials and visible road identity. Preserve these and judge changes through the real game camera. Use model-derived geometry, physically supported checkpoint flags and coherent layer placement. Temporary route diagnostics are disabled; permanent generated road edges are not requested. Roulette remains the active procedural tabletop environment; unrelated kitchen/bedroom/course expansion briefs are archived.

## Visual priorities

- Playful miniature scale, distinct vehicle silhouettes and oversized everyday landmarks.
- Surface/prop identity follows each course's environment; avoid mixing unrelated theme kits.
- Maintain contrast between cars, driving surfaces, cues and background texture.
- Checkpoint numbers, minimap and recovery feedback stay readable through scenery.
- Pool effects and keep smoke/dust/sparks from obscuring the next turn.
- Preserve warm key/fill lighting on procedural work; do not replace imported baked lighting without rendered evidence.

## Shared colours

| Role | Colours |
|---|---|
| Menu ink / purple / blue | #100E35 / #281369 / #454FFF |
| Selection / paper | #FFE500 / #FFF0CF |
| Character palettes | #EF6546 / #4BA5C9 / #F1C44F / #86BB5B / #A784EB / #FF9833 / #58D9EF / #C85C94 |

Colour identifiers also need shape/number cues. Keep optional shake/flash effects restrained. Render/lighting changes require before/after live frames and measured timing.

The owner's saved Micro Machines images and DOS inventory under [docs/art-reference](../docs/art-reference/README.md) are study references for scale, composition and palette. Original executable data and extracted sprites are excluded from production art. Earlier casino overhaul and expansion notes are historical, preserved in `archive/documentation-before-cleanup.zip`.
