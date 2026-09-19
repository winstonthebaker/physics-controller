class_name ObjectTracker
extends RefCounted

var tracked_objects = {}

const NUM_FRAMES_BEFORE_OBJECT_CLEANUP: int = 1000

class TemporalObjectInfo:
	var previous_frame_transform: Transform3D = Transform3D.IDENTITY
	var before_previous_frame_transform: Transform3D = Transform3D.IDENTITY
	var previous_frame_linear_velocity: Vector3 = Vector3.ZERO
	var previous_frame_angular_velocity: Vector3 = Vector3.ZERO
	var num_frames_processed: int = 0
	var num_frames_unencountered: int = 0

static func update_object_info(
	object: CollisionObject3D,
	info: TemporalObjectInfo
	) -> void:
	info.num_frames_processed += 1
	info.num_frames_unencountered += 1
	info.before_previous_frame_transform = info.previous_frame_transform
	info.previous_frame_transform = object.global_transform
	if object is RigidBody3D:
		info.previous_frame_linear_velocity = object.linear_velocity
		info.previous_frame_angular_velocity = object.angular_velocity

func update_tracked_objects() -> void:
	var keys_to_remove: Array = []
	
	for object in tracked_objects.keys():
		if not is_instance_valid(object):
			keys_to_remove.append(object)
			continue
			
		var info: TemporalObjectInfo = tracked_objects[object]
		update_object_info(object, info)
		
		if info.num_frames_unencountered > NUM_FRAMES_BEFORE_OBJECT_CLEANUP:
			keys_to_remove.append(object)

	# Safe erase loop without type-validation panics
	for key in keys_to_remove:
		tracked_objects.erase(key)

func record_object_contact(object: Object) -> void:
	if not object is CollisionObject3D:
		return
	if not is_instance_valid(object):
		return
	var collision_object = object as CollisionObject3D
	if not tracked_objects.has(collision_object):
		tracked_objects[collision_object] = TemporalObjectInfo.new()
	var info: TemporalObjectInfo = tracked_objects[collision_object]
	info.num_frames_unencountered = 0

func get_point_velocity(object: CollisionObject3D, point: Vector3, delta: float, include_angular: bool = true) -> Vector3:
	if not is_instance_valid(object):
		return Vector3.ZERO

	if object is RigidBody3D:
		var rb := object as RigidBody3D
		var r := point - rb.global_position
		return rb.linear_velocity + (int(include_angular) * rb.angular_velocity.cross(r))
		
	if tracked_objects.has(object):
		var info: TemporalObjectInfo = tracked_objects[object]
		if info.num_frames_processed >= 2:
			var previous_transform: Transform3D = info.previous_frame_transform
			var point_local := object.to_local(point)
			return (point - (previous_transform * point_local)) / delta
			
	return Vector3.ZERO

func get_object_point_velocity(object: Object, point: Vector3, delta: float)-> Vector3:
	if object is CollisionObject3D:
		return get_point_velocity(object, point, delta)
	return Vector3.ZERO

func get_point_acceleration(object: CollisionObject3D, point: Vector3, delta: float, include_angular: bool = true) -> Vector3:
	if not is_instance_valid(object):
		return Vector3.ZERO

	if tracked_objects.has(object):
		var info: TemporalObjectInfo = tracked_objects[object]
		
		if object is RigidBody3D:
			var rb := object as RigidBody3D
			if info.num_frames_processed >= 2:
				var r := point - rb.global_position
				var current_vel := rb.linear_velocity + (int(include_angular) * rb.angular_velocity.cross(r))
				var old_vel := info.previous_frame_linear_velocity + (int(include_angular) * info.previous_frame_angular_velocity.cross(r))
				return (current_vel - old_vel) / delta
		else:
			if info.num_frames_processed >= 3:
				var previous_transform := info.previous_frame_transform
				var point_local := object.to_local(point)
				var current_vel := (point - (previous_transform * point_local)) / delta
				var old_vel := (previous_transform * point_local - info.before_previous_frame_transform * point_local) / delta
				return (current_vel - old_vel) / delta
				
	return Vector3.ZERO

func get_object_point_acceleration(object: Object, point: Vector3, delta: float)-> Vector3:
	if object is CollisionObject3D:
		return get_point_acceleration(object, point, delta)
	return Vector3.ZERO
