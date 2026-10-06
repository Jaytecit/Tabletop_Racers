extends "res://tests/probes/bedroom_presentation_verification.gd"

func _ready() -> void:
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_selected = true
	var course: String = OS.get_environment("TABLETOP_VERIFY_COURSE")
	check(select_test_course(course),"selected")
	await settle(4)
	await inspect_course()
	check(race.profile.read_only,"read_only")
	check(FileAccess.get_sha256("res://scripts/vehicles/arcade_car.gd")==OS.get_environment("TABLETOP_EXPECT_CAR_HASH"),"accepted_car_revision")
	check(FileAccess.get_sha256("res://showcase_track.gd")==OS.get_environment("TABLETOP_EXPECT_TRACK_HASH"),"accepted_track_revision")
	var display: Node3D = race.get_node("CourseEnvironment/BedroomDisplay")
	var original: Environment = display.original_environment
	check(race.course.select("game_table"),"switch_to_source")
	check(race.get_node("Environment").environment==original,"source_environment_restored")
	var preview: Node3D = race.menu.get_node("Diorama").get_child(0).get_child(0)
	check(preview.find_children("BedroomDisplay","",true,false).is_empty(),"source_preview_restored")
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
