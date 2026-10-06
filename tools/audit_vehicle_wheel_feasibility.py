"""Read-only topology assessment; original GLBs and game scripts are untouched."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent / 'tabletop_reference'))
from glb_source import Source

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'tests/evidence/wheel-feasibility-2026-10-04'
OUT.mkdir(parents=True, exist_ok=True)


def components(faces, count):
    edges = np.concatenate((faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]))
    graph = coo_matrix((np.ones(len(edges), dtype=np.uint8), (edges[:, 0], edges[:, 1])), shape=(count, count)).tocsr()
    return connected_components(graph, directed=False)


rows = []
for path in sorted((ROOT / 'assets/vehicles').glob('*.glb')):
    source = Source(path)
    primitive = source.primitives[0]
    vertices, faces = primitive['vertices'], primitive['indices']
    raw_count, raw_labels = components(faces, len(vertices))
    welds = []
    for tolerance in (1e-7, 1e-6, 1e-5):
        _, inverse = np.unique(np.rint(vertices / tolerance).astype(np.int64), axis=0, return_inverse=True)
        count, labels = components(inverse[faces], int(inverse.max()) + 1)
        face_labels = labels[inverse[faces[:, 0]]]
        sizes = np.bincount(face_labels, minlength=count)
        order = np.argsort(sizes)[::-1]
        details = []
        for index in order[:12]:
            points = vertices[np.unique(faces[face_labels == index])]
            details.append(dict(triangles=int(sizes[index]), min=points.min(0).round(6).tolist(), max=points.max(0).round(6).tolist()))
        welds.append(dict(tolerance=tolerance, components=count, largest_fraction=round(float(sizes.max()/len(faces)),6), largest=details))
        if tolerance == 1e-6:
            vertex_labels = labels[inverse]
            rank = np.empty(count, dtype=int)
            rank[order] = np.arange(count)
            palette = np.array([[70,160,230],[245,110,70],[110,215,110],[230,195,75],[195,110,235],[70,215,205]],dtype=np.uint8)
            colours = palette[rank[vertex_labels] % len(palette)]
    image = Image.new('RGB', (1400, 850), '#17212d')
    draw = ImageDraw.Draw(image)
    draw.text((20, 15), path.name + ' - geometry connectivity (same colour = same component)', fill='white')
    for panel, axes in enumerate(((2, 1), (2, 0))):
        xy = vertices[:, axes]
        size = np.ptp(xy, axis=0)
        scale = min(1300 / size[0], 340 / size[1])
        pixels = np.rint((xy-xy.min(0))*scale).astype(int)
        pixels[:, 0] += int((1400-size[0]*scale)/2)
        pixels[:, 1] = 405+panel*400-pixels[:, 1]
        rgb = np.asarray(image).copy()
        rgb[pixels[:, 1], pixels[:, 0]] = colours
        image = Image.fromarray(rgb)
        draw = ImageDraw.Draw(image)
        draw.text((20, 48+panel*400), 'SIDE: horizontal = length, vertical = height' if panel==0 else 'TOP: horizontal = length, vertical = width', fill='white')
    image.save(OUT / (path.stem + '_connectivity.png'))
    row = dict(model=path.name, sha256=source.sha256, meshes=len(source.doc['meshes']), nodes=len(source.doc['nodes']),
               skins=len(source.doc.get('skins', [])), animations=len(source.doc.get('animations', [])),
               vertices=len(vertices), triangles=len(faces), raw_components=raw_count, welded=welds,
               source_unchanged=hashlib.sha256(path.read_bytes()).hexdigest()==source.sha256)
    rows.append(row)
    print(path.name, 'triangles',len(faces),'raw_components',raw_count,'welded',[(r['tolerance'],r['components'],r['largest_fraction']) for r in welds])
(OUT / 'topology.json').write_text(json.dumps(rows, indent=2))
