class_name ItemPickup
extends RigidBody3D

## A physics item the player can carry one at a time (coal, wrench, extinguisher...).
## Same API as Interactable (see interactable.gd), but it must be a RigidBody3D.
## Every item is its own scene inheriting from item_pickup.tscn; give it a look by
## replacing the MeshInstance3D mesh and CollisionShape3D shape in that scene.

@export var item_id: StringName = &"item"
@export var display_name := "Item"
## LMB throws it. Items with their own "use" (extinguisher) turn this off.
@export var throwable := true
@export var hold_time := 0.0

var _saved_layer := 1
var _saved_mask := 1


func get_prompt(player: Node) -> String:
	if player.held_item.is_empty():
		return "Pick up %s" % display_name
	return "Swap for %s" % display_name


func can_interact(_player: Node) -> bool:
	return true


func interact(player: Node) -> void:
	player.held_item.pick_up(self)


func interact_hold(_player: Node, _delta: float) -> void:
	pass


## Freezes the item and removes its collision while it rides in the player's hand.
func set_held(held: bool) -> void:
	if held:
		_saved_layer = collision_layer
		_saved_mask = collision_mask
		collision_layer = 0
		collision_mask = 0
		freeze = true
	else:
		collision_layer = _saved_layer
		collision_mask = _saved_mask
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
