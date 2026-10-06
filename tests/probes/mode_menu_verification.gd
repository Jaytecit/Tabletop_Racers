extends "res://tests/probes/race_quality_ai_verification.gd"
const MODES: Array[String] = ["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"]
const BUTTONS: Array[String] = ["Quick","Trial","Freestyle","Tournament","Challenge","Elimination","TimeAttack","Drift"]

func inspect_layout(tag: String) -> void:
	var buttons: Array[Control] = []
	for node: Node in race.menu.find_children("*","BaseButton",true,false):
		if node.is_visible_in_tree(): buttons.append(node)
	for index: int in range(buttons.size()):
		var button: Control = buttons[index]
		check(race.menu.get_global_rect().encloses(button.get_global_rect()),tag+"_bounds_"+str(button.name))
		for other: int in range(index+1,buttons.size()):
			check(not button.get_global_rect().intersects(buttons[other].get_global_rect()),tag+"_spacing_"+str(button.name)+"_"+str(buttons[other].name))
	if race.menu_flow.step==3:
		for path: String in ["CourseInfo","Record"]:
			check(race.menu.get_node(path).get_global_rect().end.y<=race.menu.get_node("Start").get_global_rect().position.y,tag+"_text_clear_"+path)

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
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"read_only")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,720)]:
		get_window().size = dimensions
		await settle(5)
		race.menu_flow.show_step(0)
		await settle(4)
		inspect_layout(str(dimensions)+"_home")
		save_frame("home_%dx%d" % [dimensions.x,dimensions.y])
		for index: int in range(MODES.size()):
			race.menu_flow.home.get_node(BUTTONS[index]).pressed.emit()
			while race.course.loading: await get_tree().process_frame
			check(race.race_mode==MODES[index],"select_"+MODES[index])
			for page: int in range(1,4):
				race.menu_flow.show_step(page)
				await settle(3)
				inspect_layout(str(dimensions)+"_"+MODES[index]+"_"+str(page))
			if dimensions==Vector2i(1280,720): save_frame("course_"+MODES[index])
			race.start_race()
			check(race.phase==6,"start_"+MODES[index])
			if MODES[index] in ["trial","challenge","time_attack","drift"]: check(race.cars.size()==1,"solo_"+MODES[index])
			if MODES[index]=="drift": check(race.player_car.base_tuning.id=="drift_car","drift_class")
			race.show_menu()
			if MODES[index]=="tournament": race.profile.data.tournament = {}
	race.menu_flow.choose_mode("challenge")
	check(race.course.select("game_table"),"long_description_course")
	race.menu_flow.show_step(3)
	await settle(4)
	inspect_layout("long_description")
	save_frame("long_description")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
