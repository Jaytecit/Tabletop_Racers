extends Node2D
# 0 setup, 1 countdown, 2 racing, 3 results, 4 safe failure.
var phase: int = 0
var paused_race: bool = false
var opponents: int = 3
var race_time: float = 0.0
var countdown: float = 3.8
var last_count: int = 4
var winner: int = 0
var best_record: float = 0.0
var shake: float = 0.0
var muted: bool = false
var cars: Array = []
var finish_order: Array = []
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var hud_tick: float = 0.0
var message_time: float = 0.0
var message: String = ""
var action_latches: PackedByteArray = PackedByteArray([0,0,0,0])
var filtered_tracks: PackedInt32Array = PackedInt32Array()
var selected_track: int = 0
@onready var controller: Node = $Controller
@onready var catalog: Node = $TrackCatalog
@onready var particles: Node2D = $Particles
@onready var library: Control = $HUD/TrackLibrary
var names: PackedStringArray = PackedStringArray(["YOU","BLUE COMET","GOLD RUSH","GREEN MACHINE"])
@onready var track: Node2D = $Track
@onready var camera: Camera2D = $Camera
@onready var player_car: CharacterBody2D = $Car1
@onready var status: Label = $HUD/Status
@onready var details: Label = $HUD/Details
@onready var banner: Label = $HUD/Banner
@onready var standings: Label = $HUD/Standings
@onready var menu: Control = $HUD/Menu
@onready var results: Control = $HUD/Results
@onready var minimap: Node2D = $HUD/Minimap
@onready var engine_sound: AudioStreamPlayer = $Engine
@onready var skid_sound: AudioStreamPlayer = $Skid

func _ready() -> void:
	cars = [$Car1,$Car2,$Car3,$Car4]
	var config := ConfigFile.new()
	if config.load("user://room_records.cfg") == OK:
		best_record = float(config.get_value("record","best_lap",0.0))
	setup_audio()
	if catalog.entries.is_empty():
		fail_safe("No valid tracks in catalog")
		return
	filter_tracks("")
	choose_track(0)
	select_opponents(3)
	setup_grid()
	menu.visible = true
	library.visible = true
	results.visible = false
	banner.visible = false
	camera.position = player_car.position
	$HUD/Menu/Start.grab_focus()
	update_hud()

func setup_grid() -> void:
	$Skids.clear()
	particles.clear()
	$HUD/Confetti.clear()
	finish_order.clear()
	winner = 0
	race_time = 0.0
	for i in range(4):
		var car = cars[i]
		car.active = i<=opponents
		car.reset_car(25.0-float(int(i/2.0))*50.0,-22.0 if i%2==0 else 22.0)
		car.distance = -float(int(i/2.0))*50.0
	camera.position = player_car.position

func select_opponents(count: int) -> void:
	opponents = clampi(count,1,3)
	$HUD/Menu/Opponents.text = "%d AI OPPONENT%s" % [opponents,"" if opponents==1 else "S"]
	for i in range(1,4):
		var button: Button = get_node("HUD/Menu/AI%d" % i)
		button.button_pressed = opponents==i
	if not cars.is_empty() and phase==0:
		setup_grid()
		update_hud()

func _one() -> void: select_opponents(1)
func _two() -> void: select_opponents(2)
func _three() -> void: select_opponents(3)
func start_race() -> void:
	paused_race = false
	setup_grid()
	phase = 1
	countdown = 3.8
	last_count = 3
	menu.visible = false
	library.visible = false
	results.visible = false
	banner.visible = true
	banner.text = "3"
	play_sound("count")
func restart_race() -> void: start_race()
func show_menu() -> void:
	library.visible = true
	phase = 0
	paused_race = false
	setup_grid()
	menu.visible = true
	results.visible = false
	banner.visible = false
	engine_sound.stop()
	skid_sound.stop()
	$HUD/Menu/Start.grab_focus()
	update_hud()

