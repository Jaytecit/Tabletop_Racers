extends Node3D
@export var definition: Resource = preload("res://tracks/game_table/definition.tres")
var points: PackedVector2Array = []
var lengths: PackedFloat32Array = []
var starts: PackedVector3Array = []
var ends: PackedVector3Array = []
var section_ids: PackedInt32Array = []
var total_length: float = 0.0
var half_width: float = 3.0
var validation_errors: Array[String] = []
var gates: Array[Dictionary] = []
var anchors: Array[Dictionary] = []
var corridor_polygons: Array[PackedVector2Array] = []
var corridor_bounds: Array[Rect2] = []

func _ready() -> void:
	build()
	if validation_errors.is_empty(): rebuild_art()

func build() -> void:
	validation_errors = preload("res://scripts/tracks/track_validator.gd").validate(definition)
	points.clear()
	lengths.clear()
	starts.clear()
	ends.clear()
	section_ids.clear()
	gates.clear()
	anchors.clear()
	corridor_polygons.clear()
	corridor_bounds.clear()
	total_length = 0.0
	if not validation_errors.is_empty(): return
	for index: int in range(definition.sections.size()):
		var section: Resource = definition.sections[index]
		for step: int in range(24):
			var a: Vector3 = section.point(float(step)/24.0)
			var b: Vector3 = section.point(float(step+1)/24.0)
			starts.append(a)
			ends.append(b)
			section_ids.append(index)
			points.append(Vector2(a.x,a.z))
			lengths.append(total_length)
			total_length += Vector2(a.x-b.x,a.z-b.z).length()
	for i: int in range(starts.size()):
		var polygon: PackedVector2Array = make_road_polygon(i)
		corridor_polygons.append(polygon)
		var bounds: Rect2 = Rect2(polygon[0],Vector2.ZERO)
		for p: Vector2 in polygon: bounds = bounds.expand(p)
		corridor_bounds.append(bounds.grow(0.001))
	points.append(points[0])
	lengths.append(total_length)
	half_width = definition.sections[0].width*0.5
	if definition.start_station<0.0 or definition.start_station>=total_length:
		validation_errors.append("Start station outside route")
		return
	for i: int in range(definition.gate_count):
		var s: float = fposmod(definition.start_station+float(i)*total_length/definition.gate_count,total_length)
		var data: Dictionary = at(s)
		data.station = s
		data.index = i
		gates.append(data)
	for i: int in range(int(ceil(total_length))):
		var data: Dictionary = at(float(i))
		if definition.sections[data.section].anchor and data.surface!="water":
			data.station = float(i)
			anchors.append(data)
	if anchors.is_empty():
		validation_errors.append("No sampled recovery anchors")
		return
	for i: int in range(anchors.size()):
		if fposmod(anchors[(i+1)%anchors.size()].station-anchors[i].station,total_length)>10.0:
			validation_errors.append("Recovery anchors must be reachable within 10 route units")
			break
func segment(station: float) -> int:
	var s: float = fposmod(station,total_length)
	var lo: int = 0
	var hi: int = lengths.size()-2
	while lo<hi:
		var mid: int = int((lo+hi+1)/2.0)
		if lengths[mid]<=s: lo = mid
		else: hi = mid-1
	return lo
func sample(station: float) -> Vector2:
	var p: Vector3 = sample_3d(station)
	return Vector2(p.x,p.z)
func sample_3d(station: float) -> Vector3:
	var s: float = fposmod(station,total_length)
	var i: int = segment(s)
	return starts[i].lerp(ends[i],(s-lengths[i])/maxf(lengths[i+1]-lengths[i],0.001))
func direction(station: float) -> Vector2:
	return (sample(station+0.25)-sample(station-0.25)).normalized()
func at(station: float) -> Dictionary:
	var i: int = segment(station)
	var section: Resource = definition.sections[section_ids[i]]
	var edge3: Vector3 = ends[i]-starts[i]
	var tangent: Vector2 = direction(station)
	var slope: float = edge3.y/maxf(Vector2(edge3.x,edge3.z).length(),0.001)
	return {"position":sample_3d(station),"normal":Vector3(-tangent.x*slope,1.0,-tangent.y*slope).normalized(),
		"section":section_ids[i],"layer":section.layer,"width":section.width_at((float(i%24)+(fposmod(station,total_length)-lengths[i])/maxf(lengths[i+1]-lengths[i],0.001))/24.0),"surface":section.surface,"edge":section.edge}

