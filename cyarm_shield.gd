extends CyarmBase
class_name CyarmShield

### External Scenes
var s_shield_pulse_potential_line : PackedScene = preload("res://scenes/shield_pulse_potential_line.tscn")

### Component references
@onready var c_folder_pulse_victims : Node = $PulseVictims
@onready var c_body : CharacterBody2D = $"."
@onready var c_sprite_pulse_range_indicator : Sprite2D = $PulseRangeIndicator
@onready var c_area_shield_pulse_hitbox : Area2D = $PulseHitbox
@onready var c_collider_shield_hitbox : CollisionShape2D = $ShieldCollider
@onready var c_collider_shield_guard : CollisionShape2D = $GuardHitbox/GuardCollider
@onready var c_collider_shield_pulse : CollisionShape2D = $PulseHitbox/PulseCollider
@onready var c_raycast_top_clearance : RayCast2D = $TopClearanceCast
@onready var c_line_shield_trail : Line2D = $Trails/ShieldTrail
@onready var c_line_shield_guard_trajectory : Line2D = $Trails/ShieldGuardTrajectory
@onready var c_timer_shield_clean : Timer = $Timers/ShieldCleanTimer
@onready var c_timer_shield_invincibility : Timer = $Timers/ShieldInvincibilityDuration
@onready var c_timer_shield_guard : Timer = $Timers/ShieldGuardCooldown
@onready var c_timer_shield_pulse : Timer = $Timers/ShieldPulseCooldown
@onready var c_timer_shield_glide_onclick_buffer : Timer = $Timers/ShieldGlideOnClickBuffer

### State
enum ShieldState {IDLING, PULSING, GUARDING, SLIDING, GLIDING}
var shield_curr_state : ShieldState = ShieldState.IDLING
var shield_state_as_str : String:
	get:
		return ShieldState.keys()[shield_curr_state]

### Enable/Disable
var f_after_enable_pos_under_player : bool = false # Enable Cyarm-Shield underneath Player

### Cyarm-Shield trail variables
var shield_trail_len : int = 24

### Shield action variables
var o_cyactiontext_primary_shield_guard : CyarmActionTexture
var o_cyactiontext_secondary_shield_slide : CyarmActionTexture
var o_cyactiontext_secondary_shield_slide_held : CyarmActionTexture
var o_cyactiontext_secondary_shield_glide : CyarmActionTexture
var o_cyactiontext_secondary_shield_glide_held : CyarmActionTexture
var o_cyactiontext_icon_shield : CyarmActionTexture
var o_cyactiontext_icon_shield_guard : CyarmActionTexture
var o_cyactiontext_icon_shield_slide : CyarmActionTexture
var o_cyactiontext_icon_shield_glide : CyarmActionTexture
var icon_shield_text : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_shield.png")
var icon_shield_guard : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_shield_guard.png")
var icon_shield_slide : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_shield_slide.png")
var icon_shield_glide : Texture2D = preload("res://sprites/UI/cyarm_radial_icon_shield_glide.png")
var shield_guard_primary_action_text : Texture2D = preload("res://sprites/UI/UI_action_primary_shield_guard.png")
var shield_slide_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_shield_slide.png")
var shield_slide_held_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_shield_slide_held.png")
var shield_glide_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_shield_glide.png")
var shield_glide_held_secondary_action_text : Texture2D = preload("res://sprites/UI/UI_action_secondary_shield_glide_held.png")
var o_cyactionbundle_primary_shield_guard : CyarmActionBundle
var o_cyactionbundle_secondary_shield_slide : CyarmActionBundle
var o_cyactionbundle_secondary_shield_pulse : CyarmActionBundle

### Cyarm-Shield pulse variables
var shield_pulse_line_texture : Texture2D = preload("res://sprites/cyarm/cyarm_spear_trajectory.png")
var shield_pulse_radius : float = 50.0
var shield_pulse_speed : CVP_Speed = CVP_Speed.new(1000.0)
var shield_pulse_victims : Dictionary = {} # Dictionary of {key: Node, value: Line2D}
var shield_pulse_launch_dir_length : float = 20.0
var shield_pulse_cooldown_duration : CVP_Duration = CVP_Duration.new(0.8, true, c_timer_shield_pulse) # How often Cyarm-Shield can pulse

