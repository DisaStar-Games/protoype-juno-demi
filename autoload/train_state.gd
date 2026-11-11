extends Node

## The "virtual train": the train never moves physically, this node simulates it.
## Everything else (dashboard, furnace, events, debug panel) reads these values and
## listens to the signals. Registered as the autoload `TrainState`.

signal speed_changed(speed: float)
signal fuel_changed(fuel: float)
signal coolant_changed(coolant: float)
signal distance_changed(distance: float)
signal boost_changed(active: bool)
signal track_changed(track: StringName)
signal hallucinating_changed(active: bool)
signal hallucination_changed(intensity: float)
signal furnace_temp_changed(temp: float)
## The furnace reached its maximum temperature (EventManager answers with a fire).
signal furnace_overheated
signal furnace_fire_changed(active: bool)
## A system (see SYSTEMS) was damaged or repaired.
signal system_damage_changed(id: StringName, damaged: bool)
## Dashboard warning light turned on/off. Ids: &"coolant", &"fire", &"gas", &"fuel", &"temp", &"damage".
signal warning_changed(id: StringName, active: bool)
## The horn button was pressed. Track events (Milestone 6) judge the timing from `distance`.
signal horn_sounded
## The radio was used. Events can be resolved by calling the track regulator.
signal radio_called

## Systems that can be switched off. Only the console (&"controls") is left: while it is
## damaged (bandits, a collision) none of its controls work and the engine has no power, until
## it is repaired at its panel (objects/system_repair_point.tscn) with the wrench. The furnace,
## coolant tank and pipes break through their own events instead (fire, coolant leak, gas leak).
const SYSTEMS: Array[StringName] = [&"controls"]

@export_group("Speed")
## The train drives by itself: this is its cruising speed when nothing is wrong.
@export var max_speed := 20.0
@export var acceleration := 3.0
## Slowing down when something is broken or the fuel runs out.
@export var coast_decel := 1.5
@export var boost_speed_multiplier := 1.3

@export_group("Fuel")
@export var max_fuel := 100.0
@export var start_fuel := 50.0
## Fuel used per second at max speed (scales with speed).
@export var fuel_drain_at_max_speed := 0.4
@export var fuel_per_coal := 20.0

@export_group("Coolant")
@export var max_coolant := 100.0
## Cooling strength left when the coolant is completely empty (1 = unaffected).
@export var empty_coolant_cooling_factor := 0.1
## Top speed multiplier when the coolant is empty (scales up to 1 at `low_coolant_threshold`).
@export var empty_coolant_speed_factor := 0.5

@export_group("Furnace")
@export var max_furnace_temp := 100.0
## Heat gained per second while the train is running (and there is fuel to burn).
@export var heat_rate_running := 1.5
## Extra heat per second while boost is on. Boost always heats the furnace, so leaving it on
## always ends in an overheat.
@export var heat_rate_boost := 9.0
## Heat lost per second with full coolant. Less coolant cools less.
@export var cool_rate := 5.0
## The TEMP warning light comes on from this temperature.
@export var high_temp_threshold := 70.0
## Temperature the furnace drops back to once its fire is out.
@export var temp_after_fire := 50.0

@export_group("Wear")
## Top speed multipliers while something is broken (1 = no effect). A broken console cuts the
## power completely.
@export var fire_power_factor := 0.5
## Same, once the fire has spread all over (it scales in from `fire_power_factor`): 0 = stopped.
@export var spread_fire_power_factor := 0.0

@export_group("Damage")
## How hard a collision brakes the train to a stop (u/s^2).
@export var emergency_decel := 14.0

@export_group("Hallucinations")
## Intensity lost per second once the gas leak is fixed.
@export var hallucination_decay := 0.05

@export_group("Warnings")
## The FUEL light comes on below this fuel level.
@export var low_fuel_threshold := 20.0
## The COOLANT light comes on below this coolant level.
@export var low_coolant_threshold := 40.0

var speed := 0.0:
	set(value):
		value = maxf(value, 0.0)
		if value < 0.001:
			value = 0.0 # snap, so "stopped" is exactly 0 and not 0.00000000000002
		if speed != value:
			speed = value
			speed_changed.emit(speed)

var fuel := 0.0:
	set(value):
		value = clampf(value, 0.0, max_fuel)
		if not is_equal_approx(fuel, value):
			fuel = value
			fuel_changed.emit(fuel)
			_update_derived_warnings()

