extends TrainEvent

## Someone is aboard. The event arms, and when the player walks into the cabin it picked,
## a stalker (Figure in TRESPASSER mode) appears at the far end of it. It freezes while
## watched and creeps when not; staring it down resolves the event, being reached by it
## fails the event (jump scare + time penalty) and a random system of the train goes down. Walking out of its cabin leaves it behind.
## Not scheduled randomly: start it from the F2 panel (or a route entry).
## If the player is already in a cabin when it starts, the stalker appears right away.

@export var figure_scene: PackedScene
## Seconds the event stays armed without the player entering the cabin before it gives up.
@export var armed_timeout := 120.0
## The stalker appears at least this far from the player.
@export var spawn_min_distance := 5.0

var _zone: CabinZone
var _figure: Figure
var _armed_for := 0.0
var _outcome: StringName = &""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func warning_message() -> String:
	return "You hear footsteps... someone is aboard. Be careful in the cabins."


func resolved_message() -> String:
	match _outcome:
		&"stared":
			return "You stared it down. It's gone."
		&"left":
			return "You left it behind."
		&"timeout":
			return "Whoever was aboard has moved on."
	return "The trespasser is gone."


func failed_message() -> String:
	return "The trespasser got you!"


func on_start() -> void:
	var player := _player()
	var zones: Array[CabinZone] = []
	for zone in get_tree().get_nodes_in_group("cabin_zones"):
		if zone.encounters_allowed:
			zones.append(zone)
	if zones.is_empty():
		return
	var wanted: String = params.get("zone", "")
	var here := CabinZone.at(get_tree(), player.global_position) if player != null else null
	if wanted != "":
		for zone in zones:
			if zone.zone_name == wanted:
				_zone = zone
	elif here != null and here.encounters_allowed:
		_zone = here # already in a cabin: it is right here
	if _zone == null:
		_zone = zones[_rng.randi_range(0, zones.size() - 1)]
	if player != null and _zone.contains(player.global_position):
		_spawn_figure(player)


func process_event(delta: float) -> void:
	if state != State.ACTIVE or _zone == null or is_instance_valid(_figure):
		return
	var player := _player()
	if player != null and _zone.contains(player.global_position):
		_spawn_figure(player)
		return
	_armed_for += delta
	if _armed_for >= armed_timeout:
		_outcome = &"timeout"
		resolve()


func on_resolve() -> void:
	_remove_figure()


func on_fail() -> void:
	_remove_figure()


func _spawn_figure(player: Node3D) -> void:
	_figure = figure_scene.instantiate() as Figure
	add_child(_figure)
	_figure.global_position = _zone.floor_point_away_from(player.global_position, spawn_min_distance, _rng)
	_figure.setup(Figure.Mode.TRESPASSER, player, _zone)
	_figure.vanished.connect(_on_figure_vanished)
	_figure.caught.connect(_on_figure_caught)


func _on_figure_vanished(reason: StringName) -> void:
	if reason == &"stared" or reason == &"left":
		_outcome = reason
		resolve()


func _on_figure_caught() -> void:
	var kind: StringName = EventManager.sabotage_random()
	if kind != &"":
		GameState.post_message("The trespasser wrecked the %s!" % EventManager.SYSTEM_NAMES[kind])
	fail()


## The jump scare plays out on its own; any other figure is removed with the event.
func _remove_figure() -> void:
	if is_instance_valid(_figure) and not _figure.is_catching():
		_figure.cancel()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func task_text() -> String:
	return "Someone is aboard: stare it down in the cabins" if is_instance_valid(_figure) else "Someone is aboard: watch the cabins"
