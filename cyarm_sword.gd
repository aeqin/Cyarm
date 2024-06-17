extends CyarmBase
class_name CyarmSword

### Component references
@onready var c_area_sword_slash_potential : Area2D = $DO_NOT_MOVE/SlashPotentialMarker/SlashPotentialHitArea
@onready var c_collider_sword_slash_potential : CollisionShape2D = $DO_NOT_MOVE/SlashPotentialMarker/SlashPotentialHitArea/SlashPotentialCollider
@onready var c_collider_sword_slash : CollisionShape2D = $CyarmSprite/SlashHitArea/SlashCollider
@onready var c_shapecast_sword_spin : ShapeCast2D = $DO_NOT_MOVE/SpinCast
@onready var c_marker_sword_slashend : Marker2D = $CyarmSprite/SlashEndMarker
@onready var c_marker_sword_trailpos : Marker2D = $CyarmSprite/SwordTrailMarker
@onready var c_marker_sword_trailpos_mini1 : Marker2D = $CyarmSprite/SwordTrailMarkerMini1
@onready var c_marker_sword_trailpos_mini2 : Marker2D = $CyarmSprite/SwordTrailMarkerMini2
@onready var c_marker_sword_slash_potential : Marker2D = $DO_NOT_MOVE/SlashPotentialMarker
@onready var c_line_sword_trail : Line2D = $Trails/SwordTrail
@onready var c_line_sword_trail_mini1 : Line2D = $Trails/SwordTrailMini1
@onready var c_line_sword_trail_mini2 : Line2D = $Trails/SwordTrailMini2
@onready var c_timer_sword_cooldown : Timer = $Timers/AttackCooldown
@onready var c_timer_sword_slash_queued_buffer : Timer = $Timers/SlashQueuedBuffer
@onready var c_timer_swordboard_cooldown : Timer = $Timers/SwordboardCooldown
@onready var c_timer_swordiai_cooldown : Timer = $Timers/SwordIaiCooldown

### Sword trail variables
var sword_trail_len : int = 16
var sword_trail_len_mini1 : int = 8
var sword_trail_len_mini2 : int = 8

### Sword action variables
var o_cyactiontext_primary_sword_slash : CyarmActionTexture
var o_cyactiontext_secondary_sword_iai : CyarmActionTexture
var o_cyactiontext_icon_sword : CyarmActionTexture
var o_cyactiontext_icon_sword_slash : CyarmActionTexture
var o_cyactiontext_icon_sword_iai : CyarmActionTexture
var icon_sword_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_sword.png")
var icon_sword_slash_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_sword_slash.png")
var icon_sword_iai_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_sword_iai.png")
var sword_slash_primary_action_text : Texture2D = preload("res://sprites/UI/UI_action_primary_sword_slash.png")
var sword_iai_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_sword_iai.png")
var o_cyactionbundle_primary_sword_slash : CyarmActionBundle
var o_cyactionbundle_secondary_sword_board : CyarmActionBundle
var o_cyactionbundle_secondary_sword_iai : CyarmActionBundle

### Sword slash variables
var f_sword_is_slashing : bool = false
var f_sword_is_cleaning_slash : bool = false
var f_sword_slash_queued : bool = false
var sword_slash_can_be_hit_dict : Dictionary = {}
var sword_slash_from_pos : Vector2 # Position Sword starts the slash from
var sword_slash_end_pos : Vector2 # Position Sword teleports to do the slash
var sword_slash_dir : Vector2 # Direction of the Sword slash
var sword_slash_collider_orig_pos : Vector2 # Original position of slash collider
var sword_slash_collider_orig_size : Vector2 # Original size of slash collider
var sword_slash_range : float = 65.0 # When following Player, how far away should the slash be
var o_sword_slash_damage : DamageManager.DamageBase
var sword_slash_dmg : int = 50
var sword_slash_crit : float = 0.3
var dmg_spread : int = 10
var sword_slash_cooldown_duration : CVP_Duration = CVP_Duration.new(0.26, true, c_timer_sword_cooldown) # How often Cyarm-Sword can slash
var sword_slash_queued_buffer_duration : CVP_Duration = CVP_Duration.new(0.15, true, c_timer_sword_slash_queued_buffer) # How long to wait, with sword slash queued on next idle state