func fail_safe(reason: String) -> void:
	if phase==4: return
	phase = 4
	push_error(reason)
	for car in cars: car.frozen = true
	engine_sound.stop()
	skid_sound.stop()
	banner.visible = true
	banner.text = "RACE PAUSED\n"+reason

func tapped(action: String, index: int) -> bool:
	var pressed: bool = Input.is_action_pressed(action)
	var fresh: bool = pressed and action_latches[index]==0
	action_latches[index] = 1 if pressed else 0
	return fresh

func _physics_process(delta: float) -> void:
	if phase==0 and $HUD/TrackLibrary/Search.has_focus():
		action_latches.fill(0)
		return
	if tapped("restart",0): start_race()
	if tapped("pause_race",1) and (phase==1 or phase==2): toggle_pause()
	if tapped("menu",2): show_menu()
	if tapped("mute",3):
		muted = not muted
		engine_sound.volume_db = -80.0 if muted else -24.0
		skid_sound.volume_db = -80.0 if muted else -29.0
	if Input.is_action_pressed("start_race") and phase==0 and not $HUD/TrackLibrary/Search.has_focus(): start_race()
	if phase==4: return
	if paused_race:
		engine_sound.stream_paused = true
		skid_sound.stream_paused = true
		return
	if engine_sound.stream_paused: engine_sound.stream_paused = false
	if skid_sound.stream_paused: skid_sound.stream_paused = false
	if phase==1:
		countdown -= delta
		var count: int = int(ceil(maxf(countdown-0.8,0.0)))
		if count!=last_count and count>0:
			last_count = count
			banner.text = str(count)
			play_sound("count")
		if countdown<=0.8:
			phase = 2
			banner.text = "GO!"
			message_time = 0.8
			message = "GO!"
			play_sound("go")
			engine_sound.play()
	if phase==2:
		race_time += delta
		if not engine_sound.playing: engine_sound.play()
		message_time = maxf(0.0,message_time-delta)
		if player_car.state!=0:
			banner.visible = true
			banner.text = "RECOVERING…"
		elif player_car.wrong_way>0.8:
			banner.visible = true
			banner.text = "WRONG WAY"
		else:
			banner.visible = message_time>0.0
			banner.text = message
		engine_sound.pitch_scale = 0.7+player_car.velocity.length()/230.0
		var lateral: float = absf(player_car.velocity.dot(Vector2.RIGHT.rotated(player_car.rotation).orthogonal()))
		if lateral>65.0 and player_car.state==0 and not skid_sound.playing:
			skid_sound.play()
		elif lateral<45.0 or player_car.state!=0:
			skid_sound.stop()
		var target: Vector2 = player_car.position
		if player_car.state==3: target = player_car.safe_position
		camera.position = camera.position.lerp(target,1.0-exp(-8.0*delta))
		shake = maxf(0.0,shake-delta*20.0)
		camera.offset = Vector2(sin(race_time*78),cos(race_time*91))*shake
	hud_tick += delta
	if hud_tick>0.10:
		hud_tick = 0.0
		update_hud()
		minimap.queue_redraw()

func update_progress(car: CharacterBody2D) -> void:
	if phase!=2 or car.finish_time>=0.0: return
	var length: float = track.total_length
	var lap_progress: float = car.distance-float(car.laps)*length
	if car.progress_gate<8 and lap_progress>=length*float(car.progress_gate)/8.0:
		car.progress_gate += 1
	if lap_progress>=length and car.progress_gate==8:
		car.laps += 1
		car.progress_gate = 1
		car.last_lap = race_time-car.lap_started
		car.lap_started = race_time
		if car.best_lap<=0.0 or car.last_lap<car.best_lap: car.best_lap = car.last_lap
		if not car.ai:
			if best_record<=0.0 or car.last_lap<best_record:
				best_record = car.last_lap
				var config := ConfigFile.new()
				config.load("user://room_records.cfg")
				config.set_value(track.track_id,"best_lap",best_record)
				var error: Error = config.save("user://room_records.cfg")
				if error!=OK: print("Lap record could not be saved: ",error)
			message = "FINAL LAP!" if car.laps==track.lap_target-1 else "LAP %d / %d" % [car.laps+1,track.lap_target]
			message_time = 1.6
			play_sound("lap")
			particles.burst(car.position,car.rotation,3,24)
			controller.rumble(0.2,0.15)
		if car.laps>=track.lap_target:
			car.finish_time = race_time
			finish_order.append(car.player)
			if winner==0: winner = car.player
			if not car.ai: finish_race()

