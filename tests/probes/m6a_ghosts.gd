extends "res://tests/probes/m6_course_ghosts.gd"
func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--course="): secondary_course = argument.trim_prefix("--course=")