### Sword spin variables
var sword_spin_to_hits : Dictionary = {}
var sword_spin_notyet_hits : Dictionary = {}
var sword_spin_speed : CVP_Speed = CVP_Speed.new(2500.0) # Speed of Sword return
var o_sword_spin_damage : DamageManager.DamageBase
var sword_spin_dmg : int = 20
var sword_spin_crit : float = 0.1

### Swordboarding variables
var f_sword_swordboarding : bool = false
var f_sword_swordboard_cancelled : bool = false
var swordboard_cooldown_duration : CVP_Duration = CVP_Duration.new(0.41, true, c_timer_swordboard_cooldown) # How often Cyarm-Sword can swordboard

### Sword Iai variables
var f_sword_swordiaiing : bool = false
var sword_iai_stop_duration : float = 4.8
var sword_iai_cut_max_len : float = 260.0
var o_sword_iai_damage : DamageManager.DamageBase
var sword_iai_dmg : int = 60
var sword_iai_crit : float = 1.0
var swordiai_cooldown_duration : CVP_Duration = CVP_Duration.new(4.0, true, c_timer_swordiai_cooldown) # How often Cyarm-Sword can sword iai

### State & Animations
enum SwordState {
	IDLING,
	SLASHING, CLEANING_SLASH,
	SPINNING,
	SWORDBOARDING, SWORDBOARD_SLASHING,
	SWORDIAIING,
	}
var sword_curr_state : SwordState = SwordState.IDLING
var sword_state_as_str : String:
	get:
		return SwordState.keys()[sword_curr_state]
var anim_sword_idle : String = "sword_idle"
var anim_sword_slash : String = "sword_slash"
var anim_sword_spin : String = "sword_spin"

######################
## Main functions
######################
func _ready() -> void:
	super() # Call CyarmBase _ready()

	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_cyarm_swordiai_SwordIaiStop_spawn", _on_received_swordiaistop_spawn)
	_Player.connect("sig_cyarm_swordiai_finish", _on_received_swordiai_finish)
	
	## Set timers
	c_timer_sword_cooldown.wait_time = sword_slash_cooldown_duration.val
	c_timer_sword_slash_queued_buffer.wait_time = sword_slash_queued_buffer_duration.val
	c_timer_swordboard_cooldown.wait_time = swordboard_cooldown_duration.val
	c_timer_swordiai_cooldown.wait_time = swordiai_cooldown_duration.val
	damage_mtick_cooldown = c_timer_sword_cooldown.wait_time * .99 * 1000 # Have damage tick always be below sword attack speed

	## Set raycasts
	sword_slash_collider_orig_pos = c_collider_sword_slash.position
	sword_slash_collider_orig_size = c_collider_sword_slash.shape.size
	c_collider_sword_slash_potential.shape.size = c_collider_sword_slash.shape.size
	c_collider_sword_slash_potential.position.x = sword_slash_range

	## Create objects
	# Set up trail object
	o_cyarm_trail.add_trail(c_line_sword_trail, c_marker_sword_trailpos, sword_trail_len)
	#o_cyarm_trail.add_trail(c_line_sword_trail_mini1, c_marker_sword_trailpos_mini1, sword_trail_len_mini1)
	#o_cyarm_trail.add_trail(c_line_sword_trail_mini2, c_marker_sword_trailpos_mini2, sword_trail_len_mini2)
	# Set up CyarmActionTexture objects
	o_cyactiontext_primary_sword_slash = CyarmActionTexture.new(sword_slash_primary_action_text, sword_get_slash_availability)
	o_cyactiontext_secondary_sword_iai = CyarmActionTexture.new(sword_iai_secondary_action_text, sword_get_iai_availability)
	o_cyactiontext_icon_sword = CyarmActionTexture.new(icon_sword_text, func(): return 1)
	o_cyactiontext_icon_sword_slash = CyarmActionTexture.new(icon_sword_slash_text, sword_get_slash_availability)
	o_cyactiontext_icon_sword_iai = CyarmActionTexture.new(icon_sword_iai_text, sword_get_iai_availability)
	# Set up Cyarm-Sword damage objects
	o_sword_slash_damage = DamageManager.DamageBase.new(_Player, sword_slash_dmg, dmg_spread, sword_slash_crit)
	o_sword_spin_damage = DamageManager.DamageBase.new(_Player, sword_spin_dmg, dmg_spread, sword_spin_crit)
	o_sword_iai_damage = DamageManager.DamageBase.new(_Player, sword_iai_dmg, 0, sword_iai_crit)

