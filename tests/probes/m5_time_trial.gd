extends "res://tests/autopilot/probe_base.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const TEST_PATH: String = "user://m5_trial_test.json"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)
func clear_test() -> void:
	var directory: DirAccess = DirAccess.open(TEST_PATH.get_base_dir())
	for file: String in directory.get_files():
		if file.begins_with(TEST_PATH.get_file()): directory.remove(file)
func reconstruct() -> Node:
	var old: Node = get_tree().current_scene
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.get_node("Race").profile.path = TEST_PATH
	get_tree().current_scene = null
	old.queue_free()
	get_tree().root.add_child.call_deferred(app)
	await get_tree().process_frame
	get_tree().current_scene = app
	await settle(3)
	return app.get_node("Race")
func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(3)
	clear_test()
	var race: Node = await reconstruct()
	var mode: OptionButton = race.menu.get_node("Mode")
	mode.grab_focus()
	await key(KEY_ENTER,50)
	await key(KEY_DOWN,50)
	await key(KEY_ENTER,50)
	check("keyboard_selects_trial",race.race_mode=="trial" and not mode.get_popup().visible)
	race.race_laps = 1
	race.rival_count = 3
	race.difficulty = 2
	race.save_preferences()
	race.show_menu()
	check("trial_solo_retains_preferences",race.cars.size()==1 and race.rival_count==3 and race.menu.get_node("QuickRace/Rivals").disabled)
	race.player_car.ai = true
	race.focus_start()
	await press("start_race")
	check("countdown_no_ghost",race.phase==1 and not race.trial.ghost.visible)
	race.toggle_pause()
	var count: int = race.trial.recording.size()
	var clock: float = race.race_time
	await settle_physics(8)
	check("pause_freezes_recording",race.paused_race and race.race_time==clock and race.trial.recording.size()==count)
	race.toggle_pause()
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	for frame: int in range(12000):
		await get_tree().process_frame
		if race.phase==3: break
	check("legal_trial_finish",race.phase==3 and race.player_car.laps==1 and race.session.results.size()==1)
	var key_id: String = race.trial.key
	var record: Dictionary = race.profile.data.records.get(key_id,{})
	check("record_written",not record.is_empty() and record.total==race.player_car.finish_time and record.best_lap>0.0 and record.best_lap<=record.total)
	check("ghost_written",not record.is_empty() and record.replay!="" and FileAccess.file_exists(race.trial.replay_path(record.replay)))
	check("results_pb",race.banner.text.contains("NEW PERSONAL BEST"))
	report("record",record)
	await settle(2)
	save_frame("01_trial_results")
	Engine.time_scale = 1.0
	race = await reconstruct()
	report("restart_state",{"mode":race.race_mode,"record":race.profile.data.records.get(key_id,{}),"rivals":race.rival_count,"difficulty":race.difficulty})
	await settle(2)
	save_frame("03_trial_menu")
	check("restart_mode_and_record",race.race_mode=="trial" and race.profile.data.records[key_id].signature==record.signature and race.profile.data.records[key_id].replay==record.replay and absf(race.profile.data.records[key_id].total-record.total)<0.000001 and race.rival_count==3 and race.difficulty==2)
	race.player_car.ai = true
	race.start_race()
	check("replay_loaded",race.trial.playback.size()>2)
	race.session.change_phase(2)
	race.session.race_time = 1.0
	race.trial.observe()
	check("ghost_visible",race.trial.ghost.visible)
	check("ghost_has_no_physics",race.trial.ghost.find_children("*","CollisionObject3D",true,false).is_empty() and race.cars.size()==1 and race.session.progress.records.size()==1)
	var at: Vector3 = race.trial.ghost.position
	race.toggle_pause()
	await settle_physics(8)
	check("pause_freezes_ghost",race.trial.ghost.position==at and race.race_time==1.0)
	race.toggle_pause()
	await settle(2)
	save_frame("02_ghost")

	# Ghost clock continues while the human car is in crash/recovery.
	race.player_car.crash(false)
	var cursor_before: int = race.trial.cursor
	var samples_before: int = race.trial.recording.size()
	await settle_physics(30)
	check("recovery_does_not_freeze_ghost",race.trial.cursor>cursor_before and race.trial.recording.size()>samples_before)
	race.start_race()
	check("retry_clears_run",not race.trial.playback.is_empty() and race.trial.recording.size()==1 and race.trial.cursor==0 and not race.trial.ghost.visible and race.player_car.laps==0)
	race.show_menu()
	check("menu_hides_ghost",not race.trial.ghost.visible)
	race.race_mode = "quick"
	race.show_menu()
	check("quick_restores_grid",race.cars.size()==4 and not race.menu.get_node("QuickRace/Rivals").disabled)
	check("record_partition",STORE.record_key("quick",1,3,2)!=key_id and STORE.record_key("trial",2,0,0)!=key_id)
	var invalid: Dictionary = STORE.validate({"schema_version":2,"records":{key_id:{"signature":"bad","total":-1,"best_lap":"bad","replay":"../../outside"}}})
	check("malformed_records_rejected",invalid.records.is_empty())
	var old: Dictionary = STORE.validate({"schema_version":1,"quick_race":{"laps":5}})
	check("v1_migration",old.schema_version==STORE.SCHEMA_VERSION and old.quick_race.laps==5 and old.records.is_empty())
	race.race_mode = "trial"
	race.start_race()
	race.trial.tick_playback(record.total+1.0)
	check("finished_ghost_hidden",not race.trial.ghost.visible)
	var replay_path: String = race.trial.replay_path(record.replay)
	var file: FileAccess = FileAccess.open(replay_path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	race.start_race()
	report("corrupt_state",{"samples":race.trial.playback.size(),"notice":race.trial.ghost_notice,"total":race.profile.data.records[key_id].total,"expected":record.total})
	check("corrupt_ghost_safe",race.trial.playback.is_empty() and race.trial.ghost_notice.contains("unavailable") and absf(race.profile.data.records[key_id].total-record.total)<0.000001)
	race.profile.data.records[key_id].signature = "0".repeat(64)
	race.start_race()
	check("incompatible_record_retired",race.trial.playback.is_empty() and race.trial.ghost_notice.contains("changed") and race.trial.summary().contains("changed"))

	# A finished slower run cannot replace the PB ghost; a better lap can update alone.
	race.profile.data.records[key_id] = record.duplicate(true)
	race.trial.completed = false
	race.player_car.finish_time = record.total+10.0
	race.trial.best_lap = record.best_lap+1.0
	race.trial.finish_run()
	check("slower_run_preserves_pb",race.profile.data.records[key_id].replay==record.replay and absf(race.profile.data.records[key_id].total-record.total)<0.000001)
	race.trial.completed = false
	race.trial.best_lap = record.best_lap-1.0
	race.trial.finish_run()
	check("lap_pb_preserves_total_and_ghost",race.profile.data.records[key_id].replay==record.replay and absf(race.profile.data.records[key_id].total-record.total)<0.000001 and race.profile.data.records[key_id].best_lap==record.best_lap-1.0)
	# Explicit DNF classification never awards a record.
	race.race_laps = 2
	race.start_race()
	race.session.classify()
	check("dnf_not_recorded",not race.profile.data.records.has(race.trial.key))
	# Valid checksum cannot make malformed sample data acceptable.
	race.race_laps = 1
	race.start_race()
	var payload: String = JSON.stringify({"version":1,"signature":race.trial.signature,"key":key_id,"total":record.total,"samples":[[0,0,0,0,0],[0,1,1,1,1]]})
	var malformed_id: String = payload.sha256_text()
	file = FileAccess.open(race.trial.replay_path(malformed_id),FileAccess.WRITE)
	file.store_string(payload)
	file.close()
	check("malformed_samples_rejected",race.trial.load_replay(malformed_id,record.total).is_empty())
	var store: RefCounted = STORE.new()
	store.path = TEST_PATH
	store.load_profile()
	store.save_profile()
	file = FileAccess.open(TEST_PATH,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check("v2_backup_preserves_records",store.load_profile().records.has(key_id))
	# Future profiles suppress both profile and ghost writes.
	file = FileAccess.open(TEST_PATH,FileAccess.WRITE)
	file.store_string('{"schema_version":99}')
	file.close()
	race.profile.load_profile()
	race.trial.completed = false
	race.trial.best_lap = 10.0
	race.player_car.finish_time = 10.0
	race.trial.finish_run()
	check("future_profile_untouched",race.profile.read_only and race.profile.read_raw(TEST_PATH).schema_version==99 and race.profile.data.records[key_id].replay=="")
	clear_test()
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
