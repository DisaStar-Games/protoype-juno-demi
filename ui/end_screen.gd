extends CanvasLayer

## Win / lose overlay shown when GameState ends the run. Autoload `EndScreen`.
## It stays alive across the scene reload that Restart triggers, and hides itself
## as soon as GameState is running again.

@onready var title: Label = %Title
@onready var reason: Label = %Reason
@onready var stats: Label = %Stats
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	visible = false
	GameState.game_over.connect(_on_game_over)
	GameState.state_changed.connect(_on_state_changed)
	restart_button.pressed.connect(GameState.restart)


func _on_game_over(won: bool, why: String) -> void:
	title.text = "DELIVERED" if won else "DELIVERY FAILED"
	title.modulate = Color(0.5, 1.0, 0.55) if won else Color(1.0, 0.45, 0.4)
	reason.text = why
	stats.text = "Distance  %d / %d u\nFuel  %d%%" % [
		TrainState.distance,
		GameState.route_length,
		roundi(100.0 * TrainState.fuel / TrainState.max_fuel),
	]
	visible = true
	# The cursor must be free to press the button.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	restart_button.grab_focus()


func _on_state_changed(state: GameState.State) -> void:
	if state == GameState.State.RUNNING:
		visible = false
