extends RefCounted
const BUILDER: Script = preload("res://scripts/tracks/track_builder.gd")
static func bar(parent: Node3D, title: String, a: Vector3, b: Vector3, colour: Color, radius: float = 0.025) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = title
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	part.mesh = mesh
	part.material_override = BUILDER.material(colour)
	parent.add_child(part)
	part.position = (a+b)*0.5
	part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func build(visual: Node3D) -> void:
	# Coral buggy, exposed ivory cage, open cockpit and chunky off-road tyres.
	for title: String in ["Cabin","RearWindow","RoofStripe","Spoiler"]: visual.get_node(title).hide()
	var cabin: MeshInstance3D = visual.get_node("Cabin")
	cabin.mesh = cabin.mesh.duplicate()
	cabin.mesh.size = Vector3(0.38,0.06,0.34)
	cabin.position.y = 0.45
	cabin.show()
	var screen: MeshInstance3D = visual.get_node("Windshield")
	screen.position = Vector3(0.12,0.54,0)
	screen.rotation.z = -0.25
	var cage: Node3D = Node3D.new()
	cage.name = "RollCage"
	visual.add_child(cage)
	for side: float in [-1.0,1.0]:
		var z: float = side*0.20
		bar(cage,"FrontPillar",Vector3(0.19,0.42,z),Vector3(0.07,0.70,z),Color("fff0cf"))
		bar(cage,"RearPillar",Vector3(-0.37,0.40,z),Vector3(-0.27,0.70,z),Color("fff0cf"))
		bar(cage,"RoofRail",Vector3(-0.27,0.70,z),Vector3(0.07,0.70,z),Color("fff0cf"))
		bar(cage,"Suspension",Vector3(-0.30,0.25,side*0.34),Vector3(-0.16,0.43,side*0.23),Color("e7ba52"),0.035)
	bar(cage,"FrontCrossbar",Vector3(0.07,0.70,-0.20),Vector3(0.07,0.70,0.20),Color("fff0cf"))
	bar(cage,"RearCrossbar",Vector3(-0.27,0.70,-0.20),Vector3(-0.27,0.70,0.20),Color("fff0cf"))
	for title: String in ["HeadA","HeadB"]:
		var lamp: MeshInstance3D = visual.get_node(title)
		var lens: SphereMesh = SphereMesh.new()
		lens.radius = 0.065
		lens.height = 0.13
		lens.radial_segments = 12
		lens.rings = 6
		lamp.mesh = lens
		lamp.position.y = 0.43
	# Open wheel arches: the swept tyres clear the chassis at full lock.
	for title: String in ["Body","Chassis"]:
		var body: MeshInstance3D = visual.get_node_or_null(title)
		if body != null:
			body.mesh = body.mesh.duplicate()
			body.mesh.size.z = 0.32
	for wheel: Node3D in visual.get_node("Wheels").get_children():
		wheel.scale = Vector3.ONE
		wheel.position.y = 0.19
		wheel.position.z = signf(wheel.position.z)*0.36
		var tire: MeshInstance3D = wheel.get_node("Tire")
		tire.mesh = tire.mesh.duplicate()
		tire.mesh.top_radius = 0.19
		tire.mesh.bottom_radius = 0.19
		wheel.get_node("Hub").material_override = BUILDER.material(Color("e7ba52"))
		# A non-circular spoke makes rotation readable at the driving distance.
		var spoke: MeshInstance3D = MeshInstance3D.new()
		spoke.name = "Spoke"
		var spoke_mesh: BoxMesh = BoxMesh.new()
		spoke_mesh.size = Vector3(0.13,0.028,0.165)
		spoke.mesh = spoke_mesh
		spoke.material_override = BUILDER.material(Color("fff0cf"))
		wheel.add_child(spoke)
	var number: Label3D = Label3D.new()
	number.name = "DriverNumber"
	number.position = Vector3(-0.08,0.87,0)
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.font_size = 40
	number.pixel_size = 0.006
	number.outline_size = 12
	number.outline_modulate = Color("121b2b")
	number.modulate = Color("fff3d6")
	visual.add_child(number)
