extends RefCounted
# Session-only settings. The descriptor list is the menu/export contract.
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const AI: Script = preload("res://scripts/vehicles/ai_driver.gd")
const SURFACES: Script = preload("res://scripts/tracks/surface_definition.gd")
const CATALOG: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const DEFAULTS: Script = preload("res://scripts/vehicles/tuning_defaults.gd")
var race: Node3D
var edits: Dictionary = {}
var baselines: Dictionary = {}
var run_experimental: bool = false

func _init(owner: Node3D = null) -> void:
	race = owner

func active() -> bool:
	return not edits.is_empty() or not baselines.is_empty()

func vehicle_id(target: String) -> String:
	var id: String = target.trim_prefix("vehicle:")
	return id if target.begins_with("vehicle:") and id in CATALOG.IDS else ""

func target_descriptors(target: String) -> Array[Dictionary]:
	var id: String = vehicle_id(target)
	if not id.is_empty():
		var result: Array[Dictionary] = []
		for item: Dictionary in descriptors(CATALOG.definition(id)):
			if item.target!="ai": result.append(item)
		return result
	var cars: Array = targets(target)
	return descriptors(cars[0].base_tuning,cars[0].ai_driver.difficulty) if not cars.is_empty() else []

static func apply_fields(result: Resource, changes: Dictionary) -> void:
	for field: String in changes:
		var value: Variant = changes[field]
		if field.begins_with("ai.") or field.begins_with("surface."): continue
		if field=="recovery_duration": result.recovery_speed /= float(value)
		elif field.begins_with("collision_size."): result.collision_size[field.get_slice(".",1)] = value
		elif field.contains("."): result.get(field.get_slice(".",0))[field.get_slice(".",1)] = value
		else: result.set(field,value)

func baseline(base: Resource, for_ai: bool = false) -> Resource:
	var result: Resource = base.duplicate(true)
	if for_ai: apply_fields(result,DEFAULTS.AI_PHYSICS.get(base.id,{}))
	apply_fields(result,baselines.get(base.id,{}))
	return result

func combined_edits(car: CharacterBody3D) -> Dictionary:
	var result: Dictionary = baselines.get(car.base_tuning.id,{}).duplicate(true)
	result.merge(edits.get(car.player,{}),true)
	return result

static func descriptor(field: String, stock: Variant, unit: String, low: float, high: float, target: String = "physics", restart: bool = false) -> Dictionary:
	return {"field":field,"type":"bool" if stock is bool else "float","default":stock,"unit":unit,"min":low,"max":high,"target":target,"apply":"restart" if restart else "live","fine":0.01,"coarse":0.1}

