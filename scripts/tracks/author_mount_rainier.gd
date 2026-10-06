@tool
extends RefCounted
static func build() -> Dictionary:
	return load("res://scripts/tracks/author_tabletop.gd").build("mount_rainier")

static func add_ground_collision() -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/mount_rainier/measurement_manifest.json"))
	if FileAccess.get_sha256("res://assets/imported/tabletop/mount_rainier.glb")!=manifest.source_sha256: return {"errors":["Source hash changed"]}
	var path: String = "res://environments/tabletop/mount_rainier.tscn"
	var root: Node3D = load(path).instantiate()
	var added: Array[String] = []
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var source: String = mesh.get_meta("source_mesh_name","")
		if source not in manifest.supported_ground_meshes and source not in manifest.get("barrier_collision_meshes",[]): continue
		if mesh.find_children("*","StaticBody3D",false,false).is_empty(): mesh.create_trimesh_collision()
		for body: StaticBody3D in mesh.find_children("*","StaticBody3D",false,false):
			body.set_meta("supported_terrain",source in manifest.supported_ground_meshes)
			body.set_meta("source_mesh_name",source)
			for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",false,false):
				if shape.shape is ConcavePolygonShape3D: shape.shape.backface_collision = true
		added.append(source)
	if added.size()!=manifest.supported_ground_meshes.size()+manifest.get("barrier_collision_meshes",[]).size():
		root.free()
		return {"errors":["A selected ground primitive is missing"]}
	load("res://scripts/tracks/author_toys_r_you.gd").stamp(root,root)
	var packed: PackedScene = PackedScene.new()
	var error: Error = packed.pack(root)
	if error==OK: error = ResourceSaver.save(packed,path)
	root.free()
	return {"errors":[] if error==OK else [error_string(error)],"meshes":added}