func rank_of(car: CharacterBody2D) -> int:
	var rank: int = 1
	for other in cars:
		if other==car or not other.active: continue
		if other.finish_time>=0.0:
			if car.finish_time<0.0 or other.finish_time<car.finish_time: rank += 1
		elif car.finish_time<0.0 and (other.distance>car.distance or (is_equal_approx(other.distance,car.distance) and other.player<car.player)):
			rank += 1
	return rank

func finish_race() -> void:
	phase = 3
	for car in cars: car.frozen = true
	engine_sound.stop()
	skid_sound.stop()
	banner.visible = false
	results.visible = true
	var position_rank: int = rank_of(player_car)
	$HUD/Results/Title.text = "VICTORY!" if position_rank==1 else "FINISHED · %d%s" % [position_rank,"ND" if position_rank==2 else ("RD" if position_rank==3 else "TH")]
	$HUD/Results/Summary.text = "TIME  %.2fs     BEST LAP  %.2fs\n%d CRASHES     %d AI OPPONENTS" % [race_time,player_car.best_lap,player_car.crashes,opponents]
	play_sound("finish")
	$HUD/Confetti.burst(Vector2(600,245),0.0,4,140)
	controller.rumble(0.35,0.5)
	$HUD/Results/Again.grab_focus()
	update_hud()

func update_hud() -> void:
	if cars.is_empty(): return
	status.text = "LAP %d / %d     POS %d / %d" % [mini(player_car.laps+1,track.lap_target),track.lap_target,rank_of(player_car),opponents+1]
	details.text = "%03d km/h    BOOST %03d%%\nTIME %.2fs    BEST %s" % [int(player_car.velocity.length()*0.32),int(player_car.boost),race_time,"—" if best_record<=0.0 else "%.2fs" % best_record]
	var listing: String = ""
	for rank in range(1,opponents+2):
		for car in cars:
			if car.active and rank_of(car)==rank:
				listing += "%d  %s   %s\n" % [rank,names[car.player-1],"FIN" if car.finish_time>=0.0 else "L%d" % mini(car.laps+1,track.lap_target)]
	standings.text = listing
	$HUD/Boost.value = player_car.boost
	$HUD/Footer.text = ("STICK / D-PAD · STEER    RT · GAS    LT / B · BRAKE    A · BOOST    START · PAUSE    Y · RESTART    SELECT · MENU" if controller.using_pad else "WASD / ARROWS · DRIVE     SPACE · BOOST     ESC · PAUSE     R · RESTART     TAB · MENU     M · SOUND")
	$HUD/Menu/ControllerStatus.text = "CONTROLLER: "+controller.controller_name if controller.device>=0 else "KEYBOARD READY · CONNECT A GAMEPAD ANYTIME"
	$HUD/Menu/Help.text = "STICK / D-PAD · STEER   RT / RB · GAS   LT / B · BRAKE\nA · BOOST   START · RACE / PAUSE   Y · RESTART   SELECT · MENU" if controller.device>=0 else "WASD / ARROWS · DRIVE   SPACE · BOOST\nESC · PAUSE   R · RESTART   TAB · MENU   M · SOUND"
	$HUD/MapTitle.text = track.track_title.to_upper()
	$HUD/Title.text = "MINIATURE GRAND PRIX · "+track.track_title.to_upper()
	$HUD/Menu/Subtitle.text = track.track_title+" · "+str(track.lap_target)+" laps · miniature mayhem"
	$HUD/SoundStatus.text = "SOUND "+("OFF" if muted else "ON")

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
	sounds["count"] = synth("tone",540,0.18)
	sounds["go"] = synth("tone",1080,0.48)
	sounds["bump"] = synth("bump",90,0.15)
	sounds["crash"] = synth("crash",60,0.75)
	sounds["fall"] = synth("fall",410,0.85)
	sounds["return"] = synth("return",370,0.65)
	sounds["lap"] = synth("lap",620,0.48)
	sounds["finish"] = synth("finish",440,1.5)
	sounds["boost"] = synth("return",120,0.20)
	engine_sound.stream = synth("engine",80,0.5,true)
	engine_sound.volume_db = -24.0
	skid_sound.stream = synth("skid",1600,0.5,true)
	skid_sound.volume_db = -29.0
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		voices.append(voice)

