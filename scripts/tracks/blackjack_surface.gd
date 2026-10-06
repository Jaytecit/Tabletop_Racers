extends RefCounted
# World-space, discrete thread clusters: stable at the actual pixelated race camera.
static func felt_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/arcade/blackjack_felt.gdshader")
	return material

static func wood_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://assets/arcade/casino_wood.gdshader")
	return material

static func apply(root: Node) -> void:
	for child: Node in root.get_children():
		if child is MeshInstance3D and child.get_parent().name=="FeltTable":
			child.material_override = felt_material()
		elif child is MeshInstance3D and child.name=="TableEdge":
			child.material_override = wood_material()
		apply(child)
