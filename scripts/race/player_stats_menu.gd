extends Node
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const PROGRESSION: Script = preload("res://scripts/vehicles/vehicle_progression.gd")
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
var race: Node3D
var panel: Panel
var mask: ColorRect
var launch: Button
var choices: Dictionary = {}
var bars: Dictionary = {}
var pending: Dictionary = {}
var notice: Label
var values: Label
var title: Label
var help: Label
var save_button: Button
var shop_button: Button
var test_button: Button
var shop: bool = false
var previous_focus: Dictionary = {}

func setup(race_owner: Node3D) -> void:
	race = race_owner
	launch = Button.new()
	launch.name = "VehicleUpgrades"
	launch.text = "VEHICLE UPGRADES"
	launch.position = Vector2(444,658)
	launch.size = Vector2(260,38)
	race.menu.add_child(launch)
	launch.pressed.connect(open)
	launch.hide()
	mask = ColorRect.new()
	mask.size = race.menu.size
	mask.color = Color(0,0,0,0.8)
	race.menu.add_child(mask)
	panel = Panel.new()
	panel.name = "PlayerStats"
	panel.position = Vector2(126,74)
	panel.size = Vector2(900,542)
	panel.theme = race.menu.theme
	panel.add_theme_stylebox_override("panel",SKIN.box(SKIN.INK,SKIN.GOLD,3))
	race.menu.add_child(panel)
	title = SKIN.label(panel,"Title","",Vector2(24,20),Vector2(852,36),24,SKIN.GOLD)
	help = SKIN.label(panel,"Help","",Vector2(24,64),Vector2(852,40),14)
	for i: int in range(STATS.FIELDS.size()):
		var field: String = STATS.FIELDS[i]
		var choice: Button = Button.new()
		choice.name = field.capitalize()
		choice.position = Vector2(24,116+i*44)
		choice.size = Vector2(852,40)
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.add_theme_font_size_override("font_size",16)
		panel.add_child(choice)
		choices[field] = choice
		choice.pressed.connect(func() -> void: activate(field))
		var bar: ProgressBar = ProgressBar.new()
		bar.position = Vector2(490,8)
		bar.size = Vector2(350,24)
		bar.max_value = 24
		bar.step = 1
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size",1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice.add_child(bar)
		for segment: int in range(1,24):
			var divider: ColorRect = ColorRect.new()
			divider.position = Vector2(roundf(350.0*segment/24.0),0)
			divider.size = Vector2(2,24)
			divider.color = SKIN.INK
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(divider)
		bars[field] = bar
	notice = SKIN.label(panel,"Budget","",Vector2(24,342),Vector2(852,24),16,SKIN.GOLD)
	values = SKIN.label(panel,"Values","",Vector2(24,378),Vector2(852,44),12)
	test_button = Button.new()
	test_button.name = "StatTest"
	test_button.position = Vector2(24,424)
	test_button.size = Vector2(852,30)
	test_button.add_theme_font_size_override("font_size",14)
	panel.add_child(test_button)
	test_button.pressed.connect(func() -> void:
		race.stats_test_mode = (race.stats_test_mode+1)%3
		race.garage.apply_stats(race)
		refresh())
	for i: int in range(3):
		var button: Button = Button.new()
		button.position = Vector2(24+i*286,466)
		button.size = Vector2(270,46)
		panel.add_child(button)
		if i==0:
			save_button = button
			button.text = "SAVE UPGRADES"
			button.pressed.connect(apply)
		elif i==1:
			shop_button = button
			button.pressed.connect(func() -> void:
				shop = not shop
				refresh())
		else:
			button.text = "CANCEL / BACK"
			button.pressed.connect(close)
	close()

func cost() -> int:
	return STATS.spent(pending)-STATS.spent(race.profile.vehicle().stats)

