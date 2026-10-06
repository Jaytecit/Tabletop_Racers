extends CharacterBody3D
@export var tuning: Resource = preload("res://scenes/vehicles/buggy_definition.tres")
var base_tuning: Resource
var player_input: RefCounted = preload("res://scripts/vehicles/player_input.gd").new()
var ai_driver: RefCounted = preload("res://scripts/vehicles/ai_driver.gd").new()
@export var player: int = 1
@export var ai: bool = false
@export var top_speed: float = 11.0
@export var lane: float = 0.0
var race: Node3D
var track: Node3D
var heading: float = 0.0
var station: float = 0.0
var distance: float = 0.0
var laps: int = 0
var gate: int = 1
var boost: float = 100.0
var state: int = 0
var state_time: float = 0.0
var safe_position: Vector3
var safe_heading: float = 0.0
var safe_station: float = 0.0
var recovery_from: Vector3
var immunity: float = 0.0
var crashes: int = 0
var impacts: int = 0
var jumps: int = 0
var airborne: bool = false
var lift_speed: float = 0.0
var ramp_velocity: float = 0.0
var previous_ground: float = 0.0
var finish_time: float = -1.0
var collision_cooldown: float = 0.0
var boost_was_on: bool = false
var shoulder_time: float = 0.0
var surface_normal: Vector3 = Vector3.UP
var surface_presets: Dictionary = preload("res://scripts/tracks/surface_definition.gd").presets()
var recovery_target_valid: bool = false
var visual_motion: RefCounted = preload("res://scripts/vehicles/vehicle_visual_motion.gd").new()
@onready var visual: Node3D = $Visual
@onready var smoke: CPUParticles3D = $Smoke
@onready var sparks: CPUParticles3D = $Sparks
@onready var debris: CPUParticles3D = $Debris
@onready var ring: MeshInstance3D = $RecoveryRing
var wheels: Array[Node] = []
var effects: Node3D
func _ready() -> void:
	base_tuning = tuning
	top_speed = tuning.top_speed
	visual.free()
	visual = preload("res://scripts/vehicles/imported_visual.gd").build(tuning.id)
	add_child(visual)
	wheels = visual.get_node("Wheels").get_children()
	visual_motion.configure(self)
	race = get_parent()
	track = race.get_node("Track")
	effects = preload("res://scripts/vehicles/vehicle_effects.gd").new()
	effects.name = "VehicleEffects"
	add_child(effects)
	effects.configure(self)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.005
	fit_collision()

func set_class(id: String) -> bool:
	var definition: Resource = preload("res://scripts/vehicles/vehicle_catalog.gd").definition(id)
	if definition==null: return false
	if base_tuning.id==id: return true
	var replacement: Node3D = preload("res://scripts/vehicles/imported_visual.gd").build(id)
	visual.free()
	add_child(replacement)
	visual = replacement
	wheels = visual.get_node("Wheels").get_children()
	base_tuning = definition
	tuning = definition.duplicate()
	top_speed = tuning.top_speed
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = tuning.collision_size*Vector3(0.94,1.0,0.94)
	$Collision.shape = shape
	$Collision.transform = Transform3D(Basis.IDENTITY,Vector3.UP*tuning.collision_height)
	for title: String in ["TailA","TailB"]:
		visual.get_node(title).material_override = visual.get_node(title).material_override.duplicate()
	visual_motion = preload("res://scripts/vehicles/vehicle_visual_motion.gd").new()
	visual_motion.configure(self)
	if effects!=null:
		effects.clear()
		effects.refresh_class()
	return true

func fit_collision() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = tuning.collision_size*Vector3(0.94,1.0,0.94)
	$Collision.shape = shape
	align_class_collision()

func set_brake_lights(braking: bool) -> void:
	for title: String in ["TailA","TailB"]:
		var material: StandardMaterial3D = visual.get_node(title).material_override
		material.albedo_color = Color("ff392b") if braking else Color("7b292b")
		material.emission_enabled = true
		material.emission = Color("ff2414")
		material.emission_energy_multiplier = 3.5 if braking else 0.08

func permits_surface(surface: String) -> bool:
	return tuning.permits(surface,race.race_mode=="freestyle")

func align_class_collision() -> void:
	var forward: Vector3 = Vector3(cos(heading),0,sin(heading))
	var slope: float = atan2(-surface_normal.dot(forward),surface_normal.y)
	var orientation: Basis = Basis(Vector3.BACK,clampf(slope,-0.7,0.7))
	$Collision.transform = Transform3D(orientation,orientation*Vector3.UP*tuning.collision_height)

