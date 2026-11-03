extends Interactable

## Radio to the track regulator. PLACEHOLDER: only static for now. Milestone 6 adds the
## short dialogue that tells the player which side of a track split is correct.


func interact(_player: Node) -> void:
	TrainState.call_radio()
	GameState.post_message("Radio: only static... the track regulator isn't answering yet.")
