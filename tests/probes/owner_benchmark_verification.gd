extends "res://tests/probes/race_quality_ai_verification.gd"
const RULES: Script = preload("res://scripts/race/owner_benchmark_rules.gd")
const STORE: Script = preload("res://scripts/profile_store.gd")

func prepare() -> void:
	race.start_race()
	check(race.cars.size()==1 and race.session.laps_required==3,"locked_three_lap_solo")
	check(race.active_stats()==preload("res://scripts/vehicles/player_stats.gd").neutral(),"locked_neutral_stats")
	race.begin_countdown()
	race.session.change_phase(2)
	race.set_physics_process(false)
	race.player_car.set_physics_process(false)

func complete_fixture(elapsed: float) -> void:
	race.session.progress.records[1].laps = 3
	race.player_car.laps = 3
	race.trial.best_lap = elapsed/3.0
	race.session.progress.mark_finished(race.player_car,elapsed)
	race.on_racer_finished(race.player_car)
	race.session.classify()
	await settle(20)

func _ready() -> void:
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"sentinel_before_setup")
	# Synthetic fixture designation is confined to this test profile, never the
	# owner's profile and never valid calibration evidence.
	race.profile.path = summer_out_dir+"/synthetic-profile.json"
	race.profile.read_only = false
	race.profile.status = ""
	var earned: Dictionary = race.profile.vehicle().duplicate(true)
	race.menu_flow.choose_mode("trial")
	race.menu_flow.show_step(3)
	race.benchmark.toggle.pressed.emit()
	check(race.benchmark.active() and race.stats_menu.launch.disabled,"benchmark_toggle_locks_upgrades")
	await settle(4)
	save_frame("locked_setup")
	prepare()
	await complete_fixture(150.0)
	check(not race.benchmark.candidate.is_empty() and race.profile.data.owner_benchmarks.is_empty(),"explicit_designation_required")
	check(race.profile.vehicle()==earned,"no_benchmark_upgrade_rewards")
	check(race.benchmark.designate_button.disabled,"designation_held_input_guard")
	race._physics_process(0.2)
	await settle(3)
	check(not race.benchmark.designate_button.disabled,"designation_enabled_after_release")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,720)]:
		get_window().size = dimensions
		await settle(4)
		var button: Button = race.benchmark.designate_button
		check(race.results_panel.get_global_rect().encloses(button.get_global_rect()),"designation_bounds_"+str(dimensions))
		check(not race.banner.get_global_rect().intersects(button.get_global_rect()),"designation_text_clear_"+str(dimensions))
		var next: Control = button.get_node(button.focus_next)
		check(next!=button and next.is_visible_in_tree(),"designation_has_navigation_exit_"+str(dimensions))
		check(next.get_node(next.focus_previous)==button,"designation_navigation_returns_"+str(dimensions))
		for other: Node in race.results_panel.find_children("*","BaseButton",true,false):
			if other!=button and other.is_visible_in_tree(): check(not button.get_global_rect().intersects(other.get_global_rect()),"designation_spacing_"+str(dimensions)+str(other.name))
	save_frame("candidate_results")
	race.benchmark.designate_button.pressed.emit()
	check(race.profile.data.owner_benchmarks.game_table.current.time==150.0,"explicit_designation_saved")
	var loaded: RefCounted = STORE.new()
	loaded.path = race.profile.path
	loaded.load_profile()
	check(loaded.data.owner_benchmarks==race.profile.data.owner_benchmarks and loaded.data.benchmark_enabled,"benchmark_reload")
	verify_collision_signature()
	var first: Dictionary = race.profile.data.owner_benchmarks.game_table.current.duplicate(true)
	var slower: Dictionary = first.duplicate(true)
	slower.time = 151.0
	check(not RULES.designate(race.profile.data.owner_benchmarks,slower),"slower_not_best")
	var faster: Dictionary = first.duplicate(true)
	faster.time = 149.0
	check(RULES.designate(race.profile.data.owner_benchmarks,faster),"faster_replaces")
	check(race.profile.data.owner_benchmarks.game_table.history==[first],"previous_retained")
	var changed: Dictionary = faster.duplicate(true)
	changed.signature = "b".repeat(64)
	changed.time = 160.0
	check(RULES.designate(race.profile.data.owner_benchmarks,changed),"changed_rules_new_baseline")
	check(race.benchmark.summary().contains("STALE") and race.profile.data.owner_benchmarks.game_table.history.size()==2,"staleness_and_history")
	for invalid: String in ["ai","impact","recovery","gate","dnf"]:
		prepare()
		match invalid:
			"ai": race.player_car.ai = true
			"impact": race.player_car.impacts = 1
			"recovery": race.player_car.crashes = 1
			"gate": race.on_gate_warning(race.player_car,false)
		if invalid=="dnf": race.session.classify()
		else: await complete_fixture(145.0)
		check(race.benchmark.candidate.is_empty(),"reject_"+invalid)
		race.player_car.ai = false
	race.show_menu()
	race.menu_flow.choose_mode("quick")
	check(not race.benchmark.active() and not race.stats_menu.launch.disabled,"normal_upgrade_rules_restored")
	check(race.active_stats()==race.profile.vehicle().stats,"earned_stats_restored")
	check(STORE.validate(JSON.parse_string(JSON.stringify(race.profile.data))).owner_benchmarks==race.profile.data.owner_benchmarks,"history_json_roundtrip")
	report("synthetic_only_not_owner_times",true)
	await settle(8)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

func verify_collision_signature() -> void:
	var original_environment: PackedScene = race.course.entry.environment
	var original_signature: String = race.trial.signature
	var fixture: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	fixture.add_child(body)
	body.owner = fixture
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	body.add_child(collider)
	collider.owner = fixture
	var previous_signature: String = original_signature
	for shift: float in [1.0,2.0]:
		body.position.x = shift
		var packed: PackedScene = PackedScene.new()
		check(packed.pack(fixture)==OK,"pack_collision_fixture")
		var path: String = summer_out_dir+"/collision-signature.tscn"
		check(ResourceSaver.save(packed,path)==OK,"save_collision_fixture")
		packed.take_over_path(path)
		race.course.entry.environment = packed
		race.trial.refresh_signature()
		check(race.trial.signature!=previous_signature and race.benchmark.summary().contains("STALE"),"collision_change_retires_benchmark_"+str(shift))
		previous_signature = race.trial.signature
	race.course.entry.environment = original_environment
	race.trial.refresh_signature()
	check(race.trial.signature==original_signature,"restored_environment_signature")
	fixture.free()
