extends Node3D

## The journey train: the resource-management train (no bandits, no events on the rail, only
## random faults inside the train) with the station loop on top. Journey (autoload) runs the
## loop; this script sets the level up the first time and, after every visit to a station,
## restores what the train looked like when it left (coal pile, chest, barrel stock).
## The overrides below stay in place for the whole run: the stations need them too.

const POOL := preload("res://data/random_events_resources.tres")

## Pocket sizes for this run (a station can hold more than the resource level's pockets).
@export var pocket_sizes := {&"coal": 10, &"water": 6, &"bullets": 10}
## Fuel used per second at top speed: the coal has to last the trips.
@export var fuel_drain := 0.5


func _ready() -> void:
	Journey.leaving_train.connect(_save)
	if Journey.run_started:
		_restore()
		return
	EventManager.random_pool = POOL
	EventManager.random_enabled = true
	EventManager.idle_raid_enabled = false
	EventManager.chase_event = null
	TrainState.fuel_drain_at_max_speed = fuel_drain
	Inventory.max_override = pocket_sizes
	Journey.start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		Journey.skip_phase() # debug: jump to the end of the current leg


func _save() -> void:
	if Journey.phase != Journey.Phase.AT_STATION or not is_inside_tree():
		return
	var store := {"coal": ($CoalPile.coal_left as int), "chest": ($Chest as Chest).snapshot()}
	for node in find_children("*", "SupplyPoint", true, false):
		store[String(node.name)] = (node as SupplyPoint).stock
	Journey.store = store


func _restore() -> void:
	var store := Journey.store
	if store.is_empty():
		return
	$CoalPile.coal_left = store.get("coal", 0)
	($Chest as Chest).restore(store.get("chest", {}))
	for node in find_children("*", "SupplyPoint", true, false):
		if store.has(String(node.name)):
			(node as SupplyPoint).stock = store[String(node.name)]
			node._update_label()
