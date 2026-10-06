extends "res://tests/autopilot/probe_base.gd"
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
const STORE: Script = preload("res://scripts/profile_store.gd")
var failures: Array[String] = []

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null: node.hardware_input_isolated = true)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	check(race.profile.read_only,"read-only sentinel loaded before setup")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	get_tree().current_scene.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	var mode: OptionButton = race.menu.get_node("Mode")
	check(choice.item_count==10,"course count")
	check(mode.item_count==8,"eight integrated modes")
	check(not race.menu.get_node("Back").visible,"2D fallback visible")
	check(CATALOG.IDS.size()==CATALOG.TITLES.size(),"ID/title lengths")
	var legacy: Dictionary = STORE.defaults()
	legacy.quick_race.track_id = "felt_sprint"
	legacy.mode = "cup"
	legacy.cup_wins = 2
	legacy.gold_livery = true
	legacy.cup = preload("res://scripts/race/cup_rules.gd").fresh()
	var record: Dictionary = {"signature":"a".repeat(64),"total":100.0,"best_lap":30.0,"replay":""}
	legacy.records[STORE.record_key("trial",3,0,0,"felt_sprint")] = record
	var migrated: Dictionary = STORE.validate(legacy)
	check(migrated.quick_race.track_id=="game_table" and migrated.mode=="quick","legacy selection migration")
	check(migrated.cup_wins==2 and migrated.gold_livery and migrated.records.size()==1 and not migrated.cup.is_empty(),"legacy data lost")
	legacy.quick_race.track_id = "blackjack"
	check(STORE.validate(legacy).quick_race.track_id=="game_table","blackjack alias")
	report("legacy_migration",migrated)
	var rows: Array = []
	for index: int in range(CATALOG.IDS.size()):
		var id: String = CATALOG.IDS[index]
		check(choice.get_item_text(index)==CATALOG.choice_title(index),"menu identity "+id)
		check(CATALOG.CLASSIFICATION.has(id),"course classification "+id)
		var load_begin: int = Time.get_ticks_usec()
		choice.select(index)
		choice.item_selected.emit(index)
		for frame: int in range(1800):
			await get_tree().process_frame
			if not race.course.loading: break
		await settle_physics(3)
		await settle(2)
		var visible_ms: float = (Time.get_ticks_usec()-load_begin)/1000.0
		check(not race.course.loading,"load completed "+id)
		check(race.course.error=="" and race.track_id==id,"menu select "+id)
		check(race.track.validation_errors.is_empty(),"route validation "+id)
		check(race.player_car.base_tuning.id==CATALOG.assigned_vehicle(id),"assigned vehicle "+id)
		var reference: Node3D = preload("res://tests/fixtures/track_sampling_before_loading.gd").new()
		reference.definition = race.track.definition
		reference.build()
		for property: String in ["points","lengths","starts","ends","section_ids","total_length","half_width","validation_errors","anchors","corridor_polygons","corridor_bounds"]:
			check(race.track.get(property)==reference.get(property),"transferred "+property+" "+id)
		# Generated flag geometry enriches active gate dictionaries with plane_edges.
		check(race.track.gates.size()==reference.gates.size(),"transferred gate count "+id)
		for gate_index: int in range(reference.gates.size()):
			for key: String in reference.gates[gate_index]:
				check(race.track.gates[gate_index][key]==reference.gates[gate_index][key],"transferred gate "+key+" "+id)
		reference.free()
		check(race.course.entry.title==CATALOG.TITLES[index],"entry title "+id)
		var saved: Dictionary = STORE.defaults()
		saved.quick_race.track_id = id
		saved.mode = "trial"
		saved.records[STORE.record_key("trial",3,0,0,id)] = record
		var clean: Dictionary = STORE.validate(saved)
		check(clean.quick_race.track_id==id and clean.records.size()==1,"profile validation "+id)
		mode.select(1)
		mode.item_selected.emit(1)
		race.start_race()
		check(race.race_mode=="trial" and race.cars.size()==1,"trial start "+id)
		await settle_physics(2)
		race.show_menu()
		race.menu_flow.show_step(3)
		mode.select(0)
		mode.item_selected.emit(0)
		race.start_race()
		check(race.race_mode=="quick" and race.cars.size()==race.rival_count+1,"quick start "+id)
		await settle_physics(2)
		race.show_menu()
		race.menu_flow.show_step(3)
		await settle(2)
		save_frame("menu_"+id)
		rows.append({"id":id,"title":race.course.entry.title,"length":race.track.total_length,"validation_errors":race.track.validation_errors,"selection_visible_ms":visible_ms,"stages":race.course.last_load_metrics.duplicate()})
	for id: String in ["practice_patch","felt_sprint","card_bridge","cereal_slalom","plate_rim","countertop_table","carpet_cruise","desk_drawer","toybox_trestle","beach_buggies"]:
		check(CATALOG.load_entry(id).has("error"),"retired course loads "+id)
	check(race.course.select("game_table"),"return to Roulette")
	await settle(3)
	save_frame("final_roulette")
	# Round-trip one GLB selection using an evidence-only file, never user://.
	var temporary: RefCounted = STORE.new()
	temporary.path = summer_out_dir.path_join("test_profile.json")
	temporary.data = STORE.defaults()
	temporary.data.quick_race.track_id = "topspeed_oval"
	check(temporary.save_profile()==OK,"temporary profile save")
	check(temporary.load_profile().quick_race.track_id=="topspeed_oval","temporary profile reload")
	report("courses",rows)
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