### Cyarm-Shield guard variables
var f_shield_guard_reached : bool = false
var shield_guard_reach_duration : CVP_Duration = CVP_Duration.new(0.05) # Time it takes for Shield to reach guard position
var shield_guard_anim_duration : CVP_Duration # Time it takes for Shield guard to finish animation
var shield_guard_invincible_duration : CVP_Duration # Duration Shield guard makes Player invincible
var shield_guard_cooldown_duration : CVP_Duration = CVP_Duration.new(0.8, true, c_timer_shield_guard) # How often Cyarm-Shield can guard
var shield_guard_anim_name : String = "shield_guard"

### Cyarm-Shield slide variables
var f_request_shield_slide = false
var f_shield_sliding : bool = false

### Cyarm-Shield glide variables
var f_request_shield_glide : bool = false
var f_shield_gliding : bool = false
var shield_glide_onclick_buffer_duration : CVP_Duration = CVP_Duration.new(0.2, true, c_timer_shield_glide_onclick_buffer) # Buffer before a second click activates shield glide

######################
## Main functions
######################
func _ready() -> void:
	super() # Call CyarmBase _ready()

	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_cyarm_shieldslide_cancel", _on_received_shieldslide_cancel)
	_Player.connect("sig_cyarm_shieldslide_request_begin", _on_received_shieldslide_request_begin)
	_Player.connect("sig_cyarm_shieldglide_request_begin", _on_received_shieldglide_request_begin)
	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_cyarm_sword_disabled", _on_received_cyarm_sword_disabled)
		cyarm.connect("sig_cyarm_spear_disabled", _on_received_cyarm_spear_disabled)
	var _CyarmManager : Node = get_tree().get_first_node_in_group("CyarmManager")
	_CyarmManager.connect("sig_cyMgr_cyarm_enabled", _on_received_cyMgr_cyarm_enabled)

	### Set timers
	# Set clean Shield guard timer to length of Shield guard animation, instead of using an
	# on_animation_finished signal, since Shield pulse can be used during Shield guard,
	# which interrupts Shield guard animation
	var _shield_guard_anim : Animation = c_animplayer.get_animation(shield_guard_anim_name)
	var _shield_guard_anim_length : float = _shield_guard_anim.length
	shield_guard_anim_duration = CVP_Duration.new(_shield_guard_anim_length, true, c_timer_shield_clean)
	c_timer_shield_clean.wait_time = shield_guard_anim_duration.val
	c_timer_shield_guard.wait_time = shield_guard_cooldown_duration.val
	c_timer_shield_pulse.wait_time = shield_pulse_cooldown_duration.val
	c_timer_shield_glide_onclick_buffer.wait_time = shield_glide_onclick_buffer_duration.val
	
	# Also, set Shield guard invincibility duration, for same reason as above
	# Find time where invincibility method is called, then the difference from when the cancel-invincibility method is called
	var _track_key_guard_begin : Array[int] = Utilities.get_track_and_key_ids_for_method_track(_shield_guard_anim, "shield_guard_invincible_begin")
	var _track_key_guard_end : Array[int] = Utilities.get_track_and_key_ids_for_method_track(_shield_guard_anim, "shield_guard_invincible_end")
	var _invinciblility_duration : float = (
										_shield_guard_anim.track_get_key_time(_track_key_guard_end[0], _track_key_guard_end[1])
										-
										_shield_guard_anim.track_get_key_time(_track_key_guard_begin[0], _track_key_guard_begin[1]))
	shield_guard_invincible_duration = CVP_Duration.new(_invinciblility_duration, true, c_timer_shield_invincibility)
	c_timer_shield_invincibility.wait_time = shield_guard_invincible_duration.val
	
	# Set raycasts
	c_raycast_top_clearance.global_position = c_collider_shield_hitbox.global_position - Vector2(0, c_collider_shield_hitbox.shape.size.y / 2) # Raycast extends from top-middle of Shield
	c_collider_shield_pulse.shape.radius = shield_pulse_radius
	c_sprite_pulse_range_indicator.scale = Vector2(shield_pulse_radius / 90, shield_pulse_radius / 90)

	## Create objects
	o_cyarm_trail.add_trail(c_line_shield_trail, false, shield_trail_len) # Set up trail object
	# Set up CyarmActionTexture objects
	o_cyactiontext_primary_shield_guard = CyarmActionTexture.new(shield_guard_primary_action_text, shield_get_guard_availability)
	o_cyactiontext_secondary_shield_slide = CyarmActionTexture.new(shield_slide_secondary_action_text, shield_get_slide_availability)
	o_cyactiontext_secondary_shield_slide_held = CyarmActionTexture.new(shield_slide_held_secondary_action_text, shield_get_slide_availability)
	o_cyactiontext_secondary_shield_glide = CyarmActionTexture.new(shield_glide_secondary_action_text, shield_get_glide_availability)
	o_cyactiontext_secondary_shield_glide_held = CyarmActionTexture.new(shield_glide_held_secondary_action_text, shield_get_glide_availability)
	o_cyactiontext_icon_shield = CyarmActionTexture.new(icon_shield_text, func(): return 1)
	o_cyactiontext_icon_shield_guard = CyarmActionTexture.new(icon_shield_guard, shield_get_guard_availability)
	o_cyactiontext_icon_shield_slide = CyarmActionTexture.new(icon_shield_slide, shield_get_slide_availability)
	o_cyactiontext_icon_shield_glide = CyarmActionTexture.new(icon_shield_glide, shield_get_slide_availability)

