# (not) THE REAL THING

The game uses the name and winged emblem from the owner's supplied tabletop-racing poster. A transparent logo reproduction is stored at `assets/brand/real_thing_logo.png`; the original reference is preserved at `assets/brand/real_thing_poster.png`.

Menus use navy, cyan, red, yellow and cream. The kitchen and miniature racers form the background, framed below the poster titles and above its promotional badges. The logo appears throughout the menu flow and on results, with the supplied homage tagline on the main screens. Setup and controls also carry the new name.

The project and window names are updated. The Windows user-data directory deliberately retains the existing `Godot/app_userdata/Room Run · Miniature Grand Prix` path so profiles, controls, records and unlocks survive the rename. `scripts/race/game_brand.gd` centralizes the visible name and shared assets.

The full rendered menu-flow probe also checks the project name, logo and save directory. Evidence is retained under `tests/evidence/real_thing_brand/`, including the failed save-directory checks.