######################
## Enable/disable functions
######################
func enable_before() -> void:
	"""
	Sets up current Cyarm mode before enabling (before anything is visible and position is set)
	"""
	# Flip off/on the slash potential Area2D, in order to call _on_slash_potential_hit_area_body_entered()
	# and notify any potential Enemies that are in slash range
	c_area_sword_slash_potential.monitoring = false
	c_area_sword_slash_potential.monitoring = true
	
	# Default rotation
	c_sprite.rotation = 0
	
	# Default flags
	f_sword_swordboard_cancelled = false
	f_follow = true
	
	# Default state
	trans_state(SwordState.IDLING)

func enable(enable_at_pos : Vector2, action_context : CyarmActionContext = null) -> void:
	"""
	Enables Cyarm at position (starts processing and shows sprite)
	
	enable_at_pos : Vector2 -- the global_position to enable Cyarm at
	action_context : CyarmActionContext = null -- the state of pressed action buttons + mouse global_position
	"""
	super(enable_at_pos)

	# If Cyarm-Sword was enabled through Cyarm radial menu, instantly perform action
	if action_context:
		if action_context.primary_action_pressed:
			update_physics_flags(get_physics_process_delta_time()) # Update Sword slash direction, after pause, before slash
			sword_slash_begin()
		elif action_context.secondary_action_pressed:
			swordiai_begin()

	# If the Sword is currently away from Player, recall the sword
	if not f_follow_player:
		sword_spin() # Pull Sword back to Player, which spins and does damage

func disable() -> void:
	"""
	Disables Cyarm (exits state, stop animations, processing, and movement)
	"""
	# If Cyarm-Sword was disabled mid-slash, potentially have next Cyarm mode do something
	if in_state(SwordState.SLASHING):
		sig_cyarm_sword_disabled.emit(Globals.mouse_pos, false)
	elif in_state(SwordState.SWORDBOARDING) or in_state(SwordState.SWORDBOARD_SLASHING):
		sig_cyarm_sword_disabled.emit(Vector2.ZERO, true)
	
	super() # Call CyarmBase's disable()
	
	# Make sure colliders are disabled
	c_collider_sword_slash.set_deferred("disabled", true)

	# Notifies any Enemy still logged in sword_slash_can_be_hit_dict, that Sword cannot hit them anymore
	for enemy_ref in sword_slash_can_be_hit_dict:
		enemy_ref.notify_can_be_hit(false)
	sword_slash_can_be_hit_dict.clear() # then clear the dictionary

