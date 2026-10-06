extends "res://tests/autopilot/probe_base.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const DIRECTORY: Script = preload("res://scripts/profiles/profile_directory.gd")

func write_json(path: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func course_ready(race: Node) -> void:
	await settle(3)
	for i: int in range(600):
		if not race.course.loading: return
		await get_tree().process_frame
	report("course_wait_timeout",false)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var opening: Node = app.get_node_or_null("Opening/Sequence")
	if opening!=null:
		opening.hardware_input_isolated = true
		opening.timeline_offset = opening.PROMPT_TIME+1.0-opening._audio_clock()
		await settle(3)
		await press("start_race",40)
		for i: int in range(120):
			if race.profile_menu.visible: break
			await get_tree().process_frame
	report("intro_or_skip_reaches_profiles",race.profile_menu.visible)
	get_tree().paused = false
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.machine_settings.path = summer_out_dir+"/machine.json"
	race.machine_settings.read_only = true
	report("startup_save_guard",race.profile.read_only and not race.profile_selected)
	race.start_race()
	report("unselected_start_blocked",race.phase==0)
	var directory: RefCounted = DIRECTORY.new()
	directory.root = summer_out_dir+"/profiles"
	directory.legacy_path = summer_out_dir+"/legacy.json"
	var legacy: RefCounted = STORE.new()
	legacy.path = directory.legacy_path
	legacy.wallet().points = 37
	legacy.wallet().bling = 82
	legacy.data.cup_wins = 2
	var record_key: String = STORE.record_key("trial",3,0,0,"game_table")
	legacy.data.records[record_key] = {"signature":"a".repeat(64),"total":120.0,"best_lap":38.0,"replay":""}
	report("legacy_fixture",legacy.save_profile()==OK)
	var schema12: Dictionary = legacy.data.duplicate(true)
	schema12.schema_version = 12
	schema12.vehicles.buggy.points = 37
	schema12.vehicles.buggy.bling = 82
	schema12.erase("wallet")
	schema12.erase("identity")
	write_json(legacy.path,schema12)
	var original_hash: String = FileAccess.get_sha256(legacy.path)
	report("migration",directory.load_directory()==OK and directory.index.entries.size()==1)
	var legacy_id: String = directory.index.entries[0].id
	# Simulate interrupted publication, leaving the staged payload intact.
	DirAccess.rename_absolute(directory.root+"/index.json",directory.root+"/interrupted-index.json")
	var resumed: RefCounted = DIRECTORY.new()
	resumed.root = directory.root
	resumed.legacy_path = legacy.path
	report("interrupted_migration",resumed.load_directory()==OK and resumed.index.entries[0].id==legacy_id)
	directory = resumed
	report("name_boundaries",DIRECTORY.valid_name("A") and DIRECTORY.valid_name("Abcdefghi") and not DIRECTORY.valid_name("") and not DIRECTORY.valid_name("Abcdefghij") and not DIRECTORY.valid_name("A/B") and not DIRECTORY.valid_name("A1"))
	report("invalid_requests",directory.create_profile("../bad",0).error==ERR_INVALID_PARAMETER and directory.create_profile("Valid",4).error==ERR_INVALID_PARAMETER and directory.select_profile("../legacy",STORE.new())==ERR_DOES_NOT_EXIST)
	race.profile_directory = directory
	race.show_menu()
	race.open_profiles()
	await settle(3)
	var ui: Control = race.profile_menu
	ui.name_input.text = "A123456789!"
	ui.confirm()
	report("paste_rejected",ui.visible and not race.profile_selected)
	ui.name_input.text = "Alex"
	ui.choose_portrait(2)
	ui.find_child("Confirm",true,false).grab_focus()
	await press("ui_accept",40)
	await course_ready(race)
	report("legacy_confirmation",race.profile_selected and race.profile.data.identity=={"name":"Alex","portrait_id":2} and race.profile.wallet().points==37 and race.profile.data.records.has(record_key) and not ui.visible)
	report("legacy_source_preserved",FileAccess.get_sha256(legacy.path)==original_hash)
	report("duplicate_rejected",directory.create_profile("aLeX",1).error==ERR_ALREADY_EXISTS)
	race.open_profiles()
	ui.create()
	ui.name_input.text = "Beatrice"
	ui.choose_portrait(1)
	await settle(2)
	ui.find_child("Confirm",true,false).grab_focus()
	await press("ui_accept",40)
	await course_ready(race)
	var second_id: String = directory.index.last_selected
	report("second_profile_fresh",race.profile.data.identity.name=="Beatrice" and race.profile.wallet().points==0 and race.profile.data.records.is_empty())
	race.profile.data.records[record_key] = {"signature":"b".repeat(64),"total":90.0,"best_lap":29.0,"replay":""}
	var before_legacy: String = FileAccess.get_sha256(directory.payload_path(legacy_id))
	var modes: Array[String] = ["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"]
	var modes_ok: bool = true
	for mode: String in modes:
		race.race_mode = mode
		race.save_preferences()
		var saved: Dictionary = STORE.validate(STORE.new().read_raw(race.profile.path))
		modes_ok = modes_ok and saved.identity.name=="Beatrice" and saved.mode==mode and FileAccess.get_sha256(directory.payload_path(legacy_id))==before_legacy
	report("all_modes_identity_and_save_isolation",modes_ok)
	race.rewards_awarded = false
	race.race_mode = "quick"
	race.award_race_rewards([{"player":1,"rank":1,"finished":true},{"player":2,"rank":2,"finished":true}])
	report("reward_file_isolation",race.profile.wallet().points>0 and FileAccess.get_sha256(directory.payload_path(legacy_id))==before_legacy)
	race.race_mode = "quick"
	race.profile.wallet().points = 9
	race.save_preferences()
	race.open_profiles()
	ui.go_back()
	report("cancel_switch_keeps_identity",race.profile.data.identity.name=="Beatrice" and not ui.visible)
	race.activate_profile(legacy_id)
	race.show_menu()
	await course_ready(race)
	report("switch_restores_progression",race.profile.wallet().points==37 and race.profile.data.records[record_key].total==120.0 and race.profile.data.identity.name=="Alex" and race.stats_test_mode==0)
	var machine: Dictionary = race.machine_settings.data.duplicate(true)
	race.activate_profile(second_id)
	race.show_menu()
	await course_ready(race)
	report("switch_restores_second_and_machine",race.profile.wallet().points==9 and race.profile.data.records[record_key].total==90.0 and race.machine_settings.data==machine)
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.start_race()
	race.begin_countdown()
	await settle(4)
	race.session.change_phase(race.session.Phase.RACING)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	race.session.set_physics_process(false)
	race.update_hud()
	await settle(3)
	var panel_names: String = ""
	for row: Node in race.get_node("HUD/Standings").get_children(): panel_names += row.text
	report("race_panel_names",panel_names.contains("Beatrice") and panel_names.contains(race.names[1]))
	var ranks_ok: bool = true
	for car: CharacterBody3D in race.cars:
		var label: Label3D = race.identities.labels[car]
		ranks_ok = ranks_ok and label.visible and label.text==str(race.session.rank_of(car)) and not car.visual.get_node("DriverNumber").visible
	report("live_ranks",ranks_ok)
	save_frame("race_names_positions_dots")
	race.set_physics_process(false)
	var records: Dictionary = race.session.progress.records
	if records.has(1) and records.has(2):
		records[2].distance = records[1].distance+race.track.total_length*0.5
	await settle(3)
	report("rank_changes_without_identity_change",race.identities.labels[race.player_car].text=="2" and race.identities.labels[race.all_cars[1]].text=="1" and race.names[0]=="Beatrice")
	report("in_race_switch_blocked",race.activate_profile(legacy_id)==ERR_BUSY and race.active_profile_id==second_id)
	var identity: Dictionary = race.identities.racers[1].duplicate(true)
	race.garage.select(race,3)
	report("livery_keeps_saved_person",race.identities.racers[1].profile_id==identity.profile_id and race.identities.racers[1].display_name==identity.display_name and race.identities.racers[1].portrait_id==identity.portrait_id)
	preload("res://scripts/race/arcade_podium.gd").show_results(race,[{"player":1,"rank":1,"finished":true,"time":120.0,"laps":3,"penalty":0.0}])
	var podium: Node = race.results_panel.get_node("Podium")
	report("results_keep_name_and_portrait",podium.get_node("Place1/Driver").text=="Beatrice" and podium.get_node("Driver0").texture.region==race.ARCADE.portrait(1).region)
	records[1].distance = race.track.total_length*1.2
	records[2].distance = race.track.total_length*0.1
	await settle(2)
	report("lapped_rank",race.identities.labels[race.player_car].text=="1")
	records[1].finish_time = 10.0
	await settle(3)
	report("finish_rank",race.identities.labels[race.player_car].text=="1")
	for id: int in records:
		records[id].finish_time = -1.0
		records[id].distance = 0.0
	await settle(3)
	report("tied_rank",race.identities.labels[race.player_car].text=="1" and race.identities.labels[race.all_cars[1]].text=="2")
	race.race_mode = "elimination"
	race.session.mode = "elimination"
	race.session.elimination.reset(race.session)
	await settle(2)
	report("elimination_rank",race.identities.labels[race.player_car].text==str(race.session.rank_of(race.player_car)))
	race.session.elimination.lap_completed(race.player_car,2)
	await settle(2)
	report("eliminated_label_hidden",not race.identities.labels[race.all_cars[3]].visible)
	race.race_mode = "quick"
	race.start_race()
	race.begin_countdown()
	await settle(2)
	report("retry_retains_identity",race.names[0]=="Beatrice" and race.profile.data.identity.portrait_id==1)
	race.show_menu()
	race.open_profiles()
	await settle(3)
	save_frame("saved_driver_selection")
	ui.create()
	ui.name_input.text = "Charlotte"
	ui.choose_portrait(3)
	await settle(3)
	save_frame("create_driver")
	ui.go_back()
	ui.go_back()
	var reloaded: RefCounted = DIRECTORY.new()
	reloaded.root = directory.root
	reloaded.legacy_path = legacy.path
	report("restart_directory",reloaded.load_directory()==OK and reloaded.list_profiles().size()==2)
	var store: RefCounted = STORE.new()
	report("restart_payload",reloaded.select_profile(second_id,store)==OK and store.wallet().points==9)
	var boundary: RefCounted = DIRECTORY.new()
	boundary.root = summer_out_dir+"/boundaries"
	boundary.legacy_path = summer_out_dir+"/missing.json"
	boundary.load_directory()
	report("persist_name_boundaries",boundary.create_profile("A",0).error==OK and boundary.create_profile("Abcdefghi",3).error==OK and boundary.create_profile("Abcdefghij",0).error==ERR_INVALID_PARAMETER)
	boundary.read_only = true
	report("read_only_rename_guard",boundary.rename_legacy(legacy_id,"Blocked",0)==ERR_UNAVAILABLE)
	boundary.read_only = false
	var corrupt_entry: Dictionary = boundary.create_profile("Corrupt",2)
	var corrupt_store: RefCounted = STORE.new()
	boundary.select_profile(corrupt_entry.id,corrupt_store)
	corrupt_store.wallet().points = 11
	corrupt_store.save_profile()
	corrupt_store.wallet().points = 12
	corrupt_store.save_profile()
	write_json(corrupt_store.path,{"schema_version":999})
	var unchanged_path: String = store.path
	report("newer_payload_guard",boundary.select_profile(corrupt_entry.id,store)==ERR_FILE_CORRUPT and store.path==unchanged_path)
	write_json(corrupt_store.path,["broken"])
	report("payload_backup_recovery",boundary.select_profile(corrupt_entry.id,corrupt_store)==OK and corrupt_store.wallet().points==11)
	var future: RefCounted = DIRECTORY.new()
	future.root = summer_out_dir+"/future"
	DirAccess.make_dir_recursive_absolute(future.root)
	write_json(future.root+"/index.json",{"schema_version":99,"entries":[],"last_selected":""})
	report("newer_index_guard",future.load_directory()==ERR_UNAVAILABLE and future.read_only and future.create_profile("Other",0).error==ERR_UNAVAILABLE)
	var unwritable: RefCounted = DIRECTORY.new()
	unwritable.root = summer_out_dir+"/blocked_root"
	write_json(unwritable.root,{})
	report("write_failure_guard",unwritable.create_profile("Other",0).error!=OK and unwritable.list_profiles().is_empty())
	write_json(directory.root+"/index.json",{"broken":true})
	var backup: RefCounted = DIRECTORY.new()
	backup.root = directory.root
	backup.legacy_path = legacy.path
	report("corrupt_index_backup",backup.load_directory()==OK and backup.list_profiles().size()==2)
	write_json(directory.root+"/index.json.bak",{"broken":true})
	var corrupt: RefCounted = DIRECTORY.new()
	corrupt.root = directory.root
	report("corrupt_index_guard",corrupt.load_directory()==ERR_FILE_CORRUPT and corrupt.read_only and corrupt.create_profile("Other",0).error==ERR_UNAVAILABLE)
	var passed: bool = true
	for value: Variant in _reports.values():
		if value is bool and not value: passed = false
	report("passed",passed)
	race.profile.read_only = true
	race.set_physics_process(false)
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")
