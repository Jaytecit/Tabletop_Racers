extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race_courses: Array[String] = ["practice_patch","felt_sprint","game_table"]
const TEST_PATH: String = "user://m6_content_test.json"

func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)

func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(6)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = TEST_PATH
	race.profile.data = race.profile.defaults()
	race.profile.read_only = false
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.difficulty = 1
	race.player_car.ai = true
	race.course.select("game_table")
	race.show_menu()
	await settle(3)
	var menu: OptionButton = race.menu.get_node("TrackSelect")
	check("catalogue_entries",menu.item_count==race.course.CATALOG.IDS.size())
	menu.grab_focus()
	await key(KEY_ENTER,50)
	check("keyboard_opens_course_list",menu.get_popup().visible and race.phase==0)
	await key(KEY_DOWN,50)
	await key(KEY_ENTER,50)
	check("keyboard_selects_course",race.track_id=="practice_patch" and not menu.get_popup().visible and race.phase==0)
	check("legacy_alias",race.course.CATALOG.load_entry("blackjack").entry.id=="game_table")
	for index: int in [1,2,0,2,1,0]:
		menu.item_selected.emit(index)
		await settle(3)
		var id: String = race.course.CATALOG.IDS[index]
		check(id+"_selected",race.track_id==id and race.track.definition.id==id and race.phase==0)
		check(id+"_saved",race.profile.validate(race.profile.read_raw(TEST_PATH)).quick_race.track_id==id)
		check(id+"_resources",race.course.entry.preview==race.menu.get_node("CourseMap").texture and race.track.validation_errors.is_empty())
		check(id+"_support_sibling",race.has_node("CourseEnvironment/Support") and not race.track.has_node("CourseEnvironment"))
		var environment: Node = race.get_node("CourseEnvironment")
		race.track.rebuild_art()
		check(id+"_rebuild_preserves_environment",is_instance_valid(environment) and race.get_node("CourseEnvironment")==environment)
		var signature: String = race.trial.signature
		check(id+"_signature",signature.length()==64)
		for gate: Dictionary in race.track.gates:
			var direction: Vector2 = race.track.direction(gate.station)
			for lane: float in [-3.6,-2.0,0.0,2.0,3.6]:
				var position: Vector3 = gate.position+Vector3(-direction.y,0,direction.x)*lane
				var support: Dictionary = race.player_car.physical_support(position+Vector3.UP*0.32)
				check("%s_gate%d_lane%.1f" % [id,gate.index,lane],not support.is_empty())
		if index in [1,2]:
			check(id+"_flat",race.track.definition.sections.all(func(section: Resource) -> bool: return not section.jump_exit and section.start.y==0.0 and section.end.y==0.0))
		await settle(2)
		save_frame(id+"_menu")
	var old_environment: Node = race.get_node("CourseEnvironment")
	check("unknown_rejected",not race.course.select("missing"))
	check("unknown_keeps_course",race.get_node("CourseEnvironment")==old_environment and race.phase==0 and race.menu.get_node("Start").disabled)
	check("class_rejected",not race.course.select("felt_sprint","boat"))
	check("error_recoverable",race.course.select("felt_sprint") and not race.menu.get_node("Start").disabled)
	var invalid: Resource = race.course.entry.duplicate()
	invalid.environment = null
	check("missing_resource_rejected",race.course.CATALOG.validate_entry(invalid,invalid.id,"buggy").has("error"))
	invalid = race.course.entry.duplicate()
	invalid.id = "duplicate"
	check("identity_rejected",race.course.CATALOG.validate_entry(invalid,"felt_sprint","buggy").has("error"))
	check("record_namespaces",race.profile.record_key("trial",3,0,0,"felt_sprint")!=race.profile.record_key("trial",3,0,0,"practice_patch"))
	check("legacy_record_namespace",race.profile.record_key("trial",3,0,0,"blackjack")==race.profile.record_key("trial",3,0,0,"game_table"))
	# Real driving commands on each new start straight, before automated full races.
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	for id: String in ["practice_patch","felt_sprint"]:
		race.course.select(id)
		# Settle new physics support before bypassing the normal 3.8s countdown.
		await settle(3)
		race.player_car.ai = false
		race.start_race()
		race.session.countdown = 0.8
		race.session.tick(0.05)
		Input.action_press("p1_go")
		Input.action_press("boost")
		var peak: float = 0.0
		for frame: int in range(75):
			await get_tree().physics_frame
			peak = maxf(peak,Vector2(race.player_car.velocity.x,race.player_car.velocity.z).length())
		Input.action_release("p1_go")
		Input.action_release("boost")
		check(id+"_boost_input",peak>12.0 and race.player_car.boost<100.0 and race.player_car.crashes==0)
		report(id+"_peak_speed",peak)
		report(id+"_boost_crashes",race.player_car.crashes)
		await settle(2)
		save_frame(id+"_boost_drive")
		var crashes: int = race.player_car.crashes
		await press("reset_car",50)
		check(id+"_manual_reset",race.player_car.crashes==crashes+1)
		race.show_menu()
	race.controller.set_physics_process(true)
	race.player_car.ai = true
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	for id: String in race_courses:
		race.course.select(id)
		race.start_race()
		check(id+"_grid",race.cars.size()==(1 if id=="practice_patch" else 4))
		for frame: int in range(18000):
			await get_tree().process_frame
			if race.phase==3: break
		check(id+"_race_finished",race.phase==3 and race.player_car.laps==3)
		for row: Dictionary in race.session.results:
			check(id+"_finish_"+str(row.player),row.finished and row.laps==3)
		report(id+"_results",race.session.results.duplicate(true))
		await settle(2)
		save_frame(id+"_results")
		race.start_race()
		check(id+"_retry",race.phase==1 and race.player_car.laps==0 and race.session.results.is_empty() and race.trial.playback.is_empty())
		race.paused_race = true
		race.course.select("felt_sprint" if id!="felt_sprint" else "game_table")
		check(id+"_switch_cleans_pause",race.phase==0 and not race.paused_race and race.session.results.is_empty() and not race.trial.ghost.visible)
	Engine.time_scale = 1.0
	race.race_mode = "cup"
	race.course.select("practice_patch")
	race.start_race()
	check("cup_starts_sprint",race.track_id=="felt_sprint" and race.cars.size()==4 and race.session.laps_required==3)
	race.show_menu()
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(TEST_PATH+suffix)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
