extends "res://tests/autopilot/probe_base.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const EXPORT: Script = preload("res://scripts/vehicles/developer_export.gd")
const MODEL: Script = preload("res://scripts/vehicles/developer_tuning.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func choose(menu: Node, target_index: int, group_index: int) -> void:
	menu.target.select(target_index)
	menu.group.select(group_index)
	menu.rebuild()
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
	var opening: Node = app.get_node("Opening/Sequence")
	opening.hardware_input_isolated = true
	opening._restore_menu()
	opening.get_parent().queue_free()
	get_tree().paused = false
	race.profile_selected = true
	race.profile_menu.hide()
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	race.race_mode = "quick"
	race.course.select("game_table")
	for wait_frame: int in range(300):
		if not race.course.loading: break
		await get_tree().process_frame
	race.rival_count = 3
	race.configure_quick_race()
	race.set_vehicle("buggy")
	race.menu_flow.show_step(0)
	await settle(3) # Flush deferred menu focus before the modal disables it.
	var ui: Node = race.developer_menu
	ui.open()
	choose(ui,0,5)
	check(ui.fields.has("tyre_effect_threshold"),"effects_menu_field")
	ui.apply_text("tyre_effect_threshold","3")
	check(is_equal_approx(race.player_car.tuning.tyre_effect_threshold,3.0),"live_menu_apply")
	ui.apply_text("tyre_effect_threshold","0")
	check(is_equal_approx(race.player_car.tuning.tyre_effect_threshold,3.0),"invalid_threshold_rejected")
	await settle(3)
	save_frame("tyre_effects_menu")
	ui.close()
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	race.session.change_phase(2)
	race.paused_race = false
	var car: CharacterBody3D = race.player_car
	var observations: Array = []
	for threshold: float in [1.0,3.0,1.0]:
		check(race.developer.set_value("player","tyre_effect_threshold",threshold),"threshold_apply")
		car.reset_car(10.0,0.0)
		var forward: Vector2 = Vector2.RIGHT.rotated(car.heading)
		var lateral: Vector2 = forward.orthogonal()
		car.velocity = Vector3(forward.x*5.0+lateral.x*3.0,0,forward.y*5.0+lateral.y*3.0)
		car._physics_process(1.0/60.0)
		race._physics_process(1.0/60.0)
		var expected: bool = threshold==1.0
		check(car.smoke.emitting==expected,"smoke_threshold_%s" % threshold)
		check(race.skid_sound.playing==expected,"squeal_threshold_%s" % threshold)
		observations.append({"threshold":threshold,"smoke":car.smoke.emitting,"squeal":race.skid_sound.playing})
	check(race.developer.set_value("all_ai","tyre_effect_threshold",4.0),"ai_threshold_apply")
	for ai: CharacterBody3D in race.all_cars.slice(1): check(ai.tuning.tyre_effect_threshold==4.0,"ai_value")
	var setup: Dictionary = EXPORT.snapshot(race)
	check(setup.racers[0].effective.tyre_effect_threshold==1.0,"export_threshold")
	race.developer.reset_all()
	check(car.tuning.tyre_effect_threshold==car.base_tuning.tyre_effect_threshold,"reset_threshold")
	report("observations",observations)
	report("failures",failures)
	report("passed",failures.is_empty())
	race.session.change_phase(0)
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
		voice.stream = null
	await settle_physics(3)
	finish()
