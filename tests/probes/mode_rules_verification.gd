extends "res://tests/probes/race_quality_ai_verification.gd"
const TOURNAMENT: Script = preload("res://scripts/race/tournament_rules.gd")
const CHALLENGE: Script = preload("res://scripts/race/challenge_rules.gd")
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")

func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	check(race.profile.read_only,"read_only")
	var rows: Array = []
	for id: int in range(1,5): rows.append({"player":id,"finished":true,"time":60.0+id})
	for series: Dictionary in TOURNAMENT.SERIES:
		var state: Dictionary = TOURNAMENT.fresh(series.id,2)
		for index: int in range(series.courses.size()):
			var course: String = series.courses[index]
			check(TOURNAMENT.course_id(state)==course,"series_course_%s_%d" % [series.id,index])
			check(TOURNAMENT.append_round(state,index,course,CATALOG.assigned_vehicle(course),"a".repeat(64),rows),"series_append_%s_%d" % [series.id,index])
			check(not TOURNAMENT.append_round(state,index,course,CATALOG.assigned_vehicle(course),"a".repeat(64),rows),"series_duplicate_%s_%d" % [series.id,index])
			check(TOURNAMENT.validate(state)==state,"series_resume_%s_%d" % [series.id,index])
		check(TOURNAMENT.complete(state) and TOURNAMENT.course_id(state)=="","series_complete_"+series.id)
		check(TOURNAMENT.standings(state)[0].player==1 and TOURNAMENT.standings(state)[0].points==10*series.courses.size(),"series_points_"+series.id)
		var invalid: Dictionary = state.duplicate(true)
		invalid.rounds[0].course = "felt_sprint"
		check(TOURNAMENT.validate(invalid).is_empty(),"retired_course_rejected_"+series.id)
	var tie_rows: Array = [{"player":1,"finished":true,"time":60.0},{"player":2,"finished":true,"time":62.0},{"player":3,"finished":false,"time":0.0},{"player":4,"finished":false,"time":0.0}]
	var reversed: Array = tie_rows.duplicate(true)
	reversed[0].player = 2
	reversed[1].player = 1
	var tied: Array = TOURNAMENT.standings({"rounds":[{"rows":tie_rows},{"rows":reversed}]})
	check(tied[0].player==1 and tied[1].player==2 and tied[0].points==16 and tied[1].points==16,"deterministic_tie")
	check(tied[2].points==0 and tied[3].points==0,"dnf_no_points")
	var context: Dictionary = {"driver":0,"course":"toys_r_you","vehicle":"buggy","laps":3,"stats":STATS.VERSION+":"+STATS.code(STATS.neutral()),"signature":"a".repeat(64)}
	var records: Dictionary = {}
	var run: Dictionary = {"finished":true,"ordered_laps":true,"laps":3,"time":140.0,"crashes":0,"impacts":0,"penalty":0.0,"test_build":false,"ai":false}
	check(CHALLENGE.award(records,context,run,145.0)==["finish","clean","medal"],"challenge_all_awards")
	check(CHALLENGE.award(records,context,run,145.0).is_empty(),"challenge_once")
	check(CHALLENGE.validate(records)==records,"challenge_reload")
	check(CHALLENGE.validate(JSON.parse_string(JSON.stringify(records)))==records,"challenge_json_roundtrip")
	var other_driver: Dictionary = context.duplicate(true)
	other_driver.driver = 1
	check(CHALLENGE.context_key(other_driver)!=CHALLENGE.context_key(context),"challenge_driver_isolation")
	var changed: Dictionary = context.duplicate(true)
	changed.signature = "b".repeat(64)
	check(CHALLENGE.context_key(context)!=CHALLENGE.context_key(changed),"changed_rules_separate")
	check(CHALLENGE.award(records,changed,run,135.0)==["finish","clean"] and records.size()==2,"old_awards_retained")
	for invalidation: String in ["test_build","ai","finished","ordered_laps","laps"]:
		var invalid: Dictionary = run.duplicate(true)
		invalid[invalidation] = 2 if invalidation=="laps" else invalidation in ["test_build","ai"]
		check(CHALLENGE.award({},context,invalid,145.0).is_empty(),"reject_"+invalidation)
	for blemish: String in ["crashes","impacts","penalty","missed_gates"]:
		var dirty: Dictionary = run.duplicate(true)
		dirty[blemish] = 1
		check(CHALLENGE.award({},context,dirty,145.0)==["finish"],"unclean_"+blemish)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
