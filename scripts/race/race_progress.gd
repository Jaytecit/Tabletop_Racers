extends RefCounted
# Ordered route crossings; vehicle motion never awards laps.
const GATES: int = 8
const START_STATION: float = 1.0
const SHOULDER_ALLOWANCE: float = 0.75
var length: float = 0.0
var records: Dictionary = {}
var start_station: float = START_STATION
var gate_count: int = GATES

func reset(cars: Array, route_length: float) -> void:
	length = route_length
	start_station = cars[0].track.definition.start_station
	gate_count = cars[0].track.definition.gate_count
	records.clear()
	for car: CharacterBody3D in cars:
		records[car.player] = {"station":fposmod(car.station-start_station,length),"legal_station":car.station,
			"position":car.position,"gate":1,"laps":0,"distance":car.distance,"finish_time":-1.0,"missed_deadline":-1.0,"penalty":0.0}

func observe(car: CharacterBody3D, hit: Vector2, delta: float, clock: float) -> Dictionary:
	var record: Dictionary = records[car.player]
	var previous: float = record.station
	var station: float = fposmod(hit.x-start_station,length)
	var advance: float = wrapf(station-previous,-length*0.5,length*0.5)
	var previous_position: Vector3 = record.position
	var travelled: float = car.position.distance_to(record.position)
	# Rebase rejected samples, never retroactively credit missing crossings.
	record.station = station
	record.position = car.position
	if record.finish_time>=0.0 or car.state!=0:
		return {}
	var allowed: float = car.top_speed*maxf(car.tuning.boost_speed,1.0)*delta+0.30
	var sample: Dictionary = car.track.at(hit.x)
	if car.track.definition.imported_surface:
		# Banked road height is measured at this lane, not at its centreline.
		sample = car.track.project_3d(car.position,hit.x)
	# Wide imported bends can jump between centreline projections while actual
	# movement remains small. Physical displacement still rejects teleporting.
	if delta<=0.0 or not car.position.is_finite() or (not car.track.definition.imported_surface and absf(advance)>minf(2.0,allowed)) or travelled>allowed:
		return {}
	var in_corridor: bool = hit.y<=sample.width*0.5
	if not in_corridor and sample.edge=="shoulder" and hit.y<=sample.width*0.5+SHOULDER_ALLOWANCE and not car.airborne:
		var support: Dictionary = car.physical_support(car.position)
		in_corridor = not support.is_empty() and absf(support.position.y-sample.position.y)<=0.18
	var step: float = length/gate_count
	var boundary: float = (floor(previous/step)+1.0)*step
	var crossed: int = int(round(boundary/step))%gate_count
	var expected: int = int(record.gate)%gate_count
	var crossed_boundary: bool = advance>0.0 and previous+advance>=boundary
	var crossing_fraction: float = (boundary-previous)/maxf(advance,0.000001)
	if car.track.definition.imported_surface:
		# At an oblique measured bend, nearest-centre projection can lag a real
		# checkpoint plane crossing. Use the same plane as its visible flags.
		crossed_boundary = false
		for gate: Dictionary in car.track.gates:
			if gate.layer!=sample.layer: continue
			var direction: Vector2 = car.track.direction(gate.station)
			var forward: Vector3 = Vector3(direction.x,0,direction.y)
			var before_plane: float = (previous_position-gate.position).dot(forward)
			var after_plane: float = (car.position-gate.position).dot(forward)
			if before_plane<0.0 and after_plane>=0.0:
				var fraction: float = -before_plane/(after_plane-before_plane)
				var crossing: Vector3 = previous_position.lerp(car.position,fraction)
				if not gate.has("plane_edges"):
					gate.plane_edges = preload("res://scripts/tracks/imported_checkpoint_flags.gd").plane_edges(car.track,gate)
				var edges: Array[Vector3] = gate.plane_edges
				if edges.size()!=2: continue
				var lateral: Vector3 = Vector3(-direction.y,0,direction.x)
				var left: float = (edges[0]-gate.position).dot(lateral)
				var right: float = (edges[1]-gate.position).dot(lateral)
				var across: float = (crossing-gate.position).dot(lateral)
				var allowance: float = SHOULDER_ALLOWANCE if sample.edge=="shoulder" and not car.airborne else 0.0
				if across<minf(left,right)-allowance or across>maxf(left,right)+allowance: continue
				crossed_boundary = true
				crossed = gate.index
				crossing_fraction = fraction
				break
	if not in_corridor or not car.permits_surface(sample.surface) or car.position.y<sample.position.y-0.18 or (not car.airborne and absf(car.position.y-sample.position.y)>0.18):
		# The car can drive on the floor outside the course. Return it behind
		# a missed gate now, rather than silently discarding the entire lap.
		if not in_corridor and sample.edge=="shoulder" and car.permits_surface(sample.surface) and not car.airborne and absf(car.position.y-sample.position.y)<=0.18 and crossed_boundary and crossed==expected:
			if not car.physical_support(car.position).is_empty(): return {"missed_gate":true}
		return {}
	record.distance = float(record.laps)*length+minf(station,float(record.gate)*length/gate_count)
	car.distance = record.distance
	var result: Dictionary = {}
	if advance>0.0 or (car.track.definition.imported_surface and crossed_boundary):
		if crossed_boundary:
			if crossed==expected:
				record.missed_deadline = -1.0
				record.gate += 1
				result.checkpoint = crossed
				result.crossing_time = maxf(0.0,clock-delta+delta*crossing_fraction)
				if crossed==0:
					record.laps += 1
					record.gate = 1
					result.lap = record.laps
					result.crossing_time = maxf(0.0,clock-delta+delta*crossing_fraction)
			# Re-entry behind an already passed gate may cross it again. Preserve
			# the ordered record; only skipping an unvisited gate invalidates it.
			elif crossed!=0 and expected!=0 and crossed>expected:
				return {"missed_gate":true}
	car.gate = record.gate
	car.laps = record.laps
	car.distance = float(record.laps)*length+minf(station,float(record.gate)*length/gate_count)
	record.distance = car.distance
	if not car.airborne and station<=float(record.gate)*length/gate_count:
		record.legal_station = hit.x
	return result

func rebase(car: CharacterBody3D) -> void:
	var record: Dictionary = records[car.player]
	record.station = fposmod(car.station-start_station,length)
	record.position = car.position

func mark_finished(car: CharacterBody3D, time: float) -> void:
	records[car.player].finish_time = time+records[car.player].penalty
	car.finish_time = records[car.player].finish_time

func ordered_ids() -> Array:
	var ids: Array = records.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var left: Dictionary = records[a]
		var right: Dictionary = records[b]
		if left.finish_time>=0.0 or right.finish_time>=0.0:
			if left.finish_time<0.0: return false
			if right.finish_time<0.0: return true
			if left.finish_time!=right.finish_time: return left.finish_time<right.finish_time
		elif left.distance!=right.distance:
			return left.distance>right.distance
		return a<b
	)
	return ids

func rank_of(id: int) -> int:
	return ordered_ids().find(id)+1
