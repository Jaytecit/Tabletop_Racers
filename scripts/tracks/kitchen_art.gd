@tool
extends RefCounted
# Original breakfast kit. Geometry is baked; surface patterns use world coordinates.
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const WOOD: Color = Color("d3ac69")
const BLUE: Color = Color("4ba5c9")
const CREAM: Color = Color("f4e8cb")

static func surface_material(cloth: bool = false) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform bool cloth = false;
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	if (cloth) {
		vec2 cell = floor(world * 1.25);
		float check = mod(cell.x + cell.y, 2.0);
		float weave = step(0.85, fract(world.x * 8.0)) * 0.025;
		ALBEDO = mix(vec3(0.92,0.84,0.65), vec3(0.72,0.46,0.38), check * 0.38) + weave;
	} else {
		float grain = sin(world.x * 4.2 + sin(world.y * 0.18) * 1.1);
		float seam = step(0.97, fract(world.x / 7.0));
		ALBEDO = vec3(0.72,0.49,0.28) + grain * 0.035 - seam * 0.06;
	}
	ROUGHNESS = 0.9;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cloth",cloth)
	return material

static func ring(parent: Node3D, title: String, pos: Vector3, radius: float, color: Color) -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = radius * 0.58
	mesh.outer_radius = radius
	mesh.rings = 12
	mesh.ring_segments = 8
	ART.shape(parent,title,mesh,pos,color)

static func cereal(parent: Node3D, variant: int) -> void:
	for i: int in range(3):
		ring(parent,"CerealLoop",Vector3(float(i-1)*0.38,0.13,float((i+variant)%2)*0.30),0.22,Color("e0aa54") if i%2==0 else Color("c37d63"))
	ART.box(parent,"Crumb",Vector3(0.1,0.05,-0.27),Vector3(0.19,0.09,0.16),CREAM)

static func carton(parent: Node3D) -> void:
	ART.box(parent,"Carton",Vector3(0,2,0),Vector3(3.2,4,1.5),BLUE)
	ART.box(parent,"TopFold",Vector3(0,4.08,0),Vector3(3.2,0.18,1.5),CREAM)
	ART.box(parent,"FrontPanel",Vector3(0,2,-0.76),Vector3(2.8,3.1,0.025),Color("f1c44f"))
	var title: Label3D = ART.flat_text(parent,"OriginalLabel",Vector3(0,2.8,-0.80),"SUNRISE\nLOOPS",0.65,ART.INK)
	title.rotation_degrees.x = 0
	for i: int in range(3):
		var loop: Node3D = ART.group(parent,"PrintedLoop",Vector3(float(i-1)*0.7,1.5,-0.81))
		loop.rotation_degrees.x = 90
		ring(loop,"Loop",Vector3.ZERO,0.35,CREAM)
	ART.collider(parent,Vector3(0,2,0),Vector3(3.2,4,1.5))

static func bowl(parent: Node3D) -> void:
	ART.cylinder(parent,"BowlFoot",Vector3(0,0.15,0),1.6,0.3,BLUE)
	var wall: CylinderMesh = CylinderMesh.new()
	wall.bottom_radius = 1.6
	wall.top_radius = 2.6
	wall.height = 1.1
	ART.shape(parent,"CeramicWall",wall,Vector3(0,0.8,0),CREAM)
	ART.cylinder(parent,"Milk",Vector3(0,1.36,0),2.35,0.035,Color("e6dca5"))
	ring(parent,"BlueRim",Vector3(0,1.42,0),2.6,BLUE)
	for i: int in range(8):
		var angle: float = float(i)*TAU/8.0
		ring(parent,"FloatingCereal",Vector3(cos(angle)*1.35,1.48,sin(angle)*1.35),0.27,Color("e0aa54"))
	ART.collider(parent,Vector3(0,0.7,0),Vector3(5.2,1.4,5.2),2.6)

static func spoon(parent: Node3D) -> void:
	var bowl_mesh: SphereMesh = SphereMesh.new()
	bowl_mesh.radius = 0.7
	bowl_mesh.height = 1.4
	var head: MeshInstance3D = ART.shape(parent,"SpoonHead",bowl_mesh,Vector3(-1.4,0.18,0),Color("bdc6c5"))
	head.scale = Vector3(1.6,0.18,0.85)
	ART.box(parent,"Handle",Vector3(0.8,0.12,0),Vector3(3.5,0.12,0.35),Color("bdc6c5"))
	ART.box(parent,"HandleTip",Vector3(2.6,0.12,0),Vector3(0.4,0.12,0.55),BLUE)
	ART.collider(parent,Vector3(0.2,0.18,0),Vector3(5.6,0.36,1.4))

static func board(parent: Node3D) -> void:
	var top: MeshInstance3D = ART.box(parent,"Breadboard",Vector3(0,0.16,0),Vector3(4.8,0.3,3.2),WOOD)
	top.material_override = surface_material()
	ART.box(parent,"BreadCrust",Vector3(0,0.45,0),Vector3(2.6,0.28,2.4),Color("b37643"))
	ART.box(parent,"Bread",Vector3(0,0.60,0),Vector3(2.2,0.07,2.0),CREAM)
	ART.collider(parent,Vector3(0,0.33,0),Vector3(4.8,0.66,3.2))

