extends "res://tests/autopilot/probe_base.gd"
const MODEL: Script = preload("res://scripts/vehicles/developer_tuning.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const EXPORT: Script = preload("res://scripts/vehicles/developer_export.gd")
var failures: Array[String] = []
func equivalent(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]: return is_equal_approx(float(left),float(right))
	if left is Dictionary and right is Dictionary:
		if left.size()!=right.size(): return false
		for key: Variant in left:
			if not right.has(key) or not equivalent(left[key],right[key]): return false
		return true
	return left==right
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func choose(ui: Node, target_name: String, group_index: int = 0) -> void:
	ui.target.select(ui.TARGETS.find(target_name))
	ui.group.select(group_index)
	ui.rebuild()
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
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	race.race_mode = "quick"
	race.course.select("game_table")
	for frame: int in range(300):
		if not race.course.loading: break
		await settle()
	race.rival_count = 7
	race.difficulty = 2
	race.configure_quick_race()
	race.set_vehicle("buggy")
	race.menu_flow.show_step(0)
	var model: RefCounted = race.developer
	model.storage_path = summer_out_dir+"/baselines.json"
	model.reset_all()
	model.saved_layers = model.layers()
	var profile_before: String = JSON.stringify(race.profile.data)
	var ui: Node = race.developer_menu
	await settle(3)
	ui.launch.grab_focus()
	await press("ui_accept",40)
	await settle(3)
	check(ui.root.visible and race.paused_race,"open_keyboard")
	if not ui.fields.has("top_speed"):
		report("failures",failures)
		report("open_state",{"visible":ui.root.visible,"launch":ui.launch.visible,"phase":race.phase,"profile":race.profile_selected,"profile_menu":race.profile_menu.visible,"stats":race.stats_menu.panel.visible,"setup":race.setup_menu.panel.visible,"controls":race.controls_setup.panel.visible,"loading":race.course.loading,"focus":str(get_viewport().gui_get_focus_owner())})
		report("passed",false)
		finish()
		return
	check(ui.target.item_count==16,"three_shared_five_vehicles_eight_characters")
	ui.fields.top_speed.text = "1.2"
	ui.fields.top_speed.text_submitted.emit("1.2")
	check(is_equal_approx(model.baseline(MODEL.CATALOG.definition("buggy")).top_speed,MODEL.CATALOG.definition("buggy").top_speed*1.2),"shared_vehicle_factor")
	check(is_equal_approx(model.baseline(MODEL.CATALOG.definition("speedboat")).top_speed,MODEL.CATALOG.definition("speedboat").top_speed*1.2),"inactive_vehicle_shared_factor")
	var before: Dictionary = model.layers()
	ui.apply_text("top_speed","nan")
	ui.apply_text("top_speed","999999")
	check(model.layers()==before,"invalid_values_atomic")
	await settle(3)
	save_frame("shared_vehicle")
	choose(ui,"vehicle:buggy")
	ui.apply_value("top_speed",20.0)
	check(model.values("vehicle:buggy","top_speed").overridden,"explicit_vehicle_override")
	check(is_equal_approx(race.player_car.top_speed,20.0*STATS.factor(race.active_stats().speed,0.10,0.06)),"vehicle_baseline_before_upgrades")
	choose(ui,"shared_character")
	ui.apply_value("top_speed",1.1)
	var character: int = model.character_for(race.player_car)
	choose(ui,"character:%d" % character)
	check(is_equal_approx(model.values(ui.TARGETS[ui.target.selected],"top_speed").value,1.1),"character_inherits_shared")
	ui.apply_value("top_speed",1.3)
	check(is_equal_approx(race.player_car.top_speed,20.0*1.3*STATS.factor(race.active_stats().speed,0.10,0.06)),"character_before_driver_upgrades")
	await settle(3)
	save_frame("character_override")
	choose(ui,"overall_ai")
	ui.apply_value("top_speed",0.9)
	check(is_equal_approx(model.baseline(race.player_car.base_tuning,true).top_speed,18.0),"ai_physics_shared")
	check(is_equal_approx(race.player_car.top_speed,20.0*1.3*STATS.factor(race.active_stats().speed,0.10,0.06)),"ai_physics_excludes_human")
	choose(ui,"overall_ai",3)
	ui.apply_value("ai.speed",0.83)
	check(is_equal_approx(race.all_cars[7].ai_driver.overrides.speed,0.83),"overall_ai_all_seven")
	var ai_character: int = model.character_for(race.all_cars[7])
	choose(ui,"character:%d" % ai_character,3)
	ui.apply_value("ai.speed",0.77)
	check(is_equal_approx(race.all_cars[7].ai_driver.overrides.speed,0.77) and is_equal_approx(race.all_cars[1].ai_driver.overrides.speed,0.83),"individual_character_ai")
	var original_portrait: int = race.profile.data.identity.portrait_id
	race.profile.data.identity.portrait_id = ai_character
	race.garage.select(race,race.garage.selected)
	check(model.character_for(race.player_car)==ai_character and not race.player_car.ai,"character_follows_identity")
	check(is_equal_approx(race.all_cars[1].ai_driver.overrides.speed,0.83),"old_slot_does_not_retain_character_ai")
	race.profile.data.identity.portrait_id = original_portrait
	race.garage.select(race,race.garage.selected)
	race.set_vehicle("speedboat")
	check(is_equal_approx(race.player_car.top_speed,MODEL.CATALOG.definition("speedboat").top_speed*1.2*1.3*STATS.factor(race.active_stats().speed,0.10,0.06)),"character_follows_vehicle_change")
	model.inherit_field("character:%d" % character,"top_speed")
	check(is_equal_approx(model.values("character:%d" % character,"top_speed").value,1.1),"inherit_removes_override")
	choose(ui,"vehicle:speedboat",4)
	var height: float = race.player_car.tuning.collision_height
	ui.apply_value("collision_height",height*1.1)
	check(model.values("vehicle:speedboat","collision_height").restart_required and is_equal_approx(race.player_car.tuning.collision_height,height),"geometry_deferred")
	for car: CharacterBody3D in race.all_cars: model.apply_car(car,true)
	check(is_equal_approx(race.player_car.tuning.collision_height,height*1.1),"geometry_reset")
	await settle(3)
	save_frame("vehicle_geometry")
	ui.save_baselines()
	check(FileAccess.file_exists(model.storage_path) and not model.dirty(),"save_baselines")
	var saved: Dictionary = model.layers()
	model.reset_all()
	check(model.load_settings()==OK and model.layers()==saved,"saved_reload")
	var loader: RefCounted = MODEL.new(null,model.storage_path)
	check(loader.layers()==saved,"new_instance_loads_saved_baselines")
	var saved_path: String = model.storage_path
	model.storage_path = summer_out_dir+"/malformed.json"
	var malformed: FileAccess = FileAccess.open(model.storage_path,FileAccess.WRITE)
	malformed.store_string("{broken")
	malformed.close()
	check(model.load_settings()==ERR_INVALID_DATA and model.layers()==saved,"malformed_load_retains_current_layers")
	model.storage_path = summer_out_dir+"/missing-folder/baselines.json"
	check(model.save_settings()!=OK and model.layers()==saved,"failed_save_retains_current_layers")
	model.storage_path = saved_path
	model.set_value("shared_vehicle","recovery_duration",1.2)
	model.set_value("shared_character","recovery_duration",1.1)
	check(is_equal_approx(model.values("player","recovery_duration").value,1.32),"recovery_export_composes_shared_layers")
	model.inherit_field("shared_vehicle","recovery_duration")
	model.inherit_field("shared_character","recovery_duration")
	var invalid: Dictionary = saved.duplicate(true)
	invalid.characters["8"] = {"grip":1.2}
	check(not model.validate_layers(invalid),"reject_unknown_character")
	invalid = saved.duplicate(true)
	invalid.shared_vehicle.grip = INF
	check(not model.validate_layers(invalid),"reject_nonfinite_saved_layer")
	invalid = saved.duplicate(true)
	invalid.overall_ai["unknown"] = 1.0
	check(not model.validate_layers(invalid),"reject_unknown_field")
	check(EXPORT.write(race,summer_out_dir+"/setup.json")==OK,"complete_export")
	var exported: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(summer_out_dir+"/setup.json"))
	check(exported.schema_version==3 and equivalent(exported.baseline_layers,saved) and exported.character_baselines.size()==8 and exported.vehicle_baselines.size()==5 and exported.racers.size()==8,"export_all_layers_and_eight_racers")
	var protected: Dictionary = JSON.parse_string(profile_before)
	for field: String in ["wallet","vehicles","identity"]: check(equivalent(race.profile.data[field],protected[field]),"profile_untouched_"+field)
	ui.close()
	check(not ui.root.visible and not race.paused_race,"close_restores_pause")
	for cycle: int in range(5):
		ui.open()
		await settle()
		await press("ui_cancel",30)
		await settle(3)
		check(not ui.root.visible and not race.paused_race,"repeated_escape_close_%d" % cycle)
		if ui.root.visible: ui.close()
	race.set_vehicle("buggy")
	race.start_race()
	await settle(3)
	await press("ui_accept",50)
	await settle(3)
	if race.phase==6: race.begin_countdown()
	for frame: int in range(420):
		if race.phase==2: break
		await settle_physics()
	check(race.experimental() and race.cars.size()==8,"eight_car_experimental_race")
	var position_before: Vector3 = race.player_car.global_position
	Input.action_press("p1_go")
	await settle_physics(90)
	Input.action_release("p1_go")
	report("drive_state",{"phase":race.phase,"paused":race.paused_race,"distance":race.player_car.global_position.distance_to(position_before),"speed":race.player_car.velocity.length(),"time":race.race_time})
	check(race.player_car.global_position.distance_to(position_before)>0.5,"drive_with_layers")
	race.paused_race = true
	ui.open()
	await settle(3)
	save_frame("paused_race_tuning")
	ui.close()
	check(race.paused_race,"close_keeps_prior_pause")
	for field: String in ["wallet","vehicles","identity"]: check(equivalent(race.profile.data[field],protected[field]),"drive_preserves_"+field)
	report("failures",failures)
	report("passed",failures.is_empty())
	race.session.change_phase(0)
	race.set_physics_process(false)
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false): voice.stop()
	for voice: Node in app.find_children("*","AudioStreamPlayer3D",true,false): voice.stop()
	await settle_physics(20)
	finish()
