extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, passed: bool) -> void:
	report(label,passed)
	if not passed: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(6)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6_breakfast_loading_test.json"
	race.profile.data = race.profile.defaults()
	race.profile.read_only = false
	race.race_mode = "quick"
	race.rival_count = 3
	race.course.select("game_table")
	race.show_menu()
	await settle(3)
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	check("catalogue_entries",choice.item_count==race.course.CATALOG.IDS.size())
	choice.grab_focus()
	await key(KEY_ENTER,50)
	for index: int in range(4): await key(KEY_DOWN,50)
	await key(KEY_ENTER,50)
	check("keyboard_selects_breakfast",race.track_id=="cereal_slalom" and race.phase==0 and not choice.get_popup().visible)
	report("selected_course",race.track_id)
	if race.track_id!="cereal_slalom":
		report("passed",false)
		finish()
		return
	check("saved_selection",race.profile.validate(race.profile.read_raw(race.profile.path)).get("quick_race",{}).get("track_id","")=="cereal_slalom")
	check("breakfast_identity",race.get_node("CourseEnvironment").get_meta("theme")=="breakfast" and race.course.entry.cup=="Breakfast")
	check("matching_preview",race.course.entry.preview==race.menu.get_node("CourseMap").texture)
	check("breakfast_diorama",race.menu.get_node("Diorama").find_children("Bowl","Node3D",true,false).size()==1)
	save_frame("breakfast_menu")
	var environment: Node = race.get_node("CourseEnvironment")
	race.track.rebuild_art()
	check("rebuild_preserves_support",is_instance_valid(environment) and environment==race.get_node("CourseEnvironment"))
	var samples: int = 0
	for step: int in range(int(ceil(race.track.total_length/2.0))):
		var station: float = float(step)*2.0
		var direction: Vector2 = race.track.direction(station)
		for lane: float in [-3.6,-2.0,0.0,2.0,3.6]:
			var position: Vector3 = race.track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*lane
			var support: Dictionary = race.player_car.physical_support(position+Vector3.UP*0.32)
			if support.is_empty(): failures.append("unsupported_%.1f_%.1f"%[station,lane])
			var projected: Dictionary = race.track.project_3d(position,station)
			if absf(wrapf(projected.station-station,-race.track.total_length*0.5,race.track.total_length*0.5))>1.0: failures.append("projection_%.1f_%.1f"%[station,lane])
			samples += 1
	report("physical_support_projection_samples",samples)
	check("invalid_class_rejected",not race.course.select("cereal_slalom","boat"))
	check("invalid_id_rejected",not race.course.select("missing"))
	check("error_keeps_support",environment==race.get_node("CourseEnvironment") and race.menu.get_node("Start").disabled)
	check("error_recoverable",race.course.select("cereal_slalom") and not race.menu.get_node("Start").disabled)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.player_car.ai = false
	race.start_race()
	await settle(3)
	race.session.countdown = 0.8
	race.session.tick(0.05)
	var before: float = race.player_car.station
	Input.action_press("p1_go")
	Input.action_press("boost")
	var peak: float = 0.0
	for frame: int in range(75):
		await get_tree().physics_frame
		peak = maxf(peak,Vector2(race.player_car.velocity.x,race.player_car.velocity.z).length())
	Input.action_release("p1_go")
	Input.action_release("boost")
	check("boost_moves_player",peak>17.0 and race.player_car.boost<100.0 and race.player_car.crashes==0 and fposmod(race.player_car.station-before,race.track.total_length)>8.0)
	report("boost_peak_speed",peak)
	await settle(2)
	save_frame("breakfast_boost")
	await press("pause_race",50)
	check("pause_input",race.paused_race)
	await settle_physics(2)
	await press("pause_race",50)
	await settle_physics(2)
	check("resume_input",not race.paused_race)
	var crashes: int = race.player_car.crashes
	await press("reset_car",50)
	await settle_physics(2)
	check("reset_input",race.player_car.crashes==crashes+1)
	race.show_menu()
	race.start_race()
	check("retry_cleans_state",race.phase==1 and race.player_car.laps==0 and race.session.results.is_empty())
	race.paused_race = true
	check("switch_to_casino",race.course.select("game_table"))
	check("switch_cleans_state",race.phase==0 and not race.paused_race and race.session.results.is_empty() and race.get_node("CourseEnvironment").get_meta("theme","")!="breakfast")
	check("return_to_breakfast",race.course.select("cereal_slalom"))
	var record: String = race.profile.record_key("trial",3,0,0,"cereal_slalom")
	check("record_key_accepted",race.profile.valid_record_key(record))
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(race.profile.path+suffix)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
