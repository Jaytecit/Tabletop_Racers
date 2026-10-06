# Opening artwork and sound

## Approved expanded theme opening — 5 October 2026

The live opening now derives from `theme-review/opening-theme-review-v3.mp4`.
The owner's four additional clips (`cerealtunnel.mp4`, `speedboat.mp4`,
`monster.mp4`, `buggy.mp4`) are included with their original audio excluded.
They use the four built-in OpenAI-generated reference stills preserved in
`theme-review/`. Jaylabs blends into the new theme rather than cutting to
silence. `theme-opening.ogv` is silent; the shared player uses
`audio/music/opening_theme_mix.ogg`. The existing original synthesized thud
plays on the interactive `(not)` landing. Previous assets and provenance
below are retained as history. See `docs/verification/theme-opening.md`.

Generated 4 October 2026 with the built-in OpenAI image generator, using this
project's existing vehicle card art, driver portraits and brand logo as supplied
references. The original illustrated opening was later replaced by the owner's
supplied MiniMax H3 video clips generated through Summer. The extended opening
uses eight supplied clips and moving crops of the existing illustrated artwork.

- `jump.png`: Roxy's coral buggy and Bea's lime monster truck.
- `drift.png`: Finn's cyan drift coupe and Kit's yellow racing car.
  Edited with the built-in OpenAI image generator to seat Finn fully behind
  the windscreen, with his hair below the roof frame and glass reflections
  over his head. `drift-before-cockpit-fix.png` preserves the original artwork.
- `water.png`: Finn's orange speedboat leading Roxy and Kit.
- `logo_main.png`: existing logo edited to omit `(not)` for its initial reveal.

The final revealed logo is `assets/brand/real_thing_logo.png`, unchanged.

## Single vehicle type video reference images

Generated with the built-in OpenAI image generator using the existing opening
artwork as style, vehicle and character references. These are separate video
start frames used for generating the owner's video clips.

- `buggy_only.png`: Roxy's coral buggy with matching buggy rivals, approaching a ramp.
- `monster_truck_only.png`: Bea's lime monster truck with matching truck rivals.
- `drift_only.png`: Finn's cyan coupe with matching coupe rivals; drivers behind glass.
- `racing_car_only.png`: Kit's yellow open-wheel racer with matching formula-car rivals.
- `speedboat_only.png`: Finn's orange speedboat with matching speedboat rivals.
- `tabletop_wide_reference.png`: a new wide desk circuit view, generated from
  `buggy_only.png` and `jump.png` with the built-in OpenAI image generator.
  It is the reference for the owner's supplied tabletop reveal video.

Generation prompt constraints: only the named vehicle type throughout each
race, including background racers; preserve character identities, vehicle
designs, miniature surroundings and pixel-edged illustrated style; use a wide
video start frame, coherent seating and wheel/hull geometry, no text or UI.
Buggy and truck frames start grounded near obstacles; enclosed-car drivers'
heads and hair stay below the roof frame behind the windscreen.
Driver portrait cards use `assets/arcade/drivers.png`, unchanged.
The soundtrack is the existing `audio/music/menu_pulsing.mp3`; its credits remain
in `audio/music/CREDITS.md`. The original synthesized impact sound is generated
by `tools/analyze_opening_music.py` at `audio/sfx/opening_thud.wav`.

`race_reference.png` and `shot-prompts.json` preserve the earlier Summer concept
and failed video-generation attempt. They are not displayed by the opening.

## Implemented video montage

`montage.ogv` combines the owner's supplied tabletop reveal, buggy, monster
truck, drift coupe, formula car, speedboat, stunt and charging-racers clips,
plus animated crops of `jump.png` and `drift.png`. `video-manifest.json` records source filenames,
SHA-256 hashes, timing and processing. All generated clip audio is removed.
The existing shared menu music and original synthesized impacts remain in use.
`tools/build_opening_video.py` reproduces the silent Ogg Theora montage with
one-beat crossfades, driver artwork, a callback edit and a final dip to the
title background. The main logo impact is timed separately to the music drop.
