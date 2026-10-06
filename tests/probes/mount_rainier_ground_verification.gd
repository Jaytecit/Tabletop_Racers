extends "res://tests/autopilot/probe_base.gd"
const GROUND: Array[String] = ["env_rock02_grass_0","env.003_soil_grass_0","env.007_rock04_soil_0","env.011_rock02_soil_0","env_assets.007_soil_0"]

func clear_drive_path(race: Node3D, point: Vector3, station: float) -> bool:
	var direction: Vector2 = race.track.direction(station)
	var forward: Vector3 = Vector3(direction.x,0,direction.y)
	for offset: float in [-7.0,-4.0,-2.0,2.0,4.0,7.0]:
		var hit: Dictionary = race.player_car.physical_support(point+forward*offset)
		if hit.is_empty() or absf(hit.position.y-point.y)>0.18: return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(race.to_global(point-forward*7.0+Vector3.UP*0.25),race.to_global(point+forward*7.0+Vector3.UP*0.25),1)
	return race.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.profile_selected = true # Disposable read-only identity only.
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
	report("selected",race.course.select("mount_rainier"))
	race.show_menu()
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	await settle_physics(3)
	var regions: Dictionary = {}
	var samples: Array = []
	var drives: Dictionary = {}
	for mesh: MeshInstance3D in race.find_children("*","MeshInstance3D",true,false):
		var source: String = mesh.get_meta("source_mesh_name","")
		if source not in GROUND: continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var region: Dictionary = {"checks":0,"supported":0,"covered_by_higher_terrain":0,"missing":[]}
		for i: int in range(0,faces.size(),3):
			var a: Vector3 = race.to_local(mesh.to_global(faces[i]))
			var b: Vector3 = race.to_local(mesh.to_global(faces[i+1]))
			var c: Vector3 = race.to_local(mesh.to_global(faces[i+2]))
			var normal: Vector3 = (b-a).cross(c-a).normalized()
			if absf(normal.y)<0.7: continue
			var point: Vector3 = (a+b+c)/3.0
			var route: Dictionary = race.track.project_3d(point)
			if route.supported or route.distance>18.0 or absf(route.position.y-point.y)>0.8: continue
			var hit: Dictionary = race.player_car.physical_support(point+Vector3.UP*0.03)
			# Overlapping terrain triangles are visible only at their upper surface.
			var supported: bool = not hit.is_empty() and hit.position.y>=point.y-0.12
			if supported and hit.position.y>point.y+0.12: region.covered_by_higher_terrain += 1
			region.checks += 1
			if supported: region.supported += 1
			else: region.missing.append({"point":[point.x,point.y,point.z],"road_distance":route.distance,"collider":str(hit.collider.name) if not hit.is_empty() else "missing","height":hit.position.y if not hit.is_empty() else -999})
			if supported and samples.size()<30: samples.append(point)
			if supported and not drives.has(source) and absf(route.position.y-point.y)<0.6 and hit.normal.y>0.9 and clear_drive_path(race,point,route.station):
				drives[source] = {"point":point,"station":route.station}
		regions[source] = region
	report("regions",regions)
	var all_supported: bool = regions.size()==GROUND.size()
	for region: Dictionary in regions.values(): all_supported = all_supported and region.checks>0 and region.missing.is_empty()
	report("ground_support",all_supported)
	var helper: Node = preload("res://tests/probes/mount_rainier_live.gd").new()
	race.add_child(helper)
	var road_support: Dictionary = helper.support_report()
	var gates: Dictionary = helper.gate_checks()
	report("road_support",road_support)
	report("gates",gates)
	var drive_results: Array = []
	race.session.change_phase(race.session.Phase.RACING)
	var car: CharacterBody3D = race.player_car
	for source: String in drives:
		var sample: Dictionary = drives[source]
		for ai: bool in [false,true]:
			for speed: float in [1.0,car.top_speed*1.2]:
				for direction: float in [-1.0,1.0]:
					car.reset_car(sample.station,0.0)
					car.remove_meta("last_support_failure")
					car.position = sample.point
					car.previous_ground = car.position.y
					car.heading += PI if direction<0 else 0.0
					car.ai = ai
					var forward: Vector2 = Vector2.RIGHT.rotated(car.heading)
					car.velocity = Vector3(forward.x*speed,0,forward.y*speed)
					Input.action_press("p1_go")
					Input.action_press("boost")
					car.set_physics_process(true)
					await settle_physics(1)
					var no_boost: bool = is_equal_approx(car.boost,100.0)
					var slowed: bool = Vector2(car.velocity.x,car.velocity.z).length()<=maxf(car.top_speed*0.5,speed)+0.01
					await settle_physics(20)
					car.set_physics_process(false)
					Input.action_release("p1_go")
					Input.action_release("boost")
					var support: Dictionary = car.physical_support(car.position)
					var passed: bool = car.crashes==0 and car.position.is_finite() and not support.is_empty() and slowed and (ai or no_boost)
					drive_results.append({"source":source,"point":str(sample.point),"end":str(car.position),"collider":str(support.collider.name) if not support.is_empty() else "missing","failure":car.get_meta("last_support_failure",{}),"state":car.state,"ai":ai,"speed":speed,"direction":direction,"crashes":car.crashes,"supported":not support.is_empty(),"no_boost":no_boost,"slowed":slowed,"passed":passed})
	report("drive_regions",drives.keys())
	report("drives",drive_results)
	var driving_passed: bool = drives.size()==GROUND.size()
	for drive: Dictionary in drive_results: driving_passed = driving_passed and drive.passed
	report("driving",driving_passed)
	race.menu.hide()
	race.menu_flow.refresh()
	race.get_node("HUD").hide()
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = 330
	race.camera.far = 500
	race.camera.position = Vector3(0,300,0)
	race.camera.rotation_degrees = Vector3(-90,0,0)
	await settle(3)
	save_frame("terrain_overview")
	report("passed",all_supported and driving_passed and road_support.failures.is_empty() and gates.failures.is_empty())
	race.show_menu()
	race.set_physics_process(false)
	for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(false)
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")
