extends Node
class_name JitterCounter
"""
Object JitterCounter(non_jitter_min : int) used to create counter object
	non_jitter_min : int -- how many times counter must increment without reset, to be considered NOT jitter

Jitter may occur when working with floats. Where, for example, a direction alternates between extremely
small + and -, and consequently, trips an if statement multiple times and produces a "jitter" (example, rapidly
changing Player sprite if direction is + vs -).

Prevent this jitter by requiring 5 frames of the same [if statement] before triggering (for example,
5 consistent frames of + before finally changing Player sprite)
"""
var non_jitter_min : int # Counter minimum before deciding NOT jitter
var curr_counter : int = 0

func _init(_non_jitter_min : int = 5) -> void:
	"""
	Constructor
	"""
	non_jitter_min = _non_jitter_min
	curr_counter = non_jitter_min

func _to_string() -> String:
	"""
	Override so that print() can be used on this object to return String of CONST and val
	"""
	return str(self) + " non_jitter_min: " + str(non_jitter_min) + " curr_counter: " + str(curr_counter)
	
func incr_and_trigger() -> bool:
	"""
	Increments counter, and returns boolean
	
	Returns : bool -- whether current counter has made it to non_jitter_min 
	"""
	curr_counter += 1
	if curr_counter >= non_jitter_min:
		reset()
		return true
	return false

func reset() -> void:
	"""
	Sets current counter back to 0
	"""
	curr_counter = 0