func _draw() -> void:
	pass

######################
## SETUP functions
######################
func SETUP_cyarm_action_bundles() -> void:
	"""
	Sets up an CyarmActionBundle for each action Cyarm-Shield has:
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
	## Shield Guard
	o_cyactionbundle_primary_shield_guard = CyarmActionBundle.new(self, "shield_guard", true, null,
		## Primary action button
		func():
			shield_guard_begin() # Move Shield to a radius around the Player
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

	## Shield Slide
	o_cyactionbundle_secondary_shield_slide = CyarmActionBundle.new(self, "shield_slide", true, null,
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
			if not in_state(ShieldState.SLIDING):
				if c_timer_shield_glide_onclick_buffer.is_stopped():
					# On first click, start a timer that, if still active on second click, activates Shield glide
					c_timer_shield_glide_onclick_buffer.start()
					
					shield_slide_begin() # Slide
				else:
					# Timer still active, so glide
					shield_glide_begin(true) # Glide
			,
		func():
			if f_request_shield_slide: # Did the Player request a Shield slide (after landing from glide)
				shield_slide_begin(false) # False, not initiated from action button press, but hold
			if in_state(ShieldState.SLIDING):
				shield_slide_during()

			if f_request_shield_glide: # Did the Player request a Shield glide (after launching from slide)
				shield_glide_begin(false)
			if in_state(ShieldState.GLIDING):
				shield_glide_during()
			,
		func():
			if in_state(ShieldState.SLIDING):
				shield_slide_end()
			if in_state(ShieldState.GLIDING):
				shield_glide_end()
			,
			)

	## Shield Pulse
	o_cyactionbundle_secondary_shield_pulse = CyarmActionBundle.new(self, "shield_pulse", true, null,
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
			if (
						not in_state(ShieldState.PULSING)
					and
						Globals.EM_f_can_electro_cast # Enough electro to cast?
				):
				shield_pulse_slow()
			,
		func():
			if (
						in_state(ShieldState.PULSING)
					and
						Globals.EM_f_can_electro_cast # Enough electro to cast?
				):
				shield_pulse_slow()
			,
		func():
			if (
						in_state(ShieldState.PULSING)
					and
						Globals.EM_f_can_electro_cast # Enough electro to cast?
				):
				shield_pulse_do()
			,
			)

func SETUP_cyarm_state_bundles() -> void:
	"""
	Sets up o_cyarm_action_state_bundle_dict (a Dictionary of {ShieldState -> CyarmStateBundle}):
		For each ShieldState, sets up the prerequisite functions, such as what to do when
		exiting a particular state, or how to animate a particular state
	
	CyarmStateBundle object constructor arguments:
	CyarmStateBundle.new(
					_cyarm_ref : Node,
					_func_animate : Callable,            # Function to be called when animating ShieldState
					_func_during_physics : Callable,     # Function to be called during physics_process while in ShieldState
					_func_get_action_texture : Callable, # Function to be called during physics_process to get action texture
					_func_exit_state : Callable          # Function to be called after exiting ShieldState
				)
	"""
	var _temp_casb : CyarmStateBundle

	for ss in ShieldState.values(): # Iterate over enum values (the integers)
		match ss:
			ShieldState.IDLING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = true
						c_animplayer.play("shield_idle")
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return shield_get_action_texture(get_primary)
						,
					func():
						pass
						,
					)
			ShieldState.PULSING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_animplayer.play("shield_idle")
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return shield_get_action_texture(get_primary)
						,
					func():
						Globals.set_time_scale_normal()
						,
					)
			ShieldState.GUARDING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = true
						if f_shield_guard_reached:
							# Once Shield has reached guard position, play the animation of the
							# guard effect.
							c_animplayer.play(shield_guard_anim_name)
						else:
							c_animplayer.play("shield_idle")
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return shield_get_action_texture(get_primary)
						,
					func():
						shield_guard_invincible_end()
						,
					)
			ShieldState.SLIDING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = false
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return shield_get_action_texture(get_primary)
						,
					func():
						c_sprite.visible = true
						shield_slide_end()
						,
					)
			ShieldState.GLIDING:
				_temp_casb = CyarmStateBundle.new(self,
					func():
						c_sprite.visible = false
						,
					func(_delta : float):
						pass
						,
					func(get_primary : bool):
						return shield_get_action_texture(get_primary)
						,
					func():
						c_sprite.visible = true
						shield_glide_end()
						,
					)

		# Add particular CyarmStateBundle to dictionary, mapped to key of ShieldState
		o_cyarm_state_bundle_dict[ss] = _temp_casb

######################
## Enable/disable functions
######################
func enable_before() -> void:
	"""
	Sets up current Cyarm mode before enabling (before anything is visible and position is set)
	"""
	c_sprite.rotation = 0 # Shield doesn't rotate

	# Enable Shield hitbox
	c_collider_shield_hitbox.set_deferred("disabled", false)

	# Flip off/on the Shield pulse potential Area2D, in order to call _on_pulse_hitbox_body_entered()
	# and notify any potential Nodes that are in Shield pulse range
	c_area_shield_pulse_hitbox.monitoring = false
	c_area_shield_pulse_hitbox.monitoring = true

	# Default flags
	
	# Default state
	trans_state(ShieldState.IDLING)

func enable(enable_at_pos : Vector2, action_context : CyarmActionContext = null) -> void:
	"""
	Enables Cyarm at position (starts processing and shows sprite)
	
	enable_at_pos : Vector2 -- the global_position to enable Cyarm at
	action_context : CyarmActionContext = null -- the state of pressed action buttons + mouse global_position
	"""
	super(enable_at_pos) # Call CyarmBase's enable()

	# If Cyarm-Shield was enabled through Cyarm radial menu, instantly perform action
	if action_context:
		if action_context.primary_action_pressed:
			shield_guard_begin()
		elif action_context.secondary_action_pressed:
			if Globals.player_f_is_grounded:
				shield_slide_begin()
			else:
				shield_glide_begin()

	# If Cyarm was disabled during swordboarding or spearbrooming, then enable
	# Shield right underneath Player, and stop Player momentum
	if f_after_enable_pos_under_player:
		global_position = Globals.player_pos + Vector2(0, c_collider_shield_hitbox.shape.size.y / 2)
		sig_player_stop_momentum.emit(Globals.player_pos)
	
	set_follow_pos(global_position, true)

func disable() -> void:
	"""
	Disables Cyarm (exits state, stop animations, processing, and movement)
	"""
	# If Player is within Shield guard range, make next Cyarm automatically follow Player
	if global_position.distance_to(Globals.player_center_pos) <= (c_collider_shield_guard.shape as CircleShape2D).radius:
		sig_cyarm_shield_disabled.emit(true)
	
	super() # Call CyarmBase's disable()
	
	# Make sure colliders are disabled
	c_collider_shield_hitbox.set_deferred("disabled", true)

	# Clean the Shield pulse potential victims dictionary
	for node_ref in shield_pulse_victims:
		shield_pulse_remove_victim(node_ref, false) # queue_free() each Line2D that shows the potential Shield pulse launch directions
	shield_pulse_victims.clear() # Clear the dictionary

######################
## Action functions
######################
func get_primary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Shield's primary action
	"""
	return o_cyactionbundle_primary_shield_guard

