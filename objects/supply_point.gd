class_name SupplyPoint
extends Interactable

## A place to restock the inventory: hold E to take `amount` of `item_id` (the water barrel, the
## ammo crate). `stock` limits how much it holds (-1 = unlimited); `regen_per_minute` refills it.

@export var item_id: StringName = &"water"
@export var amount := 2
@export var title := "SUPPLY"
## How much is in it (-1 = unlimited).
@export var stock := -1
## Stock it can hold when refilling (only used with a limited stock).
@export var max_stock := 10
## Units it refills by per minute (0 = never).
@export var regen_per_minute := 0.0
## Played when you take something (set it on the water barrel for the water sound).
@export var take_sound: AudioStream

var _regen := 0.0

@onready var label: Label3D = $Label3D


func _ready() -> void:
	_update_label()


func _process(delta: float) -> void:
	if stock < 0 or regen_per_minute <= 0.0 or stock >= max_stock:
		return
	_regen += regen_per_minute * delta / 60.0
	if _regen >= 1.0:
		_regen -= 1.0
		stock = mini(stock + 1, max_stock)
		_update_label()


func get_prompt(_player: Node) -> String:
	var name: String = Inventory.INFO[item_id]["name"]
	if stock == 0:
		return "%s: empty" % title.capitalize()
	if Inventory.is_full(item_id):
		return "%s: you can't carry more" % name
	var left := "" if stock < 0 else "  [%d left]" % stock
	return "%s %d %s  (%d/%d)%s" % [prompt_text, _take_amount(), name.to_lower(), Inventory.count(item_id), Inventory.capacity(item_id), left]


func interact(_player: Node) -> void:
	if stock == 0:
		GameState.post_message("The %s is empty." % title.to_lower())
		return
	var taken := Inventory.add(item_id, _take_amount())
	if taken == 0:
		GameState.post_message("You can't carry more %s." % String(Inventory.INFO[item_id]["name"]).to_lower())
		return
	Sfx.play_at(self, take_sound)
	if stock > 0:
		stock -= taken
	_update_label()


func _take_amount() -> int:
	return amount if stock < 0 else mini(amount, stock)


func _update_label() -> void:
	label.text = title if stock < 0 else "%s  %d" % [title, stock]
