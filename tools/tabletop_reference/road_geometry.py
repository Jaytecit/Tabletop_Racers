"""Geometry gates for a single, non-overlapping annular driving surface."""
import numpy as np
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import nearest_points, unary_union
from shapely.strtree import STRtree


class GeometryError(ValueError):
    pass


class DrivingSurface:
    def __init__(self, triangles, height_tolerance=0.02):
        self.triangles = np.asarray(triangles, dtype=float)
        if self.triangles.ndim != 3 or self.triangles.shape[1:] != (3, 3):
            raise GeometryError('Expected an N x 3 x 3 triangle array')
        if not len(self.triangles) or not np.isfinite(self.triangles).all():
            raise GeometryError('Empty or non-finite driving geometry')
        self.height_tolerance = height_tolerance
        self.xy = self.triangles[:, :, [0, 2]]
        self.polygons = [Polygon(t) for t in self.xy]
        # A vertical wall is not a driving surface. Explicitly reject selected
        # degenerate projected faces instead of silently dropping collision walls.
        if any(p.area <= 1e-10 for p in self.polygons):
            raise GeometryError('Selected surface contains vertical/degenerate projected faces')
        self.tree = STRtree(self.polygons)
        self.low, self.high = self.xy.min(1), self.xy.max(1)
        self.inverse = np.linalg.inv(np.stack([self.xy[:, 1]-self.xy[:, 0],
                                              self.xy[:, 2]-self.xy[:, 0]], axis=2))
        self.road = unary_union(self.polygons)
        if self.road.geom_type != 'Polygon' or not self.road.is_valid or len(self.road.interiors) != 1:
            raise GeometryError('Requires one valid connected polygon with one hole; use a reviewed network/layer profile otherwise')
        self.check_overlap_heights()

    def triangle_height(self, index, q):
        bary = self.inverse[index] @ (np.asarray(q)-self.xy[index, 0])
        weights = np.array([1-bary.sum(), *bary])
        return float(weights @ self.triangles[index, :, 1]), weights

    def check_overlap_heights(self):
        # A flat union can hide an overpass. Differences of affine triangle
        # height functions reach extrema at intersection-polygon vertices.
        for i, polygon in enumerate(self.polygons):
            for j in self.tree.query(polygon):
                j = int(j)
                if j <= i:
                    continue
                overlap = polygon.intersection(self.polygons[j])
                if overlap.is_empty:
                    continue
                points = intersection_vertices(overlap)
                for q in points:
                    a, _ = self.triangle_height(i, q)
                    b, _ = self.triangle_height(j, q)
                    if abs(a-b) > self.height_tolerance:
                        raise GeometryError(f'Conflicting road layers at {q}: triangles {i}/{j}, heights {a}/{b}')

    def height(self, q):
        candidates = np.where(np.all(q >= self.low-1e-7, axis=1) &
                              np.all(q <= self.high+1e-7, axis=1))[0]
        hits = []
        for k in candidates:
            h, weights = self.triangle_height(k, q)
            if weights.min() >= -1e-6:
                hits.append(h)
        if not hits:
            raise GeometryError(f'No selected source support at {np.asarray(q).tolist()}')
        if max(hits)-min(hits) > self.height_tolerance:
            raise GeometryError(f'Conflicting selected source support at {q}: {hits}')
        return float(np.mean(hits))

    def clearance_samples(self, spacing):
        inner = LineString(self.road.interiors[0])
        outer = LineString(self.road.exterior)
        widths = []
        for station in np.arange(0, inner.length, spacing):
            a = inner.interpolate(station)
            b = nearest_points(a, outer)[1]
            if self.road.buffer(1e-7).covers(LineString([a, b])):
                widths.append(a.distance(b))
        if not widths:
            raise GeometryError('No supported clearance chords')
        return np.asarray(widths)


def intersection_vertices(geometry):
    if geometry.geom_type == 'Polygon':
        return list(geometry.exterior.coords)
    if geometry.geom_type in ('LineString', 'Point'):
        return list(geometry.coords)
    return [point for part in geometry.geoms for point in intersection_vertices(part)]


