extends CyarmBase
class_name CyarmSpear

### Component references
@onready var c_raycast_spear_terrain : RayCast2D = $CyarmSprite/TerrainCast
@onready var c_raycast_spear_enemies : RayCast2D = $CyarmSprite/EnemyCast
@onready var c_raycast_spear_first_enemy : RayCast2D = $CyarmSprite/FirstEnemyCast
@onready var c_raycast_spear_canplayerdash : RayCast2D = $CanPlayerDashCast
@onready var c_marker_spear_trailpos : Marker2D = $CyarmSprite/SpearTrailMarker
@onready var c_marker_spear_tip : Marker2D = $CyarmSprite/SpearTipMarker
@onready var c_line_spear_trail : Line2D = $Trails/SpearTrail
@onready var c_line_spear_throw_indicator : Line2D = $Trails/ThrowIndicator
@onready var c_line_spear_candash_indicator : Line2D = $Trails/CanDashIndicator
@onready var c_timer_spear_throwcooldown : Timer = $Timers/ThrowTimer
@onready var c_timer_spear_tether_afterland_cooldown : Timer = $Timers/TetherAfterLandTimer

### Spear lookat variables
var spear_lookat_speed : ConstValPair = ConstValPair.new(30.0, 30.0) # Don't set as CVP_Speed, because it feels better not to slow this during time slow
var spear_rotation_offset : float = deg_to_rad(225)

### Spear trail variables
var spear_trail_len : int = 30

### Spear action variables
var o_cyactiontext_primary_spear_throw : CyarmActionTexture
var o_cyactiontext_primary_spear_tether : CyarmActionTexture
var o_cyactiontext_secondary_spear_tether_slow : CyarmActionTexture
var o_cyactiontext_secondary_spear_dash : CyarmActionTexture
var o_cyactiontext_secondary_spear_broom : CyarmActionTexture
var spear_throw_primary_action_text : Texture2D = preload("res://sprites/UI/UI_action_primary_spear_throw.png")
var spear_tether_primary_action_text : Texture2D = preload("res://sprites/UI/UI_action_primary_spear_tether.png")
var spear_tether_slow_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_spear_tether_slow.png")
var spear_dash_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_spear_dash.png")
var spear_broom_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_spear_broom.png")
var o_cyactionbundle_primary_spear_throw : CyarmActionBundle
var o_cyactionbundle_primary_spear_tether : CyarmActionBundle
var o_cyactionbundle_secondary_spear_dash : CyarmActionBundle
var o_cyactionbundle_secondary_spear_broom : CyarmActionBundle

### Spear Throw variables
var f_after_enable_throw : bool = false
var spear_trajectory_width_col : float = 10
var spear_trajectory_width_NO_col : float = 5
var spear_throw_speed : CVP_Speed = CVP_Speed.new(3000.0)
var spear_throw_cooldown_duration : CVP_Duration = CVP_Duration.new(0.15, true, c_timer_spear_throwcooldown) # How often Cyarm-Spear can throw
var spear_throw_max_distance : float = 1000.0
var spear_throw_queued_end_pos : Vector2
var spear_hit_queue : Array = []
var spear_notify_queue : Array = []
var spear_pierce_max : int = 10
var o_spear_throw_damage : DamageManager.DamageBase
var spear_throw_dmg : int = 60
var spear_throw_crit : float = 0.15
var dmg_spread : int = 10

# Class used to store related Spear throw attributes together
var o_spear_throw : SpearThrowBundle
class SpearThrowBundle:
	var f_hit_something : bool
	var f_found_wall : bool
	var spear_target_pos : Vector2 # Position Spear should be positioned when stuck in wall
	var hit_pos : Vector2 # Position of Spear hit
	var hit_normal: # Either returns a Vector2, or a false
		get:
			if f_found_wall:
				return hit_normal
			else:
				return false

	func _init():
		reset()

	func set_hit_without_normal(_hit_pos) -> void:
		"""
		Set attributes if Spear throw would NOT hit terrain
		"""
		hit_pos = _hit_pos
		f_found_wall = false

		# Spear target position is same as hit position
		spear_target_pos = hit_pos

	func set_hit_with_normal(_hit_pos, _hit_normal) -> void:
		"""
		Set attributes if Spear throw would hit terrain
		"""
		hit_pos = _hit_pos
		hit_normal = _hit_normal
		f_found_wall = true # If provided a normal, then naturally, Spear throw had found a wall to hit

		# Adjust position so only Spear-head sticks into the wall
		spear_target_pos = hit_pos + hit_normal * 5
		
	func set_hit(yes_hit : bool):
		"""
		yes_hit : bool -- whether or not Spear would hit something
		"""
		f_hit_something = yes_hit
		
	func reset():
		"""
		Resets the attributes of the SpearThrowBundle
		"""
		f_hit_something = false
		f_found_wall = false
		hit_pos = Vector2.ZERO
		hit_normal = Vector2.ZERO
		spear_target_pos = Vector2.ZERO