static func descriptors(base: Resource, difficulty: int = 1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for field: String in ["top_speed","acceleration","braking","reverse_speed","grip","coast_grip","steering_low","steering_high","drag","boost_drain","boost_recharge","boost_speed","boost_acceleration","recovery_immunity"]:
		var stock: float = base.get(field)
		var unit: String = "m/s" if field in ["top_speed","reverse_speed"] else ("m/s²" if field in ["acceleration","braking"] else ("%/s" if field in ["boost_drain","boost_recharge"] else ("rad/s" if field.begins_with("steering") else ("s" if field=="recovery_immunity" else "factor"))))
		if field in ["grip","coast_grip","drag"]: unit = "1/s"
		result.append(descriptor(field,stock,unit,0.0,stock*(20.0 if field in ["grip","coast_grip"] else 10.0)))
	result.append(descriptor("recovery_duration",1.0,"× earned duration",0.05,20.0))
	result.append(descriptor("tyre_effect_threshold",base.tyre_effect_threshold,"× threshold",0.1,20.0,"effects"))
	result.append(descriptor("watercraft",base.watercraft,"toggle",0,1,"physics",true))
	for axis: String in ["x","y","z"]:
		var stock: float = base.collision_size[axis]
		result.append(descriptor("collision_size."+axis,stock,"m",stock*0.05,stock*5.0,"physics",true))
	for field: String in ["collision_height","traffic_half_width"]:
		var stock: float = base.get(field)
		result.append(descriptor(field,stock,"m",stock*0.05,stock*5.0,"physics",true))
	var presets: Dictionary = SURFACES.presets()
	for surface: String in presets:
		for kind: String in ["surface_speed","surface_grip"]:
			result.append(descriptor(kind+"."+surface,float(base.get(kind).get(surface,1.0)),"factor",0,10))
		for kind: String in ["grip","drag"]:
			result.append(descriptor("surface."+surface+"."+kind,float(presets[surface].get(kind)),"factor",0,10,"surface"))
	var profile: Dictionary = AI.PROFILES[clampi(difficulty,0,3)]
	for field: String in profile:
		var unit: String = {"look":"s","margin":"m","error":"rad","boost":"toggle"}.get(field,"factor")
		result.append(descriptor("ai."+field,profile[field],unit,0,10,"ai"))
	return result

func targets(target: String) -> Array:
	var id: String = vehicle_id(target)
	if not id.is_empty():
		return race.all_cars.filter(func(car: CharacterBody3D) -> bool: return car.base_tuning.id==id)
	if target=="player": return [race.all_cars[0]]
	if target=="all_ai": return race.all_cars.slice(1)
	if target.begins_with("ai_") and target.trim_prefix("ai_").is_valid_int():
		var slot: int = int(target.trim_prefix("ai_"))
		if slot>0 and slot<race.all_cars.size(): return [race.all_cars[slot]]
	return []

func set_value(target: String, field: String, value: Variant) -> bool:
	var cars: Array = targets(target)
	var id: String = vehicle_id(target)
	if not id.is_empty():
		var valid: bool = false
		for item: Dictionary in target_descriptors(target):
			if item.field!=field: continue
			valid = value is bool if item.type=="bool" else (typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and value>=item.min and value<=item.max)
		if not valid: return false
		if not baselines.has(id): baselines[id] = {}
		baselines[id][field] = value
		for car: CharacterBody3D in cars: apply_car(car)
		if race.session!=null and race.session.phase in [1,2,5]: run_experimental = true
		return true
	if cars.is_empty(): return false
	# Validate the whole batch before changing any car.
	for car: CharacterBody3D in cars:
		var found: bool = false
		for item: Dictionary in descriptors(car.base_tuning,car.ai_driver.difficulty):
			if item.field!=field: continue
			if item.target=="ai" and car.player==1: return false
			if item.type=="bool":
				if not value is bool: return false
			else:
				if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value<item.min or value>item.max: return false
			found = true
		if not found: return false
	for car: CharacterBody3D in cars:
		if not edits.has(car.player): edits[car.player] = {}
		edits[car.player][field] = value
		apply_car(car)
	if race.session!=null and race.session.phase in [1,2,5]: run_experimental = true
	return true

func reset_target(target: String) -> void:
	var id: String = vehicle_id(target)
	if not id.is_empty():
		baselines.erase(id)
		for car: CharacterBody3D in targets(target): apply_car(car)
		return
	for car: CharacterBody3D in targets(target):
		edits.erase(car.player)
		apply_car(car)

func reset_all() -> void:
	edits.clear()
	baselines.clear()
	for car: CharacterBody3D in race.all_cars: apply_car(car)

func resolved(car: CharacterBody3D) -> Resource:
	var result: Resource = STATS.compose(baseline(car.base_tuning,car.player!=1),race.active_stats() if car.player==1 else STATS.neutral())
	result.surface_speed = result.surface_speed.duplicate(true)
	result.surface_grip = result.surface_grip.duplicate(true)
	apply_fields(result,edits.get(car.player,{}))
	return result

func apply_car(car: CharacterBody3D, restarting: bool = false) -> void:
	var result: Resource = resolved(car)
	if not restarting and car.tuning!=null:
		for field: String in ["collision_size","collision_height","traffic_half_width","watercraft"]: result.set(field,car.tuning.get(field))
	car.tuning = result
	car.top_speed = result.top_speed
	car.ai_driver.overrides.clear()
	car.surface_presets = SURFACES.presets()
	var changes: Dictionary = combined_edits(car)
	for field: String in changes:
		if field.begins_with("ai."): car.ai_driver.overrides[field.trim_prefix("ai.")] = changes[field]
		elif field.begins_with("surface."):
			car.surface_presets[field.get_slice(".",1)].set(field.get_slice(".",2),changes[field])
	if restarting:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = result.collision_size*Vector3(0.94,1.0,0.94)
		car.get_node("Collision").shape = shape

func values(target: String, field: String) -> Dictionary:
	var id: String = vehicle_id(target)
	if not id.is_empty():
		for item: Dictionary in target_descriptors(target):
			if item.field!=field: continue
			var value: Variant = baselines.get(id,{}).get(field,item.default)
			var pending: bool = false
			if item.apply=="restart":
				for car: CharacterBody3D in targets(target):
					pending = pending or values("player" if car.player==1 else "ai_%d" % (car.player-1),field).restart_required
			return {"value":value,"mixed":false,"restart_required":pending}
		return {"value":null,"mixed":false,"restart_required":false}
	var first: Variant = null
	var mixed: bool = false
	var pending: bool = false
	for car: CharacterBody3D in targets(target):
		var value: Variant = null
		for item: Dictionary in descriptors(car.base_tuning,car.ai_driver.difficulty):
			if item.field==field:
				value = item.default
				var tuning: Resource = resolved(car)
				if field.begins_with("ai."): value = car.ai_driver.overrides.get(field.trim_prefix("ai."),item.default)
				elif field.begins_with("surface."): value = car.surface_presets[field.get_slice(".",1)].get(field.get_slice(".",2))
				elif field=="recovery_duration": value = float(baselines.get(car.base_tuning.id,{}).get(field,1.0))*float(edits.get(car.player,{}).get(field,1.0))
				elif field.begins_with("collision_size."): value = tuning.collision_size[field.get_slice(".",1)]
				elif field.contains("."): value = tuning.get(field.get_slice(".",0)).get(field.get_slice(".",1),1.0)
				else: value = tuning.get(field)
				if item.apply=="restart":
					var actual: Variant = car.tuning.collision_size[field.get_slice(".",1)] if field.begins_with("collision_size.") else car.tuning.get(field)
					pending = pending or actual!=value
		if first==null: first = value
		elif value!=first: mixed = true
	return {"value":first,"mixed":mixed,"restart_required":pending}
