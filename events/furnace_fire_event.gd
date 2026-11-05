extends TrainEvent

## The furnace overheated and caught fire. The fire burns until the player puts it out
## with the extinguisher (hold LMB and spray at the flames). While it burns the train has
## less power (TrainState.fire_power_factor). After `spread_delay` seconds it spreads over
## `spread_time` seconds: the flames grow and the train slows down until it stops
## (TrainState.fire_spread). The fire never fails or goes away by itself and costs no time
## penalty: only the extinguisher ends it.
## Started automatically by EventManager when TrainState.furnace_overheated fires.

## Seconds before the fire starts spreading.
@export var spread_delay := 0.0
## Seconds it takes to spread fully (the train is stopped by then).
@export var spread_time := 20.0
## How much bigger the flames (and the area to spray) get at full spread.
@export var spread_growth := 1.5

var _burned := 0.0
var _fire: FireSpot
var _base_radius := 1.0


func warning_message() -> String:
	return "The furnace is on fire! Get the extinguisher!"


func resolved_message() -> String:
	return "Fire out! Stay off the boost."


func failed_message() -> String:
	return "The furnace burned out of control!"


func on_start() -> void:
	TrainState.furnace_on_fire = true
	ItemPickup.ensure_available(get_tree(), &"extinguisher")
	_fire = get_tree().get_first_node_in_group("furnace_fire") as FireSpot
	if _fire != null:
		_base_radius = _fire.radius
		_fire.ignite()
		_fire.extinguished.connect(resolve, CONNECT_ONE_SHOT)


func process_event(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_burned += delta
	var spread := clampf(inverse_lerp(spread_delay, spread_delay + spread_time, _burned), 0.0, 1.0)
	TrainState.fire_spread = spread
	if is_instance_valid(_fire):
		_fire.scale = Vector3.ONE * (1.0 + spread_growth * spread)
		_fire.radius = _base_radius * (1.0 + spread_growth * spread)


func on_resolve() -> void:
	_cool_down()


func on_fail() -> void:
	if _fire != null:
		_fire.put_out()
	_cool_down()


func on_cancel() -> void:
	if is_instance_valid(_fire):
		_fire.put_out()
	# Only while still flagged: after a full reset the train is already clean.
	if TrainState.furnace_on_fire:
		_cool_down()


func _cool_down() -> void:
	TrainState.fire_spread = 0.0
	if is_instance_valid(_fire):
		_fire.scale = Vector3.ONE
		_fire.radius = _base_radius
	TrainState.furnace_on_fire = false
	TrainState.furnace_temp = TrainState.temp_after_fire


func task_text() -> String:
	return "Put out the furnace fire with the extinguisher!"
