extends RefCounted
# Versioned local preferences. Only validated saves can replace the backup.
const SCHEMA_VERSION: int = 17
const MAX_PROFILE_BYTES: int = 8388608
const PROGRESSION: Script = preload("res://scripts/vehicles/vehicle_progression.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const VEHICLE_IDS: Array[String] = preload("res://scripts/vehicles/vehicle_catalog.gd").IDS
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
# Retained IDs validate historical records; only CATALOG.IDS may be selected.
const TRACK_IDS: Array[String] = ["blackjack","game_table","practice_patch","felt_sprint","card_bridge","cereal_slalom","plate_rim","countertop_table","carpet_cruise","desk_drawer","toybox_trestle","beach_buggies","toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","mount_rainier","topspeed_oval","bazaar","town_square"]
var path: String = "user://profile.json"
var read_only: bool = false
var status: String = ""
var data: Dictionary = defaults()

static func defaults() -> Dictionary:
	var result: Dictionary = {"schema_version":SCHEMA_VERSION,"quick_race":{"rivals":3,"difficulty":1,"laps":3,"vehicle_id":"buggy","track_id":"game_table","driver":0},"mode":"quick","vehicles":{},"records":{},"legacy_records":{},"cup":{},"cup_wins":0,"gold_livery":false,"setup":{"master":1.0,"music":1.0,"effects":1.0,"mute":false,"reduced_effects":false,"pixels":true,"width":1200,"height":800,"fullscreen":false}}
	for id: String in VEHICLE_IDS: result.vehicles[id] = PROGRESSION.fresh()
	result.wallet = {"points":0,"bling":0}
	result.freestyle_vehicle = "buggy"
	result.tournament = {}
	result.tournament_series = "toybox"
	result.tournament_wins = 0
	result.challenges = {}
	result.challenge_roadmaps = {}
	result.drift_records = {}
	result.owner_benchmarks = {}
	result.benchmark_enabled = false
	result.identity = {"name":"Player","portrait_id":0}
	result.character_colour_id = -1
	result.reward_reset_token = ""
	return result

func vehicle() -> Dictionary:
	return data.vehicles[data.quick_race.vehicle_id]

func wallet() -> Dictionary:
	return data.wallet

static func number(value: Variant, fallback: int, low: int, high: int) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return fallback
	return int(clampf(float(value),float(low),float(high)))

static func valid_display_name(value: Variant) -> bool:
	if not value is String or value.length()<1 or value.length()>9: return false
	for letter: String in value:
		if letter not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz": return false
	return true

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var version: Variant = raw.get("schema_version",0)
	if typeof(version) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(version)) or float(version)<0.0 or float(version)>SCHEMA_VERSION or float(version)!=int(version): return {}
	# Version 0 used a flat preferences object; missing fields use current defaults.
	var source: Variant = raw.get("quick_race",raw if int(version)==0 else {})
	if not source is Dictionary: return {}
	var result: Dictionary = defaults()
	result.character_colour_id = number(raw.get("character_colour_id",-1),-1,-1,7)
	if raw.get("reward_reset_token","") is String: result.reward_reset_token = raw.get("reward_reset_token","")
	var identity: Variant = raw.get("identity",{})
	if identity is Dictionary:
		if valid_display_name(identity.get("name")): result.identity.name = identity.name
		result.identity.portrait_id = number(identity.get("portrait_id",0),0,0,7)
	var settings: Dictionary = result.quick_race
	for field: String in ["rivals","difficulty","laps","driver"]:
		var limits: Dictionary = {"rivals":[0,7],"difficulty":[0,3],"laps":[1,9],"driver":[0,3]}
		settings[field] = number(source.get(field,settings[field]),settings[field],limits[field][0],limits[field][1])
	if settings.difficulty==3: settings.rivals = maxi(3,settings.rivals)
	var vehicle: Variant = source.get("vehicle_id","buggy")
	var track: Variant = source.get("track_id","blackjack")
	settings.vehicle_id = vehicle if vehicle is String and vehicle in VEHICLE_IDS else "buggy"
	settings.track_id = CATALOG.canonical_id(track) if track is String and CATALOG.canonical_id(track) in CATALOG.IDS else "game_table"
	var mode: Variant = raw.get("mode","quick")
	result.mode = mode if mode is String and mode in ["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"] else "quick"
	var free_vehicle: Variant = raw.get("freestyle_vehicle",settings.vehicle_id if result.mode=="freestyle" else "buggy")
	result.freestyle_vehicle = free_vehicle if free_vehicle is String and free_vehicle in VEHICLE_IDS else "buggy"
	result.cup_wins = number(raw.get("cup_wins",0),0,0,999999)
	result.gold_livery = raw.get("gold_livery",false)==true and result.cup_wins>0
	result.cup = preload("res://scripts/race/cup_rules.gd").validate(raw.get("cup",{}))
	var tournaments: Script = preload("res://scripts/race/tournament_rules.gd")
	result.tournament = tournaments.validate(raw.get("tournament",{}))
	var series_id: Variant = raw.get("tournament_series","toybox")
	result.tournament_series = series_id if series_id is String and not tournaments.series(series_id).is_empty() else "toybox"
	result.tournament_wins = number(raw.get("tournament_wins",0),0,0,999999)
	result.challenges = preload("res://scripts/race/challenge_rules.gd").validate(raw.get("challenges",{}))
	result.challenge_roadmaps = preload("res://scripts/race/challenge_roadmap.gd").validate(raw.get("challenge_roadmaps",{}))
	result.drift_records = preload("res://scripts/race/drift_rules.gd").validate_records(raw.get("drift_records",{}))
	result.owner_benchmarks = preload("res://scripts/race/owner_benchmark_rules.gd").validate(raw.get("owner_benchmarks",{}))
	result.benchmark_enabled = raw.get("benchmark_enabled",false)==true
	var setup: Variant = raw.get("setup",{})
	if setup is Dictionary:
		for field: String in ["master","music","effects"]:
			var value: Variant = setup.get(field,1.0)
			if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)): result.setup[field] = clampf(float(value),0.0,1.0)
		for field: String in ["mute","pixels","fullscreen","reduced_effects"]:
			if setup.get(field) is bool: result.setup[field] = setup[field]
		result.setup.width = number(setup.get("width",1200),1200,640,7680)
		result.setup.height = number(setup.get("height",800),800,480,4320)
	var vehicles: Variant = raw.get("vehicles",{})
	for id: String in VEHICLE_IDS:
		var build: Dictionary = result.vehicles[id]
		var saved: Variant = vehicles.get(id) if vehicles is Dictionary else null
		if int(version)>=7 and saved is Dictionary:
			var fields: Array[String] = STATS.OLD_FIELDS if int(version)==7 else STATS.FIELDS
			if STATS.valid_fields(saved.get("stats"),fields):
				for field: String in fields: build.stats[field] = float(saved.stats[field])
				if int(version)==7: build.stats.acceleration = 0.0
			build.points = number(saved.get("points",0),0,0,999999)
			build.bling = number(saved.get("bling",0),0,0,999999)
			var owned: Variant = saved.get("owned",[])
			if owned is Array:
				for paint: Variant in owned:
					if paint is String and paint in PROGRESSION.PAINTS and paint not in build.owned: build.owned.append(paint)
			var paint: Variant = saved.get("paint","stock")
			if paint is String and paint in build.owned: build.paint = paint
		elif int(version)<7 and id=="buggy":
			var allocations: Variant = raw.get("player_stats",{})
			var old: Variant = allocations.get(str(settings.driver)) if allocations is Dictionary else null
			if STATS.legacy_valid(old):
				for field: String in STATS.OLD_FIELDS: build.stats[field] = float(old[field])
				build.stats.acceleration = 0.0
	if int(version)<15:
		# Pool unspent historical balances once; purchased upgrades stay intact.
		for build: Dictionary in result.vehicles.values():
			result.wallet.points = mini(result.wallet.points+build.points,999999)
			result.wallet.bling = mini(result.wallet.bling+build.bling,999999)
	else:
		var saved_wallet: Variant = raw.get("wallet",{})
		if saved_wallet is Dictionary:
			result.wallet.points = number(saved_wallet.get("points",0),0,0,999999)
			result.wallet.bling = number(saved_wallet.get("bling",0),0,0,999999)
	for build: Dictionary in result.vehicles.values():
		build.points = 0
		build.bling = 0
	var records: Variant = raw.get("records",{})
	if records is Dictionary:
		for key: Variant in records:
			if not key is String or not valid_record_key(key): continue
			var record: Dictionary = validate_record(records[key])
			if not record.is_empty(): result.records[key] = record
	var history: Variant = raw.get("legacy_records",{})
	if history is Dictionary:
		for key: Variant in history:
			if not key is String or not valid_record_key(key) or not history[key] is Array: continue
			var entries: Array[Dictionary] = []
			for value: Variant in history[key]:
				var old_record: Dictionary = validate_record(value)
				if not old_record.is_empty() and old_record not in entries: entries.append(old_record)
			if not entries.is_empty(): result.legacy_records[key] = entries
	return result

