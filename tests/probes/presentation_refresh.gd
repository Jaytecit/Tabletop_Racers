extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, title: String) -> void:
	if not value: failures.append(title)
	print(("PASS " if value else "FAIL ")+title)
func frames(count: int) -> void:
	for index: int in range(count): await physics_frame
func run() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	var race: Node = app.get_node("Race")
	race.profile.path = "user://presentation_verify_profile.json"
	race.profile.read_only = true
	race.set_meta("controls_config_path","user://presentation_verify_controls.cfg")
	root.add_child(app)
	await frames(3)
	var controls: Node = race.controls_setup
	check(not race.get_node("HUD/Footer").visible,"controls footer removed")
	check(race.get_node("HUD/Top").size==Vector2(270,68),"compact HUD dimensions")
	for card: Button in race.garage.cards:
		var caption: Label = card.get_node("DriverCaption")
		check(absf(caption.position.x+caption.size.x*0.5-76.5)<1,"portrait caption centred")
	controls.open()
	await frames(2)
	check(controls.panel.visible and controls.mask.visible,"controls setup opens with modal mask")
	check(race.menu.get_node("Start").focus_mode==Control.FOCUS_NONE,"modal focus stays in setup")
	controls.waiting = "boost"
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_Q
	key.pressed = true
	controls._input(key)
	check(InputMap.action_get_events("boost")[0].keycode==KEY_Q,"keyboard remapping")
	var saved: ConfigFile = ConfigFile.new()
	check(saved.load(controls.config_path)==OK and saved.get_value("keyboard","boost")==KEY_Q,"binding persisted")
	controls.waiting = "boost"
	key.keycode = KEY_W
	controls._input(key)
	check(InputMap.action_get_events("boost")[0].keycode==KEY_Q,"duplicate keyboard binding rejected")
	controls.restore_defaults()
	check(InputMap.action_get_events("boost")[0].keycode==KEY_SPACE,"restore default bindings")
	controls.close_setup()
	race.start_race()
	await frames(1)
	var before: Vector3 = race.player_car.position
	var camera_before: Vector3 = race.camera.position
	await frames(120)
	check(race.phase==6 and race.race_time==0.0,"preview waits without starting timer")
	check(race.player_car.position.is_equal_approx(before),"preview holds cars on grid")
	check(race.camera.position.distance_to(camera_before)>1.0,"course camera orbits")
	Input.action_press("ui_accept")
	await frames(2)
	Input.action_release("ui_accept")
	check(race.phase==1,"select input starts countdown")
	await frames(190)
	check(race.phase==2 and race.race_time>0.0,"countdown reaches racing")
	check(is_equal_approx(race.camera.size,14.0),"driving camera restored")
	race.toggle_pause()
	var clock: float = race.race_time
	await frames(10)
	check(race.race_time==clock,"pause freezes race timer")
	race.show_menu()
	check(race.phase==0 and race.menu.visible,"menu return resets preview/race")
	check(race.player_car.visual.has_node("RollCage"),"buggy roll cage present")
	for id: String in ["felt_sprint","card_bridge"]:
		check(race.course.select(id),id+" loads")
		race.start_race()
		await frames(3)
		check(race.phase==6 and race.camera.size>14.0,id+" pulled-out preview")
		check_cards(race.get_node("CourseEnvironment"))
		check_cards(race.track)
		race.show_menu()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(controls.config_path))
	print("PRESENTATION_CHECK "+("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)

func check_cards(node: Node) -> void:
	if node.has_node("PaperEdge") and node.has_node("PrintedFace"):
		check(node.get_node("PrintedFace").mesh.size.is_equal_approx(Vector2(2.4,3.36)),"consistent deck scale")
	for child: Node in node.get_children(): check_cards(child)
