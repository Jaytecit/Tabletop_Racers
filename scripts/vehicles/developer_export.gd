extends RefCounted
const MODEL: Script = preload("res://scripts/vehicles/developer_tuning.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const VISUALS: Script = preload("res://scripts/vehicles/imported_visual.gd")

static func finite(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR3: return value.is_finite()
		TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
		TYPE_ARRAY:
			for item: Variant in value:
				if not finite(item): return false
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not finite(value[key]): return false
	return true

static func plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3: return [value.x,value.y,value.z]
		TYPE_COLOR: return [value.r,value.g,value.b,value.a]
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value: result[str(key)] = plain(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item: Variant in value: result.append(plain(item))
			return result
		TYPE_OBJECT: return value.resource_path if value is Resource else null
	return value

static func tuning(resource: Resource) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name] = resource.get(property.name)
	return result

static func visual_dimensions(car: CharacterBody3D) -> Vector3:
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in car.visual.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node
		if mesh.mesh==null: continue
		var box: AABB = (car.visual.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds.size

static func controls(race: Node3D) -> Dictionary:
	var result: Dictionary = {"camera_mode":race.camera_driver.mode,"pad_select":race.controls_setup.select_button,"pad_boost":race.controls_setup.boost_button,"keyboard":{}}
	for action: String in race.controls_setup.ACTIONS:
		var bindings: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			bindings.append(event.as_text())
		result.keyboard[action] = bindings
	return result

static func snapshot(race: Node3D) -> Dictionary:
	race.identities.refresh_identity()
	var result: Dictionary = {"schema_version":3,"experimental":race.experimental(),"vehicle_baselines":{},"settings":{},"racers":[],"vehicle_definitions":{},"context":{
		"game":preload("res://scripts/race/game_brand.gd").NAME,"game_version":ProjectSettings.get_setting("application/config/version","development"),
		"engine_version":Engine.get_version_info().string,"handling_version":race.player_car.base_tuning.HANDLING_VERSION,"stats_version":STATS.VERSION,
		"course_id":race.track_id,"course_resource":race.track.definition.resource_path,"route_revision":race.track.definition.revision,"route_signature":race.trial.signature,
		"mode":race.race_mode,"laps":race.race_laps,"rivals":race.rival_count,"difficulty":race.difficulty,"race_seed":race.race_seed,
		"profile_id":race.active_profile_id,"identity":race.profile.data.identity.duplicate(true),"setup":race.machine_settings.data.duplicate(true),
		"stat_test_mode":race.stats_test_mode,"benchmark_enabled":race.benchmark.active(),"time_attack":race.session.time_attack_settings.duplicate(true),
		"tournament_series":race.profile.data.tournament_series,"phase":race.phase,"paused":race.paused_race,"controls":controls(race)}}
	result.baseline_layers = race.developer.layers()
	result.composition_order = ["factory vehicle / accepted AI factory compensation","shared vehicle multipliers","individual vehicle overrides","overall AI physics multipliers (AI only)","shared character modifiers / individual character overrides","driver upgrade build"]
	result.character_baselines = {}
	for character: int in range(MODEL.CHARACTERS.NAMES.size()):
		result.character_baselines[str(character)] = {"name":MODEL.CHARACTERS.NAMES[character],"overrides":race.developer.characters.get(str(character),{}).duplicate(true)}
	for id: String in MODEL.CATALOG.IDS:
		result.vehicle_baselines[id] = {"overrides":race.developer.baselines.get(id,{}).duplicate(true),"properties":tuning(race.developer.baseline(MODEL.CATALOG.definition(id)))}
	if race.course.entry!=null:
		result.context.course_entry = race.course.entry.resource_path
		result.context.course_environment = race.course.entry.environment.resource_path
		var sources: Array[String] = []
		var scene: SceneState = race.course.entry.environment.get_state()
		for index: int in range(scene.get_node_count()):
			var instance: PackedScene = scene.get_node_instance(index)
			if instance!=null and not instance.resource_path.is_empty(): sources.append(instance.resource_path)
		result.context.course_visual_sources = sources
	var route_surfaces: Dictionary = {}
	for section: Resource in race.track.definition.sections: route_surfaces[section.surface] = true
	for car: CharacterBody3D in race.all_cars:
		var id: String = car.base_tuning.id
		var derived: Resource = STATS.compose(race.developer.character_baseline(car),race.active_stats() if car.player==1 else STATS.neutral())
		var requested: Resource = race.developer.resolved(car)
		var row: Dictionary = {"slot":car.player-1,"active":car in race.cars,"ai":car.ai,"vehicle_id":id,"identity":race.identities.racers[car.player].duplicate(true),
			"base":tuning(car.base_tuning),"derived":tuning(derived),"effective":tuning(car.tuning),"requested":tuning(requested),
			"earned_build":race.profile.data.vehicles[id].duplicate(true) if car.player==1 else STATS.neutral(),
			"ai_difficulty":car.ai_driver.difficulty,"ai_seed":race.race_seed+car.player*104729,"ai_profile":car.ai_driver.PROFILES[clampi(car.ai_driver.difficulty,0,3)].duplicate(true),
			"settings":{},"surfaces":{},"character_id":race.developer.character_for(car),"overrides":race.developer.combined_edits(car)}
		row.ai_profile.merge(car.ai_driver.overrides,true)
		for surface: String in car.surface_presets: row.surfaces[surface] = tuning(car.surface_presets[surface])
		var target: String = "player" if car.player==1 else "ai_%d" % (car.player-1)
		for item: Dictionary in MODEL.descriptors(car.base_tuning,car.ai_driver.difficulty):
			var state: Dictionary = race.developer.values(target,item.field)
			var setting: Dictionary = item.duplicate(true)
			setting.merge({"value":state.value,"active":car in race.cars and (item.target!="ai" or car.ai),"overridden":row.overrides.has(item.field),"restart_required":state.restart_required})
			if item.field.begins_with("surface"):
				var surface: String = item.field.get_slice(".",1)
				setting.active = setting.active and route_surfaces.has(surface)
				if item.field.begins_with("surface_speed.") and race.race_mode=="freestyle" and ((car.tuning.watercraft and surface!="water") or (not car.tuning.watercraft and surface=="water")): setting.active = false
			row.settings[item.field] = setting
			if not result.settings.has(item.field): result.settings[item.field] = {}
			result.settings[item.field][str(car.player-1)] = setting
		result.racers.append(row)
		result.vehicle_definitions[id] = {"resource_path":car.base_tuning.resource_path,"source_visual":VISUALS.MODELS[id],"runtime_visual":VISUALS.scene_path(id),
			"collision_dimensions":car.base_tuning.collision_size,"visual_dimensions":visual_dimensions(car),"properties":tuning(car.base_tuning)}
	return result

static func write(race: Node3D, path: String) -> Error:
	var data: Dictionary = snapshot(race)
	if not finite(data): return ERR_INVALID_DATA
	var payload: String = JSON.stringify(plain(data),"\t",true,true)
	if not JSON.parse_string(payload) is Dictionary: return ERR_INVALID_DATA
	var temporary: String = path+".tmp"
	var file: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(payload)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error==OK: error = DirAccess.rename_absolute(temporary,path)
	if error!=OK and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	return error
