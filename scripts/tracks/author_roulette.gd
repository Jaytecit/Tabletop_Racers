@tool
extends RefCounted
# Source asset coordinates are retained here; gameplay dimensions are baked once.
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const BUILDER: Script = preload("res://scripts/tracks/track_builder.gd")
const SCALE: float = 24.0
const FELT_Y: float = 3.489399
const CENTRE: Vector3 = Vector3(0.614668,FELT_Y,-0.166808)

static func pose() -> Transform3D:
	var basis: Basis = Basis(Vector3.UP,PI*0.5).scaled(Vector3.ONE*SCALE)
	return Transform3D(basis,-(basis*CENTRE))

static func textured(path: String, normal_path: String = "") -> StandardMaterial3D:
	var mat: StandardMaterial3D = BUILDER.material(Color.WHITE)
	mat.albedo_texture = load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not normal_path.is_empty():
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path)
		mat.normal_scale = 0.55
	return mat

static func flatten(node: Node, transform: Transform3D, target: Node3D, table_mat: Material, wood_mat: Material) -> void:
	var current: Transform3D = transform
	if node is Node3D: current *= node.transform
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = node.name
		mesh.mesh = node.mesh
		mesh.transform = current
		mesh.material_override = table_mat if str(node.name)=="polySurface36" else wood_mat
		if str(node.name).begins_with("polySurface") and str(node.name)!="polySurface36":
			mesh.mesh = chair_mesh(node.mesh,node.transform)
			mesh.material_override = null
		mesh.set_meta("overview_hide",str(node.name)=="pPlane2")
		if str(node.name)=="pPlane2": mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_meta("camera_occlusion_exempt",str(node.name)=="polySurface36" or str(node.name)=="pPlane3")
		mesh.set_meta("camera_occluder",true)
		mesh.set_meta("fade_strength",0.98)
		target.add_child(mesh)
	for child: Node in node.get_children(): flatten(child,current,target,table_mat,wood_mat)

