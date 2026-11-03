extends TrainEvent

## People (or an animal) on the track ahead. Sound the horn while they are between
## `honk_window_far` and `honk_window_near` units ahead and they scramble off. Too early
## they can't hear you; too late, or never, and you hit them: a scare and a time penalty.

@export var honk_window_far := 250.0
@export var honk_window_near := 80.0


func _ready() -> void:
	TrainState.horn_sounded.connect(_on_horn)


func warning_message() -> String:
	return "Warning: people on the track ahead! Sound the horn."


func resolved_message() -> String:
	return "They scrambled off the track."


func failed_message() -> String:
	return "You hit someone on the track!"


func on_start() -> void:
	fail() # reached them without a good honk


func on_fail() -> void:
	crash_effects(0.7)


func _on_horn() -> void:
	if not is_live():
		return
	var remaining := remaining_distance()
	if remaining > honk_window_far:
		GameState.post_message("Too early! They can't hear the horn yet.")
	elif remaining < honk_window_near:
		GameState.post_message("Too late!")
	else:
		resolve()
