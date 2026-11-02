extends StaticBody3D

## Blockout furnace: coal pushes the progress bar up, idle time lets it fall.

@export var fill_per_coal := 50.0
@export var decay_per_second := 4.0
@export var max_progress := 100.0

var progress := 0.0

@onready var bar_pivot: Node3D = $ProgressBar/BarPivot
@onready var intake: Area3D = $Intake


func _ready() -> void:
	# Any coal thrown through the intake zone gets eaten and fuels the bar.
	intake.body_entered.connect(_on_intake_body_entered)


func _on_intake_body_entered(body: Node) -> void:
	if body.is_in_group("coal"):
		add_coal()
		body.queue_free()


## Fuels the furnace by one coal's worth of progress.
func add_coal() -> void:
	progress = min(progress + fill_per_coal, max_progress)


func _process(delta: float) -> void:
	if progress > 0.0:
		progress = max(progress - decay_per_second * delta, 0.0)

	# Bar grows from its left edge; never scale to exactly 0 (avoids zero-basis).
	var t := progress / max_progress
	bar_pivot.scale.x = max(t, 0.0001)
