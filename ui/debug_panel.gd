extends DebugWindow

## F1 debug panel: live TrainState values and sliders to override them. Events have
## their own panel on F2 (ui/events_debug_panel.gd). Autoload `DebugPanel`, hidden by
## default. While open the cursor is free so the sliders can be used.

@onready var rows: VBoxContainer = %Rows

var _sliders := {}   # property name -> {slider, label, dragging}
var _toggles := {}   # property name -> CheckBox
var _warning_toggles := {}   # warning id -> CheckBox
var _system_toggles := {}   # system id -> CheckBox
var _info: Label
var _track_button: Button


func _ready() -> void:
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Mirror live values into the controls (unless the user is dragging that slider).
	for prop in _sliders:
		var row: Dictionary = _sliders[prop]
		var value: float = TrainState.get(prop)
		if not row.dragging:
			row.slider.set_value_no_signal(value)
		row.label.text = "%.2f" % value
	for prop in _toggles:
		_toggles[prop].set_pressed_no_signal(TrainState.get(prop))
	for id in _warning_toggles:
		_warning_toggles[id].set_pressed_no_signal(TrainState.is_warning(id))
	for id in _system_toggles:
		_system_toggles[id].set_pressed_no_signal(TrainState.is_system_damaged(id))
	_track_button.text = "Track switch: %s  (click to flip)" % TrainState.current_track
	_info.text = "Speed %.1f u/s   Distance %.0f u\nFuel %.0f%%   Brake strength %.0f%%\nDelivery timer (placeholder) %s" % [
		TrainState.speed,
		TrainState.distance,
		100.0 * TrainState.fuel / TrainState.max_fuel,
		100.0 * TrainState.brake_effectiveness(),
		GameState.format_time(),
	]


func _build() -> void:
	var title := Label.new()
	title.text = "DEBUG  (F1 to close, F2 for events)"
	rows.add_child(title)

	_info = Label.new()
	rows.add_child(_info)
	rows.add_child(HSeparator.new())

	_add_slider("Throttle", &"throttle", 0.0, 1.0, 0.05)
	_add_slider("Brake", &"brake", 0.0, 1.0, 0.05)
	_add_slider("Speed", &"speed", 0.0, TrainState.max_speed * TrainState.boost_speed_multiplier, 0.5)
	_add_slider("Fuel", &"fuel", 0.0, TrainState.max_fuel, 1.0)
	_add_slider("Brake fluid", &"brake_fluid", 0.0, TrainState.max_brake_fluid, 1.0)
	_add_slider("Furnace temp", &"furnace_temp", 0.0, TrainState.max_furnace_temp, 1.0)
	_add_slider("Hallucination", &"hallucination_intensity", 0.0, 1.0, 0.01)

	_add_toggle("Boost active", &"boost_active")
	_add_toggle("Hallucinating", &"hallucinating")
	_add_warning_toggle("Fire warning light", &"fire")
	_add_warning_toggle("Gas warning light", &"gas")
	for id in TrainState.SYSTEMS:
		_add_system_toggle("%s damaged" % String(id).capitalize(), id)

	_track_button = Button.new()
	_track_button.pressed.connect(func() -> void:
		TrainState.current_track = &"B" if TrainState.current_track == &"A" else &"A")
	rows.add_child(_track_button)

	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	var add_fuel := Button.new()
	add_fuel.text = "+20 fuel"
	add_fuel.pressed.connect(func() -> void: TrainState.add_fuel(20.0))
	buttons.add_child(add_fuel)
	var reset := Button.new()
	reset.text = "Reset train + timer"
	reset.pressed.connect(func() -> void:
		TrainState.reset()
		GameState.reset())
	buttons.add_child(reset)

	var ends := HBoxContainer.new()
	rows.add_child(ends)
	var win := Button.new()
	win.text = "Force win"
	win.pressed.connect(func() -> void: GameState.end_run(true, "Forced from debug panel"))
	ends.add_child(win)
	var lose := Button.new()
	lose.text = "Force lose"
	lose.pressed.connect(func() -> void: GameState.end_run(false, "Forced from debug panel"))
	ends.add_child(lose)


func _add_slider(title: String, prop: StringName, min_value: float, max_value: float, step: float) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 90
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size.x = 170
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 50
	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	rows.add_child(row)

	var entry := {"slider": slider, "label": value_label, "dragging": false}
	_sliders[prop] = entry
	slider.drag_started.connect(func() -> void: entry.dragging = true)
	slider.drag_ended.connect(func(_changed: bool) -> void: entry.dragging = false)
	slider.value_changed.connect(func(value: float) -> void: TrainState.set(prop, value))


func _add_toggle(title: String, prop: StringName) -> void:
	var box := CheckBox.new()
	box.text = title
	box.toggled.connect(func(pressed: bool) -> void: TrainState.set(prop, pressed))
	rows.add_child(box)
	_toggles[prop] = box


## Fire and gas lights are normally set by events; fuel and brakes follow their levels.
func _add_warning_toggle(title: String, id: StringName) -> void:
	var box := CheckBox.new()
	box.text = title
	box.toggled.connect(func(pressed: bool) -> void: TrainState.set_warning(id, pressed))
	rows.add_child(box)
	_warning_toggles[id] = box


## Damaged systems stop the engine until each one is repaired at its panel.
func _add_system_toggle(title: String, id: StringName) -> void:
	var box := CheckBox.new()
	box.text = title
	box.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			TrainState.damage_system(id)
		else:
			TrainState.repair_system(id))
	rows.add_child(box)
	_system_toggles[id] = box
