extends TrainEvent

## A bandit raid. The bandits come from OUTSIDE (one on each side of the train): they run in,
## hang at a window (shoot them from the windows with the shotgun!), then climb in and walk
## through the train taking the coal and wrecking things (see Bandit). They leave after
## `stay_time` seconds inside (by default they stay until you shoot them, or there is nothing
## left to break); killing them all ends the raid. With `params.inside` they start inside,
## already in the train (a wrong junction).

@export var bandit_scene: PackedScene
@export var bandit_count := 2
## How long each bandit stays aboard, in seconds.
@export var stay_time := 100000.0

var _bandits: Array = []
var _killed := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func warning_message() -> String:
	return "Bandits are on the train! Grab the shotgun!" if params.get("inside", false) else "Bandits are closing in on the train! Grab the shotgun and shoot them from the windows!"


func resolved_message() -> String:
	return "You drove the bandits off." if _killed > 0 else "The bandits are gone, with your coal."


func on_start() -> void:
	EventManager.note_raid_started()
	ItemPickup.ensure_available(get_tree(), &"shotgun") # never leave the player unarmed
	var first_side := -1 if _rng.randf() < 0.5 else 1
	for i in bandit_count:
		var bandit := bandit_scene.instantiate() as Bandit
		add_child(bandit)
		bandit.stay_time = stay_time
		bandit.vanished.connect(_on_bandit_vanished)
		var side := first_side if i % 2 == 0 else -first_side # opposite sides
		bandit.start_outside(side, _rng.randf_range(6.0, 34.0))
		if params.get("inside", false):
			bandit.global_position = Vector3(side * 1.6, 0.0, bandit.window_z)
			bandit.start()
		_bandits.append(bandit)


func process_event(_delta: float) -> void:
	if state == State.ACTIVE and _bandits.is_empty():
		resolve()


func on_resolve() -> void:
	_cleanup()


func on_fail() -> void:
	_cleanup()


func on_cancel() -> void:
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


func task_text() -> String:
	return "Bandits aboard: kill them with the shotgun!"