### Spear Dash
var f_spear_can_dash : bool = false
var f_queue_dash_during_throw : bool = false
var spear_curr_dist_to_player : float:
	get:
		return global_position.distance_to(Globals.player_center_pos)
var spear_max_dash_dist : float = 640.0
var spear_no_cost_dist : float = 50.0

### Speartether variables
var spear_tether_afterland_cooldown_duration : CVP_Duration = CVP_Duration.new(0.11, true, c_timer_spear_tether_afterland_cooldown) # How soon does tether activate if holding button after spear throw lands

### Spearbrooming variables
var f_spear_spearbrooming : bool = false

### State & Animations
enum SpearState {
	IDLING,
	THROWING,
	STUCK,
	RECALLING,
	SPEARBROOMING,
	SPEARTETHERING,
	}
var spear_curr_state : SpearState = SpearState.IDLING
var spear_state_as_str : String:
	get:
		return SpearState.keys()[spear_curr_state]
var anim_spear_idle : String = "spear_idle"

######################
## Main functions
######################
func _ready() -> void:
	super() # Call CyarmBase _ready()

	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_cyarm_follow_player", _on_received_follow_player)
	_Player.connect("sig_cyarm_spear_unlock", _on_received_spear_unlock)
	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_cyarm_sword_disabled", _on_received_cyarm_sword_disabled)
		cyarm.connect("sig_cyarm_shield_disabled", _on_received_cyarm_shield_disabled)
	var _CyarmManager : Node = get_tree().get_first_node_in_group("CyarmManager")
	_CyarmManager.connect("sig_cyMgr_cyarm_enabled", _on_received_cyMgr_cyarm_enabled)

	## Set timers
	c_timer_spear_throwcooldown.wait_time = spear_throw_cooldown_duration.val
	c_timer_spear_tether_afterland_cooldown.wait_time = spear_tether_afterland_cooldown_duration.val
	damage_mtick_cooldown = c_timer_spear_throwcooldown.wait_time * .99 * 1000 # Have damage tick always be below spear attack speed

	## Set raycasts
	spear_set_raylen(spear_throw_max_distance)

	## Create objects
	o_spear_throw = SpearThrowBundle.new()
	o_cyarm_trail.add_trail(c_line_spear_trail, c_marker_spear_trailpos, spear_trail_len) # Set up trail object
	# Set up CyarmActionTexture objects
	o_cyactiontext_primary_spear_throw = CyarmActionTexture.new(spear_throw_primary_action_text, func(): return 1)
	o_cyactiontext_primary_spear_tether = CyarmActionTexture.new(spear_tether_primary_action_text, func(): return 1)
	o_cyactiontext_secondary_spear_tether_slow = CyarmActionTexture.new(spear_tether_slow_secondary_action_text, func(): return 1)
	o_cyactiontext_secondary_spear_dash = CyarmActionTexture.new(spear_dash_secondary_action_text, func(): return 1)
	o_cyactiontext_secondary_spear_broom = CyarmActionTexture.new(spear_broom_secondary_action_text, func(): return 1)
	# Set up Cyarm-Spear damage object
	o_spear_throw_damage = DamageManager.DamageBase.new(_Player, spear_throw_dmg, dmg_spread, spear_throw_crit)

######################
## Enable/disable functions
######################
func enable_before() -> void:
	"""
	Sets up current Cyarm mode before enabling (before anything is visible and position is set)
	"""
	# Default flags
	f_follow = true
	
	# Default state
	trans_state(SpearState.IDLING)

func enable(enable_at_pos : Vector2, action_context : CyarmActionContext = null) -> void:
	"""
	Enables Cyarm at position (starts processing and shows sprite)
	
	enable_at_pos : Vector2 -- the global_position to enable Cyarm at
	action_context : CyarmActionContext = null -- the state of pressed action buttons + mouse global_position
	"""
	super(enable_at_pos)

	# If Cyarm-Spear was enabled in the middle of Cyarm-Sword slash, immediately throw Spear
	if f_after_enable_throw:
		# Point raycasts, calculate throw end position, then throw Spear
		point_sprite_at(spear_throw_queued_end_pos, true, spear_lookat_speed.val, spear_rotation_offset)
		spear_calc_throw_bundle()
		spear_throw()
	
	# If Player was standing atop of Cyarm-Shield during disable, automatically follow Player
	if f_after_enable_follow_player:
		set_follow_player()

