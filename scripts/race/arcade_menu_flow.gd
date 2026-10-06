extends RefCounted
# Stage presentation reuses the existing selectors and their save signals.
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const BRAND: Script = preload("res://scripts/race/game_brand.gd")
const VEHICLES: Array[String] = ["BEACH BUGGY","MONSTER TRUCK","RACING CAR","DRIFT CAR","SPEEDBOAT"]
const ART_IDS: Array[String] = ["buggy","monster_truck","racing_car","drift_car","speedboat"]
const DESCRIPTIONS: Array[String] = ["CHUNKY TYRES. OPEN COCKPIT. READY TO RACE.","BIG WHEELS. BIG PLANS.","LOW, FAST AND BUILT FOR THE ROAD.","WIDE STANCE. SIDEWAYS STYLE.","SMALL BOAT. BIG WAKE."]
const TITLES: Array[String] = ["PLEASE SELECT OPTION","PLAYER STATS","EXPLORE THE GARAGE","SELECT YOUR COURSE"]
const MODE_DESCRIPTIONS: Dictionary = {
	"quick": "RACE TO THE FINISH AGAINST UP TO SEVEN AI RIVALS.",
	"trial": "RACE SOLO AGAINST THE CLOCK AND YOUR PERSONAL BEST GHOST.",
	"freestyle": "CHOOSE ANY VEHICLE AND EXPLORE THE COURSE FREELY.",
	"tournament": "RACE A SERIES OF COURSES AND EARN POINTS TO WIN THE TROPHY.",
	"challenge": "COMPLETE SOLO RUNS, FINISH CLEANLY AND BEAT TARGET TIMES.",
	"elimination": "THE LAST CAR IS ELIMINATED EACH LAP AFTER LAP ONE.\nBE THE FINAL SURVIVOR TO WIN.",
	"time_attack": "FINISH BEFORE TIME RUNS OUT.\nPASS CHECKPOINTS TO EXTEND THE COUNTDOWN.",
	"drift": "CHAIN DRIFTS AND BANK COMBOS TO SCORE POINTS IN 90 SECONDS."
}
var race: Node3D
var step: int = 0
var vehicle: int = 0
var artwork: Array[Texture2D] = []
var home: Control
var heading: Label
var mode_hint: Label
var vehicle_art: TextureRect
var vehicle_rotation: Node
var vehicle_name: Label
var vehicle_description: Label
var vehicle_status: Label
var colour_choice: OptionButton
var previous_vehicle: Button
var next_vehicle: Button
var back: Button
var next: Button
var selected_driver: Label
var driver_stats: Control
var curtain: TextureRect
var option_frame: Control
var preview_frame: Control
var quit_button: Button
var eight_car_button: Button
var quit_dialog: ConfirmationDialog

func triple_frame(parent: Control, title: String) -> Control:
	var frame: Control = Control.new()
	frame.name = title
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	for index: int in range(3):
		var ring: Panel = Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var inset: float = index*2.0
		ring.offset_left = inset
		ring.offset_top = inset
		ring.offset_right = -inset
		ring.offset_bottom = -inset
		ring.add_theme_stylebox_override("panel",SKIN.box(Color.TRANSPARENT,[SKIN.GOLD,SKIN.INK,Color("6b3291")][index],1))
		frame.add_child(ring)
	return frame

