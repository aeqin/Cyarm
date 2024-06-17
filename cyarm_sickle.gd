extends CyarmBase
class_name CyarmSickle

### Component references
@onready var c_raycast_sickle_whip_terrain : RayCast2D = $DO_NOT_MOVE/WhipTerrainCast
@onready var c_shapecast_sickle_whip_enemies : ShapeCast2D = $DO_NOT_MOVE/WhipEnemyCast
@onready var c_marker_tether : Marker2D = $CyarmSprite/TetherPos
@onready var c_line_sickle_tether : Line2D = $DO_NOT_MOVE/SickleTether
@onready var c_timer_sling_cooldown : Timer = $Timers/SlingCooldown

### Sickle action variables
var o_cyactiontext_primary_sickle_pull_player_to_target : CyarmActionTexture
var o_cyactiontext_secondary_sickle_pull_target_to_player : CyarmActionTexture
var o_cyactiontext_icon_sickle : CyarmActionTexture
var o_cyactiontext_icon_sickle_pull_player_to_target : CyarmActionTexture
var o_cyactiontext_icon_sickle_pull_target_to_player : CyarmActionTexture
var icon_sickle_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_sickle.png")
var icon_sickle_pull_player_to_target_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_sickle_pull_player_to_target.png")
var icon_sickle_pull_target_to_player_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_sickle_pull_target_to_player.png")
var sickle_pull_player_to_target_primary_action_text : Texture2D = preload("res://sprites/UI/UI_action_primary_sickle_pull_player_to_target.png")
var sickle_pull_target_to_player_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_sickle_pull_target_to_player.png")
var o_cyactionbundle_primary_sickle_sling : CyarmActionBundle
var o_cyactionbundle_secondary_sickle_whip : CyarmActionBundle

### Sickle Sling Shard variables
var f_after_enable_sling_shard : bool # Immediately sling CyarmSickleShard after enable
var sickle_sling_cooldown_duration : CVP_Duration = CVP_Duration.new(0.2, true, c_timer_sling_cooldown) # How often Cyarm-Sickle can sling shards
var sickle_shard_stored_pickups : int # How many Shards has Player picked up before throwing another Shard
var o_sickle_shard_damage : DamageManager.DamageBase
var sickle_shard_dmg : int = 4
var sickle_shard_crit : float = 0.1
var sickle_shard_dmg_spread : int = 1

### Sickle Whip variables
var f_sickle_whip_hit_something : bool = false:
	set(flag):
		f_sickle_whip_hit_something = flag
		if not f_sickle_whip_hit_something:
			f_sickle_whip_reached_hit = false # Reset reached flag if calculated flag was determined to be no hit
var f_sickle_whip_reached_hit : bool = false
var sickle_whip_target_pos: Vector2
var dir_to_sickle_whip_target : Vector2
var sickle_whip_max_len : float = 170
var sickle_whip_speed : CVP_Speed = CVP_Speed.new(2500.0)
var sickle_rotation_offset : float:
	get:
		if c_sprite.scale.x < 0:
			return 3 * PI / 4
		else:
			return PI / 4

### Sickle Pull variables
enum SicklePull {
	PLAYER_TO_TARGET,
	TARGET_TO_PLAYER,
	END_PULL,
	}
var sickle_curr_pull : SicklePull = SicklePull.END_PULL
var sickle_stuck_target : Node2D # What is the sickle stuck in?
var f_sickle_stuck_target_is_moveable : bool = false
var sickle_pullout_dmg : int = 80
var sickle_pullout_crit : float = 0.3
var dmg_spread : int = 10

### State & Animations
enum SickleState {
	IDLING,
	WHIPPING,
	HIT,
	SLINGING,
	}
var sickle_curr_state : SickleState = SickleState.IDLING
var sickle_state_as_str : String:
	get:
		return SickleState.keys()[sickle_curr_state]
var anim_sickle_idle : String = "sickle_idle"
var anim_sickle_whip : String = "sickle_whip"
var anim_sickle_hit : String = "sickle_hit"
var sickle_hit_anim_duration : CVP_Duration

