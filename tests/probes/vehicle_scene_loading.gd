extends "res://tests/probes/race_quality_ai_verification.gd"
# Measure repeated source scene loads before considering a retained scene cache.
func _ready() -> void:
	await settle(4)
	race = get_tree().current_scene.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	check(race.profile.read_only,"read_only")
	var visual_script: Script = preload("res://scripts/vehicles/imported_visual.gd")
	var samples: Array[Dictionary] = []
	for id: String in ["racing_car","buggy","racing_car","buggy"]:
		var paths: Array[float] = []
		for index: int in range(4):
			var begun: int = Time.get_ticks_usec()
			var source: PackedScene = visual_script.animated_scene(id)
			paths.append((Time.get_ticks_usec()-begun)/1000.0)
			source = null
		var builds: Array[float] = []
		for index: int in range(4):
			var begun: int = Time.get_ticks_usec()
			var visual: Node3D = visual_script.build(id)
			builds.append((Time.get_ticks_usec()-begun)/1000.0)
			visual.free()
		check(visual_script.scene_cache.size() <= 2,"bounded_scene_cache_"+str(samples.size()))
		samples.append({"class":id,"scene_load_ms":paths,"visual_build_ms":builds,"scene_cache_size":visual_script.scene_cache.size()})
	var first: Node3D = visual_script.build("racing_car")
	var second: Node3D = visual_script.build("racing_car")
	var first_paint: MeshInstance3D = visual_script.paint_meshes(first)[0]
	var second_paint: MeshInstance3D = visual_script.paint_meshes(second)[0]
	visual_script.set_paint(first_paint,Color.GREEN)
	check(first_paint.material_override != second_paint.material_override and second_paint.material_override.get_shader_parameter("player_colour") == Color("ef6546"),"cached_scene_private_paint")
	check(visual_script.bounds(first) == visual_script.bounds(second),"cached_scene_equal_bounds")
	first.free()
	second.free()
	report("samples",samples)
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
