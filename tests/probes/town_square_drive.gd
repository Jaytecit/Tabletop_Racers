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

func inspect_course() -> void:
	pass

func inspect_after_race() -> void:
	for car: CharacterBody3D in race.cars:
		check(car.crashes==0 and car.ai_driver.recoveries==0 and race.session.progress.records[car.player].penalty==0.0,"clean_race_"+str(car.player))
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