######################
## SETUP functions
######################
func SETUP_cyarm_action_bundles() -> void:
	"""
	Sets up an CyarmActionBundle for each action Cyarm-Sword has:
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
	## Sword Slash
	o_cyactionbundle_primary_sword_slash = CyarmActionBundle.new(self, "sword_slash", true, null,
		## Primary action button
		func():
			if in_state(SwordState.IDLING):
				sword_slash_begin()
			elif in_state(SwordState.SWORDBOARDING):
				sword_swordboard_slash()
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

	## Sword Iai
	o_cyactionbundle_secondary_sword_iai = CyarmActionBundle.new(self, "sword_iai", true, null,
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
			if in_state(SwordState.SLASHING):
				sword_slash_end()

			swordiai_begin()
			,
		func():
			pass
			,
		func():
			if in_state(SwordState.SWORDIAIING):
				# If Player releases Sword Iai button before SwordIaiStop spawns, immediately do cut
				var _dir_to_endpoint : Vector2 = (Globals.mouse_pos - Globals.player_center_pos).normalized()
				var _len_to_endpoint : float = Globals.player_center_pos.distance_to(Globals.mouse_pos)
				var _cut_distance = min(sword_iai_cut_max_len, _len_to_endpoint) # Cut has a maximum distance
				var _cut_end_point = global_position + _dir_to_endpoint * _cut_distance
				sig_player_swordiai_cut.emit(_cut_end_point, _cut_distance)
				_on_received_swordiai_cut(Globals.player_center_pos, _cut_end_point)

			swordiai_end()
			,
			)

	## Swordboard
	#o_cyactionbundle_secondary_sword_board = CyarmActionBundle.new(self, "sword_board", true, null,
		### Primary action button
		#func():
			#pass
			#,
		#func():
			#pass
			#,
		#func():
			#pass
			#,
		#
		### Secondary action button
		#func():
			#if in_state(SwordState.IDLING):
				#swordboard_begin()
				#f_sword_swordboard_cancelled = false # On action pressed, reset cancelled flag
			#,
		#func():
			#if in_state(SwordState.SWORDBOARDING):
				#swordboard_during()
			#elif (
						#in_state(SwordState.IDLING)
					#and
						#not f_sword_swordboard_cancelled # If Player cancelled swordboard, then disallow swordboard until action pressed again
				#):
				#swordboard_begin()
			#,
		#func():
			#if in_state(SwordState.SWORDBOARDING):
				#swordboard_end()
			#elif in_state(SwordState.SWORDBOARD_SLASHING): # Cancel swordboarding after slash
				#swordboard_end()
			#,
			#)

func SETUP_cyarm_state_bundles() -> void:
	"""
	Sets up o_cyarm_action_state_bundle_dict (a Dictionary of {SwordState -> CyarmStateBundle}):
		For each SwordState, sets up the prerequisite functions, such as what to do when
		exiting a particular state, or how to animate a particular state
	
	CyarmStateBundle object constructor arguments:
	CyarmStateBundle.new(
					_cyarm_ref : Node,
					_func_animate : Callable,            # Function to be called when animating SwordState
					_func_during_physics : Callable,     # Function to be called during physics_process while in SwordState
					_func_get_action_texture : Callable, # Function to be called during physics_process to get action texture
					_func_exit_state : Callable          # Function to be called after exiting SwordState
				)

	"""
	var _temp_casb : CyarmStateBundle

	for ss in SwordState.values(): # Iterate over enum values (the integers)
		match ss:
			SwordState.IDLING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = true
						c_animplayer.play(anim_sword_idle)
						,
					func(delta : float):
						bob(delta) # Move sprite up and down
						sword_point_potential_slash() # When slash is possible, point potential slash area colliders at mouse
						f_about_to_hit = c_area_sword_slash_potential.has_overlapping_bodies() # Set flag if slash can hit Enemy based on current mouse pos
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						pass
						,
					)
			SwordState.SLASHING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = true
						c_animplayer.play(anim_sword_slash) # sword_slash_end() is called by animation
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						sword_slash_end()
						set_follow_pos(sword_slash_end_pos) # Have next Cyarm mode start in the direction & pos of the slash
						,
						)
			SwordState.CLEANING_SLASH:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						sword_clean_slash_end()
						,
					)
			SwordState.SPINNING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = true
						c_animplayer.play(anim_sword_spin)
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						sword_clean_spin()
						,
					)
			SwordState.SWORDBOARDING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						swordboard_end()
						,
					)
			SwordState.SWORDBOARD_SLASHING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						pass
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						sword_swordboard_slash_end()
						,
					)
			SwordState.SWORDIAIING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = false
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return sword_get_action_texture(get_primary)
						,
					func():
						swordiai_end()
						,
					)

		# Add particular CyarmStateBundle to dictionary, mapped to key of SwordState
		o_cyarm_state_bundle_dict[ss] = _temp_casb

######################
## Action functions
######################
func get_primary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Sword's primary action
	"""
	return o_cyactionbundle_primary_sword_slash

