extends RefCounted
const RULES: Script = preload("res://scripts/race/owner_benchmark_rules.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
var race: Node3D
var toggle: Button
var designate_button: Button
var missed_gates: int = 0
var candidate: Dictionary = {}
var context: Dictionary = {}
var notice: String = ""
var source_hash: String = ""

func configure(owner: Node3D) -> void:
	race = owner
	source_hash = FileAccess.get_sha256("res://scripts/race/owner_benchmark_rules.gd")+FileAccess.get_sha256("res://scripts/race/owner_benchmark.gd")

func active() -> bool:
	return race!=null and race.race_mode=="trial" and race.profile.data.benchmark_enabled

func setup_ui() -> void:
	toggle = Button.new()
	toggle.name = "OwnerBenchmark"
	toggle.position = Vector2(444,658)
	toggle.size = Vector2(260,38)
	toggle.add_theme_font_size_override("font_size",14)
	toggle.pressed.connect(func() -> void:
		race.profile.data.benchmark_enabled = not race.profile.data.benchmark_enabled
		if active(): race.stats_test_mode = 0
		race.garage.apply_stats(race)
		race.save_preferences())
	race.menu.add_child(toggle)
	designate_button = Button.new()
	designate_button.name = "DesignateBenchmark"
	designate_button.position = Vector2(28,448)
	designate_button.size = Vector2(704,36)
	designate_button.add_theme_font_size_override("font_size",16)
	designate_button.pressed.connect(designate)
	race.results_panel.add_child(designate_button)
	refresh()

func current_context() -> Dictionary:
	return {"driver":race.garage.selected,"course":race.track_id,"vehicle":race.player_car.base_tuning.id,"laps":RULES.LAPS,"stats":STATS.VERSION+":"+STATS.code(STATS.neutral()),"signature":(race.trial.signature+RULES.VERSION+source_hash).sha256_text()}

func begin() -> void:
	candidate.clear()
	missed_gates = 0
	notice = ""
	context = current_context() if active() else {}

func finish() -> void:
	if context.is_empty(): return
	var car: CharacterBody3D = race.player_car
	var record: Dictionary = race.session.progress.records[1]
	if car.ai or race.experimental() or car.finish_time<=0.0 or record.laps!=RULES.LAPS or record.penalty>0.0 or missed_gates>0 or car.crashes>0 or car.impacts>0:
		notice = "BENCHMARK NEEDS A CLEAN HUMAN RUN"
		return
	candidate = context.duplicate(true)
	candidate.merge({"owner":true,"clean":true,"time":car.finish_time,"recorded_utc":Time.get_datetime_string_from_system(true)})
	notice = "CLEAN RUN / YOU MAY DESIGNATE THIS OWNER BENCHMARK"

func designate() -> void:
	if race.experimental() or candidate.is_empty(): return
	if RULES.designate(race.profile.data.owner_benchmarks,candidate):
		notice = "OWNER BENCHMARK SAVED / %.2fs" % candidate.time
		race.save_preferences()
		if race.profile.read_only or race.profile.status!="": notice = "BENCHMARK SAVE FAILED / "+race.profile.status
	else: notice = "EXISTING OWNER BENCHMARK IS FASTER"
	candidate.clear()
	race.banner.text = notice
	refresh()

func summary() -> String:
	var saved: Dictionary = race.profile.data.owner_benchmarks.get(race.track_id,{})
	var text: String = "OWNER BENCHMARK / 3 LAPS / NEUTRAL BUILD\n"
	if saved.is_empty(): return text+"NO OWNER TIME / AI UNCALIBRATED"
	var stale: bool = not RULES.context_matches(saved.current,current_context())
	return text+("STALE " if stale else "OWNER ")+"%.2fs / %d PREVIOUS / AI UNCALIBRATED" % [saved.current.time,saved.history.size()]

func refresh() -> void:
	if toggle==null or race.menu_flow==null: return
	toggle.visible = race.race_mode=="trial" and race.menu_flow.step==3
	toggle.text = "BENCHMARK: ON" if active() else "OWNER BENCHMARK"
	toggle.tooltip_text = "Lock a solo three-lap run to the assigned class and neutral stats. Designate a clean human finish from its results."
	if active() and race.menu_flow.step==3:
		race.menu.get_node("QuickRace").hide()
		race.menu.get_node("Record").text = summary()
	designate_button.visible = race.results_panel.visible and not candidate.is_empty()
	designate_button.text = "DESIGNATE OWNER BENCHMARK / %.2fs" % candidate.get("time",0.0)
	designate_button.disabled = race.results_input_guard
