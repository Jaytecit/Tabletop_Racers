extends RefCounted

static func occupied(car: CharacterBody3D, position: Vector3) -> bool:
	for other: CharacterBody3D in car.race.cars:
		if other==car or other.finish_time>=0.0 or other.state!=0: continue
		var separation: float = maxf(1.25,car.tuning.traffic_half_width+other.tuning.traffic_half_width+0.35)
		if absf(other.position.y-position.y)<0.7 and Vector2(other.position.x-position.x,other.position.z-position.z).length()<separation: return true
	return false

static func clear_anchor(car: CharacterBody3D, position: Vector3, heading: float) -> bool:
	if occupied(car,position): return false
	var shape: BoxShape3D = BoxShape3D.new()
	# Lift the bottom clear of the supporting deck; retain the full footprint.
	shape.size = car.tuning.collision_size*Vector3(0.94,0.8,0.94)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [car.get_rid()]
	var surface: Dictionary = car.track.project_3d(position,car.station)
	var forward: Vector3 = Vector3(cos(heading),0,sin(heading))
	var slope: float = clampf(atan2(-surface.normal.dot(forward),surface.normal.y),-0.7,0.7)
	var basis: Basis = Basis(Vector3.UP,-heading)*Basis(Vector3.BACK,slope)
	query.transform = car.race.global_transform*Transform3D(basis,position+basis*Vector3.UP*(car.tuning.collision_height+0.04))
	return car.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

static func select_anchor(car: CharacterBody3D) -> Dictionary:
	var track: Node3D = car.track
	var legal: float = car.race.session.progress.records[car.player].legal_station
	var candidates: Array = track.anchors.duplicate()
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return fposmod(legal-a.station,track.total_length)<fposmod(legal-b.station,track.total_length))
	for anchor: Dictionary in candidates:
		if not car.permits_surface(anchor.surface): continue
		if fposmod(legal-anchor.station,track.total_length)>minf(car.top_speed*maxf(car.tuning.boost_speed,1.0),track.total_length*0.25): continue
		var d: Vector2 = track.direction(anchor.station)
		for lane: float in [0.0,-1.0,1.0]:
			if absf(lane)+maxf(0.6,car.tuning.traffic_half_width+0.15)>anchor.width*0.5: continue
			var p: Vector3 = anchor.position+Vector3(-d.y,0,d.x)*lane
			if clear_anchor(car,p,d.angle()): return {"position":p,"station":anchor.station,"heading":d.angle()}
	return {}
