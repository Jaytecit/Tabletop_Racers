"""Rebuild the full promo from non-overlapping animation shots and unique gameplay takes."""
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from build_theme_opening_preview import analyse
from build_redline_promo import label

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/video/opening/theme-review'
OLD = ROOT / 'tests/baselines/opening/extended_build'
LIB = ROOT / 'marketing/gameplay-clips-2026-10-06'
WORK = ROOT / 'tests/baselines/opening/unique-promo-20261006'
FINAL = ROOT / 'marketing/tabletop-racers-full-theme-promo.mp4'
PREVIOUS = WORK / 'previous-promo.mp4'
FPS = 30


def probe(path):
    return json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
        '-show_streams', '-show_format', '-of', 'json', str(path)]))


def run(args, name='encode-errors.log'):
    with (WORK / name).open('ab') as log:
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-filter_complex_threads', '1', *map(str, args)], stderr=log, check=True)


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    if not PREVIOUS.exists():
        shutil.copy2(ART / 'opening-coming-soon-promo.mp4', PREVIOUS)
    cues = analyse()
    # These are separate original animated shots within the preserved assembly.
    animations = [(name, OLD/'01_action.mp4', start, 3.8, 8) for name, start in
        [('world', .5), ('buggy', 5.25), ('truck', 9.95), ('drift', 14.65),
         ('formula', 19.3), ('boat', 24)]]
    animations += [('stunt', OLD/'03_stunt.mp4', .1, 4.3, 8),
                   ('charge', OLD/'04_charge.mp4', .1, 4.3, 8)]
    for name in ['cerealtunnel', 'monster', 'speedboat', 'buggy']:
        path = ART / (name + '.mp4')
        animations.append((name + '_new', path, .2,
            min(7.6, float(probe(path)['streams'][0]['duration'])-.4), 16))
    # Spread the newer animations through the edit instead of grouping them at the end.
    animations = [animations[i] for i in [0,8,1,2,9,3,4,10,5,6,11,7]]
    shots = json.loads((LIB/'manifest.json').read_text())
    courses = sorted({s['course'] for s in shots})
    queues = [[s for s in shots if s['course']==c] for c in courses]
    gameplay = []
    while any(queues):
        for queue in queues:
            if queue:
                gameplay.append(queue.pop(0))
    assert len(gameplay)==30
    plan = []
    g = 0
    for index, animation in enumerate(animations):
        name,path,start,used,beats = animation
        title = {0:'TINY CARS. GIANT RACES.', 4:'BRING THE BIG WHEELS.',
                 7:'MAKE A SPLASH.', 9:'SMALL SCALE. BIG ADVENTURE.',
                 11:'ONE MORE RACE.'}.get(index, '')
        plan.append(dict(name=name,path=path,start=start,used=used,beats=beats,
            kind='animation', title=title, subtitle='MINIATURE ARCADE RACING' if title else ''))
        for _ in range(3 if index%2==0 else 2):
            shot = gameplay[g]
            beats = 12 if g%2==0 or g==29 else 8
            plan.append(dict(name=shot['name'],path=LIB/shot['file'],start=0,
                used=4 if beats==12 else 3.2,beats=beats,kind='gameplay',
                title=shot['course'].replace('_',' ').upper() if g%3==0 else '',
                subtitle='ACTUAL GAMEPLAY' if g%3==0 else ''))
            g += 1
    assert sum(s['beats'] for s in plan)==432
    hashes = {}
    for shot in plan:
        path = shot['path']
        hashes.setdefault(path, hashlib.sha256(path.read_bytes()).hexdigest())
        shot['source_sha256'] = hashes[path]
    # Hash identity also catches renamed duplicate files; intervals catch reused frames.
    for i,a in enumerate(plan):
        for b in plan[i+1:]:
            if a['source_sha256']==b['source_sha256']:
                assert a['start']+a['used']<=b['start'] or b['start']+b['used']<=a['start'], (a,b)
    parts = []
    def encode(inputs, vf, frames, target):
        run([*inputs, '-vf', vf, '-an', '-frames:v', frames, '-c:v','libx264',
            '-crf','18','-preset','fast','-pix_fmt','yuv420p', target])
        assert int(probe(target)['streams'][0]['nb_frames'])==frames
        parts.append(target)
    standard = 'scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,setsar=1'
    encode(['-i',PREVIOUS], 'trim=end=3.6,setpts=PTS-STARTPTS,fps=30,setsar=1',108,WORK/'studio.mp4')
    previous_frame = beat = 0
    records = []
    sheet = Image.new('RGB',(1280,11*204),'#121522')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
    for i,shot in enumerate(plan):
        end = round((.025+(beat+shot['beats'])*.4)*FPS)
        frames = end-previous_frame
        duration = frames/FPS
        inputs = ['-ss',shot['start'],'-t',shot['used'],'-i',shot['path']]
        vf = f'setpts={duration/shot["used"]:.10f}*(PTS-STARTPTS),{standard},fps=30'
        if shot['title']:
            card = WORK/f'caption-{i:02}.png'
            label(card,shot['title'],shot['subtitle'])
            inputs += ['-loop','1','-i',card]
            vf += f'[base];[base][1:v]overlay=0:0:shortest=1:enable=\'between(t,0.15,{duration-.15})\''
            # Multi-input overlays use filter_complex.
            target = WORK/f'part-{i:02}.mp4'
            run([*inputs,'-filter_complex',vf,'-an','-frames:v',frames,'-c:v','libx264',
                '-crf','18','-preset','fast','-pix_fmt','yuv420p',target])
            assert int(probe(target)['streams'][0]['nb_frames'])==frames
            parts.append(target)
        else:
            target = WORK/f'part-{i:02}.mp4'
            encode(inputs,vf,frames,target)
        preview = WORK/f'preview-{i:02}.jpg'
        run(['-ss',duration/2,'-i',target,'-frames:v',1,'-vf','scale=320:180',preview])
        x,y=(i%4)*320,(i//4)*204
        sheet.paste(Image.open(preview),(x,y))
        draw.text((x+4,y+182),f'{3.6+previous_frame/FPS:06.2f} {shot["name"]}',font=font,fill='white')
        records.append({k:v for k,v in shot.items() if k!='path'} | dict(
            source=str(shot['path']), start_seconds=3.6+previous_frame/FPS,
            duration_seconds=duration,start_beat=beat,frames=frames))
        print(f'{i+1}/42 {shot["name"]}',flush=True)
        previous_frame=end
        beat+=shot['beats']
    sheet.save(WORK/'contact-sheet.jpg',quality=92)
    tail_start = 3.6+previous_frame/FPS
    encode(['-ss',tail_start,'-i',PREVIOUS], 'setpts=PTS-STARTPTS,fps=30,setsar=1',528,WORK/'ending.mp4')
    listing = WORK/'concat.txt'
    listing.write_text(''.join(f"file '{p.as_posix()}'\n" for p in parts))
    silent = WORK/'silent.mp4'
    run(['-f','concat','-safe',0,'-i',listing,'-c','copy',silent])
    candidate = WORK/'candidate.mp4'
    # Preserve the approved complete soundtrack, including studio sting and final phrase.
    run(['-i',silent,'-i',PREVIOUS,'-map','0:v:0','-map','1:a:0','-c','copy',
         '-t',5821/FPS,'-movflags','+faststart',candidate])
    run(['-xerror','-i',candidate,'-f','null','-'],'decode-errors.log')
    metadata = probe(candidate)
    assert abs(float(metadata['format']['duration'])-5821/FPS)<.04
    assert int(metadata['streams'][0]['nb_frames'])==5821
    audio = np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(candidate),
        '-vn','-f','f32le','pipe:1']),dtype='<f4')
    peak=float(np.max(np.abs(audio)))
    assert peak<1
    error=max(abs(s['start_seconds']-3.6-(.025+s['start_beat']*.4)) for s in records[1:])
    assert error<=1/(2*FPS)+.00001
    manifest=dict(duration_seconds=5821/FPS,fps=FPS,resolution='1280x720',
        music_cues=cues,shots=records,unique_gameplay_clips=30,unique_animated_shots=12,
        repeated_source_intervals=0,max_cut_beat_error_seconds=error,
        full_decode_passed=True,audio_peak=peak,soundtrack='Approved promo audio stream preserved unchanged',
        source_promo=str(PREVIOUS),output=str(FINAL))
    (WORK/'validation.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copy2(candidate,FINAL)
    shutil.copy2(candidate,ART/'opening-coming-soon-promo.mp4')
    (ROOT/'marketing/tabletop-racers-full-theme-promo-edit.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Validated: {FINAL}',flush=True)


if __name__=='__main__':
    main()
