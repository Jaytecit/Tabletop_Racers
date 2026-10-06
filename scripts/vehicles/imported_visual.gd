extends RefCounted
# Preserve the supplied originals; wheeled variants use measured axle extraction.
const MODELS: Dictionary = {
	"buggy": "res://assets/vehicles/BeachBuggy.glb",
	"monster_truck": "res://assets/vehicles/MonsterTruck.glb",
	"racing_car": "res://assets/vehicles/RacingCar.glb",
	"drift_car": "res://assets/vehicles/DriftCar.glb",
	"speedboat": "res://assets/vehicles/Sppedboat.glb",
}

const ANIMATED: Dictionary = {
	"buggy": ["BeachBuggy",0.148,0.205,0.0],
	"monster_truck": ["MonsterTruck",0.164,0.185,0.25],
	"racing_car": ["RacingCar",0.102,0.188,0.16],
	"drift_car": ["DriftCar",0.100,0.212,0.55],
}
const SCENE_CACHE_LIMIT: int = 2
static var scene_cache: Dictionary = {}
static var scene_order: Array[String] = []

static func scene_path(id: String, animate_wheels: bool = true) -> String:
	return "res://assets/vehicles/animated/%s_wheels.glb"%ANIMATED[id][0] if animate_wheels and ANIMATED.has(id) else MODELS[id]

static func retain_scene(path: String, scene: PackedScene) -> void:
	scene_cache[path] = scene
	scene_order.erase(path)
	scene_order.append(path)
	while scene_order.size() > SCENE_CACHE_LIMIT: scene_cache.erase(scene_order.pop_front())

static func source_scene(path: String) -> PackedScene:
	var scene: PackedScene = scene_cache.get(path)
	if scene == null: scene = load(path)
	retain_scene(path,scene)
	return scene

static func animated_scene(id: String) -> PackedScene:
	return source_scene(scene_path(id))

static func bounds(node: Node3D, relative: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result: AABB
	var found: bool = false
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var transform: Transform3D = relative*child.transform
		var box: AABB = transform*child.get_aabb() if child is MeshInstance3D else bounds(child,transform)
		if box.size == Vector3.ZERO: continue
		result = result.merge(box) if found else box
		found = true
	return result

static func build(id: String, animate_wheels: bool = true) -> Node3D:
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.set_meta("imported_vehicle",true)
	var animated: bool = animate_wheels and ANIMATED.has(id)
	var model: Node3D = source_scene(scene_path(id,animate_wheels)).instantiate()
	model.name = "Model"
	# Rendered front/rear views confirm the supplied GLBs face +Z; gameplay faces +X.
	model.rotation.y = 0.0 if animated else PI*0.5
	visual.add_child(model)
	var box: AABB = bounds(visual)
	var definition: Resource = preload("res://scripts/vehicles/vehicle_catalog.gd").definition(id)
	var ratio: float = minf(definition.collision_size.x*0.94/box.size.x,definition.collision_size.z*0.94/box.size.z)
	model.scale *= ratio
	model.position = Vector3(-box.get_center().x,-box.position.y,-box.get_center().z)*ratio
	var wheels: Node3D = Node3D.new()
	wheels.name = "Wheels"
	visual.add_child(wheels)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if animated and mesh.name!=&"Body":
			var mount: Node3D = Node3D.new()
			mount.name = mesh.name
			mount.position = mesh.position*ratio+model.position
			mount.set_meta("wheel_radius",float(ANIMATED[id][1])*ratio)
			mount.set_meta("max_steer",0.30 if id=="drift_car" else 0.45)
			wheels.add_child(mount)
			mesh.owner = null
			mesh.reparent(mount,false)
			mesh.name = "Tire"
			mesh.position = Vector3.ZERO
			mesh.scale = Vector3.ONE*ratio
			# Opaque inner hub covers the extraction join when the tyre turns.
			var cap: MeshInstance3D = MeshInstance3D.new()
			cap.name = "InnerHub"
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = float(ANIMATED[id][1])*ratio*0.88
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = 0.008*ratio
			cylinder.radial_segments = 32
			cap.mesh = cylinder
			cap.rotation.x = PI*0.5
			cap.position.z = (float(ANIMATED[id][2])*ratio-absf(mount.position.z))*signf(mount.position.z)
			cap.material_override = preload("res://scripts/tracks/track_builder.gd").material(Color("263630"))
			mount.add_child(cap)
		else:
			var paint: ShaderMaterial = ShaderMaterial.new()
			paint.shader = preload("res://assets/vehicles/animated/player_paint.gdshader")
			paint.set_shader_parameter("source_texture",mesh.get_active_material(0).albedo_texture)
			paint.set_shader_parameter("source_hue",float(ANIMATED[id][3]) if animated else (0.10 if id=="speedboat" else 0.0))
			paint.set_shader_parameter("protect_windows",id=="drift_car")
			paint.set_shader_parameter("hue_width",0.20 if id=="monster_truck" else 0.12)
			paint.set_shader_parameter("player_colour",Color("ef6546"))
			mesh.material_override = paint
	var fitted: AABB = bounds(visual)
	for side: float in [-1.0,1.0]:
		preload("res://scripts/vehicles/class_visual.gd").box(visual,"TailA" if side<0 else "TailB",Vector3(fitted.position.x-0.005,fitted.size.y*0.35,side*fitted.size.z*0.28),Vector3(0.015,0.035,0.045),Color("7b292b"))
	if id == "speedboat":
		var skids: Node3D = Node3D.new()
		skids.name = "LandAssist"
		visual.add_child(skids)
		for side: float in [-1.0,1.0]:
			preload("res://scripts/vehicles/class_visual.gd").box(skids,"Skid",Vector3(0,0.025,side*fitted.size.z*0.3),Vector3(fitted.size.x*0.7,0.05,0.04),Color("263630"))
	else:
		var flotation: MeshInstance3D = preload("res://scripts/vehicles/class_visual.gd").box(visual,"WaterAssist",Vector3(0,0.10,0),Vector3(fitted.size.x*0.6,0.15,fitted.size.z*0.65),Color("e7ba52"))
		flotation.hide()
	var number: Label3D = Label3D.new()
	number.name = "DriverNumber"
	number.position.y = box.size.y*ratio+0.16
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.font_size = 40
	number.pixel_size = 0.006
	number.outline_size = 12
	number.outline_modulate = Color("121b2b")
	number.modulate = Color("fff3d6")
	visual.add_child(number)
	return visual

static func paint_meshes(visual: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in visual.get_node("Model").find_children("*","MeshInstance3D",true,false): meshes.append(mesh)
	return meshes

static func set_paint(mesh: MeshInstance3D, colour: Color, metallic: float = 0.0, roughness: float = 0.8) -> void:
	if mesh.material_override is ShaderMaterial:
		mesh.material_override.set_shader_parameter("player_colour",colour)
		mesh.material_override.set_shader_parameter("paint_metallic",metallic)
		mesh.material_override.set_shader_parameter("paint_roughness",roughness)
	else:
		mesh.material_override.albedo_color = colour
		mesh.material_override.metallic = metallic
		mesh.material_override.roughness = roughness
