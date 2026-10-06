# Course catalogue

The production game uses 3D resource entries at `tracks/<id>/entry.tres`. `scripts/tracks/content_catalog.gd` defines the active IDs and matching menu titles; environments load lazily on selection. The catalogue has eleven active courses. Quick Race and Time Trial use it; other modes apply course capability gates. Town Square supports Quick Race, Time Trial and Freestyle only. Quick Race/Freestyle support up to eight cars; tournament/elimination expansion is pending.

| ID | Playable title | Environment |
|---|---|---|
| game_table | Roulette Grand Prix | environments/casino/blackjack.tscn |
| toys_r_you | Toys R You | environments/tabletop/toys_r_you.tscn |
| toys_r_asleep | Toys R Asleep | environments/tabletop/toys_r_asleep.tscn |
| rusty_nuts_workshop | Rusty Nuts Workshop | environments/tabletop/rusty_nuts_workshop.tscn |
| moonlight_junk_heap | Moonlight Junk Heap | environments/tabletop/moonlight_junk_heap.tscn |
| firefly_bbq | Firefly BBQ | environments/tabletop/firefly_bbq.tscn |
| nighttime_noodles | Nighttime Noodles | environments/tabletop/nighttime_noodles.tscn |
| mount_rainier | Mount Rainier | environments/tabletop/mount_rainier.tscn |
| topspeed_oval | Topspeed Oval | environments/tabletop/topspeed_oval.tscn |
| bazaar | Bazaar | environments/tabletop/bazaar.tscn |
| town_square | Town Square | environments/tabletop/town_square.tscn |

`game_table` keeps its historical ID and environment filename; older reports call earlier revisions Blackjack Grand Prix. The `blackjack` ID remains a compatibility alias for saved records.

## Preserved, inactive content

Practice Patch, Felt Sprint, Card Bridge Circuit, Cereal Slalom, Plate Rim Rally, Countertop-to-Table Run, Carpet Cruise, Desk Drawer Dash, Toybox Trestle and Beach Buggies retain available authoring recipes and archived baselines. Several retired entry/definition/preview resources are absent from the active tracks directory; these are not claimed directly runnable. They cannot be selected through the production catalogue. Casino Cup rules/results are retained, but its retired courses are no longer reachable from the menu. The build retains older profile data where accepted, but the owner permits development records/rewards to reset when useful; preservation-only migrations are not required.

The legacy 2D `main.tscn`/scripts remain, but `tracks/catalog.json` and several referenced JSON circuits are absent from the active directory. Restoring that old build is separate work. They do not populate the production course selector. Unintegrated sources under `GLB Tracks/` are a source library, not automatically playable content.

Route changes and import gates are documented in [AUTHORING.md](AUTHORING.md). Current status is in the [rollout record](../.summer/plans/2026-10-03-tabletop-glb-rollout.md).