func disable() -> void:
	"""
	Disables Cyarm (exits state, stop animations, processing, and movement)
	"""
	# Cyarm-Spear disabled signal
	if in_state(SpearState.SPEARBROOMING):
		sig_cyarm_spear_disabled.emit(true)
	
	super() # Call CyarmBase's disable()

	# Notifies any Enemy still logged in spear_notify_queue, that Spear cannot hit them anymore
	spear_populate_potential_hits(0, true)

######################
## SETUP functions
######################
func SETUP_cyarm_action_bundles() -> void:
	"""
	Sets up an CyarmActionBundle for each action Cyarm-Spear has:
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
	## Spear Aim/Throw
	o_cyactionbundle_primary_spear_throw = CyarmActionBundle.new(self, "spear_throw", true, null,
		## Primary action button
		func():
			spear_throw()
			,
		func():
			pass
			,
		func():
			pass
			,

		## Secondary action button
		func():
			pass
			,
		func():
			pass
			,
		func():
			pass
			,
		)

	## Spear Tether
	o_cyactionbundle_primary_spear_tether = CyarmActionBundle.new(self, "spear_tether", true, null,
		## Primary action button
		func():
			if in_state(SpearState.IDLING) or in_state(SpearState.STUCK):
				spear_tether_begin()
			,
		func():
			if (
					(in_state(SpearState.IDLING) or in_state(SpearState.STUCK)) # Spear landed
				and
					c_timer_spear_tether_afterland_cooldown.is_stopped() # Appropriate amount of time after landing
				):
				spear_tether_begin()
			,
		func():
			if in_state(SpearState.SPEARTETHERING):
				spear_tether_end() # Stop drawing tether
			,

		## Secondary action button
		func():
			if in_state(SpearState.SPEARTETHERING):
				spear_tether_slowdown(true) # Slow down time
			,
		func():
			pass
			,
		func(): 
			if in_state(SpearState.SPEARTETHERING):
				spear_tether_slowdown(false) # Restore time scale
			,
			)

	## Spear Dash
	o_cyactionbundle_secondary_spear_dash = CyarmActionBundle.new(self, "spear_dash", true, null,
		## Primary action button
		func():
			pass
			,
		func():
			pass
			,
		func():
			pass
			,

		## Secondary action button
		func():
			if not in_state(SpearState.SPEARTETHERING) and f_spear_can_dash: # No Terrain in the way, and enough electro to cast?
				spear_dash()
			,
		func():
			pass
			,
		func():
			pass
			,
		)

	## Spearbroom
	o_cyactionbundle_secondary_spear_broom = CyarmActionBundle.new(self, "spear_broom", true, null,
		## Primary action button
		func():
			pass
			,
		func():
			pass
			,
		func():
			pass
			,

		## Secondary action button
		func():
			# During Throw state, may need to queue dash to happen immediately during spearbroom action
			if o_move_onrails.is_active() and in_state(SpearState.THROWING):
				f_queue_dash_during_throw = true
				return
			else:
				spearbroom_begin()
			,
		func():
			if in_state(SpearState.SPEARBROOMING):
				spearbroom_during()
			elif in_state(SpearState.IDLING):
				spearbroom_begin()
			,
		func():
			spearbroom_end()
			,
			)

func SETUP_cyarm_state_bundles() -> void:
	"""
	Sets up o_cyarm_state_bundle_dict (a Dictionary of {SpearState -> CyarmStateBundle}):
		For each SpearState, sets up the prerequisite functions, such as what to do when
		exiting a particular state, or how to animate a particular state
	
	CyarmStateBundle object constructor arguments:
	CyarmStateBundle.new(
					_cyarm_ref : Node,
					_func_animate : Callable,            # Function to be called when animating SpearState
					_func_during_physics : Callable,     # Function to be called during physics_process while in SpearState
					_func_get_action_texture : Callable, # Function to be called during physics_process to get action texture
					_func_exit_state : Callable          # Function to be called after exiting SpearState
				)
	"""
	var _temp_casb : CyarmStateBundle

	for ss in SpearState.values(): # Iterate over enum values (the integers)
		match ss:
			SpearState.IDLING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_animplayer.play(anim_spear_idle)
						,
					func(delta : float):
						# Aim at mouse
						point_sprite_at(Globals.mouse_pos, false,
										spear_lookat_speed.val, spear_rotation_offset, delta)
						# Check if Spear can hit any Enemy
						spear_populate_potential_hits(1, true)
						# Update Spear indicator (draw line from Player to Spear, or Spear to end throw pos)
						spear_draw_indicator()
						,
					func(get_primary : bool):
						return spear_get_action_texture(get_primary)
						,
					func():
						pass
						,
					)
			SpearState.THROWING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return spear_get_action_texture(get_primary)
						,
					func():
						spear_clean_throw()
						,
					)
			SpearState.STUCK:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						# Notify Enemys that they cannot be hit
						spear_populate_potential_hits(0, true)
						# Update Spear indicator (draw line from Player to Spear, or Spear to end throw pos)
						spear_draw_indicator()
						,
					func(get_primary : bool):
						return spear_get_action_texture(get_primary)
						,
					func():
						pass
						,
					)
			SpearState.RECALLING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						if f_reached:
							# Once Spear has reached Player, switch to IDLING state
							trans_state(SpearState.IDLING)
						,
					func(get_primary : bool):
						return spear_get_action_texture(get_primary)
						,
					func():
						pass
						,
					)
			SpearState.SPEARBROOMING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return spear_get_action_texture(get_primary)
						,
					func():
						spearbroom_end()
						,
					)
			SpearState.SPEARTETHERING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return spear_get_action_texture(get_primary)
						,
					func():
						spear_tether_end()
						,
					)

		# Add particular CyarmStateBundle to dictionary, mapped to key of SpearState
		o_cyarm_state_bundle_dict[ss] = _temp_casb

######################
## Action functions
######################
func get_primary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Spear's primary action
	"""
	if f_follow_player:
		return o_cyactionbundle_primary_spear_throw
	else:
		return o_cyactionbundle_primary_spear_tether

