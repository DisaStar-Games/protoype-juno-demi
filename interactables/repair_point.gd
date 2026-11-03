class_name RepairPoint
extends Interactable

## Something broken that the player fixes by holding E with the right item in hand
## (brake reservoir, gas leak). It is only interactable while `needs_repair` is set,
## which an event does. Without the item a press just tells the player what is missing.

signal repaired

## Item id the player must hold; empty = no item needed.
@export var required_item_id: StringName = &""
## Shown in prompts and messages, e.g. "brake fluid".
@export var required_item_name := ""
@export var repair_time := 3.0
## Prompt when the player holds the right item, e.g. "Pour brake fluid".
@export var action_text := "Repair"
## Use up the held item when the repair succeeds.
@export var consume_item := false

var needs_repair := false


func can_interact(_player: Node) -> bool:
	return needs_repair


func get_hold_time(player: Node) -> float:
	return repair_time if _has_required_item(player) else 0.0


func get_prompt(player: Node) -> String:
	if _has_required_item(player):
		return action_text
	return "Needs %s" % required_item_name


func interact(player: Node) -> void:
	if not needs_repair:
		return
	if not _has_required_item(player):
		GameState.post_message("You need the %s!" % (required_item_name if required_item_name != "" else "right item"))
		return
	if consume_item:
		player.held_item.consume()
	needs_repair = false
	repaired.emit()


func _has_required_item(player: Node) -> bool:
	if required_item_id == &"":
		return true
	var held: ItemPickup = player.held_item.item
	return held != null and held.item_id == required_item_id
