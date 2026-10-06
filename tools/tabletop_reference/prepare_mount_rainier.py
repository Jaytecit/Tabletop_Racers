"""Pair independent asphalt rings monotonically and stage Mount Rainier only."""
import json, shutil
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import Polygon, LineString, Point
from shapely.ops import unary_union
from glb_source import Source

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT/'tracks/mount_rainier'
OUT = ROOT/'tests/baselines/content/mount_rainier/playable_geometry'

def main(replace=False):
    if (BASE/'measured_route.json').exists() and not replace:
        raise RuntimeError('Measured route already exists; use --replace only for intentional remeasurement')
    OUT.mkdir(parents=True,exist_ok=True)
    manifest = json.loads((BASE/'measurement_manifest.json').read_text())
    backup = OUT/'original_geometry_manifest.json'
    if not backup.exists(): shutil.copy2(BASE/'measurement_manifest.json',backup)
    source = Source(manifest['source'],manifest['transform']['scale'],manifest['transform']['offset'])
    selected = [p for p in source.primitives if p['name'] in manifest['road_meshes']]
    tris = np.concatenate([p['vertices'][p['indices']] for p in selected])
    xy = tris[:,:,[0,2]]
    road = unary_union([Polygon(t) for t in xy if Polygon(t).area>1e-10])
    # Rotate both independently measured rings to the same southwest straight.
    rings=[]
    for ring in [road.exterior,road.interiors[0]]:
        coords=np.array(ring.coords)[:-1]
        if Polygon(coords).exterior.is_ccw: coords=coords[::-1]
        start=np.argmin(np.linalg.norm(coords-np.array([-65.,92.]),axis=1))
        coords=np.roll(coords,-start,axis=0)
        rings.append(LineString(np.vstack([coords,coords[0]])))
    a,b=rings
    na,nb=int(np.ceil(a.length/.65)),int(np.ceil(b.length/.65))
    sa=np.linspace(0,a.length,na+1); sb=np.linspace(0,b.length,nb+1)
    aa=np.array([a.interpolate(s).coords[0] for s in sa]); bb=np.array([b.interpolate(s).coords[0] for s in sb])
    # DTW respects traversal order; transverse distances cannot jump across hairpins.
    costs=np.full((na+1,nb+1),np.inf); steps=np.zeros((na+1,nb+1),np.uint8)
    costs[0,0]=np.sum((aa[0]-bb[0])**2)
    for i in range(na+1):
        for j in range(max(0,int(i*nb/na)-100),min(nb+1,int(i*nb/na)+101)):
            if i==0 and j==0: continue
            options=[costs[i-1,j-1] if i and j else np.inf,
                     costs[i-1,j]+.15 if i else np.inf,costs[i,j-1]+.15 if j else np.inf]
            k=int(np.argmin(options));steps[i,j]=k
            costs[i,j]=options[k]+np.sum((aa[i]-bb[j])**2)
    assert np.isfinite(costs[-1,-1])
    path=[];i,j=na,nb
    while i or j:
        path.append((i,j)); k=steps[i,j]
        if k==0:i-=1;j-=1
        elif k==1:i-=1
        else:j-=1
    path.append((0,0));path=np.array(path[::-1])
    centers=(aa[path[:,0]]+bb[path[:,1]])*.5
    lengths=np.r_[0,np.cumsum(np.linalg.norm(np.diff(centers,axis=0),axis=1))]
    count=int(np.ceil(lengths[-1]/.32/24))*24
    stations=np.linspace(0,lengths[-1],count,endpoint=False)
    # Smoothing only the correspondence guide, never the source boundary rings.
    left_s=np.interp(stations,lengths,sa[path[:,0]])
    right_s=np.interp(stations,lengths,sb[path[:,1]])
    left=np.array([a.interpolate(s).coords[0] for s in left_s])
    right=np.array([b.interpolate(s).coords[0] for s in right_s])
    center=(left+right)*.5
    # Anatomical side identity from forward tangent.
    tangent=np.roll(center,-1,axis=0)-np.roll(center,1,axis=0)
    side=tangent[:,0]*(left-center)[:,1]-tangent[:,1]*(left-center)[:,0]
    if np.median(side)<0:left,right=right,left
    low,high=xy.min(1),xy.max(1)
    def height(q):
        hits=[]
        for k in np.where(np.all(q>=low-1e-6,axis=1)&np.all(q<=high+1e-6,axis=1))[0]:
            t=xy[k];m=np.stack([t[1]-t[0],t[2]-t[0]],axis=1)
            if abs(np.linalg.det(m))<1e-9:continue
            w=np.linalg.solve(m,q-t[0]);weights=np.array([1-w.sum(),*w])
            if weights.min()>=-1e-5:hits.append(float(weights@tris[k,:,1]))
        if not hits:raise ValueError(f'Missing intended road height {q}')
        assert max(hits)-min(hits)<.02
        return max(hits)
    rows=[];bad=[];residuals=[]
    for k in range(count):
        nxt=(k+1)%count
        quad=Polygon([left[k],left[nxt],right[nxt],right[k]])
        if not quad.is_valid or quad.area<1e-8:bad.append(k)
        # Independent comparison against the original asphalt polygon.
        for t in [.04,.5,.96]:
            p=(left[k]+left[nxt])*.5*(1-t)+(right[k]+right[nxt])*.5*t
            if not road.buffer(.001).covers(Point(p)):bad.append([k,t])
        for edge in [left,right]:
            residuals.append(road.boundary.distance(Point((edge[k]+edge[nxt])*.5)))
        rows.append(dict(left=[float(left[k,0]),height(left[k]),float(left[k,1])],
                         right=[float(right[k,0]),height(right[k]),float(right[k,1])],
                         center=[float(center[k,0]),height(center[k]),float(center[k,1])],section=k//24))
    checks=dict(rows=count,sections=count//24,length=lengths[-1],bad_polygons=bad,
                max_span_boundary_residual=max(residuals),boundary_residual_p99=float(np.percentile(residuals,99)))
    (OUT/'pairing_checks.json').write_text(json.dumps(checks,indent=2))
    print(checks)
    assert not bad, 'Resolve folded/source-exterior polygons before authoring'
    (BASE/'measured_route.json').write_text(json.dumps(rows,separators=(',',':')))
    names=[p['name'] for p in source.primitives if not p['name'].startswith('lens_')]
    collision=manifest['road_meshes']+[p['name'] for p in source.primitives if p['name'].startswith(('env.001_','env.002_','env.004_','env_assets.002_'))]
    manifest.update(description='Mountain road circuit · sweeping bends, hillside climbs and tight hairpins',
        revision=1,start_station=0.,source_url=source.doc['asset']['extras']['source'],
        visible_meshes=names,collision_meshes=collision,section_surfaces=['wood']*(count//24),
        section_layers=[0]*(count//24),height_surfaces=manifest['road_meshes'],
        imported_mesh_names={n:n.replace('.','_') for n in names},mesh_compression=False,
        route_direction='clockwise in X/Z plan',unresolved_intervals=[],
        start_cue='Generated FINISH flags on southwest straight; source road has no dedicated START arch',
        surface_note='Neutral existing wood handling preset for asphalt; no shared handling change',
        status='geometry paired; rendered gameplay verification pending')
    (BASE/'measurement_manifest.json').write_text(json.dumps(manifest,indent=2))
    # Existing author applies the recorded transform to the original GLB once.
    shutil.copy2(manifest['source'],ROOT/'assets/imported/tabletop/mount_rainier.glb')
    # Disable geometry compression consistently with the accepted import method.
    image=Image.open(ROOT/'tests/baselines/content/mount_rainier/road_source.png')
    draw=ImageDraw.Draw(image)
    def pixels(points):
        pts=(points-np.array([manifest['transform']['offset'][0],manifest['transform']['offset'][2]]))/manifest['transform']['scale']
        return [tuple(q) for q in (pts-np.array([-700,-600]))/.5]
    for edge,color in [(left,'cyan'),(right,'magenta'),(center,'yellow')]:draw.line(pixels(np.vstack([edge,edge[0]])),fill=color,width=2)
    image.save(OUT/'paired_route.png')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--replace',action='store_true')
    main(parser.parse_args().replace)
