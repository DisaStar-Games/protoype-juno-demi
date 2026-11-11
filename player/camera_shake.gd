class_name CameraShake
extends Camera3D

## Subtle train rumble: wobbles the view in proportion to the train's speed, using the
## camera's own offsets and roll so it never fights the mouse look (which only turns X).

## Biggest sideways / vertical camera shift at top speed, in metres.
@export var max_offset := 0.012
## Biggest roll at top speed, in degrees.
@export var max_roll_degrees := 0.12
## Extra shake of a full-strength kick (a jump scare): metres and degrees.
@export var kick_offset := 0.05
@export var kick_roll_degrees := 2.5

var _kick := 0.0
var _kick_left := 0.0
var _kick_duration := 0.6


## A sudden hard shake that dies down over `duration` seconds (1 = full strength).
func kick(strength := 1.0, duration := 0.6) -> void:
	_kick = strength
	_kick_left = duration
	_kick_duration = maxf(duration, 0.01)


## Current kick strength, 0..1 (fades out linearly).
func current_kick() -> float:
	return _kick * (_kick_left / _kick_duration) if _kick_left > 0.0 else 0.0


func _process(delta: float) -> void:
	_kick_left = maxf(_kick_left - delta, 0.0)
	var kicking := current_kick()
	var strength := clampf(TrainState.world_speed() / TrainState.max_speed, 0.0, 1.0)
	var t := Time.get_ticks_msec() / 1000.0
	# Two out-of-step sine waves per axis read as irregular but stay smooth and bounded.
	h_offset = (max_offset * strength + kick_offset * kicking) * (sin(t * 31.0) + 0.6 * sin(t * 53.0 + 1.7)) / 1.6
	v_offset = (max_offset * strength + kick_offset * kicking) * (sin(t * 27.0 + 0.8) + 0.6 * sin(t * 61.0 + 2.9)) / 1.6
	rotation_degrees.z = (max_roll_degrees * strength + kick_roll_degrees * kicking) * sin(t * 19.0 + 0.3)
