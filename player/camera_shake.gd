class_name CameraShake
extends Camera3D

## Subtle train rumble: wobbles the view in proportion to the train's speed, using the
## camera's own offsets and roll so it never fights the mouse look (which only turns X).

## Biggest sideways / vertical camera shift at top speed, in metres.
@export var max_offset := 0.012
## Biggest roll at top speed, in degrees.
@export var max_roll_degrees := 0.12


func _process(_delta: float) -> void:
	var strength := clampf(TrainState.world_speed() / TrainState.max_speed, 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	# Two out-of-step sine waves per axis read as irregular but stay smooth and bounded.
	h_offset = max_offset * strength * (sin(t * 31.0) + 0.6 * sin(t * 53.0 + 1.7)) / 1.6
	v_offset = max_offset * strength * (sin(t * 27.0 + 0.8) + 0.6 * sin(t * 61.0 + 2.9)) / 1.6
	rotation_degrees.z = max_roll_degrees * strength * sin(t * 19.0 + 0.3)
