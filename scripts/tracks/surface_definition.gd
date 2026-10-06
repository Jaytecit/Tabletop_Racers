@tool
extends Resource
@export var id: String = "felt"
@export var grip: float = 1.0
@export var drag: float = 1.0
@export var color: Color = Color("168f78")

static func presets() -> Dictionary:
	var result: Dictionary = {}
	for name: String in ["felt","wood","paper","fabric","ceramic","sand","puddle","water"]:
		var item: Resource = load("res://scripts/tracks/surface_definition.gd").new()
		item.id = name
		item.color = {"felt":Color("168f78"),"wood":Color("d3ac69"),"paper":Color("f4e8cb"),"fabric":Color("c37d63"),"ceramic":Color("f4e8cb"),"sand":Color("d3ac69"),"puddle":Color("4ba5c9"),"water":Color("4ba5c9")}[name]
		# Glazed plate offers modestly less lateral bite; existing surfaces stay neutral.
		if name == "ceramic":
			item.grip = 0.88
			item.drag = 0.95
		result[name] = item
	return result
