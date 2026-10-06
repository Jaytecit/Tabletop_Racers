extends Node
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const MODEL: Script = preload("res://scripts/vehicles/developer_tuning.gd")
const EXPORT: Script = preload("res://scripts/vehicles/developer_export.gd")
const GROUPS: Array[String] = ["Physics","Boost / Recovery","Surfaces","AI","Vehicle Details","Effects"]
const TARGETS: Array[String] = ["player","all_ai","ai_1","ai_2","ai_3","vehicle:buggy","vehicle:monster_truck","vehicle:racing_car","vehicle:drift_car","vehicle:speedboat"]
var race: Node3D
var root: Control
var panel: PanelContainer
var launch: Button
var pause_launch: Button
var target: OptionButton
var group: OptionButton
var rows: VBoxContainer
var fields: Dictionary = {}
var notice: Label
var status: Label
var dialog: FileDialog
var reset_dialog: ConfirmationDialog
var old_focus: Control
var old_modes: Dictionary = {}
var was_paused: bool = false

func button(parent: Node, text: String, action: Callable) -> Button:
	var control: Button = Button.new()
	control.text = text
	control.add_theme_font_size_override("font_size",14)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func label(parent: Node, text: String) -> Label:
	var control: Label = Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size",13)
	parent.add_child(control)
	return control

func setup(owner: Node3D) -> void:
	race = owner
	launch = button(race.menu,"DEVELOPER TUNING",open)
	launch.name = "DeveloperTuning"
	launch.position = Vector2(590,658)
	launch.size = Vector2(320,36)
	pause_launch = button(race.get_node("HUD"),"DEVELOPER TUNING",open)
	pause_launch.theme = race.menu.theme
	pause_launch.position = Vector2(440,510)
	pause_launch.size = Vector2(320,42)
	pause_launch.hide()
	root = Control.new()
	root.name = "DeveloperOverlay"
	root.size = get_viewport().get_visible_rect().size
	root.z_index = 200
	root.theme = race.menu.theme
	race.get_node("HUD").add_child(root)
	var mask: ColorRect = ColorRect.new()
	mask.color = Color(0,0,0,0.85)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(mask)
	panel = PanelContainer.new()
	panel.position = Vector2(36,24)
	panel.size = Vector2(1080,646)
	panel.add_theme_stylebox_override("panel",SKIN.box(SKIN.INK,SKIN.GOLD,3))
	root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	label(column,"DEVELOPER TUNING / SESSION OVERRIDES").add_theme_font_size_override("font_size",22)
	status = label(column,"")
	var selectors: HBoxContainer = HBoxContainer.new()
	column.add_child(selectors)
	target = OptionButton.new()
	target.custom_minimum_size = Vector2(280,34)
	for title: String in ["PLAYER","ALL AI","AI 1","AI 2","AI 3"]: target.add_item(title)
	for title: String in preload("res://scripts/vehicles/vehicle_catalog.gd").TITLES: target.add_item(title+" BASELINE")
	selectors.add_child(target)
	target.item_selected.connect(func(_index: int) -> void: rebuild())
	group = OptionButton.new()
	group.custom_minimum_size = Vector2(300,34)
	for title: String in GROUPS: group.add_item(title)
	selectors.add_child(group)
	group.item_selected.connect(func(_index: int) -> void: rebuild())
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,332)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	label(column,"Enter a number, then APPLY. Fine: 0.01 / coarse: 0.1. Geometry and watercraft apply on race reset.")
	notice = label(column,"")
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 38
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	button(actions,"RESET TARGET",func() -> void: race.developer.reset_target(TARGETS[target.selected]); rebuild())
	button(actions,"RESET ALL",func() -> void: race.developer.reset_all(); rebuild())
	button(actions,"EXPORT SETUP JSON",export_dialog)
	button(actions,"CLEAR EARNED AND SPENT REWARDS",confirm_reset)
	button(actions,"BACK",close)
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Setup JSON"])
	dialog.title = "Export Complete Developer Setup"
	dialog.current_file = "tabletop-setup.json"
	dialog.size = Vector2i(860,560)
	root.add_child(dialog)
	dialog.file_selected.connect(export_path)
	dialog.canceled.connect(func() -> void: notice.text = "Export cancelled. Session setup retained."; target.grab_focus())
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Clear Earned and Spent Rewards"
	reset_dialog.ok_button_text = "CLEAR REWARDS"
	reset_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reset_dialog.get_label().custom_minimum_size.x = 620
	root.add_child(reset_dialog)
	reset_dialog.confirmed.connect(clear_rewards)
	root.hide()

