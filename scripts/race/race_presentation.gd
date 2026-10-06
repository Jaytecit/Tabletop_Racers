extends Node3D
# Default 3D prototype; main.tscn preserves the original 2D fallback.
var garage: RefCounted = preload("res://scripts/race/race_garage.gd").new()
var menu_flow: RefCounted
@export var race_music: AudioStream = preload("res://audio/music/race1.ogg")
const MENU_MUSIC: AudioStream = preload("res://audio/music/main_theme_menu.ogg")
const OPENING_MUSIC: AudioStream = preload("res://audio/music/opening_theme_mix.ogg")
const EASY_MUSIC: AudioStream = preload("res://audio/music/menu_driving_excitement.ogg")
const NIGHTMARE_MUSIC: AudioStream = preload("res://audio/music/nightmare_driving.mp3")
const SOUNDTRACK: Script = preload("res://scripts/race/course_soundtrack.gd")
@export var hard_music: AudioStream = preload("res://audio/music/hard_jungle.mp3")
@export var final_lap_music: AudioStream
const MUSIC_VOLUME_DB: float = -22.0
const MUSIC_DUCK_DB: float = -30.0
var music: AudioStreamPlayer
var engine_layer: AudioStreamPlayer
var profile: RefCounted = preload("res://scripts/profile_store.gd").new()
var profile_directory: RefCounted = preload("res://scripts/profiles/profile_directory.gd").new()
var machine_settings: RefCounted = preload("res://scripts/profiles/machine_settings.gd").new()
var profile_selected: bool = false
var active_profile_id: String = ""
var profile_menu: Control
var identities: Node
var developer: RefCounted = preload("res://scripts/vehicles/developer_tuning.gd").new(self)

func experimental() -> bool:
	return stats_test_mode!=0 or developer.active() or developer.run_experimental

var stats_test_mode: int = 0 # Session-only: earned, displayed zero, full.

func active_stats() -> Dictionary:
	if benchmark.active(): return preload("res://scripts/vehicles/player_stats.gd").neutral()
	var stats: Script = preload("res://scripts/vehicles/player_stats.gd")
	if stats_test_mode==1: return stats.starting()
	if stats_test_mode==2: return stats.full()
	return profile.vehicle().stats

var rewards_awarded: bool = true
var reward_note: String = ""
var benchmark: RefCounted = preload("res://scripts/race/owner_benchmark.gd").new()
var drift: RefCounted = preload("res://scripts/race/drift_controller.gd").new()
var roadmap: RefCounted = preload("res://scripts/race/challenge_roadmap.gd").new()
var challenge: RefCounted = preload("res://scripts/race/challenge_controller.gd").new()
var tournament: RefCounted = preload("res://scripts/race/tournament_controller.gd").new()
var trial: RefCounted = preload("res://scripts/race/time_trial.gd").new()
var race_mode: String = "quick"
var track_id: String = "game_table"
var course: RefCounted = preload("res://scripts/tracks/selected_course.gd").new()
const CUP: Script = preload("res://scripts/race/cup_rules.gd")
const ARCADE: Script = preload("res://scripts/race/arcade_presentation.gd")
var cup_round_scored: bool = false
var rival_count: int = 3
var race_laps: int = 3
var all_cars: Array = []
var difficulty: int = 1
var race_seed: int = 42
var camera_driver: RefCounted = preload("res://scripts/race/race_camera.gd").new()
var feedback: RefCounted = preload("res://scripts/race/race_feedback.gd").new()
var intro_time: float = 0.0
var controls_setup: Node
var stats_menu: Node
var setup_menu: Node
var developer_menu: Node
var victory_celebration: Node3D
var start_lights: Control
var session: Node
var phase: int:
	get: return session.phase if session!=null else 0
var paused_race: bool:
	get: return session.paused if session!=null else false
	set(value):
		if session!=null:
			session.paused = value
			apply_pause()
var race_time: float:
	get: return session.race_time if session!=null else 0.0
var countdown: float:
	get: return session.countdown if session!=null else 3.8
