class_name Player
extends RigidBody3D

#region References

@export_category("References")
@export_group("Collider")
@export var collider: CollisionShape3D
@export var collider_shape: CylinderShape3D

@export_group("Surroundings")
@export var surroundings_analyzer: SurroundingsAnalyzer
var object_tracker: ObjectTracker

@export_group("Camera")
@export var camera_controller: CameraController
@export var camera: Camera3D

#endregion

#region Tuning
const STANDING_COLLIDER_HEIGHT: float = 1.5
const COLLIDER_RIDE_HEIGHT: float = 1.7
const GROUND_LOSS_DEPTH : float = 2.6
const WALKABLE_GROUND_SLOPE: float = 45.0
const JUMP_BUFFER_TIME: float = 0.25
const COYOTE_TIME: float = 0.35

#endregion

#region Multiplayer Stuff

var peer_id: int = 1
var local: bool = true

#endregion

#region State Variables

@export var _raw_input_dir: Vector3 = Vector3.ZERO 
var _jump_request: float = 99.9
var _mouse_delta: Vector2 = Vector2.ZERO

#endregion

#region State Machine

var state_machine: CharacterStateMachine

enum MovementState{
	FREEFALL,
	GROUNDED,
	JUMP,
	COYOTE
}

#endregion

#region Utility Functions

#region collider

func _set_collider_height(desired_collider_height: float)-> bool:
	if collider_shape.height == desired_collider_height:
		return true
	#the ratio from the top of the collider down of where the player origin should be
	#this includes the camera and wall raycasts
	const ORIGIN_HEIGHT_RATIO: float = 0.2
	var relative_ceiling_height: float = surroundings_analyzer.ceiling_height - global_position.y
	var relative_floor_height: float = surroundings_analyzer.current_ground.point.y - global_position.y
	
	var desired_collider_top: float = ORIGIN_HEIGHT_RATIO * desired_collider_height
	var desired_collider_bottom: float = desired_collider_top - desired_collider_height
	
	var could_fully_expand = true
	if (relative_ceiling_height < desired_collider_top) or (relative_floor_height > desired_collider_bottom):
		could_fully_expand = false
	
	var actual_collider_top: float = min(relative_ceiling_height, desired_collider_top)
	var actual_collider_bottom: float = max(relative_floor_height, desired_collider_bottom)
	
	var collider_origin: float = (actual_collider_top + actual_collider_bottom) / 2.0
	var actual_collider_height: float = actual_collider_top - actual_collider_bottom
	
	#even if there are collider size restrictions based on collisions this function should never shrink a collider that is trying to get bigger
	if collider_shape.height > actual_collider_height and desired_collider_height > collider_shape.height:
		return false
		
	collider_shape.height = actual_collider_height
	collider.position.y = collider_origin
	return could_fully_expand

#endregion

#region Input

const MOUSE_SENSITIVITY: float = 0.25

func _unhandled_input(event: InputEvent) -> void:
	if not local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta -= event.screen_relative * MOUSE_SENSITIVITY
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _evaluate_and_set_inputs() -> void:
	if not local:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("jump"):
		_jump_request  = 0.0
		
	var input_dir = Input.get_vector(
		"move_left", 
		"move_right", 
		"move_forward",
		"move_backward"
	).limit_length(1.0)
	
	_raw_input_dir = Vector3(input_dir.x, 0.0, input_dir.y)

func _rotate_character(rotation_delta: Vector2)-> void:
	camera_controller.tilt(rotation_delta.y)
	rotate_y(deg_to_rad(rotation_delta.x))

func _get_and_clear_delta() -> Vector2:
	var current_delta = _mouse_delta
	_mouse_delta = Vector2.ZERO
	return current_delta

#endregion

#endregion

#region Node Lifecycle

func _physics_process(delta: float) -> void:
	if local:
		_evaluate_and_set_inputs()
	surroundings_analyzer.update(delta)
	state_machine.evaluate()
	state_machine.physics_process(delta)
	object_tracker.update_tracked_objects()
	if local:
		_jump_request += delta