func get_secondary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Sword's secondary action
	"""
	return o_cyactionbundle_secondary_sword_iai

######################
## Move-on-rails functions
######################
func move_onrails_during() -> void:
	"""
	Actions to perform during a move-on-rails 
	"""
	var o_r : MoveOnRails = o_move_onrails
	match o_r.move_onrails_type:
		o_r.RAIL_TYPE.TO_TARGET:
			sword_spin_hitscan_hit()

func move_onrails_after() -> void:
	"""
	Actions to perform after a move-on-rails is complete
	"""
	var o_r : MoveOnRails = o_move_onrails
	match o_r.move_onrails_type:
		o_r.RAIL_TYPE.TO_TARGET:
			exit_state() # sword_clean_spin() # Sword has returned to Player

######################
## State & Animation functions
######################
func in_state(query_state : SwordState) -> bool:
	"""
	query_state : SwordState -- state to query
	
	Returns : bool -- whether current Sword state matches query state
	"""
	return sword_curr_state == query_state

func exit_state() -> void:
	"""
	Performs cleanup of current Cyarm state
	"""
	(o_cyarm_state_bundle_dict[sword_curr_state] as CyarmStateBundle).func_exit_state.call()

func trans_state(new_sword_state : SwordState, cleanup : bool = true) -> void:
	"""
	Transitions to new Cyarm state
	
	new_sword_state : SwordState -- new Cyarm-Sword state to transition to
	cleanup : bool = false -- whether or not to call exit_state() before transitioning to new state
	"""
	# Transitions BEFORE:
	if cleanup and new_sword_state != sword_curr_state:
		if (
				in_state(SwordState.SWORDBOARDING)
			and
				new_sword_state == SwordState.SWORDBOARD_SLASHING
			):
			# If currently swordboarding, do not call swordboard_end() with exit_state(), since
			# swordboard_slash() still requires swordboarding
			pass

		else:
			# Only exit state if transitioning to a new state
			exit_state()
	
	# Transition
	sword_curr_state = new_sword_state
	
	# Transitions AFTER:
	if (
			in_state(SwordState.IDLING)
		and
			f_sword_slash_queued
		):
		sword_slash_begin()

func update_animations() -> void:
	"""
	Updates Cyarm sprite to animation matching current state
	"""
	# Updates sprite
	(o_cyarm_state_bundle_dict[sword_curr_state] as CyarmStateBundle).func_animate.call()
	
	# Updates trails
	if (
			in_state(SwordState.SWORDBOARDING) or
			in_state(SwordState.SWORDBOARD_SLASHING)
		):
		update_trails(false) # Clear Cyarm-Sword trail
	else:
		if in_state(SwordState.IDLING):
			update_trails() # Draw trail
		else:
			update_trails(false) # Clear trail

##################
## Shared Cyarm Functions
##################
func get_curr_state() -> String:
	"""
	Returns : String -- the state of the current Cyarm
	"""
	return sword_state_as_str

func get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	return (o_cyarm_state_bundle_dict[sword_curr_state] as CyarmStateBundle).func_get_action_texture.call(get_primary)

func get_radial_icon_action_texture(_action_context : CyarmActionContext) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture for CyarmRadialMenu, of the next action based on pressed action buttons
	
	_action_context : CyarmActionContext -- whether or not action buttons are pressed + mouse global position
	"""
	if _action_context == null: # If context doesn't matter, return base icon
		return o_cyactiontext_icon_sword
	
	if _action_context.primary_action_pressed:
		return o_cyactiontext_icon_sword_slash
	elif _action_context.secondary_action_pressed:
		return o_cyactiontext_icon_sword_iai
		
	return o_cyactiontext_icon_sword

func get_crosshair_proposed_pos() -> Vector2:
	"""
	Returns : Vector2 -- the position of the crosshair to best represent the current Cyarm mode
	"""
	return sword_slash_end_pos

