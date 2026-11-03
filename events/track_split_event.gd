extends TrainEvent

## The track splits in two. When the train reaches the junction the track switch must be on
## the correct branch (A or B), otherwise it is a detour: a time penalty. The correct branch
## is random, so without more information (the radio will give it, later) it is a guess.
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
		correct_track = &"A" if _rng.randf() < 0.5 else &"B"


func sign_text() -> String:
	var distance := maxi(0, roundi(remaining_distance()))
	if reveal_distance > 0.0 and remaining_distance() <= reveal_distance:
		return "JUNCTION\nsignal: %s\n%d u" % [correct_track, distance]
	return "JUNCTION\nA | B\n%d u" % distance


func warning_message() -> String:
	return "Warning: junction ahead! Set the track switch."


func resolved_message() -> String:
	return "Right track!"


func failed_message() -> String:
	return "Wrong track! The detour costs you time."


func on_start() -> void:
	if TrainState.current_track == correct_track:
		resolve()
	else:
		fail()
