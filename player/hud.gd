extends Control

## Interaction prompt, hold-progress bar, held-item label and crosshair highlight.

@onready var prompt_label: Label = %PromptLabel
@onready var hold_bar: ProgressBar = %HoldBar
@onready var held_label: Label = %HeldLabel
@onready var crosshair_dot: ColorRect = %ColorRect2


func _ready() -> void:
	%InteractRay.prompt_changed.connect(_on_prompt_changed)
	%InteractRay.hold_progress_changed.connect(_on_hold_progress_changed)
	%HeldItem.changed.connect(_on_held_changed)
	_on_prompt_changed("")
	_on_held_changed(null)


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	crosshair_dot.color = Color.YELLOW if text != "" else Color.WHITE


func _on_hold_progress_changed(progress: float) -> void:
	hold_bar.visible = progress > 0.0
	hold_bar.value = progress


func _on_held_changed(item: ItemPickup) -> void:
	if item == null:
		held_label.text = "Hands empty"
		return
	var hints := "[Q] drop"
	if item.throwable:
		hints = "[LMB] throw   " + hints
	held_label.text = "Holding: %s    %s" % [item.display_name, hints]
