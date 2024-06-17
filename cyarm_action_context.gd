extends Node
class_name CyarmActionContext
"""
Object CyarmActionContext used to hold info pertaining to Cyarm action
	bool -- primary_action_pressed
	bool -- secondary_action_pressed
	Vector2 -- mouse_global_postition
"""
var primary_action_pressed : bool
var secondary_action_pressed : bool
var mouse_global_postition : Vector2

func _init() -> void:
	"""
	Constructor
	"""
	primary_action_pressed = false
	secondary_action_pressed = false
	mouse_global_postition = Vector2.ZERO

func set_all(_primary_action_pressed : bool, _secondary_action_pressed : bool, _mouse_global_postition : Vector2) -> void:
	"""
	_primary_action_pressed : bool -- whether primary action currently pressed
	_secondary_action_pressed : bool -- whether secondary action currently pressed
	_mouse_global_postition : Vector2 -- global_position of mouse pointer
	"""
	primary_action_pressed = _primary_action_pressed
	secondary_action_pressed = _secondary_action_pressed
	mouse_global_postition = _mouse_global_postition
	
func set_primary_pressed(_primary_action_pressed : bool) -> void:
	"""
	_primary_action_pressed : bool -- whether primary action currently pressed
	"""
	primary_action_pressed = _primary_action_pressed
	
func set_secondary_pressed(_secondary_action_pressed : bool) -> void:
	"""
	_primary_action_pressed : bool -- whether primary action currently pressed
	"""
	secondary_action_pressed = _secondary_action_pressed

func set_mouse_pos(_mouse_global_postition : Vector2) -> void:
	"""
	_mouse_global_postition : Vector2 -- global_position of mouse pointer
	"""
	mouse_global_postition = _mouse_global_postition

func _to_string() -> String:
	"""
	Override so that print() can be used on this object to return String of attributes
	"""
	return "Primary pressed: " + str(primary_action_pressed) + " Secondary pressed: " + str(secondary_action_pressed) + " Mouse_global_position: " + str(mouse_global_postition)
