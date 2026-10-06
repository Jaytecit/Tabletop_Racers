"""Review evidence, local fold correction and exact selected-triangle heights."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from glb_source import Source


def cross(a,b):
    return a[...,0]*b[...,1]-a[...,1]*b[...,0]


def finalize(profile):
    out=Path(profile['output']); candidate=np.load(out/'candidate_edges.npz')
    edges=candidate['edges'].copy();count=len(edges)
    data=np.load(out/profile['fit_map']);origin=data['origin'];spacing=float(data['spacing'])
    for review in profile.get('boundary_reviews',[]):
        anchors=np.asarray(review['pixels'],float)*spacing+origin
        lengths=np.r_[0,np.cumsum(np.linalg.norm(np.diff(anchors,axis=0),axis=1))]
        station=np.linspace(0,lengths[-1],review['end']-review['start']+1)
        fitted=np.stack([np.interp(station,lengths,anchors[:,axis]) for axis in range(2)],axis=1)
        if review.get('transverse',False):
            guide=candidate['guide']
            tangent=np.roll(guide,-2,axis=0)-np.roll(guide,2,axis=0)
            for k,i in enumerate(range(review['start'],review['end']+1)):
                signed=(anchors-guide[i])@tangent[i]
                hits=[]
                for j in range(len(anchors)-1):
                    den=signed[j]-signed[j+1]
                    if abs(den)<1e-9:continue
                    t=signed[j]/den
                    if -1e-7<=t<=1+1e-7:
                        t=np.clip(t,0.,1.)
                        q=anchors[j]+t*(anchors[j+1]-anchors[j])
                        hits.append((float(np.linalg.norm(q-edges[i,review['side']])),q))
                assert hits,f'Reviewed boundary does not intersect transverse plane: {i}, side {review["side"]}'
                fitted[k]=min(hits,key=lambda h:h[0])[1]
        edges[review['start']:review['end']+1,review['side']]=fitted
    reviewed_edges=edges.copy()
    ridge_snaps=[]
    if profile.get('snap_reviewed_ridge_bands',False):
        rgb=data['rgb'].astype(float)
        def white(q):
            xy=np.rint((q-origin)/spacing).astype(int)
            c=rgb[xy[...,1],xy[...,0]]
            return c.min(-1)-.5*(c.max(-1)-c.min(-1))
        for side in range(2):
            edge=edges[:,side]
            tangent=np.roll(edge,-2,axis=0)-np.roll(edge,2,axis=0)
            normal=np.stack([-tangent[:,1],tangent[:,0]],axis=1)
            normal/=np.linalg.norm(normal,axis=1)[:,None]
            distances=np.arange(-.35,.351,.01)
            q=edge[:,None]+normal[:,None]*distances[None,:,None]
            w=white(q)
            score=np.clip((w-np.maximum(white(q+normal[:,None]*.2),white(q-normal[:,None]*.2)))/35,0,3)*np.clip((w-75)/100,0,1)
            for i in range(count):
                peak=score[i].max()
                if peak<.3:continue
                valid=np.where(score[i]>=max(.3,peak*.5))[0]
                best=valid[np.abs(distances[valid]).argmin()]
                if abs(distances[best])<=spacing:continue
                edges[i,side]+=normal[i]*distances[best]
                ridge_snaps.append(dict(sample=i,side=side,distance=float(distances[best])))
    if profile.get('preserve_reviewed_boundaries',False):
        for review in profile.get('boundary_reviews',[]):
            edges[review['start']:review['end']+1,review['side']]=reviewed_edges[review['start']:review['end']+1,review['side']]
    if profile.get('preserve_reviewed_points',False):
        for review in profile.get('boundary_reviews',[]):
            if review['start']==review['end']:
                edges[review['start'],review['side']]=reviewed_edges[review['start'],review['side']]
    folds=[]
    for side in range(2):
        for i in range(count):
            a=edges[i,side];b=edges[(i+1)%count,side];r=b-a
            for j in range(i+2,min(i+45,count-1)):
                c=edges[j,side];d=edges[(j+1)%count,side];s=d-c
                den=cross(r,s)
                if abs(den)<1e-9:continue
                t=cross(c-a,s)/den;u=cross(c-a,r)/den
                if 0<t<1 and 0<u<1:
                    hit=a+t*r
                    folds.append(dict(side=side,start=i,end=j,max_shift=float(np.linalg.norm(edges[i+1:j+1,side]-hit,axis=1).max())))
                    edges[i+1:j+1,side]=hit
    source=Source(profile['source'],profile['scale'],profile['offset'])
    selected=profile['maps'][Path(profile['fit_map']).stem]['surfaces']
    def height(points,with_identity=False):
        result=np.full(len(points),-np.inf)
        identity=np.full(len(points),-1,dtype=int)
        for primitive_index,p in enumerate(source.primitives):
            if p['name'] not in selected:continue
            for tri in p['vertices'][p['indices']]:
                mat=np.stack([tri[1,[0,2]]-tri[0,[0,2]],tri[2,[0,2]]-tri[0,[0,2]]],axis=1)
                if abs(np.linalg.det(mat))<1e-8:continue
                b=(points-tri[0,[0,2]])@np.linalg.inv(mat).T
                mask=(b.min(1)>=-1e-6)&(b.sum(1)<=1+1e-6)
                y=(1-b.sum(1))*tri[0,1]+b@tri[1:,1]
                if 'driving_height_range' in profile:
                    mask &= (y>=profile['driving_height_range'][0]) & (y<=profile['driving_height_range'][1])
                replace=mask & (y>result+1e-6)
                result[replace]=y[replace]
                identity[replace]=primitive_index
        assert np.isfinite(result).all(),f'Missing source support: {np.where(~np.isfinite(result))[0].tolist()}'
        return (result,identity) if with_identity else result
    def xyz(points):
        return np.stack([points[:,0],height(points),points[:,1]],axis=1)
    support_snaps=[]
    if 'height_continuity_snap_radius' in profile:
        for side in range(2):
            h=height(edges[:,side])
            expected=np.median(np.stack([np.roll(h,k) for k in [-3,-2,-1,1,2,3]]),axis=0)
            for i in np.where(abs(h-expected)>.35)[0]:
                offsets=np.array([[np.cos(a)*radius,np.sin(a)*radius] for radius in np.arange(.005,profile['height_continuity_snap_radius']+.001,.005) for a in np.linspace(0,2*np.pi,32,endpoint=False)])
                candidates=edges[i,side]+offsets
                found=height(candidates)
                valid=np.where(abs(found-expected[i])<.10)[0]
                assert len(valid),f'Unresolved surface-layer boundary at {i}, side {side}'
                best=valid[np.linalg.norm(offsets[valid],axis=1).argmin()]
                support_snaps.append(dict(sample=int(i),side=side,old=edges[i,side].tolist(),new=candidates[best].tolist(),distance=float(np.linalg.norm(offsets[best]))))
                edges[i,side]=candidates[best]
    left,right,center=xyz(edges[:,0]),xyz(edges[:,1]),xyz(edges.mean(1))
    _,center_identity=height(edges.mean(1),True)
    rows=[dict(left=left[i].tolist(),right=right[i].tolist(),center=center[i].tolist(),section=i//24) for i in range(count)]
    (out/'measured_candidate.json').write_text(json.dumps(rows))
    im=Image.fromarray(data['rgb']);draw=ImageDraw.Draw(im)
    for side,col in [(0,'cyan'),(1,'magenta')]:
        xy=(edges[:,side]-origin)/spacing
        draw.line([tuple(x) for x in xy]+[tuple(xy[0])],fill=col,width=2)
    im.save(out/'measured_overlay.png')
    crops=out/'section_closeups';crops.mkdir(exist_ok=True)
    for sec in range(count//24):
        xy=(edges[sec*24:(sec+1)*24]-origin)/spacing
        low=np.maximum(xy.min((0,1))-40,0).astype(int)
        high=np.minimum(xy.max((0,1))+40,np.array(im.size)).astype(int)
        im.crop((low[0],low[1],high[0],high[1])).save(crops/f'{sec:03d}.png')
    widths=np.linalg.norm(left[:,[0,2]]-right[:,[0,2]],axis=1)
    weak=np.argwhere(candidate['scores']<.3)
    evidence=dict(source_sha256=source.sha256,folds_removed=folds,ridge_snaps=ridge_snaps,support_snaps=support_snaps,width_range=[float(widths.min()),float(widths.max())],
                  center_height_range=[float(center[:,1].min()),float(center[:,1].max())],
                  length=float(np.linalg.norm(np.roll(center,-1,axis=0)-center,axis=1).sum()),
                  weak_samples=weak.tolist(),height_method='Exact barycentric intersection of named floor/ramp primitives; no prop/highest-scene hit',
                  center_surface_names=[source.primitives[int(i)]['name'] for i in center_identity],
                  candidate_sha256=hashlib.sha256((out/'measured_candidate.json').read_bytes()).hexdigest())
    (out/'measurement_evidence.json').write_text(json.dumps(evidence,indent=2))
    print(json.dumps({k:v for k,v in evidence.items() if k not in ['weak_samples','center_surface_names','ridge_snaps']}))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('profile');args=parser.parse_args()
    finalize(json.loads(Path(args.profile).read_text()))
