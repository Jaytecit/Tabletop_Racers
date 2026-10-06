"""Read source GLB primitives with cumulative transforms and actual UV/material identity."""
import hashlib
import io
import json
import struct
from pathlib import Path
import numpy as np
from PIL import Image


class Source:
    def __init__(self, path, scale=1., offset=(0., 0., 0.)):
        self.path = Path(path)
        data = self.path.read_bytes()
        self.sha256 = hashlib.sha256(data).hexdigest()
        magic, version, length = struct.unpack_from('<III', data)
        assert magic == 0x46546c67 and version == 2 and length == len(data)
        chunks = {}
        pos = 12
        while pos < length:
            size, kind = struct.unpack_from('<II', data, pos)
            chunks[kind] = data[pos+8:pos+8+size]
            pos += 8+size
        self.doc = json.loads(chunks[0x4e4f534a])
        self.bin = chunks[0x004e4942]
        self.primitives = []
        transform = np.eye(4)
        transform[:3, :3] *= scale
        transform[:3, 3] = offset
        for node in self.doc['scenes'][self.doc.get('scene', 0)]['nodes']:
            self.visit(node, transform)

    def accessor(self, index):
        a = self.doc['accessors'][index]
        assert 'sparse' not in a
        b = self.doc['bufferViews'][a['bufferView']]
        assert b['buffer'] == 0
        dtype = np.dtype({5120:'i1', 5121:'u1', 5122:'<i2', 5123:'<u2', 5125:'<u4', 5126:'<f4'}[a['componentType']])
        width = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}[a['type']]
        result = np.ndarray((a['count'], width), dtype=dtype, buffer=self.bin,
                            offset=b.get('byteOffset',0)+a.get('byteOffset',0),
                            strides=(b.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
        assert not a.get('normalized',False), 'normalized accessor requires explicit conversion'
        return result

    def visit(self, index, parent):
        n = self.doc['nodes'][index]
        if 'matrix' in n:
            t = np.array(n['matrix']).reshape(4,4).T
        else:
            x,y,z,w = n.get('rotation',[0,0,0,1])
            r = np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],
                          [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],
                          [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])
            t = np.eye(4)
            t[:3,:3] = r @ np.diag(n.get('scale',[1,1,1]))
            t[:3,3] = n.get('translation',[0,0,0])
        t = parent @ t
        if 'mesh' in n:
            mesh = self.doc['meshes'][n['mesh']]
            for surface, p in enumerate(mesh['primitives']):
                assert p.get('mode',4) == 4
                vertices = self.accessor(p['attributes']['POSITION'])
                vertices = vertices @ t[:3,:3].T + t[:3,3]
                idx = self.accessor(p['indices']).reshape(-1,3) if 'indices' in p else np.arange(len(vertices)).reshape(-1,3)
                uv = self.accessor(p['attributes']['TEXCOORD_0']) if 'TEXCOORD_0' in p['attributes'] else None
                mat = self.doc.get('materials',[])[p['material']] if 'material' in p else {}
                self.primitives.append(dict(name=n.get('name',mesh.get('name',str(index))), surface=surface,
                                            vertices=vertices, indices=idx, uv=uv, material=mat, transform=t))
        for child in n.get('children',[]):
            self.visit(child,t)

    def texture(self, primitive):
        info = primitive['material']['pbrMetallicRoughness']['baseColorTexture']
        assert info.get('texCoord',0) == 0
        tex = self.doc['textures'][info['index']]
        im = self.doc['images'][tex['source']]
        b = self.doc['bufferViews'][im['bufferView']]
        raw = self.bin[b.get('byteOffset',0):b.get('byteOffset',0)+b['byteLength']]
        return np.asarray(Image.open(io.BytesIO(raw)).convert('RGB')), info, self.doc.get('samplers',[])[tex['sampler']] if 'sampler' in tex else {}

    def inventory(self):
        result = dict(source=str(self.path), sha256=self.sha256, size=self.path.stat().st_size,
                      asset=self.doc.get('asset',{}), primitives=[])
        for p in self.primitives:
            result['primitives'].append(dict(name=p['name'],surface=p['surface'],triangles=len(p['indices']),
                bounds=[p['vertices'].min(0).tolist(),p['vertices'].max(0).tolist()],material=p['material'],
                geometry_hash=hashlib.sha256(p['vertices'].tobytes()+p['indices'].tobytes()).hexdigest(),
                uv_hash=hashlib.sha256(p['uv'].tobytes()).hexdigest() if p['uv'] is not None else None))
        return result


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('path')
    parser.add_argument('--out',required=True)
    args = parser.parse_args()
    source = Source(args.path)
    Path(args.out).parent.mkdir(parents=True,exist_ok=True)
    Path(args.out).write_text(json.dumps(source.inventory(),indent=2))
    for p in source.inventory()['primitives']:
        print(p['name'],p['surface'],p['triangles'],np.round(p['bounds'],3).tolist(),p['geometry_hash'][:12])
