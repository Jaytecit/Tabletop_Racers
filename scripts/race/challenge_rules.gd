extends RefCounted
const VERSION: String = "achievements-2"
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
const VEHICLES: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")

static func context_key(context: Dictionary) -> String:
	return (VERSION+"|"+str(int(context.get("driver",-1)))+"|"+str(context.get("course",""))+"|"+str(context.get("vehicle",""))+"|"+str(int(context.get("laps",0)))+"|"+str(context.get("stats",""))+"|"+str(context.get("signature",""))).sha256_text()

static func valid_context(value: Variant) -> bool:
	if not value is Dictionary: return false
	var driver: Variant = value.get("driver")
	if typeof(driver) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(driver)) or driver!=int(driver) or driver<0 or driver>3: return false
	if value.get("course") not in CATALOG.IDS or value.get("vehicle") not in VEHICLES.IDS: return false
	var laps: Variant = value.get("laps")
	if typeof(laps) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(laps)) or float(laps)!=int(laps) or laps<1 or laps>9: return false
	var signature: Variant = value.get("signature")
	if not signature is String or signature.length()!=64: return false
	for character: String in signature:
		if character not in "0123456789abcdef": return false
	var stats: Variant = value.get("stats")
	if not stats is String or not stats.begins_with(STATS.VERSION+":"): return false
	var values: PackedStringArray = stats.trim_prefix(STATS.VERSION+":").split(",")
	if values.size()!=STATS.FIELDS.size(): return false
	var build: Dictionary = {}
	for index: int in range(values.size()):
		if not values[index].is_valid_float(): return false
		build[STATS.FIELDS[index]] = values[index].to_float()
	return STATS.valid(build) and STATS.VERSION+":"+STATS.code(build)==stats

static func validate(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary: return clean
	for key: Variant in raw:
		var row: Variant = raw[key]
		if not key is String or not valid_context(row) or context_key(row)!=key: continue
		var best: Variant = row.get("best_time")
		if typeof(best) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(best)) or best<=0.0 or best>3600.0: continue
		if not row.get("finish") is bool or not row.get("clean") is bool or not row.get("medal") is bool: continue
		if not row.finish or (row.medal and not row.clean): continue
		clean[key] = {"driver":int(row.driver),"course":row.course,"vehicle":row.vehicle,"laps":int(row.laps),"stats":row.stats,"signature":row.signature,"finish":true,"clean":row.clean,"medal":row.medal,"best_time":float(best)}
	return clean

static func award(records: Dictionary, context: Dictionary, run: Dictionary, target: float) -> Array[String]:
	var earned: Array[String] = []
	if not valid_context(context) or run.get("test_build",false) or run.get("ai",false): return earned
	if not run.get("finished",false) or not run.get("ordered_laps",false) or int(run.get("laps",0))!=int(context.laps): return earned
	var elapsed: float = float(run.get("time",0.0))
	if not is_finite(elapsed) or elapsed<=0.0 or elapsed>3600.0: return earned
	var clean_run: bool = int(run.get("crashes",0))==0 and int(run.get("impacts",0))==0 and int(run.get("missed_gates",0))==0 and float(run.get("penalty",0.0))==0.0
	var medal: bool = clean_run and is_finite(target) and target>0.0 and elapsed<=target
	var key: String = context_key(context)
	var previous: Dictionary = records.get(key,{})
	var row: Dictionary = context.duplicate(true)
	for name: String in ["finish","clean","medal"]:
		var achieved: bool = true if name=="finish" else (clean_run if name=="clean" else medal)
		row[name] = bool(previous.get(name,false)) or achieved
		if achieved and not previous.get(name,false): earned.append(name)
	row.best_time = minf(float(previous.get("best_time",elapsed)),elapsed)
	records[key] = row
	return earned
