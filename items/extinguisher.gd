class_name Extinguisher
extends ItemPickup

## Fire extinguisher. Hold LMB to spray water in the direction you look; fires within
## reach of the spray lose health (see FireSpot). It cannot be thrown.

@export var spray_range := 5.0
## Fire health removed per second while the spray hits.
@export var extinguish_rate := 40.0

## Water used per second of spraying, taken from the pockets (0 = free).
@export var water_per_second := 0.0

var spraying := false
var _water_used := 0.0

@onready var spray: CPUParticles3D = $Spray


func _ready() -> void:
	super()
	spray.emitting = false


## Called by HeldItem every physics frame while LMB is held.
func use_held(delta: float, origin: Vector3, direction: Vector3) -> void:
	if water_per_second > 0.0:
		_water_used += water_per_second * delta
		while _water_used >= 1.0:
			_water_used -= 1.0
			if not Inventory.remove(&"water", 1):
				_water_used = 0.0
				stop_use()
				GameState.post_message("Out of water! Fill up at the barrel.")
				return
		if Inventory.count(&"water") <= 0 and _water_used <= 0.0:
			stop_use()
			return
	spraying = true
	spray.emitting = true
	var end := origin + direction * spray_range
	for fire in get_tree().get_nodes_in_group("fire"):
		if not fire.burning:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(fire.global_position, origin, end)
		if closest.distance_to(fire.global_position) <= fire.radius:
			fire.extinguish(extinguish_rate * delta)


## Called by HeldItem when LMB is released or the item leaves the hand.
func stop_use() -> void:
	spraying = false
	spray.emitting = false
