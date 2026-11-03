extends TrainEvent

## A hazard that is only in the player's head (gas leak hallucination). It looks like a
## real hazard beacon in the cockpit window and closing in, but when it is "reached" it
## simply vanishes. Silent: no messages, no penalty, not relayed by EventManager.

const NAMES: Array[String] = ["Slow train", "Bandits", "People on the track", "Obstacle"]


func _ready() -> void:
	display_name = NAMES.pick_random()


func on_start() -> void:
	resolve() # it was never there
