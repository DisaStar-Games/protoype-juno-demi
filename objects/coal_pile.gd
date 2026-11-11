extends Interactable

## Limited coal source: E puts a lump of coal into your pockets (the inventory), until the pile
## is empty. A label on the pile shows how much is left. Bandits can empty it (`stolen`)
## until they are gone.

@export var coal_scene: PackedScene
## How many cubes the pile starts with.
@export var start_amount := 10
## How many cubes one press takes (as many as fit in your pockets).
@export var pickup_amount := 4
## Played when you take coal.
@export var pickup_sound: AudioStream

## Coal cubes left in the pile.
var coal_left := 0:
	set(value):
		coal_left = maxi(value, 0)
		if is_node_ready():
			_update_label()

## True while bandits have taken the coal: the pile gives nothing.
var stolen := false

@onready var label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("coal_pile")
	coal_left = start_amount
	_update_label()


func get_prompt(_player: Node) -> String:
	if stolen or coal_left <= 0:
		return "The pile is empty!"
	return "%s up to %d  (%d left)" % [prompt_text, pickup_amount, coal_left]


func can_interact(_player: Node) -> bool:
	return true


func interact(_player: Node) -> void:
	if stolen:
		GameState.post_message("The bandits took all the coal!")
		return
	if coal_left <= 0:
		GameState.post_message("The coal pile is empty!")
		return
	if Inventory.is_full(&"coal"):
		GameState.post_message("Your pockets are full of coal.")
		return
	var taken := Inventory.add(&"coal", mini(pickup_amount, coal_left))
	coal_left -= taken
	Sfx.play_at(self, pickup_sound)


## The bandits grab a share of what is left.
func steal(amount: int) -> void:
	coal_left -= amount


func _update_label() -> void:
	label.text = "COAL  %d" % coal_left
	label.modulate = Color(1, 0.35, 0.3) if coal_left <= 2 else Color(1, 1, 1)