func get_secondary_action_bundle() -> CyarmActionBundle:
	"""
	Gets the current CyarmActionBundle for Cyarm-Shield's secondary action
	"""
	return o_cyactionbundle_secondary_shield_slide

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
			shield_guard_reached() # Shield guarded Player

######################
## State & Animation functions
######################
func in_state(query_state : ShieldState) -> bool:
	"""
	query_state : ShieldState -- state to query
	
	Returns : bool -- whether current Shield state matches query state
	"""
	return shield_curr_state == query_state

func exit_state() -> void:
	"""
	Performs cleanup of current Cyarm state
	"""
	(o_cyarm_state_bundle_dict[shield_curr_state] as CyarmStateBundle).func_exit_state.call()

func trans_state(new_shield_state : ShieldState, cleanup : bool = true) -> void:
	"""
	Transitions to new Cyarm state
	
	new_shield_state : ShieldState -- new Cyarm-Shield state to transition to
	cleanup : bool = false -- whether or not to call exit_state() before transitioning to new state
	"""
	if cleanup and new_shield_state != shield_curr_state:
		# Only exit state if transitioning to a new state
		exit_state()

	shield_curr_state = new_shield_state

func update_animations() -> void:
	"""
	Updates Cyarm sprite to animation matching current state
	"""
	# Updates sprite
	(o_cyarm_state_bundle_dict[shield_curr_state] as CyarmStateBundle).func_animate.call()

	# Updates trails
	if shield_curr_state == ShieldState.IDLING:
		update_trails()
	else:
		update_trails(false)
	
	#if Globals.EM_f_can_electro_cast:
		## If Player has enough electro to cast Shield pulse,
		## show the range indicator, as well as potential launch trajectories
		#shield_pulse_draw_trajectories()
		#c_sprite_pulse_range_indicator.visible = true
	#else:
		#c_sprite_pulse_range_indicator.visible = false

