extends "res://tests/autopilot/probe_base.gd"
var race: Node3D
var failures: Array[String] = []
func check(value: bool, title: String) -> void:
	report(title,value)
	if not value: failures.append(title)
func prepare() -> void:
	await settle(5)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening/Sequence").hardware_input_isolated = true
	app.get_node("Opening/Sequence")._restore_menu()
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_selected = true
	check(race.profile.read_only and race.profile_directory.read_only,"read_only")
	race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
	race.race_mode = "freestyle"
	race.rival_count = 7
	race.race_laps = 3
	race.difficulty = 2
	race.race_seed = 42
	race.profile.data.character_colour_id = -1
	race.profile.data.gold_livery = false
	race.profile.data.identity.portrait_id = 0
	race.show_menu()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
func select_course(id: String, mode: String = "freestyle") -> void:
	race.race_mode = mode
	race.show_menu()
	check(race.course.select(id),"selected_"+id)
	while race.course.loading: await get_tree().process_frame
	check(race.set_vehicle("buggy"),"buggy_"+id)
	race.garage.select(race,0)
	race.rival_count = 7
	race.start_race()
	race.player_car.ai = true
	for i: int in range(race.cars.size()): race.cars[i].ai_driver.rng.seed = 64*(i+1)
	race.begin_countdown()
	race.session.countdown = 0.81
	await settle(120)
func percentile(values: Array, fraction: float) -> float:
	if values.is_empty(): return 0.0
	var ordered: Array = values.duplicate()
	ordered.sort()
	return float(ordered[mini(ordered.size()-1,int((ordered.size()-1)*fraction))])
func summary(values: Array) -> Dictionary:
	return {"samples":values.size(),"p50":percentile(values,0.5),"p95":percentile(values,0.95),"max":percentile(values,1.0)}
func sample(ticks: int) -> Dictionary:
	var wall: Array = []
	var process: Array = []
	var physics: Array = []
	var gpu: Array = []
	var draws: Array = []
	var primitives: Array = []
	var previous: int = Time.get_ticks_usec()
	for i: int in range(ticks):
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		wall.append((now-previous)/1000.0)
		previous = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if RenderingServer.has_method("viewport_get_measured_render_time_gpu"):
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	return {"wall_ms":summary(wall),"process_ms":summary(process),"physics_ms":summary(physics),"gpu_ms":summary(gpu),"draw_calls":summary(draws),"primitives":summary(primitives)}
func close() -> void:
	for voice: Node in get_tree().current_scene.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
		voice.stream = null
	await settle(3)
	finish()
func _ready() -> void:
	await super._ready()
	await prepare()
	await run()
	report("failures",failures)
	report("passed",failures.is_empty())
	await close()
func run() -> void:
	var measurements: Dictionary = {}
	var selected: String = ""
	var highest: float = -1.0
	for id: String in preload("res://scripts/tracks/content_catalog.gd").IDS:
		await select_course(id)
		check(race.cars.size()==8,"eight_"+id)
		measurements[id] = await sample(360)
		report("courses",measurements)
		var cost: float = measurements[id].wall_ms.p95
		if cost>highest:
			highest = cost
			selected = id
		race.player_car.ai = false
	report("selected_heaviest",selected)
	report("runtime",{"gpu":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().size),"vsync":false,"frame_cap":0,"vehicle":"buggy","cars":8,"difficulty":"Hard","sampling":"120 warm-up physics ticks then 360 rendered frames per course"})
