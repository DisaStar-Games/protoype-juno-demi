extends Interactable

## Endless coal source: takes a fresh coal cube straight from the pile into the hand.
## Bandits can empty it (`stolen`) until they are gone.

@export var coal_scene: PackedScene

## True while bandits have taken the coal: the pile gives nothing.
var stolen := false


func _ready() -> void:
	add_to_group("coal_pile")


func get_prompt(_player: Node) -> String:
	return "The pile is empty!" if stolen else prompt_text


func can_interact(player: Node) -> bool:
	return player.held_item.is_empty()


func interact(player: Node) -> void:
	if stolen:
		GameState.post_message("The bandits took all the coal!")
		return
	var coal := coal_scene.instantiate() as ItemPickup
	get_tree().current_scene.add_child(coal)
	coal.global_position = global_position + Vector3(0, 0.8, 0)
	player.held_item.pick_up(coal)