# Broad search is only for initial placement/tools. Driving uses a station window.
func project_3d(pos: Vector3, hint: float = -1.0, window: float = 5.0) -> Dictionary:
	var closest: float = INF
	var station: float = 0.0
	var distance2: float = INF
	var nearest_index: int = 0
	var base: int = segment(hint) if hint>=0.0 else 0
	var first: int = 0
	var last: int = starts.size()-1
	if hint>=0.0:
		first = base
		last = base
		while first>base-starts.size()+1 and fposmod(hint-lengths[posmod(first,starts.size())],total_length)<window: first -= 1
		while last<base+starts.size()-1 and fposmod(lengths[posmod(last+1,starts.size())]-hint,total_length)<window: last += 1
		# The current segment always belongs in the window, including near its end.
		if last==base: last += 1
	for index: int in range(first,last+1):
		var i: int = posmod(index,starts.size())
		if hint>=0.0:
			var section: int = section_ids[i]
			var current: int = section_ids[base]
			var count: int = definition.sections.size()
			if section!=current and section!=posmod(current-1,count) and section!=posmod(current+1,count): continue
		var a: Vector2 = Vector2(starts[i].x,starts[i].z)
		var edge: Vector2 = Vector2(ends[i].x-starts[i].x,ends[i].z-starts[i].z)
		var t: float = clampf((Vector2(pos.x,pos.z)-a).dot(edge)/maxf(edge.length_squared(),0.0001),0.0,1.0)
		var p: Vector3 = starts[i].lerp(ends[i],t)
		var ds: float = Vector2(pos.x-p.x,pos.z-p.z).length_squared()
		var score: float = ds+pow(pos.y-p.y,2.0)*0.2
		if score<closest:
			closest = score
			nearest_index = i
			distance2 = ds
			station = lerpf(lengths[i],lengths[i+1],t)
	var data: Dictionary = at(station)
	data.station = fposmod(station,total_length)
	var on_road: bool = false
	var point: Vector2 = Vector2(pos.x,pos.z)
	# Measured cross-sections need not be perpendicular to the centre spline.
	# Check the local corridor, not just the nearest centre segment's neighbours.
	var measured: bool = definition.sections[data.section].has_measured_edges()
	var corridor_first: int = first if measured else nearest_index-1
	var corridor_last: int = last if measured else nearest_index+1
	for index: int in range(corridor_first,corridor_last+1):
		var i: int = posmod(index,starts.size())
		if not corridor_bounds[i].has_point(point): continue
		var section: Resource = definition.sections[section_ids[i]]
		var section_gap: int = absi(section_ids[i]-int(data.section))
		var connected: bool = section_gap<=1 or section_gap==definition.sections.size()-1
		if section.layer!=data.layer and not (measured and connected): continue
		# Compare height at the car's projected point, not the segment start.
		# Steeper connected ramps can rise >0.15 within one sampled segment.
		var span: Vector2 = Vector2(ends[i].x-starts[i].x,ends[i].z-starts[i].z)
		var local_t: float = clampf((point-Vector2(starts[i].x,starts[i].z)).dot(span)/maxf(span.length_squared(),0.0001),0.0,1.0)
		if (not measured or section.layer!=data.layer) and absf(lerpf(starts[i].y,ends[i].y,local_t)-data.position.y)>0.15: continue
		var polygon: PackedVector2Array = road_polygon(i)
		if Geometry2D.is_point_in_polygon(point,polygon):
			on_road = true
			if measured: data.position.y = measured_height(i,point)
			break
		for edge: int in range(4):
			if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,polygon[edge],polygon[(edge+1)%4]))<0.00000001:
				on_road = true
				break
		if on_road: break
	# The corridor distance sent to lap validation agrees with the drawn strip,
	# including the tiny area beyond a centreline endpoint at an outer join.
	data.distance = minf(sqrt(distance2),data.width*0.5) if on_road else maxf(sqrt(distance2),data.width*0.5+0.001)
	data.supported = on_road and data.surface!="water"
	return data

