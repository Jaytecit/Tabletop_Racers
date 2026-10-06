"""Extract reviewed annular road meshes into a fresh candidate evidence folder."""
import argparse
from datetime import datetime, timezone
import json
import re
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw
from glb_source import Source
from raster_source import raster
from road_geometry import DrivingSurface, GeometryError, pair_rings, sample_pairing, sample_pairing_corners, validate_corridor

ROOT = Path(__file__).resolve().parents[2]


def select_triangles(source, selectors):
    if not selectors:
        raise GeometryError('An explicit reviewed primitive selection is required')
    selected, seen = [], set()
    for selector in selectors:
        identity = (selector['name'], selector['surface'])
        if identity in seen:
            raise GeometryError(f'Duplicate primitive selection: {identity}')
        seen.add(identity)
        matches = [p for p in source.primitives if (p['name'], p['surface']) == identity]
        if len(matches) != 1:
            raise GeometryError(f'Expected one selected primitive {identity}, found {len(matches)}')
        p = matches[0]
        indices = p['indices']
        if 'triangle_indices' in selector:
            mask = np.asarray(selector['triangle_indices'])
            if mask.ndim != 1 or mask.dtype.kind not in 'iu' or not len(mask) or len(np.unique(mask)) != len(mask):
                raise GeometryError(f'Invalid triangle mask for {identity}')
            if mask.min() < 0 or mask.max() >= len(indices):
                raise GeometryError(f'Triangle mask outside primitive {identity}')
            indices = indices[mask]
        selected.append(p['vertices'][indices])
    return np.concatenate(selected)


def reserve_output(path):
    path = path.resolve()
    # This command must never write to accepted courses or imported assets.
    for protected in ('tracks', 'assets', 'environments', 'scripts', '.summer'):
        if path.is_relative_to(ROOT / protected):
            raise GeometryError(f'Candidate output cannot be inside {protected}/')
    if path == ROOT or ROOT.is_relative_to(path):
        raise GeometryError('Candidate output must be a dedicated evidence folder')
    path.mkdir(parents=True, exist_ok=False)
    return path


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False)+'\n', encoding='utf-8')


