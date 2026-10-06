extends "res://tests/autopilot/probe_base.gd"

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null:
			node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
			node.profile.read_only = true
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null:
			node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	var opening: Node = get_tree().current_scene.get_node_or_null("Opening")
	if opening!=null: opening.queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var flow: RefCounted = race.menu_flow
	var passed: bool = true
	for mode: String in ["quick","trial","freestyle","challenge","elimination","time_attack","drift","tournament"]:
		flow.choose_mode(mode)
		for frame: int in range(1800):
			await settle(1)
			if not race.course.loading: break
		var driver_step: bool = flow.step==1 and not race.controls_setup.launch.visible
		race.garage.cards[2].grab_focus()
		await press("ui_accept",80)
		await settle(4)
		var expected: int = 2 if mode=="freestyle" else 3
		var auto_advance: bool = flow.step==expected and race.garage.selected==2 and not race.controls_setup.launch.is_visible_in_tree()
		if mode=="freestyle":
			race.menu.get_node("NextVehicle").pressed.emit()
			await settle(2)
			auto_advance = auto_advance and flow.step==2 and flow.next_vehicle.visible
			save_frame("freestyle_vehicle")
			flow.next.pressed.emit()
			await settle(3)
			auto_advance = auto_advance and flow.step==3
		flow.back.pressed.emit()
		await settle(3)
		var back_path: bool = flow.step==(2 if mode=="freestyle" else 1)
		if mode=="freestyle": flow.back.pressed.emit()
		await settle(2)
		flow.back.pressed.emit()
		await settle(3)
		var home_setup: bool = flow.step==0 and race.controls_setup.launch.is_visible_in_tree()
		var check: bool = driver_step and auto_advance and back_path and home_setup and not race.course.loading and race.course.error.is_empty()
		report(mode,{"passed":check,"driver":driver_step,"automatic":auto_advance,"back":back_path,"home_setup":home_setup})
		passed = passed and check
	flow.show_step(0)
	race.controls_setup.launch.pressed.emit()
	await settle(3)
	var setup_works: bool = race.setup_menu.panel.visible
	save_frame("main_menu_setup")
	race.setup_menu.close()
	await settle(3)
	var no_gold: bool = race.find_children("GoldLivery","",true,false).is_empty()
	report("setup_works",setup_works)
	report("no_gold_buttons",no_gold)
	flow.choose_mode("quick")
	race.garage.cards[0].pressed.emit()
	await settle(4)
	save_frame("standard_course")
	report("passed",passed and setup_works and no_gold and flow.step==3)
	finish()
