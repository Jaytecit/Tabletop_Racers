@tool
extends RefCounted
static func build() -> Dictionary:
	return load("res://scripts/tracks/author_tabletop.gd").build("toys_r_asleep")
