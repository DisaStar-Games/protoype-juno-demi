class_name Gauge
extends Node3D

## One dashboard readout: a title, a bar that fills 0..1 and a value text.
## Set `show_bar` off for text-only readouts (the delivery timer).

@export var title := "GAUGE"
@export var fill_color := Color(0.3, 0.8, 1.0)
@export var show_bar := true

@onready var bar: MeshInstance3D = $Bar
@onready var bar_pivot: Node3D = $BarPivot
@onready var title_label: Label3D = $Title
@onready var value_label: Label3D = $Value


func _ready() -> void:
	title_label.text = title
	bar.visible = show_bar
	bar_pivot.visible = show_bar
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = fill_color
	$BarPivot/Fill.material_override = material
	if not show_bar:
		# Without a bar the value text moves up to fill the gauge.
		value_label.position.y = 0.0


## `ratio` fills the bar (0..1), `text` is shown under the title.
func set_value(ratio: float, text: String) -> void:
	# Never scale to exactly 0 (avoids a zero basis).
	bar_pivot.scale.x = maxf(clampf(ratio, 0.0, 1.0), 0.0001)
	value_label.text = text
