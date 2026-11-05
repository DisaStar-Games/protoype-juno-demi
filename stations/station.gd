class_name Station
extends Node3D

## A station level (stations/Station*.tscn): a platform with the parked train, a few buildings,
## rocks and a row of spots for supply crates. The crates that appear are the resources the
## station offered on the route screen (Journey.trip_supplies), with the amounts that were
## hidden there. Press E on the train's door to board; the loop starts again.
## Set `station_id` to a station of RouteGraph. Started on its own (F6) it rolls supplies.

const CRATE_SCENE := preload("res://stations/supply_crate.tscn")
const ITEM_ORDER: Array[StringName] = [&"coal", &"water", &"bullets"]

@export var station_id: StringName = &"dustwater"


func _ready() -> void:
	EventManager.random_enabled = false
	GameState.post_message("Welcome to %s" % RouteGraph.station_name(station_id))
	_spawn_crates()


func _spawn_crates() -> void:
	var supplies: Dictionary = Journey.trip_supplies
	if supplies.is_empty():
		supplies = RouteGraph.roll_supplies(RouteGraph.SETS.pick_random())
	var items: Array[StringName] = []
	for item in ITEM_ORDER:
		if int(supplies.get(item, 0)) > 0:
			items.append(item)
	var spawns := $Supplies.get_children().filter(func(n: Node) -> bool: return n is Marker3D)
	var slots: Array = [1] if items.size() == 1 else ([0, 2] if items.size() == 2 else [0, 1, 2])
	for i in mini(items.size(), slots.size()):
		var crate := CRATE_SCENE.instantiate() as SupplyCrate
		crate.item_id = items[i]
		crate.amount = int(supplies[items[i]])
		crate.position = (spawns[slots[i]] as Marker3D).position
		$Supplies.add_child(crate)
