# Current menu flow — 6 October 2026

The live opening leads to named profile creation/selection, then the main mode menu. Character confirmation advances automatically. Freestyle includes vehicle selection; assigned-class modes skip that step and go to Course. Back follows the permitted sequence. Setup is on the main menu, and Change Profile is in Setup. A modal alphabet keyboard supports gamepad name entry.

All five classes are implemented, not future preview cards. Standard modes use catalogue assignment; Freestyle selects any class. Eight character portraits are separate from the four reused starting stat builds. Course selection uses a live flyover and lazy environment loading. Results offer Retry, Select Course and Main Menu.

Quick Race and Freestyle offer 0–7 AI. The Moonlight eight-car shortcut selects Hard, Beach Buggy and three laps. Tournament and Elimination still cap the field at four; [expansion work](eight-car-experience-audit.md) is pending. Solo modes and per-course eligibility remain intact.

Generated illustrations under `assets/vehicles/menu/` are menu art; runtime vehicles use original/derived GLBs. [Selection-flow evidence](verification/menu-selection-flow.md), [navigation evidence](verification/menu-navigation.md), [profile evidence](verification/saved-player-profiles.md), [gamepad name entry](gamepad-driver-name-entry.md) and [2.22.23 results/menu evidence](verification/requirements-2.22.23.md) describe their tested versions. The older `tests/evidence/arcade_menu_flow/` run records the earlier two-mode preview implementation.
