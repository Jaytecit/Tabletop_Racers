"""Build a 25.6-second portrait teaser from the approved animated intro."""
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/video/opening/theme-review'
OUT = ROOT / 'tests/baselines/opening/short'
FPS, SLOT = 30, 3.2


def run(args, log='encode-errors.log'):
    with (OUT / log).open('ab') as stream:
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-filter_complex_threads', '1', *map(str, args)], stderr=stream, check=True)


def graphic(path, subtitle, ending=False):
    canvas = Image.new('RGBA', (1080, 1920), '#101329' if ending else (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    font = lambda size: ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', size)
    logo = Image.open(ROOT / 'assets/brand/real_thing_logo.png').convert('RGBA')
    logo = logo.crop(logo.getbbox())
    logo.thumbnail((880, 330), Image.Resampling.LANCZOS)
    canvas.alpha_composite(logo, ((1080-logo.width)//2, 650 if ending else 180))
    if ending:
        draw.text((520, 1080), 'COMING SOON', font=font(86), anchor='mm', fill='#ffe500')
        draw.text((520, 1230), 'WATCH THE FULL INTRO', font=font(46), anchor='mm', fill='white')
        draw.text((520, 1310), 'Tap the related video', font=font(38), anchor='mm', fill='#d7dcee')
    else:
        draw.rounded_rectangle((80, 1230, 970, 1500), radius=25, fill=(12, 15, 35, 225))
        # Match arcade_menu_flow.triple_frame: gold, ink, purple rings.
        for index, color in enumerate(('#fff000', '#13286a', '#6b3291')):
            inset = index * 6
            draw.rounded_rectangle((80+inset, 1230+inset, 970-inset, 1500-inset),
                                   radius=25, outline=color, width=3)
        draw.text((525, 1310), subtitle, font=font(58), anchor='mm', fill='#ffe500')
        draw.text((520, 1415), 'ANIMATED GAME INTRO', font=font(35), anchor='mm', fill='white')
    canvas.save(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    action = ROOT / 'tests/baselines/opening/extended_build/01_action.mp4'
    plan = [
        (ART / 'cerealtunnel.mp4', 1.0, 'TINY CARS. GIANT RACES.'),
        (action, 5.25, 'BIG TABLETOP ACTION'),
        (ART / 'monster.mp4', 2.0, 'MONSTER TRUCKS'),
        (action, 14.65, 'DRIFT THROUGH IT'),
        (ART / 'speedboat.mp4', 2.0, 'MAKE WAVES'),
        (ART / 'buggy.mp4', 3.0, 'EVERYDAY OBSTACLES'),
        (ROOT / 'tests/baselines/opening/extended_build/03_stunt.mp4', .4, 'MINIATURE MAYHEM'),
    ]
    parts, records = [], []
    for index, (source, offset, label) in enumerate(plan):
        overlay = OUT / f'overlay-{index}.png'
        graphic(overlay, label)
        output = OUT / f'part-{index}.mp4'
        # Fit the whole shot: a portrait centre-crop would discard rival cars
        # and oversized props. A softly blurred moving backdrop fills 9:16.
        filters = ('[0:v]setpts=PTS-STARTPTS,fps=30,split=2[bg][fg];'
            '[bg]scale=270:480:force_original_aspect_ratio=increase,crop=270:480,'
            'gblur=sigma=14,eq=brightness=-0.18:saturation=0.7,scale=1080:1920[b];'
            '[fg]scale=1080:608:force_original_aspect_ratio=decrease,pad=1080:608:(ow-iw)/2:(oh-ih)/2[f];'
            '[b][f]overlay=x=0:y=580[c];[c][1:v]overlay=0:0,setsar=1,format=yuv420p[v]')
        run(['-ss', offset, '-i', source, '-loop', '1', '-i', overlay,
            '-filter_complex', filters, '-map', '[v]', '-an', '-frames:v', 96,
            '-c:v', 'libx264', '-crf', '19', '-preset', 'fast', output])
        parts.append(output)
        records.append(dict(source=str(source.relative_to(ROOT)), source_start=offset,
                            teaser_start=index*SLOT, duration=SLOT, caption=label))
        print(f'Built shot {index+1}/{len(plan)}', flush=True)
    graphic(OUT / 'ending.png', '', ending=True)
    run(['-loop', '1', '-i', OUT / 'ending.png', '-vf',
        'fps=30,fade=t=in:st=0:d=0.1,fade=t=out:st=2.3666667:d=0.8,setsar=1,format=yuv420p',
        '-an', '-frames:v', 96, '-c:v', 'libx264', '-crf', '19', '-preset', 'fast', OUT / 'ending.mp4'])
    parts.append(OUT / 'ending.mp4')
    (OUT / 'concat.txt').write_text(''.join(f"file '{p.as_posix()}'\n" for p in parts))
    run(['-f', 'concat', '-safe', '0', '-i', OUT / 'concat.txt', '-c', 'copy', OUT / 'silent.mp4'])
    candidate = OUT / 'short.candidate.mp4'
    run(['-i', OUT / 'silent.mp4', '-ss', 115.225, '-i', ROOT / 'audio/music/Main Theme - not The Real Thing.mp3',
        '-i', ROOT / 'audio/sfx/opening_thud.wav', '-filter_complex',
        '[1:a]asetpts=PTS-STARTPTS,atrim=duration=25.6,volume=0.49,'
        'afade=t=in:st=0:d=0.04,afade=t=out:st=24.8:d=0.8[m];'
        '[2:a]volume=0.45,adelay=22400:all=1[h];'
        '[m][h]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.9:level=false:latency=true[a]',
        '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
        '-t', 25.6, '-movflags', '+faststart', candidate])
    run(['-xerror', '-i', candidate, '-f', 'null', '-'], 'decode-errors.log')
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
        '-show_format', '-of', 'json', str(candidate)]))
    video = next(s for s in metadata['streams'] if s['codec_type']=='video')
    assert (video['width'], video['height'], int(video['nb_frames'])) == (1080, 1920, 768)
    assert abs(float(metadata['format']['duration'])-25.6) < .05
    audio = np.frombuffer(subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(candidate),
        '-vn', '-f', 'f32le', 'pipe:1']), dtype='<f4')
    assert float(np.max(np.abs(audio))) < 1
    final = ART / 'coming-soon-youtube-short.mp4'
    candidate.replace(final)
    for timestamp, name in [(0, 'first'), (9.6, 'drift'), (23.4, 'cta'), (25.566, 'final')]:
        run(['-ss', timestamp, '-i', final, '-frames:v', 1, OUT / f'encoded-{name}.png'])
    (OUT / 'validation.json').write_text(json.dumps(dict(full_decode_passed=True, width=1080,
        height=1920, frames=768, duration=25.6, decoded_audio_peak=float(np.max(np.abs(audio))),
        output_sha256=hashlib.sha256(final.read_bytes()).hexdigest(), shots=records,
        music_start_seconds=115.225, source_clip_audio_removed=True), indent=2)+'\n')
    print(f'Validated Short: {final}', flush=True)


if __name__ == '__main__':
    main()
