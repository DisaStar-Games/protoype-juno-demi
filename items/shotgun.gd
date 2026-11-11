class_name Shotgun
extends ItemPickup

## Double-barrelled shotgun. Each left click fires one barrel (a spread of pellets along your
## aim); two shells, then press R to reload. Pellets fly through window glass and loose items
## but stop at walls, so bandits can be shot from the windows. Anything that can be hit (the
## bandits) has a hitbox that carries `hit_target` metadata: the pellets call its `hit(damage)`.

@export var pellets := 8
## Damage of one pellet; a bandit has 3 health, so at close range two barrels kill (8 pellets
## x 0.35 = 2.8 per barrel at most), further away it takes more.
@export var pellet_damage := 0.35
## Pellets spread over a cone this wide (degrees).
@export var spread_degrees := 4.0
@export var shot_range := 60.0
@export var shells_per_load := 2
## Seconds to reload both barrels.
@export var reload_time := 2.0

var shells := 2
var reloading := false

var _reload_left := 0.0
var _loading := 0
var _rng := RandomNumberGenerator.new()

@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var muzzle_sparks: CPUParticles3D = $MuzzleSparks


func _ready() -> void:
	super()
	_rng.randomize()
	shells = shells_per_load
	muzzle_flash.visible = false


func _physics_process(delta: float) -> void:
	super(delta)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			shells += _loading
			_loading = 0


## Shown on the HUD next to the item name.
func hud_status() -> String:
	if reloading:
		return "Reloading..."
	return "Shells %d/%d" % [shells, shells_per_load]


## Called by HeldItem on every left click while the gun is held.
func use_pressed(origin: Vector3, direction: Vector3) -> void:
	if reloading:
		return
	if shells <= 0:
		GameState.post_message("Click! Out of shells. Press R to reload (needs bullets).")
		return
	shells -= 1
	_fire(origin, direction)


## Called by HeldItem on R.
func reload_pressed() -> void:
	if reloading or shells >= shells_per_load:
		return
	# The shells come out of the pockets (the inventory).
	_loading = mini(shells_per_load - shells, Inventory.count(&"bullets"))
	if _loading <= 0:
		GameState.post_message("No bullets left! Find more.")
		return
	Inventory.remove(&"bullets", _loading)
	reloading = true
	_reload_left = reload_time


func _fire(origin: Vector3, direction: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	for i in pellets:
		var dir := direction if i == 0 else _spread(direction)
		_shoot_pellet(space, origin, dir, exclude.duplicate())

	muzzle_flash.visible = true
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false)
	muzzle_sparks.restart()
	muzzle_sparks.emitting = true
	if player != null and player.camera.has_method("kick"):
		player.camera.kick(0.35, 0.3)


## One pellet: a ray that skips window glass and loose items, stops at walls, and hurts
## whatever it hits that can be hit.
func _shoot_pellet(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, exclude: Array[RID]) -> void:
	var end := origin + direction * shot_range
	for attempt in 8:
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 4) # world + hitboxes
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return
		var collider: Object = hit.collider
		if collider is ItemPickup or (collider is Node and (collider as Node).is_in_group("glass")):
			exclude.append(hit.rid)
			continue
		if collider.has_meta(&"hit_target"):
			var target: Object = collider.get_meta(&"hit_target")
			if is_instance_valid(target):
				target.hit(pellet_damage)
		return


## A random direction inside the spread cone around `direction`.
func _spread(direction: Vector3) -> Vector3:
	var angle := _rng.randf() * TAU
	var radius := sqrt(_rng.randf()) * tan(deg_to_rad(spread_degrees))
	var local := Vector3(cos(angle) * radius, sin(angle) * radius, -1.0).normalized()
	return Basis.looking_at(direction, Vector3.UP) * local
