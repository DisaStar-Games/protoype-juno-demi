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
	Journey.selection_changed.connect(_refresh_label)
	Journey.phase_changed.connect(_refresh_label)
	_on_track_changed(TrainState.current_track, true)


func get_prompt(_player: Node) -> String:
	if console_broken():
		return "The console is broken!"
	if Journey.is_active():
		if Journey.phase != Journey.Phase.CHOICE:
			return "Track switch locked: no junction right now"
		var other: Dictionary = Journey.offers[1 - Journey.selected_index]
		return "Switch to %s  (now: %s)" % [RouteGraph.station_name(other["id"]), RouteGraph.station_name(Journey.selected_offer()["id"])]
	return "Switch to track %s  (now %s)" % [_other_track(), TrainState.current_track]


func interact(_player: Node) -> void:
	if refuse_if_broken():
		return
	if Journey.is_active():
		if not Journey.toggle_selection():
			GameState.post_message("There is no junction to switch right now.")
			return
		GameState.post_message("Track set to %s" % RouteGraph.station_name(Journey.selected_offer()["id"]))
		return
	TrainState.current_track = _other_track()
	GameState.post_message("Track switch set to %s" % TrainState.current_track)


func _other_track() -> StringName:
	return &"B" if TrainState.current_track == &"A" else &"A"


func _refresh_label() -> void:
	if Journey.phase == Journey.Phase.CHOICE:
		label.text = RouteGraph.station_name(Journey.selected_offer()["id"]).to_upper()
	else:
		label.text = "TRACK %s" % TrainState.current_track


func _on_track_changed(track: StringName, instant := false) -> void:
	_refresh_label()
	var target := deg_to_rad(angle_track_a if track == &"A" else angle_track_b)
	if instant:
		pivot.rotation.z = target
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(pivot, "rotation:z", target, 0.12)
