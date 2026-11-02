extends Interactable

## Endless coal source: takes a fresh coal cube straight from the pile into the hand.

@export var coal_scene: PackedScene


func can_interact(player: Node) -> bool:
	return player.held_item.is_empty()


func interact(player: Node) -> void:
	var coal := coal_scene.instantiate() as ItemPickup
	get_tree().current_scene.add_child(coal)
	coal.global_position = global_position + Vector3(0, 0.8, 0)
	player.held_item.pick_up(coal)
