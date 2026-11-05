class_name RouteGraph
extends RefCounted

## The stations of the journey and the rules for the track choice (ported from the other train
## prototype). Every junction offers two stations. Each offer holds a different set of
## resources (1-2 of coal / water / bullets) with randomly rolled amounts. The player only sees
## WHICH resources a station has, not how many; the trip time hints at it, because the more
## there is the longer the trip takes.
##
## To add a station: add an entry to STATIONS and a scene for it (see stations/station.gd).

const STATIONS := {
	&"dustwater": {"name": "Dustwater", "scene": "res://stations/StationDustwater.tscn"},
	&"frostpine": {"name": "Frostpine", "scene": "res://stations/StationFrostpine.tscn"},
}

## Weight of one unit of each resource for the trip time (water is scarcest, bullets cheapest).
const ITEM_VALUE := {&"coal": 1.0, &"water": 1.5, &"bullets": 0.5}
const MIN_AMOUNT := {&"coal": 4, &"water": 2, &"bullets": 4}
const MAX_AMOUNT := {&"coal": 10, &"water": 6, &"bullets": 12}

## Trip time at nominal speed: MIN_TIME for a poor station up to MAX_TIME for a rich one.
const MIN_TIME := 60.0
const MAX_TIME := 120.0
## Richness that maps to MIN_TIME / MAX_TIME (2 = a few bullets, 17 = lots of coal and water).
const MIN_RICHNESS := 2.0
const MAX_RICHNESS := 17.0
## The two offers differ at least this much in trip time, so the choice is real.
const MIN_TIME_GAP := 10.0

const SETS: Array = [
	[&"coal"], [&"water"], [&"bullets"],
	[&"coal", &"water"], [&"coal", &"bullets"], [&"water", &"bullets"],
]


static func station_name(id: StringName) -> String:
	return STATIONS[id]["name"] if STATIONS.has(id) else String(id)


static func scene_for(id: StringName) -> String:
	return STATIONS[id]["scene"]


static func richness(supplies: Dictionary) -> float:
	var total := 0.0
	for item in supplies:
		total += float(supplies[item]) * float(ITEM_VALUE.get(item, 1.0))
	return total


## Trip time in seconds (at nominal speed) for a station holding these supplies.
static func trip_time(supplies: Dictionary) -> float:
	var t := inverse_lerp(MIN_RICHNESS, MAX_RICHNESS, richness(supplies))
	return roundf(lerpf(MIN_TIME, MAX_TIME, clampf(t, 0.0, 1.0)))


static func roll_supplies(items: Array) -> Dictionary:
	var supplies := {}
	for item in items:
		supplies[item] = randi_range(int(MIN_AMOUNT[item]), int(MAX_AMOUNT[item]))
	return supplies


## Two different stations with different resource sets. Returns
## [{id, supplies, time}, {id, supplies, time}].
static func roll_offers() -> Array:
	var ids: Array = STATIONS.keys()
	ids.shuffle()
	var sets := SETS.duplicate()
	sets.shuffle()
	var a := roll_supplies(sets[0])
	var b := roll_supplies(sets[1])
	for attempt in 40:
		if absf(trip_time(a) - trip_time(b)) >= MIN_TIME_GAP:
			break
		a = roll_supplies(sets[0])
		b = roll_supplies(sets[1])
	return [
		{"id": ids[0], "supplies": a, "time": trip_time(a)},
		{"id": ids[1], "supplies": b, "time": trip_time(b)},
	]
