extends Node
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
var race: Node3D
var panel: Panel
var mask: ColorRect
var resolution: OptionButton
var fullscreen: CheckButton
var mute: CheckButton
var pixels: CheckButton
var reduced_effects: CheckButton
var notice: Label
var confirm: Button
var revert: Button
var display_timer: Timer
var previous_display: Dictionary = {}
var sizes: Array[Vector2i] = []

func setup(race_owner: Node3D) -> void:
	race = race_owner
	for bus_name: String in ["Music","Effects"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus_name)
			AudioServer.set_bus_send(index,"Master")
	race.music.bus = "Music"
	for player: AudioStreamPlayer in [race.engine_sound,race.skid_sound,race.engine_layer]: player.bus = "Effects"
	for player: AudioStreamPlayer in race.voices: player.bus = "Effects"
	apply_audio()
	race.get_node("Retro").visible = race.machine_settings.data.pixels
	var settings: Dictionary = race.machine_settings.data
	set_display(Vector2i(settings.width,settings.height),settings.fullscreen)
	mask = ColorRect.new()
	mask.size = race.menu.size
	mask.color = Color(0,0,0,0.65)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	race.menu.add_child(mask)
	mask.hide()
	panel = Panel.new()
	panel.name = "Setup"
	panel.position = Vector2(206,24)
	panel.size = Vector2(740,620)
	panel.theme = race.menu.theme
	panel.add_theme_stylebox_override("panel",SKIN.box(SKIN.INK,SKIN.BLUE,4))
	race.menu.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(24,20)
	column.size = Vector2(692,580)
	column.add_theme_constant_override("separation",7)
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = "(NOT) THE REAL THING / SETUP"
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_color_override("font_color",SKIN.GOLD)
	column.add_child(title)
	for field: String in ["master","music","effects"]:
		var row: HBoxContainer = HBoxContainer.new()
		column.add_child(row)
		var label: Label = Label.new()
		label.text = field.to_upper()+" VOLUME"
		label.custom_minimum_size.x = 240
		row.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.name = field
		slider.custom_minimum_size = Vector2(320,32)
		slider.max_value = 100
		slider.step = 1
		slider.value = settings[field]*100.0
		row.add_child(slider)
		var value: Label = Label.new()
		value.text = "%d%%" % slider.value
		row.add_child(value)
		slider.value_changed.connect(func(amount: float) -> void:
			race.machine_settings.data[field] = amount/100.0
			value.text = "%d%%" % amount
			apply_audio()
			race.save_preferences())
		slider.drag_ended.connect(func(_changed: bool) -> void: race.play_sound("menu"))
	mute = check(column,"MUTE ALL SOUND",settings.mute)
	mute.toggled.connect(set_mute)
	pixels = check(column,"PIXELATION FILTER  (P)",settings.pixels)
	pixels.toggled.connect(set_pixels)
	reduced_effects = check(column,"REDUCED EFFECTS / NO CAMERA SHAKE",settings.reduced_effects)
	reduced_effects.toggled.connect(func(value: bool) -> void:
		race.machine_settings.data.reduced_effects = value
		race.feedback.shake = 0.0
		race.feedback.shake_time = 0.0
		race.save_preferences())
	resolution = OptionButton.new()
	column.add_child(resolution)
	var monitor: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	for size: Vector2i in [Vector2i(960,640),Vector2i(1200,800),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		if size.x<=monitor.x and size.y<=monitor.y: sizes.append(size)
	var current: Vector2i = clamp_size(Vector2i(settings.width,settings.height))
	if current not in sizes: sizes.append(current)
	for size: Vector2i in sizes: resolution.add_item("WINDOW SIZE · %d X %d" % [size.x,size.y])
	resolution.select(sizes.find(current))
	fullscreen = check(column,"FULLSCREEN",settings.fullscreen)
	var apply: Button = Button.new()
	apply.text = "APPLY DISPLAY"
	column.add_child(apply)
	apply.pressed.connect(apply_display)
	notice = Label.new()
	notice.text = "Display changes revert after 15 seconds unless confirmed."
	if Engine.is_embedded_in_editor():
		apply.disabled = true
		resolution.disabled = true
		fullscreen.disabled = true
		notice.text = "Display changes require a standalone game window."
	notice.add_theme_font_size_override("font_size",12)
	column.add_child(notice)
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	confirm = Button.new()
	confirm.text = "KEEP DISPLAY"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm)
	confirm.pressed.connect(confirm_display)
	revert = Button.new()
	revert.text = "REVERT"
	revert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(revert)
	revert.pressed.connect(revert_display)
	confirm.disabled = true
	revert.disabled = true
	var controls: Button = Button.new()
	controls.text = "CONTROLS & CAMERA BINDINGS"
	column.add_child(controls)
	controls.pressed.connect(func() -> void:
		close()
		race.controls_setup.open())
	var done: Button = Button.new()
	var change_profile: Button = Button.new()
	change_profile.name = "ChangeProfile"
	change_profile.text = "CHANGE PROFILE"
	column.add_child(change_profile)
	change_profile.pressed.connect(func() -> void:
		close()
		race.open_profiles())
	done.text = "DONE"
	column.add_child(done)
	done.pressed.connect(close)
	display_timer = Timer.new()
	display_timer.one_shot = true
	display_timer.wait_time = 15
	add_child(display_timer)
	display_timer.timeout.connect(revert_display)
	race.controls_setup.launch.pressed.disconnect(race.controls_setup.open)
	race.controls_setup.launch.text = "SETUP"
	race.controls_setup.launch.pressed.connect(open)
	panel.hide()

