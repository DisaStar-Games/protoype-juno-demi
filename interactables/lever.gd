class_name Lever
extends Interactable

## A stepped cockpit lever bound to a 0..1 TrainState value (throttle, brake).
## E steps it up, Shift+E steps it down. TrainState stays the single source of truth:
## the handle and label follow the value no matter who changed it (debug panel, events).

## Name of the TrainState property this lever controls; it needs a `<name>_changed` signal.
@export var property: StringName = &"throttle"
@export var title := "Lever"
## 4 steps = 0 / 25 / 50 / 75 / 100 %.
@export var steps := 4
## Handle tilt in degrees at 0 % (toward the player) and at 100 % (pushed away).
@export var angle_at_zero := 30.0
@export var angle_at_full := -30.0

var _tween: Tween

@onready var pivot: Node3D = $Pivot
@onready var label: Label3D = $Label3D


func _ready() -> void:
	TrainState.connect(String(property) + "_changed", _on_value_changed)
	_on_value_changed(_value(), true)


func get_prompt(_player: Node) -> String:
	return "%s up (now %d%%)    [Shift+E] down" % [title, roundi(_value() * 100.0)]


func interact(_player: Node) -> void:
	_step(1)


func interact_alt(_player: Node) -> void:
	_step(-1)


func _step(direction: int) -> void:
	var index := clampi(roundi(_value() * steps) + direction, 0, steps)
	TrainState.set(property, float(index) / steps)


func _value() -> float:
	return TrainState.get(property)


func _on_value_changed(value: float, instant := false) -> void:
	label.text = "%s %d%%" % [title.to_upper(), roundi(value * 100.0)]
	var target := deg_to_rad(lerpf(angle_at_zero, angle_at_full, value))
	if instant:
		pivot.rotation.x = target
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(pivot, "rotation:x", target, 0.12)
