extends Node3D
class_name PulsingTubes

## Gives every mesh below this node a slowly pulsing red/orange emissive material.

@export var base_color := Color(0.25, 0.02, 0.01)
@export var color_a := Color(1.0, 0.08, 0.02)   # red
@export var color_b := Color(1.0, 0.45, 0.05)   # orange
## Seconds per full pulse.
@export var pulse_period := 4.0
@export var energy_min := 0.4
@export var energy_max := 2.5

var _material := StandardMaterial3D.new()
var _time := 0.0


func _ready() -> void:
	_material.albedo_color = base_color
	_material.roughness = 0.5
	_material.emission_enabled = true
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _material
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


func _update() -> void:
	var t := 0.5 - 0.5 * cos(_time * TAU / maxf(pulse_period, 0.01))   # 0..1, smooth
	_material.emission = color_a.lerp(color_b, t)
	_material.emission_energy_multiplier = lerpf(energy_min, energy_max, t)
