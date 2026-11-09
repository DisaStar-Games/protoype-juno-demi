extends PushButton

## Horn. PLACEHOLDER: announces itself on the HUD and emits TrainState.horn_sounded.
## Milestone 6 track events (people/animals on the track) listen for that signal.


## The horn sound goes in the Stream slot of the child node "HornSound" (an AudioStreamPlayer3D).
@onready var horn_sound: AudioStreamPlayer3D = $HornSound


func _on_pressed(_player: Node) -> void:
	if horn_sound.stream != null:
		horn_sound.play()
	TrainState.sound_horn()
	GameState.post_message("HONK!")
