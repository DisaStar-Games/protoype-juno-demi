extends PushButton

## Horn. PLACEHOLDER: announces itself on the HUD and emits TrainState.horn_sounded.
## Milestone 6 track events (people/animals on the track) listen for that signal.


func _on_pressed(_player: Node) -> void:
	TrainState.sound_horn()
	GameState.post_message("HONK!")
