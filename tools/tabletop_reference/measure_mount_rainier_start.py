"""Locate the owner-selected transverse road marking without refitting the route."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from glb_source import Source
from raster_source import raster

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'tracks/mount_rainier'
OUT = ROOT / 'tests/baselines/content/mount_rainier/start_alignment'

def main(apply=False):
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((BASE/'measurement_manifest.json').read_text())
    route_bytes = (BASE/'measured_route.json').read_bytes()
    rows = json.loads(route_bytes)
    source = Source(ROOT/'assets/imported/tabletop/mount_rainier.glb',
                    manifest['transform']['scale'], manifest['transform']['offset'])
    assert source.sha256 == manifest['source_sha256']
    # The owner's pictured double transverse stripe on the southwest town straight.
    # This search box identifies that marking; its position comes from source UVs.
    origin = np.array([-90., 80.])
    spacing = .025
    names = [p['name'] for p in source.primitives if 'road' in p['name']]
    data = raster(source, names, origin, spacing, (1000, 1400), (-.1, .4))
    image = Image.fromarray(data['rgb'])
    image.save(OUT/'source_marking.png')
    center = np.array([r['center'] for r in rows])
    xz = center[:, [0, 2]]
    delta = np.roll(xz, -1, axis=0)-xz
    lengths = np.r_[0., np.cumsum(np.linalg.norm(delta, axis=1))]
    def sample(station):
        i = np.searchsorted(lengths, station, side='right')-1
        t = (station-lengths[i])/(lengths[i+1]-lengths[i])
        point = center[i]*(1-t)+center[(i+1)%len(rows)]*t
        direction = delta[i]/np.linalg.norm(delta[i])
        return point, direction
    scores = []
    for station in np.arange(lengths[-1]-30, lengths[-1]-5, spacing/2):
        point, direction = sample(station)
        # Interior probes exclude curb paint and test a full transverse stripe.
        probes = point[[0, 2]]+np.linspace(-2.65, 2.65, 121)[:, None]*np.array([-direction[1], direction[0]])
        pixels = np.rint((probes-origin)/spacing).astype(int)
        rgb = data['rgb'][pixels[:, 1], pixels[:, 0]]
        scores.append((station, float(np.mean(rgb.min(1)>175))))
    bands = []
    for station, score in scores:
        if score<.7: continue
        if not bands or station-bands[-1][-1][0]>spacing: bands.append([])
        bands[-1].append((station, score))
    assert len(bands)==2, 'Expected the two full-width solid paint bands; inspect evidence'
    peaks = [max(band, key=lambda p:p[1])[0] for band in bands]
    station = float(np.mean(peaks))
    point, direction = sample(station)
    result = dict(source_sha256=source.sha256,
                  measured_route_sha256=hashlib.sha256(route_bytes).hexdigest(),
                  previous_start_station=0., start_station=station,
                  shift_back=lengths[-1]-station, game_position=point.tolist(),
                  source_position=((point-np.array(manifest['transform']['offset']))/manifest['transform']['scale']).tolist(),
                  direction=direction.tolist(), full_width_band_peaks=peaks,
                  analysis_spacing=spacing, station_spacing=spacing/2,
                  alignment_tolerance=.05,
                  method='Midplane between two source-UV full-width solid paint bands, selected by owner image; route unchanged')
    (OUT/'measurement.json').write_text(json.dumps(result, indent=2))
    draw = ImageDraw.Draw(image)
    for s, color in [(0., 'orange'), (station, 'cyan')]:
        p, d = sample(s if s else lengths[-1]-.001)
        edge = p[[0,2]]+np.array([-3.4,3.4])[:,None]*np.array([-d[1],d[0]])
        draw.line([tuple(q) for q in (edge-origin)/spacing], fill=color, width=2)
    image.save(OUT/'timing_plane_fit.png')
    if apply:
        manifest['revision'] = 2
        manifest['start_station'] = station
        manifest['start_cue'] = 'FINISH flags on owner-selected double transverse stripe, independently located through source UVs'
        manifest['start_alignment'] = result
        (BASE/'measurement_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    assert (BASE/'measured_route.json').read_bytes()==route_bytes
    print(json.dumps(result, indent=2))

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    main(parser.parse_args().apply)