func update_surface_visuals(surface: String) -> void:
	var flotation: Node3D = visual.get_node_or_null("WaterAssist")
	if flotation==null and tuning.id=="buggy" and race.race_mode=="freestyle":
		flotation = preload("res://scripts/vehicles/class_visual.gd").box(visual,"WaterAssist",Vector3(0,0.12,0),Vector3(0.70,0.16,0.30),Color("e7ba52"))
	if flotation!=null: flotation.visible = surface=="water" and race.race_mode=="freestyle"
	var skids: Node3D = visual.get_node_or_null("LandAssist")
	if skids!=null: skids.visible = surface!="water"
func reset_car(start: float, lateral: float) -> void:
	race.developer.apply_car(self,true)
	station = fposmod(start,track.total_length)
	var point: Vector2 = track.sample(station)+track.direction(station).orthogonal()*lateral
	position = Vector3(point.x,track.sample_3d(station).y,point.y)
	heading = track.direction(station).angle()
	rotation.y = -heading
	safe_position = position
	safe_heading = heading
	safe_station = station
	distance = start-1.0
	laps = 0
	gate = 1
	boost = 100.0
	state = 0
	state_time = 0.0
	crashes = 0
	impacts = 0
	jumps = 0
	immunity = 0.0
	airborne = false
	lift_speed = 0.0
	ramp_velocity = 0.0
	previous_ground = position.y
	finish_time = -1.0
	collision_cooldown = 0.0
	boost_was_on = false
	shoulder_time = 0.0
	surface_normal = Vector3.UP
	align_class_collision()
	recovery_target_valid = false
	recovery_from = position
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 3
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.show()
	smoke.emitting = false
	sparks.emitting = false
	ring.visible = false
	ring.scale = Vector3.ONE
	ring.rotation = Vector3.ZERO
	for emitter: CPUParticles3D in [smoke,sparks,debris]:
		emitter.restart()
		emitter.emitting = false
		emitter.hide()
		emitter.speed_scale = 1.0
	visual_motion.reset()
	update_surface_visuals(track.at(station).surface)
	set_brake_lights(false)
	ai_driver.reset(self,race.race_seed)
	ai_driver.difficulty = 1 if race.race_mode=="cup" else race.difficulty
	effects.clear()
func set_paused(value: bool) -> void:
	for emitter: CPUParticles3D in [smoke,sparks,debris]: emitter.speed_scale = 0.0 if value else 1.0
	effects.set_paused(value)
# Query actual collision support, independently of the painted racing corridor.
func physical_support(at_position: Vector3) -> Dictionary:
	var origin: Vector3 = race.to_global(at_position)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin+Vector3.UP*0.25,origin-Vector3.UP*20.0,1,[get_rid()])
	var support: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not support.is_empty():
		support.position = race.to_local(support.position)
		# Heading and route normals use Race-local coordinates, while ray normals
		# are returned in world space (the app's Race node has a small tilt).
		support.normal = (race.global_transform.basis.inverse()*support.normal).normalized()
	return support

# A centre ray can miss by millimetres while both wheels on one side still
# contact asphalt. Only flat shoulders permit this bounded footprint fallback;
# exposed decks keep their point-support recovery rules.
func driving_support(at_position: Vector3, surface: Dictionary) -> Dictionary:
	var support: Dictionary = physical_support(at_position)
	if not support.is_empty() or not track.definition.imported_surface or surface.edge!="shoulder":
		return support
	var forward: Vector3 = Vector3(cos(heading),0,sin(heading))
	var lateral: Vector3 = Vector3(-forward.z,0,forward.x)
	for side: float in [-1.0,1.0]:
		var contacts: Array[Dictionary] = []
		for end: float in [-1.0,1.0]:
			var offset: Vector3 = forward*(end*tuning.collision_size.x*0.25)+lateral*(side*tuning.collision_size.z*0.25)
			var hit: Dictionary = physical_support(at_position+offset)
			if hit.is_empty() or hit.normal.y<0.7 or absf(hit.position.y-surface.position.y)>0.12:
				break
			contacts.append(hit)
		if contacts.size()==2:
			support = contacts[0]
			var normal: Vector3 = (contacts[0].normal+contacts[1].normal).normalized()
			var point: Vector3 = (contacts[0].position+contacts[1].position)*0.5
			# Evaluate the measured contact plane at the car centre, not a side ray.
			point.y -= (normal.x*(at_position.x-point.x)+normal.z*(at_position.z-point.z))/normal.y
			support.position = Vector3(at_position.x,point.y,at_position.z)
			support.normal = normal
			support.footprint = true
			return support
	return {}

