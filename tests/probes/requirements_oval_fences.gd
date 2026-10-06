extends "res://tests/probes/requirements_oval_repro.gd"
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
	var sweeps: int = 0
	var space: PhysicsDirectSpaceState3D = race.get_world_3d().direct_space_state
	for i: int in range(0,race.track.starts.size(),24):
		var edges: PackedVector3Array = race.track.road_edges(i)
		for side: int in range(2):
			var outward: Vector3 = edges[side]-edges[1-side]
			outward.y = 0.0
			outward = outward.normalized()
			var from: Vector3 = edges[side]-outward*0.6+Vector3.UP*0.12
			var to: Vector3 = edges[side]+outward*5.0+Vector3.UP*0.12
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(race.track.to_global(from),race.track.to_global(to),1)
			var hit: Dictionary = space.intersect_ray(query)
			checks += 1
			if hit.is_empty() or not str(hit.collider.name).contains("fence"):
				failures.append({"span":i,"side":side,"collider":str(hit.collider.name) if not hit.is_empty() else "missing","from":str(from),"to":str(to)})
			else:
				# Both faces must block, including a car swept towards the fence.
				query.from = race.track.to_global(to)
				query.to = race.track.to_global(from)
				var back: Dictionary = space.intersect_ray(query)
				if back.is_empty(): failures.append({"span":i,"side":side,"backface":"missing"})
				race.player_car.position = edges[side]-outward*0.8
				var support: Dictionary = race.player_car.physical_support(race.player_car.position)
				if not support.is_empty(): race.player_car.position.y = support.position.y
				race.player_car.collision_mask = 1
				var motion: Vector3 = outward*1.5+Vector3.UP*(edges[side].y-race.player_car.position.y)
				if race.player_car.test_move(race.player_car.global_transform,race.global_transform.basis*motion): sweeps += 1
				else: failures.append({"span":i,"side":side,"car_sweep":"missed","position":str(race.player_car.position),"shape":str(race.player_car.get_node("Collision").transform),"motion":str(motion)})
	var helper: Node = load("res://tests/probes/topspeed_oval_live.gd").new()
	race.add_child(helper)
	report("support",helper.support_report())
	report("gates",helper.gate_checks())
	report("fence_checks",checks)
	report("car_sweeps",sweeps)
	report("failures",failures)
	report("passed",failures.is_empty() and _reports.support.failures.is_empty() and _reports.gates.failures.is_empty())
	helper.overview()
	await settle(3)
	save_frame("oval_fences")
	finish()
