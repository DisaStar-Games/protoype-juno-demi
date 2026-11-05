extends CanvasLayer

## Full-screen hallucination effect (wobble, sickly tint, pulsing dark edges) that grows
## with TrainState.hallucination_intensity. Hidden entirely while the player is fine.
## It is much heavier while the player stands in the room with the gas leak.
## Autoload `HallucinationOverlay`.

## Extra strength in the gas room: shown = intensity * (1 + this * presence) + `room_boost` * presence.
@export var room_multiplier := 1.5
@export var room_boost := 0.15
## How fast the effect swells when entering / leaving the room (per second).
@export var room_blend_speed := 1.5

var _presence := 0.0   # 0 outside the gas room .. 1 inside
var _zone: CabinZone

@onready var screen: ColorRect = $Screen


func _ready() -> void:
	TrainState.hallucination_changed.connect(_on_intensity_changed)
	_on_intensity_changed(TrainState.hallucination_intensity)


func _process(delta: float) -> void:
	if not visible:
		_presence = 0.0
		return
	var target := 1.0 if _player_in_gas_room() else 0.0
	var before := _presence
	_presence = move_toward(_presence, target, room_blend_speed * delta)
	if not is_equal_approx(before, _presence) or _presence > 0.0:
		_apply(TrainState.hallucination_intensity)


func _on_intensity_changed(intensity: float) -> void:
	visible = intensity > 0.0
	_apply(intensity)


func _apply(intensity: float) -> void:
	var shown := clampf(intensity * (1.0 + room_multiplier * _presence) + room_boost * _presence, 0.0, 1.0)
	(screen.material as ShaderMaterial).set_shader_parameter("intensity", shown if intensity > 0.0 else 0.0)


func _player_in_gas_room() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	if not is_instance_valid(_zone):
		_zone = null
		for zone in get_tree().get_nodes_in_group("cabin_zones"):
			if zone.zone_name == "Gas chamber":
				_zone = zone
	return _zone != null and _zone.contains(player.global_position)