func _physics_process(delta: float) -> void:
	if race.paused_race: return
	if race.phase not in [2,5] or finish_time>=0.0:
		velocity = Vector3.ZERO
		effects.stop()
		return
	if not position.is_finite() or not velocity.is_finite():
		race.fail_safe("Invalid vehicle state")
		return
	collision_cooldown = maxf(0.0,collision_cooldown-delta)
	if immunity>0.0:
		immunity = maxf(0.0,immunity-delta)
		if immunity<=0.0 and preload("res://scripts/race/race_recovery.gd").occupied(self,position): immunity = 0.1
	if state!=0:
		recover(delta)
		return
	collision_layer = 2 if immunity<=0.0 else 0
	collision_mask = 3 if immunity<=0.0 else 1
	var surface: Dictionary = track.project_3d(position,station)
	var hit: Vector2 = Vector2(surface.station,surface.distance)
	station = hit.x
	race.observe_progress(self,hit,delta)
	if state!=0 or finish_time>=0.0 or race.phase not in [2,5]: return
	surface_normal = surface.normal
	if hit.y<surface.width*0.5-0.35 and not airborne:
		safe_station = station
		var safe2: Vector2 = track.sample(station)+track.direction(station).orthogonal()*lane
		safe_position = Vector3(safe2.x,surface.position.y,safe2.y)
		safe_heading = track.direction(station).angle()
	if not permits_surface(surface.surface):
		crash(false)
		return
	var floating: bool = surface.surface=="water" and surface.distance<=surface.width*0.5
	var off_road: bool = not surface.supported and not floating
	update_surface_visuals(surface.surface)
	var support: Dictionary = driving_support(position,surface) if off_road or track.definition.imported_surface else {}
	if track.definition.imported_surface and not floating and not support.is_empty():
		surface.position.y = support.position.y
		surface_normal = support.normal
	if off_road:
		# Chalk is a racing boundary, not a ledge. Fall only without a floor,
		# or when leaving a deck that is genuinely above the floor below.
		# Leaving a deck can mark us airborne in the preceding landing check.
		# The exposed edge must still start recovery, including after touchdown
		# on the lower floor; airborne is not permission to drive under the deck.
		if support.is_empty() or (surface.edge in ["raised","guarded"] and surface.position.y>support.position.y+0.18) or (not airborne and position.y>support.position.y+0.18 and surface.position.y>support.position.y+0.18):
			set_meta("last_support_failure",{"point":str(position),"road_height":surface.position.y,"support_height":support.position.y if not support.is_empty() else -999.0,"edge":surface.edge,"airborne":airborne})
			crash(true)
			return
		shoulder_time += delta
		surface_normal = support.normal if support.collider.get_meta("supported_terrain",false) else Vector3.UP
	else: shoulder_time = 0.0
	var horizontal := Vector2(velocity.x,velocity.z)
	var speed: float = horizontal.length()
	var forward := Vector2.RIGHT.rotated(heading)
	var command: Dictionary = ai_driver.read_commands(self) if ai else player_input.read_commands(self)
	if command.reset_requested:
		crash(false)
		return
	var steer: float = command.steer
	var throttle: float = command.throttle-command.brake
	var boosting: bool = command.boost and (boost>2.0 or tuning.boost_drain==0.0) and throttle>0.0 and not off_road
	heading += steer*lerpf(tuning.steering_low,tuning.steering_high,minf(speed/maxf(top_speed,0.001),1.0))*clampf(speed/1.15,0.0,1.0)*(-1.0 if horizontal.dot(forward)<-0.3 else 1.0)*delta*(0.35 if airborne else 1.0)
	rotation.y = -heading
	forward = Vector2.RIGHT.rotated(heading)
	if boosting and not boost_was_on: race.feedback.handle_event(&"boost_start",self,1.0,global_position)
	boost_was_on = boosting
	boost = clampf(boost+(-tuning.boost_drain if boosting else tuning.boost_recharge)*delta,0.0,100.0)
	var longitudinal: float = horizontal.dot(forward)
	if throttle<0.0 and longitudinal>0.4:
		# Brake first; reverse only after slowing to a crawl.
		horizontal -= forward*minf(longitudinal,command.brake*tuning.braking*delta)
	else:
		horizontal += forward*throttle*tuning.acceleration*(tuning.boost_acceleration if boosting else 1.0)*delta
	var surface_tuning: Resource = surface_presets.get(surface.surface,surface_presets["felt"])
	horizontal *= exp(-tuning.drag*surface_tuning.drag*delta)
	var lateral: Vector2 = forward.orthogonal()
	var grip: float = lerpf(tuning.coast_grip,tuning.grip,command.throttle)*float(tuning.surface_grip.get(surface.surface,1.0))
	horizontal -= lateral*horizontal.dot(lateral)*minf(grip*surface_tuning.grip*delta,1.0)*(0.1 if airborne else 1.0)
	if horizontal.dot(forward)<-tuning.reverse_speed:
		horizontal += forward*(-tuning.reverse_speed-horizontal.dot(forward))
	var speed_limit: float = top_speed*(tuning.boost_speed if boosting else 1.0)*tuning.speed_factor(surface.surface,race.race_mode=="freestyle")
	if off_road:
		var shoulder_limit: float = top_speed*0.5
		# Brake excess speed progressively; throttle cannot beat the half-speed cap.
		speed_limit = move_toward(speed,shoulder_limit,tuning.braking*delta) if speed>shoulder_limit else shoulder_limit
	horizontal = horizontal.limit_length(speed_limit)
	var ground: float = support.position.y if off_road else surface.position.y
	if not airborne and position.y>ground+0.10:
		airborne = true
		lift_speed = maxf(ramp_velocity,0.7)
		jumps += 1
	if airborne:
		lift_speed -= 18.0*delta
	else:
		ramp_velocity = clampf((ground-previous_ground)/maxf(delta,0.001),0.0,3.0)
		position.y = ground
		lift_speed = 0.0
	previous_ground = ground
	velocity = Vector3(horizontal.x,lift_speed,horizontal.y)
	align_class_collision()
	var before: Vector3 = velocity
	move_and_slide()
	var next_surface: Dictionary = track.project_3d(position,station)
	if next_surface.surface=="water" and permits_surface("water") and next_surface.distance<=next_surface.width*0.5: next_surface.supported = true
	var next_support: Dictionary = driving_support(position,next_surface) if not next_surface.supported or track.definition.imported_surface else {}
	if track.definition.imported_surface and next_surface.surface!="water" and not next_support.is_empty(): next_surface.position.y = next_support.position.y
	var next_ground: float = next_surface.position.y if next_surface.supported else (next_support.position.y if not next_support.is_empty() else ground)
	var landing_supported: bool = next_surface.supported or not next_support.is_empty()
	var landed_on_slope: bool = false
	if airborne and lift_speed<=0.0:
		for index: int in range(get_slide_collision_count()):
			var contact: KinematicCollision3D = get_slide_collision(index)
			if contact.get_normal().y>0.6 and contact.get_collider() is StaticBody3D: landed_on_slope = true
	# A long hull/wheelbase can contact the uphill surface before its origin is
	# within 3 cm of the centre sample. That is a landing, not endless free fall.
	if airborne and landing_supported and (position.y<=next_ground+0.03 or landed_on_slope) and lift_speed<=0.0:
		visual_motion.land(clampf(-lift_speed/8.0,0.0,1.0))
		race.feedback.handle_event(&"landing",self,clampf(-lift_speed/8.0,0.0,1.0),global_position)
		position.y = next_ground
		airborne = false
		lift_speed = 0.0
		velocity.y = 0.0
	if not airborne:
		if position.y>next_ground+0.10:
			airborne = true
			lift_speed = maxf(ramp_velocity,0.7)
			jumps += 1
		else:
			position.y = next_ground
	for i in range(get_slide_collision_count()):
		var contact: KinematicCollision3D = get_slide_collision(i)
		if absf(contact.get_normal().y)>0.6: continue
		var normal: Vector3 = contact.get_normal()
		if before.dot(normal)>-0.25: continue
		resolve_impact(before,contact)
		before = velocity
	effects.tick(delta,absf(horizontal.dot(lateral)),horizontal.length(),command.brake,boosting,next_surface.surface,not next_surface.supported)
	visual_motion.tick(delta,steer)
	set_brake_lights(command.brake>0.05)
	ring.visible = immunity>0.0
	if ring.visible: ring.scale = Vector3.ONE*(1.0+sin(immunity*18.0)*0.15)
