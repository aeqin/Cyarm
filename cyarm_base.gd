extends CharacterBody2D
class_name CyarmBase

#region Signals
signal sig_cyarm_unlocked() # Cyarm can now change mode
signal sig_cyarm_sword_disabled(disabled_during_slash_mouse_pos : Vector2, disabled_during_sword_board : bool)
signal sig_cyarm_sickle_disabled()
signal sig_cyarm_spear_disabled(disabled_during_spear_broom : bool)
signal sig_cyarm_shield_disabled(disabled_in_shield_guard_range : bool)
signal sig_player_freeze(do_freeze : bool)
signal sig_player_stop_momentum(stop_pos : Vector2)
signal sig_player_dash()
signal sig_player_dash_to_spear()
signal sig_player_dash_away_from_shield()
signal sig_player_swordslash(do_swordslash : bool)
signal sig_player_swordboard(do_swordboard : bool)
signal sig_player_swordboard_slash()
signal sig_player_swordiai(do_swordiai : bool)
signal sig_player_swordiai_cut(end_pos : Vector2, distance : float)
signal sig_player_spearbroom(do_spearbroom : bool)
signal sig_player_speartether(do_speartether : bool)
signal sig_player_sickleswing(do_sickleswing : bool, sickle_pos : Vector2)
signal sig_player_sicklepull(sicklepull_type : CyarmSickle.SicklePull, target : Node2D)
signal sig_player_sickleshard_pickup()
signal sig_player_shield_guard_invincible(isInvincible : bool)
signal sig_player_shield_guard_success()
signal sig_player_shieldslide(do_shieldslide : bool, on_press : bool)
signal sig_player_shieldglide(do_shieldglide : bool, on_click : bool)
signal sig_world_spawn_rot_effect(pos : Vector2, rot : float, anim : String)
signal sig_world_spawn_sickleshard(sickle_ref : Node2D, start_pos : Vector2, dir : Vector2, level : int)
signal sig_world_spawn_swordiaistop(pos : Vector2, time_left : float, max_length : float)
signal sig_world_spawn_swordiaicut(begin : Vector2, end : Vector2, o_damage : DamageManager.DamageBase)
signal sig_electroMgr_electro_hit()
signal sig_electroMgr_electro_spear_dash()
signal sig_electroMgr_electro_shield_guard_success()
signal sig_electroMgr_electro_shield_pulse()
signal sig_cyMgr_request_camera_focus(new_node : Node2D)
#endregion

### Component references
@onready var c_animplayer : AnimationPlayer = $AnimationPlayer
@onready var c_sprite : AnimatedSprite2D = $CyarmSprite

### Button Flags
enum ACTION_TYPE {PRIMARY, SECONDARY}
enum BUTT_STATE {NONE, JUST_PRESSED, HELD, JUST_RELEASED} # The type button press for primary action
var primaryaction_butt_state : BUTT_STATE = BUTT_STATE.NONE
var primary_state_as_str : String:
	get:
		return BUTT_STATE.keys()[primaryaction_butt_state]
var secondaryaction_butt_state : BUTT_STATE = BUTT_STATE.NONE
var secondary_state_as_str : String:
	get:
		return BUTT_STATE.keys()[secondaryaction_butt_state]

### Cyarm mode variables
var f_disabled : bool = false # If true, then this Cyarm will not _process or _physics_process
var f_locked : bool = false: # If true, then Cyarm cannot be changed into another mode
	set(flag):
		if not f_locked == flag: # Only set flag if changed to different value
			f_locked = flag
			if not f_locked:
				sig_cyarm_unlocked.emit()
var f_about_to_hit : bool = false # If true, then this Cyarm will hit an enemy based on current mouse position

### Cyarm follow variables
static var f_follow : bool = true: # Whether Cyarm wants to move towards a set position
	set(flag):
		f_follow = flag
		if not f_follow: f_reached = false # Can only reach when following
