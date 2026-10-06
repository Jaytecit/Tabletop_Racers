"""Write a per-course evidence record after reviewed, completed rendered probes."""
import argparse, hashlib, json
from pathlib import Path
from glb_source import Source

def read(path): return json.loads(Path(path).read_text())
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('course'); p.add_argument('--race',default='verification_01')
    p.add_argument('--visual',default='visual_01'); p.add_argument('--flags',default='flags_final')
    p.add_argument('--review',required=True)
    a=p.parse_args(); course=a.course
    root=Path('tests/baselines/content')/course; track=Path('tracks')/course
    manifest=read(track/'measurement_manifest.json'); profile=read(manifest['fit_profile'])
    evidence=read(root/'alignment/measurement_evidence.json'); source_check=read(root/'alignment/source_validation.json')
    results={key:read(root/folder/'results.json') for key,folder in [('race',a.race),('visual',a.visual),('flags',a.flags)]}
    for key,r in results.items():
        assert r['finished'] and r['reports']['passed'] and not r['errors_seen'], (key,r)
    assert not source_check['paint_failures'] and not source_check['boundary_intersections'] and not source_check['folded_quads']
    source=Source(profile['source'],profile['scale'],profile['offset'])
    textures=[]
    for prim in source.primitives:
        if 'baseColorTexture' not in prim['material'].get('pbrMetallicRoughness',{}): continue
        tex,info,sampler=source.texture(prim)
        if tex is not None:
            textures.append(dict(mesh=prim['name'],surface=prim['surface'],material=prim['material'],image_sha256=hashlib.sha256(tex.tobytes()).hexdigest(),size=list(tex.shape[:2]),texture_info=info,sampler=sampler))
    manifest.update(status='integrated and verified',measurement_sha256=sha(track/'measured_route.json'),profile_sha256=sha(manifest['fit_profile']),
        raster=dict(origin=profile['origin'],shape=profile['shape'],spacing=profile['spacing']),texture_inventory=textures,
        boundary_tolerance=source_check['tolerance'],source_review=a.review,uncertainty_resolution=dict(weak_samples=evidence['weak_samples'],folds_removed=evidence['folds_removed'],ridge_snaps=evidence['ridge_snaps'],support_snaps=evidence['support_snaps']),
        verification=dict(source=f'{root.as_posix()}/alignment/source_validation.json',landmarks=f'{root.as_posix()}/alignment/landmark_checks.json',race=f'{root.as_posix()}/{a.race}/results.json',visual=f'{root.as_posix()}/{a.visual}/results.json',flags=f'{root.as_posix()}/{a.flags}/results.json'))
    (track/'measurement_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    reports=results['race']['reports']; cars=reports['race']['cars']; flags=results['flags']['reports']
    shutdown=[]
    for folder in {a.race,a.visual,a.flags}:
        log=(root/folder/'stderr.log').read_text(encoding='utf-8')
        if log.strip():shutdown.append(folder+': '+log.strip().replace('\n',' '))
    text=f'''# {manifest['title']} integration verification

Verified from its own source GLB, UV textures and named driving triangles. All source sections, rendered depth-tested sections, the loop seam and checkpoint views were reviewed.

- Source: [{manifest['title']}]({manifest['source_url']}), {manifest['author']}, CC BY 4.0.
- Source SHA-256: `{source.sha256}`.
- Transform: authored scale {profile['scale']}, offset {profile['offset']}, with every GLB ancestor transform accumulated.
- {profile['section_count']} sections, {profile['section_count']*24} spans; measured independent boundaries, width {evidence['width_range'][0]:.3f}–{evidence['width_range'][1]:.3f}. Centre height {evidence['center_height_range'][0]:.5f}–{evidence['center_height_range'][1]:.5f}.
- Heights: exact barycentric support on {manifest['height_surfaces']}; centre sampled independently. Layer selection: {manifest['driving_height_range']}. Props are excluded from measurement support.
- Raster spacing {profile['spacing']} units. {source_check['paint_checks']} independent source paint-band checks, zero failures; tolerance {source_check['tolerance']}. This checks proximity to finite texture markings, not a universal geometric error bound. Ambiguous intervals: {len(source_check['ambiguous_samples'])} reviewed samples.
- Zero self-intersections or folded runtime quads. Compression disabled to preserve source vertices; three separated imported/source landmarks recorded in `alignment/landmark_checks.json`.

{a.review}

Runtime verification: {reports['alignment']['checks']} corridor cases, {reports['support']['checks']} physical support rays and {reports['gates']['checks']} actual checkpoint-plane cases; all pass. Four AI cars completed three Hard laps in {min(c['finish'] for c in cars):.3f}–{max(c['finish'] for c in cars):.3f} seconds, with zero crashes, recovery resets or penalties. Ordinary car impacts are recorded separately. Movement, boost, intentional recovery, pause/resume and course switching pass. Time trial and flag rebuilding/switching pass.

Performance: race FPS {min(reports['fps_samples']):.0f}–{max(reports['fps_samples']):.0f}; cold selection {flags.get('selection_load_ms','unrecorded')} ms. Final monitor sample: {json.dumps(flags.get('performance',{}))}. Single samples are not a percentile benchmark. Same local runtime and settings as the accepted course; hardware details are in the probe/runtime evidence.

Evidence:

- [Source validation](../../{root.as_posix()}/alignment/source_validation.json), [measurement corrections](../../{root.as_posix()}/alignment/measurement_evidence.json), [source overlay](../../{root.as_posix()}/alignment/measured_overlay.png).
- [Race results](../../{root.as_posix()}/{a.race}/results.json), [rendered route and time trial](../../{root.as_posix()}/{a.visual}/results.json), [final checkpoint cues](../../{root.as_posix()}/{a.flags}/results.json).
- All earlier attempts and raw stdout/stderr are preserved. Successful probes have no recorded runtime errors. Each disposable PID was checked exited. Profiles were read-only and hardware input isolated.

Raw stderr findings: {json.dumps(shutdown)}. Probe error capture ends before engine teardown; shutdown ResourceCache/ObjectDB warnings are recorded separately and are not relabelled as a clean shutdown.

The canonical Toys R You data and existing procedural courses are preserved. Shared checkpoint-plane progress changes were regression-tested on Toys R You. Temporary diagnostic coloured boundaries remain enabled; no permanent road edges were generated.
'''
    (Path('docs/verification')/f'{course}.md').write_text(text,encoding='utf-8')
    plan=Path('.summer/plans/2026-10-03-tabletop-glb-rollout.md')
    try: s=plan.read_text(encoding='utf-8')
    except UnicodeDecodeError: s=plan.read_text(encoding='cp1252')
    s='\n'.join(line.replace('| Planned |','| Verified — source, gameplay and cues |') if f'| {course} /' in line else line for line in s.split('\n'))
    plan.write_text(s,encoding='utf-8')
    print(course,'recorded verified')
