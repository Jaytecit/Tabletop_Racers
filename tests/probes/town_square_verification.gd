extends "res://tests/probes/staged_road_verification.gd"
var candidate: RefCounted = preload("res://tests/fixtures/town_square_selection.gd").new()

func _enter_tree() -> void:
	var uid: int = ResourceUID.text_to_id("uid://144hv5b6kwah")
	if ResourceUID.has_id(uid): ResourceUID.set_id(uid,"res://showcase_track.gd")
	else: ResourceUID.add_id(uid,"res://showcase_track.gd")
	super._enter_tree()
	assert(candidate.prepare()==OK)
	get_tree().node_added.connect(candidate.attach)

func select_test_course(course: String) -> bool:
	var vehicle: String = race.course.CATALOG.assigned_vehicle(course)
	var freestyle: bool = race.race_mode=="freestyle"
	if freestyle: vehicle = race.player_car.base_tuning.id
	var staged: Dictionary = race.course.CATALOG.validate_entry(load("res://tracks/%s/entry.tres" % course),course,vehicle,freestyle)
	return race.course.select(course,vehicle,staged)

func inspect_after_race() -> void:
	await super.inspect_after_race()
	var inspector: Node = preload("res://tests/probes/toys_flags_verification.gd").new()
	check(race.course.select("game_table"),"procedural_regression_selected")
	await settle_physics(4)
	inspector.procedural_checks(race)
	check(inspector.failures.is_empty(),"procedural_geometry_preserved")
	report("procedural_regression",inspector._reports)
	inspector.free()
	var toys: Dictionary = preload("res://tests/probes/toys_alignment_checks.gd").check(load("res://tracks/toys_r_you/definition.tres"))
	report("toys_alignment",toys)
	check(toys.get("failures",[]).is_empty() and toys.get("errors",[]).is_empty(),"canonical_toys_preserved")
	check(select_test_course("town_square"),"return_to_town_square")
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
