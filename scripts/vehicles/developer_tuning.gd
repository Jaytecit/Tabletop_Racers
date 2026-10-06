extends RefCounted
# Layered developer baselines; earned driver builds always compose last.
# Legacy slot edits remain supported for diagnostic probes, but are not menu targets.
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const AI: Script = preload("res://scripts/vehicles/ai_driver.gd")
const SURFACES: Script = preload("res://scripts/tracks/surface_definition.gd")
const CATALOG: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const DEFAULTS: Script = preload("res://scripts/vehicles/tuning_defaults.gd")
var race: Node3D
var edits: Dictionary = {}
var baselines: Dictionary = {}
const CHARACTERS: Script = preload("res://scripts/profiles/character_catalog.gd")
const FACTOR_FIELDS: Array[String] = ["top_speed","acceleration","braking","reverse_speed","grip","coast_grip","steering_low","steering_high","drag","boost_drain","boost_recharge","boost_speed","boost_acceleration","recovery_immunity","recovery_duration"]
var shared_vehicle: Dictionary = {}
var shared_character: Dictionary = {}
var characters: Dictionary = {}
var overall_ai: Dictionary = {}
var storage_path: String = "user://developer-baselines.json"
var storage_status: String = "No saved developer baselines"
var saved_layers: Dictionary = {}
var run_experimental: bool = false

func _init(owner: Node3D = null, settings_path: String = "user://developer-baselines.json") -> void:
	race = owner
	storage_path = settings_path
	load_settings()

func active() -> bool:
	return not edits.is_empty() or not baselines.is_empty() or not shared_vehicle.is_empty() or not shared_character.is_empty() or not characters.is_empty() or not overall_ai.is_empty()

func vehicle_id(target: String) -> String:
	var id: String = target.trim_prefix("vehicle:")
	return id if target.begins_with("vehicle:") and id in CATALOG.IDS else ""

func character_id(target: String) -> int:
	var text: String = target.trim_prefix("character:")
	return int(text) if target.begins_with("character:") and text.is_valid_int() and int(text)>=0 and int(text)<CHARACTERS.NAMES.size() else -1

func character_for(car: CharacterBody3D) -> int:
	return CHARACTERS.portrait_for_slot(int(race.profile.data.identity.portrait_id),car.player-1)

func layer(target: String) -> Dictionary:
	if target=="shared_vehicle": return shared_vehicle
	if target=="shared_character": return shared_character
	if target=="overall_ai": return overall_ai
	var id: String = vehicle_id(target)
	if not id.is_empty(): return baselines.get(id,{})
	var character: int = character_id(target)
	if character>=0: return characters.get(str(character),{})
	return {}

func is_layer(target: String) -> bool:
	return target in ["shared_vehicle","shared_character","overall_ai"] or not vehicle_id(target).is_empty() or character_id(target)>=0

func target_descriptors(target: String) -> Array[Dictionary]:
	var id: String = vehicle_id(target)
	var result: Array[Dictionary] = []
	if not id.is_empty():
		var inherited: Resource = CATALOG.definition(id).duplicate(true)
		apply_factors(inherited,shared_vehicle)
		for item: Dictionary in descriptors(CATALOG.definition(id)):
			if item.target=="ai": continue
			if item.field in FACTOR_FIELDS or item.field.begins_with("surface_speed.") or item.field.begins_with("surface_grip."):
				item.default = field_value(inherited,item.field)
			result.append(item)
		return result
	if target in ["shared_vehicle","shared_character","overall_ai"] or character_id(target)>=0:
		for field: String in FACTOR_FIELDS:
			var inherited: float = float(shared_character.get(field,1.0)) if character_id(target)>=0 else 1.0
			result.append(descriptor(field,inherited,"x",0.05,5.0))
		if target=="shared_vehicle":
			for surface: String in SURFACES.presets():
				for kind: String in ["surface_speed","surface_grip"]:
					result.append(descriptor(kind+"."+surface,1.0,"x",0.05,5.0))
		if target=="overall_ai" or character_id(target)>=0:
			var difficulty: int = int(race.get("difficulty")) if race!=null and typeof(race.get("difficulty"))==TYPE_INT else 1
			if race!=null and race.get("race_mode")=="cup": difficulty = 1
			for item: Dictionary in descriptors(CATALOG.definition("buggy"),difficulty):
				if item.target=="ai":
					if character_id(target)>=0: item.default = overall_ai.get(item.field,item.default)
					result.append(item)
		return result
	var cars: Array = targets(target)
	return descriptors(cars[0].base_tuning,cars[0].ai_driver.difficulty) if not cars.is_empty() else []

