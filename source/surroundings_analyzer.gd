class_name SurroundingsAnalyzer
extends Node3D

@export var character: RigidBody3D

@export var ceiling_cast: ShapeCast3D

@export var ground_shapecast: ShapeCast3D
@export var ground_raycasts: Array[RayCast3D]

@export var ledge_shapecast: ShapeCast3D
@export var ledge_raycasts: Array[RayCast3D]

@export var wall_raycasts: Array[RayCast3D]

var object_tracker: ObjectTracker

var ceiling_height: float
var current_ground: CollisionInfo
var current_wall: CollisionInfo
var current_ledge: CollisionInfo

func _ready() -> void:
	object_tracker = ObjectTracker.new()
	current_ground = CollisionInfo.new()
	current_wall = CollisionInfo.new()
	current_ledge = CollisionInfo.new()
	
	if character == null:
		push_error("SurroundingsAnalyzer requires an assigned character to operate!")
		return
	add_exception(character)

func set_ground_depth(depth: float)-> void:
	if ground_shapecast:
		ground_shapecast.target_position = Vector3(0.0, -depth, 0.0)
	for raycast in ground_raycasts:
		raycast.target_position = Vector3(0.0, -depth, 0.0)

func set_ledge_depth(depth: float) -> void:
	if ledge_shapecast:
		ledge_shapecast.target_position = Vector3(0.0, -depth, 0.0)
	for raycast in ledge_raycasts:
		raycast.target_position = Vector3(0.0, -depth, 0.0)

func update(delta: float, walkable_angle: float = 45.0) -> void:
	global_position = character.global_position
	_analyze_ceiling()
	_analyze_walls(delta)
	_analyze_ground(delta, walkable_angle)
	_analyze_ledge(delta, walkable_angle)
	
	object_tracker.update_tracked_objects()

func add_exception(node: CollisionObject3D) -> void:
	ceiling_cast.add_exception(node)
	ground_shapecast.add_exception(node)
	ledge_shapecast.add_exception(node)
	for raycast in wall_raycasts:
		raycast.add_exception(node)
	for raycast in ground_raycasts:
		raycast.add_exception(node)

func _analyze_ceiling()-> void:
	ceiling_cast.force_shapecast_update()
	ceiling_height = INF
	for i in ceiling_cast.get_collision_count():
		var height: float = ceiling_cast.get_collision_point(i).y
		if height < ceiling_height:
			ceiling_height = height

func _analyze_walls(delta: float) -> void:
	for raycast in wall_raycasts:
		raycast.force_raycast_update()
	
	current_wall = CollisionInfo.new(Vector3.ZERO)
	var closest_wall_dist_squared: float = INF
	var num_collisions: int = 0
	
	for raycast in wall_raycasts:
		if not is_instance_valid(raycast):
			continue
		if not raycast.is_colliding():
			continue
		
		current_wall.is_valid = true
		
		var point: Vector3 = raycast.get_collision_point()
		current_wall.point += point
		current_wall.normal += raycast.get_collision_normal()
		var object: Object = raycast.get_collider()
		object_tracker.record_object_contact(object)
		current_wall.velocity += object_tracker.get_point_velocity(
			object,
			point,
			delta
		)
		current_wall.acceleration += object_tracker.get_point_acceleration(
			object,
			point,
			delta
		)
		
		var dist_squared = (character.global_position - point).length_squared()
		if dist_squared < closest_wall_dist_squared:
			current_wall.object = object
		num_collisions += 1
	
	num_collisions = max(1, num_collisions)
	
	current_wall.normal /= num_collisions
	current_wall.point /= num_collisions
	current_wall.velocity /= num_collisions
	current_wall.acceleration /= num_collisions

func _analyze_ground(delta: float, walkable_angle: float) -> void:
	for raycast in ground_raycasts:
		raycast.force_raycast_update()   
	ground_shapecast.force_shapecast_update()
	current_ground = get_highest_walkable_ground(
		ground_shapecast,
		ground_raycasts,
		object_tracker,
		delta,
		walkable_angle
	)

func _analyze_ledge(delta: float, walkable_angle: float) -> void:
	for raycast in ledge_raycasts:
		raycast.force_raycast_update()

	ledge_shapecast.force_shapecast_update()
	
	#current_ledge = get_highest_walkable_ground(
		#ledge_shapecast,
		#ledge_raycasts,
		#object_tracker,
		#delta,
		#walkable_angle,
		#true
	#)


static func get_highest_walkable_ground(
	shapecast: ShapeCast3D, 
	raycasts: Array[RayCast3D], 
	tracker: ObjectTracker, 
	delta: float,
	walkable_angle: float,
	is_ledge_check: bool = false
	) -> CollisionInfo:
	var ground = CollisionInfo.new(Vector3(0.0, -INF, 0.0))

	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var objects: Array[Object] = []
	
	for i in raycasts.size():
		var raycast := raycasts[i]
		if is_instance_valid(raycast) and raycast.is_colliding():
			points.append(raycast.get_collision_point())
			normals.append(raycast.get_collision_normal())
			objects.append(raycast.get_collider())
	
	if is_instance_valid(shapecast):
		for i in shapecast.get_collision_count():
			points.append(shapecast.get_collision_point(i))
			normals.append(shapecast.get_collision_normal(i))
			objects.append(shapecast.get_collider(i))
	for i in objects.size():
		tracker.record_object_contact(objects[i])
	for i in points.size():
		if points[i].y > ground.point.y and is_point_walkable(normals[i], walkable_angle):
			ground.is_valid = true
			ground.point = points[i]
			ground.normal = normals[i]
			ground.object = objects[i]
			ground.velocity = tracker.get_point_velocity(objects[i], points[i], delta)
			ground.acceleration = tracker.get_point_acceleration(objects[i], points[i], delta)
	return ground

static func is_point_walkable(normal: Vector3, walkable_angle: float) -> bool:
	return normal.angle_to(Vector3.UP) <= deg_to_rad(walkable_angle) 
