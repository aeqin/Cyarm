extends Node

"""
ComponentTimeScaleable can be added to any scene that cares about Global's timescale (wants to be
slowed or sped up with time scale)
After adding, simply set properties of:
	speeds as CVP_Speed
	accelerations as CVP_Acceleration
	durations as CVP_Duration
and this class will handle them when Global.time_scale changes
"""
### Node to be subject to Global's time_scale
var parent : Node

### Lists of property references to be adjusted to time_scale
var arr_cvp_speeds : Array = [] # Array of CVP_Speeds (HALVED when time_scale is halved)
var arr_cvp_accels : Array = [] # Array of CVP_Accelerations (QUARTERED when time_scale is halved)

var arr_c_timers : Array = [] # Array of Timer components
var arr_cvp_durations : Array = [] # Array of CVP_Durations (DOUBLED when time_scale is halved)

var arr_c_anims : Array = [] # Array of AnimationPlayer and AnimatedSprite components

func _ready() -> void:
	## Set parent node
	parent = get_owner()

	## Subscribe to signals
	Globals.connect("sig_globals_time_scale_changed", _on_received_globals_time_scale_changed)
	parent.connect("ready", _on_received_parent_ready)

##################
## Helper Functions
##################
func print_lists() -> void:
	"""
	Prints collected lists of:
		CVP_Speeds
		CVP_Accelerations
		CVP_Durations
		AnimationPlayers and AnimatedSprite2Ds
		Timers
	"""
	# Speeds
	for speed in arr_cvp_speeds:
		print(parent, speed)

	# Accelerations
	for accel in arr_cvp_accels:
		print(parent, accel)

	# Timers
	for timer in arr_c_timers:
		print(parent, timer)

	# Durations
	for dur in arr_cvp_durations:
		print(parent, dur)

	# AnimationPlayers and AnimatedSprite2Ds
	for anim_player in arr_c_anims:
		print(parent, anim_player)

func set_timer_wait_and_preserve(timer : Timer, new_wait_time : float) -> void:
	"""
	Starts a Timer component with a new time_left, while preserving old wait_time
	"""
	# For each Timer, restart it with a new wait time, then
	# reset its wait_time back to its old wait_time (since .start() changes wait_time)
	var _old_wait_time = timer.wait_time
	var _old_time_left = timer.time_left
	if new_wait_time > 0:
#		print(timer.name,
#			  " _old_wait_time: ", _old_wait_time,
#			  " _old_time_left: ",  _old_time_left,
#			  " new_wait_time: ", new_wait_time)
		timer.start(new_wait_time)
		timer.wait_time = _old_wait_time

##################
## Received Signals
##################
func _on_received_parent_ready() -> void:
	"""
	Initialize ComponentTimeScaleable

	Collect lists of:
		CVP_Speeds
		CVP_Accelerations
		CVP_Durations
		AnimationPlayers and AnimatedSprite2Ds
		Timers
	"""
	# Iterate through parent's properties, and add relevant properties to arrays
	# that will be acted upon when Global's time_scale changes
	var parent_property_list = parent.get_script().get_script_property_list() # List of property dictionaries
	for prop_dict in parent_property_list:
		var _prop_name = prop_dict["name"]
		if _prop_name in parent:
			var _prop = parent.get(_prop_name)
			if _prop is CVP_Speed:
				arr_cvp_speeds.append(_prop)
			elif _prop is CVP_Acceleration:
				arr_cvp_accels.append(_prop)
			elif _prop is Timer:
				arr_c_timers.append(_prop)
			elif _prop is CVP_Duration:
				arr_cvp_durations.append(_prop)
			elif _prop is AnimationPlayer or _prop is AnimatedSprite2D:
				arr_c_anims.append(_prop)

	# If Globals.time_scale is currently NOT 1, then adjust time_scale relevant properties on spawn
	if Globals.time_scale != 1.0:
		_on_received_globals_time_scale_changed(1.0, Globals.time_scale)

func _on_received_globals_time_scale_changed(old_time_scale : float, new_time_scale : float) -> void:
	"""
	Adjust parent's time-sensitive properties
	"""
	if new_time_scale <= 0.0:
		# If time_scale is zero, pause the Node by disabling its process loops 
		parent.set_process(false)
		parent.set_physics_process(false)
			
		# Pause Timers
		for timer in arr_c_timers:
			timer = timer as Timer
			timer.set_paused(true)
			
		# Pause Animations
		for anim_player in arr_c_anims:
			anim_player.speed_scale = new_time_scale

		return # Return, no need to modify additional properties if process loops are disabled
	elif new_time_scale > 0.0 and old_time_scale <= 0.0:
		# Re-enable process loops
		parent.set_process(true)
		parent.set_physics_process(true)

		# Unpause Timers
		for timer in arr_c_timers:
			timer = timer as Timer
			timer.set_paused(false)
			
		# Unpause Animations
		for anim_player in arr_c_anims:
			anim_player.speed_scale = new_time_scale

		old_time_scale = 1.0 # When unpausing, set the old_time_scale to 1.0, or the ratio calculations will be messed up
	
	var _n_ts : float = new_time_scale
	var _ratio : float = old_time_scale / _n_ts

	# Velocity
	# If parent moves with "velocity" property, set current velocity to factor of time_scale ratio
	if parent is CharacterBody2D:
		parent.velocity /= _ratio

	# Speeds
	# If time slows, to take longer to get somewhere, speed should DECREASE
	for speed in arr_cvp_speeds:
		speed = speed as CVP_Speed
		speed.val = speed.CONST * _n_ts

	# Accelerations
	# If time slows, to take longer to get somewhere, accelerations should DECREASE
	for accel in arr_cvp_accels:
		accel = accel as CVP_Acceleration
		accel.val = accel.CONST * pow(_n_ts, 2)

	# Timers
	# Set current timers' time_left to factor of new time_scale
	for timer in arr_c_timers:
		timer = timer as Timer
		# For each Timer, restart it with new time_scale adjusted time, while preserving
		# its old wait_time for once the Timer finishes
		var _new_time_left = timer.time_left * _ratio
		set_timer_wait_and_preserve(timer, _new_time_left)

	# Durations
	# If time slows, to take longer to get somewhere, durations should INCREASE
	for dur in arr_cvp_durations:
		dur = dur as CVP_Duration
		dur.val = dur.CONST / _n_ts
		if dur.c_timer:
			# If this duration is paired with a Timer component
			var _c_timer : Timer = dur.c_timer
			# Set the Timer's new wait_time to time_scale adjusted duration (the Timer's current
			# time_left is adjusted in "# Timers" for loop)
			_c_timer.wait_time = dur.val

	# Animations
	# Set current animations speed to factor of new time_scale
	for anim_player in arr_c_anims:
		anim_player.speed_scale = _n_ts
