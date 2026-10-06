@tool
extends Resource
# Catalogue identity stays separate from route sampling and physics.
@export var id: String = ""
@export var title: String = ""
@export var cup: String = ""
@export var order_in_cup: int = 0
@export var route: Resource
@export var environment: PackedScene
@export var preview: Texture2D
@export var eligible_classes: PackedStringArray = ["buggy"]
@export var target_lap_seconds: Vector2 = Vector2.ZERO
@export var description: String = ""
@export_enum("source", "bedroom") var presentation: String = "source"
