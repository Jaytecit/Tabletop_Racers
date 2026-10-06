extends "res://tests/autopilot/probe_base.gd"

const BUTTONS: Array[String] = ["Quick","Trial","Freestyle","Tournament","Challenge","Elimination","TimeAttack","Drift"]
const MODES: Array[String] = ["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"]

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null: node.hardware_input_isolated = true)

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
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var flow: RefCounted = race.menu_flow
	var passed: bool = true
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size = dimensions
		flow.show_step(0)
		await settle(4)
		passed = passed and flow.mode_hint.text==flow.MODE_DESCRIPTIONS["quick"]
		for index: int in range(BUTTONS.size()):
			var choice: Button = flow.home.get_node(BUTTONS[index])
			choice.grab_focus()
			await settle(2)
			var keyboard_ok: bool = choice.has_focus() and flow.mode_hint.text==flow.MODE_DESCRIPTIONS[MODES[index]]
			flow.home.get_node(BUTTONS[(index+1)%BUTTONS.size()]).grab_focus()
			choice.mouse_entered.emit()
			await settle(2)
			var hover_ok: bool = choice.has_focus() and flow.mode_hint.text==flow.MODE_DESCRIPTIONS[MODES[index]]
			var fits: bool = flow.mode_hint.get_minimum_size().y<=48 and race.menu.get_global_rect().encloses(flow.mode_hint.get_global_rect())
			passed = passed and keyboard_ok and hover_ok and fits
			report("%d_%s" % [dimensions.x,MODES[index]],{"focus":keyboard_ok,"hover":hover_ok,"fits":fits,"text":flow.mode_hint.text})
			if dimensions.x==1280: save_frame(MODES[index])
		passed = passed and race.menu.get_node_or_null("FlowTrail")==null
		flow.show_step(1)
		await settle(2)
		flow.go_back()
		await settle(3)
		passed = passed and flow.mode_hint.text==flow.MODE_DESCRIPTIONS["quick"]
	report("passed",passed)
	finish()