func resolve_impact(before: Vector3, contact: KinematicCollision3D) -> void:
	var normal: Vector3 = contact.get_normal()
	var other: Object = contact.get_collider()
	var incoming: Vector3 = before
	var relative: Vector3 = incoming-other.velocity if other is CharacterBody3D else incoming
	var closing: float = maxf(-relative.dot(normal),0.0)
	if other is CharacterBody3D:
		var impulse: Vector3 = normal*closing*0.55
		velocity = incoming+impulse
		other.velocity -= impulse
	else:
		# Retain tangential travel: a brush slides, a direct impact rebounds.
		velocity = incoming.slide(normal)*0.97+normal*minf(closing*0.22,3.0)
	visual_motion.impact(normal,clampf(closing/10.0,0.0,1.0))
	if collision_cooldown<=0.0:
		impacts += 1
		race.feedback.handle_event(&"impact",self,clampf(-before.dot(normal)/10.0,0.0,1.0),contact.get_position(),normal)
		collision_cooldown = 0.25

func crash(fall: bool) -> void:
	if state!=0: return
	state = 2 if fall else 1
	state_time = 0.0
	crashes += 1
	visual_motion.reset()
	var anchor: Dictionary = preload("res://scripts/race/race_recovery.gd").select_anchor(self)
	recovery_target_valid = not anchor.is_empty()
	if not anchor.is_empty():
		safe_position = anchor.position
		safe_station = anchor.station
		safe_heading = anchor.heading
	lift_speed = 0.0
	velocity = Vector3.ZERO
	set_brake_lights(false)
	collision_layer = 0
	collision_mask = 0
	smoke.emitting = false
	sparks.emitting = false
	effects.clear()
	race.feedback.handle_event(&"recovery_start",self,1.0,global_position)