var last_count: int = 3
var muted: bool = false
var cars: Array = []
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var tyre_surface: String = "felt"
var cue_duck: float = 0.0
var results_input_guard: bool = false
var results_guard_time: float = 0.0
var message_time: float = 0.0
var message: String = ""
var wrong_way_time: float = 0.0
var wrong_way_notice: Label
var hud_tick: float = 0.0
var action_latches := PackedByteArray([0,0,0,0])
var names := PackedStringArray(["YOU","BLUE COMET","GOLD RUSH","GREEN MACHINE"])
@onready var track: Node3D = $Track
@onready var controller: Node = $Controller
@onready var player_car: CharacterBody3D = $Car1
@onready var camera: Camera3D = $Camera
@onready var banner: Label = $HUD/Banner
@onready var menu: Control = $HUD/Menu
@onready var results_panel: Control = $HUD/ResultsBackdrop
@onready var engine_sound: AudioStreamPlayer = $Engine
@onready var skid_sound: AudioStreamPlayer = $Skid
func _ready() -> void:
	roadmap.race = self
	DisplayServer.window_set_title(preload("res://scripts/race/game_brand.gd").NAME)
	all_cars = [$Car1,$Car2,$Car3,$Car4]
	# Additional AI cars share the neutral reference build, not player upgrades.
	for id: int in range(5,9):
		var rival: CharacterBody3D = preload("res://scenes/vehicles/buggy_4.tscn").instantiate()
		rival.name = "Car%d" % id
		rival.player = id
		rival.lane = -0.5 if id%2==1 else 0.5
		add_child(rival)
		all_cars.append(rival)
	names.resize(all_cars.size())
	cars = all_cars.duplicate()
	profile.load_profile()
	# The native runner consumes its CLI flags before exposing command-line args.
	var verification: bool = "--summer-verify" in OS.get_cmdline_args() or get_tree().root.has_node("SummerProbe")
	profile.read_only = true # No personal writes before confirmation.
	profile_directory.read_only = verification or profile_directory.read_only
	profile_directory.load_directory()
	machine_settings.read_only = verification or machine_settings.read_only
	machine_settings.load_settings(profile.data.setup)
	profile.data.setup = machine_settings.data
	race_mode = profile.data.mode
	tournament.configure(self)
	challenge.configure(self)
	drift.configure(self)
	benchmark.configure(self)
	difficulty = profile.data.quick_race.difficulty
	rival_count = profile.data.quick_race.rivals
	race_laps = profile.data.quick_race.laps
	session = preload("res://scripts/race/race_session.gd").new()
	session.name = "RaceSession"
	add_child(session)
	session.configure(cars,track)
	session.phase_changed.connect(on_phase_changed)
	session.lap_completed.connect(on_lap_completed)
	session.racer_finished.connect(on_racer_finished)
	session.racer_eliminated.connect(on_racer_eliminated)
	session.time_extended.connect(func(seconds: float) -> void: feedback.post("+%.1fs CHECKPOINT" % seconds,1.2,2))
	session.results_ready.connect(on_results_ready)
	session.gate_warning.connect(on_gate_warning)
	setup_audio()
	feedback.configure(self)
	victory_celebration = preload("res://scripts/race/victory_celebration.gd").new()
	victory_celebration.name = "VictoryCelebration"
	add_child(victory_celebration)
	camera_driver.configure(self)
	setup_difficulty()
	garage.setup(self)
	garage.select(self,profile.data.quick_race.driver)
	setup_quick_race()
	trial.configure(self)
	setup_modes()
	course.configure(self)
	if race_mode=="drift" and profile.data.quick_race.track_id not in preload("res://scripts/tracks/content_catalog.gd").DRIFT_COURSES: profile.data.quick_race.track_id = preload("res://scripts/tracks/content_catalog.gd").DRIFT_COURSES[0]
	course.select(tournament.next_course() if race_mode=="tournament" else (CUP.course_id(profile.data.cup) if race_mode=="cup" else profile.data.quick_race.track_id))
	ARCADE.setup(self)
	preload("res://scripts/race/asset_credits.gd").setup(self)
	controls_setup = preload("res://scripts/race/controls_setup.gd").new()
	add_child(controls_setup)
	controls_setup.setup(self)
	setup_menu = preload("res://scripts/race/setup_menu.gd").new()
	add_child(setup_menu)
	setup_menu.setup(self)
	menu_flow = preload("res://scripts/race/arcade_menu_flow.gd").new()
	menu_flow.setup(self)
	roadmap.setup(self)
	tournament.setup_ui()
	benchmark.setup_ui()
	stats_menu = preload("res://scripts/race/player_stats_menu.gd").new()
	add_child(stats_menu)
	stats_menu.setup(self)
	developer_menu = preload("res://scripts/race/developer_menu.gd").new()
	add_child(developer_menu)
	developer_menu.setup(self)
	profile_menu = preload("res://scripts/profiles/profile_menu.gd").new()
	profile_menu.race = self
	$HUD.add_child(profile_menu)
	identities = preload("res://scripts/race/racer_identity.gd").new()
	identities.race = self
	add_child(identities)
	wrong_way_notice = ARCADE.label($HUD,"WrongWay","WRONG WAY",Vector2(400,188),Vector2(400,42),28,ARCADE.GOLD)
	wrong_way_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrong_way_notice.add_theme_stylebox_override("normal",ARCADE.box(ARCADE.INK,ARCADE.GOLD,2))
	wrong_way_notice.hide()
	show_menu()
	if get_parent().name!="App" and not verification: open_profiles.call_deferred()

func open_profiles() -> void:
	if phase not in [0,4]: return
	profile_menu.open()

func activate_profile(id: String) -> Error:
	if phase not in [0,4]: return ERR_BUSY
	var error: Error = profile_directory.select_profile(id,profile)
	if error!=OK: return error
	profile_selected = true
	roadmap.choices.clear()
	roadmap.resolved = true
	active_profile_id = id
	profile.data.setup = machine_settings.data
	stats_test_mode = 0
	race_mode = profile.data.mode
	difficulty = profile.data.quick_race.difficulty
	rival_count = profile.data.quick_race.rivals
	race_laps = profile.data.quick_race.laps
	tournament.round_index = -1
	tournament.run_signature = ""
	tournament.scored = true
	cup_round_scored = false
	trial.recording.clear()
	trial.playback.clear()
	trial.completed = false
	challenge.configure(self)
	drift.configure(self)
	garage.select(self,profile.data.quick_race.driver)
	challenge.context.clear()
	challenge.resolved = true
	challenge.note = ""
	challenge.missed_gates = 0
	drift.context.clear()
	drift.resolved = true
	drift.elapsed = 0.0
	drift.note = ""
	benchmark.candidate.clear()
	benchmark.notice = ""
	var selected: String = tournament.next_course() if race_mode=="tournament" else profile.data.quick_race.track_id
	if race_mode=="drift" and selected not in preload("res://scripts/tracks/content_catalog.gd").DRIFT_COURSES: selected = preload("res://scripts/tracks/content_catalog.gd").DRIFT_COURSES[0]
	course.request_select.call_deferred(selected)
	refresh_mode()
	return OK

func setup_grid() -> void:
	camera_driver.reset(camera,player_car)

func _exit_tree() -> void:
	course.shutdown()

func set_vehicle(id: String) -> bool:
	if id not in preload("res://scripts/vehicles/vehicle_catalog.gd").IDS: return false
	profile.data.quick_race.vehicle_id = id
	if race_mode=="freestyle": profile.data.freestyle_vehicle = id
	for car: CharacterBody3D in all_cars:
		if not car.set_class(id): return false
	garage.select(self,garage.selected)
	if is_instance_valid(trial.ghost): trial.rebuild_ghost()
	if menu_flow!=null: menu_flow.reset_vehicle()
	return true

