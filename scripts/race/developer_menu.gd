extends Node
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const MODEL: Script = preload("res://scripts/vehicles/developer_tuning.gd")
const EXPORT: Script = preload("res://scripts/vehicles/developer_export.gd")
const GROUPS: Array[String] = ["Physics","Boost / Recovery","Surfaces","AI","Vehicle Details","Effects"]
const TARGETS: Array[String] = ["shared_vehicle","shared_character","overall_ai","vehicle:buggy","vehicle:monster_truck","vehicle:racing_car","vehicle:drift_car","vehicle:speedboat","character:0","character:1","character:2","character:3","character:4","character:5","character:6","character:7"]
var scope: Label
var preview: Label
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
	label(column,"DEVELOPER TUNING / BASELINES").add_theme_font_size_override("font_size",22)
	status = label(column,"")
	var selectors: HBoxContainer = HBoxContainer.new()
	column.add_child(selectors)
	target = OptionButton.new()
	target.custom_minimum_size = Vector2(280,34)
	for title: String in ["ALL VEHICLES / SHARED","ALL CHARACTERS / SHARED","OVERALL AI"]: target.add_item(title)
	for title: String in preload("res://scripts/vehicles/vehicle_catalog.gd").TITLES: target.add_item("VEHICLE / "+title)
	for title: String in MODEL.CHARACTERS.NAMES: target.add_item("CHARACTER / "+title.to_upper())
	selectors.add_child(target)
	target.item_selected.connect(func(_index: int) -> void: rebuild())
	group = OptionButton.new()
	group.custom_minimum_size = Vector2(300,34)
	for title: String in GROUPS: group.add_item(title)
	selectors.add_child(group)
	group.item_selected.connect(func(_index: int) -> void: rebuild())
	scope = label(column,"")
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope.custom_minimum_size.y = 34
	preview = label(column,"")
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	label(column,"1x = unchanged. APPLY edits this layer. INHERIT removes its override. Vehicle geometry applies on race reset.")
	notice = label(column,"")
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 38
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	button(actions,"RESET LAYER",func() -> void: race.developer.reset_target(TARGETS[target.selected]); rebuild())
	button(actions,"RESET ALL LAYERS",func() -> void: race.developer.reset_all(); rebuild())
	button(actions,"SAVE BASELINES",save_baselines)
	button(actions,"EXPORT SETUP",export_dialog)
	var secondary: HBoxContainer = HBoxContainer.new()
	column.add_child(secondary)
	button(secondary,"CLEAR EARNED AND SPENT REWARDS",confirm_reset)
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
		status.text = ("EXPERIMENTAL / UNRANKED" if race.experimental() else "FACTORY BASELINES")+" / "+("UNSAVED CHANGES" if race.developer.dirty() else race.developer.storage_status)

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
	notice.text = "Order: vehicle defaults > shared vehicle scale > vehicle override > AI scale (AI only) > character modifier > driver upgrade build. SAVE keeps developer baselines across launches; tuning remains unranked."
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
	var id: String = race.developer.vehicle_id(selected_target)
	var character: int = race.developer.character_id(selected_target)
	var active_count: int = 0
	for car: CharacterBody3D in cars:
		if car in race.cars: active_count += 1
	var descriptions: Dictionary = {
		"shared_vehicle":"Shared vehicle multipliers: scale factory handling for every vehicle. Individual vehicle overrides take priority. Geometry is vehicle-specific.",
		"shared_character":"Shared character multipliers: apply to every character after vehicle / AI physics, before the driver's upgrade build.",
		"overall_ai":"AI-only physics multipliers and behaviour overrides. Untouched behaviour follows the selected difficulty; character AI overrides take priority."}
	scope.text = descriptions.get(selected_target,"Individual vehicle absolute values replace the shared vehicle result; upgrades still apply afterwards." if not id.is_empty() else "Character modifiers follow portrait identity in any vehicle or race slot. Untouched fields inherit the shared character / overall AI settings. AI fields affect AI drivers only.")
	scope.text += " Affected: %d active / %d available racers." % [active_count,cars.size()]
	preview.text = "Driver upgrades, rewards, controls, audio and video are not edited here."
	if not cars.is_empty():
		var car: CharacterBody3D = cars[0]
		preview.text += " Preview slot %d: %s / %s | speed %.2f m/s, grip %.2f, accel %.2f m/s/s (includes driver build)." % [car.player,MODEL.CHARACTERS.NAMES[race.developer.character_for(car)],MODEL.CATALOG.title(car.base_tuning.id),car.tuning.top_speed,car.tuning.grip,car.tuning.acceleration]
	for item: Dictionary in race.developer.target_descriptors(selected_target):
		if section(item.field)!=group.selected: continue
		var row: HBoxContainer = HBoxContainer.new()
		rows.add_child(row)
		var caption: Label = label(row,"SMOKE / SQUEAL THRESHOLD" if item.field=="tyre_effect_threshold" else item.field.replace("_"," ").to_upper())
		caption.custom_minimum_size.x = 230
		caption.clip_text = true
		caption.tooltip_text = "Higher values require more sliding or dirt speed before smoke and squeal start. 1 = original threshold." if item.field=="tyre_effect_threshold" else item.field
		var state: Dictionary = race.developer.values(TARGETS[target.selected],item.field)
		var reference: Label = label(row,"inherited %s %s\n%s / %s\nrange %s - %s" % [str(item.default),item.unit,"OVERRIDE" if state.overridden else "INHERITING","RESET REQUIRED" if state.restart_required else ("ON RESET" if item.apply=="restart" else "LIVE"),str(item.min),str(item.max)])
		reference.custom_minimum_size.x = 240
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
		button(row,"INHERIT",func() -> void: race.developer.inherit_field(selected_target,item.field); rebuild())
	if group.selected==3 and selected_target!="overall_ai" and character<0: label(rows,"AI behaviour lives in OVERALL AI and individual CHARACTER layers.")
	if group.selected==4:
		if id.is_empty(): label(rows,"Collision geometry and watercraft belong to individual VEHICLE layers.")
		var base: Resource = preload("res://scripts/vehicles/vehicle_catalog.gd").definition(id) if not id.is_empty() else (cars[0].base_tuning if not cars.is_empty() else null)
		if base!=null and not id.is_empty():
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

func save_baselines() -> void:
	var error: Error = race.developer.save_settings()
	notice.text = "Baselines saved for all profiles and future launches. Developer tuning remains unranked." if error==OK else "Save failed: "+error_string(error)+". Changes retained in this session."
	rebuild()

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