def oriented_ring(ring, anchor, clockwise):
    coords = np.asarray(ring.coords)[:-1]
    if Polygon(coords).exterior.is_ccw == clockwise:
        coords = coords[::-1]
    line = LineString(np.vstack([coords, coords[0]]))
    seam = line.project(Point(anchor))
    distance = np.r_[0, np.cumsum(np.linalg.norm(np.diff(coords, axis=0), axis=1))]
    # Split at the exact projection, preserving every original corner.
    rotated = np.vstack([line.interpolate(seam).coords[0], coords[distance > seam],
                         coords[distance < seam], line.interpolate(seam).coords[0]])
    return LineString(rotated)


def pair_rings(surface, anchor, clockwise, ring_spacing=0.5, band=100, max_cells=4000000):
    outer = oriented_ring(surface.road.exterior, anchor, clockwise)
    inner = oriented_ring(surface.road.interiors[0], anchor, clockwise)
    na, nb = int(np.ceil(outer.length/ring_spacing)), int(np.ceil(inner.length/ring_spacing))
    if na < 3 or nb < 3 or (na+1)*(nb+1) > max_cells:
        raise GeometryError('Pairing exceeds configured cell budget; choose a reviewed coarser ring_spacing')
    sa, sb = np.linspace(0, outer.length, na+1), np.linspace(0, inner.length, nb+1)
    aa = np.asarray([outer.interpolate(s).coords[0] for s in sa])
    bb = np.asarray([inner.interpolate(s).coords[0] for s in sb])
    costs = np.full((na+1, nb+1), np.inf)
    steps = np.zeros((na+1, nb+1), np.uint8)
    costs[0, 0] = np.sum((aa[0]-bb[0])**2)
    for i in range(na+1):
        for j in range(max(0, int(i*nb/na)-band), min(nb+1, int(i*nb/na)+band+1)):
            if i == 0 and j == 0:
                continue
            choices = [costs[i-1, j-1] if i and j else np.inf,
                       costs[i-1, j]+0.15 if i else np.inf,
                       costs[i, j-1]+0.15 if j else np.inf]
            step = int(np.argmin(choices))
            steps[i, j] = step
            costs[i, j] = choices[step]+np.sum((aa[i]-bb[j])**2)
    if not np.isfinite(costs[-1, -1]):
        raise GeometryError('No monotonic closed pairing inside the configured search band')
    path, i, j = [], na, nb
    while i or j:
        path.append((i, j))
        step = steps[i, j]
        if step == 0:
            i, j = i-1, j-1
        elif step == 1:
            i -= 1
        else:
            j -= 1
    path = np.asarray([(0, 0), *path[::-1]])
    guide = (aa[path[:, 0]]+bb[path[:, 1]])*0.5
    distances = np.r_[0, np.cumsum(np.linalg.norm(np.diff(guide, axis=0), axis=1))]
    if np.any(np.diff(distances) <= 1e-10):
        raise GeometryError('Pairing guide has a stationary/reversed correspondence')
    return outer, inner, sa[path[:, 0]], sb[path[:, 1]], distances


def sample_pairing(pairing, spacing):
    outer, inner, sa, sb, distances = pairing
    count = max(24, int(np.ceil(distances[-1]/spacing/24))*24)
    stations = np.linspace(0, distances[-1], count, endpoint=False)
    return sample_pairing_at(pairing, stations)


def sample_pairing_corners(pairing, spacing):
    """Retain every ring corner and correspondence knot instead of oversampling
    entire straights to recover a few sharp vertices. No boundary is simplified.
    """
    outer, inner, sa, sb, distances = pairing
    knots = list(distances)
    for ring, source_stations in ((outer, sa), (inner, sb)):
        vertices = np.asarray(ring.coords)
        corners = np.r_[0, np.cumsum(np.linalg.norm(np.diff(vertices, axis=0), axis=1))]
        knots.extend(np.interp(corners, source_stations, distances))
    knots = np.unique(knots)
    knots = knots[np.r_[True, np.diff(knots) > 1e-9]]
    # Preserve every knot, subdivide only longer intervals, then pad to the
    # runtime's 24-span sections by splitting the longest remaining intervals.
    stations = np.concatenate([np.linspace(a, b, max(1, int(np.ceil((b-a)/spacing))), endpoint=False)
                               for a, b in zip(knots[:-1], knots[1:])])
    while len(stations) % 24:
        gaps = np.diff(np.r_[stations, distances[-1]])
        index = int(np.argmax(gaps))
        stations = np.insert(stations, index+1, stations[index]+gaps[index]/2)
    return sample_pairing_at(pairing, stations)


