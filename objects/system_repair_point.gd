class_name SystemRepairPoint
extends RepairPoint

## The repair panel of a train system. Only the console is left (the furnace, coolant tank and pipes
## break through their own events). While the console is damaged (a collision, bandits) the
## panel smokes and its lamp is red; hold E on it to repair it.

@export var system_id: StringName = &"furnace"
@export var title := "FURNACE"

var _lamp_material := StandardMaterial3D.new()

@onready var lamp: MeshInstance3D = $Lamp
@onready var smoke: CPUParticles3D = $Smoke
@onready var label: Label3D = $Title


func _ready() -> void:
	add_to_group("system_repair_points")
	label.text = title
	action_text = "Repair the %s" % title.to_lower()
	_lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_material.emission_enabled = true
	lamp.material_override = _lamp_material
	repaired.connect(_on_repaired)
	TrainState.system_damage_changed.connect(_on_damage_changed)
	_sync()


func _on_damage_changed(id: StringName, _damaged: bool) -> void:
	if id == system_id:
		_sync()


func _sync() -> void:
	var damaged: bool = TrainState.is_system_damaged(system_id)
	needs_repair = damaged
	smoke.emitting = damaged
	var color := Color(1.0, 0.15, 0.1) if damaged else Color(0.2, 1.0, 0.35)
	_lamp_material.albedo_color = color
	_lamp_material.emission = color
	_lamp_material.emission_energy_multiplier = 2.5
	if damaged:
		ItemPickup.ensure_available(get_tree(), &"wrench") # never leave the train unrepairable


func _on_repaired() -> void:
	TrainState.repair_system(system_id)
	var left: int = TrainState.damaged_system_count()
	if left == 0:
		GameState.post_message("%s repaired. The controls work again!" % title.capitalize())
	else:
		GameState.post_message("%s repaired. %d system%s still damaged." % [title.capitalize(), left, "" if left == 1 else "s"])
