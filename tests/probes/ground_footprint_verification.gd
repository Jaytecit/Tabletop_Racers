extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.profile_selected = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var opening: Node = app.get_node_or_null("Opening")
	if opening!=null: opening.queue_free()
	get_tree().paused = false
	var selected: bool = race.course.select("mount_rainier")
	race.show_menu()
	race.set_physics_process(false)
	race.set_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	await settle_physics(4)
	var car: CharacterBody3D = race.player_car
	var cases: Array = []
	var passed: bool = selected
	for point: Vector3 in [Vector3(68.26649,5.879245,92.55347),Vector3(69.60031,5.889303,92.0068)]:
		var surface: Dictionary = race.track.project_3d(point)
		car.heading = race.track.direction(surface.station).angle()
		var centre: Dictionary = car.physical_support(point)
		var contact: Dictionary = car.driving_support(point,surface)
		var ok: bool = centre.is_empty() and not contact.is_empty() and contact.get("footprint",false) and absf(contact.position.y-point.y)<0.02
		cases.append({"point":str(point),"centre_missing":centre.is_empty(),"contact":str(contact.position) if not contact.is_empty() else "missing","passed":ok})
		passed = passed and ok
		for edge: String in ["raised","guarded"]:
			var exposed: Dictionary = surface.duplicate()
			exposed.edge = edge
			var rejected: bool = car.driving_support(point,exposed).is_empty()
			passed = passed and rejected
			cases.append({"edge":edge,"rejected":rejected})
		var missing: Vector3 = Vector3(400,point.y,400)
		passed = passed and car.driving_support(missing,surface).is_empty()
	report("cases",cases)
	var helper: Node = load("res://tests/probes/mount_rainier_live.gd").new()
	race.add_child(helper)
	var support: Dictionary = helper.support_report()
	var gates: Dictionary = helper.gate_checks()
	var alignment: Dictionary = load("res://tests/probes/mount_rainier_alignment_checks.gd").check(load("res://tracks/mount_rainier/definition.tres"))
	report("support",support)
	report("gates",gates)
	report("alignment",alignment)
	passed = passed and support.failures.is_empty() and gates.failures.is_empty() and alignment.failures.is_empty()
	race.menu.hide()
	race.get_node("HUD").hide()
	car.position = Vector3(69.60031,5.889303,92.0068)
	car.show()
	race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	race.camera.position = car.position+Vector3(0,15,0.1)
	race.camera.look_at(race.to_global(car.position),Vector3.UP)
	await settle(3)
	save_frame("shoulder_contact")
	report("passed",passed)
	race.show_menu()
	race.set_physics_process(false)
	for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(false)
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")
