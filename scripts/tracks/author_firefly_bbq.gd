@tool
extends RefCounted
static func build() -> Dictionary:
	return load("res://scripts/tracks/author_tabletop.gd").build("firefly_bbq")
