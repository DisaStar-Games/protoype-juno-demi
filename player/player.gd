extends CharacterBody3D


@export var footstep_sound: Array[AudioStream]

var run_speed = 5.5
var speed = run_speed
var walk_speed = 3
var crouch_speed = 1.8

var jump_velocity = 7
var landing_velocity

var distance = 0
var footstep_distance = 2.1

# --- Coal carrying ---
var held_coal: RigidBody3D = null
var throw_force := 8.0
var throw_up := 3.0

@onready var camera: Camera3D = %Camera3D
@onready var interact_ray: RayCast3D = %InteractRay
@onready var hold_point: Node3D = %HoldPoint
@onready var crosshair_dot: ColorRect = $Crosshair/ColorRect2


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Don't let our own capsule block the interaction ray when looking down.
	interact_ray.add_exception(self)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("interact"):
		try_interact()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x / 10
		%Camera3D.rotation_degrees.x -= event.relative.y / 10
		%Camera3D.rotation_degrees.x = clamp( %Camera3D.rotation_degrees.x, -90, 90 )


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * 2 * delta
		landing_velocity = -velocity.y
		distance = 0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		play_random_footstep_sound()

	if not $CeilingDetector.is_colliding():
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.85, 0.1)
	else:
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.38, 0.1)

	if is_on_floor():
		if landing_velocity != 0:
			landing_animation(landing_velocity)
			landing_velocity = 0

		speed = run_speed
		if Input.is_action_pressed("crouch"):
			speed = crouch_speed
		elif Input.is_action_pressed("walk"):
			speed = walk_speed

	if Input.is_action_pressed("crouch"):
		$CollisionShape3D.shape.height = lerp($CollisionShape3D.shape.height, 1.38, 0.1)

	$MeshInstance3D.mesh.height = $CollisionShape3D.shape.height
	%HeadPosition.position.y = $CollisionShape3D.shape.height - 0.25

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	distance += get_real_velocity().length() * delta

	if distance >= footstep_distance:
		distance = 0
		if speed > walk_speed:
			play_random_footstep_sound()

	move_and_slide()

	# Keep carried coal pinned to the hand position (it's frozen, so we drive it).
	if held_coal != null:
		held_coal.global_transform = hold_point.global_transform


func landing_animation(landing_velocity):
	if landing_velocity >= 2:
		play_random_footstep_sound()

	var tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE)
	var amplitude = clamp( landing_velocity / 100, 0.0, 0.3)

	tween.tween_property(%LandingAnimation, "position:y", -amplitude, amplitude)
	tween.tween_property(%LandingAnimation, "position:y", 0, amplitude)


func play_random_footstep_sound() -> void:
	if footstep_sound.size() > 0:
		$FootstepSound.stream = footstep_sound.pick_random()
		$FootstepSound.play()


# --- Coal interaction ---------------------------------------------------------

func _process(_delta: float) -> void:
	# Highlight the crosshair when our hands are empty and a coal is in reach.
	var can_grab := held_coal == null and get_aimed_coal() != null
	crosshair_dot.color = Color.YELLOW if can_grab else Color.WHITE


func try_interact() -> void:
	# E picks up the coal we're looking at, or throws the one we're holding.
	if held_coal != null:
		throw_coal()
	else:
		var coal := get_aimed_coal()
		if coal != null:
			pick_up_coal(coal)


## The coal the crosshair is currently resting on, or null.
func get_aimed_coal() -> RigidBody3D:
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return null

	var collider := interact_ray.get_collider()
	if collider is RigidBody3D and collider.is_in_group("coal"):
		return collider
	return null


func pick_up_coal(coal: RigidBody3D) -> void:
	held_coal = coal
	# Freeze it and pull it out of collision so it rides cleanly in our hand.
	# We leave it in the world tree and drive its transform in _physics_process.
	coal.freeze = true
	coal.collision_layer = 0
	coal.collision_mask = 0
	coal.global_transform = hold_point.global_transform


func throw_coal() -> void:
	var coal := held_coal
	held_coal = null

	# Re-enable physics from its current in-hand position.
	coal.collision_layer = 1
	coal.collision_mask = 1
	coal.freeze = false
	coal.linear_velocity = Vector3.ZERO
	coal.angular_velocity = Vector3.ZERO

	# Fling it along the camera aim with a slight upward lob.
	var forward := -camera.global_transform.basis.z
	coal.apply_central_impulse(forward * throw_force + Vector3.UP * throw_up)
