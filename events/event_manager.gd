extends Node

## Owns the events: builds them from a route (optional), starts them at random, answers the
## furnace overheating, bandits and idling, advances them every physics frame, relays their
## state changes and force-starts them for debugging. Autoload `EventManager`.
##
## What starts events:
##  - random rolls (`random_pool`, see RandomPool): every event in the pool has a chance
##  - the furnace overheating (TrainState.furnace_overheated) -> the furnace fire
##  - bandits: wrecking something (`sabotage`), failing the bandit pass (a raid), and standing
##    still for `idle_time_limit` seconds (a raid, the bandits find you)
##  - a collision (`wreck_train`)
##  - the F2 panel and the number keys

signal event_warning(event: TrainEvent)
signal event_started(event: TrainEvent)
signal event_resolved(event: TrainEvent)
signal event_failed(event: TrainEvent)
## The list of events changed (added, removed or moved to another state).
signal events_changed

## An optional fixed schedule on top of the random events (empty in the game).
@export var route: RouteData
## Events the F2 panel and the number keys (1-9) can force-start.
@export var debug_events: Array[PackedScene] = []

@export_group("Special events")
## Started when the furnace overheats, or when bandits wreck the furnace.
@export var furnace_fire_event: PackedScene
## Started when bandits (or a crash) wreck the coolant tank.
@export var coolant_leak_event: PackedScene
## Started when bandits (or a crash) wreck the gas pipes.
@export var gas_leak_event: PackedScene
## Started when the bandits board the train.
@export var raid_event: PackedScene
## The bandit chase: started at every checkpoint (for now).
@export var chase_event: PackedScene

@export_group("Random events")
@export var random_enabled := true
@export var random_pool: RandomPool

@export_group("Idle bandits")
## Standing still too long attracts bandits.
@export var idle_raid_enabled := true
## Seconds stopped before they come.
@export var idle_time_limit := 4.0
## A warning message this many seconds before they come.
@export var idle_warning_time := 3.0
## After bandits boarded the train, no bandits (a raid, a chase, idling) for this many seconds:
## time to kill them, fix the train and get going.
@export var raid_lockout_time := 60.0

## Every event currently in the world, pending or finished-but-lingering.
var events: Array[TrainEvent] = []

var _debug_names: Array[String] = []
var _debug_categories: Array[int] = []
var _info := {}       # PackedScene -> {id, category}, read once from a sample
var _cooldowns := {}  # PackedScene -> seconds left
var _run_time := 0.0
var _next_roll := 0.0
var _since_spawn := 999.0
var _idle := 0.0
var _raid_lockout := 0.0
var _idle_warned := false


func _ready() -> void:
	for scene in debug_events:
		var info := _info_for(scene)
		_debug_names.append(info.name)
		_debug_categories.append(info.category)
	GameState.state_changed.connect(_on_game_state_changed)
	TrainState.furnace_overheated.connect(_on_furnace_overheated)
	GameState.checkpoint_reached.connect(_on_checkpoint_reached)
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
	_heal_furnace()
	_update_idle(delta)
	_update_random(delta)


## Throws away all events and rebuilds the schedule from the route.
func load_route() -> void:
	clear()
	_reset_timers()
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


## Starts an event from any scene right now, outside the route (random events, bandits, a
## crash, debugging). `params` is handed to the event before it starts.
func start_event(scene: PackedScene, active_now := false, params := {}) -> TrainEvent:
	var event := scene.instantiate() as TrainEvent
	event.params = params
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


# --- Wrecking the train ----------------------------------------------------------

## Breaks one part of the train by playing its normal event: &"furnace" (fire), &"coolant"
## (coolant leak), &"pipes" (gas leak; `params.leak_index` picks the joint) or switches the
## console off (&"controls"). Nothing happens if that part is already broken.
func sabotage(kind: StringName, params := {}) -> TrainEvent:
	if is_sabotaged(kind):
		return null
	match kind:
		&"furnace":
			if furnace_fire_event != null:
				return start_event(furnace_fire_event, true)
		&"coolant":
			if coolant_leak_event != null:
				return start_event(coolant_leak_event, true)
		&"pipes":
			if gas_leak_event != null:
				return start_event(gas_leak_event, true, params)
		&"controls":
			TrainState.damage_system(&"controls")
	return null


