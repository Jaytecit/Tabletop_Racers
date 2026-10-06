# Menu and race music — 4 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

## Current playback (owner follow-up)

The menu song now retains its original 60.029388-second duration, including the approximately 0.96-second quiet tail. Its `finished` signal restarts the complete song. Menu pages, Setup and course changes preserve playback; returning from a race starts a fresh menu visit. This supersedes the earlier one-shot behaviour and silence trimming below.

`Race1.mp3` supplies `audio/music/race1.ogg`, the default in-race music. Source SHA-256: `F55F075DFC1A1FF1514C383DE78AD164BB4717307A882EF4002222B11DCD190B`. The source remains unchanged in Downloads. FFmpeg measured only MP3 boundary padding: leading silence to 0.0267708 seconds and trailing silence from 60.026771 to 60.048 seconds (-50 dB, minimum 5 ms). Conversion retains samples from 0.026770833 to 60.026770833 seconds, producing exactly 60 seconds of stereo 48 kHz Vorbis at quality 6. It adds no silent pause, fade or crossfade. The existing runtime loop helper enables gapless Vorbis looping. The default final-lap override is cleared so Race1 continues through the final lap; retained older music assets are preserved.

`tests/evidence/menu-race-music-loop-2026-10-04/` contains the updated isolated playback probe results. All 16 checks passed: real menu completion/replay, full duration, uninterrupted menu refresh/course changes, Race1 source and loop wrap, final-lap continuity, pause, return, bus routing and mute. Both scripts compiled without errors; the probe finished in 12.568 seconds with no captured errors or frame warnings. PID 146868 exited. Profile writes and hardware controller input were isolated. Audio checks use the runner's dummy driver; audible seam quality remains a listening judgement. A reimport requested during the initial filesystem scan reported file-not-found; repeating reimport after the scan completed succeeded before verification.

## Initial one-shot implementation (historical)

The owner-supplied `a6371a06-1052-47aa-85e1-e069401ff37b_music_driving_injecting_excitement__1791117973462.mp3` supplies the new menu song. Source SHA-256: `BFE62AE8044925D15E883DD26D20AFD29E08415BF9F83F7A37D460BA84EACCAD`. The original remains unchanged in Downloads.

FFmpeg detected trailing silence from 59.068844 to 60.029388 seconds at -50 dB, minimum duration 0.5 seconds. `audio/music/menu_driving_excitement.ogg` retains the first 59.17 seconds, including the natural fade and about 100 ms of quiet tail, encoded as stereo 44.1 kHz Vorbis quality 6. Its import has `loop=false`.

The song plays once per menu visit. Menu pages, Setup and course changes preserve playback, including the completed state after the song ends. Returning from a race starts the song again. Existing race/final-lap looping tracks and Music volume/mute controls remain in use.

`tests/probes/menu_music_verification.gd` ran through the isolated rendered verification runner with a read-only profile and hardware controller isolation. Final evidence: `tests/evidence/menu-music-2026-10-04-final/`. All 12 checks passed, including duration, non-looping playback, Music bus, actual completion after seeking into the ending, no restart on menu refresh, course switching, race music, pause, return and mute/unmute. Finished in 12.085 seconds with no captured errors or frame warnings; PID 95900 exited. Audio checks use the runner's dummy audio driver; audible balance was not judged.

The initial `tests/evidence/menu-music-2026-10-04/` run failed because the new audio file had not yet been imported. Its raw errors are preserved. That specific test process (105204) was stopped and confirmed exited; the editor was left running. A filesystem scan imported the asset, after which both scripts compiled and the final run passed.