static func room() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "RouletteCasino"
	root.set_meta("environment_theme","roulette")
	var imported: Node3D = ART.group(root,"ImportedCasino",Vector3.ZERO)
	var source: Node3D = load("res://assets/imported/casino/source/casino2.fbx").instantiate()
	var table_mat: Material = textured("res://assets/imported/casino/textures/roulette_table_lambert1_BaseColor.png","res://assets/imported/casino/textures/roulette_table_lambert1_Normal.png")
	var wood_mat: Material = textured("res://assets/imported/casino/textures/lambert1_BaseColor.png","res://assets/imported/casino/textures/lambert1_Normal.png")
	flatten(source,pose(),imported,table_mat,wood_mat)
	source.free()
	# Mesh-shaped table support retains the real rim, wheel recess and floor ledges.
	var support: Node3D = ART.group(root,"Support",Vector3.ZERO)
	for title: String in ["polySurface36","pPlane3","polySurface9","polySurface37","polySurface38","polySurface39"]:
		var visual: MeshInstance3D = imported.get_node(title)
		var faces: PackedVector3Array = visual.mesh.get_faces()
		for i: int in range(faces.size()): faces[i] = visual.transform*faces[i]
		var body: StaticBody3D = StaticBody3D.new()
		body.name = title+"Support"
		body.collision_mask = 2
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		collision.shape = shape
		body.add_child(collision)
		support.add_child(body)
	var architecture: Node3D = ART.group(root,"RoomArchitecture",Vector3.ZERO)
	var floor_y: float = (0.175962-FELT_Y)*SCALE
	var ceiling_y: float = (8.002742-FELT_Y)*SCALE
	var height: float = ceiling_y-floor_y
	var burgundy: Color = Color("54263c")
	var dark_wood: Color = Color("30201e")
	var gold: Color = Color("cda85e")
	# A real doorway interrupts the rear wall; the passage continues beyond it.
	ART.box(architecture,"RearWallLeft",Vector3(-125,floor_y+height*0.5,-170),Vector3(90,height,2),burgundy)
	ART.box(architecture,"RearWallRight",Vector3(62,floor_y+height*0.5,-170),Vector3(216,height,2),burgundy)
	ART.box(architecture,"DoorLintel",Vector3(-63,ceiling_y-35,-170),Vector3(34,70,2),burgundy)
	ART.box(architecture,"PassageFloor",Vector3(-63,floor_y-1,-193),Vector3(34,2,46),dark_wood)
	ART.box(architecture,"PassageBack",Vector3(-63,floor_y+57,-217),Vector3(34,114,2),dark_wood)
	for side: float in [-1.0,1.0]:
		ART.box(architecture,"SideWall",Vector3(side*170,floor_y+height*0.5,0),Vector3(2,height,340),burgundy)
		ART.box(architecture,"DoorFrame",Vector3(-63+side*17,floor_y+57,-168),Vector3(2,114,3),gold)
	ART.box(architecture,"FrontWall",Vector3(0,floor_y+height*0.5,170),Vector3(340,height,2),burgundy)
	# Paneled wainscot, repeated architectural trim rather than route-periodic props.
	for wall_z: float in [-168.5,168.5]:
		ART.box(architecture,"Wainscot",Vector3(0,floor_y+21,wall_z),Vector3(338,42,1),dark_wood).visible = wall_z>0
		ART.box(architecture,"DadoRail",Vector3(0,floor_y+42,wall_z),Vector3(338,1.6,2),gold).visible = wall_z>0
		for x: float in [-140,-105,-25,20,65,110,145]:
			ART.box(architecture,"WallPanel",Vector3(x,floor_y+23,wall_z),Vector3(29,30,1.5),Color("654337"))
			ART.box(architecture,"PanelTrim",Vector3(x,floor_y+39,wall_z),Vector3(30,0.8,2),gold)
	for side: float in [-1.0,1.0]:
		ART.box(architecture,"SideWainscot",Vector3(side*168.5,floor_y+21,0),Vector3(1,42,338),dark_wood)
		ART.box(architecture,"SideDado",Vector3(side*168,floor_y+42,0),Vector3(2,1.6,338),gold)
		for z: float in [-125,-70,0,70,125]:
			ART.box(architecture,"PictureFrame",Vector3(side*167.5,floor_y+105,z),Vector3(2,34,25),gold)
			ART.box(architecture,"PictureInset",Vector3(side*166.3,floor_y+105,z),Vector3(0.5,29,20),Color("172c29"))
			var emblem: MeshInstance3D = ART.cylinder(architecture,"Medallion",Vector3(side*165.8,floor_y+105,z),6,0.6,gold)
			emblem.rotation.z = PI*0.5
	for x: float in [-100,0,100]:
		ART.box(architecture,"CeilingBeam",Vector3(x,ceiling_y-2,0),Vector3(3,3,330),gold)
	for z: float in [-100,0,100]:
		ART.box(architecture,"CeilingCrossBeam",Vector3(0,ceiling_y-2,z),Vector3(330,3,3),gold)
	var fixtures: Node3D = ART.group(root,"LightingFixtures",Vector3.ZERO)
	for x: float in [-75,65]:
		ART.cylinder(fixtures,"PendantStem",Vector3(x,ceiling_y-9,0),0.5,18,gold)
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 11
		ring.outer_radius = 12
		ART.shape(fixtures,"ChandelierRing",ring,Vector3(x,ceiling_y-19,0),gold)
		for i: int in range(8):
			var angle: float = TAU*float(i)/8.0
			var bulb: MeshInstance3D = ART.cylinder(fixtures,"WarmBulb",Vector3(x+cos(angle)*11.5,ceiling_y-18,sin(angle)*11.5),1.2,4,Color("ffe0a0"))
			bulb.material_override.emission_enabled = true
			bulb.material_override.emission = Color("ffcc70")
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "PendantFill"
		light.position = Vector3(x,40,0)
		light.light_color = Color("ffe3b7")
		light.light_energy = 0.6
		light.omni_range = 160
		fixtures.add_child(light)
	var label: Label3D = Label3D.new()
	label.name = "CasinoSign"
	label.text = "ROULETTE SALON"
	label.position = Vector3(35,55,-167)
	label.font_size = 96
	label.pixel_size = 0.18
	label.modulate = gold
	label.outline_size = 0
	architecture.add_child(label)
	for mesh: Node in architecture.get_children():
		if mesh is MeshInstance3D:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.set_meta("camera_occluder",true)
			mesh.set_meta("fade_strength",1.0)
	return root

static func save_environment(root: Node3D, path: String) -> void:
	INTRO.stamp(root,root)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root)==OK)
	assert(ResourceSaver.save(packed,path)==OK)

