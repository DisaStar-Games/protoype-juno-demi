extends TrainEvent

## The brake reservoir leaks. The BRAKES light comes on and the brake fluid drains, which
## weakens the brakes. Fix it by carrying the brake fluid bottle to the reservoir in the
## mechanical room and holding E to pour it in. If the reservoir stays empty for
## `fail_after_empty` seconds, the event fails.

## Brake fluid lost per second (the plan's 5/s empties a full reservoir in 20 s).
@export var leak_rate := 5.0
## Seconds with an empty reservoir before the event fails.
@export var fail_after_empty := 10.0
## Fluid level (as a fraction of the maximum) left after the event failed.
@export var fluid_after_fail := 0.3

var _empty_time := 0.0
var _reservoir: BrakeReservoir


func warning_message() -> String:
	return "Warning: brake fluid is leaking! Refill the reservoir."


func resolved_message() -> String:
	return "Reservoir refilled. The brakes are back."


func failed_message() -> String:
	return "The reservoir ran dry! The brakes are barely working."


func on_start() -> void:
	TrainState.set_warning(&"brakes", true)
	ItemPickup.ensure_available(get_tree(), &"brake_fluid")
	_reservoir = get_tree().get_first_node_in_group("brake_reservoir") as BrakeReservoir
	if _reservoir != null:
		_reservoir.needs_repair = true
		_reservoir.set_leaking(true)
		_reservoir.repaired.connect(_on_repaired, CONNECT_ONE_SHOT)


func process_event(delta: float) -> void:
	if state != State.ACTIVE:
		return
	TrainState.brake_fluid -= leak_rate * delta
	if TrainState.brake_fluid <= 0.0:
		_empty_time += delta
		if _empty_time >= fail_after_empty:
			fail()


func on_resolve() -> void:
	TrainState.brake_fluid = TrainState.max_brake_fluid
	_stop_leaking()


func on_fail() -> void:
	TrainState.brake_fluid = TrainState.max_brake_fluid * fluid_after_fail
	_stop_leaking()


func _on_repaired() -> void:
	resolve()


func _stop_leaking() -> void:
	TrainState.set_warning(&"brakes", false)
	if _reservoir != null:
		_reservoir.needs_repair = false
		_reservoir.set_leaking(false)
