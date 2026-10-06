extends Control
## Approved blended film; shared audio continues into profile and menu screens.
signal finished

const BEAT: float = 60.0 / 150.0
const FIRST_BEAT: float = 3.6 + 0.025
# Frame-aligned cues match the approved 30 fps edit.
const LOGO_TIME: float = 176.433333333
const NOT_TIME: float = LOGO_TIME + 4.0 * BEAT
const PROMPT_TIME: float = LOGO_TIME + 8.0 * BEAT
const STUDIO_END: float = 4.4
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const BRAND: Script = preload("res://scripts/race/game_brand.gd")
const VIDEO: VideoStream = preload("res://assets/video/opening/theme-opening.ogv")
const MAIN_LOGO: Texture2D = preload("res://assets/video/opening/logo_main.png")
const IMPACT: AudioStreamWAV = preload("res://audio/sfx/opening_thud.wav")

var race: Node3D
var music: AudioStreamPlayer
var video: VideoStreamPlayer
var main_logo: Texture2D
var full_logo: Texture2D
var font: Font
var stamp_font: SystemFont
var impact: AudioStreamPlayer
var skip_button: Button
var start_button: Button
var elapsed: float = 0.0
var timeline_offset: float = 0.0
var logo_hit_time: float = -1.0
var not_hit_time: float = -1.0
var impact_count: int = 0
var video_sync_corrections: int = 0
var leaving: bool = false
var fade: float = 0.0
var previous_pause: bool = false
var previous_music_mode: ProcessMode
var previous_hud_visible: bool = true
var original_music_volume: float = -22.0
var title_music_duck: float = 0.0
var hardware_input_isolated: bool = false
var _restored: bool = false
var _start_pad_held: bool = false
var _start_pad_device: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	video = VideoStreamPlayer.new()
	video.name = "Montage"
	video.stream = VIDEO
	video.volume_db = -80.0
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.hide()
	add_child(video)
	main_logo = MAIN_LOGO
	full_logo = load(BRAND.LOGO_PATH)
	font = load("res://assets/arcade/arcade_font.fnt")
	stamp_font = SystemFont.new()
	stamp_font.font_names = PackedStringArray(["Arial"])
	stamp_font.font_weight = 900
	stamp_font.font_italic = true
	music = race.music
	original_music_volume = music.volume_db
	previous_music_mode = music.process_mode
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	previous_pause = get_tree().paused
	previous_hud_visible = race.get_node("HUD").visible
	race.get_node("HUD").hide()
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	get_tree().paused = true
	impact = AudioStreamPlayer.new()
	impact.stream = IMPACT
	impact.bus = "Effects"
	add_child(impact)
	skip_button = _button("Skip", "SKIP  /  ESC", skip_to_title)
	start_button = _button("Start", "PRESS START  /  ENTER", enter_menu)
	start_button.hide()
	skip_button.hide()
	resized.connect(_layout_buttons)
	Input.joy_connection_changed.connect(_pad_connection_changed)
	_layout_buttons()
	music.stream = race.OPENING_MUSIC
	music.play()
	# The film uses external audio, so its native embedded-audio delay is unwanted.
	# Playback snapshots this setting; restore it immediately for other videos.
	var compensation: Variant = ProjectSettings.get_setting("audio/video/video_delay_compensation_ms")
	ProjectSettings.set_setting("audio/video/video_delay_compensation_ms",0)
	video.play()
	ProjectSettings.set_setting("audio/video/video_delay_compensation_ms",compensation)