func start_race() -> void:
	if developer_menu!=null and developer_menu.root.visible: return
	if not profile_selected or profile_menu.visible: return
	if course.loading or (stats_menu!=null and stats_menu.panel.visible) or course.error!="" or (controls_setup!=null and controls_setup.panel.visible) or (setup_menu!=null and setup_menu.panel.visible): return
	if benchmark.active(): stats_test_mode = 0
	developer.run_experimental = developer.active()
	roadmap.begin()
	if race_mode=="tournament" and not tournament.begin(): return
	if race_mode=="cup" and not experimental():
		if profile.data.cup.is_empty() or profile.data.cup.rounds.size()==3:
			profile.data.cup = CUP.fresh()
		if not course.select(CUP.course_id(profile.data.cup)): return
	cleanup()
	cup_round_scored = false
	music.stream = looped_music(selected_race_music())
	music.play()
	rewards_awarded = false
	reward_note = ""
	configure_quick_race()
	save_preferences()
	session.reset()
	if race_mode=="tournament":
		for car: CharacterBody3D in cars: car.ai_driver.difficulty = tournament.RULES.DIFFICULTY
	if phase!=4: session.change_phase(session.Phase.PREVIEW)
	intro_time = 0.0
	if phase==4:
		show_track_error()
		return
	setup_grid()
	last_count = 3
	menu.visible = false
	ARCADE.refresh(self)
	update_hud()
	banner.visible = true
	banner.text = preview_prompt()
	banner.position = Vector2(260,650)
	banner.size = Vector2(680,70)
	banner.add_theme_font_size_override("font_size",20)
	ARCADE.refresh_message(self)
func preview_prompt() -> String:
	return "PRESS %s / ENTER TO START" % [controls_setup.select_name()]

func begin_countdown() -> void:
	if phase!=session.Phase.PREVIEW: return
	camera_driver.reset(camera,player_car)
	session.change_phase(session.Phase.COUNTDOWN)
	trial.begin()
	if race_mode=="challenge": challenge.begin()
	if race_mode=="drift": drift.begin()
	benchmark.begin()
	banner.position = Vector2(260,287)
	banner.size = Vector2(680,172)
	banner.text = ""
	banner.hide()
	start_lights.update(self)
	ARCADE.refresh_message(self)
	play_sound("count")
	update_hud()

func is_menu_music() -> bool:
	return music.stream == MENU_MUSIC or music.stream == OPENING_MUSIC

func show_menu() -> void:
	course.cancel_selection()
	if menu_flow!=null and phase in [1,2,3,5,6]: menu_flow.show_step(0)
	cleanup()
	# Preserve the complete song and its quiet tail through menu refreshes.
	# Returning from a race starts a fresh menu visit.
	if not is_menu_music():
		music.stream = MENU_MUSIC
		music.play()
	configure_quick_race()
	session.menu()
	if phase==4:
		show_track_error()
		return
	setup_grid()
	menu.visible = true
	refresh_mode()
	banner.visible = false
	$HUD/Menu/Start.disabled = course.error!=""
	focus_start.call_deferred()
	update_hud()
	course.refresh()
	ARCADE.refresh(self)

func show_course_selection() -> void:
	show_menu()
	menu_flow.show_step(3)
func show_track_error() -> void:
	menu.visible = true
	banner.visible = true
	banner.text = "TRACK UNAVAILABLE\n"+track.validation_errors[0]+"\nSELECT ANOTHER COURSE FROM THE MENU"
	$HUD/Menu/Start.disabled = true
func toggle_pause() -> void:
	if developer_menu!=null and developer_menu.root.visible: return
	if phase not in [1,2,5]: return
	session.toggle_pause()
	apply_pause()
	banner.visible = paused_race
	banner.text = "PAUSED\nSTART / ESC · RESUME" if paused_race else ""
	start_lights.update(self)
func fail_safe(reason: String) -> void:
	if phase==4: return
	push_error(reason)
	cleanup()
	session.fail()
	banner.visible = true
	banner.text = "RACE PAUSED\n"+reason
func tapped(action: String, slot: int) -> bool:
	var down: bool = Input.is_action_pressed(action)
	var fresh: bool = down and action_latches[slot]==0
	action_latches[slot] = 1 if down else 0
	return fresh
func _physics_process(delta: float) -> void:
	if developer_menu!=null and developer_menu.root.visible: return
	if profile_menu!=null and profile_menu.visible: return
	if results_input_guard:
		results_guard_time = maxf(0.0,results_guard_time-delta)
		if results_guard_time<=0.0 and not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("start_race"):
			results_input_guard = false
			for title: String in ["Retry","CourseSelect","Menu"]: results_panel.get_node(title).disabled = false
			results_panel.get_node("Retry").grab_focus()
			benchmark.refresh()
	if stats_menu!=null and stats_menu.panel.visible: return
	if controls_setup!=null and controls_setup.panel.visible: return
	if setup_menu!=null and setup_menu.panel.visible: return
	if Input.is_action_just_pressed("cycle_camera"): cycle_camera()
	if phase==6 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("start_race")): begin_countdown()
	if tapped("restart",0): start_race()
	if tapped("pause_race",1): toggle_pause()
	if tapped("menu",2):
		if phase==0 and menu_flow!=null: menu_flow.go_back()
		else: show_menu()
	if tapped("mute",3):
		setup_menu.set_mute(not muted)
	if phase==0 and Input.is_action_just_pressed("start_race") and get_viewport().gui_get_focus_owner()==$HUD/Menu/Start: start_race()
	if phase==4: return
	if paused_race:
		engine_sound.stream_paused = true
		skid_sound.stream_paused = true
		return
	if engine_sound.stream_paused: engine_sound.stream_paused = false
	if skid_sound.stream_paused: skid_sound.stream_paused = false
	trial.observe()
	feedback.tick(delta)
	session.tick(delta)
	if race_mode=="drift": drift.tick(delta)
	start_lights.update(self)
	if phase in [2,5]: trial.tick_playback(race_time)
	if phase==1:
		var count: int = int(ceil(maxf(countdown-0.8,0.0)))
		if count!=last_count and count>0:
			last_count = count
			play_sound("count")
	if phase in [2,5]:
		if phase==2 and player_car.finish_time<0.0 and not engine_sound.playing: engine_sound.play()
		cue_duck = maxf(0.0,cue_duck-delta)
		var surface_kind: String = track.at(player_car.station).surface
		if surface_kind!=tyre_surface and sounds.has("tyre_"+surface_kind):
			tyre_surface = surface_kind
			skid_sound.stream = sounds["tyre_"+surface_kind]
		feedback.tick_messages(delta)
		update_wrong_way(delta)
		banner.visible = phase==5 or message_time>0.0
		banner.text = "FINISHED · WAITING FOR RIVALS\n%d / %d · %.2fs" % [rank_of(player_car),cars.size(),player_car.finish_time] if phase==5 else (message if message_time>0.0 else "")
		if eliminated_player():
			banner.visible = true
			banner.text = "ELIMINATED / PLACE %d\nRIVALS STILL RACING / RETRY OR WATCH" % session.rank_of(player_car)
		var deadline: float = session.progress.records[player_car.player].missed_deadline
		if deadline>=0.0:
			banner.visible = true
			banner.text = "MISSED GATE %d · RETURN!\n%.1fs BEFORE +5s PENALTY" % [player_car.gate,maxf(0.0,deadline-race_time)]
		var speed: float = Vector2(player_car.velocity.x,player_car.velocity.z).length()
		engine_sound.pitch_scale = 0.7+speed/7.5
		engine_layer.pitch_scale = 0.65+speed/9.0
		engine_layer.volume_db = -80.0 if muted else (-34.0+minf(speed,12.0)*0.5)
		music.volume_db = -80.0 if muted else MUSIC_VOLUME_DB
		if phase==2 and player_car.effects.tyre_active() and not skid_sound.playing: skid_sound.play()
		elif not player_car.effects.tyre_active(): skid_sound.stop()
	if phase==6:
		intro_time += delta
		camera_driver.preview(camera,track,intro_time)
		banner.text = preview_prompt()
	if phase in [1,2,5]:
		var followed: CharacterBody3D = player_car
		if eliminated_player() and not session.elimination.active_ids().is_empty(): followed = all_cars[session.elimination.active_ids()[0]-1]
		camera_driver.tick(camera,followed,delta)
		camera_driver.apply_feedback(camera,followed,feedback.camera_offset())
	hud_tick += delta
	if hud_tick>=0.10:
		hud_tick = 0.0
		update_hud()
