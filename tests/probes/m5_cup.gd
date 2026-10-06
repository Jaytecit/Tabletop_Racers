extends "res://tests/autopilot/probe_base.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const CUP: Script = preload("res://scripts/race/cup_rules.gd")
const TEST_PATH: String = "user://m5_cup_test.json"
var failures: Array[String] = []

func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)

func clear_test() -> void:
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(TEST_PATH+suffix)

func same_cup(a: Dictionary,b: Dictionary) -> bool:
	if a.get("id")!=b.get("id") or a.rounds.size()!=b.rounds.size(): return false
	for round_index: int in range(a.rounds.size()):
		for rank: int in range(4):
			var left: Dictionary = a.rounds[round_index][rank]
			var right: Dictionary = b.rounds[round_index][rank]
			if left.player!=right.player or left.finished!=right.finished or absf(left.time-right.time)>0.000001: return false
	return true

func reconstruct() -> Node:
	var old: Node = get_tree().current_scene
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.get_node("Race").profile.path = TEST_PATH
	get_tree().current_scene = null
	old.queue_free()
	get_tree().root.add_child.call_deferred(app)
	await get_tree().process_frame
	get_tree().current_scene = app
	await settle(3)
	return app.get_node("Race")

func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(3)
	clear_test()
	var race: Node = await reconstruct()
	var mode: OptionButton = race.menu.get_node("Mode")
	mode.grab_focus()
	await key(KEY_ENTER,50)
	await key(KEY_DOWN,50)
	await key(KEY_DOWN,50)
	await key(KEY_ENTER,50)
	check("keyboard_cup",race.race_mode=="cup" and race.menu.get_node("QuickRace/Laps").disabled)
	check("locked_livery",race.menu.get_node("GoldLivery").disabled)
	race.rival_count = 0
	race.difficulty = 2
	race.race_laps = 7
	race.save_preferences()
	race.player_car.ai = true
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	for round_index: int in range(3):
		race.focus_start()
		await press("start_race")
		check("grid_round_"+str(round_index),race.cars.size()==4 and race.session.laps_required==3 and race.track_id==CUP.COURSES[round_index] and race.all_cars[1].ai_driver.difficulty==1)
		if round_index==0:
			race.toggle_pause()
			var clock: float = race.race_time
			await settle_physics(5)
			check("pause_no_progress",race.race_time==clock and race.profile.data.cup.rounds.is_empty())
			race.toggle_pause()
			race.start_race()
			check("retry_unfinished_no_points",race.profile.data.cup.rounds.is_empty())
		for frame: int in range(20000):
			await get_tree().process_frame
			if race.phase==3: break
		check("legal_finish_"+str(round_index),race.phase==3 and race.player_car.laps==3 and race.session.results.size()==4)
		if race.phase!=3: break
		check("round_saved_"+str(round_index),race.profile.data.cup.rounds.size()==round_index+1)
		var snapshot: Dictionary = race.profile.data.cup.duplicate(true)
		race.on_results_ready(race.session.results)
		check("no_double_score_"+str(round_index),race.profile.data.cup==snapshot)
		await settle(2)
		save_frame("round_"+str(round_index))
		Engine.time_scale = 1.0
		race = await reconstruct()
		check("restart_round_"+str(round_index),race.race_mode=="cup" and same_cup(race.profile.data.cup,snapshot) and race.rival_count==0 and race.difficulty==2 and race.race_laps==7)
		race.player_car.ai = true
		Engine.time_scale = 4.0
	report("standings",CUP.standings(race.profile.data.cup))
	check("cup_no_local_record",race.profile.data.records.is_empty())
	# Exercise trophy and unlock with deterministic classified outcomes as well as live races.
	var fixture: Array = []
	for id: int in range(1,5): fixture.append({"player":id,"rank":id,"finished":true,"time":30.0+id,"penalty":0.0,"laps":3})
	race.profile.data.cup = CUP.fresh()
	CUP.append_round(race.profile.data.cup,fixture)
	CUP.append_round(race.profile.data.cup,fixture)
	var wins_before: int = race.profile.data.cup_wins
	race.cup_round_scored = false
	race.on_results_ready(fixture)
	check("trophy_unlock",race.profile.data.cup_wins==wins_before+1 and not race.menu.get_node("GoldLivery").disabled)
	race.on_results_ready(fixture)
	check("trophy_once",race.profile.data.cup_wins==wins_before+1)
	race.show_menu()
	await settle(3)
	var livery: Button = race.menu.get_node("GoldLivery")
	livery.grab_focus()
	await key(KEY_SPACE,50)
	await settle(3)
	check("keyboard_gold_livery",race.profile.data.gold_livery and race.player_car.visual.get_node("Body").material_override.albedo_color==Color("e7ba52"))
	Engine.time_scale = 1.0
	race = await reconstruct()
	check("restart_trophy_livery",race.profile.data.cup_wins==wins_before+1 and race.profile.data.gold_livery and race.player_car.visual.get_node("Body").material_override.albedo_color==Color("e7ba52"))
	await settle(2)
	save_frame("cup_menu_gold")
	race.start_race()
	check("new_cup_reset",race.profile.data.cup.rounds.is_empty() and race.session.laps_required==3 and race.track_id=="felt_sprint")
	race.show_menu()
	check("abandon_no_score",race.profile.data.cup.rounds.is_empty())
	# Tie order: points, wins, accumulated time, stable player id.
	var tie: Dictionary = CUP.fresh()
	CUP.append_round(tie,[fixture[0],fixture[1],fixture[2],fixture[3]])
	CUP.append_round(tie,[fixture[1],fixture[0],fixture[3],fixture[2]])
	check("time_tiebreak",CUP.standings(tie)[0].player==1)
	var wins_tie: Dictionary = CUP.fresh()
	CUP.append_round(wins_tie,[fixture[0],fixture[1],fixture[2],fixture[3]])
	CUP.append_round(wins_tie,[fixture[2],fixture[3],fixture[1],fixture[0]])
	CUP.append_round(wins_tie,[fixture[3],fixture[2],fixture[1],fixture[0]])
	var tied: Array = CUP.standings(wins_tie)
	check("wins_tiebreak",tied[2].player==1 and tied[2].points==14 and tied[3].player==2 and tied[3].points==14)
	var stable: Dictionary = CUP.fresh()
	var equal_rows: Array = fixture.duplicate(true)
	for row: Dictionary in equal_rows: row.time = 30.0
	CUP.append_round(stable,[equal_rows[0],equal_rows[1],equal_rows[2],equal_rows[3]])
	CUP.append_round(stable,[equal_rows[1],equal_rows[0],equal_rows[3],equal_rows[2]])
	check("stable_tiebreak",CUP.standings(stable)[0].player==1)
	var invalid_id: Array = fixture.duplicate(true)
	invalid_id[0].player = NAN
	check("nonfinite_id_rejected",CUP.validate({"id":"casino_v1","rounds":[invalid_id]}).is_empty())
	fixture[0].time = 33.0
	check("malformed_cup",CUP.validate({"id":"casino_v1","rounds":[[fixture[0],fixture[0],fixture[2],fixture[3]]]}).is_empty())
	check("v2_migration",STORE.validate({"schema_version":2,"mode":"trial","quick_race":{"laps":5}}).schema_version==3)
	check("locked_gold_sanitized",not STORE.validate({"gold_livery":true}).gold_livery)
	check("old_cup_retired",CUP.validate({"id":"blackjack","rounds":[]}).is_empty())
	# DNF classification gives points but cannot award a trophy or cosmetic.
	race.profile.data.cup = CUP.fresh()
	fixture[0].finished = false
	fixture[0].time = 0.0
	CUP.append_round(race.profile.data.cup,fixture)
	CUP.append_round(race.profile.data.cup,fixture)
	race.cup_round_scored = false
	race.on_results_ready(fixture)
	check("dnf_no_trophy",race.profile.data.cup_wins==wins_before+1)
	clear_test()
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
