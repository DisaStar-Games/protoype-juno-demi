class_name Bandit
extends Figure

## A bandit. It comes from OUTSIDE: it runs in toward the train, hangs on the running board at
## a window for `climb_time` seconds (that is when you can shoot it through the glass), then
## climbs in. Inside (no collision, like every figure) it works through targets: the coal pile
## (it steals fuel and the loose coal, and the pile stays empty while bandits are aboard) and
## four things to wreck. Wrecking something plays the NORMAL event for it
## (EventManager.sabotage): the furnace catches fire, the coolant tank starts leaking, a gas
## pipe starts leaking, and the console is switched off. After `stay_time` seconds inside it
## heads for the rear and leaves. It cannot hurt the player.
## It can be shot anywhere: a hitbox (layer 3, `hit_target` metadata) takes the shotgun's
## pellets, `hit()` hurts it and at 0 health it is killed.

enum Goal { COAL, SYSTEM, LEAVE }
## Where the bandit is: running in from outside, hanging at a window, or inside the train.
enum Phase { APPROACH, CLIMB, INSIDE }

## What a bandit can wreck, and the name used in the message.
const WRECK_NAMES := {&"furnace": "furnace", &"coolant": "coolant tank", &"pipes": "gas pipes", &"controls": "console"}

@export var walk_speed := 2.5
@export_group("Coming in from outside")
## How fast it runs toward the train.
@export var approach_speed := 5.0
## How far from the train it starts, sideways.
@export var approach_distance := 20.0
## It hangs on a running board this far from the train's middle.
@export var board_x := 2.55
## Seconds it hangs at the window before it climbs in.
@export var climb_time := 4.0
@export_group("Inside")
@export var steal_time := 3.0
## Fuel taken from the tank each time it empties the coal pile.
@export var steal_fuel := 20.0
## Coal cubes the bandits take out of the pile.
@export var pile_coal_stolen := 4
## Seconds it spends wrecking something.
@export var destroy_time := 4.0
@export var max_health := 3.0
@export var stay_time := 45.0

var health := 3.0
var phase := Phase.INSIDE
var goal := Goal.COAL
var target: Node3D
## &"coal", or one of the keys of WRECK_NAMES.
var target_kind: StringName = &""
var exit_point := Vector3(0.0, 0.0, 39.5)
var carrying_coal := false

var side := 1          # -1 or 1: which side of the train it comes in on
var window_z := 0.0    # the window it is heading for

var _busy := 0.0
var _stay := 0.0
var _climb_left := 0.0
var _body_material: StandardMaterial3D
var _body_color := Color.WHITE
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	health = max_health
	_rng.randomize()
	add_to_group("bandit")
	_add_hitbox()


## Starts inside the train, where it stands, and goes straight for its targets.
func start() -> void:
	phase = Phase.INSIDE
	set_physics_process(true)
	_pick_goal()


## Starts outside: it appears `approach_distance` away on `new_side` (-1 or 1) near height z
## along the train and runs for the closest window.
func start_outside(new_side: int, z: float) -> void:
	side = new_side
	window_z = clampf(roundf((z - 2.0) / 4.0) * 4.0 + 2.0, 2.0, 38.0) # the windows are 4 m apart
	global_position = Vector3(side * approach_distance, -1.0, window_z) # ground level
	phase = Phase.APPROACH
	set_physics_process(true)


## Damage from the shotgun (or anything else): it flashes white, and at 0 health it is killed
## (`vanished(&"killed")`).
func hit(damage := 1.0) -> void:
	if done:
		return
	health -= damage
	_hit_flash()
	if health <= 0.0:
		GameState.post_message("Bandit down!")
		_vanish(&"killed")


func _physics_process(delta: float) -> void:
	if done or GameState.state != GameState.State.RUNNING:
		return
	if phase == Phase.APPROACH:
		_approach(delta)
		return
	if phase == Phase.CLIMB:
		_climb(delta)
		return
	_stay += delta
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			_finish_action()
		return

	var destination := _destination()
	var to := destination - global_position
	to.y = 0.0
	if to.length() < 0.7:
		_arrive()
		return
	global_position += to.normalized() * walk_speed * delta
	_face(destination)


## Runs along the ground toward the train and up onto the running board at its window.
func _approach(delta: float) -> void:
	var board := side * board_x
	var step := approach_speed * delta
	var dx := board - global_position.x
	if absf(dx) <= step:
		global_position = Vector3(board, 0.0, window_z)
		phase = Phase.CLIMB
		_climb_left = climb_time
		return
	global_position.x += signf(dx) * step
	# Up the last stretch: from the ground onto the running board.
	global_position.y = lerpf(-1.0, 0.0, clampf((4.0 - absf(global_position.x)) / 1.45, 0.0, 1.0))
	_face(Vector3(0.0, 0.0, window_z))