func _process(_delta: float) -> void:
	pause_launch.visible = race.paused_race and race.phase in [1,2,5] and not root.visible
	launch.visible = race.phase==0 and race.menu_flow.step==0
	if root.visible:
		status.text = "EXPERIMENTAL / UNRANKED / RECORDS AND REWARDS DISABLED" if race.experimental() else "Earned setup / edits start an unranked experiment"

func _unhandled_input(event: InputEvent) -> void:
	if root.visible and not dialog.visible and not reset_dialog.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if root.visible or not race.profile_selected or race.profile_menu.visible or race.course.loading: return
	if race.stats_menu.panel.visible or race.setup_menu.panel.visible or race.controls_setup.panel.visible: return
	old_focus = get_viewport().gui_get_focus_owner()
	was_paused = race.paused_race
	race.paused_race = true
	old_modes.clear()
	for control: Node in race.get_node("HUD").find_children("*","Control",true,false):
		if control==root or root.is_ancestor_of(control): continue
		old_modes[control] = control.focus_mode
		control.focus_mode = Control.FOCUS_NONE
	notice.text = "Session only. Vehicle baselines apply before earned upgrades and racer overrides. Zero boost drain is unlimited."
	rebuild()
	root.show()
	target.grab_focus()

func close() -> void:
	dialog.hide()
	reset_dialog.hide()
	root.hide()
	for control: Variant in old_modes:
		if is_instance_valid(control): control.focus_mode = old_modes[control]
	old_modes.clear()
	# Escape can also be bound to pause; do not let the same press resume the race.
	for index: int in range(3):
		if Input.is_action_pressed(["restart","pause_race","menu"][index]): race.action_latches[index] = 1
	race.paused_race = was_paused
	pause_launch.visible = race.paused_race and race.phase in [1,2,5]
	if is_instance_valid(old_focus) and old_focus.is_visible_in_tree(): old_focus.grab_focus()

static func section(field: String) -> int:
	if field=="tyre_effect_threshold": return 5
	if field.begins_with("ai."): return 3
	if field.begins_with("surface"): return 2
	if field.begins_with("boost") or field.begins_with("recovery"): return 1
	if field.begins_with("collision") or field in ["watercraft","traffic_half_width"]: return 4
	return 0

