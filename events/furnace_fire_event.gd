extends TrainEvent

## The furnace overheated and caught fire. The fire burns until the player puts it out
## with the extinguisher (hold LMB and spray at the flames). While it burns the train has
## less power (TrainState.fire_power_factor) and, if it burns for `burn_time_limit`
## seconds, the event fails.
## Started automatically by EventManager when TrainState.furnace_overheated fires.

## Seconds the fire may burn before the event fails.
@export var burn_time_limit := 25.0

var _burned := 0.0
var _fire: FireSpot


func warning_message() -> String:
	return "The furnace is on fire! Get the extinguisher!"


func resolved_message() -> String:
	return "Fire out! Ease off the throttle and boost."


func failed_message() -> String:
	return "The furnace burned out of control!"


func on_start() -> void:
	TrainState.furnace_on_fire = true
	ItemPickup.ensure_available(get_tree(), &"extinguisher")
	_fire = get_tree().get_first_node_in_group("furnace_fire") as FireSpot
	if _fire != null:
		_fire.ignite()
		_fire.extinguished.connect(resolve, CONNECT_ONE_SHOT)


func process_event(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_burned += delta
	if _burned >= burn_time_limit:
		fail()


func on_resolve() -> void:
	_cool_down()


func on_fail() -> void:
	if _fire != null:
		_fire.put_out()
	_cool_down()


func _cool_down() -> void:
	TrainState.furnace_on_fire = false
	TrainState.furnace_temp = TrainState.temp_after_fire