## Hangs at the window (this is the time to shoot it), then climbs in.
func _climb(delta: float) -> void:
	_climb_left -= delta
	if _climb_left > 0.0:
		return
	global_position = Vector3(side * 1.6, 0.0, window_z)
	phase = Phase.INSIDE
	_stay = 0.0
	GameState.post_message("A bandit climbed in through the window!")
	_pick_goal()


func _destination() -> Vector3:
	if goal == Goal.LEAVE or target == null or not is_instance_valid(target):
		return exit_point
	return target.global_position


func _arrive() -> void:
	match goal:
		Goal.LEAVE:
			_vanish(&"left")
		Goal.COAL:
			_busy = steal_time
		Goal.SYSTEM:
			_busy = destroy_time


func _finish_action() -> void:
	match goal:
		Goal.COAL:
			_steal_coal()
		Goal.SYSTEM:
			if is_instance_valid(target):
				var params := {}
				if target_kind == &"pipes":
					params["leak_index"] = get_tree().get_nodes_in_group("gas_leak_points").find(target)
				EventManager.sabotage(target_kind, params)
				GameState.post_message("The bandits wrecked the %s!" % WRECK_NAMES[target_kind])
				_spawn_burst()
	_pick_goal()


func _steal_coal() -> void:
	TrainState.fuel -= steal_fuel
	var pile := get_tree().get_first_node_in_group("coal_pile")
	if pile != null:
		pile.steal(pile_coal_stolen)
		pile.stolen = true
	for coal in get_tree().get_nodes_in_group("item_coal"):
		if is_instance_valid(coal) and not coal.freeze:
			coal.queue_free() # loose coal goes too (coal in the player's hand is safe)
	carrying_coal = true
	$Visual/Carry.visible = true
	GameState.post_message("The bandits stole your coal!")


## Next: after `stay_time` leave, otherwise a random target that is still intact.
func _pick_goal() -> void:
	if _stay >= stay_time:
		goal = Goal.LEAVE
		target = null
		return
	var options: Array[Dictionary] = []
	var pile := get_tree().get_first_node_in_group("coal_pile") as Node3D
	if pile != null and not pile.stolen and pile.coal_left > 0 and not _claimed(&"coal"):
		options.append({"kind": &"coal", "node": pile})
	for kind in WRECK_NAMES:
		if EventManager.is_sabotaged(kind) or _claimed(kind):
			continue
		var node := _node_for(kind)
		if node != null:
			options.append({"kind": kind, "node": node})
	if options.is_empty():
		goal = Goal.LEAVE
		target = null
		return
	var choice: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
	target_kind = choice.kind
	target = choice.node
	goal = Goal.COAL if target_kind == &"coal" else Goal.SYSTEM


## The thing in the level that stands for `kind`.
func _node_for(kind: StringName) -> Node3D:
	match kind:
		&"furnace":
			return get_tree().get_first_node_in_group("furnace") as Node3D
		&"coolant":
			return get_tree().get_first_node_in_group("coolant_tank") as Node3D
		&"pipes":
			var points := get_tree().get_nodes_in_group("gas_leak_points")
			if not points.is_empty():
				return points[_rng.randi_range(0, points.size() - 1)] as Node3D
		&"controls":
			for point in get_tree().get_nodes_in_group("system_repair_points"):
				if point.system_id == &"controls":
					return point as Node3D
	return null


## Another bandit is already going for it.
func _claimed(kind: StringName) -> bool:
	for other in get_tree().get_nodes_in_group("bandit"):
		if other != self and other.target_kind == kind and other.goal != Goal.LEAVE:
			return true
	return false


## A box around the whole body that only the shotgun's pellets can touch (layer 3): it blocks
## nothing, the player walks right through it.
func _add_hitbox() -> void:
	var hitbox := StaticBody3D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.8, 0.6)
	shape.shape = box
	shape.position = Vector3(0.0, 0.9, 0.0)
	hitbox.add_child(shape)
	hitbox.set_meta(&"hit_target", self)
	add_child(hitbox)


func _hit_flash() -> void:
	if _body_material == null:
		return
	_body_material.albedo_color = Color(1.0, 1.0, 1.0)
	create_tween().tween_property(_body_material, "albedo_color", _body_color, 0.12)


func _apply_look() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.28, 0.17, 0.09)
	body.roughness = 1.0
	_body_material = body
	_body_color = body.albedo_color
	var eyes := StandardMaterial3D.new()
	eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eyes.albedo_color = Color(1.0, 0.6, 0.1)
	eyes.emission_enabled = true
	eyes.emission = Color(1.0, 0.5, 0.05)
	eyes.emission_energy_multiplier = 3.0
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.05, 0.05, 0.06)
	for part in visual.get_children():
		if part.name.begins_with("Eye"):
			part.material_override = eyes
		elif part.name == "Carry":
			part.material_override = coal
		else:
			part.material_override = body