######################
## Main functions
######################
func _ready() -> void:
	super() # Call CyarmBase _ready()

	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_cyarm_sicklepull_cancel", _on_received_sicklepull_cancel)
	Globals.connect("sig_globals_time_scale_changed", _on_received_globals_time_scale_changed)
	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_cyarm_sword_disabled", _on_received_cyarm_sword_disabled)
		cyarm.connect("sig_cyarm_shield_disabled", _on_received_cyarm_shield_disabled)
	var _CyarmManager : Node = get_tree().get_first_node_in_group("CyarmManager")
	_CyarmManager.connect("sig_cyMgr_cyarm_enabled", _on_received_cyMgr_cyarm_enabled)

	## Set timers
	c_timer_sling_cooldown.wait_time = sickle_sling_cooldown_duration.val

	## Set raycasts

	## Create objects
	# Set up CyarmActionTexture objects
	o_cyactiontext_primary_sickle_pull_player_to_target = CyarmActionTexture.new(sickle_pull_player_to_target_primary_action_text, sickle_get_pull_player_to_target_availability)
	o_cyactiontext_secondary_sickle_pull_target_to_player = CyarmActionTexture.new(sickle_pull_target_to_player_secondary_action_text, sickle_get_pull_player_to_target_availability)
	o_cyactiontext_icon_sickle = CyarmActionTexture.new(icon_sickle_text, func(): return 1)
	o_cyactiontext_icon_sickle_pull_player_to_target = CyarmActionTexture.new(icon_sickle_pull_player_to_target_text, sickle_get_pull_player_to_target_availability)
	o_cyactiontext_icon_sickle_pull_target_to_player = CyarmActionTexture.new(icon_sickle_pull_target_to_player_text, sickle_get_pull_target_to_player_availability)
	# Set up Cyarm-Sickle damage objects
	o_sickle_shard_damage = DamageManager.DamageBase.new(_Player, sickle_shard_dmg, sickle_shard_dmg_spread, sickle_shard_crit)

func update_globals():
	"""
	Updates Cyarm variables shared to Global script
	"""
	super() # call update_globals in CyarmBase
	Globals.cyarm_sickle_tetherpos = c_marker_tether.global_position

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
	trans_state(SickleState.IDLING)

func enable(enable_at_pos : Vector2, action_context : CyarmActionContext = null) -> void:
	"""
	Enables Cyarm at position (starts processing and shows sprite)
	
	enable_at_pos : Vector2 -- the global_position to enable Cyarm at
	action_context : CyarmActionContext = null -- the state of pressed action buttons + mouse global_position
	"""
	super(enable_at_pos)
	
	# If Cyarm-Sickle was enabled through Cyarm radial menu, instantly perform action
	if action_context:
		if action_context.primary_action_pressed:
			sickle_whip_begin(SicklePull.PLAYER_TO_TARGET)
		elif action_context.secondary_action_pressed:
			sickle_whip_begin(SicklePull.TARGET_TO_PLAYER)
	
	# If Cyarm-Sickle was enabled in the middle of Cyarm-Sword slash, immediately sling shard
	if f_after_enable_sling_shard:
		sickle_sling_shard_begin()

func disable() -> void:
	"""
	Disables Cyarm (exits state, stop animations, processing, and movement)
	"""
	# Send disabled signal
	sig_cyarm_sickle_disabled.emit()
	
	super() # Call CyarmBase's disable()

