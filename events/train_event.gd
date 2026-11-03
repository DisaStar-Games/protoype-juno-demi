class_name TrainEvent
extends Node3D

## Base class for everything that happens on the route (slower train, bandits, fire...).
##
## An event is scheduled by distance and moves through
##   PENDING -> WARNING -> ACTIVE -> RESOLVED or FAILED
## WARNING starts `warning_distance` before `trigger_distance`, ACTIVE when the train
## reaches it. Subclasses override the virtual hooks and call `resolve()` / `fail()`.
## EventManager owns the events and calls `advance()` every physics frame.

enum State { PENDING, WARNING, ACTIVE, RESOLVED, FAILED }
## Where it happens: inside the train (repairs) or outside, on the track (hazards ahead).
## The F2 events panel groups its buttons by this.
enum Category { INSIDE, OUTSIDE }

signal state_changed(event: TrainEvent, state: State)

@export var id: StringName = &"event"
@export var display_name := "Event"
@export var category := Category.OUTSIDE
## How far before `trigger_distance` the player gets warned (400 u is ~13 s at top speed).
@export var warning_distance := 400.0
@export_group("On failure")
## Seconds taken off the delivery timer.
@export var fail_time_penalty := 30.0
@export var fail_fuel_loss := 0.0
## Failing this event loses the whole run.
@export var fail_ends_run := false
@export_group("")
## How long a finished event lingers (visuals, debug list) before it frees itself.
@export var cleanup_delay := 4.0
## Silent events post no messages and are not relayed by EventManager (hallucinations).
@export var silent := false

## Distance on the route where the hazard is reached. Set by the manager from the route.
var trigger_distance := 0.0
## Extra settings from the route entry, for subclasses to read.
var params: Dictionary = {}
var state := State.PENDING

var _finished_for := 0.0


func is_live() -> bool:
	return state == State.WARNING or state == State.ACTIVE


func is_finished() -> bool:
	return state == State.RESOLVED or state == State.FAILED


func remaining_distance() -> float:
	return trigger_distance - TrainState.distance


# --- Hooks for subclasses ------------------------------------------------------

## Text on the beacon sign (see HazardMarker); the default is the name and distance.
func sign_text() -> String:
	return "%s\n%d u" % [display_name.to_upper(), maxi(0, roundi(remaining_distance()))]


## Messages posted on the HUD; return "" to stay quiet.
func warning_message() -> String:
	return "Warning: %s ahead!" % display_name


func resolved_message() -> String:
	return "%s: resolved" % display_name


func failed_message() -> String:
	return "%s: failed!" % display_name


func on_warning() -> void:
	pass


func on_start() -> void:
	pass


## Called every physics frame while the event is WARNING or ACTIVE.
func process_event(_delta: float) -> void:
	pass


func on_resolve() -> void:
	pass


func on_fail() -> void:
	pass


# --- State machine -------------------------------------------------------------

## Called by EventManager each physics frame. Returns true once the event is finished
## and has lingered long enough to be removed.
func advance(delta: float) -> bool:
	if state == State.PENDING and TrainState.distance >= trigger_distance - warning_distance:
		begin_warning()
	if state == State.WARNING and remaining_distance() <= 0.0:
		begin_active()
	if is_live():
		process_event(delta)
	if is_finished():
		_finished_for += delta
		return _finished_for >= cleanup_delay
	return false


func begin_warning() -> void:
	if state != State.PENDING:
		return
	state = State.WARNING
	_announce(warning_message())
	on_warning()
	state_changed.emit(self, state)


func begin_active() -> void:
	if state != State.PENDING and state != State.WARNING:
		return
	if state == State.PENDING:
		begin_warning()
	state = State.ACTIVE
	on_start()
	state_changed.emit(self, state)


func resolve() -> void:
	if not is_live():
		return
	state = State.RESOLVED
	_announce(resolved_message())
	on_resolve()
	state_changed.emit(self, state)


func fail() -> void:
	if not is_live():
		return
	state = State.FAILED
	_announce(failed_message())
	on_fail()
	_apply_failure_consequences()
	state_changed.emit(self, state)


## Starts the event right now for debugging: in WARNING with a normal lead, or
## (`active_now`) straight in ACTIVE.
func force_start(active_now := false) -> void:
	trigger_distance = TrainState.distance if active_now else TrainState.distance + warning_distance
	state = State.PENDING
	begin_warning()
	if active_now:
		begin_active()


func _apply_failure_consequences() -> void:
	if fail_time_penalty > 0.0:
		GameState.apply_time_penalty(fail_time_penalty, display_name)
	if fail_fuel_loss > 0.0:
		TrainState.fuel -= fail_fuel_loss
	if fail_ends_run:
		GameState.end_run(false, "%s was not handled" % display_name)


func _announce(text: String) -> void:
	if text != "" and not silent:
		GameState.post_message(text)


## Screen and camera effects for a crash or a hit: red flash, glitch and a camera kick.
func crash_effects(strength := 1.0) -> void:
	ScreenEffects.flash(Color(0.9, 0.1, 0.1), 0.55 * strength, 0.6)
	ScreenEffects.glitch(strength, 0.6)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.camera.has_method("kick"):
		player.camera.kick(strength, 0.6 + 0.8 * strength)
