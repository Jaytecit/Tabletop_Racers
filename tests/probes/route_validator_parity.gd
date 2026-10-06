extends "res://tests/probes/race_quality_ai_verification.gd"
const BEFORE: Script = preload("res://tests/fixtures/track_validator_before_loading.gd")
const AFTER: Script = preload("res://scripts/tracks/track_validator.gd")
func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	var comparisons: Array = []
	for id: String in preload("res://scripts/tracks/content_catalog.gd").IDS:
		var route: Resource = load("res://tracks/%s/definition.tres" % id)
		compare(route,id,comparisons)
		var old_track: Node3D = preload("res://tests/fixtures/track_sampling_before_loading.gd").new()
		var new_track: Node3D = preload("res://showcase_track.gd").new()
		old_track.definition = route
		new_track.definition = route
		old_track.build()
		new_track.build(true)
		for property: String in ["validation_errors","points","lengths","starts","ends","section_ids","total_length","half_width","gates","anchors","corridor_polygons","corridor_bounds"]:
			check(old_track.get(property)==new_track.get(property),id+"_"+property)
		old_track.free()
		new_track.free()
		await settle(1)
	# Seeded closed crossing/parallel/gap geometries, varied layer/height/width.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1042026
	for variant: int in range(80):
		var route: Resource = preload("res://scripts/tracks/track_definition.gd").new()
		var points: Array[Vector3] = []
		for i: int in range(8): points.append(Vector3(rng.randf_range(-35,35),float(rng.randi_range(0,3)),rng.randf_range(-35,35)))
		for i: int in range(points.size()):
			var section: Resource = preload("res://scripts/tracks/route_section.gd").new()
			section.id = str(i)
			section.next_id = str((i+1)%points.size())
			section.start = points[i]
			section.end = points[(i+1)%points.size()]
			section.width = rng.randf_range(2.0,12.0)
			section.layer = rng.randi_range(0,3)
			route.sections.append(section)
		compare(route,"fixture_%d" % variant,comparisons)
		if variant%10==0: await settle(1)
	report("comparisons",comparisons)
	check(race.profile.read_only,"read_only")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

func compare(route: Resource, title: String, output: Array) -> void:
	var began: int = Time.get_ticks_usec()
	var before: Array[String] = BEFORE.validate(route)
	var before_ms: float = (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	var after: Array[String] = AFTER.validate(route)
	check(before==after,title)
	output.append({"case":title,"before_ms":before_ms,"after_ms":(Time.get_ticks_usec()-began)/1000.0,"before_errors":before,"after_errors":after})
