extends RefCounted
# Course lighting: one time-of-day preset drives the shared Sun and
# WorldEnvironment, and every car carries head/tail lamps for dusk and night.
# Nothing here owns scene geometry; it only tunes light and shadow settings.

const DEFAULT_TIME: String = "DAY"
const TIMES: Array[String] = ["DAWN","DAY","DUSK","NIGHT"]

# Lamp tuning for the miniature scale (one table unit is a few car lengths).
const LAMP_HEIGHT: float = 0.16
const HEAD_RANGE: float = 9.0
const HEAD_ANGLE: float = 34.0
const HEAD_ENERGY: float = 3.2
const TAIL_RANGE: float = 0.65
const TAIL_ENERGY: float = 0.18

# elevation/yaw are sun pitch (0 = horizon, 90 = overhead) and compass spin in
# degrees. "lamps" lights the vehicle head and tail lamps for that hour.
const PRESETS: Dictionary = {
	"DAWN": {"elevation": 13.0, "yaw": 68.0, "color": Color(1.0, 0.78, 0.62), "energy": 1.0,
		"ambient_color": Color(0.68, 0.63, 0.72), "ambient_energy": 0.52,
		"background": Color(0.26, 0.22, 0.30), "lamps": false},
	"DAY": {"elevation": 45.0, "yaw": -35.0, "color": Color(1.0, 0.93, 0.80), "energy": 1.2,
		"ambient_color": Color(0.74509805, 0.83137256, 0.80784315), "ambient_energy": 0.65,
		"background": Color(0.22352941, 0.24313726, 0.21568628), "lamps": false},
	"DUSK": {"elevation": 9.0, "yaw": -118.0, "color": Color(1.0, 0.58, 0.34), "energy": 0.85,
		"ambient_color": Color(0.44, 0.37, 0.48), "ambient_energy": 0.42,
		"background": Color(0.16, 0.12, 0.19), "lamps": true},
	"NIGHT": {"elevation": 26.0, "yaw": -35.0, "color": Color(0.54, 0.66, 0.95), "energy": 0.32,
		"ambient_color": Color(0.15, 0.19, 0.32), "ambient_energy": 0.30,
		"background": Color(0.03, 0.04, 0.08), "lamps": true},
}

# Courses whose artwork reads as a specific hour; everything else stays DAY.
const COURSE_TIME: Dictionary = {
	"toys_r_you": "DAWN", "carpet_cruise": "DAWN", "countertop_table": "DAWN", "cereal_slalom": "DAWN",
	"firefly_bbq": "DUSK", "rusty_nuts_workshop": "DUSK", "beach_buggies": "DUSK", "bazaar": "DUSK",
	"toys_r_asleep": "NIGHT", "moonlight_junk_heap": "NIGHT", "nighttime_noodles": "NIGHT", "desk_drawer": "NIGHT",
}

static func time_for(track_id: String) -> String:
	return str(COURSE_TIME.get(track_id, DEFAULT_TIME))

static func preset_for(time: String) -> Dictionary:
	return PRESETS.get(time, PRESETS[DEFAULT_TIME])

# Sun, ambient light and flat background for one hour of the day.
static func apply(sun: Node, world: Node, time: String) -> void:
	var preset: Dictionary = preset_for(time)
	if sun is DirectionalLight3D:
		sun.rotation_degrees = Vector3(-float(preset.elevation), float(preset.yaw), 0.0)
		sun.light_color = preset.color
		sun.light_energy = float(preset.energy)
		sun.shadow_enabled = true
		# A vehicle is only a couple of units long; a coarse bias erases the
		# contact shadow underneath it completely.
		sun.shadow_bias = 0.012
		sun.directional_shadow_max_distance = 60.0
	if world is WorldEnvironment and world.environment != null:
		var environment: Environment = world.environment
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = preset.ambient_color
		environment.ambient_light_energy = float(preset.ambient_energy)
		# The carpet course swaps in a panorama sky; leave that background alone.
		if environment.background_mode != Environment.BG_SKY:
			environment.background_color = preset.background

