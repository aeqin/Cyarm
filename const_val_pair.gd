extends Node
class_name ConstValPair
"""
Object ConstValPair(CONST, force_CONST : bool = true) used to create a pair of related variables
--CONST "cannot be" changed (used for defaults) while
--val can be changed
--force_CONST boolean that determines whether or not CONST can be changed after setting
For example with a speed variable: ConstValPair(DEFAULT_MAX_SPEED) 
"""

# Since "const" type needs to be known at compiletime, CONST can't be initialized in _init()
# as a work-around, use a setter
# so that CONST is a "const" value (can't be changed once set)
var CONST: # Can't be changed
	set(newVal):
		if force_CONST:
			# Only if CONST is not yet set, set it to newVal
			if not CONST:
				CONST = newVal
			else:
				push_warning("Attempting to change CONST attr in ", _to_string())
		else:
			# If CONST is allowed to be changed, simply set it every time
			CONST = newVal

var val # Can be changed

var force_CONST : bool = true

func _init(_CONST, _force_CONST : bool = true) -> void:
	"""
	Constructor
	"""
	CONST = _CONST
	val = _CONST
	force_CONST = _force_CONST

func _to_string() -> String:
	"""
	Override so that print() can be used on this object to return String of attributes
	"""
	return "CONST: " + str(CONST) + " VAL: " + str(val) + " force_CONST: " + str(force_CONST)
	
func set_both(value) -> void:
	"""
	Sets both CONST and val to the same value
	"""
	if force_CONST:
		push_warning("Attempting to change both CONST and val, even though force_CONST is set to true")
	
	CONST = value
	val = value
	
