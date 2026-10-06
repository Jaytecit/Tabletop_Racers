"""Provisional road-topology survey; no route or game-resource writes."""
import json
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import Polygon
from shapely.ops import unary_union
from glb_source import Source

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests/baselines/content/glb_folder_audit'
FOLDER = ROOT / 'tracks/GLB Tracks'

def select(file, p):
    n = p['name'].lower()
    m = p['material'].get('name', '').lower()
    if 'mount_rainier' in file:
        return n.startswith('road_road_')
    if 'barcelona' in file:
        return n.startswith('road_road_') and m.startswith('road_')
    if 'montreal' in file:
        return n.startswith('road_road_')
    if 'lake_como' in file:
        return n.startswith(('road_road', 'causeway_road'))
    if 'glen_canyon' in file:
        return n.startswith(('road_road', 'road2_road')) or n == 'track_1_pivot_road_0'
    if 'topspeed' in file:
        return n.startswith('ringoval_road')
    if 'sunrise_ruins' in file:
        return n.startswith(('zona3_road', 'zone1_road', 'zone2_road'))
    if 'chamonix' in file:
        return n.startswith(('area1_road', 'area2_road', 'area3_road', 'insb_road'))
    if 'shanghai' in file:
        return n.startswith(('part01_road','part01b_road','part02_road','part03_road','part04_road','part1_road','part1b_road'))
    if 'wuhu' in file:
        return n in ('wi_road', 'wi_checkptroad')
    if file == 'race_track_map.glb':
        return m == 'road'
    if 'death_rally' in file:
        return n.startswith('dc_') and '_track1' in n
    if file == 'bazaar_track.glb':
        return n.startswith('mesh_bazaar_collision_') and '_collision_w_' not in n
    if file == 'raceway_map.glb':
        return n.startswith('mesh_raceway_collision_rework_') and '_wall_' not in n
    if file == 'town_square_track.glb':
        return n.startswith('track5_townsquare_collision_') and '_collision_w_' not in n
    return False

def main(only=None, label=''):
    results = []
    for path in sorted(FOLDER.glob('*.glb')):
        if only and path.name not in only:
            continue
        if not any(w in path.name for w in ('gt_racing', 'asphalt_injection', 'wuhu', 'race_track_map', 'death_rally', 'bazaar_track', 'raceway_map', 'town_square_track')):
            continue
        source = Source(path)
        selected = [p for p in source.primitives if select(path.name, p)]
        if not selected:
            continue
        tris = np.concatenate([p['vertices'][p['indices']] for p in selected])
        xy = tris[:, :, [0, 2]]
        polygons = [Polygon(t) for t in xy]
        polygons = [p for p in polygons if p.area > 1e-9]
        road = unary_union(polygons)
        parts = list(road.geoms) if road.geom_type == 'MultiPolygon' else [road]
        parts = sorted(parts, key=lambda p: -p.area)
        row = dict(file=path.name, selected=[dict(name=p['name'], surface=p['surface']) for p in selected],
                   triangles=len(tris), components=len(parts), holes=[len(p.interiors) for p in parts[:10]],
                   area_fractions=[p.area/road.area for p in parts[:10]], valid=road.is_valid,
                   height_range=[float(tris[:,:,1].min()),float(tris[:,:,1].max())],
                   caveat='Provisional semantic selection. X/Z union is not a layer-aware boundary validation.')
        results.append(row)
        (OUT/f'road_topology{label}.json').write_text(json.dumps(results, indent=2))
        (OUT/(path.stem+'_road.geojson')).write_text(json.dumps(road.__geo_interface__))
        lo=np.array(road.bounds[:2]);hi=np.array(road.bounds[2:]);factor=680/(hi-lo).max()
        image=Image.new('RGB',(740,780),'#161c25');draw=ImageDraw.Draw(image)
        for part in parts:
            draw.polygon([tuple(q) for q in (np.array(part.exterior.coords)-lo)*factor+30],fill='#495a67')
            for ring in [part.exterior,*part.interiors]:
                draw.line([tuple(q) for q in (np.array(ring.coords)-lo)*factor+30],fill='#4bd9e1',width=2)
        draw.text((15,735),path.stem,fill='white')
        draw.text((15,755),f'{len(parts)} projected components; holes {row["holes"][:5]} (provisional selection)',fill='white')
        image.save(OUT/(path.stem+'_road.png'))
        print(path.name, 'components',len(parts),'holes',row['holes'][:5],flush=True)
    for start in range(0,len(results),12):
        sheet=Image.new('RGB',(1480,1170),'#161c25')
        for i,row in enumerate(results[start:start+12]):
            tile=Image.open(OUT/(Path(row['file']).stem+'_road.png')).resize((370,390))
            sheet.paste(tile,((i%4)*370,(i//4)*390))
        sheet.save(OUT/f'road_plans{label}_{start//12+1}.jpg')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', nargs='+', help='Exact source filenames')
    parser.add_argument('--label', default='', help='Suffix for separate retained evidence')
    args = parser.parse_args()
    main(args.only, args.label)
