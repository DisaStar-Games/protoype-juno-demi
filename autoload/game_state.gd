extends Node

## Run state: the delivery countdown, winning (reach the end of the route) and losing
## (too late). When a run ends, the train is frozen and `game_over` fires; the end screen
## (ui/end_screen.tscn) listens to it. Autoload `GameState`.

enum State { RUNNING, WON, LOST }

signal time_left_changed(seconds: float)
## One-line status message for the HUD ("Track switch set to B"). Milestone 10 turns this into a log.
signal message_posted(text: String)
signal state_changed(state: State)
## The run ended. `won` is true on arrival; `reason` is a short line for the end screen.
signal game_over(won: bool, reason: String)

@export var delivery_time := 420.0 # 7:00
## Distance (TrainState units) that counts as arrived; the dashboard shows progress to it.
@export var route_length := 6000.0

var state := State.RUNNING
var time_left := delivery_time


func _ready() -> void:
	time_left = delivery_time


func _physics_process(delta: float) -> void:
	tick(delta)


## Separate from _physics_process so tests can drive it.
func tick(delta: float) -> void:
	if state != State.RUNNING:
		return

	# Arriving wins even if the timer runs out on the same frame.
	if TrainState.distance >= route_length:
		end_run(true, "Delivered on time")
		return

	var before := ceili(time_left)
	time_left = maxf(time_left - delta, 0.0)
	if ceili(time_left) != before:
		time_left_changed.emit(time_left) # once per displayed second
	if time_left <= 0.0:
		end_run(false, "Late delivery")


## Ends the run (once) and freezes the train. Also used by the debug panel.
func end_run(won: bool, reason: String) -> void:
	if state != State.RUNNING:
		return
	state = State.WON if won else State.LOST
	TrainState.frozen = true
	state_changed.emit(state)
	game_over.emit(won, reason)


func post_message(text: String) -> void:
	message_posted.emit(text)


## Back to a running run, same scene (the debug panel uses this).
func reset() -> void:
	state = State.RUNNING
	time_left = delivery_time
	TrainState.frozen = false
	time_left_changed.emit(time_left)
	state_changed.emit(state)


## Full restart: fresh state and a freshly loaded scene, so no stray coal or items
## stay behind and the player is back at the spawn.
func restart() -> void:
	reset()
	TrainState.reset()
	get_tree().reload_current_scene()


## "MM:SS" for dashboards and the debug panel.
func format_time(seconds: float = time_left) -> String:
	var total := ceili(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
