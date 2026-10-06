extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null: node.hardware_input_isolated = true)

func check(value: bool, title: String) -> void:
	if not value: failures.append(title)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var flow: RefCounted = race.menu_flow
	flow.show_step(0)
	await settle(3)
	flow.home.get_node("Quick").grab_focus()
	await settle(2)
	var logo: Control = race.menu.get_node("BrandLogo")
	check(absf(logo.position.x+logo.size.x/2.0-race.menu.size.x/2.0)<1.0,"logo_centred")
	check(logo.position.y>=24.0,"logo_top_padding")
	for child: Node in flow.home.get_children():
		if child is Button:
			check(child.size.x<=270 and child.size.y<=48,"compact_"+child.name)
	check(flow.home.get_node("Quick").get_theme_color("font_focus_color")==flow.SKIN.INK,"selected_text_contrast")
	save_frame("00_home")
	for dimensions: Vector2i in [Vector2i(960,640),Vector2i(1600,900)]:
		DisplayServer.window_set_size(dimensions)
		await settle(3)
		for page: int in range(4):
			flow.show_step(page)
			await settle(3)
			check(race.menu.get_global_rect().end.y<=800,"menu_canvas_bounds")
			save_frame("menu_%d_%d" % [dimensions.x,page])
	DisplayServer.window_set_size(Vector2i(1200,800))
	flow.show_step(0)
	race.menu.get_node("AssetCredits").pressed.emit()
	await settle(3)
	save_frame("credits")
	for node: Node in race.get_children():
		if node is AcceptDialog: node.hide()
	flow.choose_mode("quick")
	flow.show_step(3)
	await settle(3)
	var choice: OptionButton = race.menu.get_node("QuickRace/Difficulty")
	choice.get_popup().popup(Rect2i(80,540,220,160))
	await settle(3)
	save_frame("dropdown")
	choice.get_popup().hide()
	race.start_race()
	await settle(4)
	race.begin_countdown()
	await settle(3)
	save_frame("countdown")
	race.toggle_pause()
	await settle(3)
	check(race.paused_race,"pause_open")
	check(race.banner.get_minimum_size().y<=race.banner.size.y,"pause_text_fits")
	save_frame("paused")
	race.toggle_pause()
	race.session.change_phase(2)
	await settle(3)
	save_frame("race_hud")
	race.session.change_phase(3)
	var rows: Array = []
	for i: int in range(4): rows.append({"rank":i+1,"player":i+1,"finished":true,"time":88.52+i*1.45,"laps":3,"penalty":0.0})
	race.on_results_ready(rows)
	await settle(25)
	check(race.banner.get_minimum_size().y<=race.banner.size.y,"results_text_fits")
	save_frame("results")
	race.results_panel.get_node("Menu").pressed.emit()
	await settle(3)
	check(flow.step==0 and race.menu.visible,"return_home")
	check(race.profile.read_only,"profile_read_only")
	report("failures",failures)
	report("passed",failures.is_empty())
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle_physics(10)
	finish()
