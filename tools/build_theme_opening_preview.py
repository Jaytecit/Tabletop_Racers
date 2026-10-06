"""Standalone review edit; never replaces the accepted in-game opening.

Requires ffmpeg/ffprobe on PATH, numpy, scipy and Pillow. Source movie parts
are preserved in tests/baselines/opening/extended_build. Optional replacement
animations live beside the first-frame artwork; filenames are mapped below.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.signal import find_peaks, stft

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/video/opening/theme-review'
OUT = ROOT / 'tests/baselines/opening/theme-review-v2'
OLD = ROOT / 'tests/baselines/opening/extended_build'
THEME = ROOT / 'audio/music/Main Theme - not The Real Thing.mp3'
FPS, BEAT, FIRST = 30, .4, .025
THEME_START, BLEND = 3.6, .8
ANIMATIONS = {'tunnel':'cerealtunnel.mp4', 'water_bend':'speedboat.mp4',
              'obstacles':'monster.mp4', 'overhead':'buggy.mp4'}


def probe(path):
    return json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
        '-show_streams', '-show_format', '-of', 'json', str(path)]))


def run(args, log):
    with log.open('ab') as output:
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
                        '-filter_complex_threads', '1', *map(str, args)],
                       stderr=output, check=True)


def analyse():
    rate = 22050
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(THEME),
        '-t', '16', '-ar', str(rate), '-ac', '1', '-f', 'f32le', 'pipe:1'])
    samples = np.frombuffer(raw, dtype='<f4')
    _, times, spectrum = stft(samples, rate, nperseg=1024, noverlap=804)
    flux = np.maximum(0, np.diff(np.abs(spectrum), axis=1)).sum(axis=0)
    peaks, _ = find_peaks(flux, distance=25, prominence=np.std(flux))
    onsets = times[1:][peaks]
    indices = np.round((onsets - FIRST) / BEAT)
    period, offset = np.polyfit(indices, onsets, 1)
    residual = float(np.sqrt(np.mean((onsets - (indices * period + offset))**2)))
    assert abs(60 / period - 150) < .2 and residual < .01
    return dict(measured_bpm=float(60 / period), measured_first_beat=float(offset),
                onset_fit_rms_seconds=residual, measured_window_seconds=16,
                authored_bpm=150, authored_first_beat=FIRST,
                note='Beat-synchronised editorial cut; vocal/chorus alignment requires listening review.')


def title_card(logo, target, prompt=False):
    # Deterministic title graphics use the existing brand artwork unchanged.
    y, x = np.mgrid[:720, :1280]
    glow = np.maximum(0, 1 - np.sqrt(((x-640)/850)**2 + ((y-330)/550)**2))
    rgb = np.stack([10+glow*13, 13+glow*17, 34+glow*42], axis=-1).astype('uint8')
    canvas = Image.fromarray(rgb).convert('RGBA')
    badge = Image.open(logo).convert('RGBA')
    badge = badge.crop(badge.getbbox())
    badge.thumbnail((1100, 400), Image.Resampling.LANCZOS)
    canvas.alpha_composite(badge, ((1280-badge.width)//2, (720-badge.height)//2-40))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 25)
    text = 'AN HOMAGE TO CLASSIC MINIATURE RACING'
    draw.text((640, 555), text, font=font, anchor='mm', fill='#fff0cf')
    if prompt:
        draw.text((640, 630), 'PRESS START', font=font, anchor='mm', fill='#ffe500')
    canvas.convert('RGB').save(target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--analyse-only', action='store_true')
    args = parser.parse_args()
    ART.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    cues = analyse()
    duration = float(probe(THEME)['format']['duration'])
    cues.update(track=str(THEME.relative_to(ROOT)), source_duration_seconds=duration,
                logo_beat=432, logo_seconds=FIRST+432*BEAT,
                not_impact_beat=436, prompt_beat=440,
                fade_start_seconds=179.2, fade_duration_seconds=duration-179.2,
                standalone_theme_start_seconds=THEME_START,
                studio_visual_crossfade_seconds=BLEND,
                studio_audio_fade_start_seconds=3.6, studio_audio_fade_end_seconds=5.0)
    (ART/'music-cues.json').write_text(json.dumps(cues, indent=2)+'\n')
    if args.analyse_only:
        print(json.dumps(cues, indent=2))
        return
    log = OUT/'encode-errors.log'
    log.touch()
    animation_metadata = {}
    for name, filename in ANIMATIONS.items():
        path = ART/filename
        metadata = probe(path)
        video_stream = next(s for s in metadata['streams'] if s['codec_type']=='video')
        animation_metadata[name] = dict(path=path,
            duration=float(video_stream['duration']),
            source_audio_removed=any(s['codec_type']=='audio' for s in metadata['streams']))
    action = OLD/'01_action.mp4'
    sources = {'world':(action,.5,3.8), 'buggy':(action,5.25,3.8),
        'truck':(action,9.95,3.8), 'drift':(action,14.65,3.8),
        'formula':(action,19.3,3.8), 'boat':(action,24,3.8),
        'stunt':(OLD/'03_stunt.mp4',.1,4.3),
        'charge':(OLD/'04_charge.mp4',.1,4.3)}
    stills = {'tunnel':ART/'01-cereal-tunnel.png',
              'water_bend':ART/'02-bucket-bend.png',
              'obstacles':ART/'03-truck-obstacles.png',
              'overhead':ART/'04-overhead-hairpin.png',
              'jump_art':ROOT/'assets/video/opening/jump.png',
              'drift_art':ROOT/'assets/video/opening/drift.png'}
    # Musical phrases are 16 beats; action callbacks shorten to eight/four.
    plan = [('world',16),('buggy',8),('truck',8),('drift',8),('formula',8),('boat',16),
        ('tunnel',16),('stunt',16),('water_bend',16),('obstacles',16)]
    plan += [(s,8) for s in ['overhead','formula','truck','drift','boat','tunnel','stunt','charge']]
    plan += [(s,16) for s in ['buggy','drift','formula','truck']]
    plan += [(s,16) for s in ['water_bend','obstacles','tunnel','overhead']]
    plan += [(s,4) for s in ['buggy','formula','drift','boat','truck','charge','stunt','tunnel',
                            'formula','boat','truck','drift','overhead','obstacles','stunt','charge']]
    plan += [(s,8) for s in ['overhead','tunnel','water_bend','obstacles','stunt','charge']]
    assert sum(beats for _,beats in plan)==432
    parts, records = [], []
    previous_frame, beat = 0, 0
    for index,(name,beats) in enumerate(plan):
        end_frame = round((FIRST+(beat+beats)*BEAT)*FPS)
        frames = end_frame-previous_frame
        seconds = frames/FPS
        candidate = ART/ANIMATIONS[name] if name in ANIMATIONS else None
        label = None
        if 192 <= beat < 256:
            label = ['ROXY ROCKET','FINN FLYWHEEL','KIT SPARK','BEA BOLT'][(beat-192)//16]
        if name in stills and candidate is None:
            path = stills[name]
            if not path.is_file(): raise FileNotFoundError(path)
            zoom = f'1.02+on*{.06/max(1,frames-1):.9f}'
            filters = (f"scale=1920:1080,zoompan=z='{zoom}':x='iw/2-iw/zoom/2':"
                       f"y='ih/2-ih/zoom/2':d={frames}:s=1280x720:fps={FPS}")
            inputs = ['-i',path]
            kind = 'moving first-frame artwork; awaiting owner animation'
        else:
            if candidate is not None:
                path = candidate
                available = animation_metadata[name]['duration']
                if beats >= 16:
                    start, used = 0, available
                else:
                    used = min(available,seconds)
                    # Short callbacks sample later action, rather than repeating entrances.
                    start = (available-used)*(.75 if beat>=320 else .35)
            else:
                path,start,available = sources[name]
                used = min(available,seconds)
            inputs = ['-ss',start,'-i',path]
            filters = (f'trim=duration={used},setpts=(PTS-STARTPTS)*{seconds/used:.9f},'
                       'scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,'
                       f'fps={FPS},tpad=stop_mode=clone:stop_duration=0.1')
            kind = 'owner animation' if candidate is not None else 'existing animated footage'
        if label:
            filters += (f",drawbox=x=40:y=608:w=450:h=65:color=0x100e35@0.9:t=fill,"
                rf"drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':text='{label}':"
                'x=62:y=626:fontsize=30:fontcolor=0xffe500')
        if index==0: filters += ',fade=t=in:st=0:d=0.4'
        if index==len(plan)-1: filters += f',fade=t=out:st={seconds-.2}:d=0.2'
        filters += ',setsar=1,format=yuv420p'
        output = OUT/f'part-{index:02}.mp4'
        run([*inputs,'-vf',filters,'-an','-frames:v',frames,'-c:v','libx264',
             '-crf','19','-preset','fast',output],log)
        part_metadata=probe(output)
        assert len(part_metadata['streams'])==1, 'Source clip audio leaked into montage'
        assert int(part_metadata['streams'][0]['nb_frames'])==frames
        parts.append(output)
        records.append(dict(shot=name,start_beat=beat,beats=beats,
            theme_seconds=previous_frame/FPS,standalone_seconds=THEME_START+previous_frame/FPS,
            duration_seconds=seconds,kind=kind,source=str(path.relative_to(ROOT)),
            source_start_seconds=start if kind!='moving first-frame artwork; awaiting owner animation' else 0,
            source_used_seconds=used if kind!='moving first-frame artwork; awaiting owner animation' else seconds,
            source_audio_removed=candidate is not None,
            source_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        beat += beats
        previous_frame=end_frame
        print(f'{index+1}/{len(plan)} {name} at {records[-1]["theme_seconds"]:.2f}s',flush=True)
    # Two-stage badge reveal preserves the game's late '(not)' title treatment.
    title_card(ROOT/'assets/video/opening/logo_main.png',OUT/'title-main.png')
    title_card(ROOT/'assets/brand/real_thing_logo.png',OUT/'title-full.png')
    title_card(ROOT/'assets/brand/real_thing_logo.png',OUT/'title-prompt.png',True)
    ends = [round((FIRST+436*BEAT)*FPS),round((FIRST+440*BEAT)*FPS),round(duration*FPS)]
    for index,(name,end) in enumerate(zip(['main','full','prompt'],ends)):
        frames=end-previous_frame
        filters=f'fps={FPS},setsar=1,format=yuv420p'
        if index==0: filters+=',fade=t=in:st=0:d=0.1'
        if index==2: filters+=f',fade=t=out:st={frames/FPS-1}:d=1'
        path=OUT/f'title-{name}.mp4'
        run(['-loop','1','-i',OUT/f'title-{name}.png','-vf',filters,'-an',
             '-frames:v',frames,'-c:v','libx264','-crf','19','-preset','fast',path],log)
        parts.append(path)
        previous_frame=end
    listing=OUT/'concat.txt'
    listing.write_text(''.join(f"file '{p.as_posix()}'\n" for p in parts))
    silent=OUT/'theme-silent.mp4'
    run(['-f','concat','-safe','0','-i',listing,'-c','copy',silent],log)
    ident=OUT/'studio.mp4'
    run(['-i',ROOT/'assets/video/opening/jaylabs.ogv','-vf',
         'scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,'
         'fps=30,fade=t=in:st=0:d=0.6,setsar=1,format=yuv420p',
         '-an','-frames:v',round((THEME_START+BLEND)*FPS),'-c:v','libx264','-crf','19','-preset','fast',ident],log)
    film=OUT/'film-silent.mp4'
    run(['-i',ident,'-i',silent,'-filter_complex',
         f'[0:v]settb=AVTB,setpts=PTS-STARTPTS[a];[1:v]settb=AVTB,setpts=PTS-STARTPTS[b];'
         f'[a][b]xfade=transition=fade:duration={BLEND}:offset={THEME_START},format=yuv420p[v]',
         '-map','[v]','-an','-c:v','libx264','-crf','19','-preset','fast',film],log)
    candidate=OUT/'opening-theme-review.candidate.mp4'
    run(['-i',film,'-i',THEME,'-i',ROOT/'assets/video/opening/jaylabs.ogv',
         '-filter_complex',
         f'[1:a]afade=t=in:st=0:d={BLEND},afade=t=out:st=179.2:d={duration-179.2},adelay=3600|3600[theme];'
         '[2:a]afade=t=in:st=0:d=0.6,afade=t=out:st=3.6:d=1.4[studio];'
         '[theme][studio]amix=inputs=2:duration=longest:normalize=0,'
         'alimiter=limit=0.80:level=false:latency=true,volume=0.7[a]',
         '-map','0:v','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k',
         '-t',previous_frame/FPS+THEME_START,'-movflags','+faststart',candidate],log)
    run(['-xerror','-i',candidate,'-f','null','-'],OUT/'decode-errors.log')
    metadata=probe(candidate)
    assert len(metadata['streams'])==2
    assert abs(float(metadata['format']['duration'])-(duration+THEME_START))<.1
    assert metadata['streams'][0]['width']==1280 and metadata['streams'][0]['height']==720
    full_audio=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error',
        '-i',str(candidate),'-vn','-f','f32le','pipe:1']),dtype='<f4')
    decoded_peak=float(np.max(np.abs(full_audio)))
    assert decoded_peak<1.0, f'Encoded audio exceeds playback ceiling: {decoded_peak}'
    audio=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-sseof','-0.12',
        '-i',str(candidate),'-vn','-ac','1','-ar','22050','-f','f32le','pipe:1']),dtype='<f4')
    final_rms=float(np.sqrt(np.mean(audio**2)))
    assert final_rms<.008,final_rms
    final=ART/'opening-theme-review-v3.mp4'
    candidate.replace(final)
    manifest=dict(cues=cues,studio_seconds=THEME_START,shots=records,output=str(final.relative_to(ROOT)),
        imported_animations={name:dict(source=str(record['path'].relative_to(ROOT)),
            duration_seconds=record['duration'],source_audio_removed=record['source_audio_removed'])
            for name,record in animation_metadata.items()},
        review_status='Standalone full-song assembly using all four supplied animations; source clip audio removed.',
        game_opening_replaced=False)
    (ART/'edit-manifest-v3.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'validation.json').write_text(json.dumps(dict(full_decode_passed=True,
        final_audio_rms=final_rms,decoded_audio_peak=decoded_peak,
        metadata=metadata,output_sha256=hashlib.sha256(final.read_bytes()).hexdigest()),indent=2)+'\n')
    print(f'Validated standalone: {final}',flush=True)


if __name__=='__main__': main()
