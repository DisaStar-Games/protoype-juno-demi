class_name PushButton
extends Interactable

## A console push button. Pressing animates the cap and calls `_on_pressed`, which
## specific buttons (horn, boost...) override. Other code can also listen to `pressed`.

signal pressed

@export var title := "BUTTON"
@export var cap_color := Color(0.85, 0.2, 0.2)
## How far the cap sinks when pressed, in metres.
@export var travel := 0.025
## Played when the button is pressed (horn, boost, radio...).
@export var press_sound: AudioStream

## Per-button material so a button can glow (emission) independently of others.
var cap_material: StandardMaterial3D

var _cap_rest_y := 0.0
var _tween: Tween

@onready var cap: MeshInstance3D = $Cap
@onready var label: Label3D = $Label3D


func _ready() -> void:
	label.text = title
	_cap_rest_y = cap.position.y
	cap_material = StandardMaterial3D.new()
	cap_material.albedo_color = cap_color
	cap_material.roughness = 0.5
	cap.material_override = cap_material


func get_prompt(_player: Node) -> String:
	return "The console is broken!" if console_broken() else prompt_text


func interact(player: Node) -> void:
	if refuse_if_broken():
		return
	_animate_press()
	Sfx.play_at(self, press_sound)
	pressed.emit()
	_on_pressed(player)


## Override in specific buttons.
func _on_pressed(_player: Node) -> void:
	pass


func _animate_press() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(cap, "position:y", _cap_rest_y - travel, 0.05)
	_tween.tween_property(cap, "position:y", _cap_rest_y, 0.1)