# One call after a course or vehicle change: applies the hour, refreshes every
# car's lamps and re-asserts shadow casting on the freshly built vehicle meshes.
static func sync(race: Node3D, track_id: String) -> void:
	if race == null: return
	var time: String = time_for(track_id)
	# Re-shade the course before the light is applied, so the scenery and the cars
	# answer to the same sun and ambient light and the cars' shadows have a
	# surface to fall on.
	shade_environment(race)
	apply(race.get_node_or_null("Sun"), race.get_node_or_null("Environment"), time)
	var lamps_on: bool = bool(preset_for(time).lamps)
	for car: Node in race.all_cars:
		if car is Node3D:
			enforce_shadows(car)
			ensure_lamps(car).visible = lamps_on

# The imported vehicle meshes must cast into the course, whatever their import.
static func enforce_shadows(car: Node3D) -> void:
	var visual: Node = car.get_node_or_null("Visual")
	if visual == null: return
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

# Imported tabletop courses are exported with every surface forced to
# SHADING_MODE_UNSHADED (see author_tabletop.gd), so the whole course ignores the
# sun, the ambient light and every shadow. That is why the course read as lit
# differently from the cars, and why the cars cast nothing onto it. Re-shading is
# idempotent: a surface that is already shaded is skipped on the next load.
static func shade_environment(race: Node3D) -> int:
	var course: Node = race.get_node_or_null("CourseEnvironment")
	if course == null: return 0
	var changed: int = 0
	for mesh: MeshInstance3D in course.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_surface_override_material(surface)
			if material == null: material = mesh.mesh.surface_get_material(surface)
			if not material is BaseMaterial3D: continue
			var base: BaseMaterial3D = material
			if base.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED: continue
			# Neon, flames, decals and glow are meant to be flat; leave them alone.
			if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
			var lit: BaseMaterial3D = base.duplicate()
			lit.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			# Imported PBR often arrives fully metallic; with no sky to reflect that
			# renders black under a single sun, so these stylised toys go matte.
			lit.metallic = 0.0
			lit.roughness = clampf(lit.roughness,0.55,1.0)
			mesh.set_surface_override_material(surface,lit)
			changed += 1
	return changed

# Lamps live on the car body, not the visual, so they survive set_class().
static func ensure_lamps(car: Node3D) -> Node3D:
	var rig: Node3D = car.get_node_or_null("VehicleLamps")
	if rig == null:
		rig = Node3D.new()
		rig.name = "VehicleLamps"
		car.add_child(rig)
	# The car faces +X locally; the collision box supplies its size and height.
	var size: Vector3 = Vector3(1.8, 0.5, 1.0)
	var height: float = LAMP_HEIGHT
	var collision: Node = car.get_node_or_null("Collision")
	if collision is CollisionShape3D and collision.shape is BoxShape3D:
		var box: BoxShape3D = collision.shape
		size = box.size
		height = maxf(collision.position.y*0.72, LAMP_HEIGHT*0.6)
	var front: float = maxf(size.x*0.5-0.02, 0.10)
	var back: float = minf(-size.x*0.5+0.02, -0.10)
	var track: float = maxf(size.z*0.30, 0.06)
	for side: float in [-1.0, 1.0]:
		var head_name: String = "HeadlightL" if side<0.0 else "HeadlightR"
		var head: SpotLight3D = rig.get_node_or_null(head_name)
		if head==null:
			head = SpotLight3D.new()
			head.name = head_name
			rig.add_child(head)
		head.position = Vector3(front, height, side*track)
		head.rotation_degrees = Vector3(0.0, -90.0, 0.0)
		head.light_color = Color(1.0, 0.96, 0.86)
		head.light_energy = HEAD_ENERGY
		head.spot_range = HEAD_RANGE
		head.spot_angle = HEAD_ANGLE
		head.shadow_enabled = false
		var tail_name: String = "TaillightL" if side<0.0 else "TaillightR"
		var tail: OmniLight3D = rig.get_node_or_null(tail_name)
		if tail==null:
			tail = OmniLight3D.new()
			tail.name = tail_name
			rig.add_child(tail)
		tail.position = Vector3(back, height*0.8, side*track)
		tail.light_color = car.get_meta("vehicle_colour",Color("ef6546"))
		tail.light_energy = TAIL_ENERGY
		tail.omni_range = TAIL_RANGE
		tail.shadow_enabled = false
	return rig

# Used by the developer overlay and by any future tunnel trigger.
static func set_lamps(race: Node3D, on: bool) -> void:
	if race == null: return
	for car: Node in race.all_cars:
		if car is Node3D: ensure_lamps(car).visible = on

static func active_time(race: Node3D) -> String:
	if race == null: return DEFAULT_TIME
	return time_for(str(race.track_id))
