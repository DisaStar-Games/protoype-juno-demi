class_name FireSpot
extends Node3D

## A fire the extinguisher can put out. It has `health`; spraying it (see Extinguisher)
## calls `extinguish()` and the flames shrink with the health until it is out.

signal extinguished

@export var max_health := 100.0
## How close the water spray must pass to the centre to hit it, in metres.
@export var radius := 1.0

var burning := false
var health := 0.0

@onready var flames: CPUParticles3D = $Flames
@onready var glow: OmniLight3D = $Glow


func _ready() -> void:
	add_to_group("fire")
	_update_visuals()


func _process(_delta: float) -> void:
	if burning:
		# Flicker.
		var t := Time.get_ticks_msec() / 1000.0
		glow.light_energy = (1.0 + 2.0 * health / max_health) * (0.85 + 0.15 * sin(t * 17.0) * sin(t * 7.3))


func ignite() -> void:
	burning = true
	health = max_health
	_update_visuals()


## Out without the extinguisher (an event ended, restart...). No signal.
func put_out() -> void:
	burning = false
	health = 0.0
	_update_visuals()


func extinguish(amount: float) -> void:
	if not burning:
		return
	health -= amount
	if health <= 0.0:
		put_out()
		extinguished.emit()
	else:
		_update_visuals()


func _update_visuals() -> void:
	var ratio := health / max_health if burning else 0.0
	flames.emitting = burning
	flames.scale_amount_min = 0.3 + 0.7 * ratio
	flames.scale_amount_max = 0.5 + 1.1 * ratio
	glow.visible = burning
