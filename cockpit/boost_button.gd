extends PushButton

## Boost. PLACEHOLDER: toggles TrainState.boost_active and glows while it is on.
## Milestone 9 adds the real rules (needs a fuel/boost item, runs for N seconds).


func _ready() -> void:
	super()
	TrainState.boost_changed.connect(_on_boost_changed)
	_on_boost_changed(TrainState.boost_active)


func get_prompt(_player: Node) -> String:
	return "Boost: %s  (press to turn %s)" % [
		"ON" if TrainState.boost_active else "OFF",
		"off" if TrainState.boost_active else "on",
	]


func _on_pressed(_player: Node) -> void:
	TrainState.boost_active = not TrainState.boost_active
	GameState.post_message("Boost on" if TrainState.boost_active else "Boost off")


func _on_boost_changed(active: bool) -> void:
	cap_material.emission_enabled = active
	cap_material.emission = cap_color
	cap_material.emission_energy_multiplier = 2.0
