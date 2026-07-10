class_name GroundFinder extends Node3D

const MAX_TRAVERSAL_ANGLE : float = 45.0

@export_category("References")
@export var shape_cast: ShapeCast3D
@export var ray_cast : RayCast3D
@export var player_controller: Player

var ground_height : float = -INF
var ground_normal : Vector3 = Vector3.ZERO
var has_ground : bool = false
var current_ground : CollisionObject3D

var previous_transform: Transform3D
var has_previous : bool = false

var previous_ground_velocity: Vector3 = Vector3.ZERO

var ground_velocity : Vector3 = Vector3.ZERO
var ground_acceleration : Vector3 = Vector3.ZERO


func _ready() -> void:
	add_exceptions_recursive(player_controller)

func _physics_process(delta: float) -> void:
	has_ground = false
	ground_height = -INF
	ground_normal = Vector3.ZERO

	var next_ground: CollisionObject3D = null
	var ground_point := Vector3.ZERO

	if ray_cast.is_colliding():
		var collision_normal := ray_cast.get_collision_normal()
		if is_traversable_ground(collision_normal):
			ground_height = ray_cast.get_collision_point().y
			ground_normal = collision_normal
			ground_point = ray_cast.get_collision_point()
			has_ground = true

			var collider = ray_cast.get_collider()
			if collider is CollisionObject3D:
				next_ground = collider

	if shape_cast.is_colliding():
		for i in shape_cast.get_collision_count():
			var collision_point := shape_cast.get_collision_point(i)

			if collision_point.y <= ground_height:
				continue

			var collision_normal := shape_cast.get_collision_normal(i)
			if not is_traversable_ground(collision_normal):
				continue

			ground_height = collision_point.y
			ground_normal = collision_normal
			ground_point = collision_point
			has_ground = true

			var collider = shape_cast.get_collider(i)
			if collider is CollisionObject3D:
				next_ground = collider

	if not has_ground:
		current_ground = null
		has_previous = false
		ground_velocity = Vector3.ZERO
		previous_ground_velocity = Vector3.ZERO
		ground_acceleration = Vector3.ZERO
		return

	if current_ground != next_ground:
		has_previous = false
		ground_velocity = Vector3.ZERO
		previous_ground_velocity = Vector3.ZERO
		ground_acceleration = Vector3.ZERO

	current_ground = next_ground

	ground_velocity = get_point_velocity(
		current_ground,
		ground_point,
		delta
	)

	calculate_ground_acceleration(delta)
	previous_ground_velocity = ground_velocity


func is_traversable_ground(normal: Vector3) -> bool:
	var angle : float = rad_to_deg(normal.angle_to(Vector3.UP))
	return angle <= MAX_TRAVERSAL_ANGLE

func add_exceptions_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		shape_cast.add_exception(node)
		ray_cast.add_exception(node)
	for child in node.get_children():
		add_exceptions_recursive(child)

func set_depth(depth: float) -> void:
	var depth_vector = Vector3.DOWN * depth
	shape_cast.target_position = depth_vector
	ray_cast.target_position = depth_vector

func calculate_ground_acceleration(delta: float) -> void:
	if not has_previous:
		ground_acceleration = Vector3.ZERO
		return
	ground_acceleration = (ground_velocity - previous_ground_velocity) / delta

func get_point_velocity(
	body: CollisionObject3D,
	point_world: Vector3,
	delta: float
) -> Vector3:
	if body == null:
		return Vector3.ZERO

	var current_transform := body.global_transform

	if not has_previous:
		previous_transform = current_transform
		has_previous = true
		return Vector3.ZERO

	var point_local = current_transform.affine_inverse() * point_world
	var previous_point = previous_transform * point_local
	var velocity = (point_world - previous_point) / delta

	previous_transform = current_transform

	return velocity