######################
## SETUP functions
######################
func SETUP_cyarm_action_bundles() -> void:
	"""
	Sets up an CyarmActionBundle for each action Cyarm-Sickle has:
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
	## Sickle Sling
	o_cyactionbundle_primary_sickle_sling = CyarmActionBundle.new(self, "sickle_spawn", true, null,
		## Primary action button
		func():
			if in_state(SickleState.IDLING): sickle_whip_begin(SicklePull.PLAYER_TO_TARGET)
			,
		func():
			pass
			,
		func():
			sickle_whip_end()
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
	
	## Sickle Whip
	o_cyactionbundle_secondary_sickle_whip = CyarmActionBundle.new(self, "sickle_whip", true, null,
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
			if in_state(SickleState.IDLING): sickle_whip_begin(SicklePull.TARGET_TO_PLAYER)
			,
		func():
			pass
			,
		func():
			sickle_whip_end()
			,
		)

func SETUP_cyarm_state_bundles() -> void:
	"""
	Sets up o_cyarm_state_bundle_dict (a Dictionary of {SickleState -> CyarmStateBundle}):
		For each SickleState, sets up the prerequisite functions, such as what to do when
		exiting a particular state, or how to animate a particular state
	
	CyarmStateBundle object constructor arguments:
	CyarmStateBundle.new(
					_cyarm_ref : Node,
					_func_animate : Callable,            # Function to be called when animating SickleState
					_func_during_physics : Callable,     # Function to be called during physics_process while in SickleState
					_func_get_action_texture : Callable, # Function to be called during physics_process to get action texture
					_func_exit_state : Callable          # Function to be called after exiting SickleState
				)
	"""
	var _temp_casb : CyarmStateBundle

	for ss in SickleState.values(): # Iterate over enum values (the integers)
		match ss:
			SickleState.IDLING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						# Updates direction of Sickle depending on Player facing direction
						if Globals.player_cyarm_follow_pos.x > Globals.player_center_pos.x:
							c_sprite.scale.x = 1
						else:
							c_sprite.scale.x = -1
							
						# Remove Sickle rotation
						c_sprite.rotation = 0

						# Clear Sickle tether
						sickle_draw_chain_tether(false)
						
						# Draw Sickle
						c_animplayer.play(anim_sickle_idle)
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sickle_get_action_texture(get_primary)
						,
					func():
						pass
						,
					)
			SickleState.WHIPPING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						# Draw Sickle tether
						sickle_draw_chain_tether(true)
						
						# Draw Sickle
						c_animplayer.play(anim_sickle_whip)
						,
					func(_delta : float):
						sickle_whip_during()
						,
					func(get_primary : bool):
						return sickle_get_action_texture(get_primary)
						,
					func():
						sickle_draw_chain_tether(false) # Clear Sickle tether
						,
					)
			SickleState.HIT:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						# Draw Sickle tether
						sickle_draw_chain_tether(true)
						
						# Draw Sickle
						Utilities.play_no_repeat(c_animplayer, anim_sickle_hit)
						,
					func(_delta : float):
						sickle_hit_during() # Follow potentially moving Target
						,
					func(get_primary : bool):
						return sickle_get_action_texture(get_primary)
						,
					func():
						sickle_draw_chain_tether(false) # Clear Sickle tether
						sig_player_sicklepull.emit(false, null) # Signal Player to end Sickle pull decision
						,
					)

		# Add particular CyarmStateBundle to dictionary, mapped to key of SickleState
		o_cyarm_state_bundle_dict[ss] = _temp_casb

######################
## Action functions
######################
func get_primary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Sickle's primary action
	"""
	return o_cyactionbundle_primary_sickle_sling

func get_secondary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Sickle's secondary action
	"""
	return o_cyactionbundle_secondary_sickle_whip

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
			pass

func move_onrails_after() -> void:
	"""
	Actions to perform after a move-on-rails is complete
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		_o_r.RAIL_TYPE.TO_TARGET:
			# Reached Sickle whip target, so set flag that SOMETHING was hit
			if in_state(SickleState.WHIPPING):
				f_sickle_whip_reached_hit = true

######################
## State & Animation functions
######################
func in_state(query_state : SickleState) -> bool:
	"""
	query_state : SickleState -- state to query
	
	Returns : bool -- whether current Sickle state matches query state
	"""
	return sickle_curr_state == query_state

func exit_state() -> void:
	"""
	Performs cleanup of current Cyarm state
	"""
	# Updates sprite
	(o_cyarm_state_bundle_dict[sickle_curr_state] as CyarmStateBundle).func_exit_state.call()

func trans_state(new_sickle_state : SickleState, cleanup : bool = true) -> void:
	"""
	Transitions to new Cyarm state
	
	new_sickle_state : SickleState -- new Cyarm-Sickle state to transition to
	cleanup : bool = false -- whether or not to call exit_state() before transitioning to new state
	"""
	if cleanup and new_sickle_state != sickle_curr_state:
		# Only exit state if transitioning to a new state
		exit_state()

	sickle_curr_state = new_sickle_state

