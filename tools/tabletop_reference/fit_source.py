"""Course-profile transverse ridge fitting; outputs candidates for source review only."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from glb_source import Source


def seed_loop(anchors, count):
    anchors=np.asarray(anchors,float)
    parts=[]
    for i,b in enumerate(anchors):
        a,c,d=anchors[(i-1)%len(anchors)],anchors[(i+1)%len(anchors)],anchors[(i+2)%len(anchors)]
        t=np.linspace(0,1,40,endpoint=False)[:,None]
        parts.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    points=np.concatenate(parts)
    points=np.concatenate([points,points[:1]])
    lengths=np.r_[0,np.cumsum(np.linalg.norm(np.diff(points,axis=0),axis=1))]
    station=np.linspace(0,lengths[-1],count,endpoint=False)
    return np.stack([np.interp(station,lengths,points[:,axis]) for axis in range(2)],axis=1)


def fit(profile):
    out=Path(profile['output'])
    data=np.load(out/profile['fit_map'])
    rgb=data['rgb'].astype(float)
    origin=data['origin']; spacing=float(data['spacing'])
    count=profile['section_count']*24
    p=seed_loop((np.asarray(profile['seed_pixels'])/profile['seed_display_width']*profile['shape'][1])*spacing+origin,count)
    distances=np.arange(*profile['search_distances'])
    def sample(q):
        xy=np.rint((q-origin)/spacing).astype(int)
        assert xy[...,0].min()>=0 and xy[...,1].min()>=0 and xy[...,0].max()<rgb.shape[1] and xy[...,1].max()<rgb.shape[0]
        col=rgb[xy[...,1],xy[...,0]]
        return col.min(-1)-.5*(col.max(-1)-col.min(-1))
    for iteration in range(profile['refinements']+1):
        tangent=np.roll(p,-2,axis=0)-np.roll(p,2,axis=0)
        normals=np.stack([-tangent[:,1],tangent[:,0]],axis=1)
        normals/=np.linalg.norm(normals,axis=1)[:,None]
        edges=[]; scores=[]
        for sign in [-1,1]:
            q=p[:,None,:]+normals[:,None,:]*distances[None,:,None]*sign
            white=sample(q)
            ridge=white-np.maximum(sample(q+normals[:,None,:]*profile['ridge_neighborhood']),sample(q-normals[:,None,:]*profile['ridge_neighborhood']))
            score=np.clip(ridge/profile['ridge_scale'],0,3)*np.clip((white-profile['white_min'])/profile['white_range'],0,1)
            cost=2-score+profile['distance_bias']*(distances[None,:]-profile['nominal_half_width'])**2
            transition=(distances[:,None]-distances[None,:])**2*profile['continuity']
            first=int(cost[0].argmin())
            dp=np.full(len(distances),np.inf); dp[first]=cost[0,first]
            back=[]
            for i in range(1,count):
                c=dp[:,None]+transition
                k=c.argmin(0);back.append(k);dp=cost[i]+c[k,np.arange(len(distances))]
            path=[int((dp+transition[:,first]).argmin())]
            for k in back[::-1]:path.append(int(k[path[-1]]))
            path=np.array(path[::-1])
            edges.append(p+normals*distances[path,None]*sign)
            scores.append(score[np.arange(count),path])
        e=np.stack(edges,axis=1)
        if iteration<profile['refinements']:
            center=e.mean(1)
            weights=np.exp(-np.arange(-10,11)**2/24);weights/=weights.sum()
            p=sum(w*np.roll(center,k,axis=0) for w,k in zip(weights,range(-10,11)))
    image=Image.fromarray(data['rgb']);draw=ImageDraw.Draw(image)
    for side,color in [(0,'cyan'),(1,'magenta')]:
        xy=(e[:,side]-origin)/spacing
        draw.line([tuple(x) for x in xy]+[tuple(xy[0])],fill=color,width=2)
    for i in range(0,count,24):draw.text(tuple((p[i]-origin)/spacing),str(i//24),fill='yellow',stroke_width=1,stroke_fill='black')
    image.save(out/'candidate_overlay.png')
    np.savez_compressed(out/'candidate_edges.npz',edges=e,scores=np.stack(scores,axis=1),guide=p)
    widths=np.linalg.norm(e[:,0]-e[:,1],axis=1)
    print(json.dumps(dict(samples=count,width_range=[float(widths.min()),float(widths.max())],weak_counts=(np.stack(scores,axis=1)<.3).sum(0).tolist())))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('profile');args=parser.parse_args()
    fit(json.loads(Path(args.profile).read_text()))
