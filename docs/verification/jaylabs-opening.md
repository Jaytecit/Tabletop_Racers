# JAYLABS startup — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

Historical studio-only behaviour, superseded by the approved blended theme
opening on 5 October 2026; see [theme opening](theme-opening.md).

Normal startup previously faded the supplied `assets/video/opening/JAYLABS.mp4` clip in from black over 0.6 seconds, played its audio without game-intro music, held the finished logo for three seconds, then faded it to black over 0.6 seconds. The existing game intro started its video/music clocks together and used its existing fade-in. Intro completion still opens saved-profile selection. The explicit development `--skip-opening` option bypasses both clips.

The MP4 remains unchanged. `jaylabs.ogv` is the engine playback copy: FFmpeg 7.1 (the existing intro's bundled encoder), libtheora/yuv420p, 1280×480, libvorbis audio. Its original wide aspect ratio is fitted inside the viewport with black margins. `jaylabs_last.png` preserves the source's final logo frame during the hold and fade, independently of decoder cleanup at end-of-stream.

`tests/baselines/jaylabs/run04` records actual VideoStreamPlayer completion, the full-bright hold, fade beginning after three seconds, delayed game music/montage startup and the retained saved-profile flow. Rendered captures cover each stage. Owner saves are read-only, hardware inputs are isolated and the owned test process exits. The first run's timing passed but visual inspection exposed corrupted FFmpeg 8.1.2 Theora playback; that evidence is retained. Re-encoding with 7.1 resolves the corruption, verified against a source frame and the rendered `run02` capture. `run03` passes all behavioral assertions but retains a pre-existing script UID lookup warning; a fresh editor resource lookup resolves the cache without changing the scene/script UID. The final run has no gameplay/frame/shutdown errors.