func update_animations() -> void:
	"""
	Updates Cyarm sprite to animation matching current state
	"""
	# Updates sprite
	(o_cyarm_state_bundle_dict[sickle_curr_state] as CyarmStateBundle).func_animate.call()

##################
## Shared Cyarm Functions
##################
func get_curr_state() -> String:
	"""
	Returns : String -- the state of the current Cyarm
	"""
	return sickle_state_as_str

func get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	return (o_cyarm_state_bundle_dict[sickle_curr_state] as CyarmStateBundle).func_get_action_texture.call(get_primary)

func get_radial_icon_action_texture(_action_context : CyarmActionContext) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture for CyarmRadialMenu, of the next action based on pressed action buttons
	
	_action_context : CyarmActionContext -- whether or not action buttons are pressed + mouse global position
	"""
	if _action_context == null: # If context doesn't matter, return base icon
		return o_cyactiontext_icon_sickle

	if _action_context.primary_action_pressed:
		return o_cyactiontext_icon_sickle_pull_player_to_target
	elif _action_context.secondary_action_pressed:
		return o_cyactiontext_icon_sickle_pull_target_to_player
		
	return o_cyactiontext_icon_sickle

func get_crosshair_proposed_pos() -> Vector2:
	"""
	Returns : Vector2 -- the position of the crosshair to best represent the current Cyarm mode
	"""
	return Globals.mouse_pos

func update_physics_flags(_delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	# Update Cyarm-Sickle flags for this physics frame
	pass

func do_physics_state_func(delta : float) -> void:
	"""
	Runs every PHYSICS frame

	delta : float -- time between physics frames
	"""
	# Calls function specific to current SickleState every physics frame 
	(o_cyarm_state_bundle_dict[sickle_curr_state] as CyarmStateBundle).func_during_physics.call(delta)

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Cyarm currently does
	"""
	return o_no_damage

##################
## Sickle Specific Functions
##################
func sickle_get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm-Sickle action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	if get_primary:
		return o_cyactiontext_primary_sickle_pull_player_to_target
	else:
		return o_cyactiontext_secondary_sickle_pull_target_to_player

func sickle_get_pull_player_to_target_availability() -> float:
	"""
	Returns : float -- how "available" Sickle pull (PLAYER_TO_TARGET) is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1
	
func sickle_get_pull_target_to_player_availability() -> float:
	"""
	Returns : float -- how "available" Sickle pull (TARGET_TO_PLAYER) is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1

func sickle_sling_shard_begin() -> void:
	"""
	Begin Sickle sling shard
	"""
	if c_timer_sling_cooldown.is_stopped():
		var _dir_to_mouse : Vector2 = (Globals.mouse_pos - Globals.player_center_pos).normalized()
		sig_world_spawn_sickleshard.emit(self, Globals.player_center_pos + _dir_to_mouse * 20, _dir_to_mouse, sickle_shard_stored_pickups)
		sickle_shard_stored_pickups = 0 # Reset stored number of pickup shards
		
		c_timer_sling_cooldown.start() # Sling shard cooldown duration

func sickle_sling_shard_during() -> void:
	"""
	During Sickle sling shard
	"""
	pass
	
func sickle_sling_shard_end() -> void:
	"""
	End Sickle sling shard
	"""
	pass

func sickle_shard_pickup() -> void:
	"""
	Called by CyarmSickleShard. When Player pickups a launched CyarmSickleShard, power up the next Shard throw
	"""
	sickle_shard_stored_pickups += 1 # Empower the next CyarmSickleShard throw by number of pickups
	
	sig_player_sickleshard_pickup.emit() # Allow Player to jump again midair

func sickle_draw_chain_tether(do_draw : bool) -> void:
	"""
	Draws the chain tethering Sickle to Player
	"""
	if do_draw:
		var _tether_pos : Vector2
		if sickle_curr_state == SickleState.WHIPPING:
			_tether_pos = Globals.player_center_pos
		else: # sickle_curr_state == SickleState.HIT
			_tether_pos = Globals.player_sickle_tether_pos
		
		c_line_sickle_tether.clear_points()
		c_line_sickle_tether.add_point(_tether_pos)
		c_line_sickle_tether.add_point(c_marker_tether.global_position)
		
		# Move Sickle tether in front of Player
		c_line_sickle_tether.z_index = Globals.player_z_index + 1
	else:
		c_line_sickle_tether.clear_points()

		# Move Sickle tether behind Player
		c_line_sickle_tether.z_index = Globals.player_z_index - 1