func get_secondary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Spear's secondary action
	"""
	if f_follow_player:
		return o_cyactionbundle_secondary_spear_broom
	else:
		return o_cyactionbundle_secondary_spear_dash

######################
## Move-on-rails functions
######################
func move_onrails_during() -> void:
	"""
	Actions to perform during a move-on-rails 
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		_o_r.RAIL_TYPE.TO_TARGET:
			spear_hitscan() # While Spear is moving through air, find enemies in its path that are to be "hit"

func move_onrails_after() -> void:
	"""
	Actions to perform after a move-on-rails is complete
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		_o_r.RAIL_TYPE.TO_TARGET:
			spear_clean_throw() # Spear landed at position
			
			# Start timer, how long to wait after landing before tether begins (if action button was held)
			c_timer_spear_tether_afterland_cooldown.start()
			
			if f_queue_dash_during_throw:
				if f_spear_can_dash: # No Terrain in the way, and enough electro to cast?
					var _f_dash_to_spear = not f_follow_player
					if _f_dash_to_spear:
						spear_dash()
	
	# Cancel queue actions
	f_queue_dash_during_throw = false

######################
## State & Animation functions
######################
func in_state(query_state : SpearState) -> bool:
	"""
	query_state : SpearState -- state to query
	
	Returns : bool -- whether current Spear state matches query state
	"""
	return spear_curr_state == query_state

func exit_state() -> void:
	"""
	Performs cleanup of current Cyarm state
	"""
	# Updates sprite
	(o_cyarm_state_bundle_dict[spear_curr_state] as CyarmStateBundle).func_exit_state.call()

func trans_state(new_spear_state : SpearState, cleanup : bool = true) -> void:
	"""
	Transitions to new Cyarm state
	
	new_spear_state : SpearState -- new Cyarm-Spear state to transition to
	cleanup : bool = false -- whether or not to call exit_state() before transitioning to new state
	"""
	if cleanup and new_spear_state != spear_curr_state:
		# Only exit state if transitioning to a new state
		exit_state()

	spear_curr_state = new_spear_state

func update_animations() -> void:
	"""
	Updates Cyarm sprite to animation matching current state
	"""
	# Updates sprite
	(o_cyarm_state_bundle_dict[spear_curr_state] as CyarmStateBundle).func_animate.call()

	# Updates trails
	if in_state(SpearState.SPEARBROOMING): # Hide Cyarm-Spear
		update_trails(false) # Clear trail
	else:
		update_trails() # Draw trail

##################
## Shared Cyarm Functions
##################
func get_curr_state() -> String:
	"""
	Returns : String -- the state of the current Cyarm
	"""
	return spear_state_as_str

func get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	return (o_cyarm_state_bundle_dict[spear_curr_state] as CyarmStateBundle).func_get_action_texture.call(get_primary)

func get_crosshair_proposed_pos() -> Vector2:
	"""
	Returns : Vector2 -- the position of the crosshair to best represent the current Cyarm mode
	"""
	if in_state(SpearState.STUCK):
		return Globals.mouse_pos # Since Spear can't be thrown while stuck
	else:
		return o_spear_throw.hit_pos

func update_physics_flags(_delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	# Update Cyarm-Spear flags for this physics frame
	f_about_to_hit = not spear_hit_queue.is_empty() # If there are Enemys to notify, then set Spear flag can hit
	f_spear_can_dash = spear_can_player_dash()
	spear_calc_throw_bundle() # Populate bundle of Spear throw variables

func do_physics_state_func(delta : float) -> void:
	"""
	Runs every PHYSICS frame

	delta : float -- time between physics frames
	"""
	# Calls function specific to current SpearState every physics frame 
	(o_cyarm_state_bundle_dict[spear_curr_state] as CyarmStateBundle).func_during_physics.call(delta)

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Cyarm currently does
	"""
	return o_spear_throw_damage

