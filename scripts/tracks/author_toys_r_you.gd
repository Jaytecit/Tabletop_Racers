@tool
extends RefCounted
# Initial seed coordinates were traced in an orthographic 132-unit view.
# The measured route is reapplied after this seed; the model supplies road artwork.
const PIXELS: Array = [[200,555],[200,700],[202,825],[230,880],[315,928],[352,887],[395,827],[445,806],[500,815],[545,860],[570,930],[590,985],[640,1000],[720,980],[780,927],[835,845],[900,750],[949,660],[935,607],[882,562],[804,543],[747,511],[722,464],[737,405],[758,336],[738,282],[675,231],[607,184],[531,205],[445,236],[430,270],[455,311],[510,374],[565,440],[565,495],[550,542],[563,593],[580,675],[603,752],[657,805],[722,812],[772,780],[780,727],[750,679],[700,653],[610,655],[515,664],[420,670],[350,653],[320,603],[316,519],[316,438],[314,377],[292,344],[253,338],[216,356],[204,411],[201,475]]
static func build() -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "ToysRYou"
	var raw: Node3D = load("res://assets/imported/tabletop/toys_r_you.glb").instantiate()
	var transforms: Array[Transform3D] = []
	var meshes: Array[MeshInstance3D] = []
	collect(raw,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*40),Vector3(-44,0,-7.2)),meshes,transforms)
	var road_faces: Array[PackedVector3Array] = []
	for index: int in range(meshes.size()):
		var source: MeshInstance3D = meshes[index]
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = source.name
		mesh.mesh = source.mesh
		mesh.transform = transforms[index]
		root.add_child(mesh)
		mesh.visible = not "collide" in str(source.name)
		mesh.set_meta("camera_occlusion_exempt",true)
		for surface: int in range(mesh.mesh.get_surface_count()):
			var mat: BaseMaterial3D = source.get_active_material(surface).duplicate()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.set_surface_override_material(surface,mat)
		mesh.create_trimesh_collision()
		if mesh.visible and not "banner" in str(mesh.name):
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			for i: int in range(faces.size()): faces[i] = transforms[index]*faces[i]
			road_faces.append(faces)
	raw.free()
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = "toys_r_you"
	definition.revision = 1
	definition.imported_surface = true
	definition.start_station = 0.0
	var points: Array[Vector3] = []
	for i: int in range(PIXELS.size()):
		var p: Vector3 = Vector3((PIXELS[i][0]-600)*0.11,0,(PIXELS[i][1]-600)*0.11)
		if i!=37:
			p.y = height_at(p,road_faces)
		points.append(p)
	for i: int in range(points.size()):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "toys_%02d" % i
		section.next_id = "toys_%02d" % ((i+1)%points.size())
		section.start = points[i]
		section.end = points[(i+1)%points.size()]
		section.before = points[posmod(i-1,points.size())]
		section.after = points[(i+2)%points.size()]
		section.curved = true
		section.width = 4.8
		section.surface = "wood"
		section.layer = 1 if i in [44,45,46,47] else 0
		var heights: PackedFloat32Array = []
		for step: int in range(25):
			var p: Vector3 = section.point(float(step)/24.0)
			heights.append(0.0 if i in [36,37,57] else height_at(Vector3(p.x,0,p.z),road_faces))
		section.height_samples = heights
		definition.sections.append(section)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	if not track.validation_errors.is_empty():
		var errors: Array = track.validation_errors.duplicate()
		root.free()
		track.free()
		return {"errors":errors}
	DirAccess.make_dir_recursive_absolute("res://tracks/toys_r_you")
	DirAccess.make_dir_recursive_absolute("res://environments/tabletop")
	stamp(root,root)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root)==OK)
	assert(ResourceSaver.save(packed,"res://environments/tabletop/toys_r_you.tscn")==OK)
	packed.take_over_path("res://environments/tabletop/toys_r_you.tscn")
	assert(ResourceSaver.save(definition,"res://tracks/toys_r_you/definition.tres")==OK)
	definition.take_over_path("res://tracks/toys_r_you/definition.tres")
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = definition.id
	entry.title = "Toys R You"
	entry.cup = "Tabletop"
	entry.route = definition
	entry.environment = packed
	entry.preview = load("res://scripts/tracks/author_intro_courses.gd").preview(track,"res://tracks/toys_r_you/preview.res")
	entry.description = "Toy-room circuit · winding ramps and bridge"
	entry.target_lap_seconds = Vector2(40,75)
	assert(ResourceSaver.save(entry,"res://tracks/toys_r_you/entry.tres")==OK)
	var result: Dictionary = {"length":track.total_length,"sections":points.size(),"meshes":meshes.size(),"errors":[]}
	root.free()
	track.free()
	if FileAccess.file_exists("res://tracks/toys_r_you/measured_route.json"):
		var aligned: Dictionary = load("res://scripts/tracks/align_toys_r_you.gd").apply_measurement()
		result.merge(aligned,true)
	return result

static func collect(node: Node, parent: Transform3D, meshes: Array[MeshInstance3D], transforms: Array[Transform3D]) -> void:
	var t: Transform3D = parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D:
		meshes.append(node)
		transforms.append(t)
	for child: Node in node.get_children(): collect(child,t,meshes,transforms)

static func height_at(p: Vector3, arrays: Array[PackedVector3Array]) -> float:
	var result: float = 0.0
	for faces: PackedVector3Array in arrays:
		for i: int in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(p+Vector3.UP*4.0,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
			if hit!=null: result = maxf(result,hit.y)
	return result

static func stamp(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		stamp(child,root)
