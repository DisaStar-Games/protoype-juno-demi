extends TrainEvent

## The track splits in two. When the train reaches the junction the track switch must be on
## the correct branch (A or B), otherwise bandits jump on the train (no time penalty). The correct branch
## is always the opposite of where the switch stood when the junction appeared, so every
## junction means flipping the switch once.
## `reveal_distance` > 0 shows the correct branch on the beacon sign from that close.

## Force the correct track (&"A" or &"B"); empty = random. Also settable as params.correct_track.
@export var correct_track: StringName = &""
## Show the correct track on the sign within this many units (0 = never, a pure guess).
@export var reveal_distance := 0.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if params.has("correct_track"):
		correct_track = StringName(params["correct_track"])
	if correct_track == &"":
		correct_track = &"B" if TrainState.current_track == &"A" else &"A"


func sign_text() -> String:
	var distance := maxi(0, roundi(remaining_distance()))
	if reveal_distance > 0.0 and remaining_distance() <= reveal_distance:
		return "JUNCTION\nsignal: %s\n%d u" % [correct_track, distance]
	return "JUNCTION\nflip to %s\n%d u" % [correct_track, distance]


func warning_message() -> String:
	return "Warning: junction ahead! Flip the track switch to %s." % correct_track


func resolved_message() -> String:
	return "Right track!"


func failed_message() -> String:
	return "Wrong track! Bandits jumped on the train!"


func on_start() -> void:
	if TrainState.current_track == correct_track:
		resolve()
	else:
		fail()


## The wrong branch leads into bandit land: they are in the train at once.
func on_fail() -> void:
	crash_effects(0.4)
	if EventManager.raid_event != null and EventManager.bandits_allowed():
		EventManager.start_event(EventManager.raid_event, true, {"inside": true})


func task_text() -> String:
	if TrainState.current_track == correct_track:
		return ""
	return "Junction in %d u: set the track switch to %s" % [maxi(0, roundi(remaining_distance())), correct_track]
