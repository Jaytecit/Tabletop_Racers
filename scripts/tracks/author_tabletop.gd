@tool
extends RefCounted
# Only manifest-selected source geometry and measured boundaries are authored.
static func build(course_id: String) -> Dictionary:
	var base: String = "res://tracks/%s/" % course_id
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+"measurement_manifest.json"))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(base+"measured_route.json"))
	if rows.is_empty() or rows.size()%24!=0: return {"errors":["Invalid measured row count"]}
	var count: int = rows.size()/24
	if manifest.section_surfaces.size()!=count or manifest.section_layers.size()!=count:
		return {"errors":["Section manifest count mismatch"]}
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = course_id
	definition.revision = manifest.revision
	definition.imported_surface = true
	definition.start_station = manifest.start_station
	for i: int in range(count):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "%s_%03d" % [course_id,i]
		section.next_id = "%s_%03d" % [course_id,(i+1)%count]
		section.surface = manifest.section_surfaces[i]
		section.layer = manifest.section_layers[i]
		for j: int in range(25):
			var row: Dictionary = rows[(i*24+j)%rows.size()]
			section.left_samples.append(vector(row.left))
			section.right_samples.append(vector(row.right))
			section.center_samples.append(vector(row.center))
		section.start = section.center_samples[0]
		section.end = section.center_samples[24]
		section.before = section.start
		section.after = section.end
		section.width = section.width_at(0.5)
		definition.sections.append(section)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	if not track.validation_errors.is_empty():
		var errors: Array = Array(track.validation_errors)
		track.free()
		return {"errors":errors}
	var raw: Node3D = load("res://assets/imported/tabletop/%s.glb" % course_id).instantiate()
	var root: Node3D = Node3D.new()
	root.name = course_id.to_pascal_case()
	var meshes: Array[MeshInstance3D] = []
	var transforms: Array[Transform3D] = []
	var transform: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*manifest.transform.scale),vector(manifest.transform.offset))
	load("res://scripts/tracks/author_toys_r_you.gd").collect(raw,transform,meshes,transforms)
	var source_names: Dictionary = {}
	for source_name: String in manifest.get("imported_mesh_names",{}):
		source_names[manifest.imported_mesh_names[source_name]] = source_name
	var matched_names: Array[String] = []
	for index: int in range(meshes.size()):
		var source: MeshInstance3D = meshes[index]
		var source_name: String = source_names.get(str(source.name),str(source.name))
		if source_name not in manifest.visible_meshes and source_name not in manifest.collision_meshes:
			continue
		matched_names.append(source_name)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = source.name
		mesh.mesh = source.mesh
		mesh.transform = transforms[index]
		mesh.visible = source_name in manifest.visible_meshes
		mesh.set_meta("source_mesh_name",source_name)
		mesh.set_meta("camera_occlusion_exempt",true)
		root.add_child(mesh)
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material: Material = source.get_active_material(surface).duplicate()
			if material is BaseMaterial3D:
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.set_surface_override_material(surface,material)
		if source_name in manifest.collision_meshes:
			if manifest.get("bake_collision_transform",false):
				# Keep physics shapes at unit scale. Tiny source coordinates scaled
				# eightyfold can lose short-ray precision in concave collision.
				var faces: PackedVector3Array = mesh.mesh.get_faces()
				for face: int in range(faces.size()): faces[face] = mesh.transform*faces[face]
				var body: StaticBody3D = StaticBody3D.new()
				body.name = str(mesh.name)+"_Collision"
				if source_name in manifest.get("supported_ground_meshes",[]): body.set_meta("supported_terrain",true)
				root.add_child(body)
				var shape: CollisionShape3D = CollisionShape3D.new()
				var polygon: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
				polygon.backface_collision = source_name in manifest.get("supported_ground_meshes",[]) or source_name in manifest.get("double_sided_collision_meshes",[])
				polygon.set_faces(faces)
				shape.shape = polygon
				body.add_child(shape)
			else:
				mesh.create_trimesh_collision()
				if source_name in manifest.get("supported_ground_meshes",[]):
					for body: StaticBody3D in mesh.find_children("*","StaticBody3D",false,false):
						body.set_meta("supported_terrain",true)
						for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",false,false):
							if shape.shape is ConcavePolygonShape3D: shape.shape.backface_collision = true
	raw.free()
	for required: String in manifest.visible_meshes+manifest.collision_meshes:
		if required not in matched_names:
			root.free()
			track.free()
			return {"errors":["Selected source mesh missing from import: "+required]}
	load("res://scripts/tracks/author_toys_r_you.gd").stamp(root,root)
	var packed: PackedScene = PackedScene.new()
	var environment_path: String = "res://environments/tabletop/%s.tscn" % course_id
	assert(packed.pack(root)==OK)
	assert(ResourceSaver.save(packed,environment_path)==OK)
	packed.take_over_path(environment_path)
	assert(ResourceSaver.save(definition,base+"definition.tres")==OK)
	definition.take_over_path(base+"definition.tres")
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = course_id
	entry.title = manifest.title
	entry.cup = manifest.get("group","Tabletop")
	entry.eligible_classes = PackedStringArray([manifest.get("assigned_vehicle","buggy")])
	entry.route = definition
	entry.environment = packed
	entry.preview = load("res://scripts/tracks/author_intro_courses.gd").preview(track,base+"preview.res")
	entry.description = manifest.description
	var target: Array = manifest.get("target_lap_seconds",[30,70])
	entry.target_lap_seconds = Vector2(target[0],target[1])
	assert(ResourceSaver.save(entry,base+"entry.tres")==OK)
	var result: Dictionary = {"errors":[],"length":track.total_length,"sections":count,"meshes":matched_names.size()}
	root.free()
	track.free()
	return result

static func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