static var f_follow_player : bool = true # Whether or not follow position is Player's cyarm pos
static var f_after_enable_follow_player : bool = false
static var f_reached : bool = false
static var follow_pos : Vector2 = Vector2.ONE # Position to follow
var follow_acceleration : CVP_Acceleration = CVP_Acceleration.new(10.0) # Approach acceleration
var follow_max_speed : CVP_Speed = CVP_Speed.new(3000.0)
var elasticity : float = 0.65 # Lower is smoother, higher is more bouncy

### Cyarm idle-bob variables
var bob_speed : CVP_Speed = CVP_Speed.new(0.005)
var bob_distance : float = 175.0
@onready var c_sprite_orig_pos : Vector2 = c_sprite.position

### Cyarm animation variables
var f_hidden : bool = true # Whether or not to hide Cyarm sprite
var cyarm_z_index : int = z_index

### Cyarm damage variables
var o_no_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 0)
var damaged_dict : Dictionary = {} # Hold a dictionary of {Ref -> time of hit}, so that Cyarm doesn't "hit" the same target multiple times in quick succession
var damage_mtick_cooldown : int = 550 # How many milliseconds can pass before Cyarm can hit the same target again

### MoveOnRails (class to hold related movement vars together)
var o_move_onrails : MoveOnRails

#region CyarmTrail (class used to store Cyarm Trails)
var o_cyarm_trail : CyarmTrail
class CyarmTrail:
	var base : CyarmBase
	var trail_arr : Array[Line2D] # Array of trails to render for Cyarm
	var pos_arr : Array # Array of markers to render trails at position
	var points_queue : Array # Array of array of Vector2 positions
	var max_points_queue : Array[int] # Array of max length of trail

	func _init(_base : CyarmBase):
		"""
		base : CyarmBase -- reference to outer CyarmBase class (has position)
		"""
		base = _base
		trail_arr = []
		pos_arr = []
		points_queue = []
		max_points_queue = []

	func add_trail(trail : Line2D, pos_marker, max_points : int):
		"""
		Adds a pair of Line2D and positional marker to the class
		
		trail : Line2D -- component that renders the Cyarm trail
		pos_marker : Marker2D or false -- component that stores the position for the Cyarm trail,
										  or false, if the position should just be Cyarm global_position
		max_points : int -- length of trail
		"""
		trail_arr.append(trail)
		pos_arr.append(pos_marker)
		points_queue.append([])
		max_points_queue.append(max_points)

	func get_curr_pos(index : int) -> Vector2:
		"""
		index : int -- the index of the particular trail

		Returns : Vector2 -- the position for the current point of the trail to render
		"""
		if pos_arr[index]:
			return pos_arr[index].global_position # Position of marker
		else:
			return base.global_position # Position of Cyarm
		
	func clear_trail(index : int) -> void:
		"""
		Clears current trail

		index : int -- the index of the particular trail
		"""
		trail_arr[index].clear_points()
		points_queue[index].clear()
	
	func update_trail(index : int) -> void:
		"""
		Adds point to trail, then removes oldest point if past maximum points

		index : int -- the index of the particular trail
		"""
		var _trail = trail_arr[index]
		var _pts_queue = points_queue[index]

		_pts_queue.push_front(get_curr_pos(index)) # Add point to trail
		if _pts_queue.size() > max_points_queue[index]:
			# Fade trail
			_pts_queue.pop_back()

		# Redraw trail every frame
		_trail.clear_points()
		for pt in _pts_queue:
			var _local_pos : Vector2 = base.to_local(pt) # Line2D draws in local space
			_trail.add_point(_local_pos)
#endregion

#region CyarmActionTexture (class used to store Cyarm action texture and related vars)
class CyarmActionTexture:
	var texture : Texture2D
	var f_active : bool = false
	var func_availability : Callable
	var availability : float:
		get:
			return func_availability.call()

	func _init(_texture : Texture2D, _func_availability : Callable):
		"""
		_texture : Texture2D -- texture of Cyarm action
		_func_availability : Callable -- function that returns a float representing how available action is
		"""
		texture = _texture
		func_availability = _func_availability
#endregion