func open() -> void:
	if race.phase!=0 or race.setup_menu.panel.visible or race.controls_setup.panel.visible: return
	shop = false
	pending = race.profile.vehicle().stats.duplicate()
	refresh()
	previous_focus.clear()
	for control: Node in race.menu.find_children("*","Control",true,false):
		if control!=panel and not panel.is_ancestor_of(control):
			previous_focus[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	mask.show()
	panel.show()
	choices.grip.grab_focus()

func activate(field: String) -> void:
	if shop:
		var index: int = STATS.FIELDS.find(field)
		if PROGRESSION.purchase(race.profile.vehicle(),index,race.profile.wallet()):
			race.profile.data.gold_livery = false
			race.garage.select(race,race.garage.selected)
			race.save_preferences()
		refresh()
	else: adjust(field,1)

func adjust(field: String, direction: int) -> void:
	if shop or race.stats_test_mode!=0: return
	var saved: Dictionary = race.profile.vehicle().stats
	if direction>0 and (pending[field]>=STATS.MAXIMUM or cost()>=race.profile.wallet().points): return
	if direction<0 and pending[field]<=saved[field]: return
	pending[field] += STATS.STEP*direction
	refresh()

func refresh() -> void:
	var build: Dictionary = race.profile.vehicle()
	var displayed: Dictionary = pending if race.stats_test_mode==0 else race.active_stats()
	test_button.visible = not shop
	test_button.text = "TEST STATS: "+["EARNED / SWITCH TO ZERO","ZERO / SWITCH TO FULL","FULL / RESTORE EARNED"][race.stats_test_mode]
	title.text = preload("res://scripts/vehicles/vehicle_catalog.gd").title(race.player_car.base_tuning.id)+" / "+("BLING SHOP" if shop else "VEHICLE UPGRADES")
	help.text = "Buy or equip paint with Bling. Gold is earned by winning the cup." if shop else "1 POINT = 0.25 BOOST. UP/DOWN: STAT. SELECT/RIGHT: UPGRADE.\nLEFT: UNDO PENDING. SAVE TO CONFIRM."
	shop_button.text = "VEHICLE UPGRADES" if shop else "BLING SHOP"
	save_button.disabled = shop or race.stats_test_mode!=0 or cost()==0
	notice.text = "DRIVER BALANCE: %d UPGRADE POINTS / %d BLING" % [race.profile.wallet().points-cost(),race.profile.wallet().bling]
	for i: int in range(STATS.FIELDS.size()):
		var field: String = STATS.FIELDS[i]
		choices[field].visible = not shop or i<PROGRESSION.PAINTS.size()
		if not choices[field].visible: continue
		bars[field].visible = not shop
		if shop:
			var paint: String = PROGRESSION.PAINTS[i]
			var status: String = "EQUIPPED" if build.paint==paint and not race.profile.data.gold_livery else ("EQUIP" if paint in build.owned else "%d BLING" % PROGRESSION.COSTS[i])
			choices[field].text = PROGRESSION.NAMES[i]+" / "+status
			choices[field].modulate = PROGRESSION.COLORS[i]
		else:
			choices[field].modulate = Color.WHITE
			var level: int = roundi((displayed[field]-STATS.MINIMUM)/STATS.STEP)
			choices[field].text = "%s / %.2f / %d OF 24%s" % [field.to_upper(),displayed[field]-STATS.MINIMUM,level," / MAX" if level==24 else ""]
			bars[field].value = level
	if shop:
		values.text = "Paint purchases save immediately and use only Bling.\nStock uses your driver's colour. Owned paints equip freely."
	else:
		var tuning: Resource = STATS.compose(race.player_car.base_tuning,displayed)
		values.text = "GRIP %.2f / TOP SPEED %.2f / ACCELERATION %.2f\nFULL BOOST %.2fs / CRASH RETURN %.2fs / FALL RETURN %.2fs" % [tuning.grip,tuning.top_speed,tuning.acceleration,100.0/tuning.boost_drain,1.55/tuning.recovery_speed,1.85/tuning.recovery_speed]

func apply() -> void:
	var build: Dictionary = race.profile.vehicle()
	if shop or race.stats_test_mode!=0 or not STATS.valid(pending) or cost()<=0 or cost()>race.profile.wallet().points: return
	for field: String in STATS.FIELDS:
		if pending[field]<build.stats[field]: return
	race.profile.wallet().points -= cost()
	build.stats = pending.duplicate()
	race.garage.apply_stats(race)
	race.save_preferences()
	race.menu_flow.refresh()
	close()

func close() -> void:
	panel.hide()
	mask.hide()
	for control: Control in previous_focus:
		if is_instance_valid(control): control.focus_mode = previous_focus[control]
	previous_focus.clear()
	if launch.is_visible_in_tree(): launch.grab_focus()

func _input(event: InputEvent) -> void:
	if not panel.visible: return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif not shop and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		for field: String in STATS.FIELDS:
			if choices[field].has_focus():
				adjust(field,1 if event.is_action_pressed("ui_right") else -1)
				get_viewport().set_input_as_handled()
				break