func sickle_whip_begin(sicklepull_type : SicklePull, mouse_pos : Vector2 = Globals.mouse_pos) -> void:
	"""
	Begin Sickle whip
	
	sicklepull_type : SicklePull -- the type of pull to do, either pull Player to Target, or Target to Player
	"""
	# Position shape cast from center of Player towards the mouse position
	dir_to_sickle_whip_target = (mouse_pos - Globals.player_center_pos).normalized()
	c_shapecast_sickle_whip_enemies.global_position = Globals.player_center_pos
	c_shapecast_sickle_whip_enemies.target_position = dir_to_sickle_whip_target * min(sickle_whip_max_len, Globals.player_center_pos.distance_to(Globals.mouse_pos))
	c_shapecast_sickle_whip_enemies.enabled = true # Enable shape cast for this frame
	c_shapecast_sickle_whip_enemies.clear_exceptions()
	c_shapecast_sickle_whip_enemies.force_shapecast_update()
	
	# Collision
	f_sickle_whip_hit_something = false 
	var _f_target_is_terrain : bool
	var _nearest_to_mouse_pos : Vector2 = Globals.player_center_pos
	var _nearest_to_mouse_dist : float = mouse_pos.distance_squared_to(Globals.player_center_pos)
	while c_shapecast_sickle_whip_enemies.is_colliding():
		sickle_stuck_target = c_shapecast_sickle_whip_enemies.get_collider(0)
		var _enemy_or_terrain_RID : RID = c_shapecast_sickle_whip_enemies.get_collider_rid(0)
		var _f_potential_is_terrain : bool = Utilities.is_RID_terrain(_enemy_or_terrain_RID)
		var _potential_stuck_pos : Vector2
		if _f_potential_is_terrain:
			_potential_stuck_pos = c_shapecast_sickle_whip_enemies.get_collision_point(0) # If Terrain, then Sickle should be stuck at collision point
			f_sickle_stuck_target_is_moveable = false
		else:
			_potential_stuck_pos = Utilities.get_middlepos_of(sickle_stuck_target) # If Enemy, then Sickle should be stuck in middle of Enemy sprite
			f_sickle_stuck_target_is_moveable = true

		# Add collision to exceptions, so shape cast can find more collisions
		c_shapecast_sickle_whip_enemies.add_exception_rid(_enemy_or_terrain_RID)
		c_shapecast_sickle_whip_enemies.force_shapecast_update()
		
		# Save the collision nearest to mouse, for Sickle to get stuck onto
		var _dist_to_mouse = mouse_pos.distance_squared_to(_potential_stuck_pos)
		if _f_potential_is_terrain: _dist_to_mouse += 600 # Make it slightly harder to grab Terrain when mouse is near Enemy
		if _dist_to_mouse < _nearest_to_mouse_dist:
			_nearest_to_mouse_pos = _potential_stuck_pos
			_nearest_to_mouse_dist = _dist_to_mouse
			_f_target_is_terrain = _f_potential_is_terrain
			f_sickle_whip_hit_something = true
	
	# Once done, disable shape cast
	c_shapecast_sickle_whip_enemies.enabled = false
	
	# If Sickle were to be stuck on something
	if f_sickle_whip_hit_something:
		# If the Sickle were to be stuck in terrain, cast a raycast to it to get the collision (since
		# shape cast may collide inside the wall)
		if _f_target_is_terrain:
			c_raycast_sickle_whip_terrain.global_position = Globals.player_center_pos
			c_raycast_sickle_whip_terrain.target_position = _nearest_to_mouse_pos - Globals.player_center_pos
			c_raycast_sickle_whip_terrain.force_raycast_update()
			_nearest_to_mouse_pos = c_raycast_sickle_whip_terrain.get_collision_point()
			
		# Updates direction of Sickle depending on Player facing direction
		if _nearest_to_mouse_pos.x > Globals.player_center_pos.x:
			c_sprite.scale.x = 1
		else:
			c_sprite.scale.x = -1
		
		# Being moving Sickle towards target
		sickle_whip_target_pos = _nearest_to_mouse_pos
		o_move_onrails.begin_to_target(sickle_whip_target_pos, sickle_whip_speed.val)
		
		# Store whether Sickle will pull Player to Target, or vice versa
		sickle_curr_pull = sicklepull_type
	
	# If Sickle were to be stuck on nothing
	else:
		sickle_whip_target_pos = c_shapecast_sickle_whip_enemies.global_position + c_shapecast_sickle_whip_enemies.target_position

	# Point Sickle at target
	point_sprite_at(sickle_whip_target_pos, true, -1, sickle_rotation_offset)

	# Flags and State
	f_follow = false
	trans_state(SickleState.WHIPPING)

