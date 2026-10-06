"""Source-only Town Square inventory and UV road review; no accepted writes."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from glb_source import Source
from raster_source import raster
from road_geometry import DrivingSurface

ROOT = Path(__file__).resolve().parents[2]
out = ROOT/'tests/baselines/content/town_square/source01'
out.mkdir(parents=True, exist_ok=False)
source = Source(ROOT/'tracks/GLB Tracks/town_square_track.glb')
road = source.primitives[0]
assert road['name'] == 'Track5_TownSquare_Collision_Track5_TownSquare_Collision_new_0'
surface = DrivingSurface(road['vertices'][road['indices']], 0.00001)
widths = surface.clearance_samples(0.005)
data = raster(source, [p['name'] for p in source.primitives[2:]], np.array([-0.4,-0.5]),0.0005,(2000,1800),[-0.004,0.004])
Image.fromarray(data['rgb']).save(out/'source-road.png')
np.savez_compressed(out/'road-raster.npz', **data)
result = dict(source_sha256=source.sha256, metadata=source.doc['asset'],
              width_percentiles=np.percentile(widths,[0,5,50,95,100]).tolist(),
              bounds=list(surface.road.bounds), triangles=len(surface.triangles),
              components=1,holes=1, conflicting_layers=False)
(out/'inventory.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
