extends "res://tests/probes/scenery_coverage.gd"
func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--course="): course_id = argument.trim_prefix("--course=")
