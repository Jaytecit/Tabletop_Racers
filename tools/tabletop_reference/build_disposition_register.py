"""Reconcile hashes with preserved survey evidence; do not reread mesh geometry."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / 'tests/baselines/content/glb_folder_audit'

def main():
    inventory = {r['file']: r for r in json.loads((AUDIT / 'inventory.json').read_text())}
    original_files = set(inventory)
    current_files = {p.name for p in (ROOT / 'tracks/GLB Tracks').glob('*.glb')}
    if not original_files <= current_files:
        raise ValueError('Previously surveyed sources missing: '+str(sorted(original_files-current_files)))
    rerun = json.loads((AUDIT / 'free_fire_triangle_rerun/inventory.json').read_text())
    inventory.update({r['file']: r for r in rerun})
    for extra in (AUDIT / 'additions_20261005').glob('*/inventory.json'):
        inventory.update({r['file']:r for r in json.loads(extra.read_text())})
    topology = {r['file']: r for r in json.loads((AUDIT / 'road_topology.json').read_text())}
    survey = (ROOT / 'docs/glb-track-usability-audit.md').read_text(encoding='utf-8')
    descriptions = {m[0]: (m[1], m[2]) for m in re.findall(r'\| `([^`]+\.glb)` \| ([^|]+) \| ([^|]+) \|', survey)}
    active = ['toys_r_you','toys_r_asleep','rusty_nuts_workshop','moonlight_junk_heap','firefly_bbq','nighttime_noodles','mount_rainier','topspeed_oval','bazaar','town_square']
    accepted = {}
    for course in active:
        path = ROOT / 'assets/imported/tabletop' / (course + '.glb')
        accepted[hashlib.sha256(path.read_bytes()).hexdigest()] = course
    rows, seen = [], {}
    for path in sorted((ROOT / 'tracks/GLB Tracks').glob('*.glb'),key=lambda p: (' (1)' in p.name,p.name)):
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        old = inventory.get(path.name)
        if not old or old['sha256'] != sha:
            raise ValueError(f'Source changed; targeted re-survey required: {path.name}')
        label, reason = descriptions.get(path.name, ('New circuit candidate', 'New source: select driving primitives, review topology/layers/start cue, and measure width before extraction.'))
        course = accepted.get(sha)
        duplicate = seen.get(sha)
        if course:
            status = 'active'
        elif duplicate:
            status = 'duplicate'
        elif path.name == 'town_square_track.glb':
            status = 'ready-for-extraction'
        elif 'beach_buggies' in path.name:
            status = 'archived-unusable'
            reason = 'Owner-retired, not geometrically unusable. Retained inactive; reinstatement requires a new request.'
        elif any(word in label.lower() for word in ('environment', 'network')):
            status = 'authored-route-required'
        else:
            status = 'needs-repair'
        # needs-repair includes unresolved classification/seams/layers, not proven unusability.
        seen.setdefault(sha, path.name)
        measured = ROOT / 'tracks' / str(course) / 'measured_route.json'
        width = None
        layers = None
        jumps = None
        if course:
            definition = (ROOT / 'tracks' / course / 'definition.tres').read_text(encoding='utf-8')
            layers = sorted({0, *[int(n) for n in re.findall(r'^layer = (\d+)',definition,re.M)]})
            jumps = bool(re.search(r'^jump_exit = true',definition,re.M))
        if measured.exists():
            samples = json.loads(measured.read_text())
            widths = [sum((a-b)**2 for a,b in zip(r['left'],r['right']))**0.5 for r in samples]
            width = {'min':min(widths),'max':max(widths),'unit':'game units; accepted samples'}
            manifest = ROOT / 'tracks' / course / 'measurement_manifest.json'
            if manifest.exists():
                data = json.loads(manifest.read_text())
                layers = data.get('section_layers', data.get('layers',layers))
        mode_list = ['quick','trial','freestyle','challenge','time_attack','elimination'] if course else []
        if course == 'town_square': mode_list = ['quick','trial','freestyle']
        if course and course not in ['bazaar','town_square']: mode_list.append('tournament')
        if course == 'bazaar': mode_list.append('drift')
        extras = old['metadata'].get('extras', {})
        branch = 'dedicated/layer-aware road' if path.name in topology else 'surface/UV classification then selected route'
        if course and course not in ['mount_rainier','topspeed_oval','bazaar','town_square']: branch = 'UV/paint'
        row = dict(file=path.name,sha256=sha,status=status,reason=reason.strip(),duplicate_of=duplicate,
                   course_id=course,megabytes=old['megabytes'],triangles=old.get('triangles'),meshes=old['meshes'],
                   images=len(old['images']),rgba_level_bytes=sum(im['size'][0]*im['size'][1]*4 for im in old['images'] if 'size' in im),
                   route_type=label.strip(),physical_support='accepted course evidence' if course else 'unverified',
                   layers=layers,usable_width=width,credits=extras,extraction_branch=branch,topology=topology.get(path.name),
                   capabilities=dict(modes=mode_list,vehicles=['buggy','monster_truck','racing_car','drift_car','speedboat'] if course else [],
                                     loft=False,crossings_jumps={'layers':layers,'jump_exit':jumps} if course else None,
                                     readiness='accepted route; existing enabled modes, target balance pending' if course else 'not registered'),
                   evidence=f'tests/baselines/content/glb_folder_audit/{path.stem}_plan.png' if path.name in descriptions else f'tests/baselines/content/glb_folder_audit/additions_20261005/{path.stem}/{path.stem}_plan.png')
        rows.append(row)
        if course == 'town_square':
            row['reason'] = 'Independent road boundaries/heights, support, ordered checkpoints, clean Hard races, five-class Freestyle and selector/loading verified. Other modes pending course trials.'
            row['evidence'] = 'docs/verification/town_square.md'
        if path.name.startswith('free_fire_'):
            row['evidence'] = f'tests/baselines/content/glb_folder_audit/free_fire_triangle_rerun/{path.stem}_plan.png'
    output = ROOT / 'docs/glb-track-disposition.json'
    output.write_text(json.dumps(dict(schema=1,source_count=len(rows),unique_hashes=len(seen),rows=rows),indent=2)+'\n',encoding='utf-8')
    lines = ['# GLB source disposition register', '',
             f'Reconciled 5 October 2026: {len(rows)} files, {len(seen)} unique sources. All original 37 hashes match; only the five added sources received targeted geometry/texture surveys. Original failures and reruns remain preserved.', '',
             'The [machine-readable register](glb-track-disposition.json) contains complete hashes, credits, cost estimates, topology evidence, sampled widths, capability metadata and reasons. Unknown width/layers are explicit null values; they are not assumed flat or playable. Decoded RGBA costs exclude mipmaps/compression/deduplication and are not measured resident memory.', '',
             '`needs-repair` means classification, seams or layers need work; it does not assert a damaged or unusable model. `authored-route-required` needs an explicit circuit choice. Town Square is integrated for Quick Race, Time Trial and Freestyle; additional mode trials remain pending. Beach Buggies is owner-retired and retained inactive, not rejected geometry.', '',
             'No new source is confirmed unusable. No sources moved or deleted. The duplicate Silverstone file stays recoverable and both names resolve to one identity. Source GLBs already sit outside catalogue dependencies and are excluded by the Windows export preset. Sources, metadata and failed audit evidence remain intact.', '',
             'Mode capability is independent of category. Only accepted routes enter the runtime capability table; current mode availability is preserved. Full per-course mode balance/physical coverage remains pending. Loft is disabled pending Task 10. Procedural Roulette is active separately and has no GLB source row.', '',
             '| Source | Status | Triangles / source MB | Route/support and next gate |', '|---|---|---|---|']
    for r in rows:
        lines.append(f"| `{r['file']}` | {r['status']} | {r['triangles']:,} / {r['megabytes']} | {r['reason']} |")
    (ROOT / 'docs/glb-track-disposition.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps({'sources':len(rows),'unique':len(seen),'statuses':{s:sum(r['status']==s for r in rows) for s in sorted({r['status'] for r in rows})}}))

if __name__ == '__main__':
    main()
