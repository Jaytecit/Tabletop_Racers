"""Encode and index isolated, frame-by-frame gameplay captures."""
import csv
import json
import subprocess
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'marketing/gameplay-clips-2026-10-06'

def main():
    clips = OUT / 'clips'
    clips.mkdir(exist_ok=True)
    selected = {}
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 16)
    for result in sorted((OUT / 'capture-day').glob('*/results.json')):
        data = json.loads(result.read_text(encoding='utf-8-sig'))
        assert data['finished'] and data['reports']['passed'], result
        assert not data['errors_seen'] and not data['frame_warnings'], result
        assert (result.parent / 'process-exit.txt').exists(), result
        for shot in data['reports']['shots']:
            assert shot['time_of_day'] == 'DAY' and shot['vehicle'] != 'speedboat' and shot['clean']
            selected[shot['name']] = (result,shot)
    records = []
    for result,shot in selected.values():
        assert shot['states'] == {'0': 120}, (shot['name'], shot['states'])
        folder = result.parent / shot['folder']
        frames = sorted(folder.glob('frame_*.jpg'))
        assert len(frames) == 120, folder
        target = clips / (shot['name'] + '.mp4')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-framerate', '30', '-i', str(folder / 'frame_%03d.jpg'),
            '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p',
            '-movflags', '+faststart', '-an', str(target)], check=True)
        probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error',
            '-show_streams', '-show_format', '-of', 'json', str(target)]))
        stream = probe['streams'][0]
        assert stream['width'] == 1920 and stream['height'] == 1080
        assert int(stream['nb_frames']) == 120 and float(probe['format']['duration']) == 4
        # Decode the whole clip, not just its metadata.
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(target), '-f', 'null', '-'], check=True)
        record = {**shot, 'capture_folder': str(folder.relative_to(OUT)), 'file': 'clips/' + target.name, 'seconds': 4,
                  'width': 1920, 'height': 1080, 'fps': 30, 'audio': 'silent'}
        records.append(record)
    assert len(records) == 30, len(records)
    (OUT / 'manifest.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
    with (OUT / 'shot-list.csv').open('w', newline='', encoding='utf-8') as f:
        fields = ['file', 'course', 'vehicle', 'camera', 'route_fraction', 'start_station',
                  'end_station', 'seconds', 'width', 'height', 'fps', 'audio']
        writer = csv.DictWriter(f, fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(records)
    sheet = Image.new('RGB', (960, len(records)*202), '#121522')
    draw = ImageDraw.Draw(sheet)
    for row, shot in enumerate(records):
        folder = OUT / shot['capture_folder']
        for col, frame in enumerate([0,60,119]):
            im = Image.open(folder / f'frame_{frame:03d}.jpg').convert('RGB')
            im.thumbnail((320,180))
            sheet.paste(im, (col*320,row*202))
        draw.text((8,row*202+182), f"{row+1:02d}  {shot['name']}", font=font, fill='white')
    sheet.save(OUT / 'contact-sheet.jpg', quality=92)
    # Compact index for quick browsing, plus three-frame strips above for QC.
    grid = Image.new('RGB', (1600, 6*218), '#121522')
    draw = ImageDraw.Draw(grid)
    for index, shot in enumerate(records):
        x, y = (index%5)*320, (index//5)*218
        im = Image.open(OUT/shot['capture_folder']/'frame_060.jpg').convert('RGB')
        im.thumbnail((320,180))
        grid.paste(im,(x,y))
        draw.text((x+4,y+181),f"{index+1:02d} {shot['course']}",font=font,fill='white')
        draw.text((x+4,y+199),f"{shot['vehicle']} / {shot['camera']}",font=font,fill='white')
    grid.save(OUT/'preview.jpg',quality=92)
    lines = ['# Promotional gameplay clips', '', '30 clips · 4 seconds each · 1920×1080 · 30 fps · H.264 MP4.',
        '', 'Silent footage for scoring in your editor. HUD hidden; existing world-space race markers and route overlays retained.',
        'Vehicles drive using the game AI and real physics. Setup relocates the grid to different route sections before each take; no relocation occurs during a take.',
        'Capture runs use read-only sentinel profiles and hardware-input isolation. Production game files are unchanged.', '',
        'Only DAY-preset courses and land vehicles are included. Every visible racer was checked on all 120 frames: no crash, impact, fall or recovery. Superseded footage remains under capture/; new footage and rejected takes are under capture-day/. Some capture runs logged shutdown-only ObjectDB leak warnings; process exit records are preserved.', '',
        '| Clip | Course | Vehicle | Camera | Route section |', '|---|---|---|---|---|']
    for index, shot in enumerate(records):
        lines.append(f"| [{index+1:02d}]({shot['file']}) | {shot['course']} | {shot['vehicle']} | {shot['camera']} | {round(shot['route_fraction']*100)}% |")
    (OUT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    with zipfile.ZipFile(OUT/'gameplay-clips.zip','w',compression=zipfile.ZIP_STORED) as archive:
        for file in sorted(clips.glob('*.mp4')):
            archive.write(file,'clips/'+file.name)
        for name in ['README.md','manifest.json','shot-list.csv','preview.jpg','contact-sheet.jpg']:
            archive.write(OUT/name,name)
    print(json.dumps({'clips':len(records),'seconds':120,'output':str(clips)}))

if __name__ == '__main__':
    main()
