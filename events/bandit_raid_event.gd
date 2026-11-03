extends TrainEvent

## The bandits are on the train. They come in at the rear and walk through the train: they
## take the coal (fuel and the pile, which stays empty while they are aboard) and wreck
## systems one by one (a damaged system cuts the engine's power until you repair it with
## the wrench). They leave after `stay_time` seconds. There is no weapon yet: Bandit.hit()
## is the hook for it, and killing them all ends the raid early.

@export var bandit_scene: PackedScene
@export var bandit_count := 2
## How long each bandit stays aboard, in seconds.
@export var stay_time := 45.0

var _bandits: Array = []
var _killed := 0


func warning_message() -> String:
	return "The bandits are on the train! They're after your coal and the equipment!"


func resolved_message() -> String:
	return "You drove the bandits off." if _killed > 0 else "The bandits are gone, with your coal."


func on_start() -> void:
	for i in bandit_count:
		var bandit := bandit_scene.instantiate() as Bandit
		add_child(bandit)
		bandit.stay_time = stay_time
		bandit.global_position = Vector3(-0.6 + 1.2 * i, 0.0, 39.3 - 0.6 * i)
		bandit.vanished.connect(_on_bandit_vanished)
		bandit.start()
		_bandits.append(bandit)


func process_event(_delta: float) -> void:
	if state == State.ACTIVE and _bandits.is_empty():
		resolve()


func on_resolve() -> void:
	_cleanup()


func on_fail() -> void:
	_cleanup()


func _on_bandit_vanished(reason: StringName) -> void:
	if reason == &"killed":
		_killed += 1
	for bandit in _bandits.duplicate():
		if not is_instance_valid(bandit) or bandit.done:
			_bandits.erase(bandit)


## Whoever is left goes away, and the coal pile is restocked.
func _cleanup() -> void:
	for bandit in _bandits.duplicate(): # cancelling edits the list through `vanished`
		if is_instance_valid(bandit):
			bandit.cancel()
	_bandits.clear()
	var pile := get_tree().get_first_node_in_group("coal_pile")
	if pile != null:
		pile.stolen = false