##################
## Shared Cyarm Functions
##################
func get_curr_state() -> String:
	"""
	Returns : String -- the state of the current Cyarm
	"""
	return shield_state_as_str

func get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	return (o_cyarm_state_bundle_dict[shield_curr_state] as CyarmStateBundle).func_get_action_texture.call(get_primary)

func get_radial_icon_action_texture(_action_context : CyarmActionContext) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture for CyarmRadialMenu, of the next action based on pressed action buttons
	
	_action_context : CyarmActionContext -- whether or not action buttons are pressed + mouse global position
	"""
	if _action_context == null: # If context doesn't matter, return base icon
		return o_cyactiontext_icon_shield

	if _action_context.primary_action_pressed:
		return o_cyactiontext_icon_shield_guard
	elif _action_context.secondary_action_pressed:
		if Globals.player_f_is_grounded:
			return o_cyactiontext_icon_shield_slide
		else:
			return o_cyactiontext_icon_shield_glide
		
	return o_cyactiontext_icon_shield

func get_crosshair_proposed_pos() -> Vector2:
	"""
	Returns : Vector2 -- the position of the crosshair to best represent the current Cyarm mode
	"""
	# Cyarm-Shield has no real aiming, so just return current mouse position
	return Globals.mouse_pos

func update_physics_flags(_delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	pass

func do_physics_state_func(delta : float) -> void:
	"""
	Runs every physics frame

	delta : float -- time between physics frames
	"""
	# Calls function specific to current ShieldState every physics frame 
	(o_cyarm_state_bundle_dict[shield_curr_state] as CyarmStateBundle).func_during_physics.call(delta)

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Cyarm currently does
	"""
	return o_no_damage

##################
## Shield Specific Functions
##################
func shield_get_action_texture(get_primary : bool) -> CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm-Shield action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	if get_primary:
		return o_cyactiontext_primary_shield_guard
	else:
		if shield_curr_state == ShieldState.SLIDING:
			return o_cyactiontext_secondary_shield_slide_held
		elif shield_curr_state == ShieldState.GLIDING:
			return o_cyactiontext_secondary_shield_glide_held
		else:	
			if c_timer_shield_glide_onclick_buffer.is_stopped():
				return o_cyactiontext_secondary_shield_slide
			else:
				return o_cyactiontext_secondary_shield_glide

