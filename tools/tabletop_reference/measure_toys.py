"""Inspect baked road markings in model coordinates, without camera tracing."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
meshes=json.loads((ROOT/'tests/probes/toys_mesh_audit.json').read_text())
N=2600
S=20
offset=np.array([65.,65.])
rgb=np.zeros((N,N,3),np.uint8)
heights=np.full((N,N),-999.,np.float32)
for mi,m in enumerate(meshes):
 if mi==4:
  np.savez(ROOT/'tests/probes/toys_floor_map.npz',rgb=rgb.copy(),heights=heights.copy())
 if mi>5: continue
 texid=[0,1,2,3,4,4][mi]
 tex=np.asarray(Image.open(ROOT/f'assets/imported/tabletop/toys_r_you_{texid}.png').convert('RGB'))
 v=np.array(m['vertices']);uv=np.array(m['uvs']);idx=np.array(m['indices']).reshape(-1,3)
 for ids in idx:
  p=v[ids];xz=p[:,[0,2]]
  # Ground and upper faces only.
  normal=np.cross(p[1]-p[0],p[2]-p[0])
  if abs(normal[1])<1e-5: continue
  xy=(xz+offset)*S
  lo=np.maximum(np.floor(xy.min(0)).astype(int),0);hi=np.minimum(np.ceil(xy.max(0)).astype(int)+1,N)
  if np.any(hi<=lo):continue
  yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]]
  q=np.stack((xx,yy),-1)
  mat=np.stack((xy[1]-xy[0],xy[2]-xy[0]),axis=1)
  b=(q-xy[0])@np.linalg.inv(mat).T
  weights=np.concatenate((1-b.sum(-1,keepdims=True),b),axis=-1)
  h=weights@p[:,1]
  mask=(weights.min(-1)>=-1e-6)&(h>=heights[yy,xx])
  tc=weights@uv[ids]
  tx=np.clip((tc[...,0]*tex.shape[1]).astype(int),0,tex.shape[1]-1)
  ty=np.clip((tc[...,1]*tex.shape[0]).astype(int),0,tex.shape[0]-1)
  rgb[yy[mask],xx[mask]]=tex[ty[mask],tx[mask]]
  heights[yy[mask],xx[mask]]=h[mask]
np.savez(ROOT/'tests/probes/toys_road_map.npz',rgb=rgb,heights=heights)
Image.fromarray(rgb).save(ROOT/'tests/probes/toys_road_map.png')
im=Image.fromarray(rgb);d=ImageDraw.Draw(im)
old=json.loads((ROOT/'tests/probes/toys_old_route.json').read_text())
for side,col in [(0,'cyan'),(1,'magenta')]:
 pts=[tuple((np.array(x['edges'][side])+offset)*S) for x in old]
 d.line(pts+[pts[0]],fill=col,width=2)
for i in range(0,len(old),24):
 p=(np.array(old[i]['p'])[[0,2]]+offset)*S
 d.text(tuple(p),str(i//24),fill='yellow',stroke_width=1,stroke_fill='black')
im.save(ROOT/'tests/probes/toys_alignment_before.png')
print('Rendered ground and ramps.')
