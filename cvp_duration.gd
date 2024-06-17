extends ConstValPair
class_name CVP_Duration
"""
A ConstValPair that holds "duration"
Specialization that comes into play in TimeScaleableComponent's _on_received_globals_time_scale_changed()

TODO: Add GPUParticles2D lifetime timer too
"""
# Reference to Timer component, if the duration is paired with one
var c_timer : Timer

func _init(_CONST, _force_CONST : bool = true, _c_timer : Timer = null) -> void:
	"""
	Constructor
	"""
	CONST = _CONST
	val = _CONST
	force_CONST = _force_CONST
	if _c_timer:
		# Only assign Timer component if duration is paired with one
		c_timer = _c_timer

func _to_string() -> String:
	"""
	Override so that print() can be used on this object to return String of CONST and val
	"""
	return "CVP_DURATION = CONST: " + str(CONST) + " VAL: " + str(val)