func update_physics_flags(_delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	### Update Cyarm-Sword flags for this frame
	# When following Player, sword hovers near the shoulder, so instead of using that offset, use
	# center of Player, so that slash covers same distance to the left or right of Player
	sword_slash_from_pos = Globals.player_center_pos if f_follow_player else get_follow_pos()
	sword_slash_dir = (Globals.mouse_pos - sword_slash_from_pos).normalized()
	sword_slash_end_pos = sword_get_sword_slash_end_pos(sword_slash_dir)

func do_physics_state_func(delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	# Calls function specific to current SwordState every physics frame 
	(o_cyarm_state_bundle_dict[sword_curr_state] as CyarmStateBundle).func_during_physics.call(delta)

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Cyarm currently does
	"""
	# Choose damage depending on sword slashing, or spinning
	if in_state(SwordState.SPINNING):
		return o_sword_spin_damage
	else:
		return o_sword_slash_damage

##################
## Cyarm-Sword Specific Functions
##################
func sword_get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm-Sword action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	if get_primary:
		# Return whether sword slash can be used, based on attack speed cooldown
		return o_cyactiontext_primary_sword_slash
	else:
		return o_cyactiontext_secondary_sword_iai

func sword_get_slash_availability() -> float:
	"""
	Returns : float -- how "available" Sword slash is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1 - (c_timer_sword_cooldown.time_left / c_timer_sword_cooldown.wait_time)

func sword_get_iai_availability() -> float:
	"""
	Returns : float -- how "available" Sword iai is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1 - (c_timer_swordiai_cooldown.time_left / c_timer_swordiai_cooldown.wait_time)

func sword_unlock() -> void:
	"""
	Unlocks Cyarm-Sword so that it can change Cyarm modes
	Called in "sword_slash" animation, after the slash collider is enabled (basically
	keeps Sword locked until it actually deals damage), and in the slash collider hit function
	"""
	f_locked = false

func sword_point_potential_slash() -> void:
	"""
	Points the colliders of a potential slash at mouse position
	"""
	if f_follow_player:
		# Check slash from Player center
		c_marker_sword_slash_potential.global_position = Globals.player_center_pos
	else:
		# Check slash from Cyarm-Sword center
		c_marker_sword_slash_potential.global_position = global_position
	
	c_marker_sword_slash_potential.look_at(Globals.mouse_pos)

func sword_get_sword_slash_end_pos(slash_dir : Vector2) -> Vector2:
	"""
	Returns the position Sword could potentially slash to
	
	slash_dir : Vector2 -- direction of the Sword slash, from slash start
	"""
	return sword_slash_from_pos + (slash_dir * sword_slash_range)

func sword_slash_begin() -> void:
	"""
	Cyarm-Sword swing
	"""
	## Do Slash
	if c_timer_sword_cooldown.is_stopped():
		# Before slash, teleport Cyarm-Sword to the center of the follow position
		if f_follow:
			global_position = sword_slash_end_pos 

		# Rotate slash sprite to face the mouse
		point_sprite_at(global_position + (sword_slash_dir * sword_slash_range), true)
		if sword_slash_dir.x > 0:
			c_sprite.flip_v = true
		
		velocity = Vector2.ZERO # Stop movement during slash
		c_timer_sword_cooldown.start() # Attack speed cooldown duration

		f_sword_slash_queued = false # Since slash occured, remove the flag that queues slash immediately
		f_follow = false # Don't allow Sword to move while slashing
		f_locked = true # Lock Cyarm from switching mode until Sword slash has done damage
		trans_state(SwordState.SLASHING)
		sig_player_swordslash.emit(true)
	
	## Do NOT slash
	else:
		# Queue sword slash to happen when entering an idle state
		c_timer_sword_slash_queued_buffer.start()
		f_sword_slash_queued = true

func sword_slash_end() -> void:
	"""
	Clean up Cyarm-Sword swing
	"""
	# Change slash sprite back to normal Cyarm-Sword sprite
	c_animplayer.play("sword_idle")
	c_animplayer.stop()

	# At end of slash, teleport Cyarm to match end of slashing sprite
	global_position = c_marker_sword_slashend.global_position
	c_sprite.rotation += deg_to_rad(-100) # Adjust rotation to better match end of slash sprite

	# Then flourish the sword a bit, spin from its slash end sprite back to normal idle follow position
	var _flourish_tween = create_tween()
	var _rot2rest = sign(c_sprite.rotation) * TAU - c_sprite.rotation
	# Depending on sprite orientation from the slash, the resting rotation differs
	if c_sprite.flip_v:
		_rot2rest = -TAU # -360
	else:
		if c_sprite.rotation < 0: # Rotate to 0 instead of 360, otherwise sword rotates opposite from slash sprite
			_rot2rest = 0
		else:
			_rot2rest = TAU # 360
	
	c_sprite.flip_v = false # Reset sprite orientation to default
	_flourish_tween.tween_property(c_sprite, "rotation", _rot2rest, 0.15)
	_flourish_tween.tween_callback(sword_clean_slash_end) # Only set flag for slashing to false AFTER tween is done playing

	f_follow = true # Move back to follow position while flourishing
	trans_state(SwordState.CLEANING_SLASH, false)

func sword_clean_slash_end() -> void:
	"""
	Attributes to set once slash-flourish tween is over
	"""
	if in_state(SwordState.CLEANING_SLASH):
		trans_state(SwordState.IDLING, false)

func sword_spin() -> void:
	"""
	Cyarm-Sword spin return
	"""
	var _pos2spin2_dir : Vector2 = (get_follow_pos(true) - global_position).normalized()
	var _pos2spin2 : Vector2 = get_follow_pos() + _pos2spin2_dir * 30 # Move a little bit past Player
	o_move_onrails.begin_to_target(_pos2spin2, sword_spin_speed.val)

	# Discover the enemies that Sword-spin would hit
	sword_spin_hitscan_discover(_pos2spin2)

	trans_state(SwordState.SPINNING)

func sword_spin_hitscan_discover(end_pos : Vector2) -> void:
	"""
	Discover the enemies in Sword spin path to be "hit", in case Sword moves too fast
	to reliably trigger _on_body_entered() signal. Also catches enemies that at the beginning frame
	of Sword spin, that aren't hit with _on_body_entered() signal because spin moves Sword out of
	the way too soon.
	
	end_pos : Vector2 -- position sword will spin to
	"""
	var _path_of_spin = end_pos - global_position

	# Position Shapecast beginning at current Sword position, stretching to end Player position
	c_shapecast_sword_spin.global_position = global_position
	c_shapecast_sword_spin.target_position = _path_of_spin
	c_shapecast_sword_spin.enabled = true # Enable shape cast for this frame
	c_shapecast_sword_spin.clear_exceptions()
	c_shapecast_sword_spin.force_shapecast_update()

	# Collect every enemy that would be hit by Sword spin
	while c_shapecast_sword_spin.is_colliding():
		var _enemy : Object = c_shapecast_sword_spin.get_collider(0)
		var _enemy_normal = (end_pos - _enemy.global_position).normalized() # Unit vector that points from ENEMY position AWAY (in direction of Player end position)
		sword_spin_to_hits[_enemy] = _enemy_normal # Store "hit" enemy in dictionary (enemy ref as key, normal as value)
		c_shapecast_sword_spin.add_exception(_enemy) # Ignore "hit" enemy
		c_shapecast_sword_spin.force_shapecast_update() # Force shape cast to update and scan again

	c_shapecast_sword_spin.enabled = false # Hitscan done, disable shape cast

func sword_spin_hitscan_hit() -> void:
	"""
	Using enemies scanned during sword_spin_hitscan_hit(), decide whether enemies are hit
	
	Called in during_move_onrails()
	"""
	var _hit_enemies : Array = [] 
	for enemy in sword_spin_to_hits:
		var _enemy_normal = sword_spin_to_hits[enemy]
		var _enemy_to_sword_dir : Vector2 = (global_position - enemy.global_position).normalized() # Unit vector that points from ENEMY position to current SWORD position
		var passed_dot : float = _enemy_normal.dot(_enemy_to_sword_dir)
		if passed_dot > 0: # Sword passed enemy position
			do_damage_to(enemy)
			_hit_enemies.append(enemy)

	# Clear enemies that have been already hit, so they aren't hit again
	for enemy in _hit_enemies:
		sword_spin_to_hits.erase(enemy)

func sword_clean_spin() -> void:
	"""
	Clean up Cyarm-Sword spin
	"""
	c_sprite.rotation = -TAU

	# Flourish the sword a bit, one full rotation back to normal idle follow position
	var _flourish_tween = create_tween()
	_flourish_tween.tween_property(c_sprite, "rotation", 0, 0.15).set_ease(Tween.EASE_OUT)
	_flourish_tween.tween_callback(sword_clean_spin_end) # Only set flag for sword-spin to false AFTER tween is done playing
	
	set_follow_player() # Return follow position back to Player
	
	sword_spin_to_hits.clear() # Clear dictionary of potential spin hits

func sword_clean_spin_end() -> void:
	"""
	Attributes to set once sping-flourish tween is over
	"""
	if in_state(SwordState.SPINNING):
		trans_state(SwordState.IDLING, false)

func swordboard_begin() -> void:
	"""
	Begin swordboarding
	"""
	if c_timer_swordboard_cooldown.is_stopped():
		sig_player_swordboard.emit(true) # Tell Player
		c_timer_swordboard_cooldown.start() # Start timer
		f_sword_swordboarding = true # Flag
		trans_state(SwordState.SWORDBOARDING)

func swordboard_during() -> void:
	"""
	During swordboarding
	"""
	c_sprite.rotation = 0

func swordboard_end() -> void:
	"""
	End swordboarding
	"""
	sig_player_swordboard.emit(false)
	f_sword_swordboarding = false
	trans_state(SwordState.IDLING, false)

func sword_swordboard_slash() -> void:
	"""
	Cyarm-Sword swing, while swordboarding
	"""
	if c_timer_sword_cooldown.is_stopped():
		# Notify Player to play the slash animation (instead of Cyarm-Sword itself), since
		# the animation must follow the Player sprite anyway
		sig_player_swordboard_slash.emit()

		c_timer_sword_cooldown.start() # Attack speed cooldown duration

		f_follow = true # Allow Sword to follow Player while slashing
		f_locked = true # Lock Cyarm from switching mode until Sword slash has done damage
		trans_state(SwordState.SWORDBOARD_SLASHING)

func sword_swordboard_slash_end() -> void:
	"""
	End Cyarm-Sword swing, while swordboarding
	"""
	if f_sword_swordboarding:
		trans_state(SwordState.SWORDBOARDING, false)
	else:
		trans_state(SwordState.IDLING, false)

	f_locked = false # Unlock Cyarm

func swordiai_begin() -> void:
	"""
	Begin swordboarding
	"""
	if c_timer_swordiai_cooldown.is_stopped():
		sig_player_swordiai.emit(true) # Signal Player
		c_timer_swordiai_cooldown.start() # Start timer
		f_sword_swordiaiing = true # Flag
		trans_state(SwordState.SWORDIAIING)

func swordiai_end() -> void:
	"""
	End swordboarding
	"""
	f_sword_swordiaiing = false
	trans_state(SwordState.IDLING, false)

##################
## Received Signals
##################
func _on_slash_queued_buffer_timeout() -> void:
	"""
	Cyarm-Sword slash can be queued, to immediately come out on entering idle state. This timer
	represents how long slash can be queued for, and timing out removes the queued slash.
	"""
	f_sword_slash_queued = false # Sword slash no longer queued

func _on_slash_hit_area_body_entered(body: Node2D) -> void:
	"""
	Cyarm-Sword slash hit
	"""
	do_damage_to(body)
	sword_unlock() # Allow Cyarm-Sword to change to different Cyarm mode

	# Disable slash collider after dealing damage
	c_collider_sword_slash.set_deferred("disabled", true)

func _on_slash_potential_hit_area_body_entered(body: Node2D) -> void:
	"""
	Notify Enemy that it can be hit at this mouse position (shows its HP bar)
	"""
	if body.has_method("notify_can_be_hit"):
		sword_slash_can_be_hit_dict[body] = true # Add ref of body to dictionary of what can be hit
		body.notify_can_be_hit(true)

func _on_slash_potential_hit_area_body_exited(body: Node2D) -> void:
	"""
	Notify Enemy that it CANNOT be hit at this mouse position (unshows can_be_hit status)
	"""
	if body.has_method("notify_can_be_hit"):
		sword_slash_can_be_hit_dict.erase(body) # Remove ref of body to dictionary of what can be hit
		body.notify_can_be_hit(false)

func _on_received_swordiai_cancel() -> void:
	"""
	Cancel swordiaiing
	"""
	swordiai_end()
	
	# Since cut wasn't used, reset its cooldown
	c_timer_swordiai_cooldown.stop()

func _on_received_swordiai_finish() -> void:
	"""
	Finish swordiaiing
	"""
	swordiai_end()

func _on_received_swordiaistop_spawn(spawn_pos : Vector2) -> void:
	"""
	Spawn a SwordIaiStop
	
	spawn_pos : Vector2 -- position to spawn SwordIaiStop
	"""
	if in_state(SwordState.SWORDIAIING):
		sig_world_spawn_swordiaistop.emit(spawn_pos, sword_iai_stop_duration, sword_iai_cut_max_len)

func _on_received_swordiai_cut(begin_pos : Vector2, end_pos : Vector2) -> void:
	"""
	Spawn a SwordIaiCut
	
	begin_pos : Vector2 -- position SwordIaiCut begins
	end_pos : Vector2 -- position SwordIaiCut ends
	"""
	sig_world_spawn_swordiaicut.emit(begin_pos, end_pos, o_sword_iai_damage) # Signal World to spawn SwordIaiCut
	sig_player_swordiai_cut.emit(end_pos, begin_pos.distance_to(end_pos)) # Signal Player to dash towards end of cut

func _on_received_swordiai_cut_killed() -> void:
	"""
	When Sword Iai cut kills something, refresh its cooldown
	"""
	c_timer_swordiai_cooldown.stop() # Refresh Sword Iai

func _on_received_swordboard_cancel() -> void:
	"""
	Cancel swordboarding when the Player requests it
	"""
	swordboard_end()
	f_sword_swordboard_cancelled = true

func _on_received_swordboard_slash_hit(slash_col : CollisionShape2D) -> void:
	"""
	Calculate whether or not swordboard slash hit anything, then do normal slash damage
	"""
	c_collider_sword_slash.global_position = slash_col.global_position
	c_collider_sword_slash.shape.size = slash_col.shape.size
	c_collider_sword_slash.disabled = false

func _on_received_swordboard_slash_hit_end() -> void:
	"""
	Disable slash collider, and set its position and size back to normal
	"""
	c_collider_sword_slash.position = sword_slash_collider_orig_pos
	c_collider_sword_slash.shape.size = sword_slash_collider_orig_size
	c_collider_sword_slash.set_deferred("disabled", true)

	sword_swordboard_slash_end()
