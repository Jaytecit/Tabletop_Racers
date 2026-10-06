extends "res://tests/autopilot/probe_base.gd"
const TEST_PATH: String = "user://m6_ghost_test.json"
var failures: Array[String] = []
var secondary_course: String = "toybox_trestle"

func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)

func clear_test() -> void:
	var directory: DirAccess = DirAccess.open(TEST_PATH.get_base_dir())
	for file: String in directory.get_files():
		if file.begins_with(TEST_PATH.get_file()): directory.remove(file)

func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(5)
	clear_test()
	var race: Node = get_tree().current_scene.get_node("Race")
	race.controller.set_physics_process(false)
	race.controller.set_process_input(false)
	race.controller.device = -1
	race.controller.using_pad = false
	race.profile.path = TEST_PATH
	race.profile.data = race.profile.defaults()
	race.profile.read_only = false
	race.race_mode = "trial"
	race.race_laps = 1
	race.difficulty = 1
	race.player_car.ai = true
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 16
	var records: Dictionary = {}
	for id: String in ["practice_patch",secondary_course]:
		race.course.select(id)
		race.start_race()
		check(id+"_no_foreign_ghost",race.trial.playback.is_empty())
		for frame: int in range(12000):
			await get_tree().process_frame
			if race.phase==3: break
		check(id+"_finish",race.phase==3)
		var key: String = race.trial.key
		var record: Dictionary = race.profile.data.records.get(key,{})
		check(id+"_saved_replay",not record.is_empty() and record.replay!="")
		records[id] = {"key":key,"record":record.duplicate(true)}
		check(id+"_time_budget",race.player_car.finish_time>=race.course.entry.target_lap_seconds.x and race.player_car.finish_time<=race.course.entry.target_lap_seconds.y)
		report(id+"_lap_seconds",race.player_car.finish_time)
	check("independent_records",records.practice_patch.key!=records[secondary_course].key and records.practice_patch.record.signature!=records[secondary_course].record.signature)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	# Recreate the app from the persisted selected course and independent record map.
	var old: Node = get_tree().current_scene
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.get_node("Race").profile.path = TEST_PATH
	get_tree().current_scene = null
	old.queue_free()
	get_tree().root.add_child.call_deferred(app)
	await get_tree().process_frame
	get_tree().current_scene = app
	await settle(5)
	race = app.get_node("Race")
	race.controller.set_physics_process(false)
	race.controller.set_process_input(false)
	race.controller.device = -1
	race.controller.using_pad = false
	check("restart_selected_course",race.track_id==secondary_course and race.race_mode=="trial" and race.profile.data.records.size()==2)
	for id: String in ["practice_patch",secondary_course,"practice_patch"]:
		race.course.select(id)
		race.start_race()
		check(id+"_matching_replay",not race.trial.playback.is_empty() and race.trial.key==records[id].key)
		check(id+"_ghost_body_free",race.trial.ghost.find_children("*","CollisionObject3D",true,false).is_empty())
		if id=="card_bridge":
			var lower_clock: float = -1.0
			var upper_clock: float = -1.0
			for sample: Array in race.trial.playback:
				if Vector2(float(sample[1]),float(sample[3])).length()>2.5: continue
				if float(sample[2])>3.0 and upper_clock<0.0: upper_clock = float(sample[0])
				if float(sample[2])<0.1 and lower_clock<0.0: lower_clock = float(sample[0])
			check("bridge_ghost_both_heights_recorded",lower_clock>=0.0 and upper_clock>lower_clock)
			if lower_clock>=0.0 and upper_clock>lower_clock:
				race.trial.cursor = 0
				race.trial.tick_playback(lower_clock)
				check("bridge_lower_ghost_height",race.trial.ghost.position.y<0.1)
				race.trial.tick_playback(upper_clock)
				check("bridge_upper_ghost_height",race.trial.ghost.position.y>3.0)
			race.trial.cursor = 0
		race.trial.tick_playback(1.0)
		check(id+"_ghost_visible",race.trial.ghost.visible)
		race.paused_race = true
		race.banner.visible = false
		await settle(2)
		save_frame(id+"_ghost")
		race.show_menu()
		check(id+"_ghost_cleanup",not race.trial.ghost.visible and race.trial.playback.is_empty())
	clear_test()
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
