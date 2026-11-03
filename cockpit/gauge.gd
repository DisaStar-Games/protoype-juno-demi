class_name Gauge
extends Node3D

## One dashboard readout: a title, a bar that fills 0..1 and a value text.
## Set `show_bar` off for text-only readouts (the delivery timer).

@export var title := "GAUGE"
@export var fill_color := Color(0.3, 0.8, 1.0)
@export var show_bar := true

var _fill_material := StandardMaterial3D.new()

@onready var bar: MeshInstance3D = $Bar
@onready var bar_pivot: Node3D = $BarPivot
@onready var title_label: Label3D = $Title
@onready var value_label: Label3D = $Value


func _ready() -> void:
	title_label.text = title
	bar.visible = show_bar
	bar_pivot.visible = show_bar
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.albedo_color = fill_color
	$BarPivot/Fill.material_override = _fill_material
	if not show_bar:
		# Without a bar the value text moves up to fill the gauge.
		value_label.position.y = 0.0


## `ratio` fills the bar (0..1), `text` is shown under the title.
func set_value(ratio: float, text: String) -> void:
	# Never scale to exactly 0 (avoids a zero basis).
	bar_pivot.scale.x = maxf(clampf(ratio, 0.0, 1.0), 0.0001)
	value_label.text = text


func set_fill_color(color: Color) -> void:
	_fill_material.albedo_color = color


## Green when cool, yellow when warm, red when hot (0..1).
static func heat_color(ratio: float) -> Color:
	var green := Color(0.35, 0.9, 0.4)
	var yellow := Color(1.0, 0.85, 0.2)
	var red := Color(1.0, 0.25, 0.15)
	if ratio < 0.5:
		return green.lerp(yellow, ratio * 2.0)
	return yellow.lerp(red, (ratio - 0.5) * 2.0)
