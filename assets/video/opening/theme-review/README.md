# Theme opening — standalone review

Current promotional delivery: `marketing/tabletop-racers-cinematic-theme-promo.mp4`. The identical local `opening-coming-soon-promo.mp4` alias was moved into a local quarantine archive on 6 October after SHA-256 comparison. The historical builder below regenerates its earlier cut if needed; the live opening is unchanged. Rebuild with
`python tools/build_opening_promo.py`. This preserves the review and live
opening, replacing the standalone start prompt with a yellow COMING SOON
slam, rebound and the existing opening thud. The settled card holds for
12 seconds, followed by a two-second picture/audio fade. The final musical
phrase slows into this extended outro. Decode, duration, audio headroom and
final silence evidence is retained in `tests/baselines/opening/promo/`.

This is the approved full-song review assembly. The latest cut is
`opening-theme-review-v3.mp4` (about 3:08); it now supplies the live opening's
silent film and shared audio mix. The live interactive title adds the thud
when `(not)` lands. See `docs/verification/theme-opening.md`.
The original `opening-theme-review.mp4` remains available for comparison.
The complete 3:04 theme starts at standalone time 3.6s, with a 0.8s visual
crossfade from Jaylabs into racing. The theme fades in over that same overlap,
while the rocket audio fades from 3.6s to 5.0s, before its source cutoff.
The final 4.83 seconds of the theme fade smoothly. The source song, supplied
clips and earlier review versions are retained unchanged.

The measured opening beat grid is 150.012 BPM, with a first beat at 0.02486s.
The authored grid uses 150 BPM / 0.025s. Cuts use four-, eight- and sixteen-beat
groups. This is rhythmic synchronisation; vocal/chorus choices need listening
review. The final badge appears at song time 2:52.825, `(not)` resolves four
beats later, and the start prompt appears another four beats later.

Existing animated footage is reused at different cut lengths and restrained
speeds. All four new shots now use the owner's supplied animated clips, with
their original audio excluded from the edit. `cerealtunnel.mp4` is 10.125s of
video; `speedboat.mp4`, `monster.mp4` and `buggy.mp4` are each 8s. Longer slots
retime the full action to their musical duration, while callbacks use later
excerpts. `buggy.mp4` is the new overhead shot, distinct from the older buggy
footage used for the driver introduction.
The driver introduction uses existing footage and name cards.
`edit-manifest-v3.json` records every shot, exact frame timing, source and hash.
`jaylabs-transition-review-v3.mp4` provides a ten-second transition audition.
The final audio has encoding headroom and is checked for peaks exceeding the
playback ceiling after decoding.

## New animation requests

Generate one continuous **8-second, 16:9 image-to-video** clip per first frame.
Use the supplied PNG as the initial frame. No audio is needed. Keep character
identities, vehicle proportions, colour, illustrated pixel-edged style and tiny
scale. No cuts, text, logos, watermarks, morphing vehicles or extra wheels.

### 1. Cereal-box tunnel — `01-cereal-tunnel.png`

Eight-second continuous shot, starting exactly from the supplied image.
For the first two seconds, track alongside Roxy's coral buggy as it approaches
the cereal-box tunnel, followed by the green and blue buggies. From seconds
two to six, follow them through the tunnel as warm sunlight gives way to
shadow. In the final two seconds, the coral buggy emerges into sunlight with
its rivals following. Tyres spin, suspension responds and cereal crumbs
scatter. Keep a smooth low tracking camera and physically clear vehicle
paths. Preserve the illustrated style, drivers, colours and miniature scale.
Drivers stay seated with hands on wheels; props stay fixed. Only beach
buggies. 16:9, no cuts, text, logos, watermarks or audio.

The supplied clip is saved as `cerealtunnel.mp4` beside this file.

### 2. Bucket-handle bend — `02-bucket-bend.png`

Eight-second continuous shot, starting exactly from the supplied image.
Follow Finn's orange speedboat from a low water-level tracking camera as it
enters the sweeping bend during the first two seconds. From seconds two to
six, the orange boat banks gently through the water channel and passes
beneath the giant red bucket-handle arch, chased by the red and green boats.
During the final two seconds, they accelerate into clear water beyond the
arch. Produce coherent wakes and splashes; keep every hull touching the
water. Preserve the illustrated style, drivers, colours and miniature scale.
Drivers remain seated behind their windscreens; all household props stay
fixed. Only speedboats. 16:9, no cuts, text, logos, watermarks or audio.

The supplied clip is saved as `speedboat.mp4` beside this file.

### 3. Desk obstacle run — `03-truck-obstacles.png`

Eight-second continuous shot, starting exactly from the supplied image.
Track beside Bea's lime monster truck as it approaches the book ramp in the
first two seconds. From seconds two to five, the truck climbs and crests the
ramp with rotating tyres and responsive suspension. From seconds five to
eight, it makes a small hop onto the clear wooden desk, compresses its
suspension once and accelerates away. The red and blue trucks follow the
same route at a safe distance. Preserve the illustrated style, drivers,
colours and miniature scale. Drivers remain seated inside their cabs; desk
props stay fixed. Only monster trucks; no towering jumps or transformations.
16:9, no cuts, text, logos, watermarks or audio.

The supplied clip is saved as `monster.mp4` beside this file.

### 4. Overhead mug hairpin — `04-overhead-hairpin.png`

Eight-second continuous shot, starting exactly from the supplied image.
Keep the high bird's-eye three-quarter camera angle. During the first two
seconds, Roxy's coral buggy leads the green and blue buggies into the
visible hairpin around the giant blue mug, moving towards the foreground
along the curve shown in the reference. From seconds two to six, glide
the camera gently along with them as they steer around the mug, with
spinning tyres, slight suspension movement and restrained dust trails.
During the final two seconds, they straighten and accelerate towards the
clear tabletop straight beyond the bend. Preserve the illustrated style, driver
identities, colours, four-wheel geometry and miniature scale. Keep all
vehicles grounded and every household prop fixed. Only beach buggies.
16:9, no cuts, text, logos, watermarks or audio.

The supplied clip is saved as `buggy.mp4` beside this file and is included
in the standalone review's overhead racing slots.

## Rebuild and evidence

Run `python tools/build_theme_opening_preview.py` from the project root.
The builder uses all four named MP4s,
retimes them to each edit slot, removes their audio, validates full decoding
and checks duration, frame counts and the ending's audio level before
publishing the review MP4. Encode errors and validation data are preserved in
`tests/baselines/opening/theme-review-v2/`. Earlier evidence is retained in
`tests/baselines/opening/theme-review/`.

The four new first frames were generated with the built-in OpenAI image generator
on 5 October 2026 from the corresponding existing opening vehicle artwork.
