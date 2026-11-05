extends Interactable

## The radio. Press it while a slower train is ahead and that train starts speeding up
## (see events/slow_train_event.gd); otherwise there is only static. The longer
## conversation with the track regulator is not built (the radio is also disabled while
## the console is broken).


func get_prompt(_player: Node) -> String:
	return "The console is broken!" if console_broken() else prompt_text


func interact(_player: Node) -> void:
	if refuse_if_broken():
		return
	TrainState.call_radio()
	if not EventManager.has_live_event(&"slow_train"):
		GameState.post_message("Radio: only static... nobody answers.")