static func field_value(resource: Resource, field: String) -> Variant:
	if field=="recovery_duration": return 1.0
	if field.begins_with("collision_size."): return resource.collision_size[field.get_slice(".",1)]
	if field.contains("."): return resource.get(field.get_slice(".",0)).get(field.get_slice(".",1),1.0)
	return resource.get(field)

static func apply_factors(resource: Resource, changes: Dictionary) -> void:
	for field: String in changes:
		if field.begins_with("ai."): continue
		var value: float = float(changes[field])
		if field=="recovery_duration": resource.recovery_speed /= value
		elif field.contains("."):
			var values: Dictionary = resource.get(field.get_slice(".",0))
			var name: String = field.get_slice(".",1)
			values[name] = float(values.get(name,1.0))*value
		else: resource.set(field,float(resource.get(field))*value)

func layers() -> Dictionary:
	return {"schema_version":1,"shared_vehicle":shared_vehicle.duplicate(true),"vehicles":baselines.duplicate(true),"shared_character":shared_character.duplicate(true),"characters":characters.duplicate(true),"overall_ai":overall_ai.duplicate(true)}

func validate_layers(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema_version")!=1 or data.size()!=6: return false
	for key: String in ["shared_vehicle","vehicles","shared_character","characters","overall_ai"]:
		if not data.get(key) is Dictionary: return false
	var pending: Dictionary = {"shared_vehicle":data.shared_vehicle,"shared_character":data.shared_character,"overall_ai":data.overall_ai}
	for id: Variant in data.vehicles:
		if not id is String or id not in CATALOG.IDS or not data.vehicles[id] is Dictionary: return false
		pending["vehicle:"+id] = data.vehicles[id]
	for id: Variant in data.characters:
		if not id is String or character_id("character:"+id)<0 or str(int(id))!=id or not data.characters[id] is Dictionary: return false
		pending["character:"+id] = data.characters[id]
	for target: String in pending:
		for field: Variant in pending[target]:
			if not field is String or not valid_value(target,field,pending[target][field]): return false
	return true

func install_layers(data: Dictionary) -> void:
	shared_vehicle = data.shared_vehicle.duplicate(true)
	baselines = data.vehicles.duplicate(true)
	shared_character = data.shared_character.duplicate(true)
	characters = data.characters.duplicate(true)
	overall_ai = data.overall_ai.duplicate(true)

func load_settings() -> Error:
	if not FileAccess.file_exists(storage_path):
		saved_layers = layers()
		return OK
	var file: FileAccess = FileAccess.open(storage_path,FileAccess.READ)
	if file==null: return FileAccess.get_open_error()
	var payload: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(payload)!=OK:
		storage_status = "Saved baselines malformed; current settings retained"
		return ERR_INVALID_DATA
	var data: Variant = parser.data
	if not validate_layers(data):
		storage_status = "Saved baselines invalid; current settings retained"
		return ERR_INVALID_DATA
	install_layers(data)
	saved_layers = layers()
	storage_status = "Saved developer baselines loaded"
	if race!=null and race.get("all_cars")!=null: refresh()
	return OK

func save_settings() -> Error:
	var data: Dictionary = layers()
	if not validate_layers(data): return ERR_INVALID_DATA
	var temporary: String = storage_path+".tmp"
	var file: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t",true,true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error==OK: error = DirAccess.rename_absolute(temporary,storage_path)
	if error!=OK and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	if error==OK:
		saved_layers = data
		storage_status = "Developer baselines saved across launches"
	return error

func dirty() -> bool:
	return layers()!=saved_layers

func valid_value(target: String, field: String, value: Variant) -> bool:
	for item: Dictionary in target_descriptors(target):
		if item.field==field:
			return value is bool if item.type=="bool" else (typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and value>=item.min and value<=item.max)
	return false

func refresh() -> void:
	if race==null: return
	for car: CharacterBody3D in race.all_cars: apply_car(car)
	if race.session!=null and race.session.phase in [1,2,5]: run_experimental = true
	if race.trial!=null and race.trial.race!=null: race.trial.refresh_signature()

func inherit_field(target: String, field: String) -> void:
	if not is_layer(target): return
	var values: Dictionary = layer(target)
	values.erase(field)
	if values.is_empty():
		baselines.erase(vehicle_id(target))
		characters.erase(str(character_id(target)))
	refresh()

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
	apply_factors(result,shared_vehicle)
	apply_fields(result,baselines.get(base.id,{}))
	if for_ai: apply_factors(result,overall_ai)
	return result

func combined_edits(car: CharacterBody3D) -> Dictionary:
	var result: Dictionary = shared_vehicle.duplicate(true)
	result.merge(baselines.get(car.base_tuning.id,{}),true)
	if car.ai: result.merge(overall_ai,true)
	result.merge(shared_character,true)
	result.merge(characters.get(str(character_for(car)),{}),true)
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
	if race==null: return []
	if target in ["shared_vehicle","shared_character"]: return race.all_cars
	if target=="overall_ai": return race.all_cars.slice(1)
	var character: int = character_id(target)
	if character>=0: return race.all_cars.filter(func(car: CharacterBody3D) -> bool: return character_for(car)==character)
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
	if is_layer(target):
		if not valid_value(target,field,value): return false
		var id: String = vehicle_id(target)
		var character: int = character_id(target)
		if not id.is_empty() and not baselines.has(id): baselines[id] = {}
		if character>=0 and not characters.has(str(character)): characters[str(character)] = {}
		layer(target)[field] = value
		refresh()
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
	if is_layer(target):
		layer(target).clear()
		baselines.erase(vehicle_id(target))
		characters.erase(str(character_id(target)))
		refresh()
		return
	for car: CharacterBody3D in targets(target):
		edits.erase(car.player)
		apply_car(car)

func reset_all() -> void:
	edits.clear()
	baselines.clear()
	shared_vehicle.clear()
	shared_character.clear()
	characters.clear()
	overall_ai.clear()
	refresh()

func character_baseline(car: CharacterBody3D) -> Resource:
	var character_base: Resource = baseline(car.base_tuning,car.player!=1)
	var modifiers: Dictionary = shared_character.duplicate(true)
	modifiers.merge(characters.get(str(character_for(car)),{}),true)
	apply_factors(character_base,modifiers)
	return character_base

func resolved(car: CharacterBody3D) -> Resource:
	var result: Resource = STATS.compose(character_baseline(car),race.active_stats() if car.player==1 else STATS.neutral())
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
	if is_layer(target):
		for item: Dictionary in target_descriptors(target):
			if item.field!=field: continue
			var changes: Dictionary = layer(target)
			var pending: bool = false
			if item.apply=="restart":
				for car: CharacterBody3D in targets(target):
					pending = pending or values("player" if car.player==1 else "ai_%d" % (car.player-1),field).restart_required
			return {"value":changes.get(field,item.default),"inherited":item.default,"overridden":changes.has(field),"mixed":false,"restart_required":pending}
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
				elif field=="recovery_duration": value = car.base_tuning.recovery_speed/character_baseline(car).recovery_speed*float(edits.get(car.player,{}).get(field,1.0))
				elif field.begins_with("collision_size."): value = tuning.collision_size[field.get_slice(".",1)]
				elif field.contains("."): value = tuning.get(field.get_slice(".",0)).get(field.get_slice(".",1),1.0)
				else: value = tuning.get(field)
				if item.apply=="restart":
					var actual: Variant = car.tuning.collision_size[field.get_slice(".",1)] if field.begins_with("collision_size.") else car.tuning.get(field)
					pending = pending or actual!=value
		if first==null: first = value
		elif value!=first: mixed = true
	return {"value":first,"mixed":mixed,"restart_required":pending}