#region CyarmActionBundle (class used to bundle functions for each Cyarm action together)
var o_curr_primary_action : CyarmActionBundle
var o_curr_secondary_action : CyarmActionBundle
class CyarmActionBundle:
	var cyarm_ref : Node
	var action_name : String
	var action_text : CyarmActionTexture

	# Flags
	var is_primary : bool = false
	var is_secondary : bool = false
	var is_active : bool = false
	
	# References to FUNCTIONS
	var func_just_pressed_primary : Callable
	var func_held_primary : Callable
	var func_just_released_primary : Callable
	var func_just_pressed_secondary : Callable
	var func_held_secondary : Callable
	var func_just_released_secondary : Callable

	func _init(
					_cyarm_ref : Node,
					_action_name : String,
					_is_primary : bool,
					_action_text : CyarmActionTexture,
					_func_just_pressed_primary : Callable,
					_func_held_primary : Callable,
					_func_just_released_primary : Callable,
					_func_just_pressed_secondary : Callable,
					_func_held_secondary : Callable,
					_func_just_released_secondary : Callable,
				):
		cyarm_ref = _cyarm_ref
		action_name = _action_name
		is_primary = _is_primary
		is_secondary = not is_primary
		action_text = _action_text
		func_just_pressed_primary = _func_just_pressed_primary
		func_held_primary = _func_held_primary
		func_just_released_primary = _func_just_released_primary
		func_just_pressed_secondary = _func_just_pressed_secondary
		func_held_secondary = _func_held_secondary
		func_just_released_secondary = _func_just_released_secondary
#endregion

#region CyarmStateBundle (class used to bundle functions for each Cyarm state together)
var o_cyarm_state_bundle_dict : Dictionary = {} # {CyarmState -> CyarmStateBundle}
class CyarmStateBundle:
	var cyarm_ref : Node
	
	# References to FUNCTIONS
	var func_animate : Callable
	var func_during_physics : Callable
	var func_get_action_texture : Callable
	var func_exit_state : Callable

	func _init(
					_cyarm_ref : Node,
					_func_animate : Callable,
					_func_during_physics : Callable,
					_func_get_action_texture : Callable,
					_func_exit_state : Callable
				):
		cyarm_ref = _cyarm_ref
		func_animate = _func_animate
		func_during_physics = _func_during_physics
		func_get_action_texture = _func_get_action_texture
		func_exit_state = _func_exit_state
#endregion

#################
## Main functions
#################
func _ready() -> void:
	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_player_died", _on_received_player_died)
	_Player.connect("sig_cyarm_hide", _on_received_hide)

	## Set timers

	## Set raycasts

	## Create Objects
	SETUP_cyarm_state_bundles()
	SETUP_cyarm_action_bundles()
	o_move_onrails = MoveOnRails.new(self)
	o_cyarm_trail = CyarmTrail.new(self)
	
	## Add to DebugStats
	DebugStats.add_stat(self, "primary_state_as_str")

func _process(delta) -> void:
	if f_disabled:
		# Make sure process function is not called if Cyarm mode is disabled
		# This check is needed because time_scaleable_component.gd may re-enable process
		set_process(false)
		return
		
	# Update Globals script
	update_globals()
	
	# Button presses
	if o_move_onrails.is_active():
		# Capture inputs during Cyarm currently moving-on-rails
		update_inputs()
	else:
		# Accept input if Cyarm isn't currently moving-on-rails
		update_inputs()

	# Animations
	update_animations()

func _physics_process(delta : float) -> void:
	if f_disabled:
		# Make sure physics process function is not called if Cyarm mode is disabled
		# This check is needed because time_scaleable_component.gd may re-enable process
		set_physics_process(false)
		return

	# Update Cyarm flags for this frame
	update_physics_flags(delta)
	o_curr_primary_action = get_primary_action_bundle()
	o_curr_secondary_action = get_secondary_action_bundle()
	if f_follow and global_position.distance_to(follow_pos) < 5.0:
		f_reached = true

	# Calculate Cyarm actions
	if primaryaction_butt_state != BUTT_STATE.NONE:
		calc_primary_action()
	if secondaryaction_butt_state != BUTT_STATE.NONE:
		calc_secondary_action()

	## Cyarm moves on set path based on code
	if o_move_onrails.is_active():
		move_onrails(delta)

	## Cyarm moves based on button input
	else:
		# Call the function attached to Cyarm's current state
		do_physics_state_func(delta)
		
		# Calculate velocity of Cyarm follow
		calc_follow()

		# Actually move Cyarm
		move_and_slide()

