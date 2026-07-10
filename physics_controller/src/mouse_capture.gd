class_name MouseCaptureComponent extends Node


@export_category("Mouse Capture Settings")
@export var current_mouse_mode : Input.MouseMode = Input.MOUSE_MODE_CAPTURED
@export var mouse_sensitivity: float = 0.005

var _capture_mouse : bool
var _mouse_input : Vector2

func _unhandled_input(event: InputEvent) -> void:
	_capture_mouse = event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _capture_mouse:
		_mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		_mouse_input.y += -event.screen_relative.y * mouse_sensitivity

func _ready() -> void:
	Input.mouse_mode = current_mouse_mode

func _process(delta: float) -> void:
	_mouse_input = Vector2.ZERO

func get_mouse_input() -> Vector2:
	return _mouse_input