##################
## Spear Specific Functions
##################
func spear_get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm-Spear action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	match spear_curr_state:
		SpearState.THROWING:
			if get_primary:
				return o_cyactiontext_primary_spear_tether.update_availability(0)
			else:
				return o_cyactiontext_secondary_spear_dash.update_availability(Globals.EM_f_can_electro_cast)
		SpearState.STUCK:
			if get_primary:
				return o_cyactiontext_primary_spear_tether.update_availability(1)
			else:
				return o_cyactiontext_secondary_spear_dash.update_availability(Globals.EM_f_can_electro_cast)
		SpearState.RECALLING:
			if get_primary:
				return o_cyactiontext_primary_spear_throw.update_availability(0)
			else:
				return o_cyactiontext_secondary_spear_broom.update_availability(0)
		SpearState.SPEARBROOMING:
			if get_primary:
				return o_cyactiontext_primary_spear_throw
			else:
				return o_cyactiontext_secondary_spear_broom.update_availability(Globals.EM_curr_electro_ratio)
		SpearState.SPEARTETHERING:
			if get_primary:
				return o_cyactiontext_primary_spear_tether.update_availability(Globals.EM_curr_electro_ratio)
			else:
				return o_cyactiontext_secondary_spear_tether_slow
		_: # Default
			if get_primary:
				if f_follow_player:
					return o_cyactiontext_primary_spear_throw.update_availability(1)
				else:
					return o_cyactiontext_primary_spear_tether.update_availability(1)
			else:
				if f_follow_player:
					return o_cyactiontext_secondary_spear_broom.update_availability(Globals.EM_curr_electro > 0.0)
				else:
					return o_cyactiontext_secondary_spear_dash.update_availability(Globals.EM_f_can_electro_cast)

func spear_set_raylen(hypotenuse : float) -> void:
	"""
	Sets Spear's "Terrain" and "Enemies" raycast lengths
	
	hypotenuse : float -- new length to set raycast to
	"""
	Utilities.set_raycast_len(c_raycast_spear_enemies, hypotenuse, true)
	Utilities.set_raycast_len(c_raycast_spear_first_enemy, hypotenuse, true)
	Utilities.set_raycast_len(c_raycast_spear_terrain, hypotenuse, true)

func spear_can_player_dash() -> bool:
	"""
	Checks whether Player can dash to Spear, and emits signals to Player when dash is not possible
	
	Returns : bool -- whether Player can dash to Spear
	
	Dash NOT allowed when:
		Player doesn't have enough electro
		Cyarm-Spear is out of dash range
		Terrain is between Player and Spear
		
	"""
	var _f_can_dash : bool = false

	if spear_curr_dist_to_player > spear_max_dash_dist:
		# NO DASH if dash distance to Player is too great
		return false
	if (
				not Globals.EM_f_can_electro_cast
			and
				spear_curr_dist_to_player > spear_no_cost_dist
		):
		# NO DASH if Player has no electro AND Spear not close enough to dash for free
		return false

	c_raycast_spear_canplayerdash.target_position = Globals.player_center_pos - global_position # Point raycast FROM Spear TO Player
	c_raycast_spear_canplayerdash.force_raycast_update()
	
	if c_raycast_spear_canplayerdash.is_colliding():
		if Utilities.is_player(c_raycast_spear_canplayerdash.get_collider()):
			_f_can_dash = true # Clear line of sight from Spear to Player, so can dash
		# else: _f_can_dash = false # Hitting Terrain instead of Player, so NO dash

	return _f_can_dash

func spear_enemy_hit_valid() -> bool:
	"""
	Returns : bool -- whether the collision of the Enemy raycast is valid
	"""
	var _f_enemy_hit : bool = c_raycast_spear_first_enemy.is_colliding()
	var _f_terrain_hit : bool = c_raycast_spear_terrain.is_colliding()

	if _f_terrain_hit:
		# Enemy hit is valid ONLY if is distance is less than that of Terrain. (Otherwise means Spear is
		# aiming at wall before Enemy and wouldn't hit Enemy anyway)
		if (
			global_position.distance_squared_to(c_raycast_spear_first_enemy.get_collision_point())
			<=
			global_position.distance_squared_to(c_raycast_spear_terrain.get_collision_point())
			):
			pass # Continue to notify Enemy
		else:
			_f_enemy_hit = false # Enemy is behind Terrain, hit is NOT valid

	return _f_enemy_hit

