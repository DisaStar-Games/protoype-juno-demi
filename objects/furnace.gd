extends StaticBody3D

## Blockout furnace: coal adds to TrainState.fuel and the bar shows the fuel level.

@onready var bar_pivot: Node3D = $ProgressBar/BarPivot
@onready var intake: Area3D = $Intake


func _ready() -> void:
	# Any coal thrown through the intake zone gets eaten and fuels the train.
	intake.body_entered.connect(_on_intake_body_entered)
	TrainState.fuel_changed.connect(_on_fuel_changed)
	_on_fuel_changed(TrainState.fuel)


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