func _enter_tree() -> void:
	pass
	#peer_id = int(name)
	#$ClientSynchronizer. set_multiplayer_authority(peer_id)
	#local = (peer_id == multiplayer.get_unique_id())

func _ready() -> void:
	collider.shape = collider_shape
	state_machine = CharacterStateMachine.new()
	state_machine.build_state_array(self, MovementState)
	state_machine.current_state = MovementState.FREEFALL
	object_tracker = ObjectTracker.new()
	
	if local:
		camera.make_current()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state_machine.integrate_forces(state)

#endregion

#region States

#region freefall

func _freefall_evaluate()-> int:
	if not surroundings_analyzer.current_ground.is_valid:
		return -1
	var ground_dist: float = abs(surroundings_analyzer.current_ground.point.y - global_position.y)
	if ground_dist > COLLIDER_RIDE_HEIGHT:
		return -1
	var ground_normal = surroundings_analyzer.current_ground.normal
	if rad_to_deg(ground_normal.angle_to(Vector3.UP)) > WALKABLE_GROUND_SLOPE:
		return -1
	return MovementState.GROUNDED

func _freefall_physics_process_entry(delta: float) -> void:
	print_debug("Freefall State")
	_freefall_physics_process(delta)

func _freefall_physics_process(_delta: float) -> void:
	const FALLING_GRAVITY: float = 20.0
	const MAX_AIRBORNE_SPEED: float = 5.0
	const AIRBORNE_FORCE_SCALAR: float = 4.0
	const AIRBORNE_DIFF_CLAMP: float = 8.0
	_rotate_character(_get_and_clear_delta())
	_set_collider_height(STANDING_COLLIDER_HEIGHT)
	# Compute world movement direction using the current node's basis
	var body_input: Vector3 = (global_basis * _raw_input_dir).normalized()
	
	var force = Vector3.DOWN * FALLING_GRAVITY * mass
	if body_input.length_squared() < 0.1:
		apply_central_force(force)
		return
	
	var horizontal_vel: Vector3 = Vector3(
		linear_velocity.x, 
		0.0, 
		linear_velocity.z
	)
	var current_speed = horizontal_vel.length()
	var target_vel: Vector3 = body_input * max(MAX_AIRBORNE_SPEED, current_speed)
	var diff = ((target_vel - horizontal_vel) * AIRBORNE_FORCE_SCALAR).limit_length(AIRBORNE_DIFF_CLAMP)
	force += diff * mass
	apply_central_force(force)

#endregion

#region grounded

func _grounded_evaluate() -> int:
	if _jump_request < JUMP_BUFFER_TIME:
		_jump_request = 99.9
		return MovementState.JUMP
	if not surroundings_analyzer.current_ground.is_valid:
		return MovementState.COYOTE
	var ground_offset: float = surroundings_analyzer.current_ground.point.y - global_position.y
	if ground_offset < -GROUND_LOSS_DEPTH:
		return MovementState.COYOTE
	var ground_normal = surroundings_analyzer.current_ground.normal
	if rad_to_deg(ground_normal.angle_to(Vector3.UP)) > WALKABLE_GROUND_SLOPE:
		return MovementState.COYOTE
	return -1

func _grounded_physics_process_entry(delta: float) -> void:
	print_debug("Grounded")
	_grounded_physics_process(delta)

