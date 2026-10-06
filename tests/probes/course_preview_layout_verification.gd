extends "res://tests/probes/mode_menu_verification.gd"

func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"read_only")
	for course: String in ["mount_rainier","toys_r_you","game_table"]:
		race.menu_flow.choose_mode("quick")
		check(race.course.select(course),"select_"+course)
		for mode: String in MODES:
			# Use the normal selection flow, including mode-dependent Start text.
			race.menu_flow.choose_mode(mode)
			while race.course.loading: await get_tree().process_frame
			# Tournament chooses its first round and Drift chooses an eligible road.
			# Restore the requested preview for every mode with free course selection.
			if mode not in ["tournament","drift"]:
				check(race.course.select(course),course+"_"+mode+"_selected")
			race.menu_flow.show_step(3)
			await settle(4)
			var start: Button = race.menu.get_node("Start")
			var selector: OptionButton = race.menu.get_node("TrackSelect")
			check(absf(start.get_global_rect().get_center().x-selector.get_global_rect().get_center().x)<0.01,course+"_"+mode+"_centred")
			check(start.get_global_rect().position.y>race.menu.get_node("CourseInfo").get_global_rect().end.y,course+"_"+mode+"_below_info")
			inspect_layout(course+"_"+mode)
			check(race.garage.preview_car==null,course+"_"+mode+"_no_preview_vehicle")
			var world: Node3D = race.menu.get_node("Diorama").get_child(0).get_child(0)
			check(world.find_children("DriverNumber","Label3D",true,false).is_empty(),course+"_"+mode+"_no_driver_label")
			check(world.get_node("PreviewCamera").size<5.5,course+"_"+mode+"_close_section")
			if mode=="elimination": save_frame(course+"_elimination")
			if mode=="tournament": race.profile.data.tournament = {}
	# Reproduce the supplied course/mode at three display sizes and both filters.
	race.menu_flow.choose_mode("elimination")
	check(race.course.select("mount_rainier"),"restore_rainier")
	race.menu_flow.show_step(3)
	for dimensions: Vector2i in [Vector2i(960,640),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size = dimensions
		for pixelation: bool in [false,true]:
			race.get_node("Retro").visible = pixelation
			await settle(5)
			inspect_layout(str(dimensions)+"_"+str(pixelation))
			save_frame("rainier_%dx%d_%s" % [dimensions.x,dimensions.y,str(pixelation)])
		report("start_"+str(dimensions),{"position":str(race.menu.get_node("Start").position),"size":str(race.menu.get_node("Start").size)})
	race.menu.get_node("Start").pressed.emit()
	check(race.phase==6 and race.race_mode=="elimination","start_elimination")
	race.show_menu()
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
