class_name RepairPoint
extends Interactable

## Something broken that the player fixes by holding E (coolant tank, gas leak, console);
## `required_item_id` can still demand an item in hand, but none of the repairs do now. It is only interactable while `needs_repair` is set,
## which an event does. Without the item a press just tells the player what is missing.

signal repaired

## Item id the player must hold; empty = no item needed.
@export var required_item_id: StringName = &""
## Shown in prompts and messages, e.g. "coolant".
@export var required_item_name := ""
@export var repair_time := 3.0
## Prompt when the player holds the right item, e.g. "Pour coolant".
@export var action_text := "Repair"
## Use up the held item when the repair succeeds.
@export var consume_item := false

## Optional cost of the repair, taken from the pockets (the inventory) when it succeeds.
@export var cost_item_id: StringName = &""
@export var cost_amount := 0

@export_group("Sounds")
## Loops while the player holds E on this (filling the tank, tightening the pipe).
@export var working_sound: AudioStream
## Played once when the repair is finished.
@export var done_sound: AudioStream

var needs_repair := false

var _working_player: AudioStreamPlayer3D
var _last_hold_msec := -1000


func _process(_delta: float) -> void:
	# The hold ended when interact_hold stops being called.
	if _working_player != null and _working_player.playing and Time.get_ticks_msec() - _last_hold_msec > 150:
		Sfx.set_playing(_working_player, false)


func interact_hold(_player: Node, _delta: float) -> void:
	if needs_repair and get_hold_time(_player) > 0.0:
		_last_hold_msec = Time.get_ticks_msec()
		if _working_player == null:
			_working_player = Sfx.loop_player(self, working_sound) # made on first use
		Sfx.set_playing(_working_player, true)


func can_interact(_player: Node) -> bool:
	return needs_repair


func get_hold_time(player: Node) -> float:
	return repair_time if _has_required_item(player) and _can_afford() else 0.0


func get_prompt(player: Node) -> String:
	if _has_required_item(player) and _can_afford():
		return action_text if cost_amount <= 0 else "%s (%d %s)" % [action_text, cost_amount, _cost_name()]
	if not _has_required_item(player):
		return "Needs %s" % required_item_name
	return "Needs %d %s" % [cost_amount, _cost_name()]


func interact(player: Node) -> void:
	if not needs_repair:
		return
	if not _has_required_item(player):
		GameState.post_message("You need the %s!" % (required_item_name if required_item_name != "" else "right item"))
		return
	if not _can_afford():
		GameState.post_message("You need %d %s!" % [cost_amount, _cost_name()])
		return
	if cost_amount > 0:
		Inventory.remove(cost_item_id, cost_amount)
	if consume_item:
		player.held_item.consume()
	needs_repair = false
	Sfx.set_playing(_working_player, false)
	Sfx.play_at(self, done_sound)
	repaired.emit()


func _can_afford() -> bool:
	return cost_amount <= 0 or Inventory.count(cost_item_id) >= cost_amount


func _cost_name() -> String:
	return String(Inventory.INFO[cost_item_id]["name"]).to_lower() if Inventory.INFO.has(cost_item_id) else "supplies"


func _has_required_item(player: Node) -> bool:
	if required_item_id == &"":
		return true
	var held: ItemPickup = player.held_item.item
	return held != null and held.item_id == required_item_id
