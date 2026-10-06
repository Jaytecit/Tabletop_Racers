extends "res://tests/autopilot/probe_base.gd"
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.course.select("game_table")
	race.start_race()
	race.session.change_phase(2)
	race.set_physics_process(false)
	for other: CharacterBody3D in race.all_cars: other.set_physics_process(false)
	var car: CharacterBody3D = race.player_car
	var speeds: Array[float] = []
	var lateral: Array[float] = []
	for mode: int in [1,2]:
		race.stats_test_mode = mode
		race.garage.apply_stats(race)
		car.reset_car(5.0,0.0)
		var anchor: Vector3 = car.position
		Input.action_press("p1_go")
		report("throttle_%d" % mode,car.player_input.read_commands(car).throttle==1.0)
		for frame: int in range(30):
			# Keep both runs on the same measured surface while using real car physics.
			car.position = anchor
			race.session.progress.rebase(car)
			car._physics_process(1.0/60.0)
		speeds.append(Vector2(car.velocity.x,car.velocity.z).length())
		report("stable_%d" % mode,car.position.is_finite() and car.state==0 and not car.airborne)
		Input.action_release("p1_go")
		car.reset_car(5.0,0.0)
		var forward: Vector2 = Vector2.RIGHT.rotated(car.heading)
		var across: Vector2 = forward.orthogonal()
		car.velocity = Vector3(forward.x*5+across.x*2,0,forward.y*5+across.y*2)
		car._physics_process(1.0/60.0)
		lateral.append(absf(Vector2(car.velocity.x,car.velocity.z).dot(across)))
		race.show_menu()
		race.menu_flow.show_step(1)
		race.stats_menu.open()
		await settle(3)
		save_frame("zero_tune" if mode==1 else "full_tune")
		race.stats_menu.close()
		race.start_race()
		race.session.change_phase(2)
		race.set_physics_process(false)
		for other: CharacterBody3D in race.all_cars: other.set_physics_process(false)
	report("half_second_speeds",speeds)
	report("acceleration_difference",speeds[1]>speeds[0]*1.9)
	report("grip_difference",lateral[1]<lateral[0])
	var low: Resource = STATS.compose(car.base_tuning,STATS.starting())
	var high: Resource = STATS.compose(car.base_tuning,STATS.full())
	report("top_speed_gap",is_equal_approx(high.top_speed/low.top_speed,1.55))
	report("boost_duration_gap",is_equal_approx(low.boost_drain/high.boost_drain,1.6/0.65))
	report("recovery_gap",is_equal_approx(high.recovery_speed/low.recovery_speed,1.5/0.7))
	report("controls_preserved",low.braking==high.braking and low.steering_low==high.steering_low and low.steering_high==high.steering_high)
	var passed: bool = true
	for value: Variant in _reports.values():
		if value is bool and not value: passed = false
	report("passed",passed)
	for player: Node in race.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")
