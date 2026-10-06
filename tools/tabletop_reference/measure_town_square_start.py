"""Measure original UV checker band against the independently extracted route."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
base = ROOT/'tests/baselines/content/town_square'
data = np.load(base/'source01/road-raster.npz')
rgb = data['rgb']
# Reviewed eastern-straight checker band. Mask excludes kerbs, roofs and shadows.
pixels = []
for x in range(1380,1495):
    expected = 1038 - 0.04*(x-1400)
    for y in range(int(expected)-7,int(expected)+8):
        if rgb[y,x].max() < 95:
            pixels.append([x,y])
pixels = np.array(pixels)
coeff = np.polyfit(pixels[:,0],pixels[:,1],1)
residual = pixels[:,1]-np.polyval(coeff,pixels[:,0])
assert np.quantile(np.abs(residual),.95) < 6
native = data['origin'] + pixels*float(data['spacing'])
slope = float(coeff[0])
normal = np.array([-slope,1.]); normal /= np.linalg.norm(normal)
native_midpoint = data['origin']+np.array([pixels[:,0].mean(),np.polyval(coeff,pixels[:,0].mean())])*float(data['spacing'])
candidate = base/'extraction01'
manifest = json.loads((candidate/'measurement_manifest_candidate.json').read_text())
scale = manifest['transform']['scale']
offset = np.array(manifest['transform']['offset'])
midpoint = native_midpoint*scale+offset[[0,2]]
rows = json.loads((candidate/'measured_candidate.json').read_text())
center = np.array([r['center'] for r in rows])[:,[0,2]]
delta = np.roll(center,-1,axis=0)-center
lengths = np.r_[0.,np.cumsum(np.linalg.norm(delta,axis=1))]
solutions = []
for i,d in enumerate(delta):
    denom = d@normal
    if abs(denom)<1e-9: continue
    t = (midpoint-center[i])@normal/denom
    if 0<=t<=1:
        p = center[i]+d*t
        solutions.append((np.linalg.norm(p-midpoint),i,float(t),p))
distance,i,t,point = min(solutions,key=lambda q:q[0])
assert distance < 2
direction = delta[i]/np.linalg.norm(delta[i])
station = float(lengths[i]+t*np.linalg.norm(delta[i]))
def sample(s):
    s %= lengths[-1]
    j = min(len(rows)-1, int(np.searchsorted(lengths,s,side='right')-1))
    return center[j]+delta[j]*(s-lengths[j])/(lengths[j+1]-lengths[j])
direction = sample(station+0.25)-sample(station-0.25)
direction /= np.linalg.norm(direction)
left = np.array(rows[i]['left'])+(np.array(rows[(i+1)%len(rows)]['left'])-rows[i]['left'])*t
right = np.array(rows[i]['right'])+(np.array(rows[(i+1)%len(rows)]['right'])-rows[i]['right'])*t
# Intersect actual gameplay timing plane with measured cross-section boundaries.
edges = []
for key in ('left','right'):
    for j in range(len(rows)):
        a=np.array(rows[j][key])[[0,2]]; b=np.array(rows[(j+1)%len(rows)][key])[[0,2]]
        denominator=(b-a)@direction
        if abs(denominator)<1e-9: continue
        u=(point-a)@direction/denominator
        if 0<=u<=1: edges.append((np.linalg.norm(a+(b-a)*u-point),a+(b-a)*u))
edges=sorted(edges,key=lambda q:q[0])[:2]
plane_residuals=[float(abs((q-point)@normal)) for _,q in edges]
half_width=float(np.quantile(np.abs(residual),.98)*float(data['spacing'])*scale/np.sqrt(1+slope*slope))
assert max(plane_residuals) < half_width
cue=dict(source_sha256=manifest['source_sha256'],start_station=station,
         source_midpoint_xz=native_midpoint.tolist(),game_position_xz=point.tolist(),
         stripe_normal_xz=normal.tolist(),direction_xz=direction.tolist(),
         gate_edge_plane_residuals=plane_residuals,stripe_half_width=half_width,
         source_analysis_spacing=float(data['spacing']),game_analysis_spacing=float(data['spacing'])*scale,
         pixels=len(pixels),method='Reviewed UV checker mask; least-squares band midplane, centreline intersection and actual gate-plane boundary residuals')
(candidate/'source_start_cue.json').write_text(json.dumps(cue,indent=2)+'\n')
print(json.dumps(cue))