func rebuild() -> void:
	for node: Node in rows.get_children():
		rows.remove_child(node)
		node.queue_free()
	fields.clear()
	var selected_target: String = TARGETS[target.selected]
	var cars: Array = race.developer.targets(selected_target)
	for item: Dictionary in race.developer.target_descriptors(selected_target):
		if section(item.field)!=group.selected: continue
		if item.target=="ai" and target.selected==0: continue
		var row: HBoxContainer = HBoxContainer.new()
		rows.add_child(row)
		var caption: Label = label(row,"SMOKE / SQUEAL THRESHOLD" if item.field=="tyre_effect_threshold" else item.field.replace("_"," ").to_upper())
		caption.custom_minimum_size.x = 270
		caption.clip_text = true
		caption.tooltip_text = "Higher values require more sliding or dirt speed before smoke and squeal start. 1 = original threshold." if item.field=="tyre_effect_threshold" else item.field
		var state: Dictionary = race.developer.values(TARGETS[target.selected],item.field)
		var reference: Label = label(row,"stock %s %s\nrange %s - %s\n%s" % [str(item.default),item.unit.replace("×","x").replace("²","^2"),str(item.min),str(item.max),"RESET REQUIRED" if state.restart_required else ("APPLIES ON RESET" if item.apply=="restart" else "LIVE")])
		reference.custom_minimum_size.x = 185
		reference.clip_text = true
		reference.tooltip_text = reference.text
		if item.type=="bool":
			var toggle: CheckButton = CheckButton.new()
			toggle.text = "MIXED" if state.mixed else "ON / OFF"
			toggle.button_pressed = bool(state.value)
			row.add_child(toggle)
			toggle.toggled.connect(func(value: bool) -> void: apply_value(item.field,value))
			fields[item.field] = toggle
		else:
			var entry: LineEdit = LineEdit.new()
			entry.custom_minimum_size.x = 110
			entry.text = "MIXED" if state.mixed else "%.4f" % float(state.value)
			entry.tooltip_text = "%s: %s to %s %s" % [item.field,str(item.min),str(item.max),item.unit]
			row.add_child(entry)
			fields[item.field] = entry
			entry.text_submitted.connect(func(text: String) -> void: apply_text(item.field,text))
			button(row,"APPLY",func() -> void: apply_text(item.field,entry.text))
			for amount: float in [-float(item.coarse),-float(item.fine),float(item.fine),float(item.coarse)]:
				button(row,("+" if amount>0 else "")+str(amount),func() -> void: adjust(item.field,amount))
	if group.selected==3 and (target.selected==0 or not race.developer.vehicle_id(selected_target).is_empty()): label(rows,"Select All AI or an individual AI to edit behaviour.")
	if group.selected==4:
		var id: String = race.developer.vehicle_id(selected_target)
		var base: Resource = preload("res://scripts/vehicles/vehicle_catalog.gd").definition(id) if not id.is_empty() else (cars[0].base_tuning if not cars.is_empty() else null)
		if base!=null:
			label(rows,"VEHICLE: "+base.id+" / "+base.resource_path)
			label(rows,"SOURCE: "+preload("res://scripts/vehicles/imported_visual.gd").MODELS[base.id])

func apply_text(field: String, text: String) -> void:
	if not text.is_valid_float():
		notice.text = "Enter a finite number for "+field+". No settings changed."
		return
	apply_value(field,float(text))

func adjust(field: String, amount: float) -> void:
	var value: Dictionary = race.developer.values(TARGETS[target.selected],field)
	if value.mixed:
		notice.text = "Mixed values: enter a shared value or select one AI first."
		return
	apply_value(field,float(value.value)+amount)

func apply_value(field: String, value: Variant) -> void:
	var focus_field: String = field
	if not race.developer.set_value(TARGETS[target.selected],field,value):
		notice.text = "Rejected "+field+": use its displayed range and a finite value. No settings changed."
		return
	var state: Dictionary = race.developer.values(TARGETS[target.selected],field)
	notice.text = field.replace("_"," ")+" applied"+(" / RESET RACE TO APPLY GEOMETRY" if state.restart_required else " / LIVE")
	rebuild()
	if fields.has(focus_field): fields[focus_field].grab_focus()

func export_dialog() -> void:
	dialog.popup_centered()

func export_path(path: String) -> void:
	var error: Error = EXPORT.write(race,path)
	notice.text = "Export saved: "+path if error==OK else "Export failed: "+error_string(error)+". Session setup retained."
	target.grab_focus()

func confirm_reset() -> void:
	reset_dialog.dialog_text = "Selected profile: "+race.profile.data.identity.name+"\n\nClear upgrade balances and spent upgrades, Bling,\npurchased/equipped paint and gold unlock,\ncup/tournament reward progress and challenge awards.\n\nRestore the portrait's ten-point starting build\nfor EVERY vehicle.\n\nKeep name, portrait, preferences and race records.\nA separate profile backup is saved before clearing."
	reset_dialog.popup_centered(Vector2i(720,400))

func clear_rewards() -> void:
	var error: Error = race.profile.clear_earned_and_spent_rewards()
	if error!=OK:
		notice.text = "Reward reset failed: "+error_string(error)+". Check profile storage before retrying."
		return
	race.rewards_awarded = true
	if race.phase in [1,2,5]: race.developer.run_experimental = true
	race.garage.select(race,race.garage.selected)
	race.trial.refresh_signature()
	rebuild()
	notice.text = "Earned and spent rewards cleared. Identity, preferences and records preserved; backup saved."
