extends "res://tests/probes/race_quality_ai_verification.gd"
func inspect_after_race() -> void:
 for car: CharacterBody3D in race.cars:
  check(car.crashes==0 and car.ai_driver.recoveries==0 and race.session.progress.records[car.player].penalty==0.0,"clean_imported_"+str(car.player))
 race.show_menu()
 await settle(8)
var draining: bool = false
func finish() -> void:
 if draining: return
 draining = true
 call_deferred("drain_then_finish")
func drain_then_finish() -> void:
 var app: Node = get_tree().current_scene
 if is_instance_valid(app): app.queue_free()
 race = null
 await settle(8)
 super.finish()
