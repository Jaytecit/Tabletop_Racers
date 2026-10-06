extends RefCounted
const RULES: Script = preload("res://scripts/race/challenge_rules.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const LAPS: int = 3
# Initial designer targets use each course's documented lap range midpoint.
# These are not owner benchmarks; target edits change the context signature.
const TARGET_VERSION: String = "catalogue-midpoint-1"
var race: Node3D
var context: Dictionary = {}
var target: float = 0.0
var missed_gates: int = 0
var resolved: bool = true
var note: String = ""
var rules_hash: String = ""

func configure(owner: Node3D) -> void:
	race = owner
	rules_hash = FileAccess.get_sha256("res://scripts/race/challenge_rules.gd")+FileAccess.get_sha256("res://scripts/race/challenge_controller.gd")

func target_time() -> float:
	if race.course.entry==null: return 0.0
	var bounds: Vector2 = race.course.entry.target_lap_seconds
	return snappedf((bounds.x+bounds.y)*0.5*LAPS*race.roadmap.factor(),0.1)

func current_context() -> Dictionary:
	# Include target/rule implementation, route, physical handling, class and stats.
	# Driver identity is explicit; another driver cannot inherit these achievements.
	var signature: String = (race.trial.signature+TARGET_VERSION+str(target_time())+rules_hash).sha256_text()
	return {"driver":race.garage.selected,"course":race.track_id,"vehicle":race.player_car.base_tuning.id,"laps":LAPS,"stats":STATS.VERSION+":"+STATS.code(race.active_stats()),"signature":signature}

func begin() -> void:
	context = current_context()
	target = target_time()
	missed_gates = 0
	resolved = false
	note = ""

func gate_warning() -> void:
	if not resolved: missed_gates += 1

func score() -> String:
	if resolved: return note
	resolved = true
	var car: CharacterBody3D = race.player_car
	var progress: Dictionary = race.session.progress.records[1]
	var run: Dictionary = {"test_build":race.experimental(),"ai":car.ai,"finished":car.finish_time>0.0,"ordered_laps":progress.laps==race.session.laps_required,"laps":progress.laps,"time":car.finish_time,"crashes":car.crashes,"impacts":car.impacts,"penalty":progress.penalty,"missed_gates":missed_gates}
	var earned: Array[String] = RULES.award(race.profile.data.challenges,context,run,target)
	if run.test_build or run.ai: note = "CHALLENGE AWARDS REQUIRE A HUMAN RUN WITH EARNED STATS"
	elif not run.finished: note = "CHALLENGE INCOMPLETE · FINISH ALL THREE LAPS"
	elif earned.is_empty(): note = "FINISH RECORDED · NO NEW ACHIEVEMENTS"
	else: note = "EARNED · "+" / ".join(earned).to_upper()
	if run.finished and not run.ai and not run.test_build:
		if car.crashes>0 or car.impacts>0 or progress.penalty>0 or missed_gates>0: note += "\nCLEAN: NO CONTACT, RECOVERY OR MISSED GATE"
		elif car.finish_time>target: note += "\nTIME MEDAL · TARGET %.1fs" % target
		race.save_preferences()
	return note

func summary() -> String:
	var current: Dictionary = current_context()
	var record: Dictionary = race.profile.data.challenges.get(RULES.context_key(current),{})
	var statuses: PackedStringArray = []
	for item: String in ["finish","clean","medal"]: statuses.append(item.to_upper()+(" OK" if record.get(item,false) else " --"))
	var historic: int = 0
	for row: Dictionary in race.profile.data.challenges.values():
		if row.driver==current.driver and row.course==current.course and RULES.context_key(row)!=RULES.context_key(current): historic += 1
	return " / ".join(statuses)+"\n3 LAPS SOLO · CLEAN TARGET %.1fs" % target_time()+(" · %d OLD SETS" % historic if historic>0 else "")

func hud_text() -> String:
	var clean_run: bool = race.player_car.crashes==0 and race.player_car.impacts==0 and missed_gates==0
	return "TARGET %.1fs · " % target+("CLEAN" if clean_run else "FINISH ONLY")
