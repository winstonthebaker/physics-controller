class_name CameraEffects extends Camera3D

@export_category("References")
@export var player: Player

@export_category("Effects")
@export var enable_tilt: bool = true
@export var enable_fall_kick: bool = true
@export var enable_head_bob: bool = true

@export_category("Kick and Recoil Settings")
@export_group("Run Tilt")
@export var max_pitch: float = 1.0
@export var max_roll: float = 2.5

@export_group("Camera Kick")
@export_subgroup("Fall Kick")
@export var fall_kick_duration: float = 0.3
@export var fall_kick_time_curve: Curve
@export var fall_kick_velocity_curve: Curve
@export var max_fall_velocity: float = 20.0
@export var max_fall_kick_angle: float = 5.0
var _fall_kick_timer: float = 0.0
var fall_kick_amount : float = 0.0

@export_group("Head Bob")
@export var bob_pitch_max : float = 0.6
@export var bob_roll_max : float = 0.8
@export var bob_yaw_max: float = 0.6
@export var bob_frequency_max : float = 6.0
@export var bob_speed_amplitude_curve : Curve
@export var bob_speed_frequency_curve: Curve

var normalized_bob_speed : float = 0.0
var _step_timer: float = 0.0
var head_bob_amplitude: float = 0.0
var head_bob_frequency: float = 0.0


var angles = Vector3.ZERO
var offset = Vector3.ZERO

func _process(delta: float)-> void:
	calculate_view_adjustment(delta)

func calculate_view_adjustment(delta: float) -> void:
	if not player:
		return
	var horizontal_velocity = player.get_horizontal_velocity()
	var max_speed = player.ground_movement_speed
	
	angles = Vector3.ZERO
	offset = Vector3.ZERO
	calculate_run_tilt(delta, horizontal_velocity, max_speed)
	calculate_fall_kick(delta)
	calculate_head_bob(delta)
	rotation = angles
	position = offset
	

func calculate_run_tilt(delta: float, velocity: Vector3, max_speed: float) -> void:
	if not enable_tilt:
		return
	var tilt = Vector3.ZERO
	var forward = global_transform.basis.z
	var right = global_transform.basis.x
	var forward_tilt_deg = clampf(remap(velocity.dot(forward), -max_speed, max_speed, -max_pitch, max_pitch), -max_pitch, max_pitch)
	var right_tilt_deg = clampf(remap(velocity.dot(right), -max_speed, max_speed, -max_roll, max_roll), -max_roll, max_roll)
	tilt.x += deg_to_rad(forward_tilt_deg)
	tilt.z -= deg_to_rad(right_tilt_deg)
	angles += tilt

func calculate_fall_kick(delta: float) -> void:
	if not enable_fall_kick:
		return
	if _fall_kick_timer >= fall_kick_duration:
		return
	_fall_kick_timer = move_toward(_fall_kick_timer, fall_kick_duration, delta)
	var fall_ratio = fall_kick_time_curve.sample(_fall_kick_timer / fall_kick_duration)
	var fall_kick = fall_ratio * fall_kick_amount
	var kick_angles = Vector3.ZERO
	kick_angles.x -= fall_kick
	angles += kick_angles

func add_fall_kick(y_velocity: float) -> void:
	if not enable_fall_kick:
		return
	fall_kick_amount = deg_to_rad(
		fall_kick_velocity_curve.sample(abs(y_velocity) / max_fall_velocity) * max_fall_kick_angle)
	_fall_kick_timer = 0.0

func calculate_head_bob(delta: float) -> void:
	if not enable_head_bob: 
		return
	
	var target_head_bob_amplitude = bob_speed_amplitude_curve.sample(normalized_bob_speed)
	head_bob_amplitude = move_toward(head_bob_amplitude, target_head_bob_amplitude, 5.0 * delta)
	var target_head_bob_frequency = bob_speed_frequency_curve.sample(normalized_bob_speed)
	head_bob_frequency = move_toward(head_bob_frequency, target_head_bob_frequency, 5.0 * delta)
	
	_step_timer += normalized_bob_speed * delta * head_bob_frequency * bob_frequency_max
	_step_timer = fmod(_step_timer, 1.0)
	
	var head_bob_vertical_period = sin(_step_timer * 2 * TAU)
	var head_bob_horizontal_period = sin(_step_timer * TAU)
	
	var pitch_delta = head_bob_vertical_period * deg_to_rad(bob_pitch_max) * head_bob_amplitude
	angles.x -= pitch_delta
	var roll_delta = head_bob_horizontal_period * deg_to_rad(bob_roll_max) * head_bob_amplitude
	angles.z -= roll_delta
	var yaw_delta = head_bob_horizontal_period * deg_to_rad(bob_yaw_max) * head_bob_amplitude
	angles.y -= yaw_delta
	
func head_bob_move(normalized_speed: float):
	normalized_bob_speed = normalized_speed
