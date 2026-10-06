extends "res://tests/autopilot/probe_base.gd"
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const STORE: Script = preload("res://scripts/profile_store.gd")
const PROGRESSION: Script = preload("res://scripts/vehicles/vehicle_progression.gd")

func action(name: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = name
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.profile_selected = true
	race.profile_menu.hide()
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	var store: RefCounted = STORE.new()
	store.read_only = true
	store.data = STORE.defaults()
	race.profile = store
	race.show_menu()
	race.garage.select(race,0)
	var rival_top_speed: float = race.all_cars[1].tuning.top_speed
	race.menu_flow.show_step(1)
	var ui: Node = race.stats_menu
	ui.open()
	await settle(3)
	save_frame("starting_upgrades")
	report("starting_zero",ui.choices.grip.text.contains("0.00") and store.vehicle().stats==STATS.starting() and store.wallet().points==0)
	report("focus_isolated",get_viewport().gui_get_focus_owner()==ui.choices.grip and race.menu.get_node("FlowNext").focus_mode==Control.FOCUS_NONE)
	await action("ui_right")
	report("no_free_upgrade",ui.pending==STATS.starting())
	store.wallet().points = 3
	await action("ui_right")
	report("keyboard_upgrade",ui.pending.grip==-1.75 and ui.cost()==1)
	await action("ui_left")
	report("pending_refund",ui.pending.grip==-2 and ui.cost()==0)
	await action("ui_down")
	report("keyboard_navigation",ui.choices.speed.has_focus())
	await action("ui_accept")
	report("select_upgrade",ui.pending.speed==-1.75)
	for i: int in range(10): ui.adjust("speed",1)
	report("budget_limit",ui.cost()==3 and ui.pending.speed==-1.25)
	ui.close()
	ui.open()
	report("cancel_no_spend",store.wallet().points==3 and ui.pending==STATS.starting())
	ui.adjust("speed",1)
	ui.apply()
	report("save_upgrade",not ui.panel.visible and store.vehicle().stats.speed==-1.75 and store.wallet().points==2 and is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*0.825))
	race.garage.select(race,1)
	report("vehicle_shared_rivals_unchanged",store.vehicle().stats.speed==-1.75 and is_equal_approx(race.all_cars[1].tuning.top_speed,rival_top_speed))
	ui.open()
	ui.adjust("acceleration",1)
	report("acceleration_upgrade",ui.pending.acceleration==-1.75 and ui.cost()==1)
	ui.adjust("acceleration",-1)
	ui.adjust("speed",-1)
	report("no_refund_saved_upgrade",ui.pending.speed==-1.75)
	store.wallet().points = 200
	for field: String in STATS.FIELDS:
		for i: int in range(30): ui.adjust(field,1)
	report("max_cap",ui.pending==STATS.full() and STATS.spent(ui.pending)==120)
	await settle(3)
	save_frame("max_upgrades")
	ui.apply()
	report("max_tuning",is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*1.24) and is_equal_approx(race.player_car.tuning.grip,race.player_car.base_tuning.grip*1.4))
	store.wallet().bling = 300
	ui.open()
	ui.shop_button.pressed.emit()
	ui.choices.speed.pressed.emit()
	var points_before: int = store.wallet().points
	report("buy_paint",store.vehicle().paint=="mint" and store.wallet().bling==200 and "mint" in store.vehicle().owned)
	ui.choices.speed.pressed.emit()
	report("equip_free",store.wallet().bling==200 and store.wallet().points==points_before)
	ui.choices.recovery.pressed.emit()
	report("reject_expensive_paint",store.vehicle().paint=="mint" and store.wallet().bling==200)
	report("visible_paint",race.garage.paint_meshes(race.player_car.visual)[0].material_override.get_shader_parameter("player_colour").is_equal_approx(PROGRESSION.COLORS[1]))
	store.wallet().bling += 100
	ui.choices.recovery.pressed.emit()
	var body: MeshInstance3D = race.garage.paint_meshes(race.player_car.visual)[0]
	report("chrome_finish",store.vehicle().paint=="chrome" and is_equal_approx(body.material_override.get_shader_parameter("paint_metallic"),0.9))
	ui.choices.grip.pressed.emit()
	report("stock_finish_restored",store.vehicle().paint=="stock" and is_equal_approx(body.material_override.get_shader_parameter("paint_metallic"),0.0) and is_equal_approx(body.material_override.get_shader_parameter("paint_roughness"),0.8))
	ui.choices.speed.pressed.emit()
	await settle(3)
	save_frame("bling_shop")
	ui.close()
	store.vehicle().stats = STATS.starting()
	store.wallet().points = 0
	store.wallet().bling = 0
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.start_race()
	race.begin_countdown()
	# Feed the authoritative finish classification; the route and handling are unchanged.
	for i: int in range(race.cars.size()): race.session.progress.mark_finished(race.cars[i],10.0+i)
	race.session.classify()
	report("results_award",store.wallet().points==3 and store.wallet().bling==30 and race.reward_note.contains("+3 UPGRADE"))
	race.on_results_ready(race.session.results)
	report("award_once",store.wallet().points==3 and store.wallet().bling==30)
	await settle(3)
	save_frame("race_rewards")
	var rows: Array = [{"player":1,"rank":2,"finished":true},{"player":2,"rank":1,"finished":true}]
	report("second_reward",PROGRESSION.rewards("quick",3,rows).points==2)
	rows[0].rank = 4
	report("completion_reward",PROGRESSION.rewards("quick",3,rows).points==1)
	rows[0].rank = 1
	report("long_race",PROGRESSION.rewards("cup",6,rows).points==6)
	report("solo_trial",PROGRESSION.rewards("trial",3,rows).points==1 and PROGRESSION.rewards("quick",3,[rows[0]]).points==1)
	rows[0].finished = false
	report("dnf_no_reward",PROGRESSION.rewards("quick",3,rows).points==0)
	var legacy: Dictionary = STORE.validate({"schema_version":6,"quick_race":{"driver":2},"player_stats":{"2":{"grip":-1,"speed":1,"boost":1,"recovery":-1}}})
	report("legacy_migration",STATS.code(legacy.vehicles.buggy.stats)=="-1.00,1.00,1.00,-1.00,0.00" and legacy.vehicles.buggy.points==0)
	report("missing_legacy_starts_zero",STORE.validate({"schema_version":5}).vehicles.buggy.stats==STATS.starting())
	var old_vehicle: Dictionary = STORE.validate({"schema_version":7,"vehicles":{"buggy":{"stats":{"grip":-2,"speed":1,"boost":0,"recovery":2},"points":7,"bling":120,"owned":["stock","mint"],"paint":"mint"}}})
	report("vehicle_migration",old_vehicle.vehicles.buggy.stats.acceleration==0.0 and old_vehicle.vehicles.buggy.stats.speed==1 and old_vehicle.wallet.points==7 and old_vehicle.vehicles.buggy.paint=="mint")
	report("old_record_keys",STORE.valid_record_key("blackjack|buggy|3|trial|0|0|stats-2:-2.00,-1.75,-2.00,-2.00"))
	report("invalid_stats",not STATS.valid({"grip":4.25,"speed":0,"boost":0,"recovery":0,"acceleration":0}) and not STATS.valid({"grip":-2.25,"speed":0,"boost":0,"recovery":0,"acceleration":0}) and not STATS.valid({"grip":0.1,"speed":0,"boost":0,"recovery":0,"acceleration":0}) and not STATS.valid({"grip":0,"speed":0,"boost":0,"recovery":0,"acceleration":4.25}))
	var fractional: Dictionary = {"grip":-2,"speed":-1.75,"boost":-2,"recovery":-2,"acceleration":-2}
	var key: String = STORE.record_key("trial",3,0,0,"game_table",STATS.code(fractional))
	report("record_keys",STORE.valid_record_key(key) and STORE.valid_record_key("blackjack|buggy|3|trial|0|0|stats-1:-1,1,1,-1"))
	store.vehicle().stats = fractional
	store.path = summer_out_dir+"/profile.json"
	store.read_only = false # Only this disposable evidence profile may be written.
	var error: Error = store.save_profile()
	store.read_only = true
	var restored: RefCounted = STORE.new()
	restored.path = store.path
	restored.load_profile()
	restored.read_only = true
	report("disk_persistence",error==OK and restored.data==store.data)
	var passed: bool = true
	for value: Variant in _reports.values():
		if value is bool and not value: passed = false
	report("passed",passed)
	# Let the disposable audio mixer release its active playback before shutdown.
	race.set_physics_process(false)
	for player: Node in race.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")


