extends "res://tests/probes/race_quality_ai_verification.gd"
const PROTOTYPE: Script = preload("res://scripts/vehicles/buggy_wheel_prototype.gd")
const COLOURS: Array[Color] = [Color("ef6546"),Color("4ba5c9"),Color("f1c44f"),Color("86bb5b")]

func _ready() -> void:
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	check(race.profile.read_only,"read_only")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.menu_flow.choose_mode("freestyle")
	check(race.course.select("game_table"),"course")
	while race.course.loading: await get_tree().process_frame
	race.rival_count = 3
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.81
	await settle_physics(3)
	for i: int in range(4):
		var car: CharacterBody3D = race.all_cars[i]
		var replacement: Node3D = PROTOTYPE.build(COLOURS[i])
		car.visual.free()
		car.visual = replacement
		car.add_child(car.visual)
		car.wheels = car.visual.get_node("Wheels").get_children()
		car.visual_motion = preload("res://scripts/vehicles/buggy_prototype_motion.gd").new()
		car.visual_motion.configure(car)
		car.visual.get_node("DriverNumber").text = "%02d" % (i+1)
		check(car.wheels.size()==4,"four_wheels_%d"%i)
		car.set_physics_process(false)
		race.camera_driver.mode = 0
	var car: CharacterBody3D = race.player_car
	car.reset_car(20,0)
	car.ai = false
	car.set_physics_process(true)
	race.session.progress.reset(race.cars,race.track.total_length)
	var origin: Vector3 = car.position
	Input.action_press("p1_go")
	await settle_physics(40)
	Input.action_release("p1_go")
	check(car.position.distance_to(origin)>0.5 and car.crashes==0,"forward")
	check(absf(car.visual_motion.roll_angle)>0.1,"wheels_spin")
	report("forward_roll",car.visual_motion.roll_angle)
	Input.action_press("p1_brake")
	await settle_physics(100)
	Input.action_release("p1_brake")
	check(car.velocity.dot(Vector3(cos(car.heading),0,sin(car.heading)))<0,"reverse")
	var reverse_before: float = car.visual_motion.roll_angle
	await settle_physics(3)
	check(wrapf(car.visual_motion.roll_angle-reverse_before,-PI,PI)>0.001,"reverse_wheel_direction")
	car.velocity = Vector3.ZERO
	Input.action_press("p1_left")
	await settle_physics(5)
	Input.action_release("p1_left")
	var front: Array[float] = []
	for mount: Node3D in car.wheels:
		if mount.position.x>0:
			front.append(mount.rotation.y)
			check(absf(mount.rotation.y)>0.1,"steers_"+str(mount.name))
		else: check(absf(mount.rotation.y)<0.001,"rear_fixed_"+str(mount.name))
	report("front_steering",front)
	car.set_physics_process(false)
	race.set_physics_process(false)
	race.get_node("HUD").hide()
	race.get_node("Retro").hide()
	var base: Vector3 = car.position
	for i: int in range(4):
		var vehicle: CharacterBody3D = race.all_cars[i]
		vehicle.position = base+Vector3(0,0,(i-1.5)*1.1)
		vehicle.rotation = Vector3.ZERO
		vehicle.visual.rotation = Vector3.ZERO
		vehicle.visual_motion.reset()
	race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	race.camera.global_position = base+Vector3(3.5,2.8,3.8)
	race.camera.look_at(base+Vector3.UP*0.25)
	await settle(4)
	save_frame("four_player_colours")
	# Capture one complete revolution on the isolated proof, with the front wheels steered.
	for frame: int in range(24):
		for mount: Node3D in car.wheels:
			mount.get_node("Roll").rotation.z = -float(frame)*TAU/24.0
			mount.rotation.y = 0.45 if mount.position.x>0 else 0.0
		race.camera.global_position = car.global_position+Vector3(1.1,0.65,1.05)
		race.camera.look_at(car.global_position+Vector3.UP*0.2)
		await settle(1)
		save_frame("spin_%02d"%frame)
	for pose: int in range(3):
		for mount: Node3D in car.wheels:
			mount.get_node("Roll").rotation.z = pose*PI/3.0
			mount.rotation.y = 0.45 if mount.position.x>0 else 0.0
		race.camera.global_position = car.global_position+Vector3(1.1,0.65,1.05)
		race.camera.look_at(car.global_position+Vector3.UP*0.2)
		await settle(3)
		save_frame("wheel_pose_%d"%pose)
	check(race.profile.read_only,"still_read_only")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
