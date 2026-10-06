extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	race.course.select("topspeed_oval")
	await settle_physics(5)
	for car: Node in race.all_cars: car.set_physics_process(false)
	var failures: Array = []
	var checks: int = 0
	var car: CharacterBody3D = race.player_car
	for gate: Dictionary in race.track.gates:
		var edges: Array[Vector3] = preload("res://scripts/tracks/imported_checkpoint_flags.gd").plane_edges(race.track,gate)
		var d: Vector2 = race.track.direction(gate.station)
		var forward: Vector3 = Vector3(d.x,0,d.y)
		for lane: float in [0.03,0.15,0.5,0.85,0.97]:
			var crossing: Vector3 = edges[0].lerp(edges[1],lane)
			car.reset_car(gate.station-0.15,0.0)
			car.position = crossing-forward*0.15
			var support: Dictionary = car.physical_support(car.position)
			if not support.is_empty(): car.position.y = support.position.y
			race.session.progress.reset(race.all_cars,race.track.total_length)
			var expected: int = 8 if gate.index==0 else gate.index
			race.session.progress.records[1].gate = expected
			car.gate = expected
			car.position = crossing+forward*0.15
			support = car.physical_support(car.position)
			if not support.is_empty(): car.position.y = support.position.y
			var p: Dictionary = race.track.project_3d(car.position,gate.station)
			var result: Dictionary = race.session.progress.observe(car,Vector2(p.station,p.distance),0.05,1.0)
			checks += 1
			if not result.has("checkpoint"): failures.append({"gate":gate.index,"lane":lane,"road_y":car.position.y,"centre_y":race.track.at(p.station).position.y,"result":result})
	report("checks",checks)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
