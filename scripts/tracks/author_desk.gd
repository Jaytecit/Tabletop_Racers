@tool
extends RefCounted
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")
const BEDROOM: Script = preload("res://scripts/tracks/bedroom_art.gd")
const WOOD: Script = preload("res://scripts/tracks/kitchen_art.gd")

static func paper_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	float ruled = step(0.96,fract(world.y * 0.7));
	ALBEDO = mix(vec3(0.88,0.84,0.73),vec3(0.58,0.65,0.67),ruled * 0.35);
	ROUGHNESS = 1.0;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material

static func lamp(parent: Node3D) -> void:
	ART.cylinder(parent,"Base",Vector3(0,0.15,0),1.3,0.3,BEDROOM.BLUE)
	ART.box(parent,"Stem",Vector3(0,2.1,0),Vector3(0.3,4,0.3),ART.INK)
	ART.box(parent,"Arm",Vector3(0.65,4.1,0),Vector3(1.5,0.3,0.3),ART.INK)
	ART.cylinder(parent,"Shade",Vector3(1.2,3.8,0),1.3,0.9,BEDROOM.CORAL)
	ART.cylinder(parent,"Bulb",Vector3(1.2,3.33,0),0.9,0.05,ART.IVORY)
	ART.collider(parent,Vector3(0.5,2.2,0),Vector3(3.6,4.5,2.8))

static func pencil(parent: Node3D) -> void:
	ART.box(parent,"YellowBody",Vector3(0,0.15,0),Vector3(4.5,0.25,0.3),ART.GOLD)
	ART.box(parent,"Lead",Vector3(-2.5,0.15,0),Vector3(0.5,0.16,0.16),ART.INK)
	ART.box(parent,"Eraser",Vector3(2.4,0.15,0),Vector3(0.4,0.3,0.35),BEDROOM.CORAL)

static func washer(parent: Node3D) -> void:
	ART.cylinder(parent,"Washer",Vector3(0,0.04,0),0.3,0.06,Color("bec7c2"))
	ART.cylinder(parent,"Hole",Vector3(0,0.078,0),0.13,0.01,ART.INK)
	ART.box(parent,"PencilTick",Vector3(0.65,0.04,0),Vector3(0.45,0.025,0.12),ART.INK)

static func build_environment(track: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CourseEnvironment"
	root.set_meta("theme","bedroom")
	# A low visual ground lies below the drawer. Every driving deck is independently supported.
	var ground: Node3D = ART.group(root,"DeskGround",Vector3.ZERO)
	var base: MeshInstance3D = ART.box(ground,"WoodFloor",Vector3(0,-0.22,15),Vector3(285,0.16,210),Color("b27c4b"))
	base.material_override = WOOD.surface_material()
	var support: Node3D = ART.group(root,"DrawerSupport",Vector3.ZERO)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		var a: Vector3 = track.starts[i]-Vector3.UP*0.015
		var b: Vector3 = track.ends[i]-Vector3.UP*0.015
		var na: Vector3 = track.edge_offset(i)*5.3
		var nb: Vector3 = track.edge_offset(i+1)*5.3
		load("res://scripts/tracks/track_builder.gd").quad(tool,a+na,b+nb,b-nb,a-na)
	tool.generate_normals()
	var deck: MeshInstance3D = MeshInstance3D.new()
	deck.name = "SupportedDeskAndDrawer"
	deck.mesh = tool.commit()
	deck.material_override = WOOD.surface_material()
	support.add_child(deck)
	deck.create_trimesh_collision()
	# Drawer walls sit outside the full shoulder band; the connector remains visibly open.
	var drawer: Node3D = ART.group(root,"OpenDrawer",Vector3(64,0,-31))
	ART.box(drawer,"DrawerFront",Vector3(0,0.85,-31),Vector3(88,1.2,1),BEDROOM.BLUE)
	ART.box(drawer,"Handle",Vector3(0,1.0,-32),Vector3(10,0.7,0.8),ART.GOLD)
	ART.box(drawer,"SideWall",Vector3(47,0.85,0),Vector3(1,1.2,63),BEDROOM.BLUE)
	ART.batch(drawer)
	var cues: Node3D = ART.group(root,"TracksideCues",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/3.0))):
		var station: float = float(i)*3.0
		var direction: Vector2 = track.direction(station)
		for side: float in [-1,1]:
			var pos: Vector3 = track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*4.7*side
			if track.project_3d(pos).distance<4.4: continue
			var cue: Node3D = ART.group(cues,"Washer%03d_%d"%[i,int(side)],pos)
			cue.set_meta("cue_station",station)
			washer(cue)
			ART.batch(cue)
	var landmarks: Node3D = ART.group(root,"Landmarks",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/14.0))):
		var station: float = float(i)*14.0
		var direction: Vector2 = track.direction(station)
		var pos: Vector3 = track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*11.0*(1 if i%2==0 else -1)
		if track.project_3d(pos).distance<9.0: continue
		var prop: Node3D = ART.group(landmarks,"DeskSector%02d"%i,pos)
		prop.rotation.y = -direction.angle()
		match i%4:
			0: lamp(prop)
			1: BEDROOM.spool(prop)
			2: BEDROOM.books(prop)
			3: pencil(prop)
		ART.batch(prop)
	ART.build_guidance(root,track)
	return root

static func build_all() -> void:
	# Two drawer corners, a separated spool hairpin and a long sweeping desk return.
	var points: Array[Vector2] = [Vector2(-95,-40),Vector2(-50,-40),Vector2(5,-40),Vector2(38,-40),Vector2(38,-8),Vector2(72,-8),Vector2(86,14),Vector2(75,42),Vector2(48,42),Vector2(42,19),Vector2(22,22),Vector2(18,54),Vector2(-18,66),Vector2(-58,52),Vector2(-92,24),Vector2(-104,-10)]
	for i: int in range(points.size()): points[i] *= 1.2
	var heights: Array[float] = [2.2,2.2,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,0.8,2.2,2.2,2.2,2.2,2.2]
	var definition: Resource = INTRO.route("desk_drawer",points)
	definition.start_station = 24.0
	for i: int in range(points.size()):
		var section: Resource = definition.sections[i]
		section.surface = "paper" if i in [11,12] else "wood"
		section.start.y = heights[i]
		section.end.y = heights[(i+1)%heights.size()]
		section.before.y = section.start.y
		section.after.y = section.end.y
		section.edge = "raised"
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/desk_drawer")
	assert(ResourceSaver.save(definition,"res://tracks/desk_drawer/definition.tres")==OK)
	definition.take_over_path("res://tracks/desk_drawer/definition.tres")
	var environment: Node3D = build_environment(track)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/bedroom/desk_drawer.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "desk_drawer"
	entry.title = "Desk Drawer Dash"
	entry.cup = "Bedroom"
	entry.order_in_cup = 2
	entry.route = definition
	entry.environment = load("res://environments/bedroom/desk_drawer.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/desk_drawer/preview.res")
	entry.target_lap_seconds = Vector2(40,55)
	entry.description = "Bedroom desk · supported drawer · square corners · spool hairpin"
	assert(ResourceSaver.save(entry,"res://tracks/desk_drawer/entry.tres")==OK)
	print("DESK_DRAWER length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()
