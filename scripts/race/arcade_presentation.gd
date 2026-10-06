extends RefCounted
# Shared arcade skin; existing menu nodes retain their signals and save behaviour.
const INK: Color = Color("13286a")
const BLUE: Color = Color("00d5ff")
const PURPLE: Color = Color("0739a6")
const GOLD: Color = Color("fff000")
const PAPER: Color = Color("ffffff")
const RED: Color = Color("ff263f")
const PINK: Color = Color("ff2297")
const PORTRAITS: Texture2D = preload("res://assets/arcade/drivers.png")
const EXTRA_PORTRAITS: Array[Texture2D] = [preload("res://assets/arcade/driver_4.png"),preload("res://assets/arcade/driver_5.png"),preload("res://assets/arcade/driver_6_cyan.png"),preload("res://assets/arcade/driver_7_magenta.png")]
const PORTRAIT_COUNT: int = 8
const COURSE: Texture2D = preload("res://assets/arcade/blackjack.png")

static func portrait(index: int) -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	index = clampi(index,0,PORTRAIT_COUNT-1)
	texture.atlas = PORTRAITS if index<4 else EXTRA_PORTRAITS[index-4]
	texture.region = Rect2((index%2)*128,floorf(float(index)/2.0)*128,128,128) if index<4 else Rect2(Vector2.ZERO,texture.atlas.get_size())
	texture.filter_clip = true
	return texture

static func box(color: Color, border: Color = BLUE, width: int = 3) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.corner_detail = 8
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func theme() -> Theme:
	var skin: Theme = Theme.new()
	var font: FontFile = load("res://assets/arcade/arcade_font.fnt").duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	skin.default_font = font
	skin.default_font_size = 16
	for type: String in ["Label","RichTextLabel","Button","CheckButton","CheckBox","OptionButton","PopupMenu"]:
		skin.set_color("font_color",type,PAPER)
		skin.set_color("font_shadow_color",type,INK)
		skin.set_constant("shadow_offset_x",type,2)
		skin.set_constant("shadow_offset_y",type,2)
	for type: String in ["Button","CheckButton","CheckBox","OptionButton"]:
		skin.set_stylebox("normal",type,box(PURPLE))
		skin.set_stylebox("hover",type,box(Color("104fc5"),GOLD))
		skin.set_stylebox("pressed",type,box(GOLD,PINK))
		skin.set_stylebox("focus",type,box(Color.TRANSPARENT,PINK,3))
		skin.set_stylebox("disabled",type,box(Color("243a70"),Color("7092c7"),2))
		skin.set_color("font_hover_color",type,PAPER)
		skin.set_color("font_pressed_color",type,INK)
		skin.set_color("font_disabled_color",type,Color("b4cdfa"))
	skin.set_stylebox("panel","PopupMenu",box(INK,BLUE))
	skin.set_stylebox("hover","PopupMenu",box(PURPLE,GOLD,2))
	skin.set_stylebox("panel","Panel",box(PURPLE))
	skin.set_stylebox("panel","PanelContainer",box(INK))
	skin.set_stylebox("panel","AcceptDialog",box(INK,BLUE,3))
	skin.set_stylebox("panel","Window",box(INK,BLUE,3))
	for state: String in ["embedded_border","embedded_unfocused_border"]:
		var window_frame: StyleBoxFlat = box(INK,BLUE,3)
		window_frame.expand_margin_top = 30
		skin.set_stylebox(state,"Window",window_frame)
	skin.set_color("title_color","Window",PAPER)
	skin.set_color("title_outline_modulate","Window",INK)
	skin.set_stylebox("normal","TooltipPanel",box(INK,GOLD,2))
	skin.set_stylebox("background","ProgressBar",box(INK,BLUE,1))
	skin.set_stylebox("fill","ProgressBar",box(GOLD,Color.TRANSPARENT,0))
	for type: String in ["HSlider","VSlider"]:
		skin.set_stylebox("slider",type,box(INK,BLUE,1))
		skin.set_stylebox("grabber_area",type,box(BLUE,Color.TRANSPARENT,0))
		skin.set_stylebox("grabber_area_highlight",type,box(GOLD,Color.TRANSPARENT,0))
	return skin

