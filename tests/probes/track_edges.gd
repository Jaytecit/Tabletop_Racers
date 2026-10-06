extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(name: String, value: bool) -> void:
	report(name,value)
	if not value: failures.append(name)
func _ready() -> void:
	await super._ready()
	await settle(2)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	var track: Node3D = race.track
	check("valid_route",track.validation_errors.is_empty())
	report("route_length",track.total_length)
	check("longer_than_original",track.total_length>73.184*3.5)
	var folded: int = 0
	var rejected_inside: int = 0
	var accepted_outside: int = 0
	for i: int in range(track.starts.size()):
		var a: Vector3 = track.starts[i]
		var b: Vector3 = track.ends[i]
		var forward: Vector2 = Vector2(b.x-a.x,b.z-a.z).normalized()
		var w: float = track.definition.sections[track.section_ids[i]].width*0.5
		for side: float in [-1.0,1.0]:
			var pa: Vector3 = a+track.edge_offset(i)*w*side
			var pb: Vector3 = b+track.edge_offset(i+1)*w*side
			if Vector2(pb.x-pa.x,pb.z-pa.z).dot(forward)<=0.0: folded += 1
			for fraction: float in [0.0,0.5,0.99]:
				var centre: Vector3 = a.lerp(b,fraction)
				var normal: Vector3 = track.edge_offset(i).lerp(track.edge_offset(i+1),fraction)
				var station: float = lerpf(track.lengths[i],track.lengths[i+1],fraction)
				if not track.project_3d(centre+normal*(w-0.02)*side,station).supported: rejected_inside += 1
				if track.project_3d(centre+normal*(w+0.08)*side,station).supported: accepted_outside += 1
	check("no_folded_edges",folded==0)
	check("paint_inside_supported",rejected_inside==0)
	check("paint_outside_rejected",accepted_outside==0)
	report("edge_counts",{"folds":folded,"inside_rejected":rejected_inside,"outside_accepted":accepted_outside})
	# Follow the inner edge through every gate using the actual projection.
	for lane: float in [-2.95,2.95]:
		race.start_race()
		race.session.change_phase(2)
		var car: CharacterBody3D = race.player_car
		var previous: float = track.definition.start_station
		car.reset_car(previous,lane)
		race.session.progress.reset(race.cars,track.total_length)
		for step: int in range(int(ceil(track.total_length/0.15))+2):
			var s: float = track.definition.start_station+float(step+1)*0.15
			var index: int = track.segment(s)
			var t: float = (fposmod(s,track.total_length)-track.lengths[index])/(track.lengths[index+1]-track.lengths[index])
			car.position = track.sample_3d(s)+track.edge_offset(index).lerp(track.edge_offset(index+1),t)*lane
			var hit: Dictionary = track.project_3d(car.position,previous)
			car.station = hit.station
			race.session.observe(car,Vector2(hit.station,hit.distance),0.1)
			previous = hit.station
		check("edge_lap_"+str(lane),car.laps==1)
	race.show_menu()
	race.menu.visible = false
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = 125.0
	race.camera.position = Vector3(0,95,38)
	race.camera.look_at(Vector3.ZERO)
	await settle(3)
	save_frame("overview")
	race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var s: float = track.lengths[10*24]+3.0
	race.player_car.reset_car(s,0.0)
	race.camera_driver.reset(race.camera,race.player_car)
	await settle(3)
	save_frame("corner")
	report("passed",failures.is_empty())
	report("failures",failures)
	finish()