static func mug(parent: Node3D) -> void:
	ART.cylinder(parent,"Mug",Vector3(0,1.05,0),1.15,2.1,BLUE)
	ART.cylinder(parent,"Coffee",Vector3(0,2.11,0),0.98,0.03,Color("563c2c"))
	var handle: Node3D = ART.group(parent,"Handle",Vector3(1.25,1.05,0))
	handle.rotation_degrees.x = 90
	ring(handle,"CeramicHandle",Vector3.ZERO,0.65,BLUE)
	ART.collider(parent,Vector3(0.3,1.1,0),Vector3(3.4,2.2,2.3))

static func build(track: Node3D) -> Node3D:
	var environment: Node3D = Node3D.new()
	environment.name = "CourseEnvironment"
	environment.set_meta("theme","breakfast")
	var bounds: Rect2 = Rect2(track.points[0],Vector2.ZERO)
	for point: Vector2 in track.points: bounds = bounds.expand(point)
	var size: Vector2 = bounds.size + Vector2(24,24)
	var centre: Vector2 = bounds.get_center()
	var table: Node3D = ART.group(environment,"BreakfastTable",Vector3(centre.x,0,centre.y))
	var top: MeshInstance3D = ART.box(table,"WoodTop",Vector3(0,-0.09,0),Vector3(size.x,0.16,size.y),WOOD)
	top.material_override = surface_material()
	ART.collider(table,Vector3(0,-0.09,0),Vector3(size.x,0.16,size.y))
	ART.box(table,"TableApron",Vector3(0,-0.65,0),Vector3(size.x+0.3,1.0,size.y+0.3),Color("a56d40"))
	for x: float in [-1.0,1.0]:
		for z: float in [-1.0,1.0]:
			ART.box(table,"Leg",Vector3(x*(size.x*0.5-3),-4,z*(size.y*0.5-3)),Vector3(1.7,7,1.7),Color("a56d40"))
	ART.box(environment,"KitchenFloor",Vector3(centre.x,-7.6,centre.y),Vector3(size.x+40,0.2,size.y+40),Color("d8d1b8"))
	var cues: Node3D = ART.group(environment,"TracksideCues",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/3.0))):
		var station: float = float(i)*3.0
		var p: Vector3 = track.sample_3d(station)
		var direction: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		for side: float in [-1.0,1.0]:
			var pos: Vector3 = p+normal*4.6*side
			if track.project_3d(pos).distance<4.4: continue
			var cue: Node3D = ART.group(cues,"Cereal%03d_%d"%[i,int(side)],pos)
			cue.set_meta("cue_station",station)
			cereal(cue,i)
			ART.batch(cue)
	var landmarks: Node3D = ART.group(environment,"Landmarks",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/12.0))):
		var station: float = float(i)*12.0
		var direction: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		var pos: Vector3 = track.sample_3d(station)+normal*9.5*(1.0 if i%2==0 else -1.0)
		if track.project_3d(pos).distance<8.0: continue
		var sector: Node3D = ART.group(landmarks,"BreakfastSector%02d"%i,pos)
		sector.rotation.y = -direction.angle()
		match i%5:
			0: carton(sector)
			1: bowl(sector)
			2: spoon(sector)
			3: board(sector)
			4: mug(sector)
		ART.batch(sector)
	var guidance: Node3D = ART.build_guidance(environment,track)
	for mesh: Node in guidance.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = mesh.material_override.duplicate()
		mesh.material_override.albedo_color = Color("725239")
	return environment

static func build_all() -> void:
	# Short steering pulses on the outward side, decreasing radius bowl turn,
	# then a longer breadboard passing straight and forgiving napkin return.
	var points: Array[Vector2] = [Vector2(-58,-28),Vector2(-28,-28),Vector2(-12,-18),Vector2(4,-30),Vector2(20,-17),Vector2(36,-29),Vector2(52,-18),Vector2(61,-3),Vector2(55,10),Vector2(43,17),Vector2(18,19),Vector2(-20,19),Vector2(-47,23),Vector2(-61,12),Vector2(-66,-9)]
	for i: int in range(points.size()): points[i] *= 1.35
	var definition: Resource = INTRO.route("cereal_slalom",points)
	definition.start_station = 24.0
	for i: int in range(definition.sections.size()):
		definition.sections[i].surface = "paper" if i in [11,12] else "wood"
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/cereal_slalom")
	DirAccess.make_dir_recursive_absolute("res://environments/kitchen")
	assert(ResourceSaver.save(definition,"res://tracks/cereal_slalom/definition.tres")==OK)
	definition.take_over_path("res://tracks/cereal_slalom/definition.tres")
	var environment: Node3D = build(track)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/kitchen/cereal_slalom.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "cereal_slalom"
	entry.title = "Cereal Slalom"
	entry.cup = "Breakfast"
	entry.order_in_cup = 1
	entry.route = definition
	entry.environment = load("res://environments/kitchen/cereal_slalom.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/cereal_slalom/preview.res")
	entry.target_lap_seconds = Vector2(35,45)
	entry.description = "Breakfast table · steering pulses · bowl turn · napkin return"
	assert(ResourceSaver.save(entry,"res://tracks/cereal_slalom/entry.tres")==OK)
	print("CEREAL_SLALOM length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()
