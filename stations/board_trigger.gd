class_name BoardTrigger
extends Interactable

## The door of the parked train at a station: press E to get back on board. The train then
## drives off towards the next junction (Journey.board_train).

func _init() -> void:
	prompt_text = "Board the train"


func interact(_player: Node) -> void:
	Journey.board_train()