func play_sound(kind: String) -> void:
	if muted or voices.is_empty() or not sounds.has(kind): return
	var voice: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index+1)%voices.size()
	voice.stream = sounds[kind]
	voice.play()

func diagnostic_state() -> Dictionary:
	return {"fps":Engine.get_frames_per_second(),"engine_playing":engine_sound.playing,"engine_loop_mode":engine_sound.stream.loop_mode,"engine_loop_end":engine_sound.stream.loop_end,"sound_count":sounds.size(),"sound_rate":engine_sound.stream.mix_rate,"phase":phase,"opponents":opponents}

func toggle_pause() -> void:
	if phase!=1 and phase!=2: return
	paused_race = not paused_race
	banner.visible = paused_race
	banner.text = "PAUSED\nSTART / ESC · RESUME"

func filter_tracks(query: String) -> void:
	var list: ItemList = $HUD/TrackLibrary/List
	list.clear()
	filtered_tracks.clear()
	var search: String = query.strip_edges().to_lower()
	for i in range(catalog.entries.size()):
		var entry: Dictionary = catalog.entries[i]
		if search.is_empty() or (str(entry.title)+" "+str(entry.get("description",""))).to_lower().contains(search):
			filtered_tracks.append(i)
			list.add_item(str(entry.title))
			if i==selected_track: list.select(list.item_count-1)
	$HUD/TrackLibrary/Count.text = "%d / %d CIRCUITS" % [filtered_tracks.size(),catalog.entries.size()]

func select_track_item(index: int) -> void:
	if index>=0 and index<filtered_tracks.size(): choose_track(filtered_tracks[index])

func choose_track(index: int) -> void:
	if phase!=0: return
	var definition: Dictionary = catalog.definition(index)
	if definition.is_empty():
		fail_safe(catalog.error_message)
		return
	selected_track = index
	track.apply_definition(definition)
	catalog.current_id = track.track_id
	var config := ConfigFile.new()
	best_record = 0.0
	if config.load("user://room_records.cfg")==OK:
		best_record = float(config.get_value(track.track_id,"best_lap",config.get_value("record","best_lap",0.0) if track.track_id=="room-run" else 0.0))
	$HUD/TrackLibrary/Description.text = "%s\n\n%.1f m · %d laps\n%s" % [definition.description,track.total_length/100.0,track.lap_target,"Raised table section" if track.raised else "Floor-level circuit"]
	minimap.rebuild()
	if not cars.is_empty(): setup_grid()
	update_hud()

func catalog_state() -> Dictionary:
	return {"tracks":catalog.entries.size(),"selected":track.track_id,"title":track.track_title,"length":track.total_length,"width":track.half_width,"laps":track.lap_target,"filtered":filtered_tracks.size(),"record":best_record}

func open_showcase() -> void:
	var error: Error = get_tree().change_scene_to_file("res://showcase_3d.tscn")
	if error!=OK: fail_safe("Cannot open 3D showcase: "+str(error))