func spear_draw_indicator() -> void:
	"""
	Draws an indicator from Player to Cyarm-Spear if Player is allowed to dash
	"""
	## If NOT following Player, draw indicator from Player to Spear
	if not f_follow_player:
		if f_spear_can_dash:
			# Draw the indicator if Spear is AWAY from Player, and Player is allowed to dash
			c_line_spear_candash_indicator.clear_points()
			c_line_spear_candash_indicator.set_default_color(Color("43efb53c"))
			c_line_spear_candash_indicator.add_point(to_local(Globals.player_center_pos)) # Player
			c_line_spear_candash_indicator.add_point(to_local(global_position)) # To Cyarm-Spear
			
			# Erase the throw indicator
			c_line_spear_throw_indicator.clear_points()
		else:
			# Erase the dash indicator
			c_line_spear_candash_indicator.clear_points()

	## If following Player, draw indicator from Spear tip to Spear throw end position
	else:
		# Construct the trajectory
		if o_spear_throw.f_hit_something: # If Spear would collide with "Terrain" or "Enemies" layer
			# Set bright color and bigger line thickness
			c_line_spear_throw_indicator.set_default_color(Globals.CY_RED)
			c_line_spear_throw_indicator.set_width(spear_trajectory_width_col)
		else:
			# Set dull color and thinner line thickness
			c_line_spear_throw_indicator.set_default_color(Color.GRAY)
			c_line_spear_throw_indicator.set_width(spear_trajectory_width_NO_col)

		# Draw the throw indicator
		c_line_spear_throw_indicator.clear_points()
		c_line_spear_throw_indicator.add_point(to_local(c_marker_spear_trailpos.global_position))
		c_line_spear_throw_indicator.add_point(to_local(o_spear_throw.hit_pos))
		
		# Erase the dash indicator
		c_line_spear_candash_indicator.clear_points()

func spear_calc_throw_bundle() -> void:
	"""
	Calculates the o_spear_throw object that stores position of throw and normal of collision point
	also calculates spear_throw_end_pos every physics frame
	"""
	var _spear_ray_dist = min(c_raycast_spear_terrain.global_position.distance_to(Globals.mouse_pos) + 1,
							  spear_throw_max_distance)
	spear_set_raylen(_spear_ray_dist) # Set raycast lengths as the distance to the mouse position

	o_spear_throw.set_hit(false) # On default, Spear collides with nothing

	## Calculate Spear hit
	# If Spear would collide with terrain
	if c_raycast_spear_terrain.is_colliding():
		# Set object bundle that will be used in spear_throw()
		var _hit_pos : Vector2 = c_raycast_spear_terrain.get_collision_point()
		var _hit_normal : Vector2 = c_raycast_spear_terrain.get_collision_normal()
		o_spear_throw.set_hit_with_normal(_hit_pos, _hit_normal)
		o_spear_throw.set_hit(true)
	
	# If Spear would collide with enemies or nothing
	else:
		# If Spear would collide with only enemies
		if c_raycast_spear_first_enemy.is_colliding():
			o_spear_throw.set_hit(true)

		# Spear end position after throw is the same whether hitting enemy or hitting nothing
		o_spear_throw.set_hit_without_normal(Globals.mouse_pos) # Mouse position

func spear_populate_potential_hits(max_hits : int, do_notify : bool = false) -> void:
	"""
	Populates an array of potential targets (spear_hit_queue) in Spear's throw path

	max_hits : int -- max amount of Enemys that Spear throw will scan for in a line
	do_notify : bool -- whether Enemy added to queue should be notified that it can be hit
	"""
	# Clean up Enemy raycast's exceptions
	c_raycast_spear_enemies.clear_exceptions() # Clear exceptions
	c_raycast_spear_enemies.force_raycast_update() # Force update this frame

	# Clear prior Enemy log
	spear_hit_queue.clear()

	# Scan ahead with Enemy raycast, add Enemy hit to queue, then ignore that Enemy so that
	# raycast may scan further ahead
	for i in range(max_hits):

		if not spear_enemy_hit_valid():
			break # Hit a "Terrain" collider instead of an "Enemies", so stop casting

		var _col_obj = c_raycast_spear_enemies.get_collider()
		if _col_obj and _col_obj.is_in_group("Enemy"):
			spear_hit_queue.push_back(_col_obj) # Queue to maintain order of enemy hits
			c_raycast_spear_enemies.add_exception(_col_obj) # Once enemy added, ignore in raycast
			c_raycast_spear_enemies.force_raycast_update() # Force update this frame

	# Notify Enemys that they can be hit
	if do_notify:
		for enemy_ref in spear_notify_queue:
			if not spear_hit_queue.has(enemy_ref):
				# If the Enemy has been erased from spear_hit_queue, then notify Enemy that it cannot be hit anymore
				Utilities.notify_can_be_hit(enemy_ref, false)

		spear_notify_queue = spear_hit_queue.duplicate(false) # Copy spear_hit_queue over to spear_notify_queue
		for enemy_ref in spear_notify_queue:
			# Notify every Enemy in spear_hit_queue, that it can be hit
			Utilities.notify_can_be_hit(enemy_ref, true)

