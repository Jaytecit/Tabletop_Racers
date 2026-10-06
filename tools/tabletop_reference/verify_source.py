"""Independent pixel-band and topology audit, with explicit ambiguous source intervals."""
import argparse
import json
from pathlib import Path
import numpy as np


def verify(profile):
    out=Path(profile['output']);data=np.load(out/profile['fit_map'])
    rows=json.loads((out/'measured_candidate.json').read_text())
    e=np.array([[r['left'][::2],r['right'][::2]] for r in rows]);count=len(e)
    rgb=data['rgb'].astype(float);origin=data['origin'];spacing=float(data['spacing'])
    # This mask uses source paint colour rather than the fitter's DP path or saved score.
    white=rgb.min(-1)-.5*(rgb.max(-1)-rgb.min(-1))
    immediate=np.maximum.reduce([np.roll(white,4,axis=0),np.roll(white,-4,axis=0),np.roll(white,4,axis=1),np.roll(white,-4,axis=1)])
    narrow=(white>profile['white_min']) & ((white-immediate)>15)
    # A line can run parallel to one sampling axis: either axis must show contrast.
    across=np.minimum(np.maximum(np.roll(white,4,axis=0),np.roll(white,-4,axis=0)),np.maximum(np.roll(white,4,axis=1),np.roll(white,-4,axis=1)))
    narrow |= (white>profile['white_min']) & ((white-across)>20)
    checks=[];ambiguous=[];failures=[]
    reviewed=profile.get('ambiguous_source_sections',[])
    for i in range(count):
        for side in range(2):
            xy=(e[i,side]-origin)/spacing;x,y=np.rint(xy).astype(int)
            yy,xx=np.mgrid[y-8:y+9,x-8:x+9]
            mask=narrow[yy,xx]
            distance=float(np.sqrt(np.where(mask,(xx-xy[0])**2+(yy-xy[1])**2,np.inf).min())*spacing)
            record=dict(sample=i,side=side,distance=distance if np.isfinite(distance) else None)
            if i//24 in reviewed:
                ambiguous.append(record)
            else:
                checks.append(record)
                if distance>profile['paint_band_half_width']+spacing:failures.append(record)
    def cross(a,b):return a[...,0]*b[...,1]-a[...,1]*b[...,0]
    intersections=[];folded=[]
    for side in range(2):
        a=e[:,side];r=np.roll(a,-1,axis=0)-a
        for i in range(count):
            js=np.arange(i+2,count)
            if i==0:js=js[js!=count-1]
            den=cross(r[i],r[js]);valid=abs(den)>1e-9
            js=js[valid];den=den[valid]
            t=cross(a[js]-a[i],r[js])/den;u=cross(a[js]-a[i],r[i])/den
            for j in js[(t>1e-7)&(t<1-1e-7)&(u>1e-7)&(u<1-1e-7)]:intersections.append([side,i,int(j)])
    for i in range(count):
        a,b=e[i];c,d=e[(i+1)%count];den=cross(c-a,d-b)
        if abs(den)<1e-9:continue
        t=cross(b-a,d-b)/den;u=cross(b-a,c-a)/den
        if 0<t<1 and 0<u<1:folded.append(i)
    result=dict(paint_checks=len(checks),paint_failures=failures,ambiguous_samples=ambiguous,
                boundary_intersections=intersections,folded_quads=folded,tolerance=profile['paint_band_half_width']+spacing,
                note='Ambiguous intervals require the recorded source close-up/manual-anchor/topology review; this colour mask is not a proof for invisible paint.')
    (out/'source_validation.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({k:v for k,v in result.items() if k!='ambiguous_samples'}))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('profile');args=parser.parse_args()
    verify(json.loads(Path(args.profile).read_text()))
