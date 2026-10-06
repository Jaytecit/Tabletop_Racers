extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	await super._ready()
	await settle(3)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	report("controller_before_isolation",race.controller.diagnostic_state())
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/toys_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	helper.start_test(1,1)
	helper.player_control()
	for i: int in range(250): await get_tree().physics_frame
	var before: Vector3 = race.player_car.position
	var before_frame: int = Engine.get_physics_frames()
	Input.action_press("p1_go")
	Input.action_press("boost")
	for i: int in range(45): await get_tree().physics_frame
	Input.action_release("boost")
	Input.action_release("p1_go")
	report("input",{"before":str(before),"after":str(race.player_car.position),"before_frame":before_frame,"after_frame":Engine.get_physics_frames(),"moved":race.player_car.position.distance_to(before)>1.0,"boost":race.player_car.boost,"boost_used":race.player_car.boost<95.0})
	save_frame("boost")
	Input.action_press("reset_car")
	for i: int in range(2): await get_tree().physics_frame
	Input.action_release("reset_car")
	for i: int in range(210): await get_tree().physics_frame
	report("recovery",{"state":race.player_car.state,"supported":not race.player_car.physical_support(race.player_car.position).is_empty()})
	report("passed",_reports.input.moved and _reports.input.boost_used and _reports.recovery.state==0 and _reports.recovery.supported)
	finish()
