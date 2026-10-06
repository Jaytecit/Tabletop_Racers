extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
const TEST_PATH: String = "user://m5_quick_race_test.json"
func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)
func write_json(path: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(3)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = TEST_PATH
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(TEST_PATH+suffix)
	race.profile.data = race.profile.defaults()
	race.profile.read_only = false
	race.race_mode = "quick"
	race.race_mode = "quick"
	race.menu.get_node("Mode").select(0)
	race.menu.get_node("QuickRace/Laps").select(2)
	race.difficulty = 1
	race.rival_count = 3
	race.race_laps = 3
	race.save_preferences()
	var store: RefCounted = load("res://scripts/profile_store.gd").new()
	store.path = TEST_PATH
	check("default_reload",store.load_profile().quick_race.rivals==3)
	var sanitized: Dictionary = store.validate({"schema_version":1,"quick_race":{"rivals":99,"laps":-2,"difficulty":"bad","driver":99,"vehicle_id":"missing","track_id":"missing"}})
	check("clamp_and_ids",sanitized.quick_race.rivals==3 and sanitized.quick_race.laps==1 and sanitized.quick_race.difficulty==1 and sanitized.quick_race.driver==3 and sanitized.quick_race.vehicle_id=="buggy" and sanitized.quick_race.track_id=="blackjack")
	write_json(TEST_PATH,{"difficulty":2,"laps":5,"rivals":1})
	check("version_zero_migration",store.load_profile().quick_race.laps==5 and store.data.schema_version==store.SCHEMA_VERSION)
	check("migration_save",store.save_profile()==OK)
	store.data.quick_race.laps = 2
	check("atomic_overwrite",store.save_profile()==OK and not FileAccess.file_exists(TEST_PATH+".tmp"))
	var bad: FileAccess = FileAccess.open(TEST_PATH,FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	check("backup_recovery",store.load_profile().quick_race.laps==5 and store.status=="Profile restored from backup")
	check("recovery_save",store.save_profile()==OK and store.validate(store.read_raw(TEST_PATH+".bak")).quick_race.laps==5)
	write_json(TEST_PATH,{"schema_version":99,"quick_race":{"laps":7}})
	store.load_profile()
	check("future_not_overwritten",store.read_only and store.save_profile()==ERR_UNAVAILABLE and store.read_raw(TEST_PATH).schema_version==99)
	race.save_preferences()
	var laps: OptionButton = race.menu.get_node("QuickRace/Laps")
	laps.grab_focus()
	await key(KEY_ENTER,50)
	check("enter_opens_options",race.phase==0 and laps.get_popup().visible)
	await key(KEY_UP,50)
	await key(KEY_ENTER,50)
	check("dropdown_changes_laps",race.race_laps==2 and not laps.get_popup().visible)
	await key(KEY_ESCAPE,50)
	race.menu.get_node("QuickRace/Rivals").item_selected.emit(1)
	laps.item_selected.emit(0)
	race.menu.get_node("QuickRace/Difficulty").item_selected.emit(2)
	race.garage.cards[2].pressed.emit()
	store.load_profile()
	check("menu_settings_saved",store.data.quick_race.rivals==1 and store.data.quick_race.laps==1 and store.data.quick_race.difficulty==2 and store.data.quick_race.driver==2)
	# Recreate the real app with the isolated path before _ready loads preferences.
	var old_app: Node = get_tree().current_scene
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.get_node("Race").profile.path = TEST_PATH
	get_tree().current_scene = null
	old_app.queue_free()
	get_tree().root.add_child.call_deferred(app)
	await get_tree().process_frame
	get_tree().current_scene = app
	await settle(3)
	race = app.get_node("Race")
	check("app_restart_preferences",race.rival_count==1 and race.race_laps==1 and race.difficulty==2 and race.garage.selected==2)
	await settle(2)
	save_frame("01_quick_race_menu")
	race.player_car.ai = true
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	for rivals: int in [0,1,2,3]:
		race.rival_count = rivals
		race.race_laps = 1
		race.difficulty = 1
		race.show_menu()
		race.focus_start()
		await press("start_race")
		check("grid_"+str(rivals),race.phase==1 and race.cars.size()==rivals+1 and race.session.progress.records.size()==rivals+1)
		for i: int in range(4):
			var car: Node = race.all_cars[i]
			check("active_"+str(rivals)+"_"+str(i),car.visible==(i<=rivals) and car.is_physics_processing()==(i<=rivals) and (car.collision_layer!=0)==(i<=rivals))
		for frame: int in range(12000):
			await get_tree().process_frame
			if race.phase==3: break
		check("finish_"+str(rivals),race.phase==3 and race.session.results.size()==rivals+1 and race.player_car.laps==1)
		for result: Dictionary in race.session.results:
			check("legal_finish_"+str(rivals)+"_"+str(result.player),result.finished and result.laps==1)
		race.update_hud()
		check("hud_"+str(rivals),race.get_node("HUD/Status").text.contains("LAP 1 / 1") and race.get_node("HUD/Status").text.contains("/ "+str(rivals+1)))
		report("results_"+str(rivals),race.session.results.duplicate(true))
		await settle(1)
		save_frame("results_"+str(rivals))
	Engine.time_scale = 1.0
	race.start_race()
	check("retry_reset",race.phase==1 and race.player_car.laps==0 and race.session.results.is_empty())
	await press("pause_race")
	check("pause",race.paused_race)
	await press("menu")
	check("return_menu",race.phase==0 and not race.paused_race)
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(TEST_PATH+suffix)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