func sickle_whip_during() -> void:
	"""
	During Sickle whip
	"""
	# When Sickle is calculated to hit NOTHING
	if not f_sickle_whip_hit_something:
		# Move Sickle towards its max distance
		velocity = dir_to_sickle_whip_target * sickle_whip_speed.val

		# Reached past target position, return sickle back to Player
		var _curr_dir_to_sickle_whip_target : Vector2 = (sickle_whip_target_pos - global_position).normalized()
		if _curr_dir_to_sickle_whip_target.dot(dir_to_sickle_whip_target) < 0:
			sickle_whip_end(true)

	# Once Sickle actually hits something
	elif f_sickle_whip_reached_hit:
		set_follow_pos(sickle_whip_target_pos) # Next Cyarm position
		
		sig_player_sicklepull.emit(sickle_curr_pull, sickle_stuck_target) # Signal Player to begin Sickle pull decision
		
		trans_state(SickleState.HIT) # Set state

func sickle_hit_during() -> void:
	"""
	During Stickle hit, may have to update Sickle position as Target is being moved (pulled)
	"""
	if sickle_stuck_target == null:
		sickle_whip_end()

	if f_sickle_stuck_target_is_moveable:
		var _target_pos = Utilities.get_middlepos_of(sickle_stuck_target)
		if not Utilities.approx_equal_vec2(sickle_whip_target_pos, _target_pos):
			global_position = _target_pos
			sickle_whip_target_pos = _target_pos
			set_follow_pos(_target_pos)

func sickle_whip_end(do_clean : bool = false) -> void:
	"""
	End Sickle whip
	"""
	set_follow_player() # Return Sickle back to Player
	trans_state(SickleState.IDLING, do_clean)
	
	# Tell Player to end Sickle pull
	sickle_curr_pull = SicklePull.END_PULL
	sig_player_sicklepull.emit(sickle_curr_pull, sickle_stuck_target)

##################
## Received Signals
##################
func _on_received_sicklepull_cancel() -> void:
	"""
	Cancel Cyarm-Sickle pull (because decision was made)
	"""
	# Return Sickle back to Player
	if in_state(SickleState.HIT) or in_state(SickleState.WHIPPING):
		sickle_whip_end()

func _on_received_sicklepull_target_to_player_reached() -> void:
	"""
	Once Sickle target has reached position towards Player (signal sent by EnemyBase)
	"""
	# Return Sickle back to Player
	sickle_whip_end()

func _on_received_globals_time_scale_changed(_old_time_scale : float, _new_time_scale : float) -> void:
	"""
	When Globals time_scale is paused due to SicklePullDecision being spawned, all animations also pause,
	so unpause Cyarm-Sickle's animation so that the hit animation still plays
	"""
	if in_state(SickleState.HIT):
		c_animplayer.speed_scale = 1.0
		update_animations()

func _on_received_cyarm_sword_disabled(disabled_during_slash_mouse_pos : Vector2, _disabled_during_sword_board : bool) -> void:
	"""
	Cyarm-Sword was disabled
	
	disabled_during_slash_mouse_pos : Vector2 -- the mouse position when Sword was disabled mid-slash
	_disabled_during_sword_board : Vector2 -- whether Sword was disabled while swordboarding
	"""
	# If Cyarm-Sword was disabled mid-slash, immediately sling CyarmSickleShard in direction of slash
	if disabled_during_slash_mouse_pos != Vector2.ZERO:
		f_after_enable_sling_shard = true
	
	set_follow_player()

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
	f_after_enable_sling_shard = false