func shield_get_guard_availability() -> float:
	"""
	Returns : float -- how "available" Shield guard is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1 - (c_timer_shield_guard.time_left / c_timer_shield_guard.wait_time)

func shield_get_slide_availability() -> float:
	"""
	Returns : float -- how "available" Shield slide is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1
	
func shield_get_glide_availability() -> float:
	"""
	Returns : float -- how "available" Shield glide is (1.0 is ready, 0.0 is just used and on cooldown)
	"""
	return 1

func shield_get_ledgeup_pos() -> Vector2:
	"""
	Get the position of the top-middle of Shield
	"""
	return c_raycast_top_clearance.global_position

func shield_has_top_clearance(dist_to_check : float) -> bool:
	"""
	dist_to_check : float -- distance to check

	Returns : bool -- whether or not there is enough given space above Shield
	"""
	dist_to_check = abs(dist_to_check) # No negative distance
	c_raycast_top_clearance.target_position = Vector2(0, dist_to_check)
	c_raycast_top_clearance.force_raycast_update() # Force update this frame
	return (not c_raycast_top_clearance.is_colliding())

func shield_pulse_clean_trajectory() -> void:
	"""
	Cleans up related Cyarm-Shield trajectory attributes
	"""
	trans_state(ShieldState.IDLING)

func shield_pulse_add_victim(victim : Node) -> void:
	"""
	Adds Node that can be potentially affected by Shield pulse to a dictionary of {Node, Line2D}
	
	victim : Node -- the Node that was potentially affected by Shield pulse
	"""
	if not shield_pulse_victims.has(victim):
		# Only add a Line2D if the potential victim doesn't already have one
		var _line : Line2D = s_shield_pulse_potential_line.instantiate()
		shield_pulse_victims[victim] = _line
		
		c_folder_pulse_victims.add_child(_line)

func shield_pulse_remove_victim(victim : Node, do_erase : bool = true) -> void:
	"""
	Removes Node that can be potentially affected by Shield pulse from a dictionary of {Node, Line2D}
	
	victim : Node -- the Node that was potentially affected by Shield pulse
	do_erase : bool -- whether to erase the potentially affected Node from the dictionary
	"""
	if shield_pulse_victims.has(victim):
		# Only try removing potential victim if it was Pulsable
		var _line : Line2D = shield_pulse_victims[victim]
		_line.call_deferred("queue_free")
		
		if do_erase:
			shield_pulse_victims.erase(victim)

func shield_pulse_draw_trajectories() -> void:
	"""
	Uses Dictionary of {Node, Line2D} to draw trajectories of every Node potentially affected by Shield pulse
	"""
	for node_ref in shield_pulse_victims:
		var _line_ref : Line2D = shield_pulse_victims[node_ref]
		var _node_pos : Vector2 = Utilities.get_middlepos_of(node_ref)
		var _pulse_dir : Vector2 = (_node_pos - global_position).normalized() * shield_pulse_launch_dir_length

		_line_ref.clear_points()
		_line_ref.global_position = _node_pos # Position of Node potentially affected by Shield pulse
		
		# Line points from potentially affected Node in the direction Shield pulse would launch it
		_line_ref.add_point(Vector2.ZERO)
		_line_ref.add_point(_pulse_dir) # Direction Shield pulse would launch Node

func shield_pulse_slow() -> void:
	"""
	Slows down time while aiming Shield pulse
	"""
	if not c_timer_shield_pulse.is_stopped():
		# Only Shield pulse if action has cooled down
		return
	
	# Slow down time while aiming Shield pulse
	Globals.set_time_scale_slow()
	trans_state(ShieldState.PULSING)

func shield_pulse_do() -> void:
	"""
	Applys Shield pulse to all Nodes in range, launching them in a direction directly away from Shield
	"""
	# Set time_scale back to normal
	Globals.set_time_scale_normal()
	
	for node_ref in shield_pulse_victims:

		if Utilities.is_player(node_ref):
			# If Player, then signal Player to dash in direction directly away from Shield
			sig_player_dash_away_from_shield.emit()

		else: # Not Player
			if "override_vel" in node_ref:
				var _node_pos : Vector2 = Utilities.get_middlepos_of(node_ref)
				var _vel_toapply : Vector2 = (_node_pos - global_position).normalized() * shield_pulse_speed.val
				node_ref.override_vel(_vel_toapply)
	
	# Emit signal to DECREASE electro
	sig_electroMgr_electro_shield_pulse.emit()
	
	# Shield pulse cooldown
	c_timer_shield_pulse.start()

