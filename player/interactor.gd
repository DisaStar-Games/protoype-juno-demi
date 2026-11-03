class_name Interactor
extends RayCast3D

## Looks along the camera, finds the Interactable under the crosshair, and drives
## press / hold interaction on it. Attached to the camera's InteractRay.

## Text for the HUD prompt, or "" when nothing is usable.
signal prompt_changed(text: String)
## 0..1 while holding E on a hold_time target; 0 otherwise.
signal hold_progress_changed(progress: float)

## Ignore E while the cursor is free (Esc). Off only for headless tests.
@export var require_captured_mouse := true

var target: Object = null
var _prompt := ""
var _hold := 0.0
var _hold_done := false

@onready var player: Node = owner


func _ready() -> void:
	# Our own capsule must never block the ray when looking down.
	add_exception(player)


func _process(delta: float) -> void:
	var found := _find_target()
	if found != target:
		target = found
		_reset_hold()

	_update_prompt()

	var cursor_free := require_captured_mouse and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED
	if target == null or cursor_free:
		_reset_hold()
		return

	var hold_time := _hold_time_of(target)
	if hold_time <= 0.0:
		if Input.is_action_just_pressed("interact"):
			if Input.is_action_pressed("alt_modifier") and target.has_method("interact_alt"):
				target.interact_alt(player)
			else:
				target.interact(player)
		elif Input.is_action_pressed("interact"):
			target.interact_hold(player, delta)
		return

	if not Input.is_action_pressed("interact"):
		_reset_hold()
	elif not _hold_done:
		_hold += delta
		target.interact_hold(player, delta)
		hold_progress_changed.emit(clampf(_hold / hold_time, 0.0, 1.0))
		if _hold >= hold_time:
			target.interact(player)
			_hold_done = true # must release E before it can trigger again


func _find_target() -> Object:
	force_raycast_update()
	if not is_colliding():
		return null
	var collider := get_collider()
	if collider == null or not collider.has_method("interact"):
		return null
	if not collider.can_interact(player):
		return null
	return collider


func _update_prompt() -> void:
	var text := ""
	if target != null:
		var key := "[Hold E]" if _hold_time_of(target) > 0.0 else "[E]"
		text = "%s %s" % [key, target.get_prompt(player)]
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _reset_hold() -> void:
	if _hold > 0.0 or _hold_done:
		hold_progress_changed.emit(0.0)
	_hold = 0.0
	_hold_done = false


func _hold_time_of(candidate: Object) -> float:
	if candidate.has_method("get_hold_time"):
		return candidate.get_hold_time(player)
	return candidate.hold_time
