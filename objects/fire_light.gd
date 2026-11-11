@tool
class_name FireLight
extends OmniLight3D

## An omni light that flickers like a fire. Put this script on an OmniLight3D.
## It layers a slow swell, a fast flicker and the odd random pop on top of `base_energy`,
## and drifts the colour between a deep orange and a yellow-orange as it brightens.
## Runs in the editor too (@tool) so you can see it without playing.

## Average brightness.
@export var base_energy := 2.0
## How much the brightness varies (0 = steady, 1 = swings between dark and double).
@export_range(0.0, 1.0) var flicker_amount := 0.35
## How fast it flickers (1 = calm campfire, 3 = restless).
@export_range(0.1, 6.0) var flicker_speed := 1.0
## Colour at its dimmest and at its brightest.
@export var dim_color := Color(1.0, 0.35, 0.08)
@export var bright_color := Color(1.0, 0.7, 0.25)
## Also makes the light wobble a little in space, like flames licking around (in game only).
@export var wobble := 0.04

var _noise := FastNoiseLite.new()
var _time := 0.0
var _origin := Vector3.ZERO
var _pop := 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_time = randf() * 100.0 # so several fires do not flicker in sync
	_origin = position


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	# Slow swell + fast flicker, both from noise (-1..1).
	var slow := _noise.get_noise_1d(_time * 0.6)
	var fast := _noise.get_noise_1d(_time * 7.0 + 31.0)
	# Now and then a brief pop of brightness.
	if _pop <= 0.0 and randf() < delta * 0.6 * flicker_speed:
		_pop = 1.0
	_pop = maxf(_pop - delta * 5.0, 0.0)
	var level := 1.0 + flicker_amount * (0.65 * slow + 0.35 * fast) + 0.25 * flicker_amount * _pop
	level = maxf(level, 0.05)
	light_energy = base_energy * level
	light_color = dim_color.lerp(bright_color, clampf(inverse_lerp(0.6, 1.4, level), 0.0, 1.0))
	if wobble > 0.0 and not Engine.is_editor_hint(): # never fight you moving it in the editor
		position = _origin + Vector3(
			_noise.get_noise_1d(_time * 3.0 + 70.0),
			_noise.get_noise_1d(_time * 3.0 + 140.0) * 0.5,
			_noise.get_noise_1d(_time * 3.0 + 210.0)) * wobble
