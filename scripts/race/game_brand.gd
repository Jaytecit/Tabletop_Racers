extends RefCounted
const NAME: String = "(not) THE REAL THING"
const VERSION: String = "2.22.23"
const TAGLINE: String = "AN HOMAGE TO CLASSIC MINIATURE RACING"
const LOGO_PATH: String = "res://assets/brand/real_thing_logo.png"

static func logo_texture() -> AtlasTexture:
	var source: Texture2D = load(LOGO_PATH)
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = source
	texture.region = source.get_image().get_used_rect()
	texture.filter_clip = true
	return texture

static func tabletop_background() -> AtlasTexture:
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = load("res://assets/brand/real_thing_poster.png")
	# Frame the kitchen and toy racers below the poster titles and above its badges.
	texture.region = Rect2(0,405,848,575)
	texture.filter_clip = true
	return texture