func button(parent: Control, title: String, text: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var node: Button = Button.new()
	node.name = title
	node.text = text
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",24)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func setup(owner: Node3D) -> void:
	race = owner
	for id: String in ART_IDS: artwork.append(load("res://assets/vehicles/menu/"+id+".png"))
	var menu: Control = race.menu
	curtain = TextureRect.new()
	curtain.name = "MenuCurtain"
	curtain.texture = BRAND.tabletop_background()
	curtain.size = Vector2(1200,800)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race.get_node("HUD").add_child(curtain)
	curtain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	curtain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	curtain.modulate = Color(0.80,0.80,0.90)
	race.get_node("HUD").move_child(curtain,0)
	menu.get_node("Title").text = BRAND.NAME
	menu.get_node("Title").hide()
	SKIN.image_rect(menu,"BrandLogo",BRAND.logo_texture(),Vector2(326,24),Vector2(500,134)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tagline: Label = SKIN.label(menu,"BrandTagline",BRAND.TAGLINE,Vector2(76,164),Vector2(1000,24),14,SKIN.PAPER)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var background: TextureRect = menu.get_node("ArcadeBackdrop")
	background.texture = BRAND.tabletop_background()
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(1,1,1,0.24)
	background.position = Vector2(14,14)
	background.size = Vector2(1124,692)
	var frame: StyleBoxFlat = SKIN.box(SKIN.INK,SKIN.BLUE,4)
	frame.set_corner_radius_all(24)
	menu.add_theme_stylebox_override("panel",frame)
	heading = SKIN.label(menu,"FlowHeading",TITLES[0],Vector2(28,198),Vector2(1096,36),24,SKIN.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	option_frame = triple_frame(menu,"OptionTripleBorder")
	# Centre the entire group between the heading's bottom and the footer.
	option_frame.position = Vector2(60,280)
	option_frame.size = Vector2(1030,332)
	home = Control.new()
	home.name = "ModePage"
	menu.add_child(home)
	home.position = Vector2(76,296)
	home.size = Vector2(540,282)
	mode_hint = SKIN.label(home,"ModeHint",MODE_DESCRIPTIONS["quick"],Vector2(0,248),Vector2(560,48),12)
	mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var modes: Array[String] = ["quick","trial","freestyle","tournament","challenge","elimination","time_attack","drift"]
	var titles: Array[String] = ["QUICK RACE","TIME TRIAL","FREESTYLE","TOURNAMENT","CHALLENGES","ELIMINATION","TIME ATTACK","DRIFT CHALLENGE"]
	var nodes: Array[String] = ["Quick","Trial","Freestyle","Tournament","Challenge","Elimination","TimeAttack","Drift"]
	for index: int in range(modes.size()):
		var choice: Button = button(home,nodes[index],titles[index],Vector2((index%2)*276,int(index/2.0)*58),Vector2(260,44),choose_mode.bind(modes[index]))
		choice.add_theme_font_size_override("font_size",18)
		choice.mouse_entered.connect(choice.grab_focus)
		choice.focus_entered.connect(func() -> void:
			mode_hint.text = MODE_DESCRIPTIONS[modes[index]]
			choice.add_theme_stylebox_override("normal",SKIN.box(SKIN.GOLD,SKIN.PINK,3))
			choice.add_theme_color_override("font_color",SKIN.INK)
			choice.add_theme_color_override("font_hover_color",SKIN.INK)
			choice.add_theme_color_override("font_focus_color",SKIN.INK)
			choice.add_theme_stylebox_override("hover",SKIN.box(SKIN.GOLD,SKIN.PINK,3)))
		choice.focus_exited.connect(func() -> void:
			choice.remove_theme_stylebox_override("normal")
			choice.remove_theme_stylebox_override("hover")
			choice.remove_theme_color_override("font_color")
			choice.remove_theme_color_override("font_hover_color"))
	preview_frame = triple_frame(menu,"VehiclePreviewTripleBorder")
	vehicle_art = SKIN.image_rect(menu,"VehicleArtwork",artwork[0],Vector2(342,144),Vector2(468,330))
	vehicle_rotation = preload("res://scripts/race/menu_vehicle_rotation.gd").new()
	vehicle_rotation.name = "VehicleRotation"
	vehicle_rotation.setup(vehicle_art,artwork)
	menu.add_child(vehicle_rotation)
	vehicle_name = SKIN.label(menu,"VehicleName",VEHICLES[0],Vector2(140,468),Vector2(872,40),28,SKIN.GOLD)
	vehicle_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_description = SKIN.label(menu,"VehicleDescription","",Vector2(90,542),Vector2(972,24),16)
	vehicle_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vehicle_status = SKIN.label(menu,"VehicleStatus","",Vector2(90,574),Vector2(972,24),14,SKIN.GOLD)
	vehicle_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colour_choice = OptionButton.new()
	colour_choice.name = "CharacterColour"
	colour_choice.position = Vector2(300,610)
	colour_choice.size = Vector2(552,34)
	colour_choice.add_theme_font_size_override("font_size",14)
	colour_choice.add_item("PROFILE / EQUIPPED PAINT")
	var characters: Script = preload("res://scripts/profiles/character_catalog.gd")
	for i: int in range(characters.NAMES.size()):
		colour_choice.add_item((characters.NAMES[i]+" / "+characters.COLOUR_NAMES[i]).to_upper())
	menu.add_child(colour_choice)
	colour_choice.item_selected.connect(func(index: int) -> void:
		race.profile.data.character_colour_id = index-1
		race.garage.select(race,race.garage.selected)
		race.save_preferences())
	previous_vehicle = button(menu,"PreviousVehicle","",Vector2(108,278),Vector2(86,72),func() -> void: browse(-1))
	next_vehicle = button(menu,"NextVehicle","",Vector2(958,278),Vector2(86,72),func() -> void: browse(1))
	previous_vehicle.icon = load("res://assets/arcade/arrow_left.svg")
	next_vehicle.icon = load("res://assets/arcade/arrow_right.svg")
	back = button(menu,"FlowBack","BACK",Vector2(28,658),Vector2(180,38),go_back)
	next = button(menu,"FlowNext","NEXT",Vector2(916,658),Vector2(208,38),advance)
	race.controls_setup.launch.position = Vector2(236,658)
	race.controls_setup.launch.size = Vector2(180,38)
	SKIN.place(menu,"Start",Vector2(624,648),Vector2(474,48),22)
	SKIN.place(menu,"SaveNotice",Vector2(28,702),Vector2(660,18),10)
	SKIN.place(menu,"AssetCredits",Vector2(28,28),Vector2(140,28),10)
	for state: String in ["normal","hover","pressed"]:
		menu.get_node("AssetCredits").add_theme_stylebox_override(state,SKIN.box(Color(0.02,0.03,0.09,0.5),Color(1,1,1,0.3),1))
	var copyright: Label = SKIN.label(menu,"Copyright","(C) JAYLABS 2026  /  v"+BRAND.VERSION,Vector2(710,702),Vector2(414,18),10,SKIN.PAPER)
	copyright.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.name = "QuitConfirmation"
	quit_dialog.title = "Quit game?"
	quit_dialog.dialog_text = "Quit (not) THE REAL THING?"
	quit_dialog.ok_button_text = "QUIT"
	quit_dialog.theme = menu.theme
	race.add_child(quit_dialog)
	quit_dialog.confirmed.connect(func() -> void: race.get_tree().quit())
	quit_dialog.canceled.connect(func() -> void: quit_button.grab_focus())
	quit_button = button(menu,"Quit","QUIT",Vector2(948,658),Vector2(176,38),func() -> void: quit_dialog.popup_centered())
	quit_button.add_theme_font_size_override("font_size",18)
	eight_car_button = button(menu,"EightCarRace","8 CAR RACE / MOONLIGHT",Vector2(448,658),Vector2(472,38),setup_eight_car_race)
	eight_car_button.add_theme_font_size_override("font_size",16)
	var grid: HBoxContainer = menu.get_node("DriverCards")
	grid.position = Vector2(52,246)
	grid.size = Vector2(1048,246)
	grid.add_theme_constant_override("separation",16)
	for card: Button in race.garage.cards:
		card.custom_minimum_size = Vector2(250,246)
		card.get_node("Portrait").position = Vector2(35,12)
		card.get_node("Portrait").size = Vector2(180,180)
		card.get_node("DriverCaption").position = Vector2(8,200)
		card.get_node("DriverCaption").size = Vector2(234,46)
	selected_driver = SKIN.label(menu,"SelectedDriver","",Vector2(52,508),Vector2(1048,30),20,SKIN.GOLD)
	selected_driver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	driver_stats = preload("res://scripts/profiles/driver_stats_page.gd").new()
	menu.add_child(driver_stats)
	driver_stats.setup(race)
	SKIN.place(menu,"Diorama",Vector2(624,246),Vector2(474,210))
	SKIN.place(menu,"CourseMap",Vector2(1004,376),Vector2(82,68))
	SKIN.place(menu,"TrackSelect",Vector2(624,484),Vector2(474,40),16)
	SKIN.place(menu,"CourseInfo",Vector2(624,536),Vector2(474,74),12)
	SKIN.place(menu,"QuickRace",Vector2(50,484),Vector2(530,40))
	menu.get_node("QuickRace/Difficulty").custom_minimum_size = Vector2(180,40)
	menu.get_node("QuickRace/Rivals").custom_minimum_size = Vector2(174,40)
	menu.get_node("QuickRace/Laps").custom_minimum_size = Vector2(160,40)
	for index: int in range(4): menu.get_node("QuickRace/Difficulty").set_item_text(index,["EASY","NORMAL","HARD","NIGHTMARE"][index])
	menu.get_node("QuickRace/Rivals").set_item_text(0,"SOLO")
	SKIN.place(menu,"Record",Vector2(50,536),Vector2(530,46),14)
	menu.get_node("Record").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	show_step(0)
	var navigation: Node = preload("res://scripts/race/menu_navigation.gd").new()
	navigation.name = "MenuNavigation"
	navigation.race = race
	race.add_child(navigation)

func choose_mode(mode: String) -> void:
	if not race.profile_selected: return
	race.course.cancel_selection()
	race.race_mode = mode
	if mode=="tournament": race.tournament.enter()
	if mode=="elimination": race.rival_count = maxi(1,race.rival_count)
	if mode=="drift" and race.track_id not in preload("res://scripts/tracks/content_catalog.gd").DRIFT_COURSES: race.course.request_select(preload("res://scripts/tracks/content_catalog.gd").DRIFT_COURSES[0])
	race.set_vehicle(race.profile.data.freestyle_vehicle if mode=="freestyle" else preload("res://scripts/tracks/content_catalog.gd").mode_vehicle(race.track_id,race.race_mode))
	race.save_preferences()
	show_step(1)

func setup_eight_car_race() -> void:
	if not race.profile_selected: return
	race.course.cancel_selection()
	race.race_mode = "quick"
	race.difficulty = 2
	race.rival_count = 7
	race.race_laps = 3
	race.course.request_select("moonlight_junk_heap")
	show_step(3)

func browse(direction: int) -> void:
	if race.race_mode!="freestyle": return
	vehicle = posmod(vehicle+direction,VEHICLES.size())
	race.set_vehicle(ART_IDS[vehicle])
	race.play_sound("menu")
	race.save_preferences()
	refresh()

func go_back() -> void:
	race.course.cancel_selection()
	race.course.refresh()
	show_step(1 if step==3 and race.race_mode!="freestyle" else maxi(step-1,0))

func advance() -> void:
	if step==0:
		var focused: Control = race.get_viewport().gui_get_focus_owner()
		if focused is Button and focused.get_parent()==home: focused.pressed.emit()
	elif step<3: show_step(step+1)
	else: race.start_race()

func show_step(value: int) -> void:
	step = clampi(value,0,3)
	if step==2 and race.race_mode!="freestyle": step = 3
	if step==3 and race.race_mode!="freestyle": race.set_vehicle(preload("res://scripts/tracks/content_catalog.gd").mode_vehicle(race.track_id,race.race_mode))
	refresh()
	focus.call_deferred()

func reset_vehicle() -> void:
	vehicle = ART_IDS.find(race.player_car.base_tuning.id)
	refresh()

func refresh() -> void:
	if race==null or heading==null: return
	var menu: Control = race.menu
	curtain.visible = menu.visible
	for path: String in ["Title","Subtitle","Description","Difficulty","DriverHeading","RaceHeading","CourseHeading","DriverProfile","Mode","VehicleClass","Controller","Back","CourseIllustration"]:
		var node: Control = menu.get_node_or_null(path)
		if node!=null: node.hide()
	menu.get_node("DriverCards").hide()
	driver_stats.visible = step==1
	colour_choice.visible = step in [1,2]
	colour_choice.position.y = 622 if step==1 else 610
	colour_choice.select(int(race.profile.data.get("character_colour_id",-1))+1)
	if step==1: driver_stats.refresh()
	race.controls_setup.launch.visible = step==0
	for path: String in ["Diorama","CourseMap","TrackSelect","CourseInfo","QuickRace","Record","Start"]: menu.get_node(path).visible = step==3
	home.visible = step==0
	option_frame.visible = step==0
	preview_frame.visible = step in [0,2,3]
	var change: Control = menu.get_node_or_null("ChangeProfile")
	if change!=null: change.visible = step==0
	if race.stats_menu!=null: race.stats_menu.launch.visible = step in [1,2]
	selected_driver.hide()
	selected_driver.text = race.garage.DRIVERS[race.garage.selected].split(" · ")[1]+"  /  "+race.garage.MOTTO[race.garage.selected].to_upper()
	heading.text = TITLES[step]
	for node: Control in [vehicle_art,vehicle_name,vehicle_description,vehicle_status]: node.visible = step in [2,3]
	vehicle_art.visible = step in [0,2,3]
	for node: Control in [previous_vehicle,next_vehicle]: node.visible = step==2 and race.race_mode=="freestyle"
	back.visible = step>0
	next.visible = step in [1,2]
	vehicle = ART_IDS.find(race.player_car.base_tuning.id)
	vehicle_rotation.set_active(step==0)
	vehicle_art.texture = artwork[vehicle_rotation.index if step==0 else vehicle]
	vehicle_name.text = VEHICLES[vehicle]
	vehicle_description.text = DESCRIPTIONS[vehicle]
	var tuning: Resource = race.player_car.tuning
	vehicle_status.text = "GRIP %.2f / SPEED %.2f / BOOST %.2fs / RETURN %.2fs" % [tuning.grip,tuning.top_speed,100.0/maxf(tuning.boost_drain,0.001),1.55/tuning.recovery_speed]
	if tuning.boost_drain==0.0: vehicle_status.text += " / UNLIMITED BOOST"
	if race.experimental(): vehicle_status.text += " / EXPERIMENTAL · UNRANKED"
	if race.race_mode!="freestyle": vehicle_description.text = "STANDARD CLASS IS ASSIGNED BY THE SELECTED COURSE."
	elif vehicle==4: vehicle_description.text = "WATER PROPULSION / LAND SKID ASSIST AT 50% SPEED."
	else: vehicle_description.text = DESCRIPTIONS[vehicle]+" / WATER FLOAT ASSIST AT 55%."
	if step==3:
		vehicle_art.position = Vector2(52,246)
		vehicle_art.size = Vector2(528,192)
		vehicle_name.position = Vector2(52,450)
		vehicle_name.size = Vector2(528,30)
		vehicle_name.add_theme_font_size_override("font_size",22)
		vehicle_description.hide()
		vehicle_status.hide()
		menu.get_node("CourseInfo").set_deferred("size",Vector2(474,74))
	else:
		vehicle_art.position = Vector2(342,236)
		vehicle_art.size = Vector2(468,260)
		vehicle_name.position = Vector2(140,500)
		vehicle_name.size = Vector2(872,40)
		vehicle_name.add_theme_font_size_override("font_size",28)
	if step==0:
		vehicle_art.position = Vector2(684,296)
		vehicle_art.size = Vector2(390,300)
	preview_frame.position = vehicle_art.position-Vector2(10,10)
	preview_frame.size = vehicle_art.size+Vector2(20,12 if step in [2,3] else 20)
	menu.get_node("AssetCredits").visible = step==0
	quit_button.visible = step==0
	eight_car_button.visible = step==0
	if step==3 and race.race_mode=="elimination": menu.get_node("Record").text = "LAST CAR OUT AT LEADER LAP 2, THEN EACH LAP.\nLAST SURVIVOR WINS / TIES USE RACE ORDER.\n"+race.trial.summary()
	if step==3 and race.race_mode=="time_attack":
		var clock: Dictionary = preload("res://scripts/race/time_attack_rules.gd").settings(race.course.entry)
		menu.get_node("Record").text = "START %.1fs / ORDERED GATE +%.1fs\nFINISH BEFORE THE CLOCK REACHES ZERO" % [clock.start,clock.extension]
	if step==3 and race.race_mode=="drift":
		menu.get_node("QuickRace").hide()
		menu.get_node("Record").text = race.drift.summary()
	if step==3 and race.race_mode in ["quick","freestyle"]:
		menu.get_node("Record").text = race.trial.summary()+"\nAI PROVISIONAL / OWNER CALIBRATION PENDING"
	race.tournament.refresh()
	race.benchmark.refresh()
	if race.benchmark.toggle!=null:
		# Keep the trial-only toggle in the left column, above the footer row.
		race.benchmark.toggle.position = Vector2(52,596)
		race.benchmark.toggle.size = Vector2(528,38)
	if race.stats_menu!=null:
		race.stats_menu.launch.disabled = race.benchmark.active()
		race.stats_menu.launch.tooltip_text = "Neutral stats are locked for owner benchmarks. Toggle this on the course page." if race.benchmark.active() else "Earn and spend vehicle upgrades"
	if step==3 and race.race_mode=="challenge":
		menu.get_node("QuickRace").hide()
		menu.get_node("Record").text = race.challenge.summary()
	race.roadmap.refresh()

func focus() -> void:
	if (race.profile_menu!=null and race.profile_menu.visible) or (race.stats_menu!=null and race.stats_menu.panel.visible) or not race.menu.visible or race.setup_menu.panel.visible or race.controls_setup.panel.visible: return
	if step==0: home.get_node("Quick").grab_focus()
	elif step==1: next.grab_focus()
	elif step==2: (next_vehicle if race.race_mode=="freestyle" else next).grab_focus()
	else: race.menu.get_node("Start").grab_focus()
