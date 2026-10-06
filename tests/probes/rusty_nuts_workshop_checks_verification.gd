extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	await super._ready()
	await settle(4)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/rusty_nuts_workshop_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	await settle_physics(5)
	report("support",helper.support_report())
	report("gates",helper.gate_checks())
	report("passed",_reports.support.failures.is_empty() and _reports.gates.failures.is_empty())
	finish()