var coolant := 0.0:
	set(value):
		value = clampf(value, 0.0, max_coolant)
		if not is_equal_approx(coolant, value):
			coolant = value
			coolant_changed.emit(coolant)
			_update_derived_warnings()

## Furnace temperature, 0..max_furnace_temp. Rises with boost and a low coolant level.
var furnace_temp := 0.0:
	set(value):
		value = clampf(value, 0.0, max_furnace_temp)
		if not is_equal_approx(furnace_temp, value):
			furnace_temp = value
			furnace_temp_changed.emit(furnace_temp)
			_update_derived_warnings()

## 0..1: how far the unattended fire has spread (set by the furnace fire event).
var fire_spread := 0.0
## 0..1: how far the gas leak has slowed the train (1 = stopped). Set by the gas leak event.
var gas_spread := 0.0

## True while the overheated furnace burns. Set by the furnace fire event.
var furnace_on_fire := false:
	set(value):
		if furnace_on_fire != value:
			furnace_on_fire = value
			set_warning(&"fire", value)
			furnace_fire_changed.emit(furnace_on_fire)

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

## How strongly the player is hallucinating, 0..1 (the gas leak raises it).
var hallucination_intensity := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(hallucination_intensity, value):
			var was := hallucination_intensity > 0.0
			hallucination_intensity = value
			hallucination_changed.emit(hallucination_intensity)
			if was != (hallucination_intensity > 0.0):
				hallucinating_changed.emit(hallucination_intensity > 0.0)

## Convenience on/off view of the intensity (setting it true means a medium 0.5).
var hallucinating: bool:
	get:
		return hallucination_intensity > 0.0
	set(value):
		hallucination_intensity = 0.5 if value else 0.0

## True while a gas leak feeds the hallucinations; otherwise they fade out by themselves.
var gas_leaking := false

## Set by GameState when the run ends: the train stops simulating (speed and fuel hold).
var frozen := false

## A collision happened: the train brakes hard to a stop (and every system is damaged).
var emergency_stop := false

var _damaged := {&"controls": false}

# Warning lights: an id is lit when an event forces it (set_warning) or the level of
# something derives it (low fuel, low coolant, hot furnace).
var _forced := {&"coolant": false, &"fire": false, &"gas": false, &"fuel": false, &"temp": false, &"damage": false}
var _derived := {&"coolant": false, &"fire": false, &"gas": false, &"fuel": false, &"temp": false, &"damage": false}
var _warnings := {&"coolant": false, &"fire": false, &"gas": false, &"fuel": false, &"temp": false, &"damage": false}
var _overheat_announced := false


func _ready() -> void:
	reset()


func _physics_process(delta: float) -> void:
	simulate(delta)


## One simulation step. Separate from _physics_process so tests can drive it.
func simulate(delta: float) -> void:
	if frozen:
		return
	# The train drives itself toward its target speed; a collision brakes hard to a stop first.
	var target := target_speed()
	if emergency_stop:
		speed = move_toward(speed, 0.0, emergency_decel * delta)
		if speed == 0.0:
			emergency_stop = false
	elif speed < target:
		speed = move_toward(speed, target, acceleration * delta)
	elif speed > target:
		speed = move_toward(speed, target, coast_decel * delta)

	distance += speed * delta

	# Fuel drains in proportion to speed.
	if speed > 0.0 and fuel > 0.0:
		fuel -= fuel_drain_at_max_speed * (speed / max_speed) * delta

	_simulate_furnace(delta)

	if not gas_leaking and hallucination_intensity > 0.0:
		hallucination_intensity -= hallucination_decay * delta


## Running and boosting heat the furnace (only while there is fuel to burn), the coolant cools
## it. At the maximum it overheats, which the fire event answers.
func _simulate_furnace(delta: float) -> void:
	var heat := 0.0
	if fuel > 0.0 and not any_system_damaged():
		heat += heat_rate_running
		if boost_active:
			heat += heat_rate_boost
	var cooling := cool_rate * lerpf(empty_coolant_cooling_factor, 1.0, coolant / max_coolant)

	if furnace_on_fire:
		furnace_temp = max_furnace_temp # keeps burning at the top until it is put out
	else:
		furnace_temp += (heat - cooling) * delta

	if furnace_temp >= max_furnace_temp:
		if not furnace_on_fire and not _overheat_announced:
			_overheat_announced = true
			furnace_overheated.emit()
	else:
		_overheat_announced = false


