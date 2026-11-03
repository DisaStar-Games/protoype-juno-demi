extends Node

## The "virtual train": the train never moves physically, this node simulates it.
## Everything else (dashboard, furnace, events, debug panel) reads these values and
## listens to the signals. Registered as the autoload `TrainState`.

signal speed_changed(speed: float)
signal throttle_changed(throttle: float)
signal brake_changed(brake: float)
signal fuel_changed(fuel: float)
signal brake_fluid_changed(brake_fluid: float)
signal distance_changed(distance: float)
signal boost_changed(active: bool)
signal track_changed(track: StringName)
signal hallucinating_changed(active: bool)
## Dashboard warning light turned on/off. Ids: &"brakes", &"fire", &"gas", &"fuel".
signal warning_changed(id: StringName, active: bool)
## The horn button was pressed. Track events (Milestone 6) judge the timing from `distance`.
signal horn_sounded

@export_group("Speed")
@export var max_speed := 30.0
@export var acceleration := 3.0
## Slowing down when throttle is lowered or fuel runs out (no brake applied).
@export var coast_decel := 1.0
## Brake deceleration at full brake lever and full brake fluid.
@export var brake_decel := 8.0
@export var boost_speed_multiplier := 1.3

@export_group("Fuel")
@export var max_fuel := 100.0
@export var start_fuel := 50.0
## Fuel used per second at max speed (scales with speed).
@export var fuel_drain_at_max_speed := 0.4
@export var fuel_per_coal := 20.0

@export_group("Brakes")
@export var max_brake_fluid := 100.0
## Brake strength left when the fluid is completely empty (1 = unaffected).
@export var empty_fluid_brake_factor := 0.1

@export_group("Warnings")
## The FUEL light comes on below this fuel level.
@export var low_fuel_threshold := 20.0
## The BRAKES light comes on below this brake-fluid level.
@export var low_brake_fluid_threshold := 40.0

var speed := 0.0:
	set(value):
		value = maxf(value, 0.0)
		if value < 0.001:
			value = 0.0 # snap, so "stopped" is exactly 0 and not 0.00000000000002
		if speed != value:
			speed = value
			speed_changed.emit(speed)

## Throttle lever, 0..1.
var throttle := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(throttle, value):
			throttle = value
			throttle_changed.emit(throttle)

## Brake lever, 0..1.
var brake := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(brake, value):
			brake = value
			brake_changed.emit(brake)

var fuel := 0.0:
	set(value):
		value = clampf(value, 0.0, max_fuel)
		if not is_equal_approx(fuel, value):
			fuel = value
			fuel_changed.emit(fuel)
			_update_derived_warnings()

var brake_fluid := 0.0:
	set(value):
		value = clampf(value, 0.0, max_brake_fluid)
		if not is_equal_approx(brake_fluid, value):
			brake_fluid = value
			brake_fluid_changed.emit(brake_fluid)
			_update_derived_warnings()

## Distance travelled along the route, in units.
var distance := 0.0:
	set(value):
		if not is_equal_approx(distance, value):
			distance = value
			distance_changed.emit(distance)

var boost_active := false:
	set(value):
		if boost_active != value:
			boost_active = value
			boost_changed.emit(boost_active)

## Which side of the next track split the switch lever is set to: &"A" or &"B".
var current_track: StringName = &"A":
	set(value):
		if current_track != value:
			current_track = value
			track_changed.emit(current_track)

var hallucinating := false:
	set(value):
		if hallucinating != value:
			hallucinating = value
			hallucinating_changed.emit(hallucinating)


## Set by GameState when the run ends: the train stops simulating (speed and fuel hold).
var frozen := false

var _warnings := {&"brakes": false, &"fire": false, &"gas": false, &"fuel": false}


func _ready() -> void:
	reset()


func _physics_process(delta: float) -> void:
	simulate(delta)


## One simulation step. Separate from _physics_process so tests can drive it.
func simulate(delta: float) -> void:
	if frozen:
		return
	# Accelerate toward the throttle setting; no fuel means no power, so we coast down.
	var target := throttle * effective_max_speed() if fuel > 0.0 else 0.0
	if speed < target:
		speed = move_toward(speed, target, acceleration * delta)
	elif speed > target:
		speed = move_toward(speed, target, coast_decel * delta)

	# Brakes work against the current speed, weakened by low brake fluid.
	if brake > 0.0 and speed > 0.0:
		speed -= brake_decel * brake * brake_effectiveness() * delta

	distance += speed * delta

	# Fuel drains in proportion to speed.
	if speed > 0.0 and fuel > 0.0:
		fuel -= fuel_drain_at_max_speed * (speed / max_speed) * delta


## Speed of the scenery rushing past the windows (and the camera rumble): the train's
## speed, but 0 once the run has ended.
func world_speed() -> float:
	return 0.0 if frozen else speed


func effective_max_speed() -> float:
	return max_speed * (boost_speed_multiplier if boost_active else 1.0)


## 1 with a full reservoir, down to `empty_fluid_brake_factor` with an empty one.
func brake_effectiveness() -> float:
	return lerpf(empty_fluid_brake_factor, 1.0, brake_fluid / max_brake_fluid)


func add_fuel(amount: float) -> void:
	fuel += amount


func sound_horn() -> void:
	horn_sounded.emit()


## Turns a dashboard warning light on or off. FUEL and BRAKES are also driven by the
## fuel / brake-fluid levels; FIRE and GAS are only set by events (Milestones 5-7).
func set_warning(id: StringName, active: bool) -> void:
	if _warnings.get(id, active) != active:
		_warnings[id] = active
		warning_changed.emit(id, active)


func is_warning(id: StringName) -> bool:
	return _warnings.get(id, false)


func _update_derived_warnings() -> void:
	set_warning(&"fuel", fuel < low_fuel_threshold)
	set_warning(&"brakes", brake_fluid < low_brake_fluid_threshold)


## Back to a fresh run (also used by the debug panel).
func reset() -> void:
	speed = 0.0
	throttle = 0.0
	brake = 0.0
	fuel = start_fuel
	brake_fluid = max_brake_fluid
	distance = 0.0
	boost_active = false
	current_track = &"A"
	hallucinating = false
	set_warning(&"fire", false)
	set_warning(&"gas", false)
	_update_derived_warnings()