func spear_throw(target_pos : Vector2 = o_spear_throw.spear_target_pos) -> void:
	"""
	Cyarm-Spear throw
	"""
	if not c_timer_spear_throwcooldown.is_stopped(): return # Spear throw cooldown

	# Point sprite at target instantly before throw
	point_sprite_at(target_pos, true, spear_lookat_speed.val, spear_rotation_offset)

	# Before Spear throw, log all Enemys that would be hit by the throw, so that collisions can be checked
	# in spear_hitscan()
	spear_populate_potential_hits(spear_pierce_max, false)

	# Begin moving Spear towards target
	o_move_onrails.begin_to_target(target_pos, spear_throw_speed.val)

	c_timer_spear_throwcooldown.start() # Start Spear throw cooldown
	f_follow = false
	trans_state(SpearState.THROWING)

func spear_hitscan() -> void:
	"""
	Scan for enemies in Spear thrown path to be "hit", since Spear moves too fast
	to reliably trigger _on_body_entered() signal
	
	Called in during_move_onrails()
	"""
	# During a Cyarm-Spear throw, iterate through queue of Enemy hits collected in spear_populate_potential_hits()
	# if Spear-head has moved PAST the Enemy hit position, then emit signal for Enemy to be hit,
	# and remove that Enemy from the queue
	var _o_r : MoveOnRails = o_move_onrails
	var _sp_state = get_world_2d().get_direct_space_state()
	var _hits_to_pop : int = 0 # Every hit pops from the queue
	for enemy_ref in spear_hit_queue:
		var _spearhead_pos = c_marker_spear_tip.global_position # Spear-tip position
		var _hit_pos = Utilities.get_middlepos_of(enemy_ref) # Enemy position

		## First, check if speartip is INSIDE enemy hitbox (counts as a hit)
		var _query = PhysicsPointQueryParameters2D.new()
		_query.position = _spearhead_pos
		_query.collision_mask = enemy_ref.collision_mask
		var _col = _sp_state.intersect_point(_query, 1)
		if _col and _col[0]["collider_id"] == enemy_ref.get_instance_id():
			spear_throw_hit(enemy_ref, _hit_pos) # Send signal to enemy that it was hit
			_hits_to_pop += 1
			break # First check succeeded, so break from the loop early

		## If first check fails, then check if speartip has PASSED enemy position (counts as a hit)
		var _hit_normal : Vector2 = (_o_r.move_onrails_target - _o_r.move_onrails_start).normalized() # Unit vector that points from ENEMY position AWAY (in direction of spear throw)
		var _hit_to_spearhead_dir : Vector2 = (_spearhead_pos - _hit_pos).normalized() # Unit vector that points from ENEMY position to current SPEARHEAD position
		# If dot product positive, then both unit vectors are facing same direction, meaning spearhead has PASSED the enemy
		# (negative means that spearhead has NOT yet PASSED the enemy)
		var _passed_dot : float = _hit_normal.dot(_hit_to_spearhead_dir)
		if _passed_dot > 0:
			spear_throw_hit(enemy_ref, _hit_pos) # Send signal to enemy that it was hit
			_hits_to_pop += 1

	# Once all of the queue has been checked
	for i in range(_hits_to_pop):
		spear_hit_queue.pop_front() # Clear the queue in order (FIFO)
		
		# Notify Enemy that it cannot be hit anymore by current Spear pos
		var enemy_ref : Node = spear_notify_queue.pop_front() # Clear notify queue in same order
		Utilities.notify_can_be_hit(enemy_ref, false)

func spear_throw_hit(body : Node2D, spawn_pos : Vector2) -> void:
	"""
	Cyarm-Spear throw-hit
	"""
	# Damage Enemy, then spawn hit effect
	do_damage_to(body)
	sig_world_spawn_rot_effect.emit(spawn_pos, c_sprite.rotation - spear_rotation_offset, PSLib.anim_hit_effect)

