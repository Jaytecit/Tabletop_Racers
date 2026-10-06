"""Remove local correspondence folds, then sample the actual mesh heights."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
rows=json.loads((ROOT/'tests/probes/toys_fitted_edges.json').read_text())
e=np.array([[x['left'],x['right']] for x in rows]);N=len(e)
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
# Snap residual low-confidence wood-corner samples onto the nearest tape pixels.
maps=[np.load(ROOT/f'tests/probes/toys_{n}_map.npz') for n in ['road','floor']]
snaps=[]
for i in range(N):
 for side in range(2):
  if e[i,side,1]>.1:continue
  rgb=maps[1 if 36<=i//24<=37 else 0]['rgb']
  xy=(e[i,side,[0,2]]+65)*20
  x,y=np.rint(xy).astype(int)
  if rgb[y,x].min()>205:continue
  yy,xx=np.mgrid[max(0,y-24):min(2600,y+25),max(0,x-24):min(2600,x+25)]
  col=rgb[yy,xx].astype(float)
  white=(col.min(-1)>215)&(col.max(-1)-col.min(-1)<38)
  distance=(xx-xy[0])**2+(yy-xy[1])**2
  if not white.any():continue
  best=np.where(white,distance,np.inf).argmin()
  iy,ix=np.unravel_index(best,white.shape)
  if distance[iy,ix]>24**2:continue
  # Centre the narrow painted strip instead of snapping to its first bright pixel.
  neighborhood=white&((xx-xx[iy,ix])**2+(yy-yy[iy,ix])**2<=9)
  e[i,side,0]=float(xx[neighborhood].mean())/20-65
  e[i,side,2]=float(yy[neighborhood].mean())/20-65
  snaps.append([i,side])
folds=[]
for side in range(2):
 for i in range(N):
  a=e[i,side,[0,2]];b=e[(i+1)%N,side,[0,2]];r=b-a
  for j in range(i+2,min(i+40,N-1)):
   c=e[j,side,[0,2]];d=e[j+1,side,[0,2]];s=d-c
   den=cross(r,s)
   if abs(den)<1e-9:continue
   t=cross(c-a,s)/den;u=cross(c-a,r)/den
   if 0<t<1 and 0<u<1:
    hit=a+t*r
    # Exact intersection, no detached loop in the legal corridor.
    e[i+1:j+1,side,0]=hit[0];e[i+1:j+1,side,2]=hit[1]
    folds.append([side,i,j])
# Keep extracted tape samples; no smoothing that would cut model corners.
meshes=json.loads((ROOT/'tests/probes/toys_mesh_audit.json').read_text())
def heights(points,under):
 out=np.full(len(points),-999.)
 for mi,m in enumerate(meshes[:6]):
  v=np.array(m['vertices']);ids=np.array(m['indices']).reshape(-1,3)
  for tri in v[ids]:
   a=tri[0,[0,2]];b=tri[1,[0,2]];c=tri[2,[0,2]]
   mat=np.stack((b-a,c-a),1)
   if abs(np.linalg.det(mat))<1e-8:continue
   w=(points[:,[0,2]]-a)@np.linalg.inv(mat).T
   inside=(w.min(1)>=-1e-5)&(w.sum(1)<=1+1e-5)
   if mi>=4:inside &= ~under
   y=(1-w.sum(1))*tri[0,1]+w@tri[1:,1]
   inside &= y<4
   out[inside]=np.maximum(out[inside],y[inside])
 assert out.min()>-1,'Missing model surface'
 return out
under=(np.arange(N)//24>=36)&(np.arange(N)//24<=37)
for side in range(2):e[:,side,1]=heights(e[:,side],under)
center=e.mean(1);center[:,1]=heights(center,under)
result=[{'left':e[i,0].tolist(),'right':e[i,1].tolist(),'center':center[i].tolist(),'section':i//24} for i in range(N)]
(ROOT/'tests/probes/toys_measured_route.json').write_text(json.dumps(result))
im=Image.open(ROOT/'tests/probes/toys_road_map.png');dr=ImageDraw.Draw(im)
for side,col in [(0,'cyan'),(1,'magenta')]:
 pts=[tuple((p[[0,2]]+65)*20) for p in e[:,side]]
 dr.line(pts+[pts[0]],fill=col,width=2)
im.save(ROOT/'tests/probes/toys_alignment_final.png')
width=np.linalg.norm(e[:,0,[0,2]]-e[:,1,[0,2]],axis=1)
print(json.dumps({'folds_removed':folds,'width_min':float(width.min()),'width_max':float(width.max()),'height_max':float(center[:,1].max())}))
