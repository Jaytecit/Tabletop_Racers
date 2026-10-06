extends "res://tests/autopilot/probe_base.gd"
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const STORE: Script = preload("res://scripts/profile_store.gd")

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	var restored: RefCounted = STORE.new()
	restored.path = "res://tests/baselines/development/progression_acceleration/profile.json"
	restored.load_profile()
	restored.read_only = true
	race.profile = restored
	race.show_menu()
	race.garage.select(race,restored.data.quick_race.driver)
	report("process_restart",STATS.code(restored.vehicle().stats)=="-2.00,-1.75,-2.00,-2.00,-2.00" and restored.vehicle().points==3 and restored.vehicle().bling==30 and restored.vehicle().paint=="mint")
	race.menu_flow.show_step(2)
	race.stats_menu.open()
	await settle(3)
	save_frame("restored_upgrades")
	report("restored_tuning",is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*0.825))
	# Synthetic controller events use a device ID reserved for this disposable probe.
	var binding: InputEventJoypadButton = InputEventJoypadButton.new()
	binding.device = 63
	binding.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ui_accept",binding)
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 63
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)
	report("controller_upgrade",race.stats_menu.pending.grip==-1.75 and race.stats_menu.cost()==1)
	race.stats_menu.close()
	report("cancel_restores_focus",not race.stats_menu.panel.visible and race.menu.get_node("FlowNext").focus_mode==Control.FOCUS_ALL and restored.vehicle().points==3)
	race.start_race()
	race.begin_countdown()
	race.toggle_pause()
	report("pause_retains_stats",is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*0.825))
	race.toggle_pause()
	race.start_race()
	report("retry_retains_stats",is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*0.825) and restored.vehicle().points==3 and not race.rewards_awarded)
	var passed: bool = true
	for value: Variant in _reports.values():
		if value is bool and not value: passed = false
	report("passed",passed)
	race.set_physics_process(false)
	for player: Node in race.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")

