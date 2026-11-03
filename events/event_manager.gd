extends Node

## Owns the route's events: builds them from the RouteData, advances them every physics
## frame, relays their state changes, and force-starts events for debugging.
## Autoload `EventManager`.

signal event_warning(event: TrainEvent)
signal event_started(event: TrainEvent)
signal event_resolved(event: TrainEvent)
signal event_failed(event: TrainEvent)
## The list of events changed (added, removed or moved to another state).
signal events_changed

@export var route: RouteData
## Events the debug panel and the number keys (1-9) can force-start.
@export var debug_events: Array[PackedScene] = []
## Started automatically when the furnace overheats (TrainState.furnace_overheated).
@export var furnace_fire_event: PackedScene

## Every event currently in the world, pending or finished-but-lingering.
var events: Array[TrainEvent] = []

var _debug_names: Array[String] = []
var _debug_categories: Array[int] = []


func _ready() -> void:
	for scene in debug_events:
		var sample := scene.instantiate() as TrainEvent
		_debug_names.append(sample.display_name)
		_debug_categories.append(sample.category)
		sample.free()
	GameState.state_changed.connect(_on_game_state_changed)
	TrainState.furnace_overheated.connect(_on_furnace_overheated)
	load_route()


func _physics_process(delta: float) -> void:
	advance_events(delta)


func _input(event: InputEvent) -> void:
	for i in mini(debug_events.size(), 9):
		if event.is_action_pressed("debug_event_%d" % (i + 1)):
			force_start(i)


## Separate from _physics_process so tests can drive it.
func advance_events(delta: float) -> void:
	if GameState.state != GameState.State.RUNNING:
		return
	for event in events.duplicate():
		if event.advance(delta):
			_remove(event)


## Throws away all events and rebuilds the schedule from the route.
func load_route() -> void:
	clear()
	if route == null:
		return
	for entry in route.entries:
		if entry.event_scene == null:
			continue
		var event := entry.event_scene.instantiate() as TrainEvent
		event.trigger_distance = entry.trigger_distance
		event.params = entry.params
		if entry.warning_distance >= 0.0:
			event.warning_distance = entry.warning_distance
		_add(event)


func clear() -> void:
	for event in events:
		event.queue_free()
	events.clear()
	events_changed.emit()


## Debug: starts `debug_events[index]` now (in WARNING, or `active_now` straight in ACTIVE).
func force_start(index: int, active_now := false) -> TrainEvent:
	if index < 0 or index >= debug_events.size():
		return null
	return start_event(debug_events[index], active_now)


## Starts an event from any scene right now, outside the route (debug, furnace fire,
## hallucinated hazards).
func start_event(scene: PackedScene, active_now := false) -> TrainEvent:
	var event := scene.instantiate() as TrainEvent
	_add(event)
	event.force_start(active_now)
	return event


func has_live_event(event_id: StringName) -> bool:
	for event in events:
		if event.id == event_id and event.is_live():
			return true
	return false


func debug_event_name(index: int) -> String:
	return _debug_names[index]


## TrainEvent.Category of `debug_events[index]`.
func debug_event_category(index: int) -> int:
	return _debug_categories[index]


func live_events() -> Array[TrainEvent]:
	var live: Array[TrainEvent] = []
	for event in events:
		if event.is_live():
			live.append(event)
	return live


func _add(event: TrainEvent) -> void:
	add_child(event)
	events.append(event)
	event.state_changed.connect(_on_event_state_changed)
	events_changed.emit()


func _remove(event: TrainEvent) -> void:
	events.erase(event)
	event.queue_free()
	events_changed.emit()


func _on_event_state_changed(event: TrainEvent, state: TrainEvent.State) -> void:
	if event.silent:
		events_changed.emit()
		return
	match state:
		TrainEvent.State.WARNING:
			event_warning.emit(event)
		TrainEvent.State.ACTIVE:
			event_started.emit(event)
		TrainEvent.State.RESOLVED:
			event_resolved.emit(event)
		TrainEvent.State.FAILED:
			event_failed.emit(event)
	events_changed.emit()


## A restart (or the debug reset) begins a fresh run: rebuild the schedule.
func _on_game_state_changed(state: GameState.State) -> void:
	if state == GameState.State.RUNNING:
		load_route()


## An overheated furnace catches fire: start the fire event (once).
func _on_furnace_overheated() -> void:
	if furnace_fire_event != null and GameState.state == GameState.State.RUNNING \
			and not has_live_event(&"furnace_fire"):
		start_event(furnace_fire_event, true)
