extends Control
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const CHARACTERS: Script = preload("res://scripts/profiles/character_catalog.gd")
var race: Node3D
var picker: OptionButton
var name_input: LineEdit
var face: TextureRect
var notice: Label
var editor: Control
var title: Label
var portraits: Array[Button] = []
var selected_portrait: int = 0
var editing_id: String = ""
var entries: Array = []
var name_keyboard: Control
var character_name: Label
var character_bio: Label

func _ready() -> void:
	name = "ProfileMenu"
	size = Vector2(1200,800)
	theme = SKIN.theme()
	var backdrop: ColorRect = ColorRect.new()
	backdrop.size = size
	backdrop.color = SKIN.INK
	add_child(backdrop)
	var body: Panel = Panel.new()
	body.position = Vector2(210,60)
	body.size = Vector2(780,680)
	body.add_theme_stylebox_override("panel",SKIN.box(SKIN.PURPLE,SKIN.BLUE,3))
	add_child(body)
	title = SKIN.label(body,"Title","SELECT YOUR SAVED DRIVER",Vector2(30,24),Vector2(720,38),24,SKIN.GOLD)
	picker = OptionButton.new()
	picker.position = Vector2(30,84)
	picker.size = Vector2(520,44)
	body.add_child(picker)
	picker.item_selected.connect(preview)
	face = SKIN.image_rect(body,"Portrait",SKIN.portrait(0),Vector2(590,82),Vector2(140,140))
	character_name = SKIN.label(body,"CharacterName","",Vector2(570,238),Vector2(180,44),14,SKIN.GOLD)
	character_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_bio = SKIN.label(body,"CharacterBio","",Vector2(570,294),Vector2(180,208),12)
	character_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor = Control.new()
	editor.position = Vector2(30,152)
	editor.size = Vector2(530,370)
	body.add_child(editor)
	SKIN.label(editor,"NameLabel","NAME / 1 TO 9 LETTERS",Vector2.ZERO,Vector2(500,24),16)
	name_input = LineEdit.new()
	# Validate the entire paste rather than silently truncating a different name.
	name_input.position = Vector2(0,34)
	name_input.size = Vector2(370,44)
	name_input.placeholder_text = "Your driver name"
	editor.add_child(name_input)
	var pad_entry: Button = Button.new()
	pad_entry.name = "GamepadNameEntry"
	pad_entry.text = "PAD KEYS"
	pad_entry.position = Vector2(382,34)
	pad_entry.size = Vector2(118,44)
	pad_entry.add_theme_font_size_override("font_size",14)
	pad_entry.pressed.connect(open_name_keyboard)
	editor.add_child(pad_entry)
	SKIN.label(editor,"PortraitLabel","CHOOSE A PORTRAIT",Vector2(0,94),Vector2(500,24),16)
	for i: int in range(SKIN.PORTRAIT_COUNT):
		var choice: Button = Button.new()
		choice.position = Vector2((i%4)*126,126+floori(float(i)/4.0)*116)
		choice.size = Vector2(112,108)
		choice.toggle_mode = true
		choice.tooltip_text = CHARACTERS.NAMES[i]+" / "+CHARACTERS.COLOUR_NAMES[i]+"\n"+CHARACTERS.BIOS[i]
		choice.pressed.connect(choose_portrait.bind(i))
		editor.add_child(choice)
		SKIN.image_rect(choice,"Face",SKIN.portrait(i),Vector2(8,8),Vector2(96,92)).mouse_filter = Control.MOUSE_FILTER_IGNORE
		portraits.append(choice)
	notice = SKIN.label(body,"Notice","",Vector2(30,526),Vector2(710,54),14)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions: Array = [["Confirm","CONFIRM",confirm],["Create","NEW DRIVER",create],["Back","BACK",go_back]]
	for i: int in range(actions.size()):
		var button: Button = Button.new()
		button.name = actions[i][0]
		button.text = actions[i][1]
		button.position = Vector2(30+i*244,602)
		button.size = Vector2(230,48)
		button.pressed.connect(actions[i][2])
		body.add_child(button)
	name_keyboard = preload("res://scripts/profiles/gamepad_name_keyboard.gd").new()
	add_child(name_keyboard)
	hide()

