extends "res://tests/probes/route_direction_parity.gd"
# Exact query parity against the preserved implementation, including layers,
# boundary containment, wrapping hints, rebuilds and SelectedCourse transfer.
func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	var current: Node3D = preload("res://showcase_track.gd").new()
	var original: Node3D = preload("res://tests/fixtures/track_projection_before_cache.gd").new()
	var ids: Array = preload("res://scripts/tracks/content_catalog.gd").IDS.duplicate()
	ids.append("bazaar")
	var comparisons: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 529104
	var timings: Dictionary = {}
	for id: String in ids:
		current.definition = load("res://tracks/%s/definition.tres" % id)
		original.definition = current.definition
		current.build()
		original.build()
		if current.validation_errors!=original.validation_errors: failures.append(id+" validation")
		for i: int in range(current.starts.size()):
			if current.road_polygon(i)!=original.road_polygon(i): failures.append(id+" polygon "+str(i))
			var a: PackedVector3Array = current.road_edges(i)
			var b: PackedVector3Array = current.road_edges(i+1)
			for fraction: float in [-0.08,0.04,0.5,0.96,1.08]:
				var point: Vector3 = a[0].lerp(b[0],0.5).lerp(a[1].lerp(b[1],0.5),fraction)
				var hint: float = lerpf(current.lengths[i],current.lengths[i+1],0.5)
				compare_query(current,original,point,hint,5.0,id)
				comparisons += 1
		for i: int in range(150):
			var station: float = rng.randf_range(0,current.total_length)
			var point: Vector3 = current.sample_3d(station)+Vector3(rng.randf_range(-8,8),rng.randf_range(-3,5),rng.randf_range(-8,8))
			var hint: float = -1.0 if i<8 else station
			compare_query(current,original,point,hint,rng.randf_range(0.01,12),id)
			comparisons += 1
		# A second build must replace all cached inputs, even in the same tick.
		current.build(true)
		compare_query(current,original,current.sample_3d(0.0),current.total_length,5.0,id)
		current.span_origins.clear()
		current.corridor_heights.clear()
		compare_query(current,original,current.sample_3d(0.0),0.0,5.0,id+" reload")
		if id=="toys_r_you":
			var alignment: Dictionary = preload("res://tests/probes/toys_alignment_checks.gd").check(current.definition)
			report("toys_alignment",alignment)
			if not alignment.failures.is_empty(): failures.append("toys alignment")
		if id=="bazaar":
			for target: Node3D in [original,current]:
				var begun: int = Time.get_ticks_usec()
				for repeat: int in range(10):
					for i: int in range(target.starts.size()):
						target.project_3d(target.starts[i],float(target.lengths[i]))
				timings["original_usec" if target==original else "cached_usec"] = Time.get_ticks_usec()-begun
	var catalog: Script = preload("res://scripts/tracks/content_catalog.gd")
	var entry: Resource = load("res://tracks/bazaar/entry.tres")
	var selected: bool = race.course.select("bazaar",catalog.assigned_vehicle("bazaar"),catalog.validate_entry(entry,"bazaar",catalog.assigned_vehicle("bazaar")))
	if not selected: failures.append("staged selection")
	original.definition = entry.route
	original.build()
	for i: int in range(race.track.starts.size()):
		compare_query(race.track,original,race.track.starts[i],float(race.track.lengths[i]),5.0,"transferred bazaar")
		comparisons += 1
	if not race.course.select("game_table"): failures.append("switch procedural")
	original.definition = race.track.definition
	original.build()
	compare_query(race.track,original,race.track.starts[0],0,5,"transferred procedural")
	current.free()
	original.free()
	report("comparisons",comparisons)
	report("courses",ids)
	report("benchmark",timings)
	report("failures",failures)
	report("passed",failures.is_empty() and race.profile.read_only)
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()

func compare_query(current: Node3D, original: Node3D, point: Vector3, hint: float, window: float, title: String) -> void:
	var actual: Dictionary = current.project_3d(point,hint,window)
	var expected: Dictionary = original.project_3d(point,hint,window)
	if actual!=expected and failures.size()<30:
		failures.append(title+" query "+str(point)+" hint "+str(hint)+" actual "+str(actual)+" expected "+str(expected))