static func label(parent: Node, title: String, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 16, color: Color = PAPER) -> Label:
	var node: Label = Label.new()
	node.name = title
	node.text = text
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func image_rect(parent: Control, title: String, texture: Texture2D, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.name = title
	node.position = pos
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.size = dimensions
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture = texture
	parent.add_child(node)
	return node

static func place(menu: Node, path: String, pos: Vector2, dimensions: Vector2, font_size: int = 16) -> void:
	var node: Control = menu.get_node(path)
	node.position = pos
	node.size = dimensions
	node.add_theme_font_size_override("font_size",font_size)

static func setup(race: Node3D) -> void:
	var menu: Panel = race.menu
	menu.position = Vector2(24,40)
	menu.size = Vector2(1152,720)
	menu.theme = theme()
	menu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	menu.add_theme_stylebox_override("panel",box(INK,BLUE,4))
	# An opaque checker field replaces the translucent garage panel.
	var background: TextureRect = image_rect(menu,"ArcadeBackdrop",load("res://assets/arcade/menu_pattern.svg"),Vector2(4,4),Vector2(1144,666))
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.modulate = Color(1,1,1,0.35)
	menu.move_child(background,0)
	for child: Node in menu.get_children():
		if child is Label:
			child.add_theme_color_override("font_color",PAPER)
		if child is Button:
			child.add_theme_color_override("font_color",PAPER)
	place(menu,"Title",Vector2(28,12),Vector2(720,50),40)
	menu.get_node("Title").add_theme_color_override("font_color",GOLD)
	place(menu,"Subtitle",Vector2(28,70),Vector2(1080,28),19)
	label(menu,"DriverHeading","01  SELECT DRIVER",Vector2(28,112),Vector2(660,26),18,GOLD)
	var grid: HBoxContainer = menu.get_node("DriverCards")
	grid.position = Vector2(28,146)
	grid.size = Vector2(650,198)
	grid.add_theme_constant_override("separation",12)
	for index: int in range(race.garage.cards.size()):
		var card: Button = race.garage.cards[index]
		card.custom_minimum_size = Vector2(153,198)
		card.add_theme_color_override("font_color",PAPER)
		var face: TextureRect = card.get_node("Portrait")
		face.texture = portrait(index)
		face.position = Vector2(12,10)
		face.size = Vector2(128,128)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var caption: Label = card.get_node("DriverCaption")
		caption.clip_text = true
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = Vector2(4,144)
		caption.size = Vector2(145,48)
		caption.add_theme_font_size_override("font_size",16)
		caption.add_theme_color_override("font_color",PAPER)
	label(menu,"RaceHeading","02  SET UP RACE",Vector2(28,358),Vector2(650,24),18,GOLD)
	place(menu,"QuickRace",Vector2(28,391),Vector2(650,38))
	menu.get_node("QuickRace/Difficulty").custom_minimum_size = Vector2(206,38)
	menu.get_node("QuickRace/Rivals").custom_minimum_size = Vector2(190,38)
	menu.get_node("QuickRace/Laps").custom_minimum_size = Vector2(238,38)
	menu.get_node("QuickRace/Difficulty").set_item_text(3,"Nightmare")
	menu.get_node("QuickRace/Difficulty").get_popup().set_item_tooltip(3,"Nightmare: three rivals, two relentless attackers")
	for path: String in ["QuickRace/Difficulty","QuickRace/Rivals","QuickRace/Laps"]:
		var choice: OptionButton = menu.get_node(path)
		choice.add_theme_font_size_override("font_size",16)
		choice.fit_to_longest_item = false
		choice.get_popup().theme = menu.theme
		choice.get_popup().add_theme_font_size_override("font_size",16)
	place(menu,"TrackSelect",Vector2(28,450),Vector2(338,38),16)
	place(menu,"VehicleClass",Vector2(378,450),Vector2(300,38),16)
	place(menu,"Record",Vector2(28,502),Vector2(650,32),16)
	place(menu,"Start",Vector2(28,551),Vector2(650,54),24)
	menu.get_node("Start").add_theme_stylebox_override("normal",box(BLUE,PAPER,3))
	place(menu,"Back",Vector2(28,621),Vector2(232,30),14)
	# Preserve the 2D project for direct editor use, outside the playable game.
	menu.get_node("Back").hide()
	menu.get_node("Back").focus_mode = Control.FOCUS_NONE
	place(menu,"Controller",Vector2(278,625),Vector2(400,24),12)
	label(menu,"CourseHeading","03  SELECT COURSE",Vector2(714,72),Vector2(410,28),18,GOLD)
	image_rect(menu,"CourseIllustration",COURSE,Vector2(714,112),Vector2(410,240))
	place(menu,"Diorama",Vector2(714,112),Vector2(410,240))
	place(menu,"CourseMap",Vector2(1036,292),Vector2(76,56))
	place(menu,"CourseInfo",Vector2(714,361),Vector2(410,63),12)
	place(menu,"Mode",Vector2(714,428),Vector2(410,38),14)
	place(menu,"SaveNotice",Vector2(714,647),Vector2(410,23),12)
	for path: String in ["TrackSelect","VehicleClass","Mode"]:
		var choice: OptionButton = menu.get_node(path)
		choice.fit_to_longest_item = false
		choice.get_popup().theme = menu.theme
		choice.get_popup().add_theme_font_size_override("font_size",16)
	var profile: Panel = Panel.new()
	profile.name = "DriverProfile"
	profile.position = Vector2(714,530)
	profile.size = Vector2(410,111)
	profile.add_theme_stylebox_override("panel",box(PURPLE,BLUE,2))
	menu.add_child(profile)
	image_rect(profile,"Face",portrait(0),Vector2(10,12),Vector2(80,80))
	label(profile,"Heading","DRIVER LICENCE",Vector2(104,8),Vector2(292,20),14,GOLD)
	label(profile,"Name","",Vector2(104,33),Vector2(292,24),18)
	label(profile,"Stats","",Vector2(104,60),Vector2(292,20),12)
	label(profile,"Motto","",Vector2(104,83),Vector2(292,20),12,Color("b6afff"))
	# The HUD shares typography and framed arcade colours without filling the race view.
	for path: String in ["Top","StandingBack","FooterBack","ResultsBackdrop"]:
		var panel: Panel = race.get_node("HUD/"+path)
		panel.theme = menu.theme
		panel.add_theme_stylebox_override("panel",box(INK,BLUE,2))
	for path: String in ["Title","Status","Standings","Footer","Banner"]:
		var node: Label = race.get_node("HUD/"+path)
		node.theme = menu.theme
		node.add_theme_color_override("font_color",PAPER)
		node.add_theme_color_override("font_shadow_color",INK)
		node.add_theme_constant_override("shadow_offset_x",2)
		node.add_theme_constant_override("shadow_offset_y",2)
	# Compact royal-blue instruments carry the logo palette without hiding the road.
	for path: String in ["Top","StandingBack"]:
		race.get_node("HUD/"+path).add_theme_stylebox_override("panel",box(Color(0.028,0.16,0.48,0.90),BLUE,2))
	var hud: Control = race.get_node("HUD/Top")
	hud.position = Vector2(20,20)
	hud.size = Vector2(300,80)
	place(race.get_node("HUD"),"Status",Vector2(30,26),Vector2(280,30),20)
	var metrics: Label = label(race.get_node("HUD"),"RaceMetrics","",Vector2(30,60),Vector2(280,20),14)
	metrics.theme = menu.theme
	var context: Label = label(race.get_node("HUD"),"VehicleContext","",Vector2(340,30),Vector2(650,28),12)
	context.theme = menu.theme
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	context.hide()
	place(race.get_node("HUD"),"Boost",Vector2(30,87),Vector2(280,5))
	race.get_node("HUD/Boost").add_theme_stylebox_override("background",box(Color(0.2,0.2,0.25,0.5),Color.TRANSPARENT,0))
	race.get_node("HUD/Boost").add_theme_stylebox_override("fill",box(GOLD,Color.TRANSPARENT,0))
	place(race.get_node("HUD"),"StandingBack",Vector2(1010,20),Vector2(170,94))
	place(race.get_node("HUD"),"Standings",Vector2(1020,26),Vector2(150,80),12)
	place(race.get_node("HUD"),"RaceMinimap",Vector2(1000,128),Vector2(180,132))
	for path: String in ["Title","Footer","FooterBack"]: race.get_node("HUD/"+path).hide()
	for state: String in ["fill","background"]:
		var style: StyleBoxFlat = race.get_node("HUD/Boost").get_theme_stylebox(state).duplicate()
		style.set_content_margin_all(0)
		race.get_node("HUD/Boost").add_theme_stylebox_override(state,style)
	race.get_node("HUD/Boost").size.y = 5
	race.banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_messages(race)
	refresh(race)

static func setup_messages(race: Node3D) -> void:
	race.start_lights = preload("res://scripts/race/start_lights.gd").new()
	race.start_lights.name = "StartLights"
	race.get_node("HUD").add_child(race.start_lights)
	race.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race.banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	race.banner.add_theme_constant_override("line_spacing",8)
	var frame: StyleBoxFlat = box(INK,BLUE,4)
	frame.set_content_margin_all(24)
	race.banner.add_theme_stylebox_override("normal",frame)
	var panel: Panel = race.results_panel
	panel.add_theme_stylebox_override("panel",box(INK,BLUE,4))
	var pattern: TextureRect = image_rect(panel,"Pattern",preload("res://scripts/race/game_brand.gd").tabletop_background(),Vector2(4,4),Vector2(752,472))
	pattern.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pattern.modulate.a = 0.12
	label(panel,"Heading","RACE RESULTS",Vector2(28,20),Vector2(704,40),28,GOLD)
	label(panel,"RunContext","",Vector2(28,62),Vector2(704,18),12,PAPER)
	image_rect(panel,"BrandLogo",preload("res://scripts/race/game_brand.gd").logo_texture(),Vector2(444,8),Vector2(284,58)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for index: int in range(3):
		var button: Button = Button.new()
		button.name = ["Retry","CourseSelect","Menu"][index]
		button.text = ["RETRY","SELECT COURSE","MAIN MENU"][index]
		button.add_theme_font_size_override("font_size",16)
		button.position = Vector2(28+index*240,496)
		button.size = Vector2(224,42)
		panel.add_child(button)
		if index==0: button.pressed.connect(race.results_action)
		elif index==1: button.pressed.connect(race.show_course_selection)
		else: button.pressed.connect(race.show_menu)

static func refresh_message(race: Node3D) -> void:
	if not race.results_panel.has_node("Retry"): return
	# All overlays use the menu's frame and spacing, including Time Trial notes.
	var results: bool = race.phase==3 or race.eliminated_player()
	var frame: StyleBoxFlat = race.banner.get_theme_stylebox("normal")
	frame.bg_color = Color.TRANSPARENT if results else INK
	frame.set_border_width_all(0 if results else 4)
	frame.set_content_margin_all(0 if results else 24)
	race.banner.add_theme_constant_override("line_spacing",3 if results else 8)
	race.banner.add_theme_color_override("font_color",PAPER if results or race.banner.text.length()>12 else GOLD)
	if results:
		race.results_panel.get_node("Heading").text = "ELIMINATED" if race.eliminated_player() and race.phase!=3 else ("DRIFT RESULTS" if race.race_mode=="drift" else "RACE RESULTS")
		race.results_panel.get_node("RunContext").text = race.race_mode.to_upper().replace("TRIAL","TIME TRIAL")+" · "+preload("res://scripts/vehicles/vehicle_catalog.gd").title(race.player_car.base_tuning.id)+" · "+race.course.entry.title
		race.results_panel.position = Vector2(220,120)
		race.results_panel.size = Vector2(760,560)
		race.results_panel.get_node("Pattern").size = Vector2(752,552)
		race.banner.position = Vector2(248,466)
		race.banner.size = Vector2(704,96)
		race.banner.add_theme_font_size_override("font_size",14)
		race.results_panel.get_node("Retry").text = ("NEW SERIES" if race.tournament.RULES.complete(race.profile.data.tournament) else "NEXT ROUND") if race.race_mode=="tournament" else ("NEXT ROUND" if race.race_mode=="cup" and race.profile.data.cup.rounds.size()<3 else "RETRY")
	elif race.phase==6:
		race.banner.position = Vector2(260,650)
		race.banner.size = Vector2(680,80)
		race.banner.add_theme_font_size_override("font_size",20)
	elif race.phase in [2,5] and not race.paused_race:
		var compact: bool = race.phase==2 and not race.banner.text.contains("\n") and race.feedback.message_priority<3
		race.banner.position = Vector2(380,112) if compact else Vector2(320,112)
		race.banner.size = Vector2(440,56) if compact else Vector2(560,76)
		frame.set_border_width_all(2 if compact else 4)
		frame.set_content_margin_all(12 if compact else 24)
		race.banner.add_theme_font_size_override("font_size",18)
	else:
		race.banner.position = Vector2(260,280)
		race.banner.size = Vector2(680,180)
		race.banner.add_theme_font_size_override("font_size",22 if race.banner.text.length()>20 else 43)

static func refresh(race: Node3D) -> void:
	var menu: Control = race.menu
	if not menu.has_node("DriverProfile"): return
	# Text wrapping updates its minimum after the theme/width change. Shrink the
	# old label bounds afterwards so they cannot cover the mode selector.
	menu.get_node("CourseInfo").set_deferred("size",Vector2(410,63))
	var blackjack: bool = race.track_id=="game_table" and race.track.definition.revision<6
	menu.get_node("CourseIllustration").visible = blackjack
	menu.get_node("Diorama").visible = not blackjack
	var selected: int = race.garage.selected
	var profile: Control = menu.get_node("DriverProfile")
	profile.get_node("Face").texture = portrait(race.profile.data.identity.portrait_id)
	profile.get_node("Name").text = race.profile.data.identity.name
	profile.get_node("Stats").text = "%d SAVED RACE RECORDS" % race.profile.data.records.size()
	profile.get_node("Motto").text = preload("res://scripts/profiles/character_catalog.gd").NAMES[race.profile.data.identity.portrait_id].to_upper()
	for index: int in range(race.garage.cards.size()):
		var card: Button = race.garage.cards[index]
		card.get_node("DriverCaption").text = ("P1  " if index==selected else "%02d  " % [index+1])+race.garage.DRIVERS[index].split(" · ")[1].replace(" ","\n")
		card.get_node("DriverCaption").add_theme_color_override("font_color",INK if index==selected else PAPER)
	menu.get_node("SaveNotice").visible = not race.profile.status.is_empty()
	if race.menu_flow!=null: race.menu_flow.refresh()
	for path: String in ["Top","Status","Boost","StandingBack","Standings"]:
		race.get_node("HUD/"+path).visible = not menu.visible and race.phase!=6
