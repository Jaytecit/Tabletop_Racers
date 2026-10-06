extends RefCounted
# Earned vehicle upgrades use quarter steps; zero remains baseline tuning.
const OLD_FIELDS: Array[String] = ["grip", "speed", "boost", "recovery"]
const FIELDS: Array[String] = ["grip", "speed", "boost", "recovery", "acceleration"]
const VERSION: String = "stats-3"
const MINIMUM: float = -2.0
const MAXIMUM: float = 4.0
const STEP: float = 0.25

static func starting() -> Dictionary:
	return {"grip":-2.0,"speed":-2.0,"boost":-2.0,"recovery":-2.0,"acceleration":-2.0}

static func portrait_starting(portrait_id: int) -> Dictionary:
	var result: Dictionary = starting()
	var allocation: Dictionary = {"grip":2,"speed":2,"boost":2,"recovery":1,"acceleration":1}
	var specialty: String = ["acceleration","grip","boost","speed"][clampi(portrait_id,0,7)%4]
	allocation[specialty] += 2
	for field: String in FIELDS: result[field] += allocation[field]*STEP
	return result

static func full() -> Dictionary:
	return {"grip":4.0,"speed":4.0,"boost":4.0,"recovery":4.0,"acceleration":4.0}

static func neutral() -> Dictionary:
	return {"grip":0,"speed":0,"boost":0,"recovery":0,"acceleration":0}

static func valid(value: Variant) -> bool:
	return valid_fields(value,FIELDS)

static func valid_fields(value: Variant, fields: Array[String]) -> bool:
	if not value is Dictionary or value.size()!=fields.size(): return false
	for field: String in fields:
		var point: Variant = value.get(field)
		if typeof(point) not in [TYPE_INT,TYPE_FLOAT]: return false
		if not is_finite(float(point)) or float(point)<MINIMUM or float(point)>MAXIMUM: return false
		if float(point)/STEP!=roundf(float(point)/STEP): return false
	return true

static func legacy_valid(value: Variant) -> bool:
	if not valid_fields(value,OLD_FIELDS): return false
	var total: int = 0
	for field: String in OLD_FIELDS:
		if float(value[field])!=int(value[field]) or absf(value[field])>2: return false
		total += int(value[field])
	return total==0

static func spent(value: Dictionary) -> int:
	var total: int = 0
	for field: String in FIELDS: total += roundi((float(value[field])-MINIMUM)/STEP)
	return total

static func code(value: Dictionary) -> String:
	var values: PackedStringArray = []
	for field: String in FIELDS: values.append("%.2f" % value[field])
	return ",".join(values)

static func factor(point: float, low_slope: float, high_slope: float) -> float:
	return 1.0+point*(low_slope if point<0.0 else high_slope)

static func compose(base: Resource, value: Dictionary) -> Resource:
	var points: Dictionary = value if valid(value) else neutral()
	var result: Resource = base.duplicate()
	result.grip *= factor(points.grip,0.15,0.10)
	result.coast_grip *= factor(points.grip,0.15,0.10)
	result.top_speed *= factor(points.speed,0.10,0.06)
	result.boost_drain /= factor(points.boost,0.175,0.15)
	result.recovery_speed *= factor(points.recovery,0.15,0.125)
	result.acceleration *= factor(points.acceleration,0.175,0.10)
	return result
