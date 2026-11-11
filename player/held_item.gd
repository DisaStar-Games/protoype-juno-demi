class_name HeldItem
extends Node3D

## The player's hand: holds at most one ItemPickup and keeps it at this node's position.
## Lives under the camera, so the item follows where the player looks.

signal changed(item: ItemPickup)

const COAL_SCENE := preload("res://items/coal.tscn")

@export var throw_force := 8.0
@export var throw_up := 3.0
@export var drop_speed := 1.5

## Ignore throw/drop while the cursor is free (Esc). Off only for headless tests.
@export var require_captured_mouse := true

var item: ItemPickup = null

var _using := false


func is_empty() -> bool:
	return item == null


# _input (not _unhandled_input) so a HUD Control can never swallow the click.
func _input(event: InputEvent) -> void:
	if require_captured_mouse and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("use_item"):
		if item != null and item.has_method("use_pressed"):
			# A click does something of its own (the shotgun fires): aim along the view.
			var camera := get_parent() as Node3D
			item.use_pressed(camera.global_position, -camera.global_transform.basis.z)
		elif item == null:
			_throw_from_pockets()
		else:
			throw()
	elif event.is_action_pressed("reload"):
		if item != null and item.has_method("reload_pressed"):
			item.reload_pressed()
	elif event.is_action_pressed("drop_item"):
		drop()


func _physics_process(delta: float) -> void:
	if item == null:
		return
	if not is_instance_valid(item):
		item = null
		_using = false
		changed.emit(null)
		return
	# The held body is frozen, so we drive its transform ourselves.
	item.global_transform = global_transform

	# Items with their own LMB action (the extinguisher) act while the button is held.
	var cursor_ok := not require_captured_mouse or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	var wants_use := item.has_method("use_held") and cursor_ok and Input.is_action_pressed("use_item")
	if wants_use:
		var camera := get_parent() as Node3D
		item.use_held(delta, camera.global_position, -camera.global_transform.basis.z)
		_using = true
	elif _using:
		_stop_using(item)


## Takes the item into the hand. Anything already held is dropped first (swap).
func pick_up(new_item: ItemPickup) -> void:
	if item != null:
		drop()
	item = new_item
	item.set_held(true)
	item.global_transform = global_transform
	changed.emit(item)


## Empty hands + coal in the pockets: a left click throws a lump of coal.
func _throw_from_pockets() -> void:
	if not Inventory.remove(&"coal", 1):
		return
	var coal := COAL_SCENE.instantiate() as ItemPickup
	get_tree().current_scene.add_child(coal)
	coal.global_transform = global_transform
	coal.apply_central_impulse(-global_transform.basis.z * throw_force + Vector3.UP * throw_up)


func drop() -> void:
	var dropped := _release()
	if dropped != null:
		dropped.linear_velocity = -global_transform.basis.z * drop_speed


func throw() -> void:
	if item == null or not item.throwable:
		return
	var thrown := _release()
	thrown.apply_central_impulse(-global_transform.basis.z * throw_force + Vector3.UP * throw_up)


## Removes and deletes the held item (e.g. used up by a repair).
func consume() -> void:
	var used := item
	item = null
	changed.emit(null)
	if used != null:
		_stop_using(used)
		used.queue_free()


func _stop_using(used: ItemPickup) -> void:
	_using = false
	if is_instance_valid(used) and used.has_method("stop_use"):
		used.stop_use()


func _release() -> ItemPickup:
	if item == null:
		return null
	var released := item
	_stop_using(released)
	item = null
	released.set_held(false)
	changed.emit(null)
	return released
