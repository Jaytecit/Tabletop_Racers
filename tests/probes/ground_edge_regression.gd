extends "res://tests/autopilot/probe_base.gd"

func _ready() -> void:
	await super._ready()
	await settle(3)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var opening: Node = app.get_node_or_null("Opening/Sequence")
	if opening!=null:
		opening.hardware_input_isolated = true
		opening._restore_menu()
		opening.get_parent().queue_free()
	get_tree().paused = false
	var cases: Array = []
	var passed: bool = true
	for id: String in ["toys_r_you","game_table"]:
		var selected: bool = race.course.select(id)
		race.set_physics_process(false)
		for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
		await settle_physics(3)
		var checks: int = 0
		var failures: int = 0
		for i: int in range(race.track.starts.size()):
			if id=="toys_r_you" and race.track.at(race.track.lengths[i]).layer==0: continue
			if id=="game_table" and i%24!=0: continue
			var edges: PackedVector3Array = race.track.road_edges(i)
			for fraction: float in [0.05,0.5,0.95]:
				var p: Vector3 = edges[0].lerp(edges[1],fraction)
				var support: Dictionary = race.player_car.physical_support(p+Vector3.UP*0.03)
				checks += 1
				if support.is_empty() or support.collider.get_meta("supported_terrain",false): failures += 1
		cases.append({"course":id,"selected":selected,"checks":checks,"failures":failures})
		passed = passed and selected and checks>0 and failures==0
	report("courses",cases)
	report("passed",passed)
	race.set_physics_process(false)
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")
