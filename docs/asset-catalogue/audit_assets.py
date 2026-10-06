"""Inventory installed project files without loading third-party scripts or moving assets."""
from pathlib import Path
import collections, csv, hashlib, json, os, re

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SKIP = {'.godot', '.git', '.summer', '.assetmanager', '__MACOSX', '__pycache__', 'archive', 'replays', 'screenshots', 'tests', 'docs', 'tools', 'marketing', 'builds'}
MEDIA = {'.glb':'models','.gltf':'models','.fbx':'models','.obj':'models',
         '.png':'images','.jpg':'images','.jpeg':'images','.svg':'images','.webp':'images',
         '.tga':'images','.bmp':'images','.wav':'sounds','.ogg':'sounds','.mp3':'sounds',
         '.hdr':'hdris','.exr':'images','.ogv':'videos','.gdshader':'shaders','.tscn':'scenes'}
TEXT = {'.gd','.tscn','.tres','.godot','.gdshader','.cfg','.json','.gltf'}
files = []
for folder, directories, names in os.walk(ROOT):
    directories[:] = [name for name in directories if name not in SKIP]
    files.extend(Path(folder)/name for name in names if not name.startswith('.')
                 and Path(name).suffix not in {'.uid','.import','.bak'})
files.sort()
print('Inventory:',len(files),'source/support files',flush=True)
rel = {p.relative_to(ROOT).as_posix(): p for p in files}
contents = {r:p.read_text(encoding='utf-8',errors='replace') for r,p in rel.items() if p.suffix in TEXT}
print('Source text loaded',flush=True)
refs = {r:set(re.findall(r'res://([^"\n]+)',s)) for r,s in contents.items()}
print('References extracted',flush=True)
active_ids = re.search(r'const IDS: Array\[String\] = \[(.*?)\]', (ROOT/'scripts/tracks/content_catalog.gd').read_text()).group(1)
active_ids = re.findall(r'"([^"]+)"', active_ids)
reachable, pending = set(), ['scenes/app.tscn'] + ['tracks/%s/entry.tres' % course for course in active_ids]
while pending:
    r = pending.pop()
    if r in reachable: continue
    reachable.add(r)
    pending.extend(refs.get(r,set()) - reachable)

def family(r):
    if r.startswith('addons/'): return '/'.join(r.split('/')[:2])
    if r.startswith('Textures/Kenney Particles/'): return 'Kenney particle textures'
    if r.startswith('Textures/Checkers/'): return 'Checker textures'
    if r.startswith('Sound FX Starter Pack Vol. 1/'): return 'Sound FX Starter Pack Vol. 1'
    if r.startswith(('Models/','scripts/Duvet/','scripts/Flos/','scripts/Pogo/','scripts/Zoom/','scripts/Tools/','scripts/Singletons/')): return 'Vehicle/demo imports (mixed provenance)'
    return r.split('/')[0] if '/' in r else 'Root files (mixed provenance)'

def decision(r):
    low = r.lower()
    if r in reachable: return 'current', 'Static reference reachable from main scene; dynamic references require separate verification.'
    if r.startswith('assets/'): return 'retain', 'Project-authored art; retain for its matching environment/UI.'
    if r.startswith('audio/'): return 'retain', 'Existing racing audio; music is documented as temporary CC0.'
    if r.startswith(('environments/','tracks/','scripts/tracks/','scripts/race/','scripts/vehicles/','scripts/app/')):
        return 'retain', 'Project course, runtime or authoring resource; static reachability alone cannot prove dynamic use.'
    if 'sound fx starter' in low:
        if any(x in low for x in ['/ui & menus/','/jingles & stingers/','/retro/']):
            return 'candidate', 'Audition for menu/countdown/results/boost.'
        return 'defer', 'Genre SFX or ambience; use only for a matching course/event after audition.'
    if 'kenney particles' in low:
        if any(x in low for x in ['smoke','spark','trace','circle']): return 'candidate', 'Smoke, dust, impacts or boost; verify camera readability.'
        return 'defer', 'Effect texture outside current racing needs.'
    if r.startswith('Models/vehicle-'): return 'candidate', 'Toy vehicle visual candidate; retain arcade controller and verify scale and silhouette.'
    if r.startswith(('Shaders/EA_','Materials/EA_Water')): return 'candidate', 'Water rendering: documented 4.7+, Forward+/Mobile, depth geometry required; profile first.'
    if 'checkers' in low: return 'defer', 'Prototype ground patterns; authored cloth/wood/felt remains the art target.'
    if r.startswith('addons/'):
        if any(x in low for x in ['asset_manager/','debug_draw_3d/','godot_mcp_toolkit/']): return 'tooling', 'Editor/development tooling; keep separate from race assets.'
        if any(x in low for x in ['music_controller/','ui_sound_controller/','scene_loader/','universalfade/']): return 'defer', 'Useful reference, but current race/app systems already cover this role.'
        if any(x in low for x in ['terrain_3d/','road-generator/','godot-rapier2d/','godot_retro/','game_template/']): return 'defer', 'Optional subsystem/demo; no wholesale integration justified for current miniature arcade racing.'
        return 'tooling', 'Installed addon support file; evaluate only when needed.'
    return 'defer', 'Imported demo, support resource or legacy file; no new production use established.'

