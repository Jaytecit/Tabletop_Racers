extends RefCounted
# Paths keep course selection from loading the entire soundtrack into memory.
const TRACKS: Dictionary = {
	"town_square":"res://audio/music/menu_pulsing.mp3",
	"game_table":"res://audio/music/High Stakes Overdrive.mp3",
	"toys_r_you":"res://audio/music/Toybox Turbo.mp3",
	"toys_r_asleep":"res://audio/music/After Bedtime.mp3",
	"rusty_nuts_workshop":"res://audio/music/Redline Assembly.mp3",
	"moonlight_junk_heap":"res://audio/music/Scrapyard Pursuit.mp3",
	"firefly_bbq":"res://audio/music/Backyard Afterburner.mp3",
	"nighttime_noodles":"res://audio/music/Midnight Takeout.mp3",
	"mount_rainier":"res://audio/music/Summit Rush.mp3",
	"topspeed_oval":"res://audio/music/Maximum Velocity.mp3"
}
const WATER_MUSIC: String = "res://audio/music/Wake Velocity.mp3"

static func path_for_course(id: String) -> String:
	var catalog: Script = preload("res://scripts/tracks/content_catalog.gd")
	id = catalog.canonical_id(id)
	if catalog.CLASSIFICATION.get(id,{}).get("group","")=="WATER": return WATER_MUSIC
	return TRACKS.get(id,"")

static func for_course(id: String) -> AudioStream:
	var path: String = path_for_course(id)
	return load(path) as AudioStream if not path.is_empty() else null
