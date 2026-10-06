extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	report(label,value)
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	check(race.profile.read_only and race.profile_directory.read_only,"read_only_profiles")
	race.machine_settings.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening/Sequence").hardware_input_isolated = true
	app.get_node("Opening/Sequence")._restore_menu()
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_selected = true
	race.show_menu()
	race.course.select("game_table")
	while race.course.loading: await get_tree().process_frame
	race.set_vehicle("buggy")
	race.profile_menu.open()
	race.profile_menu.create()
	check(race.profile_menu.portraits.size()==8,"eight_profile_choices")
	for i: int in range(8):
		race.profile_menu.portraits[i].pressed.emit()
		check(race.profile_menu.selected_portrait==i,"select_portrait_%d"%i)
		var raw: Dictionary = preload("res://scripts/profile_store.gd").defaults()
		raw.identity.portrait_id = i
		check(preload("res://scripts/profile_store.gd").validate(raw).identity.portrait_id==i,"portrait_roundtrip_%d"%i)
		race.profile.data.identity.portrait_id = i
		race.identities.refresh_identity()
		var ids: Array[int] = []
		for slot: int in range(4): ids.append(race.identities.portrait_for_slot(slot))
		check(ids.size()==4 and ids[0]==i and ids[1]!=i and ids[2]!=i and ids[3]!=i and ids[1]!=ids[2] and ids[2]!=ids[3] and ids[1]!=ids[3],"unique_racers_%d"%i)
		if i>=4: check(preload("res://scripts/vehicles/player_stats.gd").portrait_starting(i)==preload("res://scripts/vehicles/player_stats.gd").portrait_starting(i-4),"reused_stats_%d"%i)
	await settle(3)
	save_frame("eight_profile_choices")
	# Writable fixtures stay inside the disposable evidence directory.
	var directory: RefCounted = preload("res://scripts/profiles/profile_directory.gd").new()
	directory.root = summer_out_dir.path_join("profile-fixtures")
	directory.legacy_path = summer_out_dir.path_join("absent-legacy.json")
	directory.load_directory()
	for i: int in range(4,8):
		var created: Dictionary = directory.create_profile(["Nova","Ravi","Skye","Milo"][i-4],i)
		check(created.get("error",ERR_BUG)==OK,"create_new_profile_%d"%i)
		if created.get("error",ERR_BUG)==OK:
			var reader: RefCounted = preload("res://scripts/profile_store.gd").new()
			reader.path = directory.payload_path(created.id)
			reader.load_profile()
			check(reader.data.identity.portrait_id==i and reader.data.quick_race.driver==i%4,"reload_new_profile_%d"%i)
	check(not directory.validate(directory.index).is_empty(),"valid_new_directory")
	race.profile_menu.hide()
	race.set_physics_process(false)
	for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(false)
	race.session.change_phase(2)
	race.paused_race = false
	var car: CharacterBody3D = race.player_car
	car.reset_car(10.0,0.0)
	var light_script: Script = preload("res://scripts/race/race_lighting.gd")
	light_script.set_lamps(race,true)
	for selected: int in [0,1,2,3]:
		race.garage.select(race,selected)
		var lamp: OmniLight3D = car.get_node("VehicleLamps/TaillightL")
		check(lamp.light_color.is_equal_approx(car.get_meta("vehicle_colour")) and lamp.light_energy<0.25,"dim_paint_light_%d"%selected)
	car.set_brake_lights(false)
	var off: float = car.visual.get_node("TailA").material_override.emission_energy_multiplier
	car.set_brake_lights(true)
	check(car.visual.get_node("TailA").material_override.emission_energy_multiplier>off*10.0,"brake_glow")
	check(is_equal_approx(car.get_node("Collision").shape.size.x,car.tuning.collision_size.x*0.94),"tight_collision")
	# Dedicated flat wall away from the course; real move_and_slide contacts.
	var wall: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20,2,0.2)
	collider.shape = shape
	wall.add_child(collider)
	race.add_child(wall)
	wall.position = Vector3(0,4,80)
	var observations: Array = []
	for glancing: bool in [true,false]:
		car.state = 0
		car.immunity = 0
		car.collision_mask = 1
		car.position = Vector3(-3,3.5,79.55)
		car.heading = 0
		car.rotation = Vector3.ZERO
		car.surface_normal = Vector3.UP
		car.align_class_collision()
		car.velocity = Vector3(9,0,3) if glancing else Vector3(0,0,9)
		await get_tree().physics_frame
		var before: Vector3 = car.velocity
		car.move_and_slide()
		# Contact response is factored into the same helper used by driving.
		for frame: int in range(12):
			if car.get_slide_collision_count()>0: break
			car.velocity = before
			car.move_and_slide()
		check(car.get_slide_collision_count()>0,"contact_%s"%glancing)
		if car.get_slide_collision_count()>0:
			var hit: KinematicCollision3D = car.get_slide_collision(0)
			car.resolve_impact(before,hit)
			check(car.velocity.x>8.0 if glancing else car.velocity.z<0.0,"deflection_%s"%glancing)
			check(car.visual_motion.impact_roll!=0.0,"impact_animation_%s"%glancing)
		observations.append({"glancing":glancing,"velocity":str(car.velocity),"position":str(car.position)})
	car.reset_car(10.0,0.0)
	race.session.progress.reset(race.all_cars,race.track.total_length)
	var origin: Vector3 = car.position
	car.crash(false)
	car.recover(0.15)
	check(car.position.is_equal_approx(origin) and car.visual.scale.x<1.0,"recovery_stationary_departure")
	car.recover(0.3)
	check(car.state==3 and not car.visual.visible,"recovery_hidden_transfer")
	car.recover(0.2)
	check(car.position.is_equal_approx(car.safe_position) and car.visual.visible,"recovery_at_anchor")
	car.recover(2.0)
	check(car.state==0 and car.visual.scale.is_equal_approx(Vector3.ONE),"recovery_complete")
	# A scenery box occupying the proposed landing must reject that anchor.
	wall.position = car.safe_position+Vector3.UP*0.4
	await get_tree().physics_frame
	check(not preload("res://scripts/race/race_recovery.gd").clear_anchor(car,car.safe_position,car.safe_heading),"blocked_anchor_rejected")
	wall.queue_free()
	await settle(3)
	save_frame("vehicle_brake_and_recovery")
	report("observations",observations)
	report("failures",failures)
	report("passed",failures.is_empty())
	race.session.change_phase(0)
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
		voice.stream = null
	await settle(3)
	finish()
