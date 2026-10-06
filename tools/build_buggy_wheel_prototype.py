"""Build a separate wheel proof GLB; never overwrite the source model."""
import json
import struct
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).parent / 'tabletop_reference'))
from glb_source import Source

root = Path(__file__).resolve().parent.parent
source = Source(root / 'assets/vehicles/BeachBuggy.glb')
p = source.primitives[0]
rotation = np.array([[0,0,1],[0,1,0],[-1,0,0]])
v = p['vertices'] @ rotation.T
primitive = source.doc['meshes'][0]['primitives'][0]
n = source.accessor(primitive['attributes']['NORMAL']) @ p['transform'][:3,:3].T @ rotation.T
uv, faces = p['uv'], p['indices']
centroids = v[faces].mean(axis=1)
groups = np.zeros(len(faces), dtype=int)
wheels = []
for longitudinal, x in [('Rear',-.235),('Front',.328)]:
    for side in [-1,1]:
        pivot = np.array([x,.148,side*.272])
        radial = np.linalg.norm(centroids[:,:2]-pivot[:2],axis=1)
        mask = (centroids[:,2]*side > .205) & (radial < .153)
        groups[mask] = len(wheels)+1
        wheels.append((longitudinal+('Left' if side<0 else 'Right'),pivot))

blob = bytearray()
doc = {'asset':{'version':'2.0','generator':'Buggy wheel extraction proof'},'scene':0,'scenes':[{'nodes':[]}],
       'nodes':[],'meshes':[],'bufferViews':[],'accessors':[],'buffers':[],
       'materials':source.doc['materials'],'textures':source.doc['textures'],'samplers':source.doc.get('samplers',[]),'images':[]}

def view(data):
    while len(blob)%4: blob.append(0)
    index=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':len(data)})
    blob.extend(data);return index

def accessor(data,kind,component):
    index=len(doc['accessors'])
    item={'bufferView':view(data.tobytes()),'componentType':component,'count':len(data),'type':kind}
    if kind=='VEC3': item.update(min=data.min(axis=0).tolist(),max=data.max(axis=0).tolist())
    doc['accessors'].append(item);return index

for image in source.doc['images']:
    b=source.doc['bufferViews'][image['bufferView']];offset=b.get('byteOffset',0)
    doc['images'].append({'bufferView':view(source.bin[offset:offset+b['byteLength']]),'mimeType':image['mimeType']})

report=[]
for group in range(5):
    selected=faces[groups==group]
    ids, indices=np.unique(selected,return_inverse=True)
    name,pivot=('Body',np.zeros(3)) if group==0 else wheels[group-1]
    positions=(v[ids]-pivot).astype('<f4')
    attributes={'POSITION':accessor(positions,'VEC3',5126),'NORMAL':accessor(n[ids].astype('<f4'),'VEC3',5126),'TEXCOORD_0':accessor(uv[ids].astype('<f4'),'VEC2',5126)}
    mesh=len(doc['meshes']);doc['meshes'].append({'name':name,'primitives':[{'attributes':attributes,'indices':accessor(indices.astype('<u4').reshape(-1),'SCALAR',5125),'material':0}]})
    node=len(doc['nodes']);doc['nodes'].append({'name':name,'mesh':mesh,'translation':pivot.tolist()});doc['scenes'][0]['nodes'].append(node)
    report.append({'name':name,'triangles':len(selected),'pivot':pivot.tolist()})
doc['buffers']=[{'byteLength':len(blob)}]
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);blob+=b'\0'*((-len(blob))%4)
data=struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
out=root/'assets/vehicles/prototypes';out.mkdir(exist_ok=True)
(out/'BeachBuggy_wheel_proof.glb').write_bytes(data)
(out/'extraction.json').write_text(json.dumps({'source_sha256':source.sha256,'parts':report,'triangles_preserved':int(len(faces)),'method':'Measured cylindrical face selection at four tyre hubs; prototype boundaries require rendered inspection.'},indent=2))
print(json.dumps(report))