func measured_height(index: int, point: Vector2) -> float:
	var polygon: PackedVector2Array = road_polygon(index)
	var a: PackedVector3Array = road_edges(index)
	var b: PackedVector3Array = road_edges(index+1)
	var heights: PackedFloat32Array = PackedFloat32Array([a[0].y,b[0].y,b[1].y,a[1].y])
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for offset: int in range(0,triangles.size(),3):
		var i: int = triangles[offset]
		var j: int = triangles[offset+1]
		var k: int = triangles[offset+2]
		var u: Vector2 = polygon[j]-polygon[i]
		var v: Vector2 = polygon[k]-polygon[i]
		var q: Vector2 = point-polygon[i]
		var denominator: float = u.cross(v)
		if absf(denominator)<0.00000001: continue
		var wj: float = q.cross(v)/denominator
		var wk: float = u.cross(q)/denominator
		if wj>=-0.00001 and wk>=-0.00001 and wj+wk<=1.00001:
			return heights[i]*(1.0-wj-wk)+heights[j]*wj+heights[k]*wk
	return starts[posmod(index,starts.size())].y

func project(pos: Vector2) -> Vector2:
	var data: Dictionary = project_3d(Vector3(pos.x,0.0,pos.y))
	return Vector2(data.station,data.distance)

func surface_height(pos: Vector2, hint: float = -1.0) -> float:
	return project_3d(Vector3(pos.x,0.0,pos.y),hint).position.y

# Mitered cross-sections keep adjacent road strips joined at the sampled vertex.
# Art and containment use these same offsets instead of unrelated smooth normals.
func edge_offset(index: int) -> Vector3:
	var i: int = posmod(index,starts.size())
	var previous: int = posmod(i-1,starts.size())
	var incoming: Vector2 = Vector2(ends[previous].x-starts[previous].x,ends[previous].z-starts[previous].z).normalized()
	var outgoing: Vector2 = Vector2(ends[i].x-starts[i].x,ends[i].z-starts[i].z).normalized()
	var normal: Vector2 = (incoming.orthogonal()+outgoing.orthogonal()).normalized()
	var offset: Vector2 = normal/maxf(normal.dot(outgoing.orthogonal()),0.5)
	return Vector3(offset.x,0,offset.y)

func road_edges(index: int) -> PackedVector3Array:
	var i: int = posmod(index,starts.size())
	var section: Resource = definition.sections[section_ids[i]]
	var t: float = float(i%24)/24.0
	if section.has_measured_edges():
		return PackedVector3Array([section.sample_vector(section.left_samples,t),section.sample_vector(section.right_samples,t)])
	var offset: Vector3 = edge_offset(i)*section.width*0.5
	return PackedVector3Array([starts[i]-offset,starts[i]+offset])

func road_polygon(index: int) -> PackedVector2Array:
	return corridor_polygons[posmod(index,starts.size())]

func make_road_polygon(index: int) -> PackedVector2Array:
	if not definition.sections[section_ids[posmod(index,starts.size())]].has_measured_edges():
		return legacy_road_polygon(index)
	var a: PackedVector3Array = road_edges(index)
	var b: PackedVector3Array = road_edges(index+1)
	return PackedVector2Array([Vector2(a[0].x,a[0].z),Vector2(b[0].x,b[0].z),Vector2(b[1].x,b[1].z),Vector2(a[1].x,a[1].z)])

func legacy_road_polygon(index: int) -> PackedVector2Array:
	var i: int = posmod(index,starts.size())
	var width: float = definition.sections[section_ids[i]].width*0.5
	var na: Vector3 = edge_offset(i)*width
	var nb: Vector3 = edge_offset(i+1)*width
	var polygon: PackedVector2Array = []
	for p: Vector3 in [starts[i]-na,ends[i]-nb,ends[i]+nb,starts[i]+na]:
		polygon.append(Vector2(p.x,p.z))
	return polygon

func rebuild_art() -> void:
	preload("res://scripts/tracks/track_builder.gd").rebuild(self)
