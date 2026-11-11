extends TrainEvent

## The coolant tank leaks. The COOLANT light comes on and the coolant drains: the furnace
## cools worse (it heats up on its own) and the train slows down. Fix it by carrying the
## coolant bottle to the tank in the mechanical room and holding E to pour it in. If the
## tank stays empty for `fail_after_empty` seconds, the event fails.

## Coolant lost per second (5/s empties a full tank in 20 s).
@export var leak_rate := 5.0
## Seconds with an empty tank before the event fails.
@export var fail_after_empty := 10.0
## Fluid level (as a fraction of the maximum) left after the event failed.
@export var fluid_after_fail := 0.3

var _empty_time := 0.0
var _tank: CoolantTank


func warning_message() -> String:
	return "Warning: coolant is leaking! Refill the tank."


func resolved_message() -> String:
	return "Tank refilled. The furnace can cool again."


func failed_message() -> String:
	return "The tank ran dry! The furnace will overheat and the train slows down."


func on_start() -> void:
	TrainState.set_warning(&"coolant", true)
	ItemPickup.ensure_available(get_tree(), &"coolant")
	_tank = get_tree().get_first_node_in_group("coolant_tank") as CoolantTank
	if _tank != null:
		_tank.needs_repair = true
		_tank.set_leaking(true)
		_tank.repaired.connect(_on_repaired, CONNECT_ONE_SHOT)


func process_event(delta: float) -> void:
	if state != State.ACTIVE:
		return
	TrainState.coolant -= leak_rate * delta
	if TrainState.coolant <= 0.0:
		_empty_time += delta
		if _empty_time >= fail_after_empty:
			fail()


func on_resolve() -> void:
	TrainState.coolant = TrainState.max_coolant
	_stop_leaking()


func on_fail() -> void:
	TrainState.coolant = TrainState.max_coolant * fluid_after_fail
	_stop_leaking()


func _on_repaired() -> void:
	resolve()


func on_cancel() -> void:
	_stop_leaking()


func _stop_leaking() -> void:
	TrainState.set_warning(&"coolant", false)
	if is_instance_valid(_tank):
		_tank.needs_repair = false
		_tank.set_leaking(false)


func task_text() -> String:
	return "Refill the coolant tank (hold E)"
