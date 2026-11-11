class_name LiftButton
extends Interactable

## A button that lifts the player to `destination` (a world position): the ride up to the pipe room
## and the rides back down. The player glides there with collisions off, so ceilings don't matter.
## Works even when the console is broken.

@export var destination := Vector3.ZERO
@export var travel_time := 1.4
## Played when the button is pressed.
@export var press_sound: AudioStream

var _busy := false


func get_prompt(_player: Node) -> String:
	return prompt_text


func interact(player: Node) -> void:
	var body := player as CharacterBody3D
	if _busy or body == null:
		return
	_busy = true
	Sfx.play_at(self, press_sound)
	var old_mask := body.collision_mask
	body.set_physics_process(false)
	body.velocity = Vector3.ZERO
	body.collision_mask = 0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(body, "global_position", destination, travel_time)
	await tween.finished
	body.collision_mask = old_mask
	body.velocity = Vector3.ZERO
	body.set_physics_process(true)
	_busy = false
