extends Node3D
# Physics support becomes queryable after the environment has entered the space.
var placement_errors: Array[String] = []
var ready_for_inspection: bool = false
var reused_cues: Dictionary = {}

func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var track: Node3D = get_parent().get_parent()
	var placements: Array[Dictionary] = []
	for gate: Dictionary in track.gates:
		# Source START artwork was individually measured and aligned with gate zero.
		if track.definition.id in ["toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","beach_buggies","town_square"] and gate.index==0:
			reused_cues[0] = "Original source START cue; gate station unchanged"
			continue
		var edges: Array[Vector3] = plane_edges(track,gate)
		if edges.size()!=2:
			placement_errors.append("No local boundary intersections for gate %d" % gate.index)
			continue
		var heading: Vector2 = track.direction(gate.station)
		var normal: Vector3 = Vector3(-heading.y,0,heading.x)
		for edge_index: int in range(2):
			var sign_value: float = -1.0 if edge_index==0 else 1.0
			var edge: Vector3 = edges[edge_index]
			var chosen: Dictionary = {}
			for offset: float in [0.45,0.7,1.0]:
				var candidate: Vector3 = edge+normal*sign_value*offset
				var support: Dictionary = support_at(track,candidate)
				if support.is_empty(): continue
				candidate.y = support.position.y
				if clear_at(track,candidate,heading):
					chosen = {"gate":gate,"side":sign_value,"position":candidate,"elevated":false}
					break
			if not chosen.is_empty(): placements.append(chosen)
		# A shoulderless gate gets one same-plane floating cue outside the corridor.
		if placements.is_empty() or placements.back().gate.index!=gate.index:
			var fallback: Dictionary = {}
			for side_index: int in range(2):
				var sign_value: float = -1.0 if side_index==0 else 1.0
				for offset: float in [0.45,0.7,1.0,1.5]:
					for lift: float in [0.0,0.5,1.0,1.5,2.0,3.0]:
						var candidate: Vector3 = edges[side_index]+normal*sign_value*offset+Vector3.UP*lift
						if cue_clear_at(track,candidate,heading):
							fallback = {"gate":gate,"side":sign_value,"position":candidate,"elevated":true}
							break
					if not fallback.is_empty(): break
				if not fallback.is_empty(): break
			if fallback.is_empty():
				placement_errors.append("No clear same-plane cue for gate %d" % gate.index)
			else: placements.append(fallback)
	preload("res://scripts/tracks/track_builder.gd").checkpoint_markers(track,self,placements)
	ready_for_inspection = true

static func plane_edges(track: Node3D, gate: Dictionary) -> Array[Vector3]:
	var heading: Vector2 = track.direction(gate.station)
	var forward: Vector3 = Vector3(heading.x,0,heading.y)
	var normal: Vector3 = Vector3(-heading.y,0,heading.x)
	var result: Array[Vector3] = []
	for sign_value: float in [-1.0,1.0]:
		var best: Vector3 = Vector3.ZERO
		var best_distance: float = INF
		for i: int in range(track.starts.size()):
			var section: Resource = track.definition.sections[track.section_ids[i]]
			if section.layer!=gate.layer: continue
			var distance: float = absf(wrapf(track.lengths[i]-gate.station,-track.total_length*0.5,track.total_length*0.5))
			if distance>12.0: continue
			var a: PackedVector3Array = track.road_edges(i)
			var b: PackedVector3Array = track.road_edges(i+1)
			for side_index: int in range(2):
				var da: float = (a[side_index]-gate.position).dot(forward)
				var db: float = (b[side_index]-gate.position).dot(forward)
				if da*db>0.0 or absf(da-db)<0.000001: continue
				var p: Vector3 = a[side_index].lerp(b[side_index],da/(da-db))
				if (p-gate.position).dot(normal)*sign_value<=0.0: continue
				if distance<best_distance:
					best_distance = distance
					best = p
		if not is_finite(best_distance): return []
		result.append(best)
	return result

static func support_at(track: Node3D, candidate: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(track.to_global(candidate+Vector3.UP*0.5),track.to_global(candidate-Vector3.UP*0.5),1)
	var hit: Dictionary = track.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		hit.position = track.to_local(hit.position)
		if hit.normal.y<0.7: return {}
	return hit

static func clear_at(track: Node3D, candidate: Vector3, heading: Vector2) -> bool:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.85,1.8,0.5)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = 1
	query.transform = track.global_transform*Transform3D(Basis(Vector3.UP,-heading.angle()),candidate+Vector3(heading.x*0.3,0.95,heading.y*0.3))
	return track.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

static func cue_clear_at(track: Node3D, candidate: Vector3, heading: Vector2) -> bool:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.85,1.0,0.5)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = 1
	query.transform = track.global_transform*Transform3D(Basis(Vector3.UP,-heading.angle()),candidate+Vector3(heading.x*0.3,1.3,heading.y*0.3))
	return track.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
