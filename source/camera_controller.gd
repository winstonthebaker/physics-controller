class_name CameraController
extends Node3D

const TILT_LOWER_LIMIT: float = -89.9
const TILT_UPPER_LIMIT: float = 89.9

func tilt(amount: float) -> void:
	var rotation_x = rotation_degrees.x
	rotation_x += amount
	rotation_x = clamp(rotation_x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	rotation_degrees = Vector3(rotation_x, 0.0, 0.0)
	
