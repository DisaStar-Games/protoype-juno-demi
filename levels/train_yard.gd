extends Node3D

## Blockout of the train yard from the level design sketch: the train on its track, the boiler
## house with its railed deck, the pump house with the big pipe, a railed walkway, the yard with
## containers, rock piles and the dark cliffs. It starts in an overview camera that looks like the
## sketch (from the south-west); F4 switches to walking around in first person.
## Events, bandits and the delivery timer are switched off here (the autoloads are shared).

var _first_person := false
var _old_random := true
var _old_idle := true

@onready var iso_camera: Camera3D = $IsoCamera
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	_old_random = EventManager.random_enabled
	_old_idle = EventManager.idle_raid_enabled
	EventManager.random_enabled = false
	EventManager.idle_raid_enabled = false
	GameState.time_left = 99999.0
	_set_first_person(false)


func _exit_tree() -> void:
	EventManager.random_enabled = _old_random
	EventManager.idle_raid_enabled = _old_idle
	GameState.reset()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		_set_first_person(not _first_person)


func _set_first_person(on: bool) -> void:
	_first_person = on
	if on:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		iso_camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