## Names of the things that can break, for messages.
const SYSTEM_NAMES := {&"furnace": "furnace", &"coolant": "coolant tank", &"pipes": "gas pipes", &"controls": "console"}


## Breaks a random part that is still intact. Returns its kind, or &"" if everything is broken.
func sabotage_random() -> StringName:
	var options: Array[StringName] = []
	for kind: StringName in SYSTEM_NAMES:
		if not is_sabotaged(kind):
			options.append(kind)
	if options.is_empty():
		return &""
	var kind: StringName = options[randi() % options.size()]
	sabotage(kind)
	return kind


func is_sabotaged(kind: StringName) -> bool:
	match kind:
		&"furnace":
			return has_live_event(&"furnace_fire")
		&"coolant":
			return has_live_event(&"coolant_leak")
		&"pipes":
			return has_live_event(&"gas_leak")
		&"controls":
			return TrainState.is_system_damaged(&"controls")
	return false


## A crash: the train stops, the console is wrecked, the furnace catches fire and
## the coolant tank and the gas pipes start leaking.
func wreck_train() -> void:
	for kind: StringName in [&"furnace", &"coolant", &"pipes"]:
		sabotage(kind)
	TrainState.collide()


# --- Random events ---------------------------------------------------------------

## Rolls the dice once: every eligible entry of the random pool gets its chance and at most one
## event starts. With `force` the chances, cooldowns and speed limit are ignored (the F2 button).
func roll_random_event(force := false) -> TrainEvent:
	if random_pool == null:
		return null
	if not force and _since_spawn < random_pool.min_gap:
		return null
	var entries: Array[RandomEntry] = random_pool.entries.duplicate()
	entries.shuffle()
	for entry in entries:
		if entry.event_scene == null:
			continue
		var info := _info_for(entry.event_scene)
		if has_live_event(info.id):
			continue
		if not force and _cooldowns.get(entry.event_scene, 0.0) > 0.0:
			continue
		if not force and info.id == &"bandits" and not bandits_allowed():
			continue
		if info.category == TrainEvent.Category.OUTSIDE:
			if not force and TrainState.speed < random_pool.min_track_speed:
				continue
			if _live_count(TrainEvent.Category.OUTSIDE) >= random_pool.max_live_outside:
				continue
		elif _live_count(TrainEvent.Category.INSIDE) >= random_pool.max_live_inside:
			continue
		if not force and randf() >= entry.chance * _chance_scale(info.category):
			continue
		_cooldowns[entry.event_scene] = entry.cooldown
		_since_spawn = 0.0
		return start_event(entry.event_scene, false)
	return null


func _update_random(delta: float) -> void:
	if not random_enabled or random_pool == null:
		return
	_run_time += delta
	_since_spawn += delta
	for scene in _cooldowns:
		_cooldowns[scene] = maxf(_cooldowns[scene] - delta, 0.0)
	if _run_time < random_pool.start_delay:
		return
	_next_roll -= delta
	if _next_roll <= 0.0:
		_next_roll = random_pool.check_interval
		roll_random_event()


## Events get more frequent the further along the route you are, faults inside the train most.
func _chance_scale(category: int) -> float:
	if random_pool == null:
		return 1.0
	var progress := clampf(TrainState.distance / GameState.route_length, 0.0, 1.0)
	var at_end := random_pool.fault_multiplier_at_end if category == TrainEvent.Category.INSIDE else random_pool.track_multiplier_at_end
	return lerpf(1.0, at_end, progress)


