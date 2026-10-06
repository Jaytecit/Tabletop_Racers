"""Promote verified Topspeed geometry and measure its separate source start stripe."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

import numpy as np
from glb_source import Source

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'tests/baselines/content/topspeed_oval/playable_geometry'
BASE = ROOT/'tracks/topspeed_oval'


def main():
    candidate = ROOT/'tests/baselines/content/topspeed_oval/extraction/final'
    render = ROOT/'tests/baselines/content/topspeed_oval/rendered_candidate_final/results.json'
    verified = json.loads(render.read_text())
    if not verified['finished'] or not verified['reports']['passed'] or verified['errors_seen']:
        raise RuntimeError('Rendered candidate verification has not passed')
    if BASE.exists():
        raise RuntimeError('Course already staged; refuse to overwrite canonical measurements')
    manifest = json.loads((candidate/'measurement_manifest_candidate.json').read_text())
    rows = json.loads((candidate/'measured_candidate.json').read_text())
    source = Source(manifest['source'],manifest['transform']['scale'],manifest['transform']['offset'])
    if source.sha256 != manifest['source_sha256']:
        raise RuntimeError('Source hash mismatch')
    # Separate checker meshes identify two drag cues and the oval cue. Use the
    # actual oval node, not an overhead guess or a drag-race starting line.
    stripe = next(p for p in source.primitives if p['name']=='race_start_node001__4_-_Default_0')
    vertices = stripe['vertices']
    midpoint = (vertices.min(0)+vertices.max(0))*0.5
    _, _, vh = np.linalg.svd(vertices[:,[0,2]]-midpoint[[0,2]],full_matrices=False)
    normal = np.array([vh[0,1],-vh[0,0]])
    if normal[0]<0: normal=-normal
    center = np.array([r['center'] for r in rows])
    xy = center[:,[0,2]]
    lengths = np.r_[0,np.cumsum(np.linalg.norm(np.roll(xy,-1,axis=0)-xy,axis=1))]
    projections = (xy-midpoint[[0,2]])@normal
    intersections=[]
    for i in range(len(rows)):
        j=(i+1)%len(rows)
        if projections[i]*projections[j]>0 or abs(projections[i]-projections[j])<1e-10:
            continue
        t=projections[i]/(projections[i]-projections[j])
        point=center[i]*(1-t)+center[j]*t
        intersections.append((float(np.linalg.norm(point-midpoint)),i,t,point))
    distance,index,t,point=min(intersections,key=lambda hit:hit[0])
    if distance>1:
        raise RuntimeError(f'Oval stripe is not at the road centre: {distance}')
    station=float(lengths[index]+t*(lengths[index+1]-lengths[index]))
    tangent=(xy[(index+1)%len(rows)]-xy[index])
    tangent/=np.linalg.norm(tangent)
    # Record the maximum gate-plane/stripe-centre-plane mismatch at measured
    # boundaries. Require it to fit within the stripe's actual horizontal band.
    residuals=[]
    for side in ('left','right'):
        edge=np.array(rows[index][side])*(1-t)+np.array(rows[(index+1)%len(rows)][side])*t
        residuals.append(float(abs((edge[[0,2]]-midpoint[[0,2]])@normal)))
    stripe_half_width=float(np.max(np.abs((vertices[:,[0,2]]-midpoint[[0,2]])@normal)))
    if max(residuals)>stripe_half_width:
        raise RuntimeError('Gate plane does not fit within the measured stripe')
    cue=dict(mesh=stripe['name'],bounds=[vertices.min(0).tolist(),vertices.max(0).tolist()],
             center=midpoint.tolist(),plane_normal_xz=normal.tolist(),start_station=station,
             route_point=point.tolist(),gate_edge_plane_residuals=residuals,
             stripe_half_width=stripe_half_width,
             method='Separate source checker geometry; cumulative GLB transform; PCA stripe plane intersected with candidate centreline')
    OUT.mkdir(parents=True,exist_ok=True)
    backups=OUT/'before'
    backups.mkdir(exist_ok=True)
    for relative in ('scripts/tracks/content_catalog.gd','scripts/tracks/selected_course.gd',
                     'scripts/race/asset_credits.gd','assets/imported/tabletop/CREDITS.md'):
        shutil.copy2(ROOT/relative,backups/Path(relative).name)
    previous={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
              for p in (ROOT/'tracks').glob('*/measured_route.json')}
    (OUT/'accepted_route_hashes_before.json').write_text(json.dumps(previous,indent=2))
    (OUT/'source_start_cue.json').write_text(json.dumps(cue,indent=2))
    names=[p['name'] for p in source.primitives if not p['name'].startswith('sky_')]
    collision=manifest['road_meshes']+['ringoval_shape_cement_0']
    manifest.update(title='Topspeed Oval',description='Raised stadium oval · sweeping curves and long straights',
                    start_station=station,start_cue='Original checker stripe on the lower oval straight; generated same-plane FINISH flags',
                    source_start_cue=cue,visible_meshes=names,collision_meshes=collision,
                    imported_mesh_names={n:n.replace('.','_') for n in names},
                    height_surfaces=manifest['road_meshes'],unresolved_intervals=[],uncertainty=[],
                    sampling_spacing=0.05,source_correspondence_tolerance=0.05,
                    physics_support_tolerance=0.02,section_count=len(rows)//24,route_sample_count=len(rows),
                    source_url=source.doc['asset']['extras']['source'],
                    author=source.doc['asset']['extras']['author'],license=source.doc['asset']['extras']['license'],
                    status='source/rendered geometry accepted; playable verification pending')
    BASE.mkdir()
    (BASE/'measurement_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copy2(candidate/'measured_candidate.json',BASE/'measured_route.json')
    shutil.copy2(candidate/'road_boundaries.json',BASE/'road_boundaries.json')
    asset=ROOT/'assets/imported/tabletop/topspeed_oval.glb'
    if asset.exists(): raise RuntimeError('Imported asset already exists')
    shutil.copy2(manifest['source'],asset)
    (ROOT/'scripts/tracks/author_topspeed_oval.gd').write_text(
        '@tool\nextends RefCounted\nstatic func build() -> Dictionary:\n\treturn load("res://scripts/tracks/author_tabletop.gd").build("topspeed_oval")\n')
    print(json.dumps(dict(start_station=station,source_cue=cue,visible_meshes=len(names),collision_meshes=collision)))


if __name__=='__main__':
    main()
