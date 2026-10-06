@tool
extends RefCounted
const KITCHEN: Script = preload("res://scripts/tracks/kitchen_art.gd")
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")

static func plate(parent: Node3D, radius: float = 3.0) -> void:
	ART.cylinder(parent,"PlateDeck",Vector3(0,0.25,0),radius,0.5,KITCHEN.CREAM)
	# A flush painted rim keeps the supported driving band clear.
	for i: int in range(64):
		var angle: float = float(i)*TAU/64.0
		var mark: Node3D = ART.group(parent,"RimMark",Vector3(cos(angle)*(radius-0.8),0.51,sin(angle)*(radius-0.8)))
		mark.rotation.y = -angle
		ART.box(mark,"BlueDivision",Vector3.ZERO,Vector3(0.7,0.015,0.22),KITCHEN.BLUE)
	ART.collider(parent,Vector3(0,0.25,0),Vector3(radius*2,0.5,radius*2),radius)

static func road_material() -> ShaderMaterial:
	var result: ShaderMaterial = KITCHEN.surface_material()
	result.shader = result.shader.duplicate()
	result.shader.code = result.shader.code.replace("varying vec2 world;", "varying vec2 world; varying float height;").replace("void vertex() {", "void vertex() { height = (MODEL_MATRIX * vec4(VERTEX,1.0)).y;").replace("ROUGHNESS = 0.9;", "if (height > 0.49 && distance(world, vec2(30.0,0.0)) < 40.5) { ALBEDO = vec3(0.957,0.910,0.796); } ROUGHNESS = 0.9;")
	return result

static func build_all() -> void:
	var points: Array[Vector2] = [Vector2(-85,-36),Vector2(-38,-36),Vector2(30,-36),Vector2(55.46,-25.46),Vector2(66,0),Vector2(55.46,25.46),Vector2(30,36),Vector2(0,36),Vector2(-20,12),Vector2(-48,12),Vector2(-63,31),Vector2(-48,52),Vector2(-85,80),Vector2(-105,55),Vector2(-105,-14)]
	var definition: Resource = INTRO.route("plate_rim",points)
	definition.start_station = 24.0
	definition.revision = 2
	for i: int in range(definition.sections.size()):
		var section: Resource = definition.sections[i]
		section.surface = "ceramic" if i in [2,3,4,5] else ("paper" if i in [8,9,10,11] else "wood")
		section.start.y = 0.5 if i in [1,2,3,4,5,6,7] else 0.0
		section.end.y = 0.5 if (i+1)%points.size() in [1,2,3,4,5,6,7] else 0.0
		section.before.y = section.start.y
		section.after.y = section.end.y
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/plate_rim")
	assert(ResourceSaver.save(definition,"res://tracks/plate_rim/definition.tres")==OK)
	definition.take_over_path("res://tracks/plate_rim/definition.tres")
	var environment: Node3D = KITCHEN.build(track)
	var dish: Node3D = ART.group(environment,"PlateSupport",Vector3(30,0,0))
	plate(dish,40.5)
	ART.batch(dish)
	# Bake physical ramp support from the same sample endpoints as driving.
	var ramps: Node3D = ART.group(environment,"RampSupport",Vector3.ZERO)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		if track.starts[i].y<=0.0 and track.ends[i].y<=0.0: continue
		var a: Vector3 = track.starts[i]-Vector3.UP*0.015
		var b: Vector3 = track.ends[i]-Vector3.UP*0.015
		var na: Vector3 = track.edge_offset(i)*5.3
		var nb: Vector3 = track.edge_offset(i+1)*5.3
		load("res://scripts/tracks/track_builder.gd").quad(tool,a+na,b+nb,b-nb,a-na)
	tool.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "RampDecks"
	mesh.mesh = tool.commit()
	mesh.material_override = KITCHEN.surface_material()
	ramps.add_child(mesh)
	mesh.create_trimesh_collision()
	var packed: PackedScene = PackedScene.new()
	INTRO.stamp(environment,environment)
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/kitchen/plate_rim.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "plate_rim"
	entry.title = "Plate Rim Rally"
	entry.cup = "Breakfast"
	entry.order_in_cup = 2
	entry.route = definition
	entry.environment = load("res://environments/kitchen/plate_rim.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/plate_rim/preview.res")
	entry.target_lap_seconds = Vector2(40,50)
	entry.description = "Breakfast · sustained plate arc · napkin hairpin · shallow ramps"
	assert(ResourceSaver.save(entry,"res://tracks/plate_rim/entry.tres")==OK)
	print("PLATE_RIM length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()