func observe_progress(car: CharacterBody3D, hit: Vector2, delta: float) -> void:
	session.observe(car,hit,delta)
func rank_of(car: CharacterBody3D) -> int:
	return session.rank_of(car)
func on_phase_changed(value: int) -> void:
	if value!=2 and wrong_way_notice!=null:
		wrong_way_time = 0.0
		wrong_way_notice.hide()
	if value==2:
		feedback.post(trial.ghost_notice,3.0,2)
		play_sound("go")
		engine_sound.play()
		engine_layer.play()

func on_gate_warning(car: CharacterBody3D, penalized: bool) -> void:
	if car.player!=1: return
	if race_mode=="challenge": challenge.gate_warning()
	if benchmark.active(): benchmark.missed_gates += 1
	feedback.post("+5s PENALTY · RETURNING TO GATE" if penalized else "MISSED GATE · RETURN WITHIN 5s",3.0,3)
	controller.rumble(0.2,0.25)

func on_lap_completed(car: CharacterBody3D, lap: int) -> void:
	if car.player==1: trial.lap(session.lap_crossing_time)
	if car.player==1 and lap<session.laps_required:
		if lap==session.laps_required-1 and final_lap_music!=null and SOUNDTRACK.path_for_course(track_id).is_empty():
			music.stream = looped_music(final_lap_music)
			music.play()
		feedback.post(("FINAL LAP!" if lap==session.laps_required-1 else "LAP %d / %d" % [lap+1,session.laps_required])+(" · BEST %.2fs" % trial.best_lap if race_mode=="trial" else ""),1.5,2)
		controller.rumble(0.2,0.15)

func on_racer_finished(car: CharacterBody3D) -> void:
	if car.player==1:
		benchmark.finish()
		trial.finish_run()
		feedback.messages.clear()
		engine_sound.stop()
		engine_layer.stop()
		skid_sound.stop()
		controller.rumble(0.35,0.45)

func eliminated_player() -> bool:
	return race_mode=="elimination" and session!=null and 1 in session.elimination.eliminated and phase in [2,3,5]

func on_racer_eliminated(car: CharacterBody3D, rank: int) -> void:
	if car.player!=1:
		feedback.post("CAR %d ELIMINATED" % car.player,2.0,2)
		if eliminated_player(): preload("res://scripts/race/arcade_podium.gd").show_results(self,session.elimination.rows())
		return
	feedback.clear()
	engine_sound.stop()
	engine_layer.stop()
	skid_sound.stop()
	results_panel.show()
	preload("res://scripts/race/arcade_podium.gd").show_results(self,session.elimination.rows())
	banner.show()
	banner.text = "ELIMINATED / PLACE %d\nRIVALS STILL RACING / RETRY OR WATCH" % rank
	results_input_guard = true
	results_guard_time = 0.15
	for title: String in ["Retry","CourseSelect","Menu"]: results_panel.get_node(title).disabled = true
	benchmark.refresh()
	update_hud()

func on_results_ready(rows: Array) -> void:
	feedback.shake = 0.0
	feedback.shake_time = 0.0
	camera.position -= camera_driver.feedback_offset
	camera_driver.feedback_offset = Vector3.ZERO
	award_race_rewards(rows)
	var cup_note: String = ""
	if race_mode=="cup" and not experimental(): cup_note = score_cup(rows)
	if race_mode=="tournament": cup_note = tournament.score(rows)
	if race_mode=="challenge": cup_note = challenge.score()
	if race_mode=="drift": cup_note = drift.note
	if race_mode=="time_attack": cup_note = "TIME EXPIRED" if session.time_attack.expired else "CLOCK BEATEN / %.1fs REMAINING" % session.time_attack.remaining(race_time)
	if race_mode=="time_attack" and trial.result_note!="": cup_note += "\n"+trial.result_note
	cup_note += roadmap.award()
	if race_mode=="elimination": cup_note = "LAST SURVIVOR · "+names[rows[0].player-1]+("\n"+trial.result_note if trial.result_note!="" else "")
	engine_layer.stop()
	results_panel.visible = true
	banner.add_theme_font_size_override("font_size",20)
	banner.position = Vector2(260,287)
	banner.size = Vector2(680,310)
	engine_sound.stop()
	skid_sound.stop()
	for car: CharacterBody3D in cars:
		car.velocity = Vector3.ZERO
		car.ring.visible = false
		car.effects.stop()
		for emitter: CPUParticles3D in [car.smoke,car.sparks,car.debris]: emitter.emitting = false
	banner.visible = true
	preload("res://scripts/race/arcade_podium.gd").show_results(self,rows)
	if race_mode!="trial" and not rows.is_empty() and rows[0].player==1 and rows[0].finished:
		victory_celebration.start(player_car)
	banner.text = (cup_note if race_mode in ["cup","tournament","challenge","elimination","time_attack","drift"] else trial.result_note)+("\n" if race_mode in ["cup","tournament","challenge","elimination","time_attack","drift"] or trial.result_note!="" else "")+reward_note
	if benchmark.active() and benchmark.notice!="": banner.text += "\n"+benchmark.notice
	update_hud()
	results_input_guard = true
	results_guard_time = 0.15
	for title: String in ["Retry","CourseSelect","Menu"]: results_panel.get_node(title).disabled = true
	benchmark.refresh()