func open_name_keyboard() -> void:
	if visible and editor.visible: name_keyboard.open(self)

func _input(event: InputEvent) -> void:
	if not visible or name_keyboard.visible or not editor.visible: return
	if event is InputEventJoypadButton and event.is_action_pressed("ui_accept") and name_input.has_focus():
		open_name_keyboard()
		get_viewport().set_input_as_handled()

func open() -> void:
	if race.phase not in [0,4]: return
	name_keyboard.hide()
	race.menu.hide()
	show()
	entries = race.profile_directory.list_profiles()
	picker.clear()
	for entry: Dictionary in entries: picker.add_item(entry.name)
	var selected: int = 0
	for i: int in range(entries.size()):
		if entries[i].id==race.profile_directory.index.last_selected: selected = i
	if entries.is_empty(): create()
	else:
		picker.select(selected)
		preview(selected)
	notice.text = race.profile_directory.status
	if race.profile_directory.read_only: notice.text += " Cannot select or create a driver."
	if editor.visible: name_input.grab_focus.call_deferred()
	else: picker.grab_focus.call_deferred()

func preview(index: int) -> void:
	var entry: Dictionary = entries[index]
	editing_id = entry.id if entry.get("needs_identity",false) else ""
	editor.visible = not editing_id.is_empty()
	title.text = "NAME YOUR EXISTING DRIVER" if editor.visible else "SELECT YOUR SAVED DRIVER"
	name_input.text = entry.name if editor.visible else ""
	choose_portrait(int(entry.portrait_id))
	notice.text = "Name this driver to keep your existing progression and records." if editor.visible else "Confirm to continue as "+entry.name+"."

func create() -> void:
	editing_id = ""
	editor.show()
	title.text = "CREATE YOUR SAVED DRIVER"
	name_input.clear()
	choose_portrait(0)
	notice.text = "New drivers start with their own progression and records."
	name_input.grab_focus.call_deferred()

func choose_portrait(index: int) -> void:
	selected_portrait = index
	face.texture = SKIN.portrait(index)
	character_name.text = CHARACTERS.NAMES[index].to_upper()
	character_name.modulate = CHARACTERS.COLOURS[index].lightened(0.2)
	character_bio.text = CHARACTERS.BIOS[index]
	for i: int in range(portraits.size()): portraits[i].set_pressed_no_signal(i==index)

func confirm() -> void:
	if not visible: return
	var id: String = ""
	var error: Error = OK
	if editor.visible:
		if not race.profile_directory.valid_name(name_input.text.strip_edges()):
			notice.text = "Use 1 to 9 letters A to Z, without numbers or punctuation."
			return
		if not editing_id.is_empty():
			id = editing_id
			error = race.profile_directory.rename_legacy(id,name_input.text,selected_portrait)
		else:
			var result: Dictionary = race.profile_directory.create_profile(name_input.text,selected_portrait)
			error = result.error
			id = result.get("id","")
	else:
		if entries.is_empty(): return
		id = entries[picker.selected].id
	if error==OK: error = race.activate_profile(id)
	if error!=OK:
		notice.text = "That name already exists." if error==ERR_ALREADY_EXISTS else "Driver could not be saved or loaded: "+error_string(error)
		return
	hide()
	race.show_menu()
	race.menu_flow.show_step(0)

func go_back() -> void:
	if name_keyboard.visible:
		name_keyboard.close()
		return
	if not editing_id.is_empty():
		notice.text = "Confirm a name to retain this driver's existing save."
		return
	if editor.visible and not entries.is_empty(): preview(picker.selected)
	elif race.profile_selected:
		hide()
		race.show_menu()
	else: notice.text = "Select or create a driver to continue."

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
