extends "res://tests/autopilot/probe_base.gd"
# Standalone numerical fixture; early profile isolation still protects app setup.
var failures: Array[String] = []
func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null: node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(3)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	get_tree().current_scene.get_node("Opening").queue_free()
	get_tree().paused = false
	var current: Node3D = preload("res://showcase_track.gd").new()
	var original: Node3D = preload("res://tests/fixtures/track_sampling_before_loading.gd").new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 74129
	var count: int = 0
	for id: String in preload("res://scripts/tracks/content_catalog.gd").IDS:
		current.definition = load("res://tracks/%s/definition.tres" % id)
		original.definition = current.definition
		original.build()
		# SelectedCourse transfers checked arrays without calling build on the
		# active node. Even in the same tick, its previous route cache must expire.
		for property: String in ["starts","ends","lengths","total_length"]: current.set(property,original.get(property))
		if current.direction(0.0)!=original.direction(0.0): failures.append(id+" route replacement mismatch")
		current.build(true)
		var stations: Array[float] = [-0.25,0.0,0.25,current.total_length,current.total_length+0.25]
		for index: int in range(1200): stations.append(rng.randf_range(-current.total_length,current.total_length*2.0))
		for station: float in stations:
			var expected: Vector2 = original.direction(station)
			for repeated: int in range(3):
				if current.direction(station)!=expected: failures.append(id+" direction mismatch "+str(station))
				count += 1
			if current.direction_cache.size()>1024: failures.append("unbounded cache")
		# Reuse the same station after a rebuild of the same resource.
		current.build(true)
		if current.direction(0.0)!=original.direction(0.0): failures.append(id+" rebuild mismatch")
	current.free()
	original.free()
	report("comparisons",count)
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
