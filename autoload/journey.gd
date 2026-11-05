extends Node

## The travel loop, kept across scene changes. Autoload `Journey`.
##
##   CRUISING    the train drives on the main line towards a junction (~30-45 s)
##   CHOICE      the junction is here: two stations are offered; flip the track switch (the lever
##               in the cockpit) to pick one. The choice locks in after CHOICE_WINDOW seconds.
##   TO_STATION  driving to the chosen station, 1-2 minutes depending on how much it holds
##   AT_STATION  the station level is loaded; boarding the train starts the next CRUISING
##
## Cruising and the trip are measured in distance at the nominal speed, so a slowed train (fire,
## gas, low coolant, no fuel) takes longer and a boost gets there sooner.
## Only active inside a journey level (levels/TrainJourney.tscn); other levels never start it.

signal phase_changed
signal selection_changed
## The train is about to be left for a station (the level saves what it must remember).
signal leaving_train
signal trip_started(station_id: StringName)

enum Phase { OFF, CRUISING, CHOICE, TO_STATION, AT_STATION }

const TRAIN_SCENE := "res://levels/TrainJourney.tscn"
const FADE_TIME := 0.6
const CHOICE_WINDOW := 20.0
## Seconds of driving at nominal speed before the junction.
const CRUISE_MIN := 30.0
const CRUISE_MAX := 45.0
const FIRST_CRUISE := 15.0

var phase := Phase.OFF
var run_started := false
var offers: Array = []
var selected_index := 0
var choice_left := 0.0
var trip_from: StringName = &""
var trip_target: StringName = &""
var trip_supplies := {}
## Trip length in seconds at nominal speed (what the cards show).
var trip_time := 0.0
var current_station: StringName = &""
## Things the train level wants back after it reloads (coal pile, chest, barrel stock).
var store := {}

var _leg_start := 0.0
var _leg_length := 1.0
var _busy := false
var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.RUNNING:
		return
	match phase:
		Phase.CRUISING:
			if leg_progress() >= 1.0:
				open_choice()
		Phase.CHOICE:
			choice_left -= delta
			if choice_left <= 0.0:
				commit_choice()
		Phase.TO_STATION:
			if leg_progress() >= 1.0:
				_arrive()


func is_active() -> bool:
	return phase != Phase.OFF


## 0..1 along the current cruise or trip.
func leg_progress() -> float:
	return clampf((TrainState.distance - _leg_start) / maxf(_leg_length, 0.01), 0.0, 1.0)


## Seconds left in the current leg at the train's current speed (-1 = not moving).
func leg_eta() -> float:
	if TrainState.speed < 0.5:
		return -1.0
	return (1.0 - leg_progress()) * _leg_length / TrainState.speed


# --- run control --------------------------------------------------------------------------

## Starts a fresh run in the train (a journey level calls this when it opens without a run).
func start_run() -> void:
	run_started = true
	store = {}
	current_station = &""
	trip_from = &""
	TrainState.reset()
	Inventory.reset()
	GameState.reset()
	# No delivery deadline and no end of the route: the loop never ends by itself.
	GameState.route_length = 1.0e9
	GameState.time_left = 99999.0
	EventManager.load_route()
	begin_cruise(&"")


## `seconds` = how long until the junction at nominal speed (default: random 30-45 s).
func begin_cruise(from_station: StringName, seconds := -1.0) -> void:
	trip_from = from_station
	trip_target = &""
	trip_supplies = {}
	offers = []
	selected_index = 0
	_begin_leg(seconds if seconds > 0.0 else randf_range(CRUISE_MIN, CRUISE_MAX))
	phase = Phase.CRUISING
	phase_changed.emit()
	selection_changed.emit()


func _begin_leg(seconds: float) -> void:
	_leg_start = TrainState.distance
	_leg_length = seconds * TrainState.max_speed


func open_choice() -> void:
	if phase != Phase.CRUISING:
		return
	offers = RouteGraph.roll_offers()
	selected_index = 0
	choice_left = CHOICE_WINDOW
	phase = Phase.CHOICE
	_sync_lever_track()
	phase_changed.emit()
	selection_changed.emit()
	GameState.post_message("Junction ahead! Flip the track switch to pick a station.")


## The track switch: flips between the two offers (only while the choice is open).
func toggle_selection() -> bool:
	if phase != Phase.CHOICE:
		return false
	selected_index = 1 - selected_index
	_sync_lever_track()
	selection_changed.emit()
	return true


func selected_offer() -> Dictionary:
	return offers[selected_index] if not offers.is_empty() else {}


## Locks in the selected station and starts the trip.
func commit_choice() -> void:
	if phase != Phase.CHOICE:
		return
	var offer := selected_offer()
	trip_target = offer["id"]
	trip_supplies = offer["supplies"]
	trip_time = offer["time"]
	_begin_leg(trip_time)
	phase = Phase.TO_STATION
	phase_changed.emit()
	trip_started.emit(trip_target)
	GameState.post_message("Track set: %s (%s)" % [RouteGraph.station_name(trip_target), format_time(trip_time)])


func _sync_lever_track() -> void:
	TrainState.current_track = &"A" if selected_index == 0 else &"B"


## Debug (F9 in the journey level): jump ahead in the current leg.
func skip_phase() -> void:
	match phase:
		Phase.CRUISING, Phase.TO_STATION:
			_leg_start = TrainState.distance - _leg_length - 0.1
		Phase.CHOICE:
			choice_left = minf(choice_left, 0.5)


# --- stations -----------------------------------------------------------------------------

func _arrive() -> void:
	phase = Phase.AT_STATION
	current_station = trip_target
	leaving_train.emit()
	# The station level replaces the train level, so events that live in it end here: the crew
	# at the station puts out the fire and seals the leaks. A wrecked console stays broken.
	EventManager.clear()
	EventManager.random_enabled = false
	TrainState.furnace_on_fire = false
	TrainState.fire_spread = 0.0
	TrainState.gas_spread = 0.0
	TrainState.gas_leaking = false
	TrainState.boost_active = false
	TrainState.furnace_temp = 0.0
	TrainState.speed = 0.0
	TrainState.frozen = true
	phase_changed.emit()
	_change_scene(RouteGraph.scene_for(current_station))


## Press E on the station train's door: back on board, a new loop begins.
func board_train() -> void:
	if phase != Phase.AT_STATION:
		return
	var from := current_station
	current_station = &""
	leaving_train.emit()
	TrainState.frozen = false
	EventManager.random_enabled = true
	EventManager.load_route()
	begin_cruise(from)
	_change_scene(TRAIN_SCENE)


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	var out := create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await back.finished
	_busy = false


func format_time(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]
