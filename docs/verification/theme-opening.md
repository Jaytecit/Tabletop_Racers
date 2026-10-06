# Approved theme opening — 5 October 2026

> Verification record: measurements, counts, versions and failures below describe the named runs. They are not a fresh acceptance claim for the current build. See [current build](../current-build.md) and [remaining work](../implementation-checklist.md), including eight-car scope and the owner's current verification policy.

The opening uses the approved `assets/video/opening/theme-review/opening-theme-review-v3.mp4`
assembly: Jaylabs blends into racing at 3.6s, with a 0.8s visual overlap and
the rocket fading before its source cutoff. All four supplied animations
are included; their audio is excluded. The 10.125s cereal-tunnel video is
retimed in long slots and excerpted in callbacks.

`assets/video/opening/theme-opening.ogv` is a silent 1280×720, 30 fps Theora
conversion through the frame-aligned main-logo cue at 176.433333s.
`audio/music/opening_theme_mix.ogg` contains the approved startup mix.
The shared Music player starts both clocks together and continues through
profile selection and menu refreshes. At the mix's end it switches to
`main_theme_menu.ogg`, a processed version of the original theme with a
smooth ending fade; subsequent visits do not replay the rocket ident.

The existing interactive title animation follows the film. `(not)` lands
four 150 BPM beats after the badge at 178.033333s and plays
`audio/sfx/opening_thud.wav` once on the Effects bus. It briefly ducks music
by 3 dB. Start appears four beats later. Skip preserves song position and
advances the title reveal to the next beat; held input stays isolated until
release. The studio portion remains unskippable through the 4.4s blend.

Town Square now explicitly uses `audio/music/menu_pulsing.mp3`, the former
menu soundtrack, through the existing race loop helper. No course geometry,
vehicle assignments or capabilities changed.

## Media conversion and failure evidence

FFmpeg 8.1.2's first Theora encoding failed full decoding in both FFmpeg
8.1.2 and bundled FFmpeg 7.1 (`error in unpack_block_qpis`). Logs and the
decoder comparison are retained in `tests/baselines/opening/theme-integration/`.
The replacement uses the same bundled encoder as the accepted earlier
opening: `imageio_ffmpeg.get_ffmpeg_exe()`, libtheora quality 8, yuv420p.
Publication requires full decoding with both binaries. The source review
video, supplied clips and old opening assets are retained.

Media validation, pre-change script snapshots and rendered test evidence
are retained under `tests/baselines/opening/theme-integration/`.
The final isolated rendered walkthrough (`full03`) passed all 33 checks:
full film and four supplied clips, title/thud, keyboard/controller held-input
release, Skip without restarting music, 720p layout, profile/menu continuity,
theme replay without the rocket, Town Square's former menu song and its loop,
and mute/unmute. The thud fired at 178.034422s, about 1 ms after its cue.
The owned child PID 80364 exited normally; runtime, frame and shutdown
errors were empty. Profiles and machine settings were read-only.

The silent film disables the native embedded-audio delay for its playback
and corrects accumulated decoder drift against the shared music clock.
The four clip samples differed by 71–185 ms; one correction occurred before
the overhead shot, which was verified in the rendered capture. The early
sync diagnostics and first failed read-only check are retained alongside
the final evidence. The rendered test uses dummy audio, so it verifies
playback and cue timing; perceived mix balance still relies on listening.
