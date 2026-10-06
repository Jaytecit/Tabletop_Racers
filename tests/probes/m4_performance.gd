extends "res://tests/autopilot/probe_base.gd"
var course_id: String = "game_table"
func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.size = Vector2i(1920,1080)
	await settle(30)
	var render_size: Vector2i = get_viewport().get_texture().get_image().get_size()
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m4_performance_test.json"
	race.race_mode = "quick"
	race.course.select(course_id)
	race.rival_count = 3
	race.race_laps = 3
	race.difficulty = 1
	race.player_car.ai = true
	race.start_race()
	var samples: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for frame: int in range(14000):
		await settle(1)
		var now: int = Time.get_ticks_usec()
		if frame>20: samples.append(float(now-last)/1000.0)
		last = now
		if race.phase==3: break
	samples.sort()
	var native: bool = render_size==Vector2i(1920,1080)
	var budget: bool = samples[int(samples.size()*0.95)]<=16.7 and samples[int(samples.size()*0.99)]<=25 and samples.back()<100
	report("time_scale",Engine.time_scale)
	report("sample_count",samples.size())
	report("render_size",str(render_size))
	report("gpu",RenderingServer.get_video_adapter_name())
	report("cpu",OS.get_processor_name())
	report("median_ms",samples[int(samples.size()*0.5)])
	report("p95_ms",samples[int(samples.size()*0.95)])
	report("p99_ms",samples[int(samples.size()*0.99)])
	report("max_ms",samples.back())
	report("frame_budget_pass",budget)
	report("complete_race",race.phase==3)
	report("passed",race.phase==3 and native and budget)
	save_frame("native_1080p_results")
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
		DirAccess.remove_absolute("user://m4_performance_test.json"+suffix)
	finish()
