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
	var controls: Node = race.controls_setup
	controls.config_path = summer_out_dir+"/controls.cfg"
	controls.config.clear()
	controls.restore_defaults()
	report("camera_binding",InputMap.action_get_events("cycle_camera")[0].keycode==KEY_C and race.controller.camera_button==JOY_BUTTON_RIGHT_STICK)
	controls.open()
	await settle(3)
	save_frame("controls")
	report("controls_fit",controls.panel.get_rect().end.y<=race.menu.size.y)
	controls.close_setup()
	# Keep hardware input out of this isolated test; synthetic actions still work.
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.start_race()
	race.begin_countdown()
	race.player_car.ai = true
	for i: int in range(250): await get_tree().physics_frame
	var observed: Array = []
	for i: int in range(3):
		await settle(3)
		save_frame("mode_%d" % race.camera_driver.mode)
		observed.append({"mode":race.camera_driver.mode,"size":race.camera.size,"position":str(race.camera.position),"finite":race.camera.transform.is_finite()})
		Input.action_press("cycle_camera")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("cycle_camera")
		await get_tree().physics_frame
	report("modes",observed)
	report("cycle_wraps",race.camera_driver.mode==0)
	race.camera_driver.mode = 2
	race.setup_grid()
	race.player_car.heading += PI*0.5
	race.camera_driver.tick(race.camera,race.player_car,1.0)
	report("close_follows_heading",race.camera.position.distance_to(race.camera_driver.focus+race.camera_driver.lead+Vector3(-cos(race.player_car.heading)*8.5,4.5,-sin(race.player_car.heading)*8.5))<0.02)
	controls.save_camera_mode()
	var saved: ConfigFile = ConfigFile.new()
	saved.load(controls.config_path)
	report("persisted_mode",saved.get_value("camera","mode",-1)==2)
	controls.pad_choices.camera.select(1)
	controls.pad_choices.camera.item_selected.emit(1)
	report("gamepad_binding",race.controller.camera_button==JOY_BUTTON_LEFT_STICK)
	race.toggle_pause()
	race.cycle_camera()
	report("paused_mode_stable",race.camera_driver.mode==2)
	race.toggle_pause()
	race.start_race()
	race.begin_countdown()
	report("retry_retains_mode",race.camera_driver.mode==2 and is_equal_approx(race.camera.size,10.5))
	report("passed",_reports.camera_binding and _reports.controls_fit and _reports.cycle_wraps and _reports.close_follows_heading and _reports.persisted_mode and _reports.gamepad_binding and _reports.paused_mode_stable and _reports.retry_retains_mode)
	finish()
