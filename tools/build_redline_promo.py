"""Beat-synchronised promo from isolated gameplay and existing approved media."""
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.signal import find_peaks

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'tests/baselines/promo-redline/edit'
OUT = ROOT / 'marketing'
ART = ROOT / 'assets/video/opening/theme-review'
MUSIC = ROOT / 'audio/music/Redline Assembly.mp3'
FPS = 30


def run(args, log='encode-errors.log'):
    with (WORK / log).open('ab') as stream:
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-filter_complex_threads', '1', *map(str, args)], stderr=stream, check=True)


def label(path, title, subtitle):
    im = Image.new('RGBA', (1280, 720))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((40, 40, 700, 144), radius=12, fill=(16, 14, 53, 230), outline='#00cafa', width=3)
    for y, text, size, color in [(51, title, 34, '#ffe500'), (99, subtitle, 20, '#fff0cf')]:
        d.text((60, y), text, font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', size), fill=color)
    im.save(path)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(exist_ok=True)
    audio = np.frombuffer(subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(MUSIC),
        '-t', '36', '-ac', '1', '-ar', '22050', '-f', 'f32le', 'pipe:1']), dtype='<f4')
    hop = 220
    env = np.sqrt(np.mean(audio[:len(audio)//hop*hop].reshape(-1, hop)**2, axis=1))
    peaks, _ = find_peaks(np.maximum(0, np.diff(env)), distance=25, prominence=.018)
    onsets = (peaks+1)*hop/22050
    regular = onsets[(onsets > 3.2) & (onsets < 12.8)]
    period, intercept = np.polyfit(np.arange(len(regular)), regular, 1)
    phase = intercept % period
    # Snap edit points to measured attacks and then to the 30 fps frame grid.
    def cut(beat):
        target = phase + beat*period
        near = onsets[np.abs(onsets-target) < .10]
        actual = near[np.argmin(np.abs(near-target))] if len(near) else target
        return round(float(actual)*FPS)
    boundaries = [0] + [cut(b) for b in range(4, 73, 4)] + [cut(80)]
    plan = [
        ('media', ROOT/'assets/video/opening/JAYLABS.mp4', 2.0, '', ''),
        ('media', ART/'cerealtunnel.mp4', 1.0, 'TINY CARS. GIANT RACES.', 'MINIATURE ARCADE RACING'),
        ('toys', 'buggy_0', 0, 'TOYS R YOU', 'ACTUAL GAMEPLAY · BEACH BUGGY'),
        ('media', ART/'buggy.mp4', 2.0, '', ''),
        ('toys', 'buggy_1', 0, '', ''),
        ('toys', 'monster_truck_1', 0, 'GO BIG.', 'MONSTER TRUCK'),
        ('media', ART/'monster.mp4', 2.0, '', ''),
        ('toys', 'monster_truck_2', 0, '', ''),
        ('toys', 'racing_car_1', 0, 'CHASE THE REDLINE.', 'RACING CAR'),
        ('toys', 'racing_car_2', 0, '', ''),
        ('media', ART/'cerealtunnel.mp4', 5.0, 'TAKE IT OUTSIDE.', 'SAME SMALL SCALE. NEW BIG RACES.'),
        ('firefly', 'buggy_0', 0, 'FIREFLY BBQ', 'ACTUAL GAMEPLAY · BEACH BUGGY'),
        ('firefly', 'buggy_1', 0, '', ''),
        ('firefly', 'monster_truck_0', 0, '', ''),
        ('firefly', 'monster_truck_1', 0, 'BRING THE BIG WHEELS.', 'MONSTER TRUCK'),
        ('firefly', 'monster_truck_2', 0, '', ''),
        ('firefly', 'racing_car_1', 0, '', ''),
        ('firefly', 'racing_car_2', 0, 'ONE MORE RACE.', 'RACING CAR'),
        ('end', '', 0, '', ''),
    ]
    ending = Image.open(ROOT/'tests/baselines/opening/theme-review-v2/title-full.png').convert('RGB')
    d = ImageDraw.Draw(ending)
    d.text((640, 640), 'COMING SOON', font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 56),
           fill='#ffe500', anchor='mm')
    ending.save(WORK/'end.png')
    edl = []
    for i, (kind, source, start, title, subtitle) in enumerate(plan):
        frames = boundaries[i+1]-boundaries[i]
        duration = frames/FPS
        inputs = []
        if kind == 'media':
            inputs = ['-ss', start, '-i', source]
        elif kind == 'end':
            inputs = ['-loop', '1', '-framerate', FPS, '-i', WORK/'end.png']
        else:
            source = ROOT/f'tests/baselines/promo-redline/{kind}/{source}_%03d.jpg'
            inputs = ['-framerate', FPS, '-i', source]
            if kind == 'toys' and 'monster_truck_2' in str(source):
                # The first half passes behind the drum; use the clear exit in slow motion.
                inputs = ['-framerate', '18', '-start_number', '30', '-i', source]
        vf = 'fps=30,scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,setsar=1'
        if i == 0:
            vf = 'fps=30,scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1'
        if kind == 'end': vf += f',fade=t=out:st={duration-.7}:d=0.7'
        if title:
            card = WORK/f'label-{i}.png'
            label(card, title, subtitle)
            inputs += ['-loop', '1', '-i', card]
            filters = f'[0:v]{vf}[base];[base][1:v]overlay=0:0[v]'
        else:
            filters = f'[0:v]{vf}[v]'
        segment = WORK/f'part-{i:02}.mp4'
        run([*inputs, '-filter_complex', filters, '-map', '[v]', '-an', '-frames:v', frames,
             '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', segment])
        edl.append(dict(index=i, start=boundaries[i]/FPS, duration=duration,
                        source=str(source), source_start=start, title=title, kind=kind))
        print(f'Encoded shot {i+1}/{len(plan)}', flush=True)
    (WORK/'concat.txt').write_text('\n'.join(f"file 'part-{i:02}.mp4'" for i in range(len(plan)))+'\n')
    duration = boundaries[-1]/FPS
    final = OUT/'redline-assembly-promo.mp4'
    run(['-f', 'concat', '-safe', '0', '-i', WORK/'concat.txt', '-i', MUSIC,
         '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-af',
         f'afade=t=in:st=0:d=0.04,afade=t=out:st={duration-.7}:d=0.7',
         '-c:a', 'aac', '-b:a', '192k', '-t', duration, '-movflags', '+faststart', final])
    run(['-xerror', '-i', final, '-f', 'null', '-'], 'decode-errors.log')
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
        '-show_format', '-of', 'json', str(final)]))
    assert abs(float(metadata['format']['duration'])-duration) < .08
    soundtrack = np.frombuffer(subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(final),
        '-vn', '-f', 'f32le', 'pipe:1']), dtype='<f4')
    assert float(np.max(np.abs(soundtrack))) < 1.0
    result = dict(output=str(final), duration=duration, fps=FPS, resolution=[1280,720],
                  measured_bpm=float(60/period), beat_phase=phase, full_decode_passed=True,
                  audio_peak=float(np.max(np.abs(soundtrack))), shots=edl,
                  rejected_shots=['toys/buggy_2: scenery occlusion', 'toys/monster_truck_2 frames 0–29: scenery occlusion'])
    (OUT/'redline-assembly-promo-edit.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'shots'}, indent=2), flush=True)


if __name__ == '__main__':
    main()