func _button(node_name: String, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.theme = SKIN.theme()
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", SKIN.box(SKIN.PURPLE, SKIN.GOLD, 2))
	button.pressed.connect(action)
	add_child(button)
	return button

func _layout_buttons() -> void:
	var factor: float = minf(size.x / 1200.0, size.y / 800.0)
	var origin: Vector2 = (size - Vector2(1200, 800) * factor) * 0.5
	skip_button.position = origin + Vector2(930, 745) * factor
	skip_button.size = Vector2(240, 38)
	skip_button.scale = Vector2.ONE * factor
	start_button.position = origin + Vector2(350, 610) * factor
	start_button.size = Vector2(500, 60)
	start_button.scale = Vector2.ONE * factor

func _audio_clock() -> float:
	return maxf(0.0, music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

func _process(delta: float) -> void:
	if logo_hit_time < 0.0:
		var clock: float = _audio_clock()
		elapsed = maxf(elapsed, clock + timeline_offset)
		# The native decoder advances on frame delta; audio advances on mixed samples.
		# Correct accumulated drift without seeking or restarting the audible song.
		if elapsed < LOGO_TIME and is_zero_approx(timeline_offset) and video.is_playing() and absf(video.stream_position-clock)>0.25:
			video.stream_position = clock + 0.15
			video_sync_corrections += 1
	else:
		# Title animation stays monotonic after the one-shot mix hands off to menu music.
		elapsed += delta
	if elapsed >= STUDIO_END and elapsed < LOGO_TIME and not leaving:
		skip_button.show()
	if elapsed >= LOGO_TIME and logo_hit_time < 0.0:
		video.stop()
		logo_hit_time = elapsed
		skip_button.hide()
	if elapsed >= NOT_TIME and not_hit_time < 0.0:
		not_hit_time = elapsed
		_play_impact(true, true)
		impact_count += 1
	if elapsed >= PROMPT_TIME and not start_button.visible and not leaving:
		start_button.show()
		skip_button.hide()
		start_button.grab_focus()
	if start_button.visible:
		start_button.modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * cos((elapsed - FIRST_BEAT) * TAU / (BEAT * 2.0)))
	title_music_duck = maxf(0.0, title_music_duck - delta)
	music.volume_db = original_music_volume - 3.0 * minf(title_music_duck / 0.16, 1.0)
	if leaving:
		fade = minf(1.0, fade + delta / 0.35)
		if fade >= 1.0 and not _start_pad_held and not Input.is_action_pressed("ui_accept") and not Input.is_action_pressed("start_race"):
			_restore_menu()
			finished.emit()
			get_parent().queue_free()
	queue_redraw()

func _play_impact(heavy: bool, duck_music: bool = false) -> void:
	impact.pitch_scale = 0.85 if heavy else 1.5
	impact.volume_db = -7.0 if heavy else -15.0
	if not race.muted: impact.play()
	if duck_music: title_music_duck = 0.3

func skip_to_title() -> void:
	if elapsed < STUDIO_END or leaving or elapsed >= LOGO_TIME: return
	# Skip video only. The song keeps its position; land the logo on its next beat.
	var clock: float = _audio_clock()
	var next_beat: float = FIRST_BEAT + ceilf((clock - FIRST_BEAT) / BEAT) * BEAT
	timeline_offset = LOGO_TIME - next_beat
	skip_button.hide()

func enter_menu() -> void:
	if leaving or elapsed < PROMPT_TIME: return
	leaving = true
	start_button.disabled = true
	skip_button.disabled = true

func _input(event: InputEvent) -> void:
	if hardware_input_isolated and not event is InputEventAction and not event.has_meta("opening_test_input"): return
	if event is InputEventKey and event.echo: return
	if elapsed < STUDIO_END:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("start_race") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
			get_viewport().set_input_as_handled()
		return
	var pad_start: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START
	if pad_start:
		_start_pad_device = event.device
		_start_pad_held = event.pressed
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("start_race") or (pad_start and event.pressed):
		if elapsed >= PROMPT_TIME: enter_menu()
		elif elapsed < LOGO_TIME: skip_to_title()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		skip_to_title()
		get_viewport().set_input_as_handled()

func _pad_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _start_pad_device: _start_pad_held = false

func _restore_menu() -> void:
	if _restored: return
	_restored = true
	music.volume_db = original_music_volume
	music.process_mode = previous_music_mode
	race.get_node("HUD").visible = previous_hud_visible
	get_tree().paused = previous_pause
	# No show_menu(), stream reassignment, seek, or play call here.
	race.focus_start.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(video): video.stop()
	if is_instance_valid(music) and is_instance_valid(race): _restore_menu()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("090e1c"))
	var factor: float = minf(size.x / 1200.0, size.y / 800.0)
	var origin: Vector2 = (size - Vector2(1200, 800) * factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	if elapsed < LOGO_TIME:
		var texture: Texture2D = video.get_video_texture()
		if texture != null:
			draw_texture_rect(texture, Rect2(0, 62, 1200, 675), false)
	else: _draw_title()
	if leaving: draw_rect(Rect2(0, 0, 1200, 800), Color(0.035, 0.055, 0.11, fade))

func _draw_title() -> void:
	var t: float = elapsed - LOGO_TIME
	var hit: float = elapsed - NOT_TIME
	var centre: Vector2 = Vector2(600, 385)
	# Slow radial light and a restrained burst echo the existing winged arcade badge.
	for i: int in range(32):
		var angle: float = float(i) * TAU / 32.0 + t * 0.012
		var a: Vector2 = centre + Vector2.from_angle(angle) * 100.0
		var b: Vector2 = centre + Vector2.from_angle(angle - 0.025) * 950.0
		var c: Vector2 = centre + Vector2.from_angle(angle + 0.025) * 950.0
		draw_colored_polygon(PackedVector2Array([a, b, c]), Color(0.12, 0.28, 0.45, 0.20))
	var burst_age: float = hit if hit >= 0.0 else t
	if burst_age < 0.65:
		for i: int in range(24):
			var angle: float = float(i) * TAU / 24.0
			var radius: float = 150.0 + burst_age * 760.0
			var point: Vector2 = centre + Vector2.from_angle(angle) * radius
			var colour: Color = SKIN.GOLD if i % 2 == 0 else SKIN.BLUE
			colour.a = 1.0 - burst_age / 0.65
			draw_line(point, point + Vector2.from_angle(angle) * 55.0, colour, 4.0)
	var zoom: float = 1.0 + 0.8 * exp(-t * 13.0) + 0.07 * sin(t * 28.0) * exp(-t * 8.0)
	var shake: Vector2 = Vector2.ZERO
	if burst_age < 0.35:
		shake = Vector2(sin(burst_age * 65.0) * 7.0, cos(burst_age * 80.0) * 10.0) * exp(-burst_age * 10.0)
	var dimensions: Vector2 = Vector2(1060, 1060.0 / 3.0) * zoom
	var rect: Rect2 = Rect2(centre - dimensions * 0.5 + shake, dimensions)
	draw_texture_rect(full_logo if hit >= 0.0 else main_logo, rect, false)
	if t < 0.18:
		draw_rect(Rect2(0, 0, 1200, 800), Color(1.0, 0.95, 0.8, 0.18 * exp(-t * 25.0)))
	# The late qualifier drops in over the badge; the exact original logo resolves at impact.
	if hit < 0.0 and hit > -0.30:
		var p: float = 1.0 + hit / 0.30
		var pos: Vector2 = Vector2(130, lerpf(-140.0, 325.0, p * p))
		draw_string_outline(stamp_font, pos, "(not)", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, 9, Color.BLACK)
		draw_string(stamp_font, pos, "(not)", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, SKIN.GOLD)
	if t > 0.5:
		var tagline: String = BRAND.TAGLINE
		var width: float = font.get_string_size(tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(600 - width * 0.5, 570), tagline, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SKIN.PAPER)
