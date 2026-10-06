extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)

func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.size = Vector2i(1920,1080)
	await settle(30)
	var race: Node = get_tree().current_scene.get_node("Race")
	# Garage changes now persist; keep this presentation regression isolated.
	race.profile.path = "user://m4_presentation_test.json"
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.course.select("game_table")
	race.show_menu()
	check("portraits_fit",race.garage.cards[0].get_node("Portrait").size==Vector2(68,65))
	check("blackjack_theme",race.get_node("CourseEnvironment/BlackjackEnvironment").get_meta("theme")=="blackjack")
	var prohibited: bool = false
	for title: String in ["RedDie","IvoryDie","YellowPencil","PencilTip","Eraser","RampSpool","SpoolFoot"]:
		prohibited = prohibited or race.has_node(title)
	check("no_mixed_theme_props",not prohibited and not race.track.get_node("Generated").has_node("RulerTicks"))
	race.garage.cards[2].pressed.emit()
	check("driver_selected",race.garage.selected==2 and race.garage.cards[2].button_pressed)
	await settle(2)
	save_frame("01_title_1080p")
	race.player_car.ai = true
	race.difficulty = 1
	race.race_seed = 1001
	await press("start_race")
	check("countdown_input",race.phase==1)
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	var captures: Dictionary = {}
	var samples: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for frame: int in range(13000):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		if frame>10: samples.append(float(now-last)/1000.0)
		last = now
		var sector: int = int(race.player_car.station/race.track.total_length*12.0)
		if not captures.has(sector) and race.phase==2:
			captures[sector] = true
			await settle(1)
			save_frame("sector_%02d"%sector)
			last = Time.get_ticks_usec()
		if race.phase==3: break
	check("complete_race",race.phase==3 and race.session.results.size()==4 and race.player_car.laps==3)
	report("results",race.session.results.duplicate(true))
	var stats: Array = []
	for car: Node in race.cars:
		stats.append({"player":car.player,"jumps":car.jumps,"impacts":car.impacts,"crashes":car.crashes,"time":car.finish_time})
		check("finished_car_"+str(car.player),car.finish_time>=0)
	report("car_stats",stats)
	await settle(2)
	save_frame("02_results_1080p")
	Engine.time_scale = 1.0
	race.start_race()
	await get_tree().physics_frame
	check("retry_clean",race.phase==1 and race.race_time==0 and race.session.results.is_empty())
	race.show_menu()
	check("selection_preserved",race.garage.selected==2)
	get_tree().root.size = Vector2i(1280,720)
	await settle(8)
	save_frame("03_menu_720p")
	get_tree().root.size = Vector2i(2560,1080)
	await settle(8)
	save_frame("04_menu_ultrawide")
	samples.sort()
	report("gpu",RenderingServer.get_video_adapter_name())
	report("accelerated_race_median_ms",samples[int(samples.size()*0.5)])
	report("accelerated_race_p95_ms",samples[int(samples.size()*0.95)])
	report("accelerated_race_p99_ms",samples[int(samples.size()*0.99)])
	report("failures",failures)
	report("passed",failures.is_empty())
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
		DirAccess.remove_absolute("user://m4_presentation_test.json"+suffix)
	finish()
