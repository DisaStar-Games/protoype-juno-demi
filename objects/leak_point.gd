class_name LeakPoint
extends RepairPoint

## A pipe joint in the gas chamber. All of them look the same until the gas leak event
## picks one: it then hisses green gas and can be fixed with the wrench (hold E).

@onready var puff: CPUParticles3D = $Puff


func _ready() -> void:
	add_to_group("gas_leak_points")
	puff.emitting = false


func set_leaking(leaking: bool) -> void:
	puff.emitting = leaking
