extends Node3D
# Translation-invariant sky: every camera stays at its centre. No added geometry.
const PANORAMA: String = "res://environments/bedroom/stylized_room_panorama.res"
var source_bounds: AABB
var environment_node: WorldEnvironment
var original_environment: Environment
var bedroom_environment: Environment

static func measured_visual_bounds(root: Node3D) -> AABB:
	var bounds: AABB
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not node.visible: continue
		var transform: Transform3D = node.transform
		var parent: Node = node.get_parent()
		while parent != root:
			transform = parent.transform * transform
			parent = parent.get_parent()
		var box: AABB = root.transform * transform * node.get_aabb()
		bounds = box if count == 0 else bounds.merge(box)
		count += 1
	return bounds

func configure(root: Node3D, lighting: WorldEnvironment = null) -> void:
	name = "BedroomDisplay"
	source_bounds = measured_visual_bounds(root)
	if lighting != null: configure_sky(lighting)

func configure_sky(lighting: WorldEnvironment) -> void:
	environment_node = lighting
	original_environment = lighting.environment
	bedroom_environment = original_environment.duplicate()
	var panorama: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	panorama.panorama = load(PANORAMA)
	var sky: Sky = Sky.new()
	sky.sky_material = panorama
	# Keep the course's accepted light, ambient, exposure and shadow settings.
	bedroom_environment.sky = sky
	bedroom_environment.background_mode = Environment.BG_SKY
	# Orthographic course cameras otherwise stretch the sky near its poles.
	bedroom_environment.sky_custom_fov = 65.0
	lighting.environment = bedroom_environment
	tree_exiting.connect(restore_environment)

func restore_environment() -> void:
	if is_instance_valid(environment_node) and environment_node.environment == bedroom_environment:
		environment_node.environment = original_environment
