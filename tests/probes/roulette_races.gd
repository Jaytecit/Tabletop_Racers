extends "res://tests/probes/m6_intro_races.gd"

func _init() -> void:
	course_id = "game_table"
	first_run = 3
	last_run = 3

func _process(_delta: float) -> void:
	if race != null and race.phase == 6:
		race.begin_countdown()