func shield_guard_begin() -> void:
	"""
	Begins Shield-guard
	"""
	if not c_timer_shield_guard.is_stopped():
		# Only Shield guard if action has cooled down
		return
	
	# Freeze Player movement until Shield guard invincibility ends
	sig_player_freeze.emit(true)

	# Shield guard will always take the same amount of time regardless of Shield's current position
	var _shield_guard_pos : Vector2 = Globals.player_center_pos
	var _shield_guard_speed = global_position.distance_to(_shield_guard_pos) / shield_guard_reach_duration.val
	o_move_onrails.begin_to_target(_shield_guard_pos, _shield_guard_speed) # Begin move to guard position
	
	# Move Shield in front of Player
	z_index = Globals.player_z_index + 1

	f_locked = true # Prevent Cyarm from changing during Shield-guard
	f_shield_guard_reached = false # Just beginning, so set reached flag false
	c_timer_shield_clean.start() # Start the timer that is synced to the animation length of Shield guard
	c_timer_shield_guard.start()
	trans_state(ShieldState.GUARDING)
	
func shield_guard_reached() -> void:
	"""
	Once Shield-guard reaches position
	"""
	# Guard position is new follow position
	set_follow_pos(global_position)

	# Set flag to cause the guard animation to play
	f_shield_guard_reached = true 

func shield_guard_invincible_begin() -> void:
	"""
	Called from Shield-guard animation, properties to set during Shield (and Player) invincibility
	"""
	# Enable Shield-guard collider
	c_collider_shield_guard.set_deferred("disabled", false)
	
	# Signal Player to become invincible to damage
	sig_player_shield_guard_invincible.emit(true)
	
	# Start the timer that is synced to the invincibility duration of Shield guard
	c_timer_shield_invincibility.start()

func shield_guard_invincible_end() -> void:
	"""
	Called from Shield-guard animation, properties to set after Shield (and Player) invincibility
	"""
	## Shield Colliders
	c_collider_shield_guard.set_deferred("disabled", true) # Disable Shield-guard collider
	
	## Signal Player
	sig_player_freeze.emit(false) # Unfreeze Player movement
	sig_player_shield_guard_invincible.emit(false) # Make Player again be vulnerable to damage

func shield_clean_guard() -> void:
	"""
	Called at the end of the guard effect animation, to set Shield back to idle state
	"""
	set_follow_pos(global_position, true) # Return to Player

	# Move Shield behind Player
	z_index = Globals.player_z_index - 1

	f_locked = false # Allow Cyarm to change form after Shield-guard
	f_shield_guard_reached = false
	trans_state(ShieldState.IDLING)

func shield_slide_begin(on_press : bool = true) -> void:
	"""
	Begin Shield slide
	"""
	# Flags
	f_request_shield_slide = false
	f_shield_sliding = true
	trans_state(ShieldState.SLIDING)
	
	sig_player_shieldslide.emit(true, on_press) # Signal Player
	
func shield_slide_during() -> void:
	"""
	During Shield slide
	"""
	global_position = Globals.player_center_pos

func shield_slide_end() -> void:
	"""
	End Shield slide
	"""
	# Set flags
	f_shield_sliding = false
	trans_state(ShieldState.IDLING, false)
	
	# Signal Player to end Shield slide
	sig_player_shieldslide.emit(false)

func shield_glide_begin(on_click : bool = false) -> void:
	"""
	Begin Shield glide
	
	on_click : bool -- whether Shield glide was initiated from a double-click
	"""
	# Set flags
	f_request_shield_glide = false
	f_shield_gliding = true
	trans_state(ShieldState.GLIDING)
	
	sig_player_shieldglide.emit(true, on_click) # Signal Player
	
func shield_glide_during() -> void:
	"""
	During Shield slide
	"""
	global_position = Globals.player_center_pos

