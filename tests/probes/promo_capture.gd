extends "res://tests/probes/race_quality_ai_verification.gd"
# Disposable real-physics footage. No production camera or profile changes.
var filming: bool = false
var angle: int = 0

func _process(delta: float) -> void:
	if not filming or not is_instance_valid(race): return
	var car: CharacterBody3D = race.player_car
	if angle < 2:
		race.camera_driver.mode = 1 if angle == 0 else 2
		race.camera_driver.tick(race.camera,car,delta)
	else:
		var forward: Vector3 = Vector3(cos(car.heading),0,sin(car.heading))
		var side: Vector3 = Vector3(-forward.z,0,forward.x)
		race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		race.camera.fov = 52
		race.camera.position = car.position+side*5.5-forward*2.0+Vector3.UP*3.5
		race.camera.look_at(car.position+forward*1.0+Vector3.UP*0.3)

func _ready() -> void:
	await super_ready()
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.profile.read_only = true
	race.profile_directory.read_only = true
	race.machine_settings.read_only = true
	race.profile_selected = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action_name: StringName in InputMap.get_actions(): InputMap.action_erase_events(action_name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	var course: String = OS.get_environment("PROMO_COURSE")
	check(race.course.select(course),"course")
	race.menu_flow.choose_mode("freestyle")
	race.rival_count = 3
	race.race_laps = 3
	race.difficulty = 2
	race.race_seed = 3106
	for vehicle: String in ["buggy","monster_truck","racing_car"]:
		filming = false
		race.show_menu()
		check(race.set_vehicle(vehicle),vehicle)
		race.start_race()
		race.player_car.ai = true
		race.begin_countdown()
		race.session.countdown = 0.81
		await settle_physics(150)
		race.get_node("HUD").hide()
		var begin: Vector3 = race.player_car.position
		for view: int in range(3):
			angle = view
			race.camera_driver.mode = 1 if view == 0 else 2
			race.camera_driver.reset(race.camera,race.player_car)
			filming = true
			await settle(2)
			for frame: int in range(60):
				await RenderingServer.frame_post_draw
				var image: Image = get_viewport().get_texture().get_image()
				image.save_jpg(summer_out_dir+"/%s_%d_%03d.jpg"%[vehicle,view,frame],0.94)
				await get_tree().process_frame
		report(vehicle+"_motion",{"distance":race.player_car.position.distance_to(begin),"station":race.player_car.station,"phase":race.phase})
	filming = false
	report("course_id",course)
	report("passed",failures.is_empty())
	finish()

func super_ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(5)
