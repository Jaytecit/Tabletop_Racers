extends Control
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const KEYS: Array[String] = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","DELETE","CLEAR","DONE","CANCEL"]
var owner_menu: Control
var draft: String = ""
var display: Label
var hint: Label
var keys: Array[Button] = []

func _ready() -> void:
	name = "GamepadNameKeyboard"
	size = Vector2(1200,800)
	theme = SKIN.theme()
	var shade: ColorRect = ColorRect.new()
	shade.size = size
	shade.color = Color(0.02,0.04,0.14,0.92)
	add_child(shade)
	var panel: Panel = Panel.new()
	panel.position = Vector2(210,140)
	panel.size = Vector2(780,520)
	panel.add_theme_stylebox_override("panel",SKIN.box(SKIN.PURPLE,SKIN.BLUE,3))
	add_child(panel)
	SKIN.label(panel,"Title","ENTER DRIVER NAME",Vector2(24,20),Vector2(730,32),24,SKIN.GOLD)
	display = SKIN.label(panel,"Draft","",Vector2(24,68),Vector2(730,42),28)
	var grid: GridContainer = GridContainer.new()
	grid.position = Vector2(24,132)
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	panel.add_child(grid)
	for key: String in KEYS:
		var button: Button = Button.new()
		button.text = key
		button.custom_minimum_size = Vector2(115,52)
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(select_key.bind(key))
		grid.add_child(button)
		keys.append(button)
	# Explicit neighbours trap controller/Tab focus inside the modal.
	for i: int in range(keys.size()):
		var row: int = i/6
		var col: int = i%6
		keys[i].focus_neighbor_left = keys[i].get_path_to(keys[row*6+(col+5)%6])
		keys[i].focus_neighbor_right = keys[i].get_path_to(keys[row*6+(col+1)%6])
		keys[i].focus_neighbor_top = keys[i].get_path_to(keys[((row+4)%5)*6+col])
		keys[i].focus_neighbor_bottom = keys[i].get_path_to(keys[((row+1)%5)*6+col])
		keys[i].focus_previous = keys[i].get_path_to(keys[(i+29)%30])
		keys[i].focus_next = keys[i].get_path_to(keys[(i+1)%30])
	hint = SKIN.label(panel,"Help","",Vector2(24,442),Vector2(730,58),14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hide()

func open(menu: Control) -> void:
	owner_menu = menu
	draft = menu.name_input.text
	refresh()
	show()
	keys[0].grab_focus()

func refresh() -> void:
	display.text = draft if not draft.is_empty() else "ENTER A NAME"
	var select_button: String = owner_menu.race.controls_setup.select_name()
	hint.text = "D-PAD / LEFT STICK: MOVE   %s: SELECT   B: CANCEL\n1 TO 9 LETTERS / %d OF 9"%[select_button,draft.length()]

func select_key(key: String) -> void:
	match key:
		"DELETE": draft = draft.left(maxi(draft.length()-1,0))
		"CLEAR": draft = ""
		"DONE":
			if not owner_menu.race.profile_directory.valid_name(draft):
				hint.text = "ENTER 1 TO 9 LETTERS BEFORE CHOOSING DONE."
				return
			owner_menu.name_input.text = draft
			close()
			return
		"CANCEL":
			close()
			return
		_:
			if draft.length()<9: draft += key
	refresh()

func close() -> void:
	hide()
	if is_instance_valid(owner_menu) and owner_menu.visible:
		owner_menu.name_input.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
