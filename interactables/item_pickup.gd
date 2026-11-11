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
## HUD hint for items with their own LMB action, e.g. "spray water" (see use_held below).
@export var use_hint := ""
## Another HUD hint, e.g. "[R] reload".
@export var extra_hint := ""

## Where each kind of item started in the level: item id -> {scene, transform}. Events use
## it to put a needed item back when it was used up or lost.
static var _homes := {}

var _saved_layer := 1
var _saved_mask := 1


func _ready() -> void:
	add_to_group("item_%s" % item_id)
	if not _homes.has(item_id) and scene_file_path != "":
		_homes[item_id] = {"scene": scene_file_path, "transform": global_transform}


func _physics_process(_delta: float) -> void:
	# Fell out of the train (or the world): never leave a needed item unreachable.
	if not freeze and global_position.y < -10.0:
		return_home()


## Puts the item back where it started.
func return_home() -> void:
	if _homes.has(item_id):
		global_transform = _homes[item_id].transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Makes sure at least one item with this id exists (held, lying around or placed): if
## it was used up, a new one appears at its home spot.
static func ensure_available(tree: SceneTree, wanted_id: StringName) -> void:
	for node in tree.get_nodes_in_group("item_%s" % wanted_id):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return
	if not _homes.has(wanted_id):
		return
	var home: Dictionary = _homes[wanted_id]
	var item := (load(home.scene) as PackedScene).instantiate() as ItemPickup
	tree.current_scene.add_child(item)
	item.global_transform = home.transform


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
