class_name Interactable
extends StaticBody3D

## Base class for things the player can look at and press E on.
## The Interactor finds anything with these four methods (duck-typed), so rigid
## bodies such as ItemPickup implement the same API without extending this class.

## Shown in the HUD as "[E] <prompt_text>".
@export var prompt_text := "Interact"
## 0 = instant press. Above 0 the player must hold E for this many seconds.
@export var hold_time := 0.0


func get_prompt(_player: Node) -> String:
	return prompt_text


func can_interact(_player: Node) -> bool:
	return true


## Seconds to hold E for this player. Override to make it depend on the player
## (a repair point is an instant "you need X" press until the right item is held).
func get_hold_time(_player: Node) -> float:
	return hold_time


func interact(_player: Node) -> void:
	pass


## Shift+E. Levers use it to step down; by default it does the same as `interact`.
func interact_alt(player: Node) -> void:
	interact(player)


## Called every frame while E is held on this target (optional).
func interact_hold(_player: Node, _delta: float) -> void:
	pass