func update_inputs() -> void:
	"""
	Updates Cyarm flags corresponding to button presses
	"""
	## Primary action button
	# Hold button only overrides state when Cyarm is ready
	# to accept input (when the state is NONE):
	if (
			primaryaction_butt_state == BUTT_STATE.NONE and
			Input.is_action_pressed("primary_action")
		):
			primaryaction_butt_state = BUTT_STATE.HELD
	# Just-pressed and just-released immediately override, regardless of state 
	if Input.is_action_just_pressed("primary_action"):
		primaryaction_butt_state = BUTT_STATE.JUST_PRESSED
	elif Input.is_action_just_released("primary_action"):
		primaryaction_butt_state = BUTT_STATE.JUST_RELEASED
	
	## Secondary action button
	# Hold button only overrides state when Cyarm is ready
	# to accept input (when the state is NONE):
	if (
			secondaryaction_butt_state == BUTT_STATE.NONE and
			Input.is_action_pressed("secondary_action")
		):
			secondaryaction_butt_state = BUTT_STATE.HELD
	# Just-pressed and just-released immediately override, regardless of state 
	if Input.is_action_just_pressed("secondary_action"):
		secondaryaction_butt_state = BUTT_STATE.JUST_PRESSED
	elif Input.is_action_just_released("secondary_action"):
		secondaryaction_butt_state = BUTT_STATE.JUST_RELEASED

func update_globals() -> void:
	"""
	Updates Cyarm variables shared to Global script
	"""
	Globals.cyarm_pos = global_position
	Globals.cyarm_canvas_pos = get_global_transform_with_canvas().origin
	Globals.cyarm_state = get_curr_state()
	Globals.cyarm_f_follow = f_follow
	Globals.cyarm_f_follow_player = f_follow_player

######################
## Enable/disable functions
######################
func enable_before() -> void:
	"""
	Sets up current Cyarm mode before enabling (before anything is visible and position is set)
	"""
	assert(false, "Override me in children.")

func enable(enable_at_pos : Vector2, action_context : CyarmActionContext = null) -> void:
	"""
	Enables Cyarm at position (starts processing and shows sprite)
	
	enable_at_pos : Vector2 -- the global_position to enable Cyarm at
	action_context : CyarmActionContext = null -- the state of pressed action buttons + mouse global_position
	"""
	enable_before() # Setup Cyarm
	
	global_position = enable_at_pos

	f_disabled = false
	set_process(true)
	set_physics_process(true)

	set_hide(false) # Show sprite again

func disable() -> void:
	"""
	Disables Cyarm (exits state, stop animations, processing, and movement)
	"""
	## Stops animations and turns invisible
	set_hide(true)
	c_animplayer.call_deferred("stop") # Stop any current animations
	c_sprite.stop()

	update_trails(false) # Clear old trail

	## Stops processing each frame
	f_disabled = true
	set_process(false)
	set_physics_process(false)
	
	## Stops movement & current move-on-rails
	velocity = Vector2.ZERO
	o_move_onrails.cleanup()
	
	## Cleans up damage_dict
	damaged_dict.clear()
	
	## Cleans up whatever state the Cyarm was in
	exit_state()
	
	## Prevent sticky keys
	primaryaction_butt_state = BUTT_STATE.NONE
	secondaryaction_butt_state = BUTT_STATE.NONE

######################
## SETUP functions
######################
func SETUP_cyarm_action_bundles() -> void:
	"""
	Sets up an CyarmActionBundle for each action this Cyarm has:
		For each action, assigns the prerequisite functions, such as what to do when clicking
		the primary action button
	
	CyarmActionBundle object constructor arguments:
	CyarmActionBundle.new(
					_cyarm_ref : Node,
					_is_primary : bool,
					_action_text : CyarmActionTexture,
					_func_just_pressed_primary : Callable,    # Function to be called on press of primary action
					_func_held_primary : Callable,            # Function to be called on hold primary action
					_func_just_released_primary : Callable,   # Function to be called on release of primary action
					_func_just_pressed_secondary : Callable,  # Function to be called on press of secondary action
					_func_held_secondary : Callable,          # Function to be called on hold of secondary action
					_func_just_released_secondary : Callable, # Function to be called on release of secondary action
				)
	"""
	assert(false, "Override me in children.")

