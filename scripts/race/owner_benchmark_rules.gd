extends RefCounted
const VERSION: String = "owner-baseline-1"
const LAPS: int = 3
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const CONTEXT: Script = preload("res://scripts/race/challenge_rules.gd")

static func context_matches(a: Dictionary, b: Dictionary) -> bool:
	for field: String in ["course","vehicle","laps","stats","signature"]:
		if a.get(field)!=b.get(field): return false
	return true

static func record(raw: Variant) -> Dictionary:
	if not CONTEXT.valid_context(raw) or raw.get("owner")!=true or raw.get("clean")!=true or raw.laps!=LAPS: return {}
	if raw.stats!=STATS.VERSION+":"+STATS.code(STATS.neutral()): return {}
	var elapsed: Variant = raw.get("time")
	if typeof(elapsed) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(elapsed)) or elapsed<=0.0 or elapsed>3600.0: return {}
	var stamp: Variant = raw.get("recorded_utc")
	if not stamp is String or stamp.length()<19 or stamp.length()>32: return {}
	return {"owner":true,"clean":true,"driver":int(raw.driver),"course":raw.course,"vehicle":raw.vehicle,"laps":int(raw.laps),"stats":raw.stats,"signature":raw.signature,"time":float(elapsed),"recorded_utc":stamp}

static func validate(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary: return clean
	for id: Variant in raw:
		var value: Variant = raw[id]
		if not id is String or not value is Dictionary: continue
		var current: Dictionary = record(value.get("current"))
		if current.is_empty() or current.course!=id: continue
		var history: Array[Dictionary] = []
		if value.get("history") is Array:
			for old: Variant in value.history:
				var previous: Dictionary = record(old)
				if not previous.is_empty() and previous.course==id and previous not in history: history.append(previous)
		clean[id] = {"current":current,"history":history}
	return clean

static func designate(records: Dictionary, candidate: Dictionary) -> bool:
	var clean: Dictionary = record(candidate)
	if clean.is_empty(): return false
	var old: Dictionary = records.get(clean.course,{})
	if not old.is_empty() and context_matches(old.current,clean) and old.current.time<=clean.time: return false
	var history: Array = old.get("history",[]).duplicate(true)
	if not old.is_empty(): history.append(old.current.duplicate(true))
	records[clean.course] = {"current":clean,"history":history}
	return true
