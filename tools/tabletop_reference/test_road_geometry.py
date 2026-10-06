"""Focused synthetic checks for extraction geometry and candidate-write guards."""
import tempfile
import hashlib
import io
import json
import struct
import subprocess
import sys
from pathlib import Path
import unittest
from types import SimpleNamespace

import numpy as np
from PIL import Image
from shapely.geometry import Point
from road_geometry import DrivingSurface, GeometryError, pair_rings, sample_pairing, sample_pairing_corners, validate_corridor
from extract_road_candidate import ROOT, reserve_output, select_triangles


def annulus(height=lambda x, z: 0):
    outer = np.array([[-10, -6], [10, -6], [10, 6], [-10, 6]], dtype=float)
    inner = np.array([[-8, -4], [8, -4], [8, 4], [-8, 4]], dtype=float)
    triangles = []
    for i in range(4):
        j = (i+1) % 4
        for tri in ((outer[i], outer[j], inner[j]), (outer[i], inner[j], inner[i])):
            triangles.append([[x, height(x, z), z] for x, z in tri])
    return np.asarray(triangles)


class GeometryTests(unittest.TestCase):
    def test_corner_samples_preserve_both_complete_rings(self):
        surface = DrivingSurface(annulus())
        for clockwise in (True, False):
            pairing = pair_rings(surface, [-12, 0.37], clockwise, ring_spacing=0.5)
            left, right, center = sample_pairing_corners(pairing, 1.3)
            self.assertEqual(len(center) % 24, 0)
            points = np.concatenate([left, right])
            for ring in (surface.road.exterior, surface.road.interiors[0]):
                for corner in ring.coords:
                    self.assertLess(np.linalg.norm(points-corner, axis=1).min(), 1e-7)
            checks = validate_corridor(surface, left, right, 1e-7, 1.5)
            self.assertTrue(checks['passed'], checks['failures'][:5])
            # A too-coarse correspondence can fold at a sharp corner. Keeping
            # the vertex exposes that defect; validation must reject it.
            coarse = pair_rings(surface, [-12, 0.37], clockwise, ring_spacing=1.1)
            a, b, _ = sample_pairing_corners(coarse, 1.3)
            self.assertFalse(validate_corridor(surface, a, b, 1e-7, 1.5)['passed'])

    def test_banked_heights_are_sampled_from_source(self):
        surface = DrivingSurface(annulus(lambda x, z: 0.1*x+0.2*z))
        self.assertAlmostEqual(surface.height(np.array([9., 0.])), 0.9)
        self.assertAlmostEqual(surface.height(np.array([0., 5.])), 1.)
        with self.assertRaisesRegex(GeometryError, 'No selected source support'):
            surface.height(np.array([0., 0.]))

    def test_flat_union_must_not_hide_two_road_layers(self):
        a = annulus()
        b = a.copy()
        b[:, :, 1] += 5
        with self.assertRaisesRegex(GeometryError, 'Conflicting road layers'):
            DrivingSurface(np.concatenate([a, b]))

    def test_disconnected_roads_are_rejected(self):
        a = annulus()
        b = a.copy()
        b[:, :, 0] += 40
        with self.assertRaisesRegex(GeometryError, 'one valid connected polygon'):
            DrivingSurface(np.concatenate([a, b]))

    def test_no_hole_is_rejected(self):
        with self.assertRaisesRegex(GeometryError, 'one valid connected polygon'):
            DrivingSurface(np.array([[[0, 0, 0], [2, 0, 0], [0, 0, 2]]]))

    def test_vertical_faces_and_nonfinite_geometry_are_rejected(self):
        with self.assertRaisesRegex(GeometryError, 'vertical/degenerate'):
            DrivingSurface(np.array([[[0, 0, 0], [0, 1, 0], [0, 1, 2]]]))
        a = annulus()
        a[0, 0, 0] = np.nan
        with self.assertRaisesRegex(GeometryError, 'non-finite'):
            DrivingSurface(a)

    def test_pairing_is_cyclic_and_preserves_each_edge_and_side(self):
        surface = DrivingSurface(annulus(lambda x, z: 0.1*x))
        for clockwise in (True, False):
            pairing = pair_rings(surface, [-12, 0], clockwise, ring_spacing=0.25)
            left, right, center = sample_pairing(pairing, 0.1)
            self.assertEqual(len(center) % 24, 0)
            for points in (left, right):
                for q in points:
                    self.assertLess(surface.road.boundary.distance(Point(q)), 1e-7)
            tangent = np.roll(center, -1, axis=0)-np.roll(center, 1, axis=0)
            side = tangent[:, 0]*(left-center)[:, 1]-tangent[:, 1]*(left-center)[:, 0]
            self.assertTrue(np.all(side > 0))
            checks = validate_corridor(surface, left, right, 0.08, 1.5)
            self.assertTrue(checks['passed'], checks['failures'][:5])

    def test_pairing_memory_budget_is_enforced(self):
        surface = DrivingSurface(annulus())
        with self.assertRaisesRegex(GeometryError, 'cell budget'):
            pair_rings(surface, [-12, 0], True, max_cells=10)

    def test_missing_ambiguous_duplicate_and_masked_selections(self):
        p = dict(name='road', surface=0, vertices=annulus().reshape(-1, 3),
                 indices=np.arange(24).reshape(-1, 3))
        source = SimpleNamespace(primitives=[p])
        selector = dict(name='road', surface=0)
        with self.assertRaisesRegex(GeometryError, 'explicit reviewed'):
            select_triangles(source, [])
        with self.assertRaisesRegex(GeometryError, 'found 0'):
            select_triangles(source, [dict(name='wrong', surface=0)])
        with self.assertRaisesRegex(GeometryError, 'Duplicate'):
            select_triangles(source, [selector, selector])
        with self.assertRaisesRegex(GeometryError, 'found 2'):
            select_triangles(SimpleNamespace(primitives=[p, p]), [selector])
        self.assertEqual(select_triangles(source, [dict(selector, triangle_indices=[0, 1])]).shape, (2, 3, 3))
        for mask in ([-1], [99], [0, 0], [0.5], []):
            with self.assertRaises(GeometryError):
                select_triangles(source, [dict(selector, triangle_indices=mask)])

    def test_existing_and_canonical_outputs_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'new'
            self.assertEqual(reserve_output(path), path.resolve())
            (path/'sentinel.txt').write_text('keep')
            with self.assertRaises(FileExistsError):
                reserve_output(path)
            self.assertEqual((path/'sentinel.txt').read_text(), 'keep')
        for folder in ('tracks', 'assets', 'environments', 'scripts', '.summer'):
            with self.assertRaises(GeometryError):
                reserve_output(ROOT/folder/'candidate_forbidden_test')

    def test_cli_hash_binding_failure_evidence_and_transformed_glb(self):
        # A real tiny GLB catches source-reader/CLI/raster/schema integration
        # mistakes without repeatedly loading the large production model.
        vertices = annulus().reshape(-1, 3).astype('<f4')
        indices = np.arange(len(vertices), dtype='<u2')
        uv = ((vertices[:, [0, 2]]+10)/20).astype('<f4')
        picture = io.BytesIO()
        Image.new('RGB', (2, 2), 'grey').save(picture, format='PNG')
        pieces = [vertices.tobytes(), indices.tobytes(), uv.tobytes(), picture.getvalue()]
        binary, views = b'', []
        for piece in pieces:
            views.append(dict(buffer=0, byteOffset=len(binary), byteLength=len(piece)))
            binary += piece+b'\0'*(-len(piece)%4)
        doc = dict(asset=dict(version='2.0'), scenes=[dict(nodes=[0])], scene=0,
                   nodes=[dict(children=[1], translation=[100, 2, -100], scale=[2, 2, 2]),
                          dict(name='road', mesh=0)],
                   meshes=[dict(primitives=[dict(attributes=dict(POSITION=0, TEXCOORD_0=2), indices=1, material=0)])],
                   materials=[dict(pbrMetallicRoughness=dict(baseColorTexture=dict(index=0)))],
                   textures=[dict(source=0)], images=[dict(bufferView=3, mimeType='image/png')],
                   buffers=[dict(byteLength=len(binary))], bufferViews=views,
                   accessors=[dict(bufferView=0, componentType=5126, count=24, type='VEC3'),
                              dict(bufferView=1, componentType=5123, count=24, type='SCALAR'),
                              dict(bufferView=2, componentType=5126, count=24, type='VEC2')])
        encoded = json.dumps(doc).encode()
        encoded += b' '*(-len(encoded)%4)
        data = struct.pack('<III', 0x46546c67, 2, 28+len(encoded)+len(binary))
        data += struct.pack('<II', len(encoded), 0x4e4f534a)+encoded
        data += struct.pack('<II', len(binary), 0x004e4942)+binary
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            source = base/'test.glb'
            source.write_bytes(data)
            profile = json.loads((ROOT/'tools/tabletop_reference/profiles/topspeed_oval.json').read_text())
            profile.pop('scale_to_median_width')
            profile.update(id='synthetic', source=str(source), source_sha256=hashlib.sha256(data).hexdigest(),
                           road_primitives=[dict(name='road', surface=0)],
                           transform=dict(scale=0.5, offset=[-50, -1, 50]),
                           start_anchor_source=[76, -100], minimum_width=1.5,
                           ring_spacing=0.25, sample_spacing=0.1, boundary_tolerance=0.08)
            profile_path = base/'profile.json'
            profile_path.write_text(json.dumps(profile))
            command = [sys.executable, str(ROOT/'tools/tabletop_reference/extract_road_candidate.py'), str(profile_path), '--out']
            success = subprocess.run(command+[str(base/'success')], capture_output=True, text=True)
            self.assertEqual(success.returncode, 0, success.stderr)
            rows = json.loads((base/'success/measured_candidate.json').read_text())
            self.assertEqual(len(rows) % 24, 0)
            self.assertTrue(all(abs(row['center'][1]) < 1e-8 for row in rows))
            original_result = (base/'success/result.json').read_bytes()
            repeated = subprocess.run(command+[str(base/'success')], capture_output=True, text=True)
            self.assertEqual(repeated.returncode, 2)
            self.assertEqual((base/'success/result.json').read_bytes(), original_result)
            profile['source_sha256'] = '0'*64
            profile_path.write_text(json.dumps(profile))
            mismatch = subprocess.run(command+[str(base/'wrong_hash')], capture_output=True, text=True)
            self.assertEqual(mismatch.returncode, 2)
            failure = json.loads((base/'wrong_hash/result.json').read_text())
            self.assertFalse(failure['passed'])
            self.assertIn('Source hash mismatch', failure['error'])
            self.assertFalse((base/'wrong_hash/measured_candidate.json').exists())


if __name__ == '__main__':
    unittest.main()
