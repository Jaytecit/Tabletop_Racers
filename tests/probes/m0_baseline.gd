extends "res://tests/autopilot/probe_base.gd"
# M0 baseline only: default launch, presentation and unchanged handling.
func _ready() -> void:
	await super._ready()
	await settle(30)
	var app: Node = get_tree().current_scene
	var race: Node = app.get_node("Race") if app != null and app.has_node("Race") else app
	if race == null or app.scene_file_path not in ["res://showcase_3d.tscn","res://scenes/app.tscn"]:
		report("passed", false)
		report("reason", "Default scene must be the 3D app or showcase")
		finish()
		return
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	report("engine", Engine.get_version_info())
	report("adapter", RenderingServer.get_video_adapter_name())
	report("renderer", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	report("viewport_size", str(get_viewport().get_visible_rect().size))
	report("main_scene", ProjectSettings.get_setting("application/run/main_scene"))
	var initial_ok: bool = race.phase == 0 and race.cars.size() == 4
	initial_ok = initial_ok and is_equal_approx(race.track.half_width, 3.0)
	initial_ok = initial_ok and race.menu.visible and race.get_node("Retro/PixelFilter").visible
	report("default_launch_passed", initial_ok)
	report("controller", race.get_node("HUD/Menu/Controller").text)
	var speeds: Array[float] = []
	for car: Node in race.cars:
		speeds.append(car.top_speed)
	report("top_speeds", speeds)
	save_frame("00_menu")
	# Exercise the real start action; the normal runtime handles the countdown.
	await press("start_race")
	for _i: int in range(250):
		await get_tree().physics_frame
	var racing_ok: bool = race.phase == 2 and not race.menu.visible
	report("race_started", racing_ok)
	var player: Node3D = race.player_car
	var start_position: Vector3 = player.position
	# Keyboard commands remain usable even with an idle detected controller.
	race.controller.using_pad = false
	Input.action_press("p1_go")
	var samples: Array[Dictionary] = []
	for _i: int in range(120):
		await RenderingServer.frame_post_draw
		samples.append({
			"process_cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_cpu_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),
			"fps": Engine.get_frames_per_second()
		})
	Input.action_release("p1_go")
	report("moved", player.position.distance_to(start_position) > 0.5)
	report("performance_samples", samples)
	report("race_state", race.diagnostic_state())
	await settle()
	save_frame("01_racing")
	report("passed", initial_ok and racing_ok and player.position.distance_to(start_position) > 0.5)
	finish()
