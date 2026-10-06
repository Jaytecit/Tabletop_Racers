extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	# The engine injects a shorter soft deadline; three laps need ~260 sim seconds.
	summer_max_seconds = 600
	await super._ready()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Bound render frames so the engine's frames-based ceiling cannot end a
	# long race early. Accelerate fixed physics ticks without changing their delta.
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 180
	Engine.time_scale = 3.0
	report("effective_physics_delta",Engine.time_scale/Engine.physics_ticks_per_second)
	report("physics_ticks_per_second",Engine.physics_ticks_per_second)
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.profile_selected = true
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var opening: Node = get_tree().current_scene.get_node_or_null("Opening")
	if opening!=null:
		var sequence: Node = opening.get_node_or_null("Sequence")
		if sequence!=null:
			sequence.hardware_input_isolated = true
			sequence._restore_menu()
		opening.queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/mount_rainier_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	var baseline: bool = OS.get_environment("TABLETOP_GROUND_BASELINE")=="1"
	if baseline:
		var previous: Node = race.get_node("CourseEnvironment")
		race.remove_child(previous)
		previous.free()
		var packed: PackedScene = ResourceLoader.load("res://tests/baselines/ground/source_before/environments/tabletop/mount_rainier.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var environment: Node3D = packed.instantiate()
		environment.name = "CourseEnvironment"
		race.add_child(environment)
	report("original_collision_baseline",baseline)
	await settle_physics(5)
	helper.start_test(2,3)
	for frame: int in range(30000):
		await get_tree().physics_frame
		if frame%3600==0:
			report("progress",helper.snapshot())
			print("MOUNT_RAINIER_PROGRESS ",helper.snapshot())
		if frame==1800: save_frame("driving")
		if race.phase==3: break
	var finished: Dictionary = helper.snapshot()
	report("race",finished)
	var support_failures: Dictionary = {}
	for car: CharacterBody3D in race.all_cars: support_failures[car.player] = car.get_meta("last_support_failure",{})
	report("support_failures",support_failures)
	save_frame("results")
	var clean: bool = race.phase==3 and finished.results==4
	for car: Dictionary in finished.cars:
		clean = clean and car.finish>0 and car.crashes==0 and car.recoveries==0 and car.penalty==0
	report("passed",clean)
	race.show_menu()
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	for player: Node in get_tree().current_scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")
