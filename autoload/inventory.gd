extends Node

## The player's pockets: three stacks that are not items in the hand. Coal (from the pile, to
## feed the furnace or throw), water and bullets (the shotgun reloads from them).
## The HUD shows the slots at the bottom of the screen. Autoload `Inventory`.

signal changed(id: StringName)

## Slot order, name, maximum amount, and the placeholder logo (a letter on a colour).
const SLOTS: Array[StringName] = [&"coal", &"water", &"bullets"]
const INFO := {
	&"coal": {"name": "Coal", "max": 20, "glyph": "C", "color": Color(0.35, 0.35, 0.4)},
	&"water": {"name": "Water", "max": 10, "glyph": "W", "color": Color(0.25, 0.5, 0.95)},
	&"bullets": {"name": "Bullets", "max": 16, "glyph": "B", "color": Color(0.85, 0.6, 0.2)},
}
## What the player starts a run with.
const START := {&"coal": 0, &"water": 0, &"bullets": 6}

## Per-level pocket sizes (id -> max); empty = the defaults in INFO. A level script sets them.
var max_override := {}

var _counts := {}


func _ready() -> void:
	reset()


func reset() -> void:
	for id in SLOTS:
		_counts[id] = START[id]
		changed.emit(id)


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func capacity(id: StringName) -> int:
	return max_override.get(id, INFO[id]["max"])


func is_full(id: StringName) -> bool:
	return count(id) >= capacity(id)


## Adds up to `amount`; returns how many fit.
func add(id: StringName, amount := 1) -> int:
	var added := clampi(amount, 0, capacity(id) - count(id))
	if added > 0:
		_counts[id] = count(id) + added
		changed.emit(id)
	return added


## Takes `amount` if there is that much; returns whether it did.
func remove(id: StringName, amount := 1) -> bool:
	if count(id) < amount:
		return false
	_counts[id] = count(id) - amount
	changed.emit(id)
	return true
