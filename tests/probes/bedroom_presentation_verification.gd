extends "res://tests/probes/staged_road_verification.gd"
const DISPLAY: Script = preload("res://scripts/tracks/bedroom_display.gd")

func _enter_tree() -> void:
	var uid: int = ResourceUID.text_to_id("uid://144hv5b6kwah")
	if ResourceUID.has_id(uid): ResourceUID.set_id(uid,"res://showcase_track.gd")
	else: ResourceUID.add_id(uid,"res://showcase_track.gd")
	# Match the accepted Town Square verification, rather than old Time Trial defaults.
	OS.set_environment("TABLETOP_EXPECT_CAR_HASH","c7f2b50cfe157592ab1e22e12f86b3c7f37bde1dc063c3c7e85282a12abdbbe1")
	OS.set_environment("TABLETOP_EXPECT_TRACK_HASH","6bc9ffcf97b5b0df39c6ea00bd72105825530328c2e9e6313494d4aa2d520375")
	super._enter_tree()

func select_test_course(course: String) -> bool:
	race.profile_menu.hide()
	return super.select_test_course(course)

func make_live_helper() -> Node:
	# Retain Mount Rainier's accepted banked-road sampling and 0.10 tolerance.
	if race.track_id == "mount_rainier": return preload("res://tests/probes/mount_rainier_live.gd").new()
	return super.make_live_helper()

func inspect_course() -> void:
	var root: Node3D = race.get_node("CourseEnvironment")
	var display: Node3D = root.get_node_or_null("BedroomDisplay")
	check(display != null,"bedroom_opt_in_loaded")
	if display == null: return
	check(display.find_children("*","CollisionObject3D",true,false).is_empty(),"display_has_no_collision")
	check(display.find_children("*","MeshInstance3D",true,false).is_empty(),"display_has_no_added_geometry")
	var source: Node3D = race.course.entry.environment.instantiate()
	check(DISPLAY.measured_visual_bounds(source).is_equal_approx(display.source_bounds),"source_transform_preserved")
	check(source.find_children("*","CollisionShape3D",true,false).size()==root.find_children("*","CollisionShape3D",true,false).size(),"source_collision_count_preserved")
	source.free()
	report("presentation",{"source_bounds":str(display.source_bounds),"background":race.get_node("Environment").environment.background_mode,"course_load":race.course.last_load_metrics})
	check(is_equal_approx(display.bedroom_environment.sky_custom_fov,65.0),"orthographic_sky_fov")
	for property: String in ["ambient_light_source","ambient_light_color","ambient_light_energy","tonemap_mode","ssao_enabled","ssao_radius","ssao_intensity"]:
		check(display.bedroom_environment.get(property)==display.original_environment.get(property),"preserved_"+property)
	var preview: Node3D = race.menu.get_node("Diorama").get_child(0).get_child(0)
	check(preview.get_node_or_null("CoursePropsPreview/BedroomDisplay") != null,"menu_preview_has_bedroom")
	race.menu_flow.show_step(3)
	await settle(8)
	save_frame("production_menu")
	await super.inspect_course()
	race.show_menu()
	race.menu.hide()
	race.get_node("HUD").hide()
	race.set_physics_process(false)
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = maxf(display.source_bounds.size.x,display.source_bounds.size.z)*1.25
	var centre: Vector3 = display.source_bounds.get_center()
	var extent: float = maxf(display.source_bounds.size.x,display.source_bounds.size.z)
	race.camera.position = centre+Vector3(0.65,1.1,0.75)*extent
	race.camera.far = extent*4.0
	race.camera.look_at(centre)
	await settle(4)
	save_frame("skybox_framing")
	for index: int in range(4):
		race.camera_driver.preview_elapsed = -1.0
		race.camera_driver.preview(race.camera,race.track,float(index)*race.track.total_length/28.0)
		# First preview call establishes the opening pose; tick again to reach the target.
		for step: int in range(120): race.camera_driver.preview(race.camera,race.track,float(index)*race.track.total_length/28.0+float(step)*0.016)
		await settle(3)
		save_frame("flyover_%d" % index)
	race.camera_driver.mode = 2
	race.camera_driver.reset(race.camera,race.player_car)
	await settle(4)
	save_frame("bedroom_close_chase")
	# Same rendered view, with and without presentation, measures its incremental cost.
	var samples: Array[Dictionary] = []
	for enabled: bool in [false,true]:
		display.visible = enabled
		display.environment_node.environment = display.bedroom_environment if enabled else display.original_environment
		await settle(20)
		var gaps: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for frame: int in range(120):
			await get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			gaps.append((now-previous)/1000.0)
			previous = now
		gaps.sort()
		samples.append({"enabled":enabled,"p50_ms":gaps[60],"p95_ms":gaps[114],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	report("presentation_cost",samples)
	check(samples[1].p95_ms <= maxf(samples[0].p95_ms*1.25,samples[0].p95_ms+4.0),"presentation_cost_bounded")
	race.camera_driver.mode = 0
	helper.race_view()
	race.set_physics_process(true)
	race.menu_flow.show_step(3)

func inspect_after_race() -> void:
	await super.inspect_after_race()
	var display: Node3D = race.get_node("CourseEnvironment/BedroomDisplay")
	check(race.get_node("Environment").environment==display.bedroom_environment,"bedroom_restored_after_switch")
	var original: Environment = display.original_environment
	check(race.course.select("game_table"),"final_switch_to_source")
	check(race.get_node("Environment").environment==original,"original_environment_restored")
	check(race.get_node("CourseEnvironment").get_node_or_null("BedroomDisplay")==null,"source_course_has_no_bedroom")
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
