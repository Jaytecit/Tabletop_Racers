extends Node3D
# Reusable emitters: a world-space shower plus crisp confetti above the podium.
const PALETTE: Array[Color] = [Color("#ef6546"),Color("#4ba5c9"),Color("#ffe500"),Color("#86bb5b"),Color("#fff0cf"),Color("#c080ff")]
var race: Node3D
var overlay: Node2D
var emitters: Array[CPUParticles3D] = []
var elapsed: float = -1.0
var stage: int = 0

func _ready() -> void:
	race = get_parent()
	overlay = preload("res://race_particles.gd").new()
	overlay.name = "VictoryConfetti"
	overlay.screen_space = true
	race.get_node("HUD").add_child(overlay)
	for index: int in range(4):
		var particles: CPUParticles3D = CPUParticles3D.new()
		particles.name = "Cannon%d" % index
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.amount = 80 if index<2 else 24
		particles.lifetime = 3.8 if index<2 else 4.4
		particles.randomness = 0.3
		particles.local_coords = false
		particles.direction = Vector3(0.0,1.0,0.0)
		particles.spread = 42.0
		particles.gravity = Vector3(0.0,-2.4,0.0)
		particles.initial_velocity_min = 3.2
		particles.initial_velocity_max = 5.4
		particles.angular_velocity_min = -280.0
		particles.angular_velocity_max = 280.0
		particles.angle_min = -180.0
		particles.angle_max = 180.0
		particles.scale_amount_min = 0.09
		particles.scale_amount_max = 0.16
		var colours: Gradient = Gradient.new()
		colours.offsets = PackedFloat32Array([0.0,0.2,0.4,0.6,0.8,1.0])
		colours.colors = PackedColorArray(PALETTE)
		particles.color_initial_ramp = colours
		var fade: Gradient = Gradient.new()
		fade.offsets = PackedFloat32Array([0.0,0.75,1.0])
		fade.colors = PackedColorArray([Color.WHITE,Color.WHITE,Color(1,1,1,0)])
		particles.color_ramp = fade
		var paper: QuadMesh = QuadMesh.new()
		paper.size = Vector2(1.0,0.5 if index<2 else 2.5)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		paper.material = material
		particles.mesh = paper
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particles)
		emitters.append(particles)
	set_physics_process(false)

func start(car: CharacterBody3D) -> void:
	clear()
	global_position = car.global_position+Vector3.UP*0.25
	var side: Vector3 = Vector3(-sin(car.heading),0.0,cos(car.heading))
	for index: int in range(emitters.size()):
		emitters[index].position = side*(-1.0 if index%2==0 else 1.0)*1.25
		emitters[index].direction = (Vector3.UP-side*(0.3 if index%2==0 else -0.3)).normalized()
		emitters[index].visible = true
		emitters[index].restart()
		emitters[index].emitting = true
	elapsed = 0.0
	stage = 0
	screen_burst(110)
	set_physics_process(true)

func screen_burst(count: int) -> void:
	# The HUD uses logical 1200x800 coordinates, matching the original 2D effect.
	overlay.burst(Vector2(230,420),0.0,4,count)
	overlay.burst(Vector2(970,420),0.0,4,count)

func _physics_process(delta: float) -> void:
	if race.paused_race: return
	elapsed += delta
	if stage==0 and elapsed>=0.45:
		screen_burst(80)
		stage = 1
	if stage==1 and elapsed>=0.95:
		screen_burst(60)
		stage = 2
	if elapsed>=5.0:
		clear()

func clear() -> void:
	for particles: CPUParticles3D in emitters:
		particles.emitting = false
		particles.visible = false
		# restart() discards particles from the preceding race.
		particles.restart()
		particles.emitting = false
		particles.visible = false
	if overlay!=null: overlay.clear()
	elapsed = -1.0
	stage = 0
	set_physics_process(false)
