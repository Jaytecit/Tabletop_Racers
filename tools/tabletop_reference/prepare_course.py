"""Stage reviewed course measurements and reuse the measured-route runtime."""
import argparse,json,shutil,re
from pathlib import Path
from glb_source import Source

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('course');p.add_argument('--title',required=True);p.add_argument('--description',required=True);p.add_argument('--direction',required=True)
    a=p.parse_args();c=a.course
    profile=json.loads(Path(f'tools/tabletop_reference/profiles/{c}.json').read_text());out=Path(profile['output'])
    source=Source(profile['source'],profile['scale'],profile['offset']);e=json.loads((out/'measurement_evidence.json').read_text());rows=json.loads((out/'measured_candidate.json').read_text())
    labels=profile['source_surface_labels'];floor=profile['maps'][Path(profile['fit_map']).stem]['surfaces']
    surfaces=[labels[e['center_surface_names'][i*24+12]] for i in range(profile['section_count'])]
    surfaces=profile.get('section_surfaces',surfaces)
    manifest=dict(title=a.title,description=a.description,revision=1,start_station=0.,source_sha256=source.sha256,source=str(source.path),source_url=source.doc['asset']['extras']['source'],author='amogusstrikesback2',license='CC BY 4.0',transform=dict(scale=profile['scale'],offset=profile['offset']),visible_meshes=profile['maps']['all_visible']['surfaces'],collision_meshes=profile.get('collision_meshes',[x['name'] for x in source.primitives]),section_surfaces=surfaces,section_layers=profile.get('section_layers',[0]*profile['section_count']),height_surfaces=floor,fit_profile=f'tools/tabletop_reference/profiles/{c}.json',source_surface_labels=labels,mesh_compression=False,driving_height_range=profile['driving_height_range'],sampling_spacing=profile['spacing'],route_direction=a.direction,uncertain_sections=profile.get('ambiguous_source_sections',[]),unresolved_intervals=[],status='source reviewed; runtime pending')
    track=Path('tracks')/c;track.mkdir(exist_ok=True);(track/'measurement_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');shutil.copy2(out/'measured_candidate.json',track/'measured_route.json')
    shutil.copy2(source.path,Path('assets/imported/tabletop')/f'{c}.glb')
    Path(f'scripts/tracks/author_{c}.gd').write_text(f'@tool\nextends RefCounted\nstatic func build() -> Dictionary:\n\treturn load("res://scripts/tracks/author_tabletop.gd").build("{c}")\n')
    for suffix in ['live','alignment_checks','verification','visual_verification','flags_final','checks_verification']:
        s=Path(f'tests/probes/rusty_nuts_workshop_{suffix}.gd').read_text().replace('rusty_nuts_workshop',c)
        if suffix=='visual_verification':
            start=s.index('\treport("toys_regression"');end=s.index('\treport("failures",failures)',start)
            s=s[:start]+s[end:];s=s.replace(' and _reports.toys_regression.failures.is_empty()','')
            s=s.replace('\treport("select",helper.select_course())','\tvar select_start: int = Time.get_ticks_msec()\n\treport("select",helper.select_course())\n\treport("selection_load_ms",Time.get_ticks_msec()-select_start)')
            s=s.replace('\tsave_frame("time_trial_driving")','\treport("performance",helper.performance_report())\n\treport("fps",Performance.get_monitor(Performance.TIME_FPS))\n\treport("render_cpu_ms",Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)\n\tsave_frame("time_trial_driving")')
        Path(f'tests/probes/{c}_{suffix}.gd').write_text(s)
    path=Path('scripts/tracks/content_catalog.gd');s=path.read_text(encoding='utf-8')
    if f'"{c}"' not in s:
        s=re.sub(r'(const IDS: Array\[String\] = \[)([^\n]*)(\])',lambda m:m[1]+m[2]+f',"{c}"'+m[3],s)
        s=re.sub(r'(if id in \["toys_r_you")([^\n]*)(\]: theme)',lambda m:m[1]+m[2]+f',"{c}"'+m[3],s)
    path.write_text(s,encoding='utf-8')
    path=Path('scripts/tracks/selected_course.gd');s=path.read_text(encoding='utf-8')
    if f'"{a.title}"' not in s:
        s=re.sub(r'(.*\["Roulette Grand Prix"[^\n]*)(\])',lambda m:m[1]+f',"{a.title}"'+m[2],s)
    path.write_text(s,encoding='utf-8')
    # Future additions append to the actual last item rather than disturbing earlier indices.
    if c not in json.loads('['+Path('scripts/tracks/content_catalog.gd').read_text().split('const IDS: Array[String] = [')[1].split(']')[0]+']'):raise RuntimeError('catalogue append failed')
    title=source.doc['asset']['extras']['title'];url=manifest['source_url']
    paragraph=f'{a.title} — “{title}”\nSource: {url}\nBy amogusstrikesback2, https://sketchfab.com/amogusstrikesback2\nCC BY 4.0, https://creativecommons.org/licenses/by/4.0/\nAdapted for Felt & Fury: scaled, baked materials preserved, collision, measured route and checkpoint cues added.\nNo endorsement by the original creator is implied.'
    path=Path('scripts/race/asset_credits.gd');s=path.read_text(encoding='utf-8')
    if url not in s:s=s.replace('implied."""\nstatic func setup','implied.\n\n'+paragraph+'"""\nstatic func setup')
    path.write_text(s,encoding='utf-8')
    path=Path('assets/imported/tabletop/CREDITS.md')
    if url not in path.read_text(encoding='utf-8'):
        with path.open('a',encoding='utf-8') as f:f.write('\n\n## '+a.title+'\n\n'+paragraph+'\n')
    print(c,len(rows),'samples staged')
