extends "res://tests/autopilot/probe_base.gd"

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	# Remove hardware bindings; selection below uses the real card signal.
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.profile.data.gold_livery = false
	var checks: Array[bool] = []
	for selected: int in [1,2,3,0,3,1,0]:
		race.garage.cards[selected].pressed.emit()
		await settle(2)
		var unique: Array[Color] = []
		var correct: bool = true
		for slot: int in range(4):
			var expected: int = selected if slot==0 else (0 if slot==selected else slot)
			var body: Color = race.all_cars[slot].visual.get_node("Body").material_override.albedo_color
			var cabin: Color = race.all_cars[slot].visual.get_node("Cabin").material_override.albedo_color
			correct = correct and body.is_equal_approx(race.garage.COLORS[expected]) and cabin.is_equal_approx(body) and not unique.has(body)
			unique.append(body)
		checks.append(correct)
		report("selection_%d_%d" % [checks.size(),selected],correct)
	race.garage.cards[1].pressed.emit()
	race.track_id = "game_table"
	race.race_mode = "quick"
	race.rival_count = 3
	race.start_race()
	race.begin_countdown()
	await settle(3)
	save_frame("grid_blue_player")
	race.camera_driver.mode = 2
	race.setup_grid()
	var offset: Vector3 = race.camera.position-race.camera_driver.focus-race.camera_driver.lead
	report("close_back_lower",is_equal_approx(Vector2(offset.x,offset.z).length(),8.5) and is_equal_approx(offset.y,4.5))
	save_frame("close_grid")
	while race.phase==1: await get_tree().physics_frame
	await press("p1_go",1500)
	await settle(5)
	save_frame("close_driving")
	report("camera_finite",race.camera.transform.is_finite())
	report("player_drove",race.player_car.velocity.length()>0.1)
	race.start_race()
	race.begin_countdown()
	await settle(3)
	report("retry_livery",race.all_cars[1].visual.get_node("Body").material_override.albedo_color.is_equal_approx(race.garage.COLORS[0]))
	report("passed",not checks.has(false) and _reports.close_back_lower and _reports.camera_finite and _reports.player_drove and _reports.retry_livery)
	finish()
