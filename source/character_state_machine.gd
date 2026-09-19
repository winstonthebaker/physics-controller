class_name CharacterStateMachine
extends RefCounted

var states: Array[StateCallables]
var current_state: int
var time_in_state: float = 0.0
var is_first_physics_frame: bool = true
var is_first_integrate_frame: bool = true

const MAX_TRANSITIONS: int = 10

class StateCallables:
	var evaluate: Callable
	var physics_process_entry: Callable
	var physics_process: Callable
	var integrate_forces_entry: Callable
	var integrate_forces: Callable
	
	func _init(
		evaluate_cb: Callable, 
		physics_process_entry_cb: Callable,
		physics_process_cb: Callable, 
		integrate_forces_entry_cb: Callable,
		integrate_forces_cb: Callable
		) -> void:
		evaluate = evaluate_cb
		physics_process = physics_process_cb
		physics_process_entry = physics_process_entry_cb
		integrate_forces = integrate_forces_cb
		integrate_forces_entry = integrate_forces_entry_cb


func build_state_array(target: Object, enum_type: Dictionary) -> void:
	states.clear()
	
	var max_val: int = -1
	for val in enum_type.values():
		if val > max_val:
			max_val = val
			
	states.resize(max_val + 1)
	
	const EVALUATE_NAME = "_evaluate"
	const PHYSICS_PROCESS_ENTRY_NAME = "_physics_process_entry"
	const PHYSICS_PROCESS_NAME = "_physics_process"
	const INTEGRATE_FORCES_ENTRY_NAME = "_integrate_forces_entry"
	const INTEGRATE_FORCES_NAME = "_integrate_forces"
	
	for key in enum_type.keys():
		var enum_val: int = enum_type[key]
		var state_name_lower: String = key.to_lower()
		
		var evaluate_cb = Callable(target, "_" + state_name_lower + EVALUATE_NAME)
		var physics_process_entry_cb = Callable(target, "_" + state_name_lower + PHYSICS_PROCESS_ENTRY_NAME)
		var physics_process_cb = Callable(target, "_" + state_name_lower + PHYSICS_PROCESS_NAME)
		var integrate_forces_entry_cb = Callable(target, "_" + state_name_lower + INTEGRATE_FORCES_ENTRY_NAME)
		var integrate_forces_cb = Callable(target, "_" + state_name_lower + INTEGRATE_FORCES_NAME)

		if not evaluate_cb.is_valid():
			push_error("State %s missing evaluate Callable" % key)
		if not physics_process_entry_cb.is_valid():
			push_warning("State %s missing entry Callable, is this intended?" % key)
		if not physics_process_cb.is_valid():
			push_warning("State %s missing process Callable, is this intended?" % key)
		
		states[enum_val] = StateCallables.new(
			evaluate_cb,
			physics_process_entry_cb,
			physics_process_cb,
			integrate_forces_entry_cb,
			integrate_forces_cb
		)


func evaluate() -> void:
	var transitions: int = 0
	var active_state: int = current_state
	while transitions < MAX_TRANSITIONS:
		var state_cb = states[active_state]
		if state_cb == null or not state_cb.evaluate.is_valid():
			break
			
		var target_state: int = state_cb.evaluate.call()
		if target_state == -1:
			break
		time_in_state = 0.0
		transitions += 1
		is_first_physics_frame = true
		is_first_integrate_frame = true
		active_state = target_state
		if transitions >= MAX_TRANSITIONS:
			push_error("Exceeded maximum state transitions in one physics frame.")
			break
	if active_state != current_state:
		current_state = active_state


func physics_process(delta: float) -> void:
	var state_cb = states[current_state]
	if state_cb == null:
		return
		
	if is_first_physics_frame and state_cb.physics_process_entry.is_valid():
		state_cb.physics_process_entry.call(delta)
	elif state_cb.physics_process.is_valid():
		state_cb.physics_process.call(delta)
		
	is_first_physics_frame = false
	time_in_state += delta


func integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var state_cb = states[current_state]
	if state_cb == null:
		return
		
	if is_first_integrate_frame and state_cb.integrate_forces_entry.is_valid():
		state_cb.integrate_forces_entry.call(state)
	elif state_cb.integrate_forces.is_valid():
		state_cb.integrate_forces.call(state)
		
	is_first_integrate_frame = false
