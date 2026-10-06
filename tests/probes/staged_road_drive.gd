extends "res://tests/probes/staged_road_verification.gd"
# Repeat driving/profiling after the separate geometry/control gate has passed.
func inspect_course() -> void:
	pass

func inspect_after_race() -> void:
	for car: CharacterBody3D in race.cars:
		check(car.crashes==0 and car.ai_driver.recoveries==0 and race.session.progress.records[car.player].penalty==0.0,"clean_race_"+str(car.player))
	race.show_menu()
	await settle(8)
	check(race.phase==0 and race.menu.visible,"return_to_menu")
