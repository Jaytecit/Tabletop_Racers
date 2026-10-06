extends RefCounted
const VERSION: String = "drift-1"
const DURATION: float = 90.0
const COURSES: Dictionary = {"bazaar":700}
# Retired challenges remain valid save history, independently of eligibility.
const RECORD_COURSES: Array[String] = ["topspeed_oval","bazaar"]
const CONTEXT: Script = preload("res://scripts/race/challenge_rules.gd")
var score: float = 0.0
var combo: float = 0.0
var sustained: float = 0.0
var straight_time: float = 0.0
var high_water: float = 0.0
var best_combo: float = 0.0
var cue: String = "GAS + STEER TO SLIDE"

func reset(progress: float) -> void:
	score = 0.0
	combo = 0.0
	sustained = 0.0
	straight_time = 0.0
	high_water = progress
	best_combo = 0.0
	cue = "GAS + STEER TO SLIDE"

func end_combo(bank: bool) -> void:
	if bank:
		score += combo
		best_combo = maxf(best_combo,combo)
	combo = 0.0
	sustained = 0.0
	straight_time = 0.0

func step(delta: float, sample: Dictionary) -> void:
	if delta<=0.0 or not is_finite(delta): return
	var progress: float = sample.progress
	var fresh_distance: float = minf(maxf(0.0,progress-high_water),float(sample.distance))
	high_water = maxf(high_water,progress)
	if not sample.safe or sample.incident or not sample.valid_motion:
		cue = "COMBO LOST"
		end_combo(false)
		return
	var angle: float = absf(sample.angle)
	if angle>65.0 or sample.forward_speed<2.5:
		cue = "KEEP MOVING FORWARD"
		end_combo(false)
		return
	if angle<12.0 or sample.speed<3.5:
		cue = "STRAIGHTEN TO BANK" if combo>0.0 else "GAS + STEER TO SLIDE"
		straight_time += delta
		if straight_time>=0.5: end_combo(true)
		return
	# Forward, new route distance rejects stationary spinning, reversing and
	# circling over a previously credited patch of road.
	if fresh_distance<2.0*delta:
		cue = "KEEP MOVING FORWARD"
		end_combo(false)
		return
	straight_time = 0.0
	sustained += delta
	cue = "HOLD THE SLIDE"
	if sustained<0.3: return
	var multiplier: float = 1.0+minf(sustained/3.0,3.0)
	cue = "DRIFT x%.1f" % multiplier
	combo += fresh_distance*clampf(angle/30.0,0.4,2.0)*clampf(sample.speed/8.0,0.5,2.0)*10.0*multiplier

static func validate_records(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary: return clean
	for key: Variant in raw:
		var row: Variant = raw[key]
		if not key is String or not CONTEXT.valid_context(row) or CONTEXT.context_key(row)!=key: continue
		if row.course not in RECORD_COURSES or row.vehicle!="drift_car": continue
		var value: Variant = row.get("score")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value!=int(value) or value<0 or value>10000000: continue
		clean[key] = {"driver":int(row.driver),"course":row.course,"vehicle":row.vehicle,"laps":int(row.laps),"stats":row.stats,"signature":row.signature,"score":int(value)}
	return clean
