extends "res://tests/probes/m6_intro_races.gd"
func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--course="): course_id = argument.trim_prefix("--course=")