def extract(profile, output):
    write_json(output/'profile_snapshot.json', profile)
    if not re.fullmatch(r'[a-z][a-z0-9_]{0,63}', profile['id']):
        raise GeometryError('Course id must use lowercase letters, digits and underscores')
    for field in ('source_height_tolerance', 'native_clearance_spacing', 'height_tolerance',
                  'ring_spacing', 'sample_spacing', 'minimum_width', 'boundary_tolerance', 'preview_spacing'):
        if not np.isfinite(profile[field]) or profile[field] <= 0:
            raise GeometryError(f'{field} must be finite and positive')
    for field in ('pairing_band', 'max_pairing_cells', 'max_preview_pixels', 'refinement_attempts'):
        if type(profile[field]) is not int or profile[field] <= 0:
            raise GeometryError(f'{field} must be a positive integer')
    if type(profile['clockwise_xz']) is not bool:
        raise GeometryError('clockwise_xz must be boolean')
    source_path = Path(profile['source'])
    if not source_path.is_absolute():
        source_path = ROOT / source_path
    source = Source(source_path)
    if source.sha256 != profile['source_sha256']:
        raise GeometryError(f'Source hash mismatch: expected {profile["source_sha256"]}, found {source.sha256}')
    raw_triangles = select_triangles(source, profile['road_primitives'])
    native = DrivingSurface(raw_triangles, profile['source_height_tolerance'])
    widths = native.clearance_samples(profile['native_clearance_spacing'])
    if ('transform' in profile) == ('scale_to_median_width' in profile):
        raise GeometryError('Choose exactly one explicit transform or scale_to_median_width')
    if 'transform' in profile:
        scale = float(profile['transform']['scale'])
        offset = np.asarray(profile['transform']['offset'], dtype=float)
    else:
        scale = float(profile['scale_to_median_width']) / float(np.median(widths))
        low, high = raw_triangles.min((0, 1)), raw_triangles.max((0, 1))
        offset = np.array([-(low[0]+high[0])*scale/2, -low[1]*scale, -(low[2]+high[2])*scale/2])
    if not np.isfinite(scale) or scale <= 0 or offset.shape != (3,) or not np.isfinite(offset).all():
        raise GeometryError('Invalid uniform source-to-game transform')
    triangles = raw_triangles*scale+offset
    surface = DrivingSurface(triangles, profile['height_tolerance'])
    anchor = np.asarray(profile['start_anchor_source'], dtype=float)*scale+offset[[0, 2]]
    if anchor.shape != (2,) or not np.isfinite(anchor).all():
        raise GeometryError('Invalid source X/Z start anchor')
    pairing = pair_rings(surface, anchor, profile['clockwise_xz'], profile['ring_spacing'],
                         profile['pairing_band'], profile['max_pairing_cells'])
    checks, rows = {}, []
    for attempt in range(profile.get('refinement_attempts', 1)):
        spacing = profile['sample_spacing'] / 2**attempt
        sampler = sample_pairing_corners if profile.get('preserve_boundary_corners', False) else sample_pairing
        left, right, center = sampler(pairing, spacing)
        checks = validate_corridor(surface, left, right, profile['boundary_tolerance'], profile['minimum_width'])
        checks.update(attempt=attempt, sample_spacing=spacing)
        write_json(output/f'geometry_checks_{attempt}.json', checks)
        rows = [dict(left=[float(a[0]), surface.height(a), float(a[1])],
                     right=[float(b[0]), surface.height(b), float(b[1])],
                     center=[float(c[0]), surface.height(c), float(c[1])], section=i//24)
                for i, (a, b, c) in enumerate(zip(left, right, center))]
        write_json(output/f'measured_attempt_{attempt}.json', rows)
        if checks['passed']:
            break
    write_json(output/'geometry_checks.json', checks)
    if not checks['passed']:
        raise GeometryError(f'Corridor gates failed: {len(checks["failures"])} failures; see retained attempts')
    # Source boundary vertices remain intact, separate from the paired samples.
    rings = {}
    for name, ring in [('outer', surface.road.exterior), ('inner', surface.road.interiors[0])]:
        rings[name] = [[float(q[0]), surface.height(np.asarray(q)), float(q[1])] for q in ring.coords]
    write_json(output/'road_boundaries.json', rings)
    write_json(output/'road_union.geojson', surface.road.__geo_interface__)
    write_json(output/'measured_candidate.json', rows)
    count = len(rows)//24
    manifest = dict(id=profile['id'], title=profile['title'], description=profile['description'],
                    revision=1, status='candidate geometry gates passed; rendered/source review and gameplay acceptance pending',
                    source=str(source_path.resolve()), source_sha256=source.sha256,
                    source_metadata=source.doc.get('asset', {}),
                    transform=dict(scale=scale, offset=offset.tolist()),
                    road_primitives=profile['road_primitives'],
                    road_meshes=list(dict.fromkeys(s['name'] for s in profile['road_primitives'])),
                    boundary_definition=profile['boundary_definition'],
                    start_station=0.0, start_cue=profile['start_cue'],
                    route_direction='clockwise X/Z' if profile['clockwise_xz'] else 'counterclockwise X/Z',
                    section_surfaces=[profile['handling_preset']]*count, section_layers=[0]*count,
                    handling_note=profile['handling_note'], mesh_compression=False,
                    topology=dict(components=1, holes=1, valid=True, conflicting_layers=False),
                    height_tolerance=profile['height_tolerance'], boundary_tolerance=profile['boundary_tolerance'],
                    native_clearance_percentiles=np.percentile(widths, [0, 5, 50, 95, 100]).tolist(),
                    uncertainty=['Source cue, visible perimeter and collision need rendered review; not auto-accepted'],
                    geometry_checks=checks)
    vertices = raw_triangles.reshape(-1, 3)
    # Three separated raw-source landmarks independently test engine transforms.
    landmark_indices = [int(np.argmin(vertices[:, 0]+vertices[:, 2]))]
    for _ in range(2):
        distances = np.min([np.linalg.norm(vertices[:, [0, 2]]-vertices[i, [0, 2]], axis=1)
                            for i in landmark_indices], axis=0)
        landmark_indices.append(int(np.argmax(distances)))
    manifest['source_landmarks_game'] = [(vertices[i]*scale+offset).tolist() for i in landmark_indices]
    manifest['landmark_tolerance'] = 0.001
    for key in ('visible_meshes', 'collision_meshes'):
        if key in profile:
            available = {p['name'] for p in source.primitives}
            if not profile[key] or any(name not in available for name in profile[key]):
                raise GeometryError(f'Unknown or empty {key} selection')
            manifest[key] = profile[key]
    if 'bake_collision_transform' in profile:
        if type(profile['bake_collision_transform']) is not bool:
            raise GeometryError('bake_collision_transform must be boolean')
        manifest['bake_collision_transform'] = profile['bake_collision_transform']
    write_json(output/'measurement_manifest_candidate.json', manifest)
    # A source-only UV raster plus the same measured corridor; no fixed-width
    # reconstruction or alternate visual boundaries.
    low, high = triangles.min((0, 1))[[0, 2]], triangles.max((0, 1))[[0, 2]]
    spacing = profile['preview_spacing']
    origin = low - spacing*8
    shape = np.ceil((high-low)/spacing).astype(int)[::-1]+17
    if int(np.prod(shape)) > profile['max_preview_pixels']:
        raise GeometryError('Preview exceeds configured pixel budget')
    transformed_source = Source(source_path, scale, offset)
    # Dedicated collision roads can be untextured. Review their boundaries over
    # the explicit UV-mapped visible surfaces, using the same source transform.
    preview_selectors = profile.get('preview_primitives', profile['road_primitives'])
    select_triangles(transformed_source, preview_selectors)  # Validate identities/masks.
    names = list(dict.fromkeys(s['name'] for s in preview_selectors))
    preview_primitives = []
    for selector in preview_selectors:
        p = next(p for p in transformed_source.primitives
                 if (p['name'], p['surface']) == (selector['name'], selector['surface']))
        if 'triangle_indices' in selector:
            p = dict(p, indices=p['indices'][selector['triangle_indices']])
        preview_primitives.append(p)
    transformed_source.primitives = preview_primitives
    data = raster(transformed_source, names, origin, spacing, tuple(shape), profile.get('preview_height_range'))
    image = Image.fromarray(data['rgb'])
    image.save(output/'source_road.png')
    draw = ImageDraw.Draw(image)
    for points, color in ((left, 'cyan'), (right, 'magenta'), (center, 'yellow')):
        coords = (np.vstack([points, points[0]])-origin)/spacing
        draw.line([tuple(q) for q in coords], fill=color, width=2)
    image.save(output/'candidate_overlay.png')
    write_json(output/'preview_transform.json', dict(origin=origin.tolist(), spacing=spacing, shape=shape.tolist()))
    write_json(output/'result.json', dict(passed=True, scope='source geometry candidate only',
                                        sections=count, rows=len(rows), length=checks['length'],
                                        candidate=str(output/'measured_candidate.json')))
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', type=Path)
    parser.add_argument('--out', type=Path, help='New evidence directory; existing directories are never overwritten')
    args = parser.parse_args()
    output = None
    try:
        profile = json.loads(args.profile.read_text(encoding='utf-8'))
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ')
        output = reserve_output(args.out or ROOT/'tests/baselines/content'/profile['id']/'extraction'/stamp)
        manifest = extract(profile, output)
        print(json.dumps(dict(output=str(output), **manifest['geometry_checks'])))
    except Exception as exc:
        failure = dict(passed=False, error=f'{type(exc).__name__}: {exc}')
        if output is not None:
            write_json(output/'result.json', failure)
        print(json.dumps(dict(output=str(output) if output else None, **failure)), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
