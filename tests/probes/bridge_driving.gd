extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(2)
	var race: Node = get_tree().current_scene.get_node("Race")
	# Preserve the relocated table support while isolating casino decoration.
	race.camera_driver.clear()
	var casino: Node = race.get_node("CourseEnvironment/BlackjackEnvironment")
	casino.free()
	# Engineering circuit: isolate the new route from Game Table prop collisions.
	for child: Node in race.get_children():
		if child.name in ["Track","CourseEnvironment","Car1","Car2","Car3","Car4","Controller","Camera","HUD","Engine","Skid","RaceSession"]: continue
		if child is Node3D:
			race.remove_child(child)
			child.queue_free()
	race.track.definition = load("res://tracks/bridge_probe/definition.tres")
	race.track.build()
	race.track.rebuild_art()
	race.player_car.ai = true
	race.start_race()
	var seen_upper: bool = false
	var seen_lower: bool = false
	for i: int in range(4600):
		await get_tree().physics_frame
		if race.player_car.state==0:
			var data: Dictionary = race.track.at(race.player_car.station)
			if data.layer==1 and race.player_car.position.y>2.3: seen_upper = true
			if data.layer==0 and race.player_car.position.y<0.1: seen_lower = true
		if race.phase==3: break
	report("state",race.diagnostic_state())
	report("both_layers_driven",seen_upper and seen_lower)
	report("results",race.session.results.duplicate(true))
	report("passed",race.phase==3 and race.player_car.laps==3 and race.session.results.size()==4 and seen_upper and seen_lower)
	await settle(2)
	save_frame("bridge_results")
	finish()
