extends Node3D

## The resource-management train: the same train and cockpit, but no bandits and no events on
## the track. Only parts of the train break at random (coolant leak, gas leak, furnace fire),
## coal, water and bullets are scarce and pockets are small, so the chest and the barrel matter.
## This script bends the shared autoloads for this level and puts them back when it closes.

const POOL := preload("res://data/random_events_resources.tres")

## Pocket sizes in this level (the defaults are 20 / 10 / 16).
@export var pocket_sizes := {&"coal": 6, &"water": 4, &"bullets": 8}
## Fuel used per second at top speed (the normal level uses 0.4): the coal has to last.
@export var fuel_drain := 0.6

var _old_pool: RandomPool
var _old_idle := true
var _old_chase: PackedScene
var _old_drain := 0.4


func _ready() -> void:
	_old_pool = EventManager.random_pool
	_old_idle = EventManager.idle_raid_enabled
	_old_chase = EventManager.chase_event
	_old_drain = TrainState.fuel_drain_at_max_speed
	EventManager.random_pool = POOL
	EventManager.idle_raid_enabled = false
	EventManager.chase_event = null
	TrainState.fuel_drain_at_max_speed = fuel_drain
	Inventory.max_override = pocket_sizes
	Inventory.reset()
	EventManager.load_route() # fresh timers for the new pool


func _exit_tree() -> void:
	EventManager.random_pool = _old_pool
	EventManager.idle_raid_enabled = _old_idle
	EventManager.chase_event = _old_chase
	TrainState.fuel_drain_at_max_speed = _old_drain
	Inventory.max_override = {}