func shield_glide_end() -> void:
	"""
	End Shield slide
	"""
	# Set flags
	f_shield_gliding = false
	trans_state(ShieldState.IDLING, false)
	
	# Signal Player to end Shield glide
	sig_player_shieldglide.emit(false, false)

##################
## Received Signals
##################
func _on_shield_clean_timer_timeout() -> void:
	"""
	Called once Shield guard "finishes" animation. Using a timer instead of an on_animation_finished
	signal, since Shield pulse can be used during Shield guard, which would interrupt Shield guard animation
	"""
	if in_state(ShieldState.GUARDING):
		shield_clean_guard() # Set Shield state back to idle

func _on_shield_invincibility_duration_timeout() -> void:
	"""
	Called once Shield guard "finishes" animation. Using a timer instead of an on_animation_finished
	signal, since Shield pulse can be used during Shield guard, which would interrupt Shield guard animation
	"""
	# Shield pulse may be used during Shield guard, so in the event where shield_guard_invincible_end() wasn't
	# called by the Shield guard animation, call it once the Timer expires
	if not c_collider_shield_guard.disabled:
		shield_guard_invincible_end() # Revert Player invincibility and frozen movement

func _on_guard_hitbox_area_entered(area: Area2D) -> void:
	"""
	When a DamageArea enters the guard hitbox
	"""
	var _f_shield_guard_success : bool = false
	var _creator : Node = area # Creator of the potential damage
	
	# Reflect Projectiles back to creator
	if _creator.has_method("return_to_sender"):
		_creator.return_to_sender()
		_f_shield_guard_success = true

func _on_received_shieldslide_request_begin() -> void:
	"""
	Player requests to enter Shield slide state. If button still pressed, tell Player to enter that state.
	"""
	f_request_shield_slide = true

func _on_received_shieldslide_cancel() -> void:
	"""
	Cancel Cyarm-Shield slide (because Player just bounced off an Enemy)
	"""
	if in_state(ShieldState.SLIDING):
		shield_slide_end()

func _on_received_shieldglide_request_begin() -> void:
	"""
	Player requests to enter Shield glide state. If button still pressed, tell Player to enter that state.
	"""
	f_request_shield_glide = true

func _on_pulse_hitbox_body_entered(body: Node2D) -> void:
	"""
	When a Node enters range of Shield pulse, add it to an array
	"""
	if Utilities.is_pulsable(body):
		shield_pulse_add_victim(body) # Only add if the Node can be affected by Shield pulse

func _on_pulse_hitbox_body_exited(body: Node2D) -> void:
	"""
	When a Node exits the range of Shield pulse, remove it from the array
	"""
	if Utilities.is_pulsable(body):
		shield_pulse_remove_victim(body) # Only remove if the Node can be affected by Shield pulse

func _on_guard_hitbox_body_entered(body: Node2D) -> void:
	"""
	When a Node enters the range of Shield guard
	"""
	pass

func _on_received_cyarm_sword_disabled(_disabled_during_slash_mouse_pos : Vector2, disabled_during_sword_board : bool) -> void:
	"""
	Cyarm-Sword was disabled
	
	disabled_during_slash_mouse_pos : Vector2 -- the mouse position when Sword was disabled mid-slash
	disabled_during_sword_board : Vector2 -- whether Sword was disabled while swordboarding
	"""
	# If Cyarm-Sword was disabled while swordboarding, queue re-enable Shield at
	# the bottom of Player feet, and stop player momentum 
	if disabled_during_sword_board:
		f_after_enable_pos_under_player = true

func _on_received_cyarm_spear_disabled(disabled_during_spear_broom : bool) -> void:
	"""
	Cyarm-Spear was disabled
	
	disabled_during_spear_broom : bool -- whether Player disabled Spear while spearbrooming
	"""
	# If Cyarm-Spear was disabled while spearboarding, queue re-enable Shield at
	# the bottom of Player feet, and stop player momentum
	if disabled_during_spear_broom:
		f_after_enable_pos_under_player = true

func _on_received_cyMgr_cyarm_enabled() -> void:
	"""
	A Cyarm mode was just enabled. Signal received after CyarmBase.enable()
	"""
	# After a Cyarm was enabled, reset enable flags
	f_after_enable_pos_under_player = false
