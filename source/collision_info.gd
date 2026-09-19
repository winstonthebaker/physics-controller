class_name CollisionInfo
extends RefCounted

func _init(
	_point: Vector3 = Vector3.ZERO
)-> void:
	point = _point

var point: Vector3
var normal: Vector3 = Vector3.ZERO
var object: Object = null
var velocity: Vector3 = Vector3.ZERO
var acceleration: Vector3 = Vector3.ZERO
var is_valid: bool = false
var is_walkable: bool = false
