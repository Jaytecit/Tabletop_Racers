@tool
extends RefCounted
static func build() -> Dictionary:
	return load("res://scripts/tracks/author_tabletop.gd").build("rusty_nuts_workshop")