static func chair_mesh(source: Mesh, local_pose: Transform3D) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	var velvet: SurfaceTool = SurfaceTool.new()
	var metal: SurfaceTool = SurfaceTool.new()
	velvet.begin(Mesh.PRIMITIVE_TRIANGLES)
	metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = source.get_faces()
	for i: int in range(0,faces.size(),3):
		var centre: Vector3 = local_pose*((faces[i]+faces[i+1]+faces[i+2])/3.0)
		var tool: SurfaceTool = velvet if centre.y>2.50 else metal
		for j: int in range(3): tool.add_vertex(faces[i+j])
	velvet.generate_normals()
	metal.generate_normals()
	velvet.commit(result)
	metal.commit(result)
	result.surface_set_material(0,BUILDER.material(Color("682c3b")))
	var steel: StandardMaterial3D = BUILDER.material(Color("a8aaa6"))
	steel.metallic = 0.8
	steel.roughness = 0.3
	result.surface_set_material(1,steel)
	return result

static func route() -> Resource:
	var points: Array[Vector3] = [
		Vector3(15,0,25),Vector3(40,0,25),Vector3(87,0,26),
		Vector3(99,0,8),Vector3(90,0,-14),Vector3(48,0,-15),
		Vector3(20,0,-15),Vector3(-15,0,-22),Vector3(-43,0,-41),
		Vector3(-90,8,-38),Vector3(-114,8,-24),
		Vector3(-126,8,0),Vector3(-126,8,24),Vector3(-110,8,64),
		Vector3(-76,8,64),Vector3(-47,8,54),Vector3(-36,6.5,44),Vector3(-6,0,35),Vector3(3,0,25)]
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = "game_table"
	definition.revision = 6
	definition.start_station = 8.0
	definition.gate_count = 8
	for i: int in range(points.size()):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "roulette_%02d" % i
		section.next_id = "roulette_%02d" % ((i+1)%points.size())
		section.start = points[i]
		section.end = points[(i+1)%points.size()]
		section.before = points[posmod(i-1,points.size())]
		section.after = points[(i+2)%points.size()]
		section.curved = true
		if i in range(8,17):
			section.surface = "wood"
			section.edge = "raised"
			section.width = 3.8 if i in range(11,15) else (5.0 if i==10 else (6.0 if i>=15 else 8.0))
		if i==7: section.width = 4.8
		definition.sections.append(section)
	return definition

static func chips(root: Node3D, track: Node3D) -> void:
	var props: Node3D = ART.group(root,"CasinoProps",Vector3.ZERO)
	var pack: ArrayMesh = load("res://assets/imported/casino/chips/chips_gameplay.res")
	var places: Array[Vector3] = [Vector3(28,0,3),Vector3(62,0,-4),Vector3(71,0,4),Vector3(6,0,-7),Vector3(-49,0,-28),Vector3(85,0,-9),Vector3(40,0,-8)]
	for i: int in range(pack.get_surface_count()):
		var arrays: Array = pack.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bounds: AABB = AABB(vertices[0],Vector3.ZERO)
		for v: Vector3 in vertices: bounds = bounds.expand(v)
		var centre: Vector3 = bounds.get_center()
		centre.y = bounds.position.y
		for v: int in range(vertices.size()): vertices[v] = (vertices[v]-centre)*36.0
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "ImportedChipStack_%d" % i
		visual.mesh = mesh
		visual.material_override = pack.surface_get_material(i)
		visual.position = places[i]+Vector3.UP*0.025
		visual.rotation.y = float(i)*0.83
		props.add_child(visual)
		var height: float = bounds.size.y*36.0
		ART.collider(props,places[i]+Vector3.UP*(height*0.5+0.025),Vector3(2,height,2),1.05)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3096
	# One untidy bank of loose chips and a smaller dealer pile, with open felt between.
	for cluster: Vector3 in [Vector3(27,0,5),Vector3(68,0,-2),Vector3(-50,0,-29)]:
		for i: int in range(11):
			var p: Vector3 = cluster+Vector3(rng.randf_range(-5,5),0.03,rng.randf_range(-4,4))
			if track.project_3d(p).distance<5.0: continue
			ART.chips(props,p,ART.RED if i%3==0 else (Color("326a8d") if i%3==1 else Color("21231f")),1+i%3,0.85)
	var dealer: Node3D = ART.group(props,"DealerBank",Vector3(7,0,-12))
	ART.box(dealer,"ChipTray",Vector3(0,0.22,0),Vector3(9,0.44,3.5),Color("241b1b"))
	for i: int in range(6):
		ART.chips(dealer,Vector3(-3.5+float(i)*1.4,0.44,0),ART.RED if i%2==0 else Color("20211f"),4,0.60)
	ART.collider(dealer,Vector3(0,0.7,0),Vector3(9,1.4,3.5))
	ART.drink(props,Vector3(51,0,-14))
	ART.drink(props,Vector3(80,0,15))
	# A real roulette rake lies away from the driving line.
	var rake: Node3D = ART.group(props,"DealerRake",Vector3(-60,0,-20))
	rake.rotation.y = 0.35
	ART.box(rake,"Handle",Vector3.ZERO,Vector3(26,0.14,0.22),Color("8d633b"))
	ART.box(rake,"Head",Vector3(13,0.20,0),Vector3(0.5,0.65,3.2),ART.GOLD)
	ART.collider(rake,Vector3(0,0.2,0),Vector3(27,0.4,3.4))
	ART.batch(props)

