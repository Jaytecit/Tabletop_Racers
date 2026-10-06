extends RefCounted
const BUILDER: Script = preload("res://scripts/tracks/track_builder.gd")
const PAINT: Color = Color("ef6546")
const CREAM: Color = Color("fff0cf")
const DARK: Color = Color("263630")
const GLASS: Color = Color("225b68")

static func box(parent: Node3D, title: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = title
	node.position = position
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.material_override = BUILDER.material(color)
	parent.add_child(node)
	return node

static func wheel(parent: Node3D, title: String, position: Vector3, radius: float, width: float) -> void:
	var mount: Node3D = Node3D.new()
	mount.name = title
	mount.position = position
	parent.add_child(mount)
	for hub: bool in [false,true]:
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = "Hub" if hub else "Tire"
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = radius*(0.48 if hub else 1.0)
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = width+(0.008 if hub else 0.0)
		cylinder.radial_segments = 16
		node.mesh = cylinder
		node.rotation.x = PI*0.5
		node.material_override = BUILDER.material(Color("e7ba52") if hub else DARK)
		mount.add_child(node)
	box(mount,"Spoke",Vector3.ZERO,Vector3(radius*0.9,0.026,width+0.012),CREAM)

static func hull(parent: Node3D) -> void:
	var outline: Array[Vector2] = [Vector2(0.78,0),Vector2(0.46,-0.32),Vector2(-0.62,-0.32),Vector2(-0.72,-0.20),Vector2(-0.72,0.20),Vector2(0.46,0.32)]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var top_a: Vector3 = Vector3(a.x,0.24,a.y)
		var top_b: Vector3 = Vector3(b.x,0.24,b.y)
		var low_a: Vector3 = Vector3(a.x*0.85,0.05,a.y*0.65)
		var low_b: Vector3 = Vector3(b.x*0.85,0.05,b.y*0.65)
		for vertex: Vector3 in [top_a,top_b,Vector3(0,0.24,0),low_b,low_a,Vector3(0,0.05,0),top_a,low_a,low_b,top_a,low_b,top_b]: surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Body"
	mesh.mesh = surface.commit()
	mesh.material_override = BUILDER.material(PAINT)
	parent.add_child(mesh)

static func build(id: String) -> Node3D:
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	var wheels: Node3D = Node3D.new()
	wheels.name = "Wheels"
	visual.add_child(wheels)
	var radius: float = 0.17
	var axle: float = 0.43
	var half_track: float = 0.36
	var width: float = 0.14
	var number_height: float = 0.78
	match id:
		"monster_truck":
			radius = 0.27
			axle = 0.47
			half_track = 0.43
			width = 0.18
			number_height = 1.05
			box(visual,"Chassis",Vector3(0,0.34,0),Vector3(1.12,0.10,0.30),DARK)
			box(visual,"Body",Vector3(0,0.50,0),Vector3(1.10,0.20,0.34),PAINT)
			box(visual,"Cabin",Vector3(0.10,0.69,0),Vector3(0.42,0.26,0.32),PAINT)
			box(visual,"Windscreen",Vector3(0.316,0.69,0),Vector3(0.016,0.16,0.27),GLASS)
			box(visual,"Bed",Vector3(-0.36,0.62,0),Vector3(0.30,0.06,0.28),DARK)
			box(visual,"RoofStripe",Vector3(0.10,0.827,0),Vector3(0.42,0.014,0.08),CREAM)
		"racing_car":
			radius = 0.15
			axle = 0.45
			half_track = 0.37
			width = 0.12
			number_height = 0.70
			box(visual,"Body",Vector3(0.06,0.22,0),Vector3(1.15,0.14,0.26),PAINT)
			box(visual,"Cabin",Vector3(-0.08,0.36,0),Vector3(0.36,0.17,0.22),PAINT)
			box(visual,"Cockpit",Vector3(-0.08,0.453,0),Vector3(0.22,0.02,0.16),DARK)
			box(visual,"FrontWing",Vector3(0.68,0.14,0),Vector3(0.10,0.04,0.96),CREAM)
			box(visual,"RearWing",Vector3(-0.67,0.38,0),Vector3(0.12,0.05,0.96),CREAM)
			box(visual,"WingSupport",Vector3(-0.64,0.29,0),Vector3(0.06,0.16,0.12),DARK)
		"drift_car":
			box(visual,"Body",Vector3(0,0.27,0),Vector3(0.44,0.22,0.60),PAINT)
			box(visual,"Hood",Vector3(0.43,0.27,0),Vector3(0.42,0.14,0.30),CREAM)
			box(visual,"Trunk",Vector3(-0.43,0.29,0),Vector3(0.42,0.14,0.30),CREAM)
			box(visual,"Cabin",Vector3(-0.025,0.47,0),Vector3(0.39,0.18,0.32),PAINT)
			box(visual,"Windscreen",Vector3(0.18,0.47,0),Vector3(0.014,0.13,0.29),GLASS)
			box(visual,"RearScreen",Vector3(-0.229,0.47,0),Vector3(0.014,0.13,0.29),GLASS)
			box(visual,"Spoiler",Vector3(-0.64,0.46,0),Vector3(0.08,0.04,0.62),DARK)
		"speedboat":
			number_height = 0.75
			hull(visual)
			box(visual,"Cabin",Vector3(-0.17,0.35,0),Vector3(0.40,0.20,0.30),PAINT)
			box(visual,"Windscreen",Vector3(0.055,0.39,0),Vector3(0.02,0.15,0.32),GLASS)
			box(visual,"DeckStripe",Vector3(0.31,0.25,0),Vector3(0.39,0.014,0.09),CREAM)
			box(visual,"Rudder",Vector3(-0.75,0.20,0),Vector3(0.08,0.22,0.035),DARK)
			var prop: Node3D = Node3D.new()
			prop.name = "Propeller"
			prop.position = Vector3(-0.77,0.16,0)
			visual.add_child(prop)
			box(prop,"BladeA",Vector3.ZERO,Vector3(0.025,0.16,0.035),CREAM)
			box(prop,"BladeB",Vector3.ZERO,Vector3(0.025,0.035,0.16),CREAM)
			var skids: Node3D = Node3D.new()
			skids.name = "LandAssist"
			visual.add_child(skids)
			for side: float in [-1.0,1.0]: box(skids,"Skid"+str(side),Vector3(-0.05,0.035,side*0.21),Vector3(1.1,0.07,0.07),DARK)
	if id!="speedboat":
		for front: float in [-1.0,1.0]:
			for side: float in [-1.0,1.0]: wheel(wheels,"Wheel_%s_%s" % [front,side],Vector3(front*axle,radius,side*half_track),radius,width)
		var flotation: MeshInstance3D = box(visual,"WaterAssist",Vector3(0,0.13,0),Vector3(0.75,0.18,0.45),Color("e7ba52"))
		flotation.hide()
	for side: float in [-1.0,1.0]:
		box(visual,"TailA" if side<0 else "TailB",Vector3(-0.62,0.30,side*0.13),Vector3(0.035,0.07,0.08),Color("7b292b"))
	var number: Label3D = Label3D.new()
	number.name = "DriverNumber"
	number.text = "01"
	number.position.y = number_height
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.font_size = 40
	number.pixel_size = 0.007
	number.modulate = CREAM
	visual.add_child(number)
	return visual
