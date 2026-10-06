@tool
extends Resource
@export var id: String = "game_table"
@export var sections: Array[Resource] = []
@export var start_station: float = 1.0
@export var gate_count: int = 8
@export var revision: int = 2
# Imported courses supply their own visible road, edges and physical support.
@export var imported_surface: bool = false
