extends Node3D
# Cosmetics only: bounded CPU emitters share meshes, contact rays run at 20 Hz,
# and existing event cooldowns remain in RaceFeedback. Four cars: <=384 particles.
const NORMAL_CAP: int = 96
const REDUCED_CAP: int = 40
const CONTACT_STEP: float = 0.05
const SMOKE: Texture2D = preload("res://assets/effects/kenney/smoke_01.png")
const SPARK: Texture2D = preload("res://assets/effects/kenney/spark_05.png")
const GLOW: Texture2D = preload("res://assets/effects/kenney/light_01.png")
var car: CharacterBody3D
var smoke_right: CPUParticles3D
var boost_trail: CPUParticles3D
var marks: Node3D
var emitters: Array[CPUParticles3D] = []
var contacts: Array[Dictionary] = []
var rear_ids: Array[int] = []
var sample_time: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var reduced: bool = false
var enabled: bool = true
var smoke_strength: float = 0.0
var dust: bool = false
static var meshes: Dictionary = {}

static func particle_mesh(kind: String, texture: Texture2D, size: Vector2, additive: bool) -> QuadMesh:
	if meshes.has(kind): return meshes[kind]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = texture
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive: mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = mat
	if not additive:
		var smoke_material: ShaderMaterial = ShaderMaterial.new()
		smoke_material.shader = preload("res://assets/effects/smoke.gdshader")
		smoke_material.set_shader_parameter("smoke_texture",texture)
		quad.material = smoke_material
	meshes[kind] = quad
	return quad

func configure(value: CharacterBody3D) -> void:
	car = value
	smoke_right = CPUParticles3D.new()
	smoke_right.name = "SmokeRight"
	add_child(smoke_right)
	boost_trail = CPUParticles3D.new()
	boost_trail.name = "BoostExhaust"
	add_child(boost_trail)
	emitters.assign([car.smoke,smoke_right,boost_trail,car.sparks,car.debris])
	for emitter: CPUParticles3D in emitters:
		emitter.emitting = false
		emitter.local_coords = false
		emitter.top_level = true
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.fixed_fps = 30
		emitter.fract_delta = true
		emitter.mesh = particle_mesh("smoke",SMOKE,Vector2(0.65,0.65),false)
	for emitter: CPUParticles3D in [car.smoke,smoke_right]:
		emitter.amount = 20
		emitter.lifetime = 0.8
		emitter.spread = 35.0
		emitter.gravity = Vector3(0,0.35,0)
		emitter.initial_velocity_min = 0.12
		emitter.initial_velocity_max = 0.45
		emitter.scale_amount_min = 0.4
		emitter.scale_amount_max = 0.7
		var size: Curve = Curve.new()
		size.max_value = 2.0
		size.add_point(Vector2(0,0.35))
		size.add_point(Vector2(0.5,1.3))
		size.add_point(Vector2(1,2.0))
		emitter.scale_amount_curve = size
		emitter.color_ramp = ramp([Color(0.88,0.9,0.92,0),Color(0.88,0.9,0.92,0.6),Color(0.78,0.81,0.85,0)],[0.0,0.12,1.0])
	boost_trail.amount = 16
	boost_trail.lifetime = 0.22
	boost_trail.mesh = particle_mesh("boost",GLOW,Vector2(0.45,0.22),true)
	boost_trail.spread = 8.0
	boost_trail.gravity = Vector3.ZERO
	boost_trail.initial_velocity_min = 1.8
	boost_trail.initial_velocity_max = 3.4
	boost_trail.scale_amount_min = 0.5
	boost_trail.scale_amount_max = 1.0
	boost_trail.color_ramp = ramp([Color(0.8,0.96,1,0.85),Color(0.18,0.62,1,0.65),Color(0.08,0.2,1,0)],[0.0,0.3,1.0])
	car.sparks.amount = 20
	car.sparks.one_shot = true
	car.sparks.explosiveness = 1.0
	car.sparks.lifetime = 0.28
	car.sparks.mesh = particle_mesh("spark",SPARK,Vector2(0.12,0.035),true)
	car.sparks.spread = 38.0
	car.sparks.gravity = Vector3(0,-3,0)
	car.sparks.color_ramp = ramp([Color(1,0.9,0.55,1),Color(1,0.4,0.12,0)],[0.0,1.0])
	car.debris.amount = 20
	car.debris.mesh = particle_mesh("landing",SMOKE,Vector2(0.28,0.28),false)
	car.debris.color_ramp = ramp([Color(0.9,0.84,0.72,0.38),Color(0.9,0.84,0.72,0)],[0.0,1.0])
	marks = preload("res://scripts/vehicles/tyre_marks.gd").new()
	marks.name = "TyreMarks"
	marks.top_level = true
	add_child(marks)
	marks.global_transform = Transform3D.IDENTITY
	refresh_class()
	set_reduced(bool(car.race.machine_settings.data.get("reduced_effects",false)))
	clear()

