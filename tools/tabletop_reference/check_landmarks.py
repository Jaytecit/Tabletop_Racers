"""Compare separated raw source landmarks with the actual flattened imported meshes."""
import argparse,json
from pathlib import Path
import numpy as np
from glb_source import Source

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('profile');a=p.parse_args();profile=json.loads(Path(a.profile).read_text())
    s=Source(profile['source'],profile['scale'],profile['offset']);out=Path(profile['output']);meshes=json.loads((out/'imported_mesh_audit_uncompressed.json').read_text())
    prims=[p for p in s.primitives if p['name'] in profile['maps'][Path(profile['fit_map']).stem]['surfaces']]
    points=np.concatenate([p['vertices'] for p in prims]);mapping=[(p,i) for p in prims for i in range(len(p['vertices']))]
    selected=[int(np.argmin(points[:,0]+points[:,2]))]
    for _ in range(2):selected.append(int(np.argmin(-np.min([np.linalg.norm(points[:,[0,2]]-points[i,[0,2]],axis=1) for i in selected],axis=0))))
    records=[]
    for i in selected:
        prim,vi=mapping[i];target=points[i];mesh=next(m for m in meshes if m['name']==prim['name'] and m['surface']==prim['surface']);v=np.array(mesh['vertices']);idx=np.linalg.norm(v-target,axis=1).argmin();err=float(np.linalg.norm(v[idx]-target));assert err<.0001,(prim['name'],err)
        records.append(dict(mesh=prim['name'],source_vertex=vi,source_world=target.tolist(),imported_world=v[idx].tolist(),error=err))
    (out/'landmark_checks.json').write_text(json.dumps(records,indent=2)+'\n');print('3 separated landmarks; max error',max(r['error'] for r in records))