func check(parent: Node, text: String, value: bool) -> CheckButton:
	var button: CheckButton = CheckButton.new()
	button.text = text
	button.button_pressed = value
	parent.add_child(button)
	return button

func apply_audio() -> void:
	var settings: Dictionary = race.machine_settings.data
	for field: String in ["master","music","effects"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(field.capitalize()),linear_to_db(maxf(settings[field],0.0001)))
	AudioServer.set_bus_mute(0,settings.mute or settings.master==0.0)
	for field: String in ["music","effects"]: AudioServer.set_bus_mute(AudioServer.get_bus_index(field.capitalize()),settings[field]==0.0)
	race.muted = settings.mute
	race.music.volume_db = race.MUSIC_VOLUME_DB
	race.engine_layer.volume_db = -36.0
	race.engine_sound.volume_db = -24.0
	race.skid_sound.volume_db = -29.0

func set_mute(value: bool) -> void:
	race.machine_settings.data.mute = value
	mute.set_pressed_no_signal(value)
	apply_audio()
	race.save_preferences()

func set_pixels(value: bool) -> void:
	race.machine_settings.data.pixels = value
	race.get_node("Retro").visible = value
	pixels.set_pressed_no_signal(value)
	race.save_preferences()

func clamp_size(size: Vector2i) -> Vector2i:
	var monitor: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	return Vector2i(clampi(size.x,640,maxi(640,monitor.x)),clampi(size.y,480,maxi(480,monitor.y)))

func set_display(size: Vector2i, full: bool) -> void:
	if Engine.is_embedded_in_editor(): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	if not full: DisplayServer.window_set_size(clamp_size(size))

func apply_display() -> void:
	if Engine.is_embedded_in_editor(): return
	var requested_size: Vector2i = sizes[resolution.selected]
	var requested_full: bool = fullscreen.button_pressed
	if not previous_display.is_empty(): revert_display()
	resolution.select(sizes.find(requested_size))
	fullscreen.set_pressed_no_signal(requested_full)
	previous_display = {"size":DisplayServer.window_get_size(),"mode":DisplayServer.window_get_mode()}
	set_display(requested_size,requested_full)
	confirm.disabled = false
	revert.disabled = false
	display_timer.start()
	confirm.grab_focus()

func confirm_display() -> void:
	if previous_display.is_empty(): return
	race.machine_settings.data.width = sizes[resolution.selected].x
	race.machine_settings.data.height = sizes[resolution.selected].y
	race.machine_settings.data.fullscreen = fullscreen.button_pressed
	previous_display.clear()
	display_timer.stop()
	confirm.disabled = true
	revert.disabled = true
	notice.text = "Display saved."
	race.save_preferences()
	resolution.grab_focus()

func revert_display() -> void:
	if previous_display.is_empty(): return
	DisplayServer.window_set_mode(previous_display.mode)
	if previous_display.mode==DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_size(previous_display.size)
	previous_display.clear()
	display_timer.stop()
	confirm.disabled = true
	revert.disabled = true
	fullscreen.set_pressed_no_signal(race.machine_settings.data.fullscreen)
	resolution.select(sizes.find(clamp_size(Vector2i(race.machine_settings.data.width,race.machine_settings.data.height))))
	notice.text = "Display reverted."
	resolution.grab_focus()

func open() -> void:
	if panel.visible: return
	race.controls_setup.suppress_focus(race.menu,panel)
	mask.show()
	mask.move_to_front()
	panel.show()
	panel.move_to_front()
	resolution.grab_focus()

func close() -> void:
	revert_display()
	panel.hide()
	mask.hide()
	for control: Control in race.controls_setup.focus_modes:
		if is_instance_valid(control): control.focus_mode = race.controls_setup.focus_modes[control]
	race.controls_setup.focus_modes.clear()
	race.controls_setup.launch.grab_focus()

func _process(_delta: float) -> void:
	if not previous_display.is_empty(): notice.text = "KEEP DISPLAY?  REVERTING IN %ds" % ceili(display_timer.time_left)

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