func SETUP_cyarm_state_bundles() -> void:
	"""
	Sets up o_cyarm_state_bundle_dict (a Dictionary of {CyarmState -> CyarmStateBundle}):
		For each Cyarm's state, sets up the prerequisite functions, such as what to do when
		exiting a particular state, or how to animate a particular state
	
	CyarmStateBundle object constructor arguments:
	CyarmStateBundle.new(
					_cyarm_ref : Node,
					_func_animate : Callable,        # Function to be called when animating CyarmState
					_func_during_physics : Callable, # Function to be called during physics_process while in CyarmState
					_func_exit_state : Callable      # Function to be called after exiting CyarmState
				)
	"""
	assert(false, "Override me in children.")

######################
## Cyarm shared functions
######################
func is_locked() -> bool:
	"""
	Returns : bool -- whether Cyarm is locked from changing mode
	"""
	return f_locked == true

func get_curr_state() -> String:
	"""
	Returns : String -- the state of the current Cyarm
	"""
	assert(false, "Override me in children.")
	return ""

func get_action_texture(_get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	availability : float -- how "ready" the Cyarm action is (example: cooldown or lack of resources)
	"""
	assert(false, "Override me in children.")
	return null

func get_radial_icon_action_texture(_action_context : CyarmActionContext) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture for CyarmRadialMenu, of the next action based on pressed action buttons
	
	_action_context : CyarmActionContext -- whether or not action buttons are pressed + mouse global position
	"""
	assert(false, "Override me in children.")
	return null

func get_crosshair_proposed_pos() -> Vector2:
	"""
	Returns : Vector2 -- the position of the crosshair to best represent the current Cyarm mode
	"""
	assert(false, "Override me in children.")
	return Globals.mouse_pos

func get_follow_pos(force_follow_player : bool = f_follow_player) -> Vector2:
	"""
	Returns : Vector2 -- the position that Cyarm should follow (travel towards)
	
	force_follow_player : bool -- whether Cyarm should follow Player
	"""
	if force_follow_player: f_follow_player = force_follow_player
	if f_follow_player:
		follow_pos = Globals.player_cyarm_follow_pos
		return follow_pos
	else:
		return follow_pos
	
func set_follow_pos(new_pos : Vector2, force_follow_player : bool = false) -> void:
	"""
	Sets the position that Cyarm should follow, then decides whether or not to follow
	given position, or the Player
	
	pos : Vector2 -- the position that Cyarm should follow (travel towards)
	follow_player : bool -- whether or not to follow Player, instead of provided new_pos
	"""
	follow_pos = new_pos
	f_follow_player = force_follow_player
	if force_follow_player: f_follow = true

func set_follow_player() -> void:
	"""
	Sets the Cyarm to follow the Player (Globals.player_cyarm_follow_pos)
	"""
	f_follow = true
	f_follow_player = true

func calc_follow() -> void:
	"""
	Calculates Cyarm velocity to follow Player. Runs every physics frame
	"""
	# Follow Player
	if f_follow:
		var follow_vel : Vector2 = (get_follow_pos() - global_position) * follow_acceleration.val
		velocity += follow_vel
		velocity *= elasticity
		velocity = Vector2(clampf(velocity.x, -follow_max_speed.val, follow_max_speed.val),
						   clampf(velocity.y, -follow_max_speed.val, follow_max_speed.val))

func update_physics_flags(_delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	assert(false, "Override me in children.")

func do_physics_state_func(_delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	assert(false, "Override me in children.")

func bob(delta : float) -> void:
	"""
	Calculates velocity for Cyarm to bob
	
	delta : float -- time between physics frames
	"""
	# Only bob once reaching Player
	if f_reached:
		var bob_vel_y = (sin(Time.get_ticks_msec() * bob_speed.val) * bob_distance * delta)
		c_sprite.position.y = c_sprite_orig_pos.y + bob_vel_y

func point_sprite_at(target : Vector2, force_instant : bool = false,
					 look_speed : float = 30.0, angle_offset : float = 0,
					 delta : float = get_physics_process_delta_time()) -> void:
	"""
	Rotates Cyarm sprite to look at a target
	
	target : Vector2 -- position to rotate towards
	force_instant : bool -- whether to instantly look at, or lerp smoothly there
	look_speed : float -- how fast to smoothly look there
	angle_offset : float -- offset to rotate sprite by (in radians)
	delta : float -- time between physics frames
	"""
	var _rotate_to : float = (global_position + c_sprite.position).angle_to_point(target) + angle_offset
	if force_instant:
		c_sprite.rotation = _rotate_to
	else:
		c_sprite.rotation = lerp_angle(c_sprite.rotation, _rotate_to, look_speed * delta)

func do_damage_to(hit_body : Node2D) -> DamageManager.DamageResult:
	"""
	Does damage to subject
	
	hit_body : Node2D -- subject that can possibly take damage
	
	Returns : DamageManager.DamageResult -- the result of the damage
	"""
	# Make sure that Cyarm doesn't "hit" the same target multiple times in quick succession
	if (
			damaged_dict.has(hit_body)
		and
			Time.get_ticks_msec() - damaged_dict[hit_body] < damage_mtick_cooldown
		):
		return DamageManager.DamageResult.IGNORE # Does no damage this instance
	
	else:
		# Do damage to subject
		var _dmg_result : DamageManager.DamageResult = DamageManager.calc_damage(get_damage(), hit_body)
		if _dmg_result != DamageManager.DamageResult.IGNORE:
			# Save the time of this hit
			damaged_dict[hit_body] = Time.get_ticks_msec()
			
			# If Cyarm can damage subject, then request ElectroManager to generate electro
			sig_electroMgr_electro_hit.emit()
			
		return _dmg_result

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Cyarm currently does
	"""
	assert(false, "Override me in children.")
	return o_no_damage

######################
## Action functions
######################
func get_primary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for the Cyarm's primary action
	"""
	assert(false, "Override me in children.")
	return null

func get_secondary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for the Cyarm's secondary action
	"""
	assert(false, "Override me in children.")
	return null

func calc_primary_action() -> void:
	"""
	Calculates the Cyarm's primary action on button state
	"""
	match primaryaction_butt_state:
		BUTT_STATE.JUST_PRESSED:
			do_just_pressed(ACTION_TYPE.PRIMARY)
		BUTT_STATE.HELD:
			do_held(ACTION_TYPE.PRIMARY)
		BUTT_STATE.JUST_RELEASED:
			do_just_released(ACTION_TYPE.PRIMARY)

	# After Cyarm has reacted to current primary action button state
	# reset state back to NONE so Cyarm can later respond to next button state
	primaryaction_butt_state = BUTT_STATE.NONE

func calc_secondary_action() -> void:
	"""
	Calculates the Cyarm's secondary action on button state
	"""
	match secondaryaction_butt_state:
		BUTT_STATE.JUST_PRESSED:
			do_just_pressed(ACTION_TYPE.SECONDARY)
		BUTT_STATE.HELD:
			do_held(ACTION_TYPE.SECONDARY)
		BUTT_STATE.JUST_RELEASED:
			do_just_released(ACTION_TYPE.SECONDARY)

	# After Cyarm has reacted to current secondary action button state
	# reset state back to NONE so Cyarm can later respond to next button state
	secondaryaction_butt_state = BUTT_STATE.NONE

func do_just_pressed(regarding_action : ACTION_TYPE) -> void:
	"""
	Calculates the Cyarm's primary action on just pressed button state
	
	regarding_action : ACTION_TYPE -- whether this function handles primary or secondary action
	"""
	match regarding_action:
		ACTION_TYPE.PRIMARY:
			o_curr_primary_action.func_just_pressed_primary.call()
			o_curr_secondary_action.func_just_pressed_primary.call()
		ACTION_TYPE.SECONDARY:
			o_curr_primary_action.func_just_pressed_secondary.call()
			o_curr_secondary_action.func_just_pressed_secondary.call()

func do_held(regarding_action : ACTION_TYPE) -> void:
	"""
	Calculates the Cyarm's primary action on held button state

	regarding_action : ACTION_TYPE -- whether this function handles primary or secondary action
	"""
	match regarding_action:
		ACTION_TYPE.PRIMARY:
			o_curr_primary_action.func_held_primary.call()
			o_curr_secondary_action.func_held_primary.call()
		ACTION_TYPE.SECONDARY:
			o_curr_primary_action.func_held_secondary.call()
			o_curr_secondary_action.func_held_secondary.call()

func do_just_released(regarding_action : ACTION_TYPE) -> void:
	"""
	Calculates the Cyarm's primary action on just released button stat

	regarding_action : ACTION_TYPE -- whether this function handles primary or secondary action
	"""
	match regarding_action:
		ACTION_TYPE.PRIMARY:
			o_curr_primary_action.func_just_released_primary.call()
			o_curr_secondary_action.func_just_released_primary.call()
		ACTION_TYPE.SECONDARY:
			o_curr_primary_action.func_just_released_secondary.call()
			o_curr_secondary_action.func_just_released_secondary.call()

######################
## Move-on-rails functions
######################
func move_onrails(delta : float) -> void:
	"""
	Moves Cyarm
	Handles calculations using Cyarm's MoveOnRails object (o_move_onrails)

	delta : float -- time between physics frames
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		_o_r.RAIL_TYPE.TO_TARGET:
			## Move Cyarm to target position
			global_position = global_position.move_toward(_o_r.move_onrails_target,
														  _o_r.move_onrails_speed.val * delta)

			move_onrails_during() # Perform Cyarm mode-specific actions DURING move to target

			## Reached target position
			if global_position == _o_r.move_onrails_target:
				velocity = Vector2.ZERO # Freeze Cyarm

				move_onrails_after() # Perform Cyarm mode-specific actions AFTER reaching target

				_o_r.cleanup() # Cleanup this particular move-on-rails

func move_onrails_during() -> void:
	"""
	Actions to perform during a move-on-rails 
	"""
	assert(false, "Override me in children.")

func move_onrails_after() -> void:
	"""
	Actions to perform after a move-on-rails is complete
	"""
	assert(false, "Override me in children.")

######################
## State & Animation functions
######################
func exit_state() -> void:
	"""
	Performs cleanup of current Cyarm state
	"""
	assert(false, "Override me in children.")

func trans_state(_new_enum_state : int, _cleanup : bool = true) -> void:
	"""
	Transitions to new Cyarm state
	
	_new_enum_state : int -- new Cyarm state enum
	cleanup : bool = false -- whether or not to call exit_state() before transitioning to new state
	"""
	assert(false, "Override me in children.")

func set_hide(do_hide : bool) -> void:
	"""
	Hides Cyarm sprite
	
	do_hide : bool -- whether to hide or show Cyarm sprite
	"""
	if not do_hide: # Show Cyarm
		if f_disabled:
			return # Don't attempt to show a disabled Cyarm
		
	f_hidden = do_hide
	visible = (not do_hide)

func update_animations() -> void:
	"""
	Updates Cyarm sprite to animation matching current state
	"""
	assert(false, "Override me in children.")

func update_trails(keep_trail : bool = true) -> void:
	"""
	Updates a light-trail to follow Cyarm
	
	keep_trail : bool -- whether or not to clear the current trail
	"""	
	for index in len(o_cyarm_trail.trail_arr):
		if not keep_trail: # Clear trail
			o_cyarm_trail.clear_trail(index)
		else: # Draw trail
			o_cyarm_trail.update_trail(index)

##################
## Received Signals
##################
func _on_received_player_died() -> void:
	"""
	Disables Cyarm control
	"""
	disable()

func _on_received_hide(do_hide : bool) -> void:
	"""
	Hides Cyarm sprite
	
	do_hide : bool -- whether to hide or show Cyarm sprite
	"""
	set_hide(do_hide)
