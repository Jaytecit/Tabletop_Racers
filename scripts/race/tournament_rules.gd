extends RefCounted
# Active series are separate from the preserved, retired Casino Cup save data.
const VERSION: String = "tour-v1"
const LEGACY: Script = preload("res://scripts/race/cup_rules.gd")
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
const SERIES: Array[Dictionary] = [
	{"id":"toybox","title":"TOYBOX TROPHY","courses":["toys_r_you","toys_r_asleep","game_table"]},
	{"id":"after_hours","title":"AFTER HOURS TOUR","courses":["rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles"]},
	{"id":"road","title":"ROAD MASTERS","courses":["mount_rainier","topspeed_oval"]}
]
const LAPS: int = 3
const DIFFICULTY: int = 1

static func series(id: String) -> Dictionary:
	for value: Dictionary in SERIES:
		if value.id==id: return value
	return {}

static func fresh(id: String, driver: int) -> Dictionary:
	if series(id).is_empty(): return {}
	return {"version":VERSION,"series":id,"driver":clampi(driver,0,3),"rounds":[],"awarded":false}

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("version")!=VERSION: return {}
	var id: Variant = raw.get("series")
	if not id is String or series(id).is_empty(): return {}
	var driver: Variant = raw.get("driver")
	if typeof(driver) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(driver)) or float(driver)!=int(driver) or driver<0 or driver>3: return {}
	var rounds: Variant = raw.get("rounds")
	var definition: Dictionary = series(id)
	if not rounds is Array or rounds.size()>definition.courses.size(): return {}
	var clean: Dictionary = fresh(id,int(driver))
	for index: int in range(rounds.size()):
		var round_data: Variant = rounds[index]
		if not round_data is Dictionary: return {}
		var course: String = definition.courses[index]
		if course not in CATALOG.IDS or round_data.get("course")!=course: return {}
		if round_data.get("vehicle")!=CATALOG.assigned_vehicle(course): return {}
		var signature: Variant = round_data.get("signature")
		if not signature is String or signature.length()!=64: return {}
		for character: String in signature:
			if character not in "0123456789abcdef": return {}
		# Reuse the retained four-driver result validation and scoring rules.
		var checked: Dictionary = LEGACY.validate({"id":"casino_v1","rounds":[round_data.get("rows")]})
		if checked.is_empty(): return {}
		var last_time: float = -1.0
		var last_id: int = 0
		var seen_dnf: bool = false
		for row: Dictionary in checked.rounds[0]:
			if not row.finished:
				seen_dnf = true
				continue
			if seen_dnf or row.time<last_time or (row.time==last_time and row.player<last_id): return {}
			last_time = row.time
			last_id = row.player
		clean.rounds.append({"course":course,"vehicle":round_data.vehicle,"signature":signature,"rows":checked.rounds[0]})
	clean.awarded = raw.get("awarded")==true and clean.rounds.size()==definition.courses.size()
	return clean

static func complete(state: Dictionary) -> bool:
	return not state.is_empty() and state.rounds.size()==series(state.series).courses.size()

static func course_id(state: Dictionary) -> String:
	if state.is_empty() or complete(state): return ""
	return series(state.series).courses[state.rounds.size()]

static func standings(state: Dictionary) -> Array:
	var rounds: Array = []
	for round_data: Dictionary in state.get("rounds",[]): rounds.append(round_data.rows)
	return LEGACY.standings({"rounds":rounds},true)

static func append_round(state: Dictionary, expected_round: int, course: String, vehicle: String, signature: String, results: Array) -> bool:
	if state.is_empty() or complete(state) or state.rounds.size()!=expected_round or course_id(state)!=course: return false
	var rows: Array = []
	for row: Dictionary in results:
		rows.append({"player":row.player,"finished":row.finished,"time":row.time if row.finished else 0.0})
	var candidate: Dictionary = state.duplicate(true)
	candidate.rounds.append({"course":course,"vehicle":vehicle,"signature":signature,"rows":rows})
	var clean: Dictionary = validate(candidate)
	if clean.is_empty(): return false
	state.rounds = clean.rounds
	return true
