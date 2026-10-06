extends "res://tests/autopilot/probe_base.gd"
func frames(count: int) -> void:
	for i: int in range(count): await get_tree().physics_frame
func _ready() -> void:
	await super._ready()
	await settle(2)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m3_handling_test.json"
	race.race_mode = "quick"
	race.rival_count = 3
	race.course.select("game_table")
	var car: CharacterBody3D = race.player_car
	race.start_race()
	race.session.change_phase(2)
	for other: CharacterBody3D in race.cars:
		if other!=car:
			other.set_physics_process(false)
			other.position = Vector3(100,0,100)
			other.collision_layer = 0
			other.collision_mask = 0
	Input.action_press("p1_go")
	await frames(30)
	Input.action_release("p1_go")
	var forward: Vector2 = Vector2.RIGHT.rotated(car.heading)
	var speed_before: float = Vector2(car.velocity.x,car.velocity.z).dot(forward)
	Input.action_press("p1_brake")
	await frames(5)
	var speed_after: float = Vector2(car.velocity.x,car.velocity.z).dot(forward)
	report("brake_before_reverse",speed_before>3.0 and speed_after>0.0 and speed_after<speed_before)
	await frames(75)
	var reverse_speed: float = Vector2(car.velocity.x,car.velocity.z).dot(forward)
	report("reverse_capped",reverse_speed< -0.5 and reverse_speed>= -car.tuning.reverse_speed-0.1)
	Input.action_release("p1_brake")
	car.reset_car(1.0,0.0)
	car.boost = 1.0
	Input.action_press("p1_go")
	Input.action_press("boost")
	await frames(1)
	report("empty_boost_rejected",not car.sparks.emitting)
	Input.action_release("boost")
	Input.action_release("p1_go")
	car.reset_car(1.0,0.0)
	forward = Vector2.RIGHT.rotated(car.heading)
	var sideways: Vector2 = forward.orthogonal()*4.0
	car.velocity = Vector3(forward.x*6.0+sideways.x,0,forward.y*6.0+sideways.y)
	Input.action_press("p1_go")
	await frames(3)
	var slide: float = absf(Vector2(car.velocity.x,car.velocity.z).dot(forward.orthogonal()))
	Input.action_release("p1_go")
	await frames(20)
	report("slide_and_release_control",slide>2.0 and absf(Vector2(car.velocity.x,car.velocity.z).dot(forward.orthogonal()))<slide)
	car.set_physics_process(false)
	car.reset_car(1.0,0.0)
	var obstacle: CharacterBody3D = race.cars[1]
	obstacle.reset_car(1.9,0.0)
	obstacle.finish_time = 10.0
	for i: int in range(50): car.ai_driver.read_commands(car)
	report("finished_car_pass",absf(car.ai_driver.lateral_target)>1.0)
	report("pass_debug",{"target":car.ai_driver.lateral_target,"lane":car.lane,"dt":car.get_physics_process_delta_time(),"time":car.ai_driver.decision_time})
	car.ai_driver.reset(car,42)
	obstacle.position.y += 3.0
	for i: int in range(50): car.ai_driver.read_commands(car)
	report("other_layer_ignored",absf(car.ai_driver.lateral_target-car.lane)<0.1)
	obstacle.position = Vector3(100,0,100)
	car.ai_driver.reset(car,42)
	var reset_requested: bool = false
	for i: int in range(240):
		var command: Dictionary = car.ai_driver.read_commands(car)
		if command.reset_requested:
			reset_requested = true
			car.crash(false)
			break
	var accepted: float = race.session.progress.records[1].distance
	# Observe the recovery itself; grounded driving afterwards can legally advance.
	car.set_physics_process(false)
	for i: int in range(160):
		car.recover(1.0/60.0)
		await get_tree().physics_frame
		if car.state==0: break
	report("stuck_legal_recovery",reset_requested and car.state==0 and race.session.progress.records[1].distance<=accepted+0.5)
	report("recovery_debug",{"requested":reset_requested,"state":car.state,"accepted":accepted,"distance":race.session.progress.records[1].distance,"timer":car.ai_driver.stalled_time})
	race.camera_driver.reset(race.camera,car)
	var rotation_before: Vector3 = race.camera.rotation
	car.position.y = 4.0
	race.camera_driver.tick(race.camera,car,1.0/60.0)
	report("camera_elevation_smooth",race.camera_driver.focus.y>0.0 and race.camera_driver.focus.y<1.0 and race.camera.rotation.is_equal_approx(rotation_before))
	car.position.y = 0.0
	race.camera_driver.reset(race.camera,car)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	race.add_child(mesh)
	mesh.global_position = race.camera.global_position.lerp(car.global_position+Vector3(0,0.35,0),0.5)
	race.camera_driver.occluders.append(mesh)
	for i: int in range(30): race.camera_driver.tick(race.camera,car,1.0/60.0)
	report("occluder_fades",mesh.transparency>0.5)
	mesh.position = Vector3(100,0,100)
	for i: int in range(30): race.camera_driver.tick(race.camera,car,1.0/60.0)
	report("occluder_restores",mesh.transparency<0.05)
	mesh.queue_free()
	race.show_menu()
	await settle(2)
	save_frame("menu")
	finish()
