extends Node3D

## Cockpit dashboard. Pure view: every value comes from TrainState / GameState signals.

@onready var speed_gauge: Gauge = %SpeedGauge
@onready var fuel_gauge: Gauge = %FuelGauge
@onready var brake_fluid_gauge: Gauge = %BrakeFluidGauge
@onready var timer_gauge: Gauge = %TimerGauge
@onready var route_gauge: Gauge = %RouteGauge
@onready var temp_gauge: Gauge = %TempGauge


func _ready() -> void:
	TrainState.speed_changed.connect(_update_speed)
	TrainState.fuel_changed.connect(_update_fuel)
	TrainState.brake_fluid_changed.connect(_update_brake_fluid)
	TrainState.distance_changed.connect(_update_route)
	TrainState.furnace_temp_changed.connect(_update_temp)
	EventManager.events_changed.connect(_on_events_changed)
	GameState.time_left_changed.connect(_update_timer)

	_update_speed(TrainState.speed)
	_update_fuel(TrainState.fuel)
	_update_brake_fluid(TrainState.brake_fluid)
	_update_route(TrainState.distance)
	_update_temp(TrainState.furnace_temp)
	_update_timer(GameState.time_left)


func _update_speed(speed: float) -> void:
	var top_speed: float = TrainState.max_speed * TrainState.boost_speed_multiplier
	speed_gauge.set_value(speed / top_speed, "%.1f u/s" % speed)


func _update_fuel(fuel: float) -> void:
	fuel_gauge.set_value(fuel / TrainState.max_fuel, "%d%%" % roundi(100.0 * fuel / TrainState.max_fuel))


func _update_brake_fluid(fluid: float) -> void:
	brake_fluid_gauge.set_value(fluid / TrainState.max_brake_fluid, "%d%%" % roundi(100.0 * fluid / TrainState.max_brake_fluid))


func _update_route(distance: float) -> void:
	var progress: float = clampf(distance / GameState.route_length, 0.0, 1.0)
	var text := "%d%%" % roundi(progress * 100.0)
	for event in EventManager.events:
		if event.id == &"track_split" and event.is_live():
			text = "SPLIT %d u" % maxi(0, roundi(event.remaining_distance())) # a junction is coming
			break
	route_gauge.set_value(progress, text)


func _update_timer(seconds: float) -> void:
	timer_gauge.set_value(0.0, GameState.format_time(seconds))


func _update_temp(temp: float) -> void:
	var ratio: float = temp / TrainState.max_furnace_temp
	temp_gauge.set_value(ratio, "%d" % roundi(temp))
	temp_gauge.set_fill_color(Gauge.heat_color(ratio))


func _on_events_changed() -> void:
	_update_route(TrainState.distance)
