extends "res://tests/probes/vehicle_effects_verification.gd"
# The general suite's forced close camera can sit behind Bazaar scenery.
# Review Drift Challenge through its real gameplay camera instead.
func _ready() -> void:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = summer_max_seconds
	timer.timeout.connect(_on_deadline)
	add_child(timer)
	timer.start()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.profile.read_only = true
	race.profile_selected = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.race_mode = "drift"
	check(race.course.select("bazaar"),"drift_selected")
	race.rival_count = 0
	race.machine_settings.data.reduced_effects = false
	race.setup_menu.set_pixels(true)
	await start_at(20.0)
	race.camera_driver.mode = 0
	race.camera_driver.reset(race.camera,race.player_car)
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(24)
	check(race.player_car.effects.boost_trail.emitting and race.player_car.tuning.id=="drift_car","drift_boost")
	await settle(2)
	save_frame("drift_gameplay_boost")
	Input.action_release("boost")
	Input.action_press("p1_right")
	var car: CharacterBody3D = race.player_car
	car.velocity += Vector3(-sin(car.heading),0,cos(car.heading))*5.0
	await settle_physics(6)
	check(car.effects.tyre_active(),"drift_contact_smoke")
	await settle(2)
	save_frame("drift_gameplay_smoke")
	Input.action_release("p1_right")
	Input.action_release("p1_go")
	report("effects",car.effects.diagnostic_state())
	report("failures",failures)
	report("passed",failures.is_empty())
	race.show_menu()
	for audio: AudioStreamPlayer in race.find_children("*","AudioStreamPlayer",true,false): audio.stop()
	await settle(3)
	finish()