def sample_pairing_at(pairing, stations):
    outer, inner, sa, sb, distances = pairing
    left = np.asarray([outer.interpolate(s).coords[0] for s in np.interp(stations, distances, sa)])
    right = np.asarray([inner.interpolate(s).coords[0] for s in np.interp(stations, distances, sb)])
    center = (left+right)*0.5
    tangent = np.roll(center, -1, axis=0)-np.roll(center, 1, axis=0)
    side = tangent[:, 0]*(left-center)[:, 1]-tangent[:, 1]*(left-center)[:, 0]
    if np.median(side) < 0:
        left, right, side = right, left, -side
    if np.any(side <= 1e-8):
        raise GeometryError('Inconsistent left/right identity or stationary centreline')
    return left, right, center


def validate_corridor(surface, left, right, tolerance, minimum_width):
    failures, residuals, quads = [], [], []
    road = surface.road
    for i in range(len(left)):
        j = (i+1) % len(left)
        quad = Polygon([left[i], left[j], right[j], right[i]])
        quads.append(quad)
        if not quad.is_valid or quad.area <= 1e-10:
            failures.append(dict(span=i, gate='folded_polygon'))
            continue
        for progress in (0.0, 0.5):
            a = left[i]*(1-progress)+left[j]*progress
            b = right[i]*(1-progress)+right[j]*progress
            if np.linalg.norm(a-b) < minimum_width:
                failures.append(dict(span=i, gate='minimum_width', progress=progress))
            for fraction in (0.04, 0.5, 0.96, -0.08, 1.08):
                q = a*(1-fraction)+b*fraction
                inside = road.buffer(1e-7).covers(Point(q))
                expected = 0 <= fraction <= 1
                if inside != expected:
                    failures.append(dict(span=i, gate='source_containment', progress=progress, fraction=fraction))
                if expected and inside:
                    surface.height(q)
        for edge in (left, right):
            for t in (0.25, 0.5, 0.75):
                residuals.append(road.boundary.distance(Point(edge[i]*(1-t)+edge[j]*t)))
    if any(not q.is_valid for q in quads):
        return dict(passed=False, failures=failures)
    tree = STRtree(quads)
    for i, quad in enumerate(quads):
        for j in tree.query(quad):
            j = int(j)
            if j > i and quad.intersection(quads[j]).area > 1e-7:
                failures.append(dict(span=i, other_span=j, gate='overlapping_corridor_polygons'))
    left_line = LineString(np.vstack([left, left[0]]))
    right_line = LineString(np.vstack([right, right[0]]))
    if not left_line.is_simple or not right_line.is_simple or left_line.intersects(right_line):
        failures.append(dict(gate='boundary_self_intersection'))
    max_residual = max(residuals, default=float('inf'))
    if max_residual > tolerance:
        failures.append(dict(gate='sampled_boundary_residual', value=max_residual, tolerance=tolerance))
    widths = np.linalg.norm(left-right, axis=1)
    center = (left+right)*0.5
    return dict(passed=not failures, failures=failures, rows=len(left), sections=len(left)//24,
                length=float(np.linalg.norm(np.roll(center, -1, axis=0)-center, axis=1).sum()),
                width_percentiles=np.percentile(widths, [0, 5, 50, 95, 100]).tolist(),
                sampled_boundary_residual_max=max_residual,
                sampled_boundary_residual_p99=float(np.percentile(residuals, 99)),
                source_checks=len(left)*10, boundary_residual_samples=len(residuals))