func award_race_rewards(rows: Array) -> void:
	if not profile_selected: return
	if rewards_awarded: return
	rewards_awarded = true
	if benchmark.active():
		reward_note = "OWNER BENCHMARK / NO UPGRADE REWARDS"
		return
	if experimental():
		reward_note = "EXPERIMENTAL / REWARDS DISABLED"
		return
	var rewards: Dictionary = preload("res://scripts/vehicles/vehicle_progression.gd").rewards(race_mode,session.laps_required,rows)
	if rewards.points==0:
		reward_note = "FINISH THE RACE TO EARN UPGRADES"
		return
	var build: Dictionary = profile.wallet()
	build.points = mini(build.points+rewards.points,999999)
	build.bling = mini(build.bling+rewards.bling,999999)
	reward_note = "+%d UPGRADE POINTS / +%d BLING" % [rewards.points,rewards.bling]
	save_preferences()

func apply_pause() -> void:
	if paused_race:
		wrong_way_time = 0.0
		wrong_way_notice.hide()
	music.stream_paused = paused_race
	engine_layer.stream_paused = paused_race
	engine_sound.stream_paused = paused_race
	skid_sound.stream_paused = paused_race
	for voice: AudioStreamPlayer in voices: voice.stream_paused = paused_race
	for car: CharacterBody3D in cars: car.set_paused(paused_race)

func cleanup() -> void:
	benchmark.candidate.clear()
	feedback.clear()
	results_input_guard = false
	if results_panel.has_node("Retry"):
		for title: String in ["Retry","CourseSelect","Menu"]: results_panel.get_node(title).disabled = false
	if victory_celebration!=null: victory_celebration.clear()
	if start_lights!=null: start_lights.hide()
	trial.reset()
	engine_layer.stop()
	engine_layer.stream_paused = false
	music.stream_paused = false
	if not is_menu_music(): music.stop()
	results_panel.visible = false
	wrong_way_time = 0.0
	if wrong_way_notice!=null: wrong_way_notice.hide()
	banner.add_theme_font_size_override("font_size",43)
	banner.position = Vector2(260,287)
	banner.size = Vector2(680,172)
	message = ""
	message_time = 0.0
	cue_duck = 0.0
	hud_tick = 0.0
	last_count = 3
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream_paused = false
	for sound: AudioStreamPlayer in [engine_sound,skid_sound]:
		sound.stop()
		sound.stream_paused = false
	if controller.device>=0: Input.stop_joy_vibration(controller.device)
func displayed_race_time() -> float:
	if race_mode=="time_attack": return session.time_attack.remaining(race_time)
	if race_mode=="drift": return maxf(0.0,drift.RULES.DURATION-drift.elapsed)
	return race_time+session.progress.records[player_car.player].penalty

func update_hud() -> void:
	if cars.is_empty(): return
	ARCADE.refresh_message(self)
	for path: String in ["Top","Status","Boost","StandingBack","Standings"]:
		get_node("HUD/"+path).visible = not menu.visible and phase!=6
	$HUD/Status.text = "LAP %d/%d  POS %d/%d" % [mini(player_car.laps+1,session.laps_required),session.laps_required,rank_of(player_car),cars.size()]
	if race_mode=="drift": $HUD/Status.text = "DRIFT %d/5 / TARGET %d" % [roadmap.run_stage+1,roadmap.drift_target()]
	var metrics: Label = get_node_or_null("HUD/RaceMetrics")
	if metrics!=null:
		metrics.visible = not menu.visible and phase!=6
		metrics.text = "%.2fs   BOOST %03d%%" % [displayed_race_time(),int(player_car.boost)]
	var context: Label = get_node_or_null("HUD/VehicleContext")
	if context!=null:
		context.visible = not menu.visible and phase in [2,5] and (experimental() or not start_lights.visible)
		context.text = ("FREESTYLE · " if race_mode=="freestyle" else "")+preload("res://scripts/vehicles/vehicle_catalog.gd").title(player_car.base_tuning.id)
		var surface: String = track.at(player_car.station).surface
		if race_mode=="freestyle":
			if surface=="water" and not player_car.tuning.watercraft: context.text += " · FLOAT ASSIST 55%"
			elif surface!="water" and player_car.tuning.watercraft: context.text += " · LAND ASSIST 50%"
		if benchmark.active(): context.text = "OWNER BENCHMARK / NEUTRAL BUILD / 3 LAPS"
		if race_mode=="challenge": context.text = challenge.hud_text()
		if race_mode=="drift": context.text = drift.hud_text()
		if race_mode=="time_attack": context.text = "TIME LEFT %.1fs / CHECKPOINT +%.1fs" % [session.time_attack.remaining(race_time),session.time_attack.extension]
		if race_mode in ["challenge","time_attack"]: context.text = "STAGE %d/5 / " % (roadmap.run_stage+1)+context.text
		if race_mode=="elimination": context.text = "NEXT CUT: LAP %d / %d CARS LEFT" % [session.elimination.next_lap,session.elimination.active_ids().size()]
		if experimental(): context.text = "EXPERIMENTAL · UNRANKED · "+context.text
		context.position.y = 100.0 if experimental() else 30.0
	$HUD/Boost.value = player_car.boost
	$HUD/Menu/Controller.text = "DETECTED · "+controller.controller_name if controller.device>=0 else "KEYBOARD READY · CONNECT A GAMEPAD"
	$HUD/Footer.text = "STICK STEER  RT GAS  LT/B BRAKE  A BOOST  START PAUSE  Y RETRY  SELECT MENU  P PIXELS" if controller.using_pad else "WASD/ARROWS DRIVE  SPACE BOOST  F RESET  R RETRY  ESC PAUSE  TAB MENU  M SOUND  P PIXELS"
	if phase==0:
		$HUD/Footer.text = "STICK / DPAD · HIGHLIGHT   A · SELECT   START · RACE" if controller.using_pad else "ARROWS · HIGHLIGHT   ENTER / SPACE · SELECT   ENTER · START RACE"
	$HUD/Standings.text = ""
	for rank: int in range(1,all_cars.size()+1):
		var row: Label = $HUD/Standings.get_node_or_null("DriverRow%d" % rank)
		if row==null:
			row = Label.new()
			row.name = "DriverRow%d" % rank
			row.position.y = (rank-1)*20
			row.size = Vector2(150,20)
			row.add_theme_font_size_override("font_size",12)
			$HUD/Standings.add_child(row)
		row.hide()
		for car: CharacterBody3D in cars:
			if rank_of(car)==rank:
				row.text = "%d  %s" % [rank,names[car.player-1]]
				row.add_theme_color_override("font_color",car.get_meta("vehicle_colour",Color.WHITE).lightened(0.4))
				row.show()
	$HUD/StandingBack.size.y = cars.size()*20+12
	$HUD/RaceMinimap.position.y = maxf(128.0,cars.size()*20.0+48.0)

