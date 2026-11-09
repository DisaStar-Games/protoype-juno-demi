class_name LeakPoint
extends RepairPoint

## A pipe joint in the gas chamber. All of them look the same until the gas leak event
## picks one: it then hisses green gas and can be fixed with the wrench (hold E).

## Loops while the pipe is leaking (until it is fixed).
@export var hiss_sound: AudioStream

var _hiss_player: AudioStreamPlayer3D

@onready var puff: CPUParticles3D = $Puff


func _ready() -> void:
	add_to_group("gas_leak_points")
	puff.emitting = false


func set_leaking(leaking: bool) -> void:
	puff.emitting = leaking
	if _hiss_player == null:
		_hiss_player = Sfx.loop_player(self, hiss_sound)
	Sfx.set_playing(_hiss_player, leaking)
