extends TrainEvent

## Throwaway event that exercises the whole framework (warning, beacon, resolve, fail,
## penalty). Resolve it by sounding the horn or using the radio once it is close enough;
## do nothing and it fails when the grace time after reaching it runs out.
## Milestone 6 replaces it with the real track events.

## The horn / radio only counts within this many units of the hazard.
@export var resolve_window := 250.0
## Seconds the player still has after the hazard is reached.
@export var grace_time := 2.0

var _grace := 0.0


func _ready() -> void:
	TrainState.horn_sounded.connect(_on_attempt.bind("horn"))
	TrainState.radio_called.connect(_on_attempt.bind("radio"))


func process_event(delta: float) -> void:
	if state == State.ACTIVE:
		_grace += delta
		if _grace >= grace_time:
			fail()


func _on_attempt(_source: String) -> void:
	if not is_live():
		return
	if remaining_distance() <= resolve_window:
		resolve()
	else:
		GameState.post_message("Too early! Wait until the %s is closer." % display_name.to_lower())