rows=[]
hashes=collections.defaultdict(list)
notice_cache={}
for r,p in rel.items():
    typ=MEDIA.get(p.suffix,'other')
    if p.suffix=='.tres':
        header=contents.get(r,'')[:300]
        typ='themes' if 'type="Theme"' in header else 'materials' if any(t in header for t in ['type="StandardMaterial3D"','type="ORMMaterial3D"','type="ShaderMaterial"']) else 'other'
    if typ=='sounds' and '/music/' in '/'+r.lower(): typ='music'
    status,reason=decision(r)
    digest=hashlib.sha256(p.read_bytes()).hexdigest()
    hashes[digest].append(r)
    licenses=[]
    parent=p.parent
    while parent!=ROOT and ROOT in parent.parents:
        if parent not in notice_cache:
            notice_cache[parent]=[x.relative_to(ROOT).as_posix() for x in parent.iterdir()
                                  if ('license' in x.name.lower() or x.name.lower()=='credits.md') and x.is_file()]
        licenses += notice_cache[parent]
        parent=parent.parent
    rows.append({'path':r,'type':typ,'family':family(r),'bytes':p.stat().st_size,'sha256':digest,
                 'status':status,'reason':reason,'licence_declared':'See source-specific notices',
                 'licence_confirmation':'Historical owner CC0 statement retained; imported metadata and scoped notices recorded separately.',
                 'licence_evidence':'; '.join(licenses) or 'No scoped local notice found; see docs/credits.md and preserved source-pack notices.'})
OUT.mkdir(exist_ok=True)
with (OUT/'inventory.csv').open('w',newline='',encoding='utf-8-sig') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
entries=[{'path':str(ROOT.joinpath(row['path'])).replace('\\','/'),'type':row['type'],
          'tags':['room_run',row['status'],re.sub(r'[^a-z0-9]+','_',row['family'].lower()).strip('_')]}
         for row in rows]
(OUT/'manager-entries.json').write_text(json.dumps(entries,indent=2),encoding='utf-8')
duplicates=[v for v in hashes.values() if len(v)>1]
summary={'files':len(rows),'bytes':sum(r['bytes'] for r in rows),'types':dict(collections.Counter(r['type'] for r in rows)),
         'licence_confirmation':'See scoped source notices and docs/credits.md; no blanket licence asserted.',
         'active_courses':active_ids,
         'statuses':dict(collections.Counter(r['status'] for r in rows)),
         'families':dict(collections.Counter(r['family'] for r in rows)),
         'duplicate_groups':duplicates,'reachable_paths':sorted(reachable),
         'missing_literal_references':sorted({x for r in reachable for x in refs.get(r,[]) if x not in rel and not ROOT.joinpath(x).is_dir() and not any(c in x for c in ['%','+','{'])})}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k not in {'duplicate_groups','reachable_paths','missing_literal_references'}},indent=2))
print('Duplicate groups:',len(duplicates),'Missing literal references:',summary['missing_literal_references'])
