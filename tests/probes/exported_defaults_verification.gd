extends "res://tests/autopilot/probe_base.gd"
const CATALOG: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.machine_settings.read_only = true
	race.profile_directory.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_selected = true
	race.profile_menu.hide()
	race.show_menu()
	race.race_mode = "freestyle"
	var exported: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tabletop-setup.json"))
	for id: String in CATALOG.IDS:
		var base: Resource = CATALOG.definition(id)
		for field: String in exported.vehicle_baselines[id].properties:
			var expected: Variant = exported.vehicle_baselines[id].properties[field]
			var actual: Variant = base.get(field)
			if expected is float or expected is int: check(is_equal_approx(float(actual),float(expected)),id+"_"+field)
			elif expected is Array: check(actual.is_equal_approx(Vector3(expected[0],expected[1],expected[2])),id+"_"+field)
			else: check(actual==expected,id+"_"+field)
		race.set_vehicle(id)
		for car: CharacterBody3D in race.all_cars: race.developer.apply_car(car,true)
		check(is_equal_approx(race.player_car.top_speed,STATS.compose(base,race.active_stats()).top_speed),id+"_earned_composition")
		check(is_equal_approx(race.all_cars[1].top_speed,15.41 if id=="buggy" else base.top_speed),id+"_ai_default")
		check(not race.experimental(),id+"_ranked_defaults")
	race.set_vehicle("buggy")
	check(race.developer.set_value("vehicle:buggy","top_speed",20.0),"baseline_edit")
	check(is_equal_approx(race.all_cars[1].top_speed,20.0),"baseline_overrides_ai_default")
	race.developer.reset_all()
	check(is_equal_approx(race.all_cars[1].top_speed,15.41),"reset_restores_ai_default")
	var controls: Node = race.controls_setup
	controls.config_path = summer_out_dir+"/controls.cfg"
	controls.config.clear()
	controls.config.set_value("camera","mode",2)
	controls.apply_camera_preferences()
	check(race.camera_driver.mode==0,"legacy_camera_adopts_high_chase")
	controls.restore_defaults()
	check(race.camera_driver.mode==0,"reset_camera_default")
	race.camera_driver.mode = 1
	controls.save_camera_mode()
	controls.config.clear()
	controls.config.load(controls.config_path)
	controls.apply_camera_preferences()
	check(race.camera_driver.mode==1,"later_camera_choice_preserved")
	race.camera_driver.mode = 0
	race.start_race()
	race.begin_countdown()
	race.paused_race = true
	race.setup_grid()
	race.camera_driver.reset(race.camera,race.player_car)
	check(race.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and race.camera.position.is_equal_approx(race.player_car.position+Vector3(3.5,15,10)),"high_isometric_position")
	race.menu.hide()
	await settle(3)
	save_frame("default_high_chase")
	report("failures",failures)
	report("passed",failures.is_empty())
	race.session.change_phase(0)
	race.set_physics_process(false)
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false): voice.stop()
	for voice: Node in app.find_children("*","AudioStreamPlayer3D",true,false): voice.stop()
	await settle_physics(20)
	finish()
