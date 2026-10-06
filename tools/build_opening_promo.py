"""Build the promotional ending without modifying the live/review intro."""
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/video/opening/theme-review'
OUT = ROOT / 'tests/baselines/opening/promo'
SOURCE = ART / 'opening-theme-review-v3.mp4'
FPS = 30
START = round((3.6 + .025 + 440 * .4) * FPS) / FPS
LENGTH = 14.4  # .4s entrance, 12s settled hold, 2s fade


def run(args, log):
    with log.open('ab') as stream:
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-filter_complex_threads', '1', *map(str, args)],
                       stderr=stream, check=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    base = Image.open(ROOT / 'tests/baselines/opening/theme-review-v2/title-full.png').convert('RGB')
    font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 70)
    lettering = Image.new('RGBA', (900, 110))
    draw = ImageDraw.Draw(lettering)
    draw.text((450, 55), 'COMING SOON', font=font, anchor='mm',
              fill='#ffe500', stroke_width=3, stroke_fill='#120f29')
    tail = OUT / 'ending.mp4'
    with (OUT / 'encode-errors.log').open('ab') as log:
        process = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo',
            '-pix_fmt', 'rgb24', '-s', '1280x720', '-r', str(FPS), '-i', 'pipe:0',
            '-an', '-c:v', 'libx264', '-crf', '19', '-preset', 'fast',
            '-pix_fmt', 'yuv420p', str(tail)], stdin=subprocess.PIPE, stderr=log)
        try:
            for frame in range(round(LENGTH * FPS)):
                t = frame / FPS
                image = base.copy()
                # Oversized lettering contracts into a brief rebound and flash.
                scale = 1 + 1.1 * (1 - min(t / .2, 1)) ** 3
                if .2 <= t < .4:
                    scale += .06 * np.sin((t - .2) / .2 * np.pi) * (1 - (t - .2) / .2)
                text = lettering.resize((round(900 * scale), round(110 * scale)), Image.Resampling.LANCZOS)
                image.paste(text, ((1280 - text.width) // 2, 627 - text.height // 2), text)
                if .2 <= t < .267:
                    image = Image.blend(image, Image.new('RGB', image.size, '#fff0cf'), .18)
                fade = max(0, min(1, (LENGTH - t - 1 / FPS) / 2))
                if fade < 1:
                    image = Image.blend(Image.new('RGB', image.size), image, fade)
                process.stdin.write(image.tobytes())
                if frame in (6, 15, 372, 431):
                    image.save(OUT / f'ending-{frame:03}.png')
        finally:
            process.stdin.close()
        assert process.wait() == 0, 'Ending encode failed; see encode-errors.log'
    final = ART / 'opening-coming-soon-promo.mp4'
    candidate = OUT / 'promo.candidate.mp4'
    # Preserve the entire preceding edit. Let the final musical phrase slow down
    # into the promotional hold, with a shared two-second picture/music fade.
    theme_duration = float(json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
        '-show_format', '-of', 'json', str(ROOT / 'audio/music/Main Theme - not The Real Thing.mp3')]))['format']['duration'])
    song_start = START - 3.6
    tempo = (theme_duration - song_start) / LENGTH
    filters = (f'[0:v]trim=end={START},setpts=PTS-STARTPTS[p];'
        '[1:v]setpts=PTS-STARTPTS[e];[p][e]concat=n=2:v=1:a=0[v];'
        f'[0:a]atrim=end={START},asetpts=PTS-STARTPTS[a0];'
        f'[2:a]atrim=start={song_start},asetpts=PTS-STARTPTS,atempo={tempo},'
        f'apad,atrim=duration={LENGTH},volume=0.49,afade=t=out:st={LENGTH-2}:d=2[a1];'
        '[a0][a1]concat=n=2:v=0:a=1[music];'
        f'[3:a]volume=0.45,adelay={round((START+.2)*1000)}:all=1[hit];'
        '[music][hit]amix=inputs=2:duration=first:normalize=0,'
        'alimiter=limit=0.9:level=false:latency=true[a]')
    run(['-i', SOURCE, '-i', tail, '-i', ROOT / 'audio/music/Main Theme - not The Real Thing.mp3',
         '-i', ROOT / 'audio/sfx/opening_thud.wav', '-filter_complex', filters,
         '-map', '[v]', '-map', '[a]', '-c:v', 'libx264', '-crf', '19', '-preset', 'fast',
         '-c:a', 'aac', '-b:a', '192k', '-t', START + LENGTH,
         '-movflags', '+faststart', candidate], OUT / 'encode-errors.log')
    run(['-xerror', '-i', candidate, '-f', 'null', '-'], OUT / 'decode-errors.log')
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
        '-show_streams', '-show_format', '-of', 'json', str(candidate)]))
    assert abs(float(metadata['format']['duration']) - (START + LENGTH)) < .1
    audio = np.frombuffer(subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(candidate),
        '-vn', '-f', 'f32le', 'pipe:1']), dtype='<f4')
    assert np.max(np.abs(audio)) < 1
    ending = np.frombuffer(subprocess.check_output(['ffmpeg', '-v', 'error', '-sseof', '-0.1',
        '-i', str(candidate), '-vn', '-f', 'f32le', 'pipe:1']), dtype='<f4')
    assert float(np.sqrt(np.mean(ending ** 2))) < .008
    candidate.replace(final)
    (OUT / 'validation.json').write_text(json.dumps(dict(full_decode_passed=True,
        coming_soon_start=START, settled_hold_seconds=12, fade_seconds=2,
        duration_seconds=START + LENGTH, decoded_audio_peak=float(np.max(np.abs(audio))),
        final_audio_rms=float(np.sqrt(np.mean(ending ** 2))),
        source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        output_sha256=hashlib.sha256(final.read_bytes()).hexdigest()), indent=2) + '\n')
    print(f'Validated promotional video: {final}', flush=True)


if __name__ == '__main__':
    main()