func preserve_legacy(key: String, record: Dictionary) -> void:
	if record.is_empty(): return
	if not data.legacy_records.has(key): data.legacy_records[key] = []
	if record not in data.legacy_records[key]: data.legacy_records[key].append(record.duplicate(true))

func read_raw(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path): return null
	var file: FileAccess = FileAccess.open(file_path,FileAccess.READ)
	if file==null or file.get_length()>MAX_PROFILE_BYTES: return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text())!=OK: return null
	return parser.data

func load_profile() -> Dictionary:
	read_only = false
	status = ""
	var raw: Variant = read_raw(path)
	if raw is Dictionary and typeof(raw.get("schema_version")) in [TYPE_INT,TYPE_FLOAT] and float(raw.schema_version)>SCHEMA_VERSION:
		read_only = true
		status = "Newer profile version · saving disabled"
		data = defaults()
		return data
	data = validate(raw)
	if data.is_empty():
		data = validate(read_raw(path+".bak"))
		if not data.is_empty(): status = "Profile restored from backup"
		else:
			data = defaults()
			if FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"): status = "Unreadable profile · using defaults"
	apply_pending_reward_reset()
	return data

static func reset_rewards(profile: Dictionary) -> void:
	profile.wallet = {"points":0,"bling":0}
	# Preserve identity, preferences and records; reset earned/spent progression.
	for id: String in VEHICLE_IDS:
		profile.vehicles[id] = PROGRESSION.fresh()
		profile.vehicles[id].stats = STATS.portrait_starting(int(profile.identity.portrait_id))
	profile.cup_wins = 0
	profile.tournament_wins = 0
	profile.gold_livery = false
	profile.cup = {}
	profile.tournament = {}
	profile.challenges = {}
	profile.challenge_roadmaps = {}

