"""Phrase-led promo with fresh cinematic gameplay and a falling qualifier title."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from build_theme_opening_preview import analyse

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'assets/video/opening/theme-review'
OLD = ROOT/'tests/baselines/opening/extended_build'
LIB = ROOT/'marketing/cinematic-clips-2026-10-06'
WORK = ROOT/'tests/baselines/opening/cinematic-promo-20261006'
PREVIOUS = ROOT/'tests/baselines/opening/unique-promo-20261006/previous-promo.mp4'
FINAL = ROOT/'marketing/tabletop-racers-cinematic-theme-promo.mp4'
FPS = 30
TITLE_START = 176.43333333333334
IMPACT = TITLE_START+1.6
# Validated on the capture machine's RTX 4060 Ti; avoids a second long CPU encode.
VIDEO_ENCODING=['-c:v','h264_nvenc','-preset','p6','-tune','hq','-rc','vbr',
    '-cq','18','-b:v','0','-profile:v','high','-pix_fmt','yuv420p']


def probe(path):
    return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams',
        '-show_format','-of','json',str(path)]))


def run(args, log='encode-errors.log'):
    with (WORK/log).open('ab') as stream:
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y',
            '-filter_complex_threads','1',*map(str,args)],stderr=stream,check=True)


def ending():
    WORK.mkdir(parents=True,exist_ok=True)
    full = Image.open(ROOT/'assets/brand/real_thing_logo.png').convert('RGBA')
    main = Image.open(ROOT/'assets/video/opening/logo_main.png').convert('RGBA')
    # Isolate the five yellow letter components and their original outlines.
    crop = np.array(full.crop((110,95,440,280)))
    yellow = (crop[:,:,0]>165)&(crop[:,:,1]>140)&(crop[:,:,2]<100)
    components,n = ndimage.label(yellow)
    mask = np.zeros(yellow.shape,bool)
    for i in range(1,n+1):
        y,x = np.where(components==i)
        if len(x)>1500 and y.max()-y.min()>65 and x.max()<325:
            mask |= components==i
    assert ndimage.label(mask)[1]==5
    mask = ndimage.binary_dilation(mask,iterations=10)
    crop[:,:,3] = np.where(mask,crop[:,:,3],0)
    qualifier = Image.fromarray(crop).resize((167,94),Image.Resampling.LANCZOS)
    qualifier.save(WORK/'not-qualifier.png')
    main = main.resize((1100,367),Image.Resampling.LANCZOS)
    full = full.resize((1100,367),Image.Resampling.LANCZOS)
    y,x = np.mgrid[:720,:1280]
    glow = np.maximum(0,1-np.sqrt(((x-640)/850)**2+((y-330)/550)**2))
    rgb = np.stack([10+glow*13,13+glow*17,34+glow*42],axis=-1).astype('uint8')
    base = Image.fromarray(rgb).convert('RGBA')
    font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',25)
    soon = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',70)
    target = WORK/'ending.mp4'
    with (WORK/'encode-errors.log').open('ab') as log:
        process = subprocess.Popen(['ffmpeg','-v','error','-y','-f','rawvideo',
            '-pix_fmt','rgb24','-s','1280x720','-r','30','-i','pipe:0','-an',
            '-c:v','libx264','-threads','2','-crf','18','-preset','fast',
            '-pix_fmt','yuv420p',str(target)],stdin=subprocess.PIPE,stderr=log)
        for frame in range(528):
            t = frame/FPS
            image = base.copy()
            scale = 1+0.04*np.exp(-t*6)
            badge = full if t>=1.6 else main
            badge = badge.resize((round(1100*scale),round(367*scale)),Image.Resampling.LANCZOS)
            image.alpha_composite(badge,((1280-badge.width)//2,round(330-badge.height/2)))
            draw = ImageDraw.Draw(image)
            if t>=.4:
                draw.text((640,555),'AN HOMAGE TO CLASSIC MINIATURE RACING',font=font,
                    anchor='mm',fill='#fff0cf')
            if 1.2<=t<1.6:
                p=(t-1.2)/.4
                drop_y=round(-110+(194+110)*p*p)
                image.alpha_composite(qualifier,(146,drop_y))
            if t>=3.2:
                draw.text((640,633),'COMING SOON',font=soon,anchor='mm',fill='#ffe500',
                    stroke_width=2,stroke_fill='#100e35')
            age=t-1.6
            if 0<=age<.65:
                dx=round(np.sin(age*83)*17*np.exp(-age*7))
                dy=round(np.cos(age*69)*20*np.exp(-age*7))
                image=image.transform(image.size,Image.Transform.AFFINE,(1,0,-dx,0,1,-dy),
                    fillcolor=(10,13,34,255))
            fade=min(1,max(0,(17.6-t-1/FPS)/2))
            if t<.15: fade*=t/.15
            image=Image.blend(Image.new('RGBA',image.size,(0,0,0,255)),image,fade).convert('RGB')
            process.stdin.write(image.tobytes())
            if frame in [0,42,45,47,48,49,54,60,100,527]:
                image.save(WORK/f'title-{frame:03}.jpg',quality=95)
        process.stdin.close()
        assert process.wait()==0
    run(['-ss',.8,'-i',target,'-i',ROOT/'audio/sfx/opening_thud.wav',
        '-filter_complex','[1:a]adelay=800:all=1,volume=0.7[a]',
        '-map','0:v','-map','[a]','-t',3.2,'-c:v','copy','-c:a','aac',
        WORK/'title-impact-preview.mp4'])
    print('Title drop/shake rendered',flush=True)


def package():
    selected={}
    (LIB/'clips').mkdir(exist_ok=True)
    for result in sorted((LIB/'capture').glob('*/results.json')):
        data=json.loads(result.read_text(encoding='utf-8-sig'))
        assert data['finished'] and not data['errors_seen'] and not data['frame_warnings'],result
        assert (result.parent/'process-exit.txt').exists(),result
        # A rejected shot does not invalidate separately measured clean takes.
        for shot in data['reports'].get('shots',[]):
            assert shot['clean']
            if result.parent.name=='mount_rainier' and shot['camera'] in ['drift_orbit','drone_sweep','drone_lead']:
                continue  # Rendered QC: camera intersects the mountain scenery.
            if result.parent.name=='topspeed_oval' and (LIB/'capture/topspeed_oval_colours/results.json').exists():
                continue
            if result.parent.name=='town_square' and (LIB/'capture/town_square_clear_colours/results.json').exists():
                continue
            source=result.parent/shot['folder']
            assert len(list(source.glob('frame_*.jpg')))==shot['frames']
            suffix='-colours' if result.parent.name.endswith('_colours') else ''
            path=LIB/'clips'/(shot['name']+suffix+'.mp4')
            if not path.exists():
                run(['-framerate',30,'-i',source/'frame_%03d.jpg','-an',
                    *VIDEO_ENCODING,'-movflags','+faststart',path])
            assert int(probe(path)['streams'][0]['nb_frames'])==shot['frames']
            selected[shot['name']]=shot|dict(path=str(path),seconds=shot['frames']/30,
                capture_result=str(result),colour=shot.get('colour','red'))
    records=list(selected.values())
    (LIB/'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
    sheet=Image.new('RGB',(1280,len(records)*202),'#121522')
    d=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
    for j,shot in enumerate(records):
        result=Path(shot['capture_result'])
        source=result.parent/shot['folder']
        for i,f in enumerate([0,shot['frames']//4,shot['frames']//2,shot['frames']-1]):
            sheet.paste(Image.open(source/f'frame_{f:03}.jpg').resize((320,180)),(i*320,j*202))
        d.text((4,j*202+182),shot['name']+' / '+shot['colour'],font=font,fill='white')
    sheet.save(LIB/'contact-sheet.jpg',quality=92)
    print(f'{len(records)} clean fresh clips packaged',flush=True)


def caption(path,title,subtitle):
    im=Image.new('RGBA',(1280,720))
    pixels=np.zeros((720,1280,4),dtype='uint8')
    pixels[:,:,0:3]=(8,10,25)
    pixels[545:,:,3]=np.linspace(0,210,175).astype('uint8')[:,None]
    im=Image.fromarray(pixels)
    d=ImageDraw.Draw(im)
    d.text((42,616),title,font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',36),
        fill='#ffe500',stroke_width=1,stroke_fill='#100e35')
    d.text((44,666),subtitle,font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',19),fill='#fff0cf')
    im.save(path)


def edit():
    cues=analyse()
    footage={s['name']:s for s in json.loads((LIB/'manifest.json').read_text())}
    plan=[]
    def game(name,beats=12,title='',subtitle=''):
        shot=footage[name]
        plan.append(dict(name=name,path=Path(shot['path']),start=0,
            used=min(shot['seconds'],beats*.4),beats=beats,kind='gameplay',
            colour=shot['colour'],course=shot['course'],vehicle=shot['vehicle'],
            camera=shot['camera'],capture_result=shot['capture_result'],title=title,
            subtitle=subtitle))
    def animation(name,beats=16,title='',subtitle=''):
        sources={'world':(OLD/'01_action.mp4',.5,3.8),
            'buggy':(OLD/'01_action.mp4',5.25,3.8),
            'truck':(OLD/'01_action.mp4',9.95,3.8),
            'drift':(OLD/'01_action.mp4',14.65,3.8),
            'formula':(OLD/'01_action.mp4',19.3,3.8),
            'boat':(OLD/'01_action.mp4',24,3.8),
            'stunt':(OLD/'03_stunt.mp4',.1,4.3),
            'charge':(OLD/'04_charge.mp4',.1,4.3)}
        path,start,used=sources.get(name,(ART/(name+'.mp4'),.2,7.6))
        if name=='overhead': path=ART/'buggy.mp4'
        plan.append(dict(name=name,path=path,start=start,used=used,beats=beats,
            kind='animation',title=title,subtitle=subtitle))
    # Vocal phrase timings are saved in vocal-phrases.json. Long animation passages
    # follow the two verses; real drift/boost actions accent the prechoruses/refrains.
    animation('world')
    game('topspeed_oval_buggy_drone_sweep',16,'TINY CARS. GIANT RACES.','ACTUAL GAMEPLAY')
    animation('cerealtunnel')
    animation('truck')
    animation('monster')
    animation('overhead')
    game('game_table_buggy_drone_sweep')
    game('toys_r_asleep_drift_car_low_tracking',12,'OWN EVERY CORNER.','DRIFT CARS · ACTUAL GAMEPLAY')
    game('topspeed_oval_racing_car_boost_away',4)
    game('mount_rainier_racing_car_boost_away',4)
    game('topspeed_oval_racing_car_drone_crane',12,'CHASE THE REDLINE.','OPEN-WHEEL RACING · ACTUAL GAMEPLAY')
    game('toys_r_asleep_monster_truck_drone_lead')
    game('topspeed_oval_drift_car_drift_orbit')
    game('nighttime_noodles_buggy_drone_sweep')
    animation('buggy')
    animation('drift')
    animation('speedboat')
    animation('boat',8)
    animation('formula',8)
    animation('stunt')
    game('toys_r_asleep_racing_car_drone_crane',12,'RACE INTO THE NIGHT.','HEADLIGHTS ON · ACTUAL GAMEPLAY')
    game('firefly_bbq_drift_car_drift_orbit')
    game('game_table_racing_car_boost_away',4)
    game('topspeed_oval_racing_car_boost_away_blue',4)
    game('nighttime_noodles_racing_car_drone_crane')
    game('topspeed_oval_monster_truck_drone_lead',12,'BRING THE BIG WHEELS.','MONSTER TRUCKS · ACTUAL GAMEPLAY')
    game('nighttime_noodles_drift_car_low_tracking')
    game('firefly_bbq_buggy_drone_sweep')
    game('firefly_bbq_racing_car_drone_crane')
    game('game_table_drift_car_drift_orbit')
    game('nighttime_noodles_monster_truck_drone_lead')
    game('nighttime_noodles_drift_car_drift_orbit')
    game('topspeed_oval_drift_car_low_tracking')
    game('firefly_bbq_drift_car_low_tracking',8)
    game('firefly_bbq_monster_truck_drone_lead',12,'ONE MORE RACE.','MINIATURE ARCADE RACING')
    animation('charge')
    assert sum(s['beats'] for s in plan)==432
    assert len([s for s in plan if s['kind']=='gameplay'])==24
    hashes={}
    for shot in plan:
        assert shot['path'].exists(),shot['path']
        assert shot['start']+shot['used']<=float(probe(shot['path'])['streams'][0]['duration'])+.02
        hashes.setdefault(shot['path'],hashlib.sha256(shot['path'].read_bytes()).hexdigest())
        shot['source_sha256']=hashes[shot['path']]
    for i,a in enumerate(plan):
        for b in plan[i+1:]:
            if a['source_sha256']==b['source_sha256']:
                assert a['start']+a['used']<=b['start'] or b['start']+b['used']<=a['start'],(a,b)
    game_colours={}
    for s in plan:
        if s['kind']=='gameplay': game_colours.setdefault(s['vehicle'],set()).add(s['colour'])
    assert all(c=={'red','blue','yellow','green'} for c in game_colours.values()),game_colours
    parts=[]
    studio=WORK/'studio.mp4'
    run(['-i',PREVIOUS,'-vf','trim=end=3.6,setpts=PTS-STARTPTS,fps=30,setsar=1',
         '-an','-frames:v',108,'-c:v','libx264','-crf',18,'-preset','fast','-threads',4,studio])
    parts.append(studio)
    previous_frame=beat=0
    records=[]
    sheet=Image.new('RGB',(1280,9*204),'#121522')
    d=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    for i,shot in enumerate(plan):
        end=round((.025+(beat+shot['beats'])*.4)*FPS)
        frames=end-previous_frame
        duration=frames/FPS
        target=WORK/f'part-{i:02}.mp4'
        inputs=['-ss',shot['start'],'-t',shot['used'],'-i',shot['path']]
        vf=f'scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,setsar=1,setpts={duration/shot["used"]:.10f}*(PTS-STARTPTS),fps=30'
        if shot['kind']=='animation' and shot['used']<duration:
            vf=vf.replace('fps=30','minterpolate=fps=30:mi_mode=blend,tpad=stop_mode=clone:stop_duration=0.2')
        vf+=',settb=1/30,setpts=N'
        if shot['title']:
            card=WORK/f'caption-{i:02}.png'
            caption(card,shot['title'],shot['subtitle'])
            inputs+=['-loop','1','-i',card]
            vf=f'[0:v]{vf}[base];[base][1:v]overlay=0:0:shortest=1:enable=\'between(t,0.25,{duration-.25})\''
            filter_args=['-filter_complex',vf]
        else: filter_args=['-vf',vf]
        run([*inputs,*filter_args,'-an','-frames:v',frames,*VIDEO_ENCODING,target])
        assert int(probe(target)['streams'][0]['nb_frames'])==frames,(shot['name'],frames)
        parts.append(target)
        preview=WORK/f'preview-{i:02}.jpg'
        run(['-ss',duration*.45,'-i',target,'-frames:v',1,'-vf','scale=320:180',preview])
        x,y=(i%4)*320,(i//4)*204
        sheet.paste(Image.open(preview),(x,y))
        d.text((x+3,y+182),f'{3.6+previous_frame/FPS:06.2f} {shot["name"]}',font=font,fill='white')
        records.append({k:v for k,v in shot.items() if k!='path'}|dict(source=str(shot['path']),
            start_seconds=3.6+previous_frame/FPS,duration_seconds=duration,start_beat=beat,frames=frames))
        previous_frame=end
        beat+=shot['beats']
        print(f'{i+1}/{len(plan)} {shot["name"]} at {records[-1]["start_seconds"]:.2f}s',flush=True)
    sheet.save(WORK/'contact-sheet.jpg',quality=92)
    assert abs(3.6+previous_frame/FPS-TITLE_START)<.001
    if not (WORK/'ending.mp4').exists(): ending()
    parts.append(WORK/'ending.mp4')
    listing=WORK/'concat.txt'
    listing.write_text(''.join(f"file '{p.as_posix()}'\n" for p in parts))
    silent=WORK/'silent.mp4'
    join_parts(parts,silent)
    finish(records,cues,game_colours,silent)


def join_parts(parts,silent):
    inputs=[]
    for part in parts: inputs+=['-threads','1','-i',part]
    filters=';'.join(f'[{i}:v]setpts=PTS-STARTPTS[v{i}]' for i in range(len(parts)))
    filters+=';'+''.join(f'[v{i}]' for i in range(len(parts)))
    filters+=f'concat=n={len(parts)}:v=1:a=0,settb=1/30,setpts=N[out]'
    run([*inputs,'-filter_complex',filters,'-map','[out]','-an',*VIDEO_ENCODING,silent])


def finish(records,cues,game_colours,silent):
    candidate=WORK/'candidate.mp4'
    # Rebuild the approved held ending without its former Coming Soon impact cue.
    tail_start=179.63333333333333
    theme=ROOT/'audio/music/Main Theme - not The Real Thing.mp3'
    theme_duration=float(probe(theme)['format']['duration'])
    tempo=(theme_duration-(tail_start-3.6))/14.4
    filters=(f'[1:a]atrim=end={tail_start},asetpts=PTS-STARTPTS[p];'
        f'[2:a]atrim=start={tail_start-3.6},asetpts=PTS-STARTPTS,atempo={tempo},'
        'apad,atrim=duration=14.4,volume=0.49,afade=t=out:st=12.4:d=2[e];'
        '[p][e]concat=n=2:v=0:a=1[music];'
        f'[music]volume=\'if(between(t,{IMPACT-.05},{IMPACT+.35}),0.72,1)\':eval=frame[duck];'
        f'[3:a]volume=0.68,adelay={round(IMPACT*1000)}:all=1[hit];'
        '[duck][hit]amix=inputs=2:duration=first:normalize=0,'
        'alimiter=limit=0.9:level=false:latency=true[a]')
    run(['-i',silent,'-i',PREVIOUS,'-i',theme,'-i',ROOT/'audio/sfx/opening_thud.wav',
        '-filter_complex',filters,'-map','0:v:0','-map','[a]',
        '-c:v','copy',
        '-c:a','aac','-b:a','192k','-t',5821/FPS,'-movflags','+faststart',candidate])
    run(['-xerror','-i',candidate,'-f','null','-'],'decode-errors.log')
    metadata=probe(candidate)
    assert int(metadata['streams'][0]['nb_frames'])==5821
    assert abs(float(metadata['format']['duration'])-5821/FPS)<.04
    packets=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0',
        '-show_packets','-show_entries','packet=pts_time','-of','json',str(candidate)]))['packets']
    timestamps=sorted(float(p['pts_time']) for p in packets)
    cadence_error=max(abs(t-i/FPS) for i,t in enumerate(timestamps))
    assert len(timestamps)==5821 and cadence_error<.00001,cadence_error
    audio=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(candidate),
        '-vn','-f','f32le','pipe:1']),dtype='<f4')
    assert np.max(np.abs(audio))<1
    error=max(abs(s['start_seconds']-3.6-(.025+s['start_beat']*.4)) for s in records[1:])
    assert error<=1/(2*FPS)+.00001
    manifest=dict(duration_seconds=5821/FPS,fps=FPS,resolution='1280x720',music_cues=cues,
        shots=records,unique_gameplay_clips=24,unique_animated_shots=12,repeated_source_intervals=0,
        verse_theme_seconds=[[12.8,38.4],[70.4,102.4]],chorus_theme_seconds=[[51.2,70.4],[115.2,134.4],[153.6,172.8]],
        title_impact_seconds=IMPACT,title_drop_seconds=.4,title_shake_seconds=.65,
        vehicle_colours={k:sorted(v) for k,v in game_colours.items()},
        max_cut_beat_error_seconds=error,max_frame_timestamp_error_seconds=cadence_error,
        full_decode_passed=True,audio_peak=float(np.max(np.abs(audio))),
        output_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),output=str(FINAL))
    (WORK/'validation.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copy2(candidate,FINAL)
    (ROOT/'marketing/tabletop-racers-cinematic-theme-promo-edit.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Validated: {FINAL}',flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--ending-only',action='store_true')
    parser.add_argument('--package-only',action='store_true')
    args=parser.parse_args()
    WORK.mkdir(parents=True,exist_ok=True)
    if args.ending_only:
        ending()
        return
    package()
    if args.package_only: return
    edit()


if __name__=='__main__': main()