func _grounded_physics_process(_delta: float) -> void:
	const GROUNDED_MOVEMENT_SPEED: float = 4.0
	const GROUNDED_FORCE_SCALAR: float = 8.0
	const GROUNDED_DIFF_CLAMP: float = 10.0
	const SPRING_CONSTANT: float = 100

	
	_rotate_character(_get_and_clear_delta())
	_set_collider_height(STANDING_COLLIDER_HEIGHT)
	var ground_normal: Vector3 = surroundings_analyzer.current_ground.normal
	
	var body_input: Vector3 = (global_basis * _raw_input_dir)
	var body_input_length: float = body_input.length()
	
	var target_vel = (body_input.slide(ground_normal)).normalized() * body_input_length * GROUNDED_MOVEMENT_SPEED
	var vel_on_plane: Vector3 = linear_velocity.slide(ground_normal)

	var diff = ((target_vel - vel_on_plane) * GROUNDED_FORCE_SCALAR).limit_length(GROUNDED_DIFF_CLAMP)
	var force = diff * mass
	
	
	var ground_offset: Vector3 = ((surroundings_analyzer.current_ground.point + ground_normal * COLLIDER_RIDE_HEIGHT) - global_position).project(ground_normal).limit_length(COLLIDER_RIDE_HEIGHT * 2)
	var spring_force: Vector3 = ground_offset * SPRING_CONSTANT * mass
	force += spring_force
	
	const DAMPING_CONSTANT: float = 10
	var vel_on_normal: Vector3 = linear_velocity.project(ground_normal)
	var damping_force = -vel_on_normal * DAMPING_CONSTANT
	force += damping_force
	
	apply_central_force(force)
#endregion

#region jump

func _jump_evaluate()-> int:
	if state_machine.time_in_state > 0.5:
		return MovementState.FREEFALL
	return -1

func _jump_physics_process_entry(delta: float)-> void:
	print_debug("Jump")

func _jump_physics_process(delta: float) -> void:
	_freefall_physics_process(delta)

func _jump_integrate_forces_entry(state: PhysicsDirectBodyState3D) -> void:
	const JUMP_SPEED: float = 8.0
	var current_horizontal_velocity: Vector3 = Vector3(
		state.linear_velocity.x,
		0.0,
		state.linear_velocity.z
	)
	state.linear_velocity = current_horizontal_velocity + Vector3.UP * JUMP_SPEED
#endregion

#region coyote

func _coyote_evaluate() -> int:
	if _jump_request < JUMP_BUFFER_TIME:
		_jump_request = 99.9
		return MovementState.JUMP
		
	if state_machine.time_in_state > COYOTE_TIME:
		return MovementState.FREEFALL

	if not surroundings_analyzer.current_ground.is_valid:
		return -1
	var ground_dist: float = abs(surroundings_analyzer.current_ground.point.y - global_position.y)
	if ground_dist > COLLIDER_RIDE_HEIGHT:
		return -1
	var ground_normal = surroundings_analyzer.current_ground.normal
	if rad_to_deg(ground_normal.angle_to(Vector3.UP)) > WALKABLE_GROUND_SLOPE:
		return -1
	return MovementState.GROUNDED

func _coyote_physics_process_entry(delta: float) -> void:
	print_debug("Coyote")
	_coyote_physics_process(delta)

func _coyote_physics_process(delta: float) -> void:
	const FALLING_GRAVITY: float = 20.0
	const MAX_COYOTE_SPEED: float = 6.0
	const COYOTE_FORCE_SCALAR: float = 6.0
	const COYOTE_DIFF_CLAMP: float = 10.0
	_rotate_character(_get_and_clear_delta())
	_set_collider_height(STANDING_COLLIDER_HEIGHT)
	# Compute world movement direction using the current node's basis
	var body_input: Vector3 = (global_basis * _raw_input_dir).normalized()
	
	var force = Vector3.DOWN * FALLING_GRAVITY * mass
	if body_input.length_squared() < 0.1:
		apply_central_force(force)
		return
	
	var horizontal_vel: Vector3 = Vector3(
		linear_velocity.x, 
		0.0, 
		linear_velocity.z
	)
	var current_speed = horizontal_vel.length()
	var target_vel: Vector3 = body_input * max(MAX_COYOTE_SPEED, current_speed)
	var diff = ((target_vel - horizontal_vel) * COYOTE_FORCE_SCALAR).limit_length(COYOTE_DIFF_CLAMP)
	force += diff * mass
	apply_central_force(force)


#endregion

#endregion
