class_name SupplyCrate
extends Interactable

## A crate on a station platform: press E to put its contents in your pockets. What does not fit
## stays in the crate, so you can come back after using some. The colour and label follow the item.

@export var item_id: StringName = &"coal"
@export var amount := 5

@onready var mesh: MeshInstance3D = $Mesh
@onready var label: Label3D = $Label3D


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Inventory.INFO[item_id]["color"]
	material.roughness = 0.8
	mesh.material_override = material
	_update_label()


func get_prompt(_player: Node) -> String:
	var item_name: String = Inventory.INFO[item_id]["name"]
	if amount <= 0:
		return "%s crate (empty)" % item_name
	return "Take %s x%d  (%d/%d)" % [item_name.to_lower(), amount, Inventory.count(item_id), Inventory.capacity(item_id)]


func interact(_player: Node) -> void:
	var item_name: String = String(Inventory.INFO[item_id]["name"]).to_lower()
	if amount <= 0:
		GameState.post_message("This crate is empty.")
		return
	var taken := Inventory.add(item_id, amount)
	if taken == 0:
		GameState.post_message("You can't carry more %s." % item_name)
		return
	amount -= taken
	GameState.post_message("+%d %s" % [taken, item_name])
	_update_label()


func _update_label() -> void:
	label.text = "%s\n%s" % [String(Inventory.INFO[item_id]["name"]).to_upper(), "EMPTY" if amount <= 0 else "x%d" % amount]
	label.modulate = Color(1, 1, 1, 0.5 if amount <= 0 else 1.0)