static func ramp(colours: Array[Color], offsets: Array[float]) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray(colours)
	gradient.offsets = PackedFloat32Array(offsets)
	return gradient

func refresh_class() -> void:
	rear_ids.clear()
	for i: int in range(car.wheels.size()):
		if car.wheels[i].position.x<0.0: rear_ids.append(i)
	break_contact()

func set_reduced(value: bool) -> void:
	reduced = value
	for emitter: CPUParticles3D in emitters: emitter.amount = 8 if value else (16 if emitter==boost_trail else 20)
	# Restart on a settings transition; particles allocated under the old budget
	# cannot remain visible and old marks cannot exceed the reduced strip cap.
	clear()

func _process(delta: float) -> void:
	if not is_instance_valid(car) or car.race.paused_race: return
	marks.age(delta)
	if reduced!=car.race.feedback.reduced(): set_reduced(car.race.feedback.reduced())
	if not enabled or car.state!=0 or car.finish_time>=0 or car.race.phase not in [2,5]: stop()

func set_paused(value: bool) -> void:
	for emitter: CPUParticles3D in emitters: emitter.speed_scale = 0.0 if value else 1.0

func break_contact() -> void:
	contacts.clear()
	marks.break_strip()
	sample_time = CONTACT_STEP
	last_position = car.global_position

func stop() -> void:
	for emitter: CPUParticles3D in [car.smoke,smoke_right,boost_trail]: emitter.emitting = false
	smoke_strength = 0.0
	break_contact()

func clear() -> void:
	stop()
	for emitter: CPUParticles3D in emitters:
		emitter.restart()
		emitter.emitting = false
		emitter.hide()
	marks.clear()

func wheel_contacts() -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for i: int in range(car.wheels.size()):
		var wheel: Node3D = car.wheels[i]
		var point: Vector3 = car.to_global(Vector3(wheel.position.x,0,wheel.position.z))
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.3,point-Vector3.UP*0.24,1,[car.get_rid()])
		var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<0.45: continue
		# Narrow rays cannot hit the lower road underneath an airborne bridge car.
		var local: Vector3 = car.race.to_local(hit.position)
		var road: Dictionary = car.track.project_3d(local,car.station)
		hits.append({"id":i,"position":hit.position,"normal":hit.normal,"road":road.supported,"surface":road.surface})
	return hits

