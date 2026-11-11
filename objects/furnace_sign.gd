extends Label3D

## The sign above the furnace: shows the furnace temperature (it is what the sign is for), turning
## from warm orange to red as it nears the overheat point.


func _ready() -> void:
	TrainState.furnace_temp_changed.connect(func(_t: float) -> void: _refresh())
	TrainState.furnace_fire_changed.connect(func(_on: bool) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var temp := TrainState.furnace_temp
	if TrainState.furnace_on_fire:
		text = "FURNACE\nON FIRE!"
		modulate = Color(1, 0.2, 0.1)
		return
	text = "FURNACE\n%d°C" % roundi(temp)
	modulate = Color(1, 0.85, 0.5).lerp(Color(1, 0.15, 0.1), clampf(temp / TrainState.max_furnace_temp, 0.0, 1.0))
