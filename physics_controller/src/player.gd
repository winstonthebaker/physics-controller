class_name Player extends RigidBody3D
@export_category("References")
@export var ground_finder : GroundFinder
@export var state_chart : StateChart
@export var camera_effects: CameraEffects

@export_category("Floating Collider")
@export var ride_height : float = 1.5
@export var ride_spring_strength: float = 100.0
var spring_constant: float
var damping_constant: float

@export_category("Grounded & Coyote Movement")
@export var ground_movement_speed: float = 5.0
@export var ground_movement_acceleration : float = 10.0
@export_group("Moving Platform")
@export var moving_platform_stability : float = 10.0

@export_category("Falling")
@export var gravity: float = 20.0
@export var coyote_gravity : float = 10.0
@export var coyote_time : float = 0.25
@export var air_movement_acceleration : float = 4.0
@export var air_movement_speed: float = 5.0

@export_category("Jumping")
@export var jump_speed : float = 7.0

var time_in_state: float = 0.0

func _ready() -> void:
	spring_constant = ride_spring_strength * mass
	damping_constant = sqrt(4.0 * mass * spring_constant)

var y_rotation : float

func update_rotation(rotation_input: Vector3) -> void:
	y_rotation = rotation_input.y
	#global_transform.basis = Basis.from_euler(rotation_input)

func get_horizontal_velocity() -> Vector3:
	return Vector3(
		linear_velocity.x, 
		0.0,
		linear_velocity.z
	)

func get_based_input() -> Vector3:
	var input_dir = Input.get_vector("left", "right","forward","backward")
	var direction = (transform.basis * Vector3(
		input_dir.x,
		0.0,
		input_dir.y
	)).normalized()
	return direction

func project_on_plane(vector: Vector3, normal: Vector3) -> Vector3:
	var dot = vector.dot(normal)
	return vector - dot * normal

func _physics_process(delta: float) -> void:
	rotation.y = y_rotation
	state_chart.set_expression_property("Velocity: ", linear_velocity)

func _on_grounded_state_physics_processing(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		state_chart.send_event("onJump")
		return
	if not ground_finder.has_ground:
		state_chart.send_event("onCoyote")
		return
	var based_input = get_based_input()
	var ground_normal: Vector3 = ground_finder.ground_normal
	
	var ground_velocity = ground_finder.ground_velocity
	var ground_acceleration = ground_finder.ground_acceleration
	
	var relative_velocity = linear_velocity - ground_velocity
	
	var planar_velocity: Vector3 = project_on_plane(relative_velocity, ground_normal)
	var desired_planar_velocity : Vector3 = project_on_plane(based_input, ground_normal).normalized() * ground_movement_speed
	var desired_y_velocity = planar_velocity.y
	var force = Vector3.ZERO
	force += ground_acceleration * mass
	var velocity_difference = desired_planar_velocity - relative_velocity
	var d = ground_finder.ground_height + ride_height - position.y
	var v: float = relative_velocity.y - desired_y_velocity
	force += Vector3.UP * (d * spring_constant - v * damping_constant)
	force += velocity_difference * mass * (ground_movement_acceleration)
	camera_effects.head_bob_move(clampf((planar_velocity).length() / ground_movement_speed, 0.0, 1.0))
	apply_central_force(force)

func horizontal_movement_force(speed: float, acceleration_factor: float)-> Vector3:
	var input: Vector3 = get_based_input()

	var desired_velocity = input * speed
	var velocity_difference = desired_velocity - get_horizontal_velocity()
	var force = velocity_difference * mass * acceleration_factor
	return force

func horizontal_air_movement_force(speed: float, acceleration_factor: float)-> Vector3:
	var input: Vector3 = get_based_input()
	if input.length() < 0.1: 
		return Vector3.ZERO
	var horizontal_velocity = get_horizontal_velocity()
	var horizontal_speed = horizontal_velocity.length()
	var desired_speed = max(horizontal_speed, speed)
	var desired_velocity = input * desired_speed
	var velocity_difference = desired_velocity - horizontal_velocity
	var force = velocity_difference * mass * acceleration_factor
	return force

func _on_coyote_state_physics_processing(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		state_chart.send_event("onJump")
		return
	if ground_finder.has_ground:
		state_chart.send_event("onGrounded")
	time_in_state += delta
	var force = horizontal_movement_force(ground_movement_speed, ground_movement_acceleration)
	force += Vector3.DOWN * coyote_gravity * mass
	apply_central_force(force)
	if time_in_state >= coyote_time:
		state_chart.send_event("onAirborne")
	camera_effects.head_bob_move(0.0)
		

func _on_airborne_state_physics_processing(delta: float) -> void:
	if ground_finder.has_ground:
		state_chart.send_event("onGrounded")
	var force = Vector3.DOWN * gravity * mass
	force += horizontal_air_movement_force(air_movement_speed, air_movement_acceleration)
	apply_central_force(force)
	camera_effects.head_bob_move(0.0)
	

func _on_jumping_state_physics_processing(delta: float) -> void:
	time_in_state += delta
	if time_in_state > 0.25 and linear_velocity.y <= 0:
		state_chart.send_event("onAirborne")
	if time_in_state > 0.5:
		state_chart.send_event("OnAirborne")
	var force = Vector3.DOWN * gravity * mass
	force += horizontal_air_movement_force(air_movement_speed, air_movement_acceleration)
	apply_central_force(force)
	camera_effects.head_bob_move(0.0)

func _any_state_entered() -> void:
	time_in_state = 0.0

func _on_jumping_state_entered() -> void:
	var jump_speed_difference : float = max(jump_speed, jump_speed - linear_velocity.y)
	apply_central_impulse(Vector3.UP * mass * jump_speed_difference)
	ground_finder.set_depth(ride_height)
	

func _on_grounded_state_entered() -> void:
	ground_finder.set_depth(ride_height + 1.0)
	camera_effects.add_fall_kick(linear_velocity.y)

func _on_airborne_state_entered() -> void:
	ground_finder.set_depth(ride_height)

func _on_coyote_state_entered() -> void:
	ground_finder.set_depth(ride_height)
