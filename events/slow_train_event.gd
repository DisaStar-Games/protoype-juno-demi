extends TrainEvent

## A slower train ahead, moving at `slow_speed`. The train drives by itself, so when you catch up
## with it you must be at or below its speed (plus `speed_tolerance`), or it is a COLLISION. Stay
## behind it for `follow_time` seconds and it pulls away. If you fall so far behind that
## it gets `give_up_distance` ahead, it simply turned off the line.
## **The radio avoids it:** press the radio and the slow train clears the line
## at once (the event is resolved).
## A collision (see on_fail) is a crash: a hard shake, the train brakes to a stop, the
## furnace catches fire, the coolant and the pipes start leaking and the console is
## wrecked (EventManager.wreck_train).

@export var slow_speed := 12.0
@export var speed_tolerance := 2.0
@export var follow_time := 8.0
@export var give_up_distance := 600.0
## How fast the train ahead speeds up after a radio call, in u/s^2.
@export var speedup_rate := 6.0

var _speed := 0.0
var _speeding_up := false
var _following := 0.0


func _ready() -> void:
	_speed = slow_speed
	TrainState.radio_called.connect(_on_radio)


func warning_message() -> String:
	return "Warning: slow train ahead! Use the radio!"


func resolved_message() -> String:
	return "The slow train sped up and cleared the line." if _speeding_up else "The slow train pulled away."


func failed_message() -> String:
	return "COLLISION! The train is wrecked: put out the fire, fix the leaks and repair the console."


func process_event(delta: float) -> void:
	if _speeding_up:
		_speed += speedup_rate * delta
		if _speed > TrainState.speed + speed_tolerance:
			resolve() # clearly faster than us now: it is gone
			return
	if state == State.WARNING:
		trigger_distance += _speed * delta # it keeps moving away from us
		if remaining_distance() > give_up_distance:
			resolve()
	elif state == State.ACTIVE:
		trigger_distance = TrainState.distance # we are right behind it
		if TrainState.speed > _speed + speed_tolerance:
			fail()
			return
		_following += delta
		if _following >= follow_time:
			resolve()


func on_fail() -> void:
	EventManager.wreck_train()
	crash_effects(1.0)


func _on_radio() -> void:
	if is_live() and not _speeding_up:
		_speeding_up = true
		GameState.post_message("Radio: the slow train ahead is clearing the line.")
		resolve()


func task_text() -> String:
	return "Slow train ahead: use the radio"
