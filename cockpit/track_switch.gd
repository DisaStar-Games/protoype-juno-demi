class_name TrackSwitch
extends Interactable

## Track switch lever (A / B). Bound to TrainState.current_track; the real use (picking
## the correct branch at a split) comes with the Milestone 6 track-split event.

@export var angle_track_a := 25.0
@export var angle_track_b := -25.0

var _tween: Tween

@onready var pivot: Node3D = $Pivot
@onready var label: Label3D = $Title


func _ready() -> void:
	TrainState.track_changed.connect(_on_track_changed)
	_on_track_changed(TrainState.current_track, true)


func get_prompt(_player: Node) -> String:
	return "Switch to track %s  (now %s)" % [_other_track(), TrainState.current_track]


func interact(_player: Node) -> void:
	TrainState.current_track = _other_track()
	GameState.post_message("Track switch set to %s" % TrainState.current_track)


func _other_track() -> StringName:
	return &"B" if TrainState.current_track == &"A" else &"A"


func _on_track_changed(track: StringName, instant := false) -> void:
	label.text = "TRACK %s" % track
	var target := deg_to_rad(angle_track_a if track == &"A" else angle_track_b)
	if instant:
		pivot.rotation.z = target
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(pivot, "rotation:z", target, 0.12)
