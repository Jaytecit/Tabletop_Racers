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
	app.get_node("Opening").queue_free()
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
	var ui: Node = race.developer_menu
	await settle(2)
	ui.launch.grab_focus()
	await press("ui_accept",40)
	await settle(2)
	check(ui.root.visible and race.paused_race,"main_entry")
	check(ui.fields.has("grip") and ui.fields.grip is LineEdit,"numeric_controls")
	ui.fields.grip.text = "0.12"
	ui.fields.grip.text_submitted.emit("0.12")
	check(is_equal_approx(race.player_car.tuning.grip,0.12),"direct_entry")
	ui.adjust("grip",0.01)
	ui.adjust("grip",0.1)
	check(is_equal_approx(race.player_car.tuning.grip,0.23),"fine_coarse")
	ui.apply_text("grip","nan")
	check(is_equal_approx(race.player_car.tuning.grip,0.23) and ui.notice.text.contains("finite"),"invalid_entry")
	ui.apply_text("grip","999999")
	check(is_equal_approx(race.player_car.tuning.grip,0.23) and ui.notice.text.contains("Rejected"),"range_entry")
	choose(ui,1,0)
	ui.apply_text("grip","0.5")
	choose(ui,3,0)
	ui.apply_text("grip","0.7")
	choose(ui,1,0)
	check(ui.fields.grip.text=="MIXED" and race.player_car.tuning.grip!=0.5,"mixed_values")
	ui.adjust("grip",0.1)
	check(ui.notice.text.contains("Mixed"),"mixed_adjust_rejected")
	choose(ui,2,3)
	ui.fields["ai.boost"].set_pressed(true)
	ui.apply_value("ai.speed",1.5)
	choose(ui,0,4)
	ui.apply_text("collision_size.x","1.2")
	check(race.developer.values("player","collision_size.x").restart_required,"restart_label")
	choose(ui,0,1)
	ui.apply_text("boost_drain","0")
	await settle(3)
	save_frame("boost_menu")
	choose(ui,1,0)
	await settle(3)
	save_frame("mixed_ai_menu")
	var setup_path: String = summer_out_dir+"/setup.json"
	ui.export_path(setup_path)
	check(ui.notice.text.contains("saved"),"export_feedback")
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(setup_path))
	check(loaded is Dictionary and loaded.schema_version==2 and loaded.experimental,"export_schema")
	check(loaded.racers.size()==4 and loaded.settings.size()==MODEL.descriptors(race.player_car.base_tuning).size(),"export_complete")
	var matching: bool = true
	for index: int in range(race.all_cars.size()):
		var car: CharacterBody3D = race.all_cars[index]
		var row: Dictionary = loaded.racers[index]
		matching = matching and row.effective==EXPORT.plain(EXPORT.tuning(car.tuning)) and row.requested==EXPORT.plain(EXPORT.tuning(race.developer.resolved(car)))
		var descriptors: Array[Dictionary] = MODEL.descriptors(car.base_tuning,car.ai_driver.difficulty)
		matching = matching and row.settings.size()==descriptors.size()
		for descriptor: Dictionary in descriptors:
			var target_id: String = "player" if index==0 else "ai_%d" % index
			matching = matching and row.settings.has(descriptor.field) and row.settings[descriptor.field].value==EXPORT.plain(race.developer.values(target_id,descriptor.field).value)
	check(matching,"export_runtime_parity")
	check(loaded.racers[0].effective.collision_size!=loaded.racers[0].requested.collision_size and loaded.racers[0].settings["collision_size.x"].restart_required,"export_pending_geometry")
	check(not loaded.racers[0].settings["ai.speed"].active and not loaded.racers[0].settings["surface.water.grip"].active,"inactive_setting_flags")
	check(loaded.vehicle_definitions.buggy.source_visual.ends_with("BeachBuggy.glb") and loaded.context.route_revision==race.track.definition.revision,"source_context")
	var good_hash: String = FileAccess.get_sha256(setup_path)
	ui.export_dialog()
	await settle(2)
	check(ui.dialog.visible,"file_dialog")
	ui.dialog.get_cancel_button().grab_focus()
	await press("ui_accept",40)
	await settle(2)
	check(not ui.dialog.visible,"dialog_cancel_closes")
	check(ui.notice.text.contains("cancelled") and FileAccess.get_sha256(setup_path)==good_hash,"cancelled_export")
	ui.export_path(summer_out_dir+"/missing/fail.json")
	check(ui.notice.text.contains("failed") and race.developer.active(),"unwritable_export")
	var old_grip: float = race.player_car.tuning.grip
	race.player_car.tuning.grip = NAN
	check(EXPORT.write(race,setup_path)==ERR_INVALID_DATA and FileAccess.get_sha256(setup_path)==good_hash,"nonfinite_export_keeps_file")
	race.player_car.tuning.grip = old_grip
	check(EXPORT.write(race,setup_path)==OK and not FileAccess.file_exists(setup_path+".tmp"),"atomic_replace")
	ui.confirm_reset()
	await settle(2)
	check(ui.reset_dialog.dialog_text.contains("EVERY vehicle") and ui.reset_dialog.dialog_text.contains("Keep name"),"reset_scope")
	check(ui.reset_dialog.size.x<=800 and ui.reset_dialog.size.y<=600,"reset_dialog_fits")
	save_frame("reset_scope")
	var before: Dictionary = race.profile.data.duplicate(true)
	ui.reset_dialog.get_ok_button().grab_focus()
	await press("ui_accept",40)
	await settle(2)
	check(race.profile.data==before and ui.notice.text.contains("failed"),"readonly_reset_blocked")
	ui.reset_dialog.hide()
	ui.close()
	check(not race.paused_race and get_viewport().gui_get_focus_owner()==ui.launch,"menu_focus_restored")
	race.developer.reset_all()
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	race.toggle_pause()
	await settle(2)
	report("before_pause",{"phase":race.phase,"paused":race.paused_race,"button_visible":ui.pause_launch.visible,"button_focus":ui.pause_launch.focus_mode,"root_visible":ui.root.visible,"guards":[race.profile_selected,race.profile_menu.visible,race.course.loading,race.stats_menu.panel.visible,race.setup_menu.panel.visible,race.controls_setup.panel.visible]})
	ui.pause_launch.grab_focus()
	await press("ui_accept",40)
	report("pause_focus",get_viewport().gui_get_focus_owner().name if get_viewport().gui_get_focus_owner()!=null else "none")
	await settle(2)
	report("after_pause",{"phase":race.phase,"paused":race.paused_race,"button_visible":ui.pause_launch.visible,"root_visible":ui.root.visible})
	save_frame("pause_entry")
	check(ui.root.visible and race.paused_race,"pause_entry")
	var escape: InputEventKey = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("ui_cancel",escape)
	InputMap.action_add_event("pause_race",escape)
	await key(KEY_ESCAPE,40)
	await settle(2)
	check(not ui.root.visible,"escape_closes_overlay")
	check(race.paused_race and get_viewport().gui_get_focus_owner()==ui.pause_launch,"pause_preserved")
	race.toggle_pause()
	await settle_physics(5)
	check(not race.paused_race,"resume_after_overlay")
	# Export inactive participants rather than silently dropping their settings.
	race.rival_count = 0
	race.configure_quick_race()
	loaded = EXPORT.plain(EXPORT.snapshot(race))
	check(loaded.racers.size()==4 and not loaded.racers[1].active and not loaded.racers[1].settings.grip.active,"inactive_export")
	# Reward tests write only a disposable profile in the probe's evidence directory.
	var store: RefCounted = STORE.new()
	store.path = summer_out_dir+"/reward-profile.json"
	store.data.identity = {"name":"Test Driver","portrait_id":3}
	store.data.setup.music = 0.3
	store.data.quick_race.laps = 5
	store.data.cup_wins = 2
	store.data.tournament_wins = 2
	store.data.gold_livery = true
	var award_context: Dictionary = {"driver":3,"course":"game_table","vehicle":"buggy","laps":3,"stats":STATS.VERSION+":"+STATS.code(STATS.full()),"signature":"b".repeat(64)}
	preload("res://scripts/race/challenge_rules.gd").award(store.data.challenges,award_context,{"finished":true,"ordered_laps":true,"laps":3,"time":90.0},100.0)
	store.data.cup = preload("res://scripts/race/cup_rules.gd").fresh()
	store.data.tournament = preload("res://scripts/race/tournament_rules.gd").fresh("toybox",3)
	for id: String in store.VEHICLE_IDS:
		store.data.vehicles[id] = {"stats":STATS.full(),"points":12,"bling":400,"owned":["stock","mint"],"paint":"mint"}
	var key: String = STORE.record_key("quick",3,3,1,"game_table","","buggy")
	store.data.records[key] = {"signature":"a".repeat(64),"total":90.0,"best_lap":29.0,"replay":""}
	check(store.save_profile()==OK,"seed_reward_profile")
	var original: Dictionary = store.data.duplicate(true)
	var stale: RefCounted = STORE.new()
	stale.path = store.path
	stale.load_profile()
	check(store.clear_earned_and_spent_rewards()==OK,"clear_persisted")
	var token: String = store.data.reward_reset_token
	var reloaded: RefCounted = STORE.new()
	reloaded.path = store.path
	reloaded.load_profile()
	check(reloaded.data==store.data and token.length()==32,"reset_reload")
	check(reloaded.data.identity==original.identity and reloaded.data.setup==original.setup and reloaded.data.quick_race==original.quick_race and reloaded.data.records==original.records,"preserve_identity_preferences_records")
	var rewards_clear: bool = reloaded.data.cup_wins==0 and reloaded.data.tournament_wins==0 and not reloaded.data.gold_livery and reloaded.data.cup.is_empty() and reloaded.data.tournament.is_empty() and reloaded.data.challenges.is_empty()
	for id: String in store.VEHICLE_IDS:
		var build: Dictionary = reloaded.data.vehicles[id]
		rewards_clear = rewards_clear and build.stats==STATS.portrait_starting(3) and STATS.spent(build.stats)==10 and build.points==0 and build.bling==0 and build.paint=="stock" and build.owned==["stock"]
	check(rewards_clear,"all_rewards_reset")
	var backup: Dictionary = store.read_raw(store.path+".rewards-before-reset-"+token+".json")
	check(STORE.validate(backup)==original,"pre_reset_backup")
	check(stale.save_profile()==OK and stale.data.vehicles==store.data.vehicles and stale.data.reward_reset_token==token,"stale_session_guard")
	check(store.clear_earned_and_spent_rewards()==OK and store.data.vehicles==reloaded.data.vehicles and store.data.reward_reset_token!=token,"idempotent_fresh_token")
	store.read_only = true
	var readonly_hash: String = FileAccess.get_sha256(store.path)
	check(store.clear_earned_and_spent_rewards()==ERR_UNAVAILABLE and FileAccess.get_sha256(store.path)==readonly_hash,"readonly_persistence_guard")
	var original_profile: RefCounted = race.profile
	store.read_only = false
	race.profile = store
	ui.clear_rewards()
	check(ui.notice.text.contains("rewards cleared") and race.player_car.tuning.grip==STATS.compose(race.player_car.base_tuning,STATS.portrait_starting(3)).grip,"ui_reset_success")
	race.profile = original_profile
	race.show_menu()
	race.menu_flow.show_step(0)
	await settle(3)
	save_frame("main_menu_entry")
	ui.open()
	choose(ui,0,2)
	await settle(3)
	save_frame("surfaces_scroll")
	ui.fields["surface.water.drag"].grab_focus()
	await settle(3)
	check(ui.rows.get_parent().scroll_vertical>0,"scroll_follows_keyboard_focus")
	await press("ui_down",30)
	await settle(2)
	check(get_viewport().gui_get_focus_owner()!=null and ui.root.is_ancestor_of(get_viewport().gui_get_focus_owner()),"keyboard_navigation_isolated")
	ui.close()
	race.developer.reset_all()
	var catalog: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
	ui.open()
	check(ui.root.visible,"baseline_overlay_open")
	for index: int in range(catalog.IDS.size()):
		var id: String = catalog.IDS[index]
		var base: Resource = catalog.definition(id)
		var stock_speed: float = base.top_speed
		choose(ui,5+index,0)
		check(ui.fields.has("top_speed"),"baseline_menu_"+id)
		ui.apply_text("top_speed",str(stock_speed*1.5))
		check(is_equal_approx(race.developer.values("vehicle:"+id,"top_speed").value,stock_speed*1.5),"baseline_value_"+id)
		check(is_equal_approx(base.top_speed,stock_speed),"immutable_source_"+id)
		check(not race.developer.set_value("vehicle:"+id,"ai.look",1.0),"baseline_no_ai_behaviour_"+id)
	check(EXPORT.snapshot(race).vehicle_baselines.size()==5,"export_all_baselines")
	race.set_vehicle("speedboat")
	var expected: Resource = STATS.compose(race.developer.baseline(race.player_car.base_tuning),race.active_stats())
	check(is_equal_approx(race.player_car.top_speed,expected.top_speed),"baseline_before_player_upgrades")
	check(is_equal_approx(race.all_cars[1].top_speed,catalog.definition("speedboat").top_speed*1.5),"baseline_shared_ai")
	race.developer.set_value("player","top_speed",10.0)
	race.developer.set_value("vehicle:speedboat","top_speed",20.0)
	check(is_equal_approx(race.player_car.top_speed,10.0) and is_equal_approx(race.all_cars[1].top_speed,20.0),"racer_override_priority")
	race.developer.reset_target("player")
	check(is_equal_approx(race.player_car.top_speed,STATS.compose(race.developer.baseline(race.player_car.base_tuning),race.active_stats()).top_speed),"racer_reset_retains_baseline")
	choose(ui,9,4)
	var height: float = race.player_car.tuning.collision_height
	ui.apply_value("collision_height",height*1.2)
	check(race.developer.values("vehicle:speedboat","collision_height").restart_required and race.player_car.tuning.collision_height==height,"baseline_geometry_pending")
	for car: CharacterBody3D in race.all_cars: race.developer.apply_car(car,true)
	check(is_equal_approx(race.player_car.tuning.collision_height,height*1.2),"baseline_geometry_reset")
	await settle(3)
	save_frame("vehicle_baseline_details")
	race.set_vehicle("buggy")
	check(is_equal_approx(race.all_cars[1].top_speed,catalog.definition("buggy").top_speed*1.5),"baseline_class_switch")
	race.developer.reset_target("vehicle:buggy")
	check(not race.developer.baselines.has("buggy") and race.developer.baselines.has("speedboat"),"baseline_reset_independent")
	race.developer.reset_all()
	check(not race.developer.active(),"baseline_reset_all")
	ui.close()
	report("failures",failures)
	report("passed",failures.is_empty())
	race.session.change_phase(0)
	race.set_physics_process(false)
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false): voice.stop()
	for voice: Node in app.find_children("*","AudioStreamPlayer3D",true,false): voice.stop()
	await settle_physics(20)
	finish()
