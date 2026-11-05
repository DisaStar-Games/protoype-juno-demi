extends TrainEvent

## A pipe in the gas chamber starts leaking. It begins silently: the player slowly
## hallucinates (screen wobble and tint, and fake hazards in the cockpit window) and the
## GAS light is on from the start. Fix it with the wrench from the cockpit shelf: find the
## hissing joint in the gas chamber and hold E on it. If the hallucinations stay at full
## strength for `fail_hold_time` seconds, the event fails. The leak also slows the train down
## until it stops after `stop_time` seconds (TrainState.gas_spread).

## Hallucination intensity gained per second (the plan's 2 %/s = 50 s to the maximum).
@export var intensity_rate := 0.02
## The warning message about the gas comes at this intensity (the GAS light is on from the start).
@export_range(0.0, 1.0) var gas_light_intensity := 0.4
## Seconds until the leak has stopped the train.
@export var stop_time := 20.0
## Seconds at full intensity before the event fails.
@export var fail_hold_time := 10.0
@export_group("Hallucinated hazards")
@export var fake_hazard_scene: PackedScene
## Fake hazards start once the intensity passes this.
@export_range(0.0, 1.0) var fake_min_intensity := 0.25
## Seconds between fake hazards: this long at the start, shrinking toward `fake_interval_min`.
@export var fake_interval_max := 20.0
@export var fake_interval_min := 6.0
@export var max_fakes := 2

var _point: RepairPoint
var _full_time := 0.0
var _elapsed := 0.0
var _next_fake := 0.0
var _gas_light_announced := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func warning_message() -> String:
	return "" # the leak starts silently


func resolved_message() -> String:
	return "Leak fixed. The air is clearing."


func failed_message() -> String:
	return "The gas got to you! Someone patched the leak."


func on_start() -> void:
	TrainState.gas_leaking = true
	TrainState.set_warning(&"gas", true) # the light is on from the first moment of the effect
	ItemPickup.ensure_available(get_tree(), &"wrench")
	var points := get_tree().get_nodes_in_group("gas_leak_points")
	if points.is_empty():
		return
	var index: int = params.get("leak_index", -1)
	if index < 0 or index >= points.size():
		index = _rng.randi_range(0, points.size() - 1)
	_point = points[index] as RepairPoint
	_point.needs_repair = true
	_point.set_leaking(true)
	_point.repaired.connect(resolve, CONNECT_ONE_SHOT)
	_next_fake = fake_interval_max


func process_event(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_elapsed += delta
	TrainState.gas_spread = clampf(_elapsed / stop_time, 0.0, 1.0)
	TrainState.hallucination_intensity += intensity_rate * delta
	var intensity: float = TrainState.hallucination_intensity

	if intensity >= gas_light_intensity and not _gas_light_announced:
		_gas_light_announced = true
		GameState.post_message("Warning: gas detected! Find the leak, you'll need a wrench.")

	if intensity >= 1.0:
		_full_time += delta
		if _full_time >= fail_hold_time:
			fail()
			return

	if fake_hazard_scene != null and intensity >= fake_min_intensity:
		_next_fake -= delta
		if _next_fake <= 0.0:
			_spawn_fake_hazard()
			var t := inverse_lerp(fake_min_intensity, 1.0, intensity)
			_next_fake = lerpf(fake_interval_max, fake_interval_min, t) * _rng.randf_range(0.7, 1.3)


func on_resolve() -> void:
	_stop_leaking()


func on_fail() -> void:
	_stop_leaking()


func on_cancel() -> void:
	_stop_leaking()


func _spawn_fake_hazard() -> void:
	var live_fakes := 0
	for event in EventManager.events:
		if event.silent and event.is_live():
			live_fakes += 1
	if live_fakes < max_fakes:
		EventManager.start_event(fake_hazard_scene)


func _stop_leaking() -> void:
	TrainState.gas_leaking = false # the hallucinations now fade out by themselves
	TrainState.gas_spread = 0.0
	TrainState.set_warning(&"gas", false)
	if is_instance_valid(_point):
		_point.needs_repair = false
		_point.set_leaking(false)


func task_text() -> String:
	return "Fix the gas leak: find the hissing pipe (hold E)"
