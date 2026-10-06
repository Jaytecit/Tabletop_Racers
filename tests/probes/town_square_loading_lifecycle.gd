extends "res://tests/probes/course_loading_verification.gd"
var candidate: RefCounted = preload("res://tests/fixtures/town_square_selection.gd").new()

func _enter_tree() -> void:
	var uid: int = ResourceUID.text_to_id("uid://144hv5b6kwah")
	if ResourceUID.has_id(uid): ResourceUID.set_id(uid,"res://showcase_track.gd")
	else: ResourceUID.add_id(uid,"res://showcase_track.gd")
	super._enter_tree()
	var error: Error = candidate.prepare()
	assert(error == OK, "Candidate catalogue compilation failed")
	report("candidate_catalogue",candidate.receipt)
	get_tree().node_added.connect(candidate.attach)
