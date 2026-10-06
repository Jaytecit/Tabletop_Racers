extends RefCounted
const RULES: Script = preload("res://scripts/race/drift_rules.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
var race: Node3D
var rules: RefCounted = RULES.new()
var previous_position: Vector3
var previous_heading: float = 0.0
var previous_impacts: int = 0
var previous_crashes: int = 0
var elapsed: float = 0.0
var resolved: bool = true
var context: Dictionary = {}
var note: String = ""
var source_hash: String = ""
var last_sample: Dictionary = {}

func configure(owner: Node3D) -> void:
	race = owner
	source_hash = FileAccess.get_sha256("res://scripts/race/drift_rules.gd")+FileAccess.get_sha256("res://scripts/race/drift_controller.gd")

func current_context() -> Dictionary:
	return {"driver":race.garage.selected,"course":race.track_id,"vehicle":"drift_car","laps":1,"stats":STATS.VERSION+":"+STATS.code(race.active_stats()),"signature":(race.trial.signature+source_hash).sha256_text()}

func begin() -> void:
	context = current_context()
	rules.reset(race.session.progress.records[1].distance)
	previous_position = race.player_car.position
	previous_heading = race.player_car.heading
	previous_impacts = race.player_car.impacts
	previous_crashes = race.player_car.crashes
	elapsed = 0.0
	resolved = false
	note = ""
	last_sample = {}

func tick(delta: float) -> void:
	if resolved or race.paused_race or race.phase!=2: return
	var car: CharacterBody3D = race.player_car
	var surface: Dictionary = race.track.project_3d(car.position,car.station)
	var horizontal: Vector2 = Vector2(car.velocity.x,car.velocity.z)
	var forward: Vector2 = Vector2.RIGHT.rotated(car.heading)
	var travelled: float = car.position.distance_to(previous_position)
	var turn_rate: float = absf(angle_difference(previous_heading,car.heading))/maxf(delta,0.001)
	var support: Dictionary = car.physical_support(car.position)
	var legal: bool = car.state==0 and not car.airborne and surface.supported and surface.distance<maxf(0.0,surface.width*0.5-car.tuning.traffic_half_width) and not support.is_empty() and absf(car.position.y-support.position.y)<0.2
	var sample: Dictionary = {"progress":race.session.progress.records[1].distance,"distance":travelled,"speed":horizontal.length(),"forward_speed":horizontal.dot(forward),"angle":rad_to_deg(forward.angle_to(horizontal)),"safe":legal,"incident":car.impacts>previous_impacts or car.crashes>previous_crashes,"valid_motion":travelled<=car.top_speed*maxf(car.tuning.boost_speed,1.0)*delta+0.3 and turn_rate<3.5 and travelled>=horizontal.length()*delta*0.25}
	last_sample = sample
	rules.step(minf(delta,RULES.DURATION-elapsed),sample)
	elapsed += delta
	previous_position = car.position
	previous_heading = car.heading
	previous_impacts = car.impacts
	previous_crashes = car.crashes
	if elapsed>=RULES.DURATION: finish()

func finish() -> void:
	if resolved: return
	resolved = true
	rules.end_combo(true)
	var total: int = floori(rules.score)
	var target: int = race.roadmap.drift_target()
	var won: bool = target>0 and total>=target
	note = ("DRIFT TARGET BEATEN" if won else "DRIFT TARGET MISSED")+" / %d POINTS / TARGET %d" % [total,target]
	if not race.experimental() and not race.player_car.ai:
		var key: String = RULES.CONTEXT.context_key(context)
		var old: Dictionary = race.profile.data.drift_records.get(key,{})
		if old.is_empty() or total>old.score:
			var row: Dictionary = context.duplicate(true)
			row.score = total
			race.profile.data.drift_records[key] = row
			note += "\nNEW BEST SCORE"
			race.save_preferences()
	else: note += "\nAUTOMATED / STAT TEST: SCORE SAVING DISABLED"
	if won:
		race.session.progress.mark_finished(race.player_car,RULES.DURATION)
		race.on_racer_finished(race.player_car)
	race.session.classify()

func summary() -> String:
	var record: Dictionary = race.profile.data.drift_records.get(RULES.CONTEXT.context_key(current_context()),{})
	return "90s / TARGET %d / BEST %d\nDRIFT FORWARD; STRAIGHTEN TO BANK. CONTACT LOSES COMBO." % [race.roadmap.drift_target(),record.get("score",0)]

func hud_text() -> String:
	return "%.1fs / %d PTS / +%d / " % [maxf(0.0,RULES.DURATION-elapsed),floori(rules.score),floori(rules.combo)]+rules.cue