## Speed of the scenery rushing past the windows (and the camera rumble): the train's
## speed, but 0 once the run has ended.
func world_speed() -> float:
	return 0.0 if frozen else speed


## Top speed right now: cruising speed, boosted, and slowed by everything that is broken.
func effective_max_speed() -> float:
	return max_speed * (boost_speed_multiplier if boost_active else 1.0) * wear_factor()


## 1 with a healthy train, lower for every broken part: a fire and a gas leak (both bring the
## train to a halt in ~20 s if left alone), low coolant.
func wear_factor() -> float:
	var factor := 1.0
	if furnace_on_fire:
		factor *= lerpf(fire_power_factor, spread_fire_power_factor, fire_spread)
	factor *= 1.0 - gas_spread # a gas leak slows the train down to a halt
	factor *= lerpf(empty_coolant_speed_factor, 1.0, clampf(coolant / low_coolant_threshold, 0.0, 1.0))
	return factor


## The speed the train is heading for: 0 without fuel or power (a broken console).
func target_speed() -> float:
	if fuel <= 0.0 or any_system_damaged():
		return 0.0
	return effective_max_speed()


func add_fuel(amount: float) -> void:
	fuel += amount


func sound_horn() -> void:
	horn_sounded.emit()


func call_radio() -> void:
	radio_called.emit()


## Damages one system. While any system is damaged the engine has no power.
func damage_system(id: StringName) -> void:
	if _damaged.has(id) and not _damaged[id]:
		_damaged[id] = true
		system_damage_changed.emit(id, true)
		_update_derived_warnings()


func repair_system(id: StringName) -> void:
	if _damaged.has(id) and _damaged[id]:
		_damaged[id] = false
		system_damage_changed.emit(id, false)
		_update_derived_warnings()


func damage_all_systems() -> void:
	for id in SYSTEMS:
		damage_system(id)


func repair_all_systems() -> void:
	for id in SYSTEMS:
		repair_system(id)


func is_system_damaged(id: StringName) -> bool:
	return _damaged.get(id, false)


func damaged_system_count() -> int:
	var count := 0
	for id in SYSTEMS:
		if _damaged[id]:
			count += 1
	return count


func any_system_damaged() -> bool:
	return damaged_system_count() > 0


## A crash: the train brakes hard to a stop and the console is wrecked (EventManager.wreck_train
## also sets the furnace on fire and starts the coolant and gas leaks).
func collide() -> void:
	emergency_stop = true
	damage_all_systems()


## Forces a dashboard warning light on or off (events use this). The light also stays
## on while its level-based condition holds: FUEL below `low_fuel_threshold`, COOLANT
## below `low_coolant_threshold`, TEMP from `high_temp_threshold`.
func set_warning(id: StringName, active: bool) -> void:
	if not _warnings.has(id):
		return
	_forced[id] = active
	_refresh_warning(id)


func is_warning(id: StringName) -> bool:
	return _warnings.get(id, false)


func _update_derived_warnings() -> void:
	_derived[&"fuel"] = fuel < low_fuel_threshold
	_derived[&"coolant"] = coolant < low_coolant_threshold
	_derived[&"temp"] = furnace_temp >= high_temp_threshold
	_derived[&"damage"] = any_system_damaged()
	for id in _warnings:
		_refresh_warning(id)


func _refresh_warning(id: StringName) -> void:
	var lit: bool = _forced[id] or _derived[id]
	if _warnings[id] != lit:
		_warnings[id] = lit
		warning_changed.emit(id, lit)


## Back to a fresh run (also used by the debug panel).
func reset() -> void:
	speed = 0.0
	fuel = start_fuel
	coolant = max_coolant
	furnace_on_fire = false
	fire_spread = 0.0
	gas_spread = 0.0
	furnace_temp = 0.0
	_overheat_announced = false
	distance = 0.0
	boost_active = false
	current_track = &"A"
	gas_leaking = false
	hallucination_intensity = 0.0
	emergency_stop = false
	repair_all_systems() # emits, so the repair panels stop smoking
	for id in _forced:
		_forced[id] = false
	_update_derived_warnings()
