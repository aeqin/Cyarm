extends ConstValPair
class_name CVP_Acceleration
"""
A ConstValPair that holds "acceleration"
Specialization that comes into play in TimeScaleableComponent's _on_received_globals_time_scale_changed()
"""
func _to_string() -> String:
	"""
	Override so that print() can be used on this object to return String of CONST and val
	"""
	return "CVP_ACCELERATION = CONST: " + str(CONST) + " VAL: " + str(val) + " force_CONST: " + str(force_CONST)
