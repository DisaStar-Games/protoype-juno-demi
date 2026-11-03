class_name BrakeReservoir
extends RepairPoint

## The brake fluid reservoir in the mechanical room. While the brake leak event is on, it
## drips and needs fluid: hold E with the brake fluid bottle to pour it in. A bar on the
## tank shows the fluid level (red when low).

@onready var drips: CPUParticles3D = $Drips
@onready var level_pivot: Node3D = $LevelPivot
@onready var level_fill: MeshInstance3D = $LevelPivot/Fill

var _fill_material := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("brake_reservoir")
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	level_fill.material_override = _fill_material
	drips.emitting = false
	TrainState.brake_fluid_changed.connect(_on_fluid_changed)
	_on_fluid_changed(TrainState.brake_fluid)


## Drips (leaking) or not.
func set_leaking(leaking: bool) -> void:
	drips.emitting = leaking


func _on_fluid_changed(fluid: float) -> void:
	var ratio := fluid / TrainState.max_brake_fluid
	level_pivot.scale.y = maxf(ratio, 0.0001) # never scale to exactly 0
	var low := 1.0 - clampf(ratio * 2.5, 0.0, 1.0)
	_fill_material.albedo_color = Color(0.35, 0.6, 1.0).lerp(Color(1.0, 0.25, 0.2), low)
