extends "res://tests/probes/race_quality_ai_verification.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")

func _ready() -> void:
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	check(race.profile.read_only,"owner_profile_isolated")
	var schema6: Dictionary = STORE.defaults()
	schema6.schema_version = 6
	schema6.player_stats = {"0":{"grip":2,"speed":-2,"boost":0,"recovery":0}}
	var migrated: Dictionary = STORE.validate(schema6)
	check(migrated.vehicles.buggy.stats.grip==2.0,"old_driver_stats_migrate_to_buggy")
	for id: String in ["monster_truck","racing_car","drift_car","speedboat"]:
		check(migrated.vehicles[id]==STORE.defaults().vehicles[id],"new_class_starts_fresh_"+id)
	var isolated_profile: RefCounted = race.profile
	var local: RefCounted = STORE.new()
	local.path = summer_out_dir.path_join("record_fixture.json")
	race.profile = local
	race.menu_flow.choose_mode("trial")
	check(race.course.select("toys_r_you"),"course_selected")
	race.race_laps = 1
	race.start_race()
	race.trial.begin()
	var trial: RefCounted = race.trial
	var key: String = trial.key
	var old_signature: String = "a".repeat(64)
	var old_payload: String = JSON.stringify({"version":1,"signature":old_signature,"key":key,"total":90.0,"samples":[[0,0,0,0,0],[90,1,0,0,0]]})
	var old_id: String = old_payload.sha256_text()
	var old_file: FileAccess = FileAccess.open(trial.replay_path(old_id),FileAccess.WRITE)
	old_file.store_string(old_payload)
	old_file.close()
	local.data.records[key] = {"signature":old_signature,"total":90.0,"best_lap":90.0,"replay":old_id}
	check(local.save_profile()==OK,"old_record_saved")
	trial.begin()
	check(trial.playback.is_empty() and not trial.ghost_notice.is_empty(),"old_ghost_not_compared")
	trial.best_lap = 100.0
	trial.last_lap = 100.0
	race.player_car.finish_time = 100.0
	trial.finish_run()
	var replacement: Dictionary = local.data.records[key].duplicate(true)
	check(replacement.signature==trial.signature and replacement.total==100.0,"new_rules_record_replaces_faster_legacy")
	check(local.data.legacy_records[key].size()==1 and local.data.legacy_records[key][0].replay==old_id,"legacy_context_retained")
	check(FileAccess.file_exists(trial.replay_path(old_id)),"legacy_ghost_retained")
	check(not replacement.replay.is_empty() and FileAccess.file_exists(trial.replay_path(replacement.replay)),"new_ghost_saved")
	race.player_car.finish_time = 50.0
	trial.finish_run()
	check(local.data.records[key]==replacement and local.data.legacy_records[key].size()==1,"duplicate_finish_ignored")
	check(local.save_profile()==OK,"replacement_backup_advanced")
	check(local.save_profile()==OK,"legacy_survives_backup_rotation")
	trial.prune_replays()
	check(FileAccess.file_exists(trial.replay_path(old_id)),"legacy_ghost_survives_pruning")
	var loaded: Dictionary = local.load_profile()
	check(loaded.records[key]==replacement and loaded.legacy_records[key][0].signature==old_signature,"legacy_reload")
	trial.begin()
	check(not trial.playback.is_empty(),"current_ghost_loads")
	var signatures: Array[String] = []
	race.race_mode = "freestyle"
	for id: String in preload("res://scripts/vehicles/vehicle_catalog.gd").IDS:
		race.set_vehicle(id)
		check(trial.signature not in signatures,"signature_"+id)
		signatures.append(trial.signature)
		check(trial.ghost.get_child_count()>1,"ghost_mesh_"+id)
	race.profile = isolated_profile
	report("failures",failures)
	report("passed",failures.is_empty())
	for audio: Node in app.find_children("*","AudioStreamPlayer",true,false): audio.stop()
	await settle(5)
	finish()
