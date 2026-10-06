extends "res://tests/autopilot/probe_base.gd"
var race: Node3D
func _enter_tree() -> void:
 super._enter_tree()
 get_tree().node_added.connect(_isolate)
func _isolate(node: Node) -> void:
 if node.name == "Race" and node.get("profile") != null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
 if node.name == "Sequence" and node.get("hardware_input_isolated") != null: node.hardware_input_isolated = true
func _ready() -> void:
 await super._ready()
 await settle(4)
 var app: Node = get_tree().current_scene
 race = app.get_node("Race")
 app.get_node("Opening").queue_free()
 get_tree().paused = false
 for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
 race.controller.set_process_input(false)
 race.controller.set_physics_process(false)
 race.process_mode = Node.PROCESS_MODE_DISABLED
 race.hide()
 for layer: CanvasLayer in race.find_children("*","CanvasLayer",true,false): layer.hide()
 var stage: Node3D = Node3D.new()
 add_child(stage)
 var light: DirectionalLight3D = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-45,-40,0)
 light.light_energy = 1.5
 stage.add_child(light)
 var camera: Camera3D = Camera3D.new()
 stage.add_child(camera)
 camera.position = Vector3(2.1,1.5,2.1)
 camera.look_at(Vector3(0,0.35,0))
 camera.current = true
 var all_valid: bool = race.profile.read_only
 for id: String in preload("res://scripts/vehicles/imported_visual.gd").MODELS:
  race.race_mode = "freestyle"
  var success: bool = race.set_vehicle(id)
  race.garage.select(race,0)
  for control: Control in app.find_children("*","Control",true,false): control.hide()
  for layer: CanvasLayer in app.find_children("*","CanvasLayer",true,false): layer.hide()
  var visual: Node3D = race.player_car.visual.duplicate()
  stage.add_child(visual)
  var box: AABB = preload("res://scripts/vehicles/imported_visual.gd").bounds(visual)
  var envelope: Vector3 = race.player_car.tuning.collision_size
  var valid: bool = success and absf(box.position.y)<0.001 and box.size.x<=envelope.x+0.001 and box.size.z<=envelope.z+0.001
  all_valid = all_valid and valid
  report(id,{"valid":valid,"bounds":str(box),"meshes":visual.find_children("*","MeshInstance3D",true,false).size()})
  await settle(8)
  save_frame(id)
  camera.position = Vector3(-2.1,1.5,-2.1)
  camera.look_at(Vector3(0,0.35,0))
  await settle(3)
  save_frame(id+"_rear")
  camera.position = Vector3(2.1,1.5,2.1)
  camera.look_at(Vector3(0,0.35,0))
  visual.free()
 race.garage.preview_car = null
 stage.queue_free()
 await settle(8)
 report("passed",all_valid)
 finish()
