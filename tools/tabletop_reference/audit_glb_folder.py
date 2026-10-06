"""Read-only GLB survey. Writes evidence only; never authors game resources."""
import argparse
import hashlib
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from glb_source import Source

ROOT = Path(__file__).resolve().parents[2]


class SurveySource(Source):
    """Ignore explicit non-triangle helpers; preserve their identity in evidence."""
    def __init__(self, path):
        self.skipped = []
        super().__init__(path)

    def visit(self, index, parent):
        node = self.doc['nodes'][index]
        if 'mesh' in node:
            mesh = self.doc['meshes'][node['mesh']]
            for primitive in mesh['primitives']:
                if primitive.get('mode', 4) != 4:
                    self.skipped.append(dict(node=node.get('name'), mode=primitive.get('mode')))
            mesh['primitives'] = [p for p in mesh['primitives'] if p.get('mode', 4) == 4]
        super().visit(index, parent)


def audit(folder, output, only=None):
    output.mkdir(parents=True, exist_ok=True)
    known = {}
    for path in (ROOT / 'assets/imported/tabletop').glob('*.glb'):
        known.setdefault(hashlib.sha256(path.read_bytes()).hexdigest(), []).append(path.stem)
    rows = []
    for path in sorted(folder.glob('*.glb')):
        if only and path.name != only:
            continue
        raw = path.read_bytes()
        size, kind = struct.unpack_from('<II', raw, 12)
        assert kind == 0x4e4f534a
        doc = json.loads(raw[20:20+size])
        sha = hashlib.sha256(raw).hexdigest()
        row = dict(file=path.name, sha256=sha, megabytes=round(len(raw)/1e6, 2),
                   metadata=doc.get('asset', {}), extensions=doc.get('extensionsUsed', []),
                   matches_imported=known.get(sha, []), meshes=len(doc.get('meshes', [])),
                   materials=[m.get('name', '') for m in doc.get('materials', [])],
                   images=[], primitives=[], error=None)
        del raw
        try:
            source = SurveySource(path)
            row['skipped_non_triangle_helpers'] = source.skipped
            row['primitives'] = source.inventory()['primitives']
            row['triangles'] = sum(len(p['indices']) for p in source.primitives)
            bounds = np.array([p['vertices'].min(0) for p in source.primitives] +
                              [p['vertices'].max(0) for p in source.primitives])
            row['bounds'] = [bounds.min(0).tolist(), bounds.max(0).tolist()]
            # Top-down diagnostic, material colours only. This is not a render
            # or proof that a road classifier selected the correct surface.
            lo, hi = bounds.min(0)[[0, 2]], bounds.max(0)[[0, 2]]
            factor = 700 / max(float((hi-lo).max()), 1e-9)
            canvas = Image.new('RGB', (760, 800), '#171b22')
            draw = ImageDraw.Draw(canvas)
            for index, p in sorted(enumerate(source.primitives), key=lambda pair: pair[1]['vertices'][:, 1].mean()):
                name = p['name'].lower() + ' ' + p['material'].get('name', '').lower()
                candidate = any(word in name for word in ('road', 'asphalt', 'track', 'circuit', 'raceway'))
                color = '#50d5e0' if candidate else '#485161'
                xy = (p['vertices'][:, [0, 2]]-lo)*factor + 30
                for tri in p['indices']:
                    draw.polygon([tuple(q) for q in xy[tri]], fill=color)
            draw.text((15, 755), path.stem[:85], fill='white')
            draw.text((15, 775), 'Cyan = name-based candidates only; grey = other geometry', fill='white')
            canvas.save(output / (path.stem + '_plan.png'))
            for index, im in enumerate(doc.get('images', [])):
                info = dict(index=index, name=im.get('name'), mime=im.get('mimeType'), uri=im.get('uri'))
                if 'bufferView' in im:
                    view = doc['bufferViews'][im['bufferView']]
                    start = view.get('byteOffset', 0)
                    image = Image.open(io.BytesIO(source.bin[start:start+view['byteLength']]))
                    info['size'] = list(image.size)
                    # Small contact sheets permit visual inspection without
                    # extracting full texture copies into game assets.
                    image.thumbnail((256, 256))
                    image.convert('RGB').save(output / (path.stem + f'_texture_{index}.jpg'))
                row['images'].append(info)
            del source
        except Exception as exc:
            row['error'] = f'{type(exc).__name__}: {exc}'
        rows.append(row)
        (output / 'inventory.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
        print(path.name, row.get('triangles'), 'matched=' + ','.join(row['matches_imported']), row['error'], flush=True)
    groups = {}
    for row in rows:
        groups.setdefault(row['sha256'], []).append(row['file'])
    (output / 'duplicates.json').write_text(json.dumps([g for g in groups.values() if len(g)>1], indent=2))
    # Paginated plan contact sheets.
    for start in range(0, len(rows), 12):
        sheet = Image.new('RGB', (4*380, 3*400), '#11151b')
        for i, row in enumerate(rows[start:start+12]):
            path = output / (Path(row['file']).stem + '_plan.png')
            if path.exists():
                tile = Image.open(path).resize((380, 400))
                sheet.paste(tile, ((i % 4)*380, (i // 4)*400))
        sheet.save(output / f'plans_{start//12+1}.jpg')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, default=ROOT / 'tracks/GLB Tracks')
    parser.add_argument('--output', type=Path, default=ROOT / 'tests/baselines/content/glb_folder_audit')
    parser.add_argument('--only', help='Audit one exact filename, preferably into a separate output folder')
    args = parser.parse_args()
    audit(args.folder, args.output, args.only)
