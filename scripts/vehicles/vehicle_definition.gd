extends Resource
const HANDLING_VERSION: String = "classes-2-export-defaults"
@export var boost_recharge: float = 13.0
@export var boost_speed: float = 1.35
@export var boost_acceleration: float = 1.5
@export var recovery_immunity: float = 1.5
@export var boost_drain: float = 34.0
@export var recovery_speed: float = 1.0
@export var id: String = "buggy"
@export var top_speed: float = 14.3
@export var acceleration: float = 16.7
@export var braking: float = 22.0
@export var reverse_speed: float = 3.5
@export var grip: float = 3.2
@export var coast_grip: float = 4.8
@export var steering_low: float = 3.8
@export var steering_high: float = 2.0
@export var drag: float = 0.28
@export var tyre_effect_threshold: float = 1.0
@export var watercraft: bool = false
@export var collision_size: Vector3 = Vector3(0.85,0.4,0.54)
@export var collision_height: float = 0.27
@export var traffic_half_width: float = 0.45
@export var surface_speed: Dictionary = {}
@export var surface_grip: Dictionary = {}

func permits(surface: String, freestyle: bool) -> bool:
	return freestyle or (surface=="water" if watercraft else surface!="water")

func speed_factor(surface: String, freestyle: bool) -> float:
	if freestyle and watercraft and surface!="water": return 0.50
	if freestyle and not watercraft and surface=="water": return 0.55
	return float(surface_speed.get(surface,1.0))