## One row per random entry for the F2 panel: its chance per roll right now (base chance times
## the progress scaling) and whether it can start at the moment.
func chance_table() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	if random_pool == null:
		return table
	for entry in random_pool.entries:
		if entry.event_scene == null:
			continue
		var info := _info_for(entry.event_scene)
		var scale := _chance_scale(info.category)
		var note := ""
		if has_live_event(info.id):
			note = "running"
		elif _cooldowns.get(entry.event_scene, 0.0) > 0.0:
			note = "cooldown %ds" % ceili(_cooldowns[entry.event_scene])
		elif info.id == &"bandits" and not bandits_allowed():
			note = "locked %ds" % ceili(_raid_lockout)
		table.append({"name": info.name, "category": info.category, "base": entry.chance,
				"scale": scale, "chance": minf(entry.chance * scale, 1.0), "note": note})
	return table


func _live_count(category: int) -> int:
	var count := 0
	for event in events:
		if event.is_live() and not event.silent and event.category == category:
			count += 1
	return count


## Reads the id, category and name of an event scene once (a throwaway sample instance).
func _info_for(scene: PackedScene) -> Dictionary:
	if not _info.has(scene):
		var sample := scene.instantiate() as TrainEvent
		_info[scene] = {"id": sample.id, "category": sample.category, "name": sample.display_name}
		sample.free()
	return _info[scene]


func _reset_timers() -> void:
	_run_time = 0.0
	_next_roll = random_pool.check_interval if random_pool != null else 0.0
	_since_spawn = 999.0
	_cooldowns.clear()
	_idle = 0.0
	_raid_lockout = 0.0
	_idle_warned = false


# --- Idle bandits ----------------------------------------------------------------

## The train drives by itself, so standing still means something is broken or the fuel is gone.
## After `idle_time_limit` seconds (a few) the bandits find the stopped train and come aboard.
func _update_idle(delta: float) -> void:
	if not idle_raid_enabled or raid_event == null:
		return
	_raid_lockout = maxf(_raid_lockout - delta, 0.0)
	var moving := TrainState.speed >= 0.5
	if moving or TrainState.distance < 5.0 or has_live_event(&"bandit_raid"):
		_idle = 0.0
		_idle_warned = false
		return
	if _raid_lockout > 0.0 or TrainState.emergency_stop:
		return
	_idle += delta
	if not _idle_warned and _idle >= idle_time_limit - idle_warning_time:
		_idle_warned = true
		GameState.post_message("The train has stopped! Bandits are closing in.")
	if _idle >= idle_time_limit:
		_idle = 0.0
		_idle_warned = false
		GameState.post_message("A stopped train is easy prey. Bandits are coming!")
		start_event(raid_event, true)


## Safety net: the train is flagged "on fire" but no fire event is running (it was removed some
## other way): put it out, otherwise the furnace could never catch fire again.
func _heal_furnace() -> void:
	if TrainState.furnace_on_fire and not has_live_event(&"furnace_fire"):
		var fire := get_tree().get_first_node_in_group("furnace_fire")
		if fire != null:
			fire.put_out()
		TrainState.furnace_on_fire = false
		TrainState.furnace_temp = TrainState.temp_after_fire


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


## A restart (or the debug reset) begins a fresh run: rebuild the schedule and the timers.
func _on_game_state_changed(state: GameState.State) -> void:
	if state == GameState.State.RUNNING:
		load_route()


## Bandits may come aboard (or chase the train) again: not for `raid_lockout_time` seconds after
## the last raid started.
func bandits_allowed() -> bool:
	return _raid_lockout <= 0.0 and not has_live_event(&"bandit_raid")


## Called by the raid when the bandits board: starts the lockout.
func note_raid_started() -> void:
	_raid_lockout = raid_lockout_time


## Seconds left of the lockout (for displays).
func raid_lockout_left() -> float:
	return _raid_lockout


## Every checkpoint sends the bandits after the train (for now).
func _on_checkpoint_reached(_index: int, checkpoint_name: String) -> void:
	GameState.post_message("Checkpoint %s!" % checkpoint_name)
	if chase_event != null and bandits_allowed() and not has_live_event(&"bandits"):
		start_event(chase_event, true)


## An overheated furnace catches fire: start the fire event (once).
func _on_furnace_overheated() -> void:
	if furnace_fire_event != null and GameState.state == GameState.State.RUNNING \
			and not has_live_event(&"furnace_fire"):
		start_event(furnace_fire_event, true)
