extends StaticBody3D

## Blockout furnace: coal adds to TrainState.fuel and the top bar shows the fuel level.
## The lower bar shows its temperature (rises with full throttle and boost); at the top it
## catches fire, see events/furnace_fire_event.gd.

@onready var bar_pivot: Node3D = $ProgressBar/BarPivot
@onready var intake: Area3D = $Intake
@onready var temp_pivot: Node3D = $TempBar/TempPivot
@onready var temp_fill: MeshInstance3D = $TempBar/TempPivot/TempFill

var _temp_material := StandardMaterial3D.new()


func _ready() -> void:
	# Any coal thrown through the intake zone gets eaten and fuels the train.
	add_to_group("furnace")
	intake.body_entered.connect(_on_intake_body_entered)
	TrainState.fuel_changed.connect(_on_fuel_changed)
	_on_fuel_changed(TrainState.fuel)

	_temp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	temp_fill.material_override = _temp_material
	TrainState.furnace_temp_changed.connect(_on_temp_changed)
	_on_temp_changed(TrainState.furnace_temp)


func _on_intake_body_entered(body: Node) -> void:
	if body is ItemPickup and body.item_id == &"coal":
		add_coal()
		body.queue_free()


## Fuels the train by one coal's worth.
func add_coal() -> void:
	TrainState.add_fuel(TrainState.fuel_per_coal)


func _on_fuel_changed(fuel: float) -> void:
	# Bar grows from its left edge; never scale to exactly 0 (avoids a zero basis).
	bar_pivot.scale.x = maxf(fuel / TrainState.max_fuel, 0.0001)


## The temperature bar grows and goes from green through yellow to red.
func _on_temp_changed(temp: float) -> void:
	var ratio := temp / TrainState.max_furnace_temp
	temp_pivot.scale.x = maxf(ratio, 0.0001)
	_temp_material.albedo_color = Gauge.heat_color(ratio)
