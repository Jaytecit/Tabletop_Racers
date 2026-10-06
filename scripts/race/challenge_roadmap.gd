extends RefCounted
const VERSION: String = "roadmap-1"
const MODES: Array[String] = ["drift","challenge","time_attack"]
const DRIFT: Array[int] = [700,1000,1300,1600,1900]
const FACTORS: Array[float] = [1.30,1.15,1.0,0.90,0.80]
var race: Node3D
var row: HBoxContainer
var choices: Dictionary = {}
var run_key: String = ""
var run_stage: int = 0
var run_target: float = 0.0
var resolved: bool = true

static func validate(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary: return result
	for key: Variant in raw:
		if not key is String: continue
		var parts: PackedStringArray = key.split("|")
		if parts.size()!=4 or parts[0] not in MODES or parts[1] not in preload("res://scripts/tracks/content_catalog.gd").IDS or not parts[2].is_valid_int() or parts[3]!=VERSION: continue
		var count: Variant = raw[key]
		if typeof(count) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(count)) and count==int(count) and count>=0 and count<=5: result[key] = int(count)
	return result

func key() -> String:
	return "%s|%s|%d|%s" % [race.race_mode,race.track_id,race.track.definition.revision,VERSION]

func completed() -> int:
	return int(race.profile.data.challenge_roadmaps.get(key(),0))

func stage() -> int:
	return clampi(int(choices.get(key(),mini(completed(),4))),0,mini(completed(),4))

func drift_target() -> int:
	return DRIFT[run_stage if race.phase in [1,2,3,5,6] and race.race_mode=="drift" else stage()]

func factor() -> float:
	return FACTORS[run_stage if not resolved else stage()]

func setup(owner: Node3D) -> void:
	race = owner
	row = HBoxContainer.new()
	row.name = "ChallengeRoadmap"
	row.position = Vector2(50,484)
	row.size = Vector2(530,40)
	row.add_theme_constant_override("separation",6)
	race.menu.add_child(row)
	for index: int in range(5):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(101,40)
		button.add_theme_font_size_override("font_size",14)
		row.add_child(button)
		button.pressed.connect(func() -> void: choices[key()] = index; race.menu_flow.refresh())
	refresh()

func refresh() -> void:
	if row==null: return
	row.visible = race.menu_flow.step==3 and race.race_mode in MODES
	if not row.visible: return
	race.menu.get_node("QuickRace").hide()
	for index: int in range(5):
		var button: Button = row.get_child(index)
		button.disabled = index>completed()
		button.text = "%d %s" % [index+1,"DONE" if index<completed() else ("PLAY" if index==stage() else "LOCK")]
		button.modulate = Color("ffd966") if index==stage() else Color.WHITE
		button.tooltip_text = "Stage %d: %d points" % [index+1,DRIFT[index]] if race.race_mode=="drift" else "Stage %d: %.0f%% time budget" % [index+1,FACTORS[index]*100.0]
	race.menu.get_node("Record").text = summary()

func summary() -> String:
	var goal: String
	if race.race_mode=="drift": goal = "90s / TARGET %d POINTS" % DRIFT[stage()]
	elif race.race_mode=="challenge": goal = "3 CLEAN LAPS / TARGET %.1fs" % race.challenge.target_time()
	else:
		var clock: Dictionary = preload("res://scripts/race/time_attack_rules.gd").settings(race.course.entry)
		goal = "3 LAPS / START %.1fs / GATE +%.1fs" % [clock.start*FACTORS[stage()],clock.extension*FACTORS[stage()]]
	return "ROADMAP %d/5 COMPLETE / STAGE %d\n%s" % [completed(),stage()+1,goal]

func begin() -> void:
	resolved = true
	if race.race_mode not in MODES: return
	run_key = key()
	run_stage = stage()
	resolved = false
	run_target = float(DRIFT[run_stage]) if race.race_mode=="drift" else (race.challenge.target_time() if race.race_mode=="challenge" else 0.0)

func award() -> String:
	if resolved or race.race_mode not in MODES: return ""
	resolved = true
	var car: CharacterBody3D = race.player_car
	if race.experimental() or car.ai or key()!=run_key: return "\nROADMAP: UNRANKED RUN"
	var progress: Dictionary = race.session.progress.records[1]
	var success: bool = false
	if race.race_mode=="drift": success = race.drift.elapsed>=race.drift.RULES.DURATION and race.drift.rules.score>=run_target
	else:
		success = car.finish_time>0.0 and progress.laps==race.session.laps_required
		if race.race_mode=="challenge": success = success and car.finish_time<=run_target and car.crashes==0 and car.impacts==0 and progress.penalty==0.0 and race.challenge.missed_gates==0
		else: success = success and not race.session.time_attack.expired
	if not success: return "\nSTAGE %d NOT BEATEN / TRY AGAIN" % (run_stage+1)
	var count: int = int(race.profile.data.challenge_roadmaps.get(run_key,0))
	if run_stage==count:
		race.profile.data.challenge_roadmaps[run_key] = mini(5,count+1)
		choices.erase(run_key)
		race.save_preferences()
	return "\nSTAGE %d BEATEN / ROADMAP %d/5" % [run_stage+1,int(race.profile.data.challenge_roadmaps.get(run_key,0))]