func apply_pending_reward_reset() -> void:
	if read_only or not FileAccess.file_exists(path+".reward-reset"): return
	var token: String = FileAccess.get_file_as_string(path+".reward-reset").strip_edges()
	if token.is_empty() or data.get("reward_reset_token","")==token: return
	reset_rewards(data)
	data.reward_reset_token = token

func clear_earned_and_spent_rewards() -> Error:
	if read_only: return ERR_UNAVAILABLE
	var clean: Dictionary = validate(data)
	if clean.is_empty(): return ERR_INVALID_DATA
	var token: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var backup: String = path+".rewards-before-reset-"+token+".json"
	var file: FileAccess = FileAccess.open(backup,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(clean,"\t",true,true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error!=OK: return error
	if validate(read_raw(backup)).is_empty(): return ERR_FILE_CORRUPT
	file = FileAccess.open(path+".reward-reset.tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(token)
	file.flush()
	error = file.get_error()
	file.close()
	if error!=OK: return error
	error = DirAccess.rename_absolute(path+".reward-reset.tmp",path+".reward-reset")
	if error!=OK: return error
	# The durable marker is authoritative even if the following profile save fails.
	apply_pending_reward_reset()
	return save_profile()

func save_profile() -> Error:
	if read_only: return ERR_UNAVAILABLE
	# A running instance cannot restore pre-reset rewards from stale memory.
	apply_pending_reward_reset()
	var clean: Dictionary = validate(data)
	if clean.is_empty(): return ERR_INVALID_DATA
	var payload: String = JSON.stringify(clean,"\t",true,true)
	if payload.to_utf8_buffer().size()>MAX_PROFILE_BYTES: return ERR_OUT_OF_MEMORY
	var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(payload)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error!=OK: return error
	if validate(read_raw(path+".tmp")).is_empty(): return ERR_FILE_CORRUPT
	# Never overwrite a good backup with a corrupt primary.
	if not validate(read_raw(path)).is_empty():
		error = DirAccess.copy_absolute(path,path+".bak.tmp")
		if error!=OK: return error
		error = DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if error!=OK: return error
	error = DirAccess.rename_absolute(path+".tmp",path)
	if error==OK:
		data = clean
		status = ""
	return error

static func record_key(mode: String, laps: int, rivals: int, difficulty: int, track_id: String = "blackjack", stats_code: String = "", vehicle_id: String = "buggy") -> String:
	# Preserve existing Blackjack records while adding independent course namespaces.
	var id: String = "blackjack" if track_id=="game_table" else track_id
	return "%s|%s|%d|%s|%d|%d" % [id,vehicle_id,laps,mode,0 if mode=="trial" else rivals,0 if mode=="trial" else difficulty]+("|"+STATS.VERSION+":"+stats_code if stats_code!="" else "")

static func valid_record_key(key: String) -> bool:
	var parts: PackedStringArray = key.split("|")
	if parts.size()==7:
		var legacy: bool = parts[6].begins_with("stats-1:")
		var four_stats: bool = legacy or parts[6].begins_with("stats-2:")
		var prefix: String = "stats-1:" if legacy else ("stats-2:" if four_stats else STATS.VERSION+":")
		var fields: Array[String] = STATS.OLD_FIELDS if four_stats else STATS.FIELDS
		var allocation: PackedStringArray = parts[6].trim_prefix(prefix).split(",")
		if not parts[6].begins_with(prefix) or allocation.size()!=fields.size(): return false
		var points: Dictionary = {}
		for i: int in range(fields.size()):
			if not allocation[i].is_valid_float(): return false
			points[fields[i]] = float(allocation[i])
		if legacy:
			if not STATS.legacy_valid(points): return false
			if "%d,%d,%d,%d" % [points.grip,points.speed,points.boost,points.recovery]!=",".join(allocation): return false
		else:
			if not STATS.valid_fields(points,fields): return false
			for i: int in range(fields.size()):
				if "%.2f" % points[fields[i]]!=allocation[i]: return false
		return valid_record_key("|".join(parts.slice(0,6)))
	if parts.size()!=6 or parts[0] not in TRACK_IDS or parts[1] not in VEHICLE_IDS: return false
	if parts[3] not in ["quick","trial","freestyle","elimination","time_attack"]: return false
	for index: int in [2,4,5]:
		if not parts[index].is_valid_int() or str(int(parts[index]))!=parts[index]: return false
	if int(parts[2])<1 or int(parts[2])>9 or int(parts[4])<0 or int(parts[4])>7 or int(parts[5])<0 or int(parts[5])>3: return false
	return parts[3]!="trial" or (parts[4]=="0" and parts[5]=="0")

static func valid_hash(value: Variant) -> bool:
	if not value is String or value.length()!=64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true

static func valid_time(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0.0 and float(value)<=3600.0

static func validate_record(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	if not valid_hash(value.get("signature")) or not valid_time(value.get("total")) or not valid_time(value.get("best_lap")): return {}
	if float(value.best_lap)>float(value.total): return {}
	var replay: Variant = value.get("replay","")
	return {"signature":value.signature,"total":float(value.total),"best_lap":float(value.best_lap),"replay":replay if valid_hash(replay) else ""}


