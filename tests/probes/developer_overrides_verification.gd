extends "res://tests/autopilot/probe_base.gd"
const MODEL: Script = preload("res://scripts/vehicles/developer_tuning.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.machine_settings.read_only = true
	race.profile_directory.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_selected = true
	race.profile_menu.hide()
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	race.rival_count = 3
	race.race_mode = "quick"
	race.course.select("game_table")
	for wait_frame: int in range(300):
		if not race.course.loading: break
		await get_tree().process_frame
	race.configure_quick_race()
	var dev: RefCounted = race.developer
	var car: CharacterBody3D = race.player_car
	race.set_vehicle("buggy")
	race.controller.using_pad = false
	var saved: Dictionary = race.profile.data.duplicate(true)
	var stock: Resource = car.base_tuning.duplicate(true)
	check(not dev.set_value("player","grip",NAN),"reject_nan")
	check(not dev.set_value("player","grip",INF),"reject_inf")
	check(not dev.set_value("player","recovery_duration",0.0),"reject_zero_duration")
	check(not dev.set_value("player","ai.speed",1.0),"reject_player_ai")
	check(dev.set_value("all_ai","grip",0.0),"all_ai")
	check(dev.set_value("ai_2","grip",2.0),"individual_ai")
	check(dev.values("all_ai","grip").mixed and car.tuning.grip!=0.0,"mixed_independent")
	dev.reset_all()
	check(is_equal_approx(race.all_cars[2].tuning.grip,race.all_cars[2].base_tuning.grip),"reset_ai")
	var old_size: Vector3 = car.tuning.collision_size
	check(dev.set_value("player","collision_size.x",old_size.x*2.0),"geometry_edit")
	check(car.tuning.collision_size==old_size,"geometry_pending")
	car.reset_car(10,0)
	check(car.get_node("Collision").shape.size.x==old_size.x*2.0,"geometry_reset_applied")
	dev.reset_all()
	car.reset_car(10,0)
	check(car.get_node("Collision").shape.size==old_size,"geometry_reset_parity")
	var count: int = 0
	var classes: Array[String] = preload("res://scripts/vehicles/vehicle_catalog.gd").IDS.duplicate()
	if "--developer-smoke" in OS.get_cmdline_user_args(): classes.clear()
	for vehicle_id: String in classes:
		dev.reset_all()
		race.set_vehicle(vehicle_id)
		for item: Dictionary in MODEL.descriptors(car.base_tuning,race.difficulty):
			var target: String = "ai_1" if item.target=="ai" else "player"
			var subject: CharacterBody3D = race.all_cars[1] if item.target=="ai" else car
			for value: Variant in ([false,true] if item.type=="bool" else [item.min,item.default,item.max]):
				dev.reset_all()
				check(dev.set_value(target,item.field,value),"set_"+item.field+"_"+str(value))
				race.session.reset()
				race.session.change_phase(2)
				race.session.race_time = 0.0
				car.ai = true
				for vehicle: CharacterBody3D in race.cars:
					vehicle.reset_car(10+vehicle.player*5,0)
				await settle_physics(8)
				check(subject.position.is_finite() and subject.velocity.is_finite() and subject.transform.basis.is_finite(),"finite_"+item.field+"_"+str(value))
				count += 1
	dev.reset_all()
	race.set_vehicle("buggy")
	dev.reset_all()
	car.ai = false
	check(car.base_tuning.grip==stock.grip and car.base_tuning.collision_size==stock.collision_size and car.base_tuning.surface_grip==stock.surface_grip,"base_immutable")
	check(dev.set_value("player","boost_drain",0.0),"unlimited_boost")
	car.boost = 100
	race.session.reset()
	race.session.change_phase(2)
	car.reset_car(10,0)
	dev.set_value("player","boost_drain",0.0)
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(30)
	Input.action_release("p1_go")
	Input.action_release("boost")
	check(car.boost==100.0 and car.boost_was_on,"unlimited_boost_drive")
	car.boost = 0
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(3)
	Input.action_release("p1_go")
	Input.action_release("boost")
	check(car.boost_was_on,"unlimited_empty_meter")
	check(car.tuning.boost_drain==0.0,"zero_drain_effective")
	dev.reset_target("player")
	check(race.experimental(),"run_latch")
	race.trial.finish_run()
	check(race.trial.result_note.contains("RECORDS DISABLED"),"record_guard")
	race.rewards_awarded = false
	race.award_race_rewards([{"player":1,"rank":1,"finished":true}])
	check(race.reward_note.contains("REWARDS DISABLED"),"reward_guard")
	race.benchmark.candidate = {"time":10.0}
	race.benchmark.designate()
	check(race.benchmark.candidate.size()==1,"benchmark_guard")
	check(not race.tournament.begin(),"tournament_guard")
	race.challenge.resolved = false
	race.challenge.score()
	check(race.profile.data.records==saved.records and race.profile.data.challenges==saved.challenges and race.profile.data.owner_benchmarks==saved.owner_benchmarks and race.profile.data.vehicles==saved.vehicles,"no_progression_writes")
	race.session.change_phase(0)
	dev.run_experimental = false
	dev.reset_all()
	check(not race.experimental(),"reset_ranked_next_run")
	check(is_equal_approx(car.tuning.grip,STATS.compose(car.base_tuning,race.active_stats()).grip),"earned_reset_parity")
	race.start_race()
	race.begin_countdown()
	race.start_lights.hide()
	race.session.change_phase(2)
	dev.set_value("player","acceleration",car.base_tuning.acceleration*2.0)
	race.get_node("HUD").show()
	race.get_node("HUD/Menu").hide()
	await settle(4)
	check(race.get_node("HUD/VehicleContext").text.contains("EXPERIMENTAL") and race.get_node("HUD/VehicleContext").is_visible_in_tree(),"unranked_label")
	save_frame("experimental_drive")
	dev.reset_all()
	race.session.change_phase(0)
	report("descriptor_cases",count)
	report("failures",failures)
	report("passed",failures.is_empty())
	save_frame("override_verification")
	stock = null
	race.set_process(false)
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
	for voice: Node in app.find_children("*","AudioStreamPlayer3D",true,false):
		voice.stop()
	await settle_physics(20)
	finish()
