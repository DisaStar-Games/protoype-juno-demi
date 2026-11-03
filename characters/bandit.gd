class_name Bandit
extends Figure

## A bandit on the train. It walks through the train (no collision, like every figure) and
## works through targets: the coal pile (it steals fuel and the loose coal, and the pile stays
## empty while bandits are aboard) and the repair panels (it destroys that system). After
## `stay_time` seconds it heads for the rear and leaves. It cannot hurt the player.
## `hit()` is the hook for the future weapon: at 0 health it is killed.

enum Goal { COAL, SYSTEM, LEAVE }

@export var walk_speed := 2.5
@export var steal_time := 3.0
## Fuel taken from the tank each time it empties the coal pile.
@export var steal_fuel := 20.0
## Seconds it spends wrecking a system.
@export var destroy_time := 4.0
@export var max_health := 3.0
@export var stay_time := 45.0

var health := 3.0
var goal := Goal.COAL
var target: Node3D
var exit_point := Vector3(0.0, 0.0, 39.5)
var carrying_coal := false

var _busy := 0.0
var _stay := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	health = max_health
	_rng.randomize()
	add_to_group("bandit")


## Starts working through its targets.
func start() -> void:
	set_physics_process(true)
	_pick_goal()


## The weapon hook: damage a bandit; at 0 health it is killed (`vanished(&"killed")`).
func hit(damage := 1.0) -> void:
	if done:
		return
	health -= damage
	if health <= 0.0:
		_vanish(&"killed")


func _physics_process(delta: float) -> void:
	if done or GameState.state != GameState.State.RUNNING:
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
			if target != null and is_instance_valid(target):
				TrainState.damage_system(target.system_id)
				GameState.post_message("The bandits wrecked the %s!" % target.title.to_lower())
				_spawn_burst()
	_pick_goal()


func _steal_coal() -> void:
	TrainState.fuel -= steal_fuel
	var pile := get_tree().get_first_node_in_group("coal_pile")
	if pile != null:
		pile.stolen = true
	for coal in get_tree().get_nodes_in_group("item_coal"):
		if is_instance_valid(coal) and not coal.freeze:
			coal.queue_free() # loose coal goes too (coal in the player's hand is safe)
	carrying_coal = true
	$Visual/Carry.visible = true
	GameState.post_message("The bandits stole your coal!")


## Next: after `stay_time` leave, otherwise a random coal pile or system that is still intact.
func _pick_goal() -> void:
	if _stay >= stay_time:
		goal = Goal.LEAVE
		target = null
		return
	var options: Array[Node3D] = []
	var pile := get_tree().get_first_node_in_group("coal_pile") as Node3D
	if pile != null and not pile.stolen and not _claimed(pile):
		options.append(pile)
	for point in get_tree().get_nodes_in_group("system_repair_points"):
		if not TrainState.is_system_damaged(point.system_id) and not _claimed(point):
			options.append(point)
	if options.is_empty():
		goal = Goal.LEAVE
		target = null
		return
	target = options[_rng.randi_range(0, options.size() - 1)]
	goal = Goal.COAL if target.is_in_group("coal_pile") else Goal.SYSTEM


## Another bandit is already going for it.
func _claimed(node: Node3D) -> bool:
	for other in get_tree().get_nodes_in_group("bandit"):
		if other != self and other.target == node:
			return true
	return false


func _apply_look() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.28, 0.17, 0.09)
	body.roughness = 1.0
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
