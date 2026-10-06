"""Source-only Mount Rainier road audit; never edits existing courses."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import Polygon, Point, LineString
from shapely.ops import unary_union, nearest_points
import struct
from glb_source import Source
from raster_source import raster

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests/baselines/content/mount_rainier'
SOURCE = Path('C:/Users/jayte/Downloads/gt_racing_2_-_mount_rainier.glb')
NAMES = ['road_road_PIVOT.001_road_0', 'road_road_PIVOT.002_road_marking_0',
         'road_road_PIVOT.003_road_clean_0']

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Source(SOURCE)
    selected = [p for p in source.primitives if p['name'] in NAMES]
    triangles = np.concatenate([p['vertices'][p['indices']] for p in selected])
    polygons = [Polygon(t[:, [0, 2]]) for t in triangles]
    polygons = [p for p in polygons if p.area > 1e-8]
    road = unary_union(polygons)
    parts = list(road.geoms) if road.geom_type == 'MultiPolygon' else [road]
    print('parts', [(round(p.area, 3), len(p.interiors)) for p in sorted(parts, key=lambda p:-p.area)][:30])
    (OUT/'road_union.geojson').write_text(json.dumps(road.__geo_interface__))
    origin = np.array([-700., -600.])
    data = raster(source, NAMES, origin, .5, (1400, 1800))
    np.savez_compressed(OUT/'road_source.npz', **data)
    Image.fromarray(data['rgb']).save(OUT/'road_source.png')
    image = Image.fromarray(data['rgb'])
    draw = ImageDraw.Draw(image)
    for p in parts:
        for i, ring in enumerate([p.exterior, *p.interiors]):
            xy = (np.array(ring.coords)-origin)/.5
            draw.line([tuple(x) for x in xy], fill='cyan' if i == 0 else 'magenta', width=2)
    image.save(OUT/'road_topology.png')
    print('triangles', len(triangles), 'bounds', road.bounds)
    assert road.geom_type == 'Polygon' and len(road.interiors) == 1 and road.is_valid
    # Independent topology rings, retaining every original corner. Sample heights
    # barycentrically from the selected source triangles, including union vertices.
    xy = triangles[:, :, [0, 2]]
    low, high = xy.min(1), xy.max(1)
    def height(q):
        candidates = np.where(np.all(q >= low-1e-6, axis=1) & np.all(q <= high+1e-6, axis=1))[0]
        hits = []
        for index in candidates:
            t = xy[index]
            mat = np.stack([t[1]-t[0], t[2]-t[0]], axis=1)
            if abs(np.linalg.det(mat)) < 1e-9:
                continue
            b = np.linalg.solve(mat, q-t[0])
            w = np.array([1-b.sum(), *b])
            if w.min() >= -1e-5:
                hits.append(float(w @ triangles[index, :, 1]))
        if not hits:
            raise ValueError(f'Boundary lacks source triangle support: {q}')
        if max(hits)-min(hits) > .05:
            raise ValueError(f'Overlapping road layers: {q}, {hits}')
        return max(hits)
    rings = [road.exterior, road.interiors[0]]
    native = [[ [float(q[0]), height(np.array(q)), float(q[1])] for q in ring.coords ] for ring in rings]
    widths = []
    cross_sections = []
    inner, outer = LineString(rings[1]), LineString(rings[0])
    for distance in np.arange(0., inner.length, 1.):
        a = inner.interpolate(distance)
        b = nearest_points(a, outer)[1]
        chord = LineString([a, b])
        if road.buffer(1e-6).covers(chord):
            widths.append(a.distance(b))
            cross_sections.append([list(a.coords)[0], list(b.coords)[0]])
    print('native width percentiles', np.percentile(widths,[0,5,50,95,100]).tolist())
    # Match the accepted tabletop road's usable multi-car proportions. Keep the
    # buggy at its existing size; target a median road width of six game units.
    scale = float(6. / np.median(widths))
    bounds = np.array(road.bounds)
    offset = np.array([-(bounds[0]+bounds[2])*.5*scale, -triangles[:,:,1].min()*scale,
                       -(bounds[1]+bounds[3])*.5*scale])
    transformed = [[(np.array(q)*scale+offset).tolist() for q in ring] for ring in native]
    content = ROOT/'tracks/mount_rainier'
    content.mkdir(parents=True, exist_ok=True)
    (content/'road_boundaries.json').write_text(json.dumps(dict(outer=transformed[0],inner=transformed[1]),indent=2))
    (OUT/'road_boundaries_source.json').write_text(json.dumps(dict(outer=native[0],inner=native[1]),indent=2))
    manifest = dict(title='Mount Rainier', status='geometry extracted; not registered as a playable course',
        source=str(SOURCE), source_sha256=source.sha256, source_metadata=source.doc.get('asset',{}),
        boundary_definition='asphalt perimeter of the three joined road meshes; excludes scenery, tyre-track overlays and pavement',
        road_meshes=NAMES, transform=dict(scale=scale,offset=offset.tolist()),
        topology=dict(connected_components=1,holes=1,valid=True,outer_vertices=len(native[0])-1,inner_vertices=len(native[1])-1),
        heights='barycentric source-triangle heights; reject missing support and overlapping layers over 0.05 source units',
        width_method='1 source-unit stations on inner boundary, nearest exterior point, chord must remain within road',
        native_width_percentiles=dict(zip(['min','p05','median','p95','max'],np.percentile(widths,[0,5,50,95,100]).tolist())),
        game_width_percentiles=dict(zip(['min','p05','median','p95','max'],(np.percentile(widths,[0,5,50,95,100])*scale).tolist())),
        game_road_bounds=[[float(bounds[0]*scale+offset[0]),float(bounds[1]*scale+offset[2])],
                          [float(bounds[2]*scale+offset[0]),float(bounds[3]*scale+offset[2])]],
        game_elevation_range=(np.array([triangles[:,:,1].min(),triangles[:,:,1].max()])*scale+offset[1]).tolist(),
        vehicle=dict(scene='res://scenes/vehicles/arcade_car.tscn',visual_length=1.0563702583313,visual_width=.819999992847443,
                     visual_height=.77099996805191,collision_size=[.85,.4,.54],
                     dimension_method='Summer mesh AABB traversal after buggy_visual.build; includes tyres, hubs, cage and lights'),
        limitations=['Asphalt boundaries are extracted, rather than painted lane lines.',
                    'Nearest-boundary distances describe local clearance; they are not paired gameplay cross-sections.',
                    'No centreline, checkpoints, collision/gameplay or performance verification in this geometry task.'])
    (OUT/'geometry_manifest.json').write_text(json.dumps(manifest,indent=2))
    # Keep a subsequent playable-course manifest intact during source-only audits.
    manifest_path = content/'measurement_manifest.json'
    if not manifest_path.exists() or json.loads(manifest_path.read_text()).get('status','').startswith('geometry extracted'):
        manifest_path.write_text(json.dumps(manifest,indent=2))
    # A new parent node applies precisely the same transform to all geometry.
    doc = json.loads(json.dumps(source.doc))
    scene = doc['scenes'][doc.get('scene',0)]
    wrapper = len(doc['nodes'])
    doc['nodes'].append(dict(name='MountRainierVehicleScale',children=scene['nodes'],scale=[scale]*3,translation=offset.tolist()))
    scene['nodes'] = [wrapper]
    encoded = json.dumps(doc,separators=(',',':')).encode()
    encoded += b' ' * (-len(encoded)%4)
    binary = source.bin + b'\0' * (-len(source.bin)%4)
    result = struct.pack('<III',0x46546c67,2,12+8+len(encoded)+8+len(binary))
    result += struct.pack('<II',len(encoded),0x4e4f534a)+encoded
    result += struct.pack('<II',len(binary),0x004e4942)+binary
    asset = ROOT/'assets/imported/racing/mount_rainier.glb'
    asset.parent.mkdir(parents=True,exist_ok=True)
    asset.write_bytes(result)
    check = Source(asset)
    assert check.bin == source.bin
    residual = max(float(np.max(abs(b['vertices']-(a['vertices']*scale+offset)))) for a,b in zip(source.primitives,check.primitives))
    assert residual < 1e-9 and len(check.primitives) == len(source.primitives)
    checks = dict(passed=True,primitive_count=len(check.primitives),boundary_vertices=sum(len(x)-1 for x in native),
                  max_transform_residual=residual,binary_geometry_and_textures_preserved=True,
                  all_boundary_vertices_supported=True,scaled_sha256=check.sha256)
    (OUT/'geometry_checks.json').write_text(json.dumps(checks,indent=2))
    print('scale',scale,'game widths',manifest['game_width_percentiles'],'checks',checks)
    preview = Image.new('RGB',(1200,1040),'#141b23')
    draw = ImageDraw.Draw(preview)
    draw.text((28,18),'MOUNT RAINIER | Source-derived asphalt boundaries',fill='white')
    draw.text((28,40),f'Scale {scale:.6f}x | Road footprint {(bounds[2]-bounds[0])*scale:.1f} x {(bounds[3]-bounds[1])*scale:.1f} game units',fill='white')
    draw.text((28,62),'Cyan: outer boundary   Magenta: inner boundary   Heights: source triangles',fill='white')
    preview.paste(image.resize((1150,894)),(25,88))
    draw.text((28,992),f'Road width: {min(widths)*scale:.2f} minimum / 6.00 median / {max(widths)*scale:.2f} maximum',fill='white')
    draw.text((28,1014),'Existing buggy: 1.056 long x 0.820 wide | Geometry audit; gameplay integration pending',fill='white')
    preview.save(OUT/'boundary_preview.png')

if __name__ == '__main__':
    main()