func spear_clean_throw():
	"""
	Attributes to set once Cyarm-Spear lands
	"""
	# If the spear actually hits a wall
	if o_spear_throw.hit_normal:
		# Rotate Spear so that it is perpendicular to the wall
		var _ang : float = atan2(o_spear_throw.hit_normal.y,
								 o_spear_throw.hit_normal.x) + spear_rotation_offset + PI
		c_sprite.rotation = _ang
		c_sprite.position = c_sprite_orig_pos

	# Clean up the enemies raycast
	c_raycast_spear_enemies.clear_exceptions() # Clear exceptions
	c_raycast_spear_enemies.force_raycast_update() # Force update this frame

	# Set Cyarm follow position to landing point, away from Player
	set_follow_pos(o_spear_throw.spear_target_pos)
	f_follow = true # Cyarm's new follow point is where Spear landed
	
	# Set Spear state depending on where it landed
	if o_spear_throw.hit_normal:
		trans_state(SpearState.STUCK, false) # Stuck in a wall
	else:
		trans_state(SpearState.IDLING, false)

	# Clean up SpearThrowBundle
	o_spear_throw.reset()
	
func spear_recall():
	"""
	Returns Spear to Player
	"""
	set_follow_pos(Globals.player_cyarm_follow_pos, true)
	trans_state(SpearState.RECALLING)

func spear_dash():
	"""
	Returns Spear to Player
	"""
	sig_player_dash_to_spear.emit() # Signal Player to dash to Spear
	if spear_curr_dist_to_player > spear_no_cost_dist:
		# Only Signal ElectroManager to decrease electro for dashing if the distance is great,
		# costs no electro if Spear is close to Player
		sig_electroMgr_electro_spear_dash.emit()
	
	# Lock Cyarm-Spear from changing form until after dash is completed
	f_locked = true

func spearbroom_begin() -> void:
	"""
	Begin spearbrooming
	"""
	sig_player_spearbroom.emit(true) # Signal Player to spearbroom (and hide Cyarm-Spear)
	set_follow_player() # Follow Player
	f_spear_spearbrooming = true
	trans_state(SpearState.SPEARBROOMING)

func spearbroom_during() -> void:
	"""
	During spearbrooming
	"""
	pass

func spearbroom_end() -> void:
	"""
	End spearbrooming
	"""
	sig_player_spearbroom.emit(false)
	f_spear_spearbrooming = false
	trans_state(SpearState.IDLING, false)

func spear_tether_begin() -> void:
	"""
	Begin Cyarm-Spear tether
	"""
	sig_player_speartether.emit(true) # Tell Player to begin tether to Spear
	
	sig_cyMgr_request_camera_focus.emit(self) # Focus camera on pivot point (Cyarm-Spear)
	
	trans_state(SpearState.SPEARTETHERING) # Set state

func spear_tether_slowdown(do_slow_time : bool) -> void:
	"""
	During Cyarm-Spear tether (grapple)
	"""
	if do_slow_time:
		Globals.set_time_scale_slow()
	else:
		# Return time to normal when done tethering
		Globals.set_time_scale_normal()

func spear_tether_during() -> void:
	"""
	During Cyarm-Spear tether
	"""
	pass

func spear_tether_end() -> void:
	"""
	End Cyarm-Spear tether
	"""
	spear_tether_slowdown(false) # Set time scale back to normal
	
	sig_player_speartether.emit(false) # Tell Player to stop tether to Spear
	
	trans_state(SpearState.IDLING, false)

##################
## Received Signals
##################
func _on_received_follow_player() -> void:
	"""
	Sent by Player after dash, to automatically "pickup" Cyarm
	"""
	spear_recall()

func _on_received_spear_unlock() -> void:
	"""
	Sent by Player after dash, to unlock Spear and allow it to change Cyarm mode again
	"""
	f_locked = false

func _on_received_cyarm_sword_disabled(disabled_during_slash_mouse_pos : Vector2, _disabled_during_sword_board : bool) -> void:
	"""
	Cyarm-Sword was disabled
	
	disabled_during_slash_mouse_pos : Vector2 -- the mouse position when Sword was disabled mid-slash
	_disabled_during_sword_board : Vector2 -- whether Sword was disabled while swordboarding
	"""
	# If Cyarm-Sword was disabled mid-slash, immediately throw Spear in direction of slash
	if disabled_during_slash_mouse_pos != Vector2.ZERO:
		spear_throw_queued_end_pos = disabled_during_slash_mouse_pos
		f_after_enable_throw = true

func _on_received_cyarm_shield_disabled(disabled_in_shield_guard_range : bool) -> void:
	"""
	Cyarm-Shield was disabled
	
	disabled_in_shield_guard_range : bool -- whether Player was within Shield guard range during disable
	"""
	# If Player was standing on top of Shield during disable, automatically follow Player
	f_after_enable_follow_player = disabled_in_shield_guard_range

func _on_received_cyMgr_cyarm_enabled() -> void:
	"""
	A Cyarm mode was just enabled. Signal received after CyarmBase.enable()
	"""
	# After a Cyarm was enabled, reset enable flags
	f_after_enable_throw = false
	f_after_enable_follow_player = false
