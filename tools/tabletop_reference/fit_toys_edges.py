"""Fit independent model-space boundaries to the baked white road markings."""
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
old=json.loads((ROOT/'tests/probes/toys_old_route.json').read_text())
p=np.array([r['p'] for r in old])
oldedges=np.array([r['edges'] for r in old])
norm=(oldedges[:,1]-oldedges[:,0]);norm/=np.linalg.norm(norm,axis=1)[:,None]
N=len(p); S=20;offset=65
import sys
if '--refine' in sys.argv:
 fitted=json.loads((ROOT/'tests/probes/toys_fitted_edges.json').read_text())
 center=np.array([(np.array(x['left'])+np.array(x['right']))/2 for x in fitted])
 # Smooth only the centre used for transverse measurements, never the model edges.
 weights=np.exp(-np.arange(-12,13)**2/32);weights/=weights.sum()
 for axis in [0,2]:p[:,axis]=sum(w*np.roll(center[:,axis],k) for w,k in zip(weights,range(-12,13)))
 tangent=np.roll(p[:,[0,2]],-2,axis=0)-np.roll(p[:,[0,2]],2,axis=0)
 norm=np.stack((-tangent[:,1],tangent[:,0]),axis=1)
 norm/=np.linalg.norm(norm,axis=1)[:,None]
maps=[np.load(ROOT/f'tests/probes/toys_{n}_map.npz') for n in ['road','floor']]
def sample(pts,key='rgb'):
 xy=np.rint((pts+offset)*S).astype(int).clip(0,2599)
 v=maps[0][key][xy[...,1],xy[...,0]].copy()
 under=(np.arange(N)//24>=36)&(np.arange(N)//24<=37)
 v[under]=maps[1][key][xy[under,...,1],xy[under,...,0]]
 return v
dist=np.arange(.5,9.01,.025)
edges=[];ds=[]
for side in [-1,1]:
 q=p[:,None,[0,2]]+norm[:,None,:]*dist[None,:,None]*side
 col=sample(q).astype(float)
 white=col.min(-1)-.5*(col.max(-1)-col.min(-1))
 # Thin bright ridge rather than broad white areas on the checkerboard/packaging.
 neighbor=[]
 for shift in [-.22,.22]:
  c=sample(q+norm[:,None,:]*shift).astype(float)
  neighbor.append(c.min(-1)-.5*(c.max(-1)-c.min(-1)))
 ridge=white-np.maximum(neighbor[0],neighbor[1])
 score=np.clip(ridge/40,0,3)*np.clip((white-160)/60,0,1)
 # Bright marking itself takes priority; smooth through invisible white-on-white parts.
 cost=2.0-score+.025*(dist[None,:]-3.3)**2
 M=len(dist); change=(dist[:,None]-dist[None,:])**2*35
 dp=cost[0];back=[]
 for i in range(1,N):
  c=dp[:,None]+change
  k=c.argmin(0);back.append(k);dp=cost[i]+c[k,np.arange(M)]
 path=[int(dp.argmin())]
 for k in back[::-1]:path.append(int(k[path[-1]]))
 path=np.array(path[::-1]);d=dist[path]
 ds.append(d);edges.append(p[:,[0,2]]+norm*d[:,None]*side)
e=np.stack(edges,axis=1)
h=[]
for side in range(2):h.append(sample(e[:,side,None,:],'heights')[:,0])
result=[]
for i in range(N):
 a=[e[i,0,0],float(h[0][i]),e[i,0,1]]
 b=[e[i,1,0],float(h[1][i]),e[i,1,1]]
 result.append({'left':a,'right':b,'section':i//24})
(ROOT/'tests/probes/toys_fitted_edges.json').write_text(json.dumps(result))
im=Image.fromarray(maps[0]['rgb']);dr=ImageDraw.Draw(im)
for side,color in [(0,'cyan'),(1,'magenta')]:
 pts=[tuple((v+offset)*S) for v in e[:,side]]
 dr.line(pts+[pts[0]],fill=color,width=2)
for i in range(0,N,24):
 dr.text(tuple((p[i,[0,2]]+offset)*S),str(i//24),fill='yellow',stroke_width=1,stroke_fill='black')
im.save(ROOT/'tests/probes/toys_alignment_fit.png')
print('width range',np.min(ds[0]+ds[1]),np.max(ds[0]+ds[1]))
print('old edge shift median/max',np.median(np.abs(np.array(ds)-2.4)),np.max(np.abs(np.array(ds)-2.4)))
