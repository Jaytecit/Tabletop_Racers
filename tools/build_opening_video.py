"""Build the silent 96-beat opening, publishing only after decode validation."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/video/opening'
BEAT = 60 / 128
FIRST_BEAT = .03
FPS = 32  # Exactly fifteen frames per beat.
SOURCES = {
    'world': '_uqcTT9WVG7kyzar-7B59_minimax-h3.mp4',
    'buggy': 'reg5SlSfwemjc6ynHqQrp_minimax-h3.mp4',
    'monster_truck': 'CLqvkzgMTucwsUxALjLOT_minimax-h3.mp4',
    'drift': '9egcf8exa3rVPpYHmQgtt_minimax-h3.mp4',
    'racing_car': '9olKVw7ISx19dC2gl_M4j_minimax-h3.mp4',
    'speedboat': 'OWf94HG91GTwzkYcbhxf1_minimax-h3 (1).mp4',
    'stunt': '3kFvpSzoHLPQvC15dW5tU_minimax-h3.mp4',
    'charge': 'uE_fHp60zUZLY9bdGChr__minimax-h3.mp4',
}
SCENE_BEATS = [0, 10, 20, 30, 40, 50, 60, 72, 82, 92]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ffmpeg', help='Validated encoder; default is bundled imageio FFmpeg 7.1')
    parser.add_argument('--source-dir', type=Path, default=Path.home() / 'Downloads')
    parser.add_argument('--evidence', type=Path, default=ROOT / 'tests/baselines/opening/extended_build')
    args = parser.parse_args()
    if args.ffmpeg:
        encoder = args.ffmpeg
    else:
        import imageio_ffmpeg
        encoder = imageio_ffmpeg.get_ffmpeg_exe()
    work = args.evidence.resolve()
    work.mkdir(parents=True, exist_ok=True)
    sources = {key: args.source_dir / name for key, name in SOURCES.items()}
    for path in sources.values():
        if not path.is_file():
            raise FileNotFoundError(path)
    records, parts = [], []

    def run(arguments):
        subprocess.run([encoder, '-hide_banner', '-loglevel', 'error', '-y', '-filter_complex_threads', '1', *arguments], check=True)

    def normalise(index, duration, start=0):
        return (f'[{index}:v]trim=start={start},setpts=PTS-STARTPTS,'
                'scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,'
                f'setsar=1,fps={FPS},format=yuv420p,tpad=stop_mode=clone:stop_duration=0.2,'
                f'trim=duration={duration},setpts=PTS-STARTPTS,fps={FPS},settb=AVTB')

    def part(inputs, filters, label, name, beats):
        output = work / name
        run([*inputs, '-filter_complex', ';'.join(filters), '-map', f'[{label}]', '-an',
             '-t', str(beats * BEAT), '-c:v', 'libx264', '-crf', '15', '-preset', 'fast', '-pix_fmt', 'yuv420p', str(output)])
        parts.append(output)
        print(f'Encoded {name}', flush=True)

    opening = ['world', 'buggy', 'monster_truck', 'drift', 'racing_car', 'speedboat']
    inputs, filters = [], []
    for i, key in enumerate(opening):
        inputs += ['-i', str(sources[key])]
        duration = (11 if i < 5 else 10) * BEAT
        filters.append(normalise(i, duration) + f'[v{i}]')
        records.append(dict(shot=key, source=SOURCES[key], start_beat=i*10, used_seconds=duration))
    previous = 'v0'
    for i in range(1, len(opening)):
        label = f'blend{i}'
        filters.append(f'[{previous}][v{i}]xfade=transition=fade:duration={BEAT}:offset={i*10*BEAT},fps={FPS},settb=AVTB[{label}]')
        previous = label
    filters.append(f'[{previous}]fade=t=in:st=0:d={BEAT}[intro]')
    part(inputs, filters, 'intro', '01_action.mp4', 60)

    # Animated existing artwork supports the four canonical driver portrait cards.
    inputs, filters = [], []
    for i, name in enumerate(['jump.png', 'jump.png', 'drift.png', 'drift.png']):
        inputs += ['-i', str(OUT / name)]
        zoom = '1.10-on*0.001' if i % 2 else '1.02+on*0.001'
        filters.append(f"[{i}:v]scale=1920:1080,zoompan=z='{zoom}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=45:s=1280x720:fps={FPS},format=yuv420p,setsar=1,settb=AVTB[s{i}]")
        records.append(dict(shot=f'driver_{i}', source=name, start_beat=60+i*3, used_seconds=3*BEAT,
                            sha256=hashlib.sha256((OUT/name).read_bytes()).hexdigest()))
    filters.append('[s0][s1][s2][s3]concat=n=4:v=1:a=0[cards]')
    part(inputs, filters, 'cards', '02_driver_cards.mp4', 12)

    for i, (key, beat) in enumerate([('stunt', 72), ('charge', 82)]):
        part(['-i', str(sources[key])], [normalise(0, 10*BEAT)+'[shot]'], 'shot', f'0{i+3}_{key}.mp4', 10)
        records.append(dict(shot=key, source=SOURCES[key], start_beat=beat, used_seconds=10*BEAT))

    inputs, filters = [], []
    for i, key in enumerate(['monster_truck', 'drift', 'speedboat', 'charge']):
        start = 2.0 if i < 3 else 4.0
        inputs += ['-i', str(sources[key])]
        filters.append(normalise(i, BEAT, start)+f'[c{i}]')
        records.append(dict(shot=f'callback_{key}', source=SOURCES[key], start_beat=92+i,
                            used_seconds=BEAT, source_start_seconds=start))
    filters.append(f'[c0][c1][c2][c3]concat=n=4:v=1:a=0,fade=t=out:st={4*BEAT-.125}:d=0.125[final]')
    part(inputs, filters, 'final', '05_callbacks.mp4', 4)

    listing = work / 'concat.txt'
    listing.write_text(''.join(f"file '{path.as_posix()}'\n" for path in parts), encoding='utf-8')
    candidate = work / 'montage.candidate.ogv'
    run(['-f', 'concat', '-safe', '0', '-i', str(listing), '-an', '-t', str(96*BEAT),
         '-c:v', 'libtheora', '-pix_fmt', 'yuv420p', '-q:v', '8', str(candidate)])
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(candidate)]))
    assert len(metadata['streams']) == 1 and metadata['streams'][0]['codec_type'] == 'video'
    assert metadata['streams'][0]['pix_fmt'] == 'yuv420p'
    assert abs(float(metadata['format']['duration'])-96*BEAT) < .05
    subprocess.run([encoder, '-hide_banner', '-loglevel', 'error', '-xerror', '-i', str(candidate), '-f', 'null', '-'], check=True)
    for record in records:
        record['start_seconds'] = record['start_beat'] * BEAT
        if 'sha256' not in record:
            record['sha256'] = hashlib.sha256((args.source_dir/record['source']).read_bytes()).hexdigest()
    manifest = dict(shots=records, scene_beats=SCENE_BEATS, fade_seconds=BEAT, duration_seconds=96*BEAT,
                    logo_beat=96, logo_seconds=FIRST_BEAT+96*BEAT, not_impact_beat=100, start_prompt_beat=104,
                    audio='removed; opening uses existing shared menu music and impact sound',
                    encoder=encoder, output='montage.ogv', fps=FPS, size=[1280,720])
    (work/'validation.json').write_text(json.dumps(dict(full_decode_passed=True, metadata=metadata), indent=2)+'\n')
    candidate.replace(OUT/'montage.ogv')
    (OUT/'video-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(f'Built and decoded {96*BEAT:.3f}s montage; logo at {FIRST_BEAT+96*BEAT:.3f}s', flush=True)


if __name__ == '__main__':
    main()