static func decks(root: Node3D, track: Node3D) -> void:
	var bridges: Node3D = ART.group(root,"ExposedTimberBridge",Vector3.ZERO)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var underside: SurfaceTool = SurfaceTool.new()
	underside.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		var section: Resource = track.definition.sections[track.section_ids[i]]
		if section.surface!="wood": continue
		var a: Vector3 = track.starts[i]
		var b: Vector3 = track.ends[i]
		var na: Vector3 = track.edge_offset(i)*section.width*0.5
		var nb: Vector3 = track.edge_offset(i+1)*section.width*0.5
		BUILDER.quad(tool,a-na,b-nb,b+nb,a+na)
		BUILDER.quad(underside,a-na-Vector3.UP*0.24,a+na-Vector3.UP*0.24,b+nb-Vector3.UP*0.24,b-nb-Vector3.UP*0.24)
		for sign: float in [-1.0,1.0]:
			BUILDER.quad(underside,a+na*sign,b+nb*sign,b+nb*sign-Vector3.UP*0.24,a+na*sign-Vector3.UP*0.24)
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ContinuousBridgeSupport"
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	bridges.add_child(body)
	BUILDER.mesh_node(bridges,"BridgeThickness",underside,Color("69432d"))
	bridges.get_node("BridgeThickness").set_meta("camera_occlusion_exempt",true)
	# Sparse trestles support the exposed bridge; none extends above its deck.
	for p: Vector3 in [Vector3(-126,8,10),Vector3(-109,8,63),Vector3(-63,8,61)]:
		var floor_y: float = (0.175962-FELT_Y)*SCALE
		ART.box(bridges,"Trestle",Vector3(p.x,(p.y+floor_y)*0.5,p.z),Vector3(1.4,p.y-floor_y,1.4),Color("513425"))
	# Small directional tokens guide the felt route without painting a continuous road.
	var tokens: Node3D = ART.group(root,"RouteTokens",Vector3.ZERO)
	for s: float in [60,128,200,264,320,track.total_length-35]:
		var data: Dictionary = track.at(s)
		var p: Vector3 = data.position
		var heading: Vector2 = track.direction(s)
		var token: Node3D = ART.group(tokens,"TurnToken",p+Vector3(-heading.y,0,heading.x)*(data.width*0.5+1.0))
		token.rotation.y = -heading.angle()
		ART.cylinder(token,"BrassToken",Vector3(0,0.035,0),0.42,0.07,ART.GOLD)
		ART.flat_text(token,"Arrow",Vector3(0,0.08,0),">",0.45,Color("241b1b"))
	ART.batch(tokens)

static func build_all() -> void:
	var definition: Resource = route()
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	var environment: Node3D = room()
	chips(environment,track)
	decks(environment,track)
	assert(ResourceSaver.save(definition,"res://tracks/game_table/definition.tres")==OK)
	definition = ResourceLoader.load("res://tracks/game_table/definition.tres","",ResourceLoader.CACHE_MODE_REPLACE)
	save_environment(environment,"res://environments/casino/blackjack.tscn")
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "game_table"
	entry.title = "Roulette Grand Prix"
	entry.cup = "Casino"
	entry.order_in_cup = 3
	entry.route = definition
	entry.environment = ResourceLoader.load("res://environments/casino/blackjack.tscn", "", ResourceLoader.CACHE_MODE_REPLACE)
	entry.preview = INTRO.preview(track,"res://tracks/game_table/preview.res")
	entry.target_lap_seconds = Vector2(45,65)
	entry.description = "Roulette salon · open felt · dealer ramp · exposed wheel-side trestle"
	assert(ResourceSaver.save(entry,"res://tracks/game_table/entry.tres")==OK)
	ResourceLoader.load("res://tracks/game_table/entry.tres","",ResourceLoader.CACHE_MODE_REPLACE)
	print("ROULETTE length=",track.total_length," gates=",track.gates.size()," revision=",definition.revision)
	environment.free()
	track.free()
