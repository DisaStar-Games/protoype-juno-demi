extends TrainEvent

## Bandits waiting by the track ahead. Pass them at `escape_speed` or faster (boost helps,
## but it heats the furnace) and you outrun them. Slower, and they catch the train and
## board it: a bandit raid starts (events/bandit_raid_event.tscn), they steal coal and
## wreck equipment.

@export var escape_speed := 22.0
## Started when the bandits get on the train.
@export var raid_scene: PackedScene


func warning_message() -> String:
	return "Warning: bandits ahead! Speed up to outrun them."


func resolved_message() -> String:
	return "You outran the bandits!"


func failed_message() -> String:
	return "The bandits caught the train and climbed aboard!"


func on_start() -> void:
	if TrainState.speed >= escape_speed:
		resolve()
	else:
		fail()


func on_fail() -> void:
	crash_effects(0.4)
	if raid_scene != null:
		EventManager.start_event(raid_scene, true)
