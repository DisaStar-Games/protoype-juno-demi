extends TrainEvent

## A slower train ahead, moving at `slow_speed`. Brake in time: when you catch up with it
## you must be at or below its speed (plus `speed_tolerance`), or it is a COLLISION. Stay
## behind it for `follow_time` seconds and it pulls away. If you fall so far behind that
## it gets `give_up_distance` ahead, it simply turned off the line.
## A collision (see on_fail) brakes the train to a stop and wrecks every system; they all
## have to be repaired before the engine runs again.

@export var slow_speed := 12.0
@export var speed_tolerance := 2.0
@export var follow_time := 8.0
@export var give_up_distance := 600.0

var _following := 0.0


func warning_message() -> String:
	return "Warning: slow train ahead! Brake before you catch up."


func resolved_message() -> String:
	return "The slow train pulled away."


func failed_message() -> String:
	return "COLLISION! The train is wrecked. Repair every system to get moving again."


func process_event(delta: float) -> void:
	if state == State.WARNING:
		trigger_distance += slow_speed * delta # it keeps moving away from us
		if remaining_distance() > give_up_distance:
			resolve()
	elif state == State.ACTIVE:
		trigger_distance = TrainState.distance # we are right behind it
		if TrainState.speed > slow_speed + speed_tolerance:
			fail()
			return
		_following += delta
		if _following >= follow_time:
			resolve()


func on_fail() -> void:
	TrainState.collide()
	crash_effects(1.0)
