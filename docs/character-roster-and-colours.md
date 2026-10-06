# Character roster and vehicle colours

Eight portraits have individual names and biographies in `scripts/profiles/character_catalog.gd`. Saved human names remain custom. AI names, portraits and biographies follow the same catalogue, with distinct consecutive identities after the selected human portrait. Existing skills remain unchanged.

| Character | Palette |
| --- | --- |
| Roxy Rocket | Rocket Red, #EF6546 |
| Finn Flywheel | Comet Blue, #4BA5C9 |
| Kit Spark | Spark Gold, #F1C44F |
| Bea Bolt | Bolt Green, #86BB5B |
| Nova Flux | Flux Violet, #A784EB |
| Ravi Ember | Ember Orange, #FF9833 |
| Skye Frost | Frost Cyan, #58D9EF |
| Milo Copper | Copper Magenta, #C85C94 |

Skye and Milo's jackets were regenerated in cyan and magenta, preserving their faces, hair, accessories and pixel-art composition. Original images remain available; the game uses `driver_6_cyan.png` and `driver_7_magenta.png`.

Choose a palette below Player Stats or in the Freestyle garage. The saved choice colours the actual vehicle body and ambient rear lights, plus minimap and standings markers. Brake lenses retain their bright red brake indication. The garage's illustrated vehicle artwork retains its original painted colour. Automatic mode uses equipped special paint/gold livery when applicable, otherwise the selected portrait's colour. Explicit palettes do not remove paint or gold unlocks. Profile schema 16 defaults older profiles to automatic mode.

## Verification

Rendered, hardware-isolated, read-only profile probe: `tests/evidence/character-roster-colours-03`. Passed eight identities, profile names/bios, palette selection and validation round-trip, all five vehicle bodies/rear lights, existing skills/unlocks, driving and AI podium identity. No runtime/shutdown errors; owned process 142256 exited normally. Screenshots include profile picker, Player Stats and garage. Failed first-run evidence is preserved: mock results omitted the required penalty field; its picker check also requested a garage step skipped by Quick Race.

## Eight-car current status

Quick Race/Freestyle support one human and seven AI, all eight identities, full-field standings, minimap, lighting and two-row results. Profile schema 17 retains the schema-16 palette feature. [Eight-car evidence](verification/eight-car-race.md) and [CPU tuning](verification/eight-car-tuning.md) describe accepted runs and measured limits. Tournament/Elimination expansion and solid post-finish run-out/parking remain [required work](eight-car-experience-audit.md).
