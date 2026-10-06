@tool
extends RefCounted
const KITCHEN: Script = preload("res://scripts/tracks/kitchen_art.gd")
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")

static func road_material() -> ShaderMaterial:
	var result: ShaderMaterial = KITCHEN.surface_material()
	result.shader = result.shader.duplicate()
	result.shader.code = result.shader.code.replace("varying vec2 world;", "varying vec2 world; varying float height;").replace("void vertex() {", "void vertex() { height = (MODEL_MATRIX * vec4(VERTEX,1.0)).y;").replace("ROUGHNESS = 0.9;", "if (height > 3.8) { vec2 tile = fract(world / 5.0); float joint = max(step(0.96,tile.x),step(0.96,tile.y)); ALBEDO = mix(vec3(0.90,0.86,0.70),vec3(0.55,0.64,0.65),joint); } ROUGHNESS = 0.9;")
	return result

static func build_all() -> void:
	var points: Array[Vector2] = [Vector2(-130,-45),Vector2(-60,-45),Vector2(25,-45),Vector2(90,-45),Vector2(90,0),Vector2(60,0),Vector2(60,35),Vector2(105,70),Vector2(65,105),Vector2(0,85),Vector2(-60,75),Vector2(-130,75),Vector2(-155,45),Vector2(-155,-10)]
	var heights: Array[float] = [4,4,0,0,0,0,0,0,0,0,0,4,4,4]
	var definition: Resource = INTRO.route("countertop_table",points)
	definition.start_station = 24.0
	for i: int in range(points.size()):
		var section: Resource = definition.sections[i]
		section.surface = "paper" if i in [4,5] else "wood"
		section.start.y = heights[i]
		section.end.y = heights[(i+1)%points.size()]
		section.before.y = section.start.y
		section.after.y = section.end.y
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/countertop_table")
	assert(ResourceSaver.save(definition,"res://tracks/countertop_table/definition.tres")==OK)
	definition.take_over_path("res://tracks/countertop_table/definition.tres")
	var environment: Node3D = KITCHEN.build(track)
	var old_table: Node = environment.get_node("BreakfastTable")
	old_table.free()
	var table: Node3D = ART.group(environment,"BreakfastTable",Vector3(65,0,30))
	var top: MeshInstance3D = ART.box(table,"WoodTop",Vector3(0,-0.09,0),Vector3(115,0.16,175),KITCHEN.WOOD)
	top.material_override = KITCHEN.surface_material()
	ART.collider(table,Vector3(0,-0.09,0),Vector3(115,0.16,175))
	ART.box(table,"Apron",Vector3(0,-0.65,0),Vector3(115,1,175),Color("a56d40"))
	for x: float in [-48,48]:
		for z: float in [-78,78]: ART.box(table,"Leg",Vector3(x,-4,z),Vector3(2,7,2),Color("a56d40"))
	var chair: Node3D = ART.group(environment,"ChairBack",Vector3(12,-2,112))
	ART.box(chair,"Seat",Vector3.ZERO,Vector3(15,1,14),KITCHEN.WOOD)
	for x: float in [-6,6]: ART.box(chair,"Post",Vector3(x,1,5),Vector3(1,8,1),KITCHEN.BLUE)
	ART.box(chair,"Back",Vector3(0,4,5),Vector3(14,2,1),KITCHEN.BLUE)
	ART.batch(chair)
	var counter: Node3D = ART.group(environment,"Counter",Vector3.ZERO)
	ART.box(counter,"CounterCabinet",Vector3(-157,-1,20),Vector3(30,10,154),KITCHEN.BLUE)
	ART.box(counter,"CounterTop",Vector3(-157,3.85,20),Vector3(34,0.17,158),KITCHEN.CREAM)
	ART.box(counter,"LaunchCounter",Vector3(-102.5,3.85,-45),Vector3(75,0.17,24),KITCHEN.CREAM)
	# Continuous broad wooden boards match sampled route heights and shoulders.
	var support: Node3D = ART.group(environment,"TransferBoards",Vector3.ZERO)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		var a: Vector3 = track.starts[i]-Vector3.UP*0.015
		var b: Vector3 = track.ends[i]-Vector3.UP*0.015
		var na: Vector3 = track.edge_offset(i)*5.3
		var nb: Vector3 = track.edge_offset(i+1)*5.3
		load("res://scripts/tracks/track_builder.gd").quad(tool,a+na,b+nb,b-nb,a-na)
	tool.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "SupportedBoards"
	mesh.mesh = tool.commit()
	mesh.material_override = road_material()
	support.add_child(mesh)
	mesh.create_trimesh_collision()
	for station: float in [95.0,140.0,620.0,655.0]:
		var direction: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		for side: float in [-1,1]:
			var mark: Node3D = ART.group(support,"BoardTick",track.sample_3d(station)+normal*4.7*side)
			ART.box(mark,"Paint",Vector3.ZERO,Vector3(0.7,0.03,0.4),KITCHEN.BLUE)
	for surface: Node in counter.get_children():
		if surface is MeshInstance3D and "Counter" in str(surface.name) and surface.name!="CounterCabinet": surface.material_override = road_material()
	ART.batch(counter)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/kitchen/countertop_table.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "countertop_table"
	entry.title = "Countertop-to-Table Run"
	entry.cup = "Breakfast"
	entry.order_in_cup = 3
	entry.route = definition
	entry.environment = load("res://environments/kitchen/countertop_table.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/countertop_table/preview.res")
	entry.target_lap_seconds = Vector2(50,60)
	entry.description = "Breakfast · long board transfers · square table corner · fast return bends"
	assert(ResourceSaver.save(entry,"res://tracks/countertop_table/entry.tres")==OK)
	print("COUNTERTOP_TABLE length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()