func diagnostic_state() -> Dictionary:
	return {"fps":Engine.get_frames_per_second(),"phase":phase,"track_length":track.total_length,"device":controller.device,"player_laps":player_car.laps,"jumps":player_car.jumps,"impacts":player_car.impacts,"crashes":player_car.crashes,"results":session.results.duplicate(true)}
func synth(kind: String, frequency: float, duration: float, looped: bool=false) -> AudioStreamWAV:
	const RATE: int = 22050
	var count: int = int(RATE*duration)
	var data := PackedByteArray()
	data.resize(count*2)
	for i in range(count):
		var t: float = i/float(RATE)
		var p: float = i/float(count)
		var envelope: float = 1.0 if looped else minf(t*90.0,1.0)*pow(1.0-p,1.5)
		var wave: float = sin(TAU*frequency*t)
		var noise: float = sin(float(i)*127.1)*sin(float(i)*311.7)
		match kind:
			"engine": wave = sin(TAU*frequency*t)*0.5+(fposmod(t*frequency,1.0)*2.0-1.0)*0.3
			"skid": wave = noise*0.35+sin(TAU*1700.0*t)*0.12
			"crash","bump": wave = noise*exp(-p*4.0)+sin(TAU*frequency*t)*0.25
			"fall": wave = sin(TAU*(frequency*t-140.0*t*t))*0.7+noise*0.1
			"return": wave = sin(TAU*(frequency*t+260.0*t*t))*0.55
			"finish","lap": wave = (sin(TAU*frequency*t)+sin(TAU*frequency*1.25*t)+sin(TAU*frequency*1.5*t))*0.28
		data.encode_s16(i*2,int(clampf(wave*envelope*0.65,-1.0,1.0)*32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func setup_audio() -> void:
	sounds["menu"] = synth("tone",740,0.09)
	sounds["count"] = synth("tone",540,0.18)
	sounds["go"] = synth("tone",1080,0.48)
	sounds["bump"] = synth("bump",90,0.15)
	sounds["landing"] = synth("bump",55,0.23)
	sounds["crash"] = synth("crash",60,0.75)
	sounds["fall"] = synth("fall",410,0.85)
	sounds["return"] = synth("return",370,0.65)
	sounds["lap"] = synth("lap",620,0.48)
	sounds["finish"] = synth("finish",440,1.5)
	sounds["boost"] = synth("return",120,0.20)
	engine_sound.stream = synth("engine",80,0.5,true)
	engine_sound.volume_db = -24.0
	sounds["tyre_felt"] = synth("skid",1600,0.5,true)
	sounds["tyre_wood"] = synth("skid",850,0.5,true)
	sounds["tyre_paper"] = synth("skid",1200,0.5,true)
	skid_sound.stream = sounds["tyre_felt"]
	skid_sound.volume_db = -29.0
	engine_layer = AudioStreamPlayer.new()
	engine_layer.stream = synth("engine",160,0.5,true)
	engine_layer.volume_db = -36.0
	add_child(engine_layer)
	music = AudioStreamPlayer.new()
	music.stream = MENU_MUSIC
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.finished.connect(func() -> void:
		# The studio mix is used once. Later menu visits replay only the theme.
		if is_menu_music():
			music.stream = MENU_MUSIC
			music.play())
	# App starts the shared player once the opening is ready. Direct race scenes
	# still start their menu music here.
	if not get_parent().has_method("play_opening"): music.play()
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)

func play_sound(kind: String, gain_db: float = 0.0) -> void:
	if muted or voices.is_empty() or not sounds.has(kind): return
	var priority: int = 4 if kind in ["finish","lap","go","count"] else (2 if kind in ["crash","fall","return"] else 0)
	var voice: AudioStreamPlayer = null
	for candidate: AudioStreamPlayer in voices:
		if not candidate.playing:
			voice = candidate
			break
		if voice==null or int(candidate.get_meta("cue_priority",0))<int(voice.get_meta("cue_priority",0)): voice = candidate
	if voice.playing and int(voice.get_meta("cue_priority",0))>priority: return
	voice.set_meta("cue_priority",priority)
	voice.stream = sounds[kind]
	voice.volume_db = -15.0+clampf(gain_db,-24.0,0.0)
	voice.play()

func update_wrong_way(delta: float) -> void:
	var direction: Vector2 = track.direction(player_car.station)
	var travel: Vector2 = Vector2(player_car.velocity.x,player_car.velocity.z)
	var reversing: bool = phase==2 and not paused_race and player_car.state==0 and not player_car.airborne and player_car.finish_time<0.0 and travel.dot(direction)<-1.0
	wrong_way_time = minf(wrong_way_time+delta,1.0) if reversing else 0.0
	wrong_way_notice.visible = wrong_way_time>=0.6


func _unhandled_input(event: InputEvent) -> void:
	if profile_menu!=null and profile_menu.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_P:
		if setup_menu!=null: setup_menu.set_pixels(not $Retro.visible)

func return_to_2d() -> void:
	cleanup()
	if get_parent().has_method("open_2d"):
		get_parent().open_2d()
		return
	var error: Error = get_tree().change_scene_to_file("res://main.tscn")
	if error!=OK: fail_safe("Cannot open original game: "+str(error))

func cycle_camera() -> void:
	if phase not in [1,2,5] or paused_race: return
	camera_driver.cycle(camera,player_car)
	feedback.shake = 0.0
	feedback.shake_time = 0.0
	if controls_setup!=null and not profile.read_only: controls_setup.save_camera_mode()
	if phase in [2,5]:
		feedback.post("CAMERA · "+camera_driver.MODES[camera_driver.mode],1.5,1,&"camera")

func setup_difficulty() -> void:
	var choice: OptionButton = OptionButton.new()
	choice.name = "Difficulty"
	choice.position = Vector2(365,80)
	choice.size = Vector2(235,34)
	for label: String in ["Easy rivals","Normal rivals","Hard rivals","Nightmare · 2 attackers"]: choice.add_item(label)
	choice.select(difficulty)
	choice.item_selected.connect(func(index: int) -> void:
		difficulty = index
		if difficulty==3: rival_count = maxi(3,rival_count)
		save_preferences())
	$HUD/Menu.add_child(choice)

func focus_start() -> void:
	if profile_menu!=null and profile_menu.visible: return
	var button: Button = $HUD/Menu/Start
	button.disabled = course.loading or course.error!="" or not track.validation_errors.is_empty() or (race_mode=="tournament" and stats_test_mode!=0)
	if menu_flow!=null:
		menu_flow.focus()
		return
	if button.is_visible_in_tree() and button.get_focus_mode_with_override()!=Control.FOCUS_NONE:
		button.grab_focus()

func selected_race_music() -> AudioStream:
	var course_music: AudioStream = SOUNDTRACK.for_course(track_id)
	if course_music!=null: return course_music
	match difficulty:
		0: return EASY_MUSIC
		2: return hard_music if hard_music!=null else race_music
		3: return NIGHTMARE_MUSIC
	return race_music

func looped_music(source: AudioStream) -> AudioStream:
	if source==null: return null
	var stream: AudioStream = source.duplicate()
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	return stream

func setup_quick_race() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "QuickRace"
	row.position = Vector2(34,92)
	row.size = Vector2(570,34)
	row.add_theme_constant_override("separation",8)
	menu.add_child(row)
	var difficulty_choice: OptionButton = menu.get_node("Difficulty")
	difficulty_choice.reparent(row)
	difficulty_choice.custom_minimum_size = Vector2(184,34)
	var rivals: OptionButton = OptionButton.new()
	rivals.name = "Rivals"
	rivals.custom_minimum_size = Vector2(174,34)
	for count: int in range(8): rivals.add_item("%d rival%s%s" % [count,"s" if count!=1 else ""," · solo" if count==0 else ""])
	rivals.select(rival_count)
	rivals.item_selected.connect(func(index: int) -> void:
		rival_count = index
		save_preferences())
	row.add_child(rivals)
	var laps: OptionButton = OptionButton.new()
	laps.name = "Laps"
	laps.custom_minimum_size = Vector2(196,34)
	for count: int in range(1,10): laps.add_item("%d lap%s" % [count,"s" if count>1 else ""])
	laps.select(race_laps-1)
	laps.item_selected.connect(func(index: int) -> void:
		race_laps = index+1
		save_preferences())
	row.add_child(laps)
	var vehicle: OptionButton = OptionButton.new()
	vehicle.name = "VehicleClass"
	vehicle.position = Vector2(326,300)
	vehicle.size = Vector2(278,32)
	vehicle.add_item("CLASS · BUGGY")
	vehicle.tooltip_text = "More vehicle classes arrive in M6."
	menu.add_child(vehicle)
	var notice: Label = Label.new()
	notice.name = "SaveNotice"
	notice.position = Vector2(630,452)
	notice.size = Vector2(320,34)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size",16)
	notice.text = profile.status
	menu.add_child(notice)

func save_preferences() -> void:
	if profile.read_only and profile_selected: return
	machine_settings.save_settings()
	if not profile_selected: return
	profile.data.setup = machine_settings.data
	profile.data.mode = race_mode
	profile.data.quick_race = {"rivals":rival_count,"difficulty":difficulty,"laps":race_laps,"vehicle_id":player_car.base_tuning.id,"track_id":track_id,"driver":garage.selected}
	var error: Error = profile.save_profile()
	if error!=OK and not profile.read_only: profile.status = "Preferences could not be saved · "+error_string(error)
	var notice: Label = menu.get_node_or_null("SaveNotice")
	if notice!=null: notice.text = profile.status
	if menu.has_node("Mode"): refresh_mode()

func configure_quick_race() -> void:
	rival_count = clampi(rival_count,0,7 if race_mode in ["quick","freestyle"] else 3)
	race_laps = clampi(race_laps,1,9)
	difficulty = clampi(difficulty,0,3)
	if race_mode=="elimination": rival_count = maxi(1,rival_count)
	if difficulty==3 and race_mode in ["quick","freestyle"]: rival_count = maxi(3,rival_count)
	cars = all_cars.slice(0,1 if race_mode in ["trial","challenge","time_attack","drift"] or track_id=="practice_patch" else (4 if race_mode in ["cup","tournament"] else rival_count+1))
	session.configure(cars,track)
	session.mode = race_mode
	if race_mode=="time_attack" and course.entry!=null: session.time_attack_settings = preload("res://scripts/race/time_attack_rules.gd").settings(course.entry)
	if race_mode=="time_attack":
		session.time_attack_settings.start *= roadmap.factor()
		session.time_attack_settings.extension *= roadmap.factor()
	session.laps_required = CUP.LAPS[mini(profile.data.cup.get("rounds",[]).size(),2)] if race_mode=="cup" else (cars.size() if race_mode=="elimination" else (3 if race_mode in ["tournament","challenge","time_attack"] else race_laps))
	if race_mode=="drift": session.laps_required = 1
	if benchmark.active(): session.laps_required = benchmark.RULES.LAPS
	for car: CharacterBody3D in all_cars:
		var active: bool = car in cars
		car.visible = active
		car.set_physics_process(active)
		car.collision_layer = 2 if active else 0
		car.collision_mask = 3 if active else 0
		car.velocity = Vector3.ZERO
		for emitter: CPUParticles3D in [car.smoke,car.sparks,car.debris]: emitter.emitting = false
		car.ring.visible = false

func setup_modes() -> void:
	menu.get_node("Start").size.y = 44
	var mode: OptionButton = OptionButton.new()
	mode.name = "Mode"
	mode.position = Vector2(630,414)
	mode.size = Vector2(320,34)
	mode.add_item("QUICK RACE")
	mode.add_item("TIME TRIAL · SOLO + PB GHOST")
	mode.add_item("FREESTYLE · ANY VEHICLE / COURSE")
	mode.add_item("TOURNAMENT / SAVED SERIES")
	mode.add_item("CHALLENGE / COURSE ACHIEVEMENTS")
	mode.add_item("ELIMINATION / LAST CAR OUT")
	mode.add_item("TIME ATTACK / CHECKPOINT CLOCK")
	mode.add_item("DRIFT CHALLENGE / CONTROLLED SLIP")
	mode.select(["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"].find(race_mode))
	mode.item_selected.connect(func(index: int) -> void:
		if menu_flow!=null: menu_flow.choose_mode(["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"][index]))
	menu.add_child(mode)
	var record: Label = Label.new()
	record.name = "Record"
	record.position = Vector2(34,397)
	record.size = Vector2(570,27)
	record.add_theme_font_size_override("font_size",16)
	menu.add_child(record)
	refresh_mode()

func refresh_mode() -> void:
	menu.get_node("Mode").select(["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"].find(race_mode))
	menu.get_node("QuickRace/Rivals").select(3 if race_mode in ["cup","tournament"] else (0 if track_id=="practice_patch" or race_mode in ["trial","challenge","time_attack","drift"] else rival_count))
	menu.get_node("QuickRace/Difficulty").select(1 if race_mode=="cup" else clampi(difficulty,0,3))
	menu.get_node("QuickRace/Laps").select(session.laps_required-1 if race_mode=="cup" else clampi(race_laps-1,0,8))
	menu.get_node("QuickRace/Rivals").disabled = race_mode not in ["quick","freestyle","elimination"] or track_id=="practice_patch"
	for index: int in range(8):
		menu.get_node("QuickRace/Rivals").set_item_disabled(index,(race_mode=="elimination" and index>3) or (race_mode in ["quick","freestyle"] and difficulty==3 and index<3))
	menu.get_node("QuickRace/Difficulty").disabled = race_mode not in ["quick","freestyle","elimination"]
	menu.get_node("QuickRace/Rivals").set_item_disabled(0,race_mode=="elimination" or (race_mode in ["quick","freestyle"] and difficulty==3))
	if race_mode=="elimination": menu.get_node("QuickRace/Laps").select(maxi(1,rival_count))
	menu.get_node("QuickRace/Laps").disabled = race_mode in ["cup","tournament","challenge","elimination","drift"]
	menu.get_node("Record").text = cup_summary() if race_mode=="cup" else trial.summary()
	menu.get_node("Start").text = start_button_text()
	course.refresh()
	ARCADE.refresh(self)

func results_action() -> void:
	if race_mode=="tournament": tournament.results_action()
	else: start_race()

func start_button_text() -> String:
	if benchmark.active(): return "START OWNER RUN"
	if race_mode=="drift": return "START DRIFT CHALLENGE"
	if race_mode=="time_attack": return "START TIME ATTACK"
	if race_mode=="elimination": return "START ELIMINATION"
	if race_mode=="challenge": return "START CHALLENGE"
	if race_mode=="tournament": return "RESUME SERIES" if not profile.data.tournament.is_empty() and not tournament.RULES.complete(profile.data.tournament) else "START SERIES"
	if race_mode=="cup": return "RESUME CUP" if not profile.data.cup.is_empty() and profile.data.cup.rounds.size() in [1,2] else "START CUP"
	return "START TIME TRIAL" if race_mode=="trial" else "START RACE"

func cup_summary() -> String:
	var completed: int = profile.data.cup.get("rounds",[]).size()
	return "CASINO CUP · %d / 3 complete · 3 laps · Normal · %d trophies" % [completed,profile.data.cup_wins]

func score_cup(rows: Array) -> String:
	if not cup_round_scored and CUP.append_round(profile.data.cup,rows):
		cup_round_scored = true
		if profile.data.cup.rounds.size()==3 and CUP.standings(profile.data.cup)[0].player==1 and cup_player_finished():
			profile.data.cup_wins = mini(profile.data.cup_wins+1,999999)
		save_preferences()
	var totals: Array = CUP.standings(profile.data.cup)
	var text: String = "CUP %d / 3 · " % profile.data.cup.rounds.size()
	for row: Dictionary in totals: text += "%02d: %d pts  " % [row.player,row.points]
	if profile.data.cup.rounds.size()==3:
		text += "\n"+("CUP WON · GOLD LIVERY UNLOCKED" if totals[0].player==1 and cup_player_finished() else "CUP WINNER · "+names[totals[0].player-1])
	if profile.status!="": text += "\n"+profile.status
	return text

func cup_player_finished() -> bool:
	for rows: Array in profile.data.cup.rounds:
		for row: Dictionary in rows:
			if row.player==1 and not row.finished: return false
	return true
