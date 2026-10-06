extends "res://tests/probes/course_loading_verification.gd"
var candidate: RefCounted = preload("res://tests/fixtures/bazaar_loading_selection.gd").new()

func _enter_tree() -> void:
	super._enter_tree()
	var error: Error = candidate.prepare()
	assert(error == OK, "Candidate catalogue compilation failed")
	report("candidate_catalogue",candidate.receipt)
	get_tree().node_added.connect(candidate.attach)
