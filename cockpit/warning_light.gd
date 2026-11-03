class_name WarningLight
extends Node3D

## A dashboard warning lamp bound to one TrainState warning id. Dim when off,
## glowing and pulsing when on.

@export var warning_id: StringName = &"fuel"
@export var title := "FUEL"
@export var color := Color(1.0, 0.8, 0.1)

var is_on := false

var _on_material: StandardMaterial3D
var _off_material: StandardMaterial3D

@onready var lamp: MeshInstance3D = $Lamp
@onready var label: Label3D = $Title


func _ready() -> void:
	_off_material = StandardMaterial3D.new()
	_off_material.albedo_color = color * 0.25
	_off_material.roughness = 0.9

	_on_material = StandardMaterial3D.new()
	_on_material.albedo_color = color
	_on_material.emission_enabled = true
	_on_material.emission = color
	_on_material.emission_energy_multiplier = 2.5

	label.text = title
	TrainState.warning_changed.connect(_on_warning_changed)
	set_active(TrainState.is_warning(warning_id))


func _process(_delta: float) -> void:
	if is_on:
		_on_material.emission_energy_multiplier = 2.0 + sin(Time.get_ticks_msec() / 1000.0 * 8.0)


func set_active(active: bool) -> void:
	is_on = active
	lamp.material_override = _on_material if active else _off_material


func _on_warning_changed(id: StringName, active: bool) -> void:
	if id == warning_id:
		set_active(active)
