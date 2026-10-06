# Temporary race music

Pure Raceway and Pure Raceway Climax by MintoDog.
Source: https://opengameart.org/content/pure-raceway
License: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/).
Downloaded 2026-10-02, original Ogg files unmodified.

- pure_raceway.ogg: normal race/menu placeholder, 160 BPM.
- pure_raceway_final_lap.ogg: final-lap placeholder, 175 BPM.

The author describes both as loopable. Runtime stream duplicates enable looping, retaining source files unchanged. Voluntary credit retained even though CC0 does not require attribution.

These Pure Raceway tracks remain available as unused placeholders. The active course soundtrack mapping is in scripts/race/course_soundtrack.gd; race_presentation.gd handles playback. Audio cue ducking, pause and mute remain active.

## Owner-supplied soundtrack (2026-10-04)

- menu_pulsing.mp3: original Music_Pulsing_increasing_energy_sy.mp3, copied unchanged; 180.035875 seconds, used throughout pre-race menu screens.
- menu_driving_excitement.ogg: former menu music, now easy race music.
- race1.ogg: existing race music, now normal race music.
- hard_jungle.mp3: original a6371a06-1052-47aa-85e1-e069401ff37b_music_driving_high_energy_jungle_r__1791119779800.mp3, copied unchanged; 120.032625 seconds, used for hard races.
- nightmare_driving.mp3: original a6371a06-1052-47aa-85e1-e069401ff37b_music_driving_high_energy_drum_and__1791119238719.mp3, copied unchanged; 120.032625 seconds, used for nightmare races.

The difficulty-based race routing above is superseded for the nine active courses by the course soundtrack below. The exported/difficulty tracks remain fallbacks for courses without a mapping. Race streams are duplicated with looping enabled; the menu song plays in full and replays on completion. No license or creator attribution was supplied for the owner-provided files.


## Owner-supplied course soundtrack (4 October 2026)

5 October update: `Main Theme - not The Real Thing.mp3` now supplies the
opening and menu theme. `opening_theme_mix.ogg` retains the approved Jaylabs
overlap; `main_theme_menu.ogg` contains the theme alone with an ending fade
and encoding headroom. Both are derived Vorbis files; the original MP3 is
retained unchanged. Town Square now uses the former menu track,
`menu_pulsing.mp3`. The `(not)` landing uses the existing original synthesized
`audio/sfx/opening_thud.wav` on the Effects bus. See
`docs/verification/theme-opening.md` for the integration and evidence.

All ten supplied MP3 originals are retained unchanged. Course music takes priority over difficulty/final-lap fallback tracks in every race mode. The existing menu music, volume, ducking, mute and pause controls remain active.

| Course | File |
|---|---|
| Town Square | menu_pulsing.mp3 (former menu track) |
| Roulette Grand Prix | High Stakes Overdrive.mp3 |
| Toys R You | Toybox Turbo.mp3 |
| Toys R Asleep | After Bedtime.mp3 |
| Rusty Nuts Workshop | Redline Assembly.mp3 |
| Moonlight Junk Heap | Scrapyard Pursuit.mp3 |
| Firefly BBQ | Backyard Afterburner.mp3 |
| Nighttime Noodles | Midnight Takeout.mp3 |
| Mount Rainier | Summit Rush.mp3 |
| Topspeed Oval | Maximum Velocity.mp3 |
| Future water route | Wake Velocity.mp3 |

Wake Velocity is reserved through WATER_MUSIC. Future catalogue entries classified with group WATER automatically select it; no water course is currently registered. Speedboats on land in Freestyle retain that course's song.

Verification: tests/baselines/audio/course_soundtrack01. All nine mappings, all four difficulties, real playback and end-of-stream looping passed. Menu continuation/replay, representative race launch, final-lap retention, pause, return to menu, mute and water-file playback passed. Runtime/frame/shutdown errors were empty; the owned read-only, hardware-isolated rendered child (PID 49512) exited normally. Dummy audio confirms playback state, not perceived mix balance or musical loop seamlessness.
