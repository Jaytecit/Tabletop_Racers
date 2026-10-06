extends Node
# Cosmetic slideshow; the selected racing vehicle is never changed.
const INTERVAL: float = 5.0
const FADE_SECONDS: float = 0.65
var active: bool = false
var index: int = 0
var elapsed: float = 0.0
var fading: bool = false
var fade_elapsed: float = 0.0
var image: TextureRect
var incoming: TextureRect
var artwork: Array[Texture2D] = []

func setup(target: TextureRect, textures: Array[Texture2D]) -> void:
	image = target
	artwork = textures
	incoming = TextureRect.new()
	incoming.name = "IncomingVehicle"
	incoming.expand_mode = image.expand_mode
	incoming.stretch_mode = image.stretch_mode
	incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.add_child(incoming)
	incoming.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	incoming.hide()

func set_active(value: bool) -> void:
	active = value
	if not active: reset_transition()

func reset_transition() -> void:
	elapsed = 0.0
	fade_elapsed = 0.0
	fading = false
	image.self_modulate.a = 1.0
	incoming.hide()

func _process(delta: float) -> void:
	if not active or not image.is_visible_in_tree():
		reset_transition()
		return
	elapsed += delta
	if fading:
		fade_elapsed += delta
		var blend: float = smoothstep(0.0,FADE_SECONDS,fade_elapsed)
		image.self_modulate.a = 1.0-blend
		incoming.self_modulate.a = blend
		if fade_elapsed>=FADE_SECONDS:
			index = (index+1)%artwork.size()
			image.texture = artwork[index]
			image.self_modulate.a = 1.0
			incoming.hide()
			fading = false
	if elapsed>=INTERVAL and not fading:
		elapsed = fmod(elapsed,INTERVAL)
		fade_elapsed = 0.0
		fading = true
		incoming.texture = artwork[(index+1)%artwork.size()]
		incoming.self_modulate.a = 0.0
		incoming.show()
