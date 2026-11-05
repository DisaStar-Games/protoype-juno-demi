extends TrainEvent

## Bandits chasing the train. Boost (stay above `escape_speed`, 20.1 u/s) to pull away from them:
## the gap (0..1, shown on the map) starts at half, grows while you are fast enough and shrinks
## while you are not. Full gap and they give up; empty gap and they board the train: a bandit
## raid starts (events/bandit_raid_event.tscn).
## The boost heats the furnace, so the time you must boost is worked out when the chase starts:
## `overheat_margin` of the time the furnace needs to overheat from its current temperature. Boost
## for that long and then let go. They come at random (the beacon warns about them on the track)
## and at every checkpoint of the route, but not within a minute of the last raid.

@export var escape_speed := 20.1
## Seconds of boosting needed are limited to this range.
@export var min_chase_time := 6.0
@export var max_chase_time := 30.0
## Fraction of the time-to-overheat the player has to boost (below 1 = a safe margin).
@export_range(0.1, 1.0) var overheat_margin := 0.8
## Seconds below the escape speed that let them catch up completely.
@export var slow_limit := 5.0
## Seconds at the start in which being slow costs nothing (time to reach the boost button).
@export var grace_time := 3.0
## Started when the bandits get on the train.
@export var raid_scene: PackedScene

## How far ahead of the bandits the train is, 0 = they board, 1 = they gave up.
var gap := 0.5
## Seconds of boosting the escape needs.
var chase_time := 15.0
var _warned_slow := false
var _elapsed := 0.0


func warning_message() -> String:
	return "Warning: bandits ahead! Be ready to boost."


func resolved_message() -> String:
	return "You outran the bandits! Let go of the boost."


func failed_message() -> String:
	return "The bandits caught the train and climbed aboard!"


func on_start() -> void:
	chase_time = clampf(_time_to_overheat() * overheat_margin, min_chase_time, max_chase_time)
	GameState.post_message("Bandits are chasing the train! Boost for %d s, then let go!" % roundi(chase_time))


func task_text() -> String:
	if state == State.ACTIVE:
		return "Bandits chasing: boost for %d s, then let go!" % ceili(boost_time_left())
	return "Bandits ahead: get ready to boost"


func process_event(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_elapsed += delta
	if TrainState.speed > escape_speed:
		gap += 0.5 * delta / chase_time
		_warned_slow = false
	elif _elapsed > grace_time:
		gap -= 0.5 * delta / slow_limit
		if gap < 0.3 and not _warned_slow:
			_warned_slow = true
			GameState.post_message("Too slow! The bandits are catching up!")
	if gap <= 0.0:
		gap = 0.0
		fail()
	elif gap >= 1.0:
		gap = 1.0
		resolve()


## Seconds of boosting still needed, for displays.
func boost_time_left() -> float:
	return (1.0 - gap) * 2.0 * chase_time


## How long the furnace takes to overheat from now with the boost on.
func _time_to_overheat() -> float:
	var cooling: float = TrainState.cool_rate * lerpf(TrainState.empty_coolant_cooling_factor, 1.0, TrainState.coolant / TrainState.max_coolant)
	var rate: float = TrainState.heat_rate_running + TrainState.heat_rate_boost - cooling
	if rate <= 0.0:
		return max_chase_time
	return (TrainState.max_furnace_temp - TrainState.furnace_temp) / rate


func on_fail() -> void:
	crash_effects(0.4)
	if raid_scene != null:
		EventManager.start_event(raid_scene, true)