func tick(delta: float, slip: float, speed: float, brake: float, boosting: bool, surface: String, off_road: bool) -> void:
	if reduced!=car.race.feedback.reduced(): set_reduced(car.race.feedback.reduced())
	if not enabled:
		stop()
		return
	if last_position.distance_to(car.global_position)>1.0: clear()
	last_position = car.global_position
	boost_trail.global_transform = Transform3D(car.global_basis,car.to_global(Vector3(-car.tuning.collision_size.x*0.48,0.16,0)))
	boost_trail.direction = Vector3(-1,0,0)
	boost_trail.emitting = boosting
	if boosting: boost_trail.show()
	if car.airborne or surface in ["water","puddle"]:
		car.smoke.emitting = false
		smoke_right.emitting = false
		break_contact()
		return
	dust = surface in ["sand","dirt","gravel"] or off_road
	var threshold: float = maxf(car.tuning.tyre_effect_threshold,0.01)
	var scrub: float = clampf((slip/threshold-0.65)/3.0,0,1)
	var braking: float = brake*clampf((speed-2.0)/7.0,0,1)
	smoke_strength = clampf((speed-1.0)/7.0,0,0.8) if dust else maxf(scrub,braking)
	# No tyre effect needs contact work during ordinary straight-line rolling.
	if smoke_strength<=0.06:
		car.smoke.emitting = false
		smoke_right.emitting = false
		break_contact()
		return
	sample_time += delta
	if sample_time<CONTACT_STEP: return
	sample_time = fmod(sample_time,CONTACT_STEP)
	contacts = wheel_contacts()
	for emitter_index: int in range(2):
		var emitter: CPUParticles3D = car.smoke if emitter_index==0 else smoke_right
		var contact: Dictionary = {}
		if rear_ids.size()>emitter_index:
			for hit: Dictionary in contacts:
				if hit.id==rear_ids[emitter_index]: contact = hit
		emitter.emitting = not contact.is_empty() and smoke_strength>0.06
		if not emitter.emitting: continue
		emitter.global_transform = Transform3D(Basis.IDENTITY,contact.position+contact.normal*0.035)
		emitter.direction = contact.normal
		emitter.color = Color(0.72,0.52,0.3,smoke_strength) if dust else Color(1,1,1,smoke_strength)
		emitter.scale_amount_max = lerpf(0.45,0.9,smoke_strength)
		emitter.show()
	var mark_contacts: Array[Dictionary] = []
	for hit: Dictionary in contacts:
		if hit.road and hit.surface not in ["water","puddle","sand","dirt","gravel"]: mark_contacts.append(hit)
	marks.sample(mark_contacts,maxf(scrub,braking),not dust,0.07 if car.tuning.id!="monster_truck" else 0.12,reduced)

func event(kind: StringName, strength: float, point: Vector3, normal: Vector3) -> void:
	if not enabled: return
	if reduced!=car.race.feedback.reduced(): set_reduced(car.race.feedback.reduced())
	if kind==&"impact":
		var emitter: CPUParticles3D = car.sparks
		emitter.global_transform = Transform3D(Basis.IDENTITY,point)
		emitter.direction = (normal.normalized()+Vector3.UP*0.45).normalized()
		emitter.initial_velocity_min = lerpf(0.4,1.5,strength)
		emitter.initial_velocity_max = lerpf(1.0,3.5,strength)
		emitter.color = Color(1,1,1,strength)
		emitter.show()
		emitter.restart()
		emitter.emitting = true
	elif kind==&"landing" and car.track.at(car.station).surface not in ["water","puddle"]:
		car.debris.global_transform = Transform3D(Basis.IDENTITY,point)
		car.debris.show()
		car.debris.restart()
		car.debris.emitting = true
	elif kind in [&"recovery_start",&"recovery_end"]: clear()

func diagnostic_state() -> Dictionary:
	var capacity: int = 0
	var emitting: int = 0
	for emitter: CPUParticles3D in emitters:
		capacity += emitter.amount
		if emitter.emitting: emitting += 1
	return {"capacity":capacity,"limit":REDUCED_CAP if reduced else NORMAL_CAP,"emitting":emitting,"contacts":contacts.size(),"smoke":smoke_strength,"dust":dust,"boost":boost_trail.emitting,"marks":marks.diagnostic_state()}

func tyre_active() -> bool:
	return car.smoke.emitting or smoke_right.emitting
