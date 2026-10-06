extends RefCounted
# Opt-in proof only; the production model remains unchanged.
static func build(colour: Color) -> Node3D:
	var factory: Script = preload("res://scripts/vehicles/imported_visual.gd")
	var visual: Node3D = factory.build("buggy",false)
	var original: Node3D = visual.get_node("Model")
	var ratio: float = original.scale.x
	var offset: Vector3 = original.position
	original.free()
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_file("res://assets/vehicles/prototypes/BeachBuggy_wheel_proof.glb",state)
	assert(error==OK)
	var model: Node3D = document.generate_scene(state)
	model.name = "Model"
	visual.add_child(model)
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = preload("res://assets/vehicles/prototypes/buggy_player_paint.gdshader")
	var wheels: Node3D = visual.get_node("Wheels")
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name == &"Body":
			paint.set_shader_parameter("source_texture",mesh.get_active_material(0).albedo_texture)
			paint.set_shader_parameter("player_colour",colour)
			mesh.material_override = paint
		else:
			var mount: Node3D = Node3D.new()
			mount.name = mesh.name
			mount.position = mesh.position*ratio+offset
			mount.set_meta("wheel_radius",0.148*ratio)
			wheels.add_child(mount)
			mesh.owner = null
			mesh.reparent(mount,false)
			mesh.name = "Tire"
			mesh.position = Vector3.ZERO
			mesh.scale = Vector3.ONE*ratio
	model.scale = Vector3.ONE*ratio
	model.position = offset
	return visual
