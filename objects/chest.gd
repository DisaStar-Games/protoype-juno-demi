class_name Chest
extends Interactable

## A storage chest: press E to open its panel and move coal, water and bullets between your
## pockets (small) and the chest (big). The cursor is free while the panel is open.

@export var capacity_per_item := 60

var _stock := {}
var _panel: ChestPanel

@onready var label: Label3D = $Label3D


func _ready() -> void:
	for id in Inventory.SLOTS:
		_stock[id] = 0
	Inventory.changed.connect(func(_id: StringName) -> void: _update_label())
	_update_label()


func get_prompt(_player: Node) -> String:
	return "Open the chest"


func interact(_player: Node) -> void:
	if _panel == null:
		_panel = ChestPanel.new()
		_panel.chest = self
		add_child(_panel)
	_panel.set_open(true)


func count(id: StringName) -> int:
	return _stock.get(id, 0)


## Moves up to `amount` from the pockets into the chest; returns how many moved.
func put(id: StringName, amount: int) -> int:
	var moved := mini(mini(amount, Inventory.count(id)), capacity_per_item - count(id))
	if moved > 0 and Inventory.remove(id, moved):
		_stock[id] = count(id) + moved
		_update_label()
		return moved
	return 0


## Moves up to `amount` from the chest into the pockets; returns how many moved.
func take(id: StringName, amount: int) -> int:
	var moved := Inventory.add(id, mini(amount, count(id)))
	if moved > 0:
		_stock[id] = count(id) - moved
		_update_label()
	return moved


## The contents, to carry over a scene change.
func snapshot() -> Dictionary:
	return _stock.duplicate()


func restore(stock: Dictionary) -> void:
	for id in stock:
		_stock[id] = stock[id]
	_update_label()


func _update_label() -> void:
	label.text = "CHEST\nC %d   W %d   B %d" % [count(&"coal"), count(&"water"), count(&"bullets")]