func recover(delta: float) -> void:
	state_time += delta
	if state==1 or state==2:
		var t: float = clampf(state_time/(0.35/tuning.recovery_speed),0.0,1.0)
		visual.scale = Vector3.ONE*maxf(0.001,1.0-t*t)
		ring.visible = true
		ring.scale = Vector3.ONE*(1.0+t*0.3)
		if t>=1.0:
			state = 3
			state_time = 0.0
			visual.hide()
			race.play_sound("return")
	elif state==3:
		if not recovery_target_valid:
			var anchor: Dictionary = preload("res://scripts/race/race_recovery.gd").select_anchor(self)
			if anchor.is_empty():
				state_time = 0.0
				return
			safe_position = anchor.position
			safe_station = anchor.station
			safe_heading = anchor.heading
			recovery_target_valid = true
			recovery_from = position
			state_time = 0.0
		if not preload("res://scripts/race/race_recovery.gd").clear_anchor(self,safe_position,safe_heading):
			visual.hide()
			recovery_target_valid = false
			state_time = 0.0
			return
		var t: float = minf(state_time/(0.85/tuning.recovery_speed),1.0)
		position = safe_position
		heading = safe_heading
		rotation.y = -heading
		visual.rotation = Vector3.ZERO
		visual.show()
		visual.scale = Vector3.ONE*maxf(0.001,t*t*(3.0-2.0*t))
		ring.rotation.y += delta*5.0
		if t>=1.0:
			# Re-check at touchdown; another racer may have entered the target.
			if not preload("res://scripts/race/race_recovery.gd").clear_anchor(self,safe_position,safe_heading):
				var anchor: Dictionary = preload("res://scripts/race/race_recovery.gd").select_anchor(self)
				if anchor.is_empty(): return
				recovery_from = position
				safe_position = anchor.position
				safe_station = anchor.station
				safe_heading = anchor.heading
				state_time = 0.0
				return
			position = safe_position
			station = safe_station
			heading = safe_heading
			rotation.y = -heading
			velocity = Vector3(cos(heading),0,sin(heading))*2.0
			visual.rotation = Vector3.ZERO
			visual.scale = Vector3.ONE
			state = 0
			immunity = tuning.recovery_immunity
			airborne = false
			lift_speed = 0.0
			ramp_velocity = 0.0
			shoulder_time = 0.0
			previous_ground = position.y
			race.session.progress.rebase(self)
			visual_motion.reset()
			race.feedback.handle_event(&"recovery_end",self,1.0,global_position)
