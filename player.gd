extends CharacterBody2D

# Variable naming:
"""
c_* -- component
f_* -- flag
f_a_* -- animation flag
func_* -- function reference
anim_func_* -- function to be called by AnimationPlayer
s_* -- scene
o_* -- object
sig_* -- signal
_* -- local temporary variable
"""
func top_of_script() -> void:
	# Method to quickly return to top of script from the sidebar method list
	pass

#region Signals
signal sig_player_readied
signal sig_player_died
signal sig_player_respawned
signal sig_player_HP_changed(new_HP : int)
signal sig_player_swordiai_ended_cut()
signal sig_cyarm_follow_player
signal sig_cyarm_hide(do_hide : bool)
signal sig_cyarm_swordiai_SwordIaiStop_spawn(spawn_pos : Vector2)
signal sig_cyarm_swordiai_finish()
signal sig_cyarm_spear_unlock()
signal sig_cyarm_sicklepull_cancel()
signal sig_cyarm_shieldslide_request_begin()
signal sig_cyarm_shieldslide_cancel()
signal sig_cyarm_shieldglide_request_begin()
signal sig_cyarm_shieldglide_cancel()
signal sig_electroMgr_electro_swordboard_slide()
signal sig_electroMgr_electro_swordboard_slash()
signal sig_electroMgr_electro_spearbrooming()
signal sig_electroMgr_electro_speartethering_nudge()
signal sig_electroMgr_electro_shield_guard_success()
signal sig_world_dim(do_dim : bool)
signal sig_world_spawn_afterimage(pos : Vector2, facing_dir : float)
signal sig_world_spawn_dust(pos : Vector2, facing_dir_x : float, facing_dir_y : float, anim : String, ground_dir : Vector2)
signal sig_world_spawn_rot_effect(pos : Vector2, rot : float, anim : String)
signal sig_world_spawn_sicklepulldecision(pos : Vector2, time_left : float, sickle_stuck_target : Node)
signal sig_HUD_display_HP(new_text : Texture2D)
signal sig_cameraMgr_follow_node(new_node : Node2D)
signal sig_cameraMgr_follow_pos(new_pos : Vector2)
#endregion

#region Component References
@onready var c_animplayer : AnimationPlayer = $AnimationPlayer
@onready var c_sprite : AnimatedSprite2D = $PlayerSprite
@onready var c_sprite_cyarm : AnimatedSprite2D = $CyarmSprite
@onready var c_sprite_arrowhead : Sprite2D = $ArrowBody/ArrowHead
@onready var c_area_inside : Area2D = $AreaColliders/InsidePlayerArea
@onready var c_area_shieldslide : Area2D = $AreaColliders/ShieldSlideHitbox
@onready var c_collider : CollisionShape2D = $PlayerCollider
@onready var c_collider_inside : CollisionShape2D = $AreaColliders/InsidePlayerArea/InsidePlayerCollider
@onready var c_collider_movableplatform : CollisionShape2D = $AreaColliders/CheckMovablePlatform/CheckMovablePlatformCollider
@onready var c_collider_swordboard_slash : CollisionShape2D = $CyarmSprite/SwordboardSlashCollider
@onready var c_collider_swordboard_dive : CollisionShape2D = $CyarmSprite/SwordboardDiveCollider
@onready var c_raycast_eye : RayCast2D = $Raycasts/EyeCast
@onready var c_raycast_shoulder : RayCast2D = $Raycasts/ShoulderCast
@onready var c_raycast_walljump : RayCast2D = $Raycasts/WallJumpCast
@onready var c_raycast_ledgesurface : RayCast2D = $Raycasts/LedgeSurfaceCast
@onready var c_raycast_below_left : RayCast2D = $Raycasts/BelowLeftCast
@onready var c_raycast_below_right : RayCast2D = $Raycasts/BelowRightCast
@onready var c_raycast_ledge_left : RayCast2D = $Raycasts/LedgeLeftCast
@onready var c_raycast_ledge_right : RayCast2D = $Raycasts/LedgeRightCast
@onready var c_raycast_stillstanding_on_ledge : RayCast2D = $Raycasts/StillStandOnLedgeCast
@onready var c_raycast_dashtrajectory : RayCast2D = $Raycasts/DashTrajectoryCast
@onready var c_raycast_lastgroundedpos : RayCast2D = $Raycasts/LastGroundedPosCast
@onready var c_shapecast_playerfits : ShapeCast2D = $Raycasts/PlayerFitsCast
@onready var c_marker_cyarm : Marker2D = $Markers/CyarmPos
@onready var c_marker_grind : Marker2D = $Markers/GrindPos
@onready var c_marker_sicklepull_tether : Marker2D = $Markers/SicklePullTetherPos
@onready var c_line_dashtrajectory: Line2D = $Lines/DashTrajectory
@onready var c_line_arrowbody: Line2D = $ArrowBody
@onready var c_line_spear_tether : Line2D = $Lines/SpearTether
@onready var c_particles_ring: GPUParticles2D = $Particles/RingParticles
@onready var c_timer_coyote : Timer = $Timers/CoyoteTimer
@onready var c_timer_jumpbuffer : Timer = $Timers/JumpBuffer
@onready var c_timer_invincible : Timer = $Timers/InvincibleTimer
@onready var c_timer_swordslash_freeze : Timer = $Timers/SwordSlashFreeze
@onready var c_timer_swordiai_hangtime : Timer = $Timers/SwordIaiHangtime
@onready var c_timer_spearbroom_turn : Timer = $Timers/SpearbroomTurnTimer
@onready var c_timer_sickle_time_before_swing : Timer = $Timers/SickleTimeBeforeSwing
@onready var c_timer_sicklepull_hangtime : Timer = $Timers/SicklepullHangtime
@onready var c_timer_grind_cooldown : Timer = $Timers/GrindCooldown
#endregion

#region Health vars
var f_invincible : bool = false
var f_invincible_from_shield : bool = false
var f_dead : bool = false
var max_HP : int = 3
var curr_HP : int = max_HP:
	set(new_HP):
		curr_HP = clampi(new_HP, 0, max_HP)
		sig_player_HP_changed.emit(curr_HP)
		match curr_HP:
			1:
				sig_HUD_display_HP.emit(HP_1_text)
			2:
				sig_HUD_display_HP.emit(HP_2_text)
			3:
				sig_HUD_display_HP.emit(HP_3_text)
			_:
				sig_HUD_display_HP.emit(HP_0_text)
var invincible_duration : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_invincible)
var HP_0_text : Texture2D = preload("res://sprites/UI/UI_HP_0.png")
var HP_1_text : Texture2D = preload("res://sprites/UI/UI_HP_1.png")
var HP_2_text : Texture2D = preload("res://sprites/UI/UI_HP_2.png")
var HP_3_text : Texture2D = preload("res://sprites/UI/UI_HP_3.png")
#endregion

#region Movement vars
const f_GOD_MODE : bool = false
var f_freeze_movement : bool = false
var vel_b4_freeze : Vector2
var max_speed : CVP_Speed = CVP_Speed.new(240.0)
var acceleration_grnd : CVP_Acceleration = CVP_Acceleration.new(37.0)
var acceleration_air : CVP_Acceleration = CVP_Acceleration.new(13.9)
var friction_grnd_lesser : CVP_Acceleration = CVP_Acceleration.new(5.0)
var friction_grnd_greater : CVP_Acceleration = CVP_Acceleration.new(61.0)
var friction_air : CVP_Acceleration = CVP_Acceleration.new(3.0)
var left_or_right : int # GUARENTEED to be either -1 or 1
var curr_direction : float:
	set(newDir):
		if not is_equal_approx(curr_direction, newDir): # Only set if curr_direction changes
			curr_direction = newDir
			if curr_direction: # Only left or right
				left_or_right = sign(curr_direction) # Always -1 or 1
				change_player_direction() # Flips raycasts
var f_facing_left : bool:
	get:
		return curr_direction < 0
var f_facing_right : bool:
	get:
		return curr_direction > 0
#endregion

#region Corner Correction & Collider vars
var mid_global_position : Vector2 = Vector2.ZERO # The position of the "middle" of the Player sprite, since normal global_position is at sprite bottom 
var mid_canvas_position : Vector2 = Vector2.ZERO
var f_is_collide_nextframe : bool = false:
	get:
		# Make sure the collision flag is always up-to-date by calling test_move() when flag is got
		return test_move(global_transform, velocity * get_physics_process_delta_time())
@onready var width : float = c_collider.shape.size.x
@onready var height : float = c_collider.shape.size.y
@onready var half_width : float = c_collider.shape.size.x / 2
@onready var half_height : float = c_collider.shape.size.y / 2
@onready var corner_leeway_x : float = half_width + 1 # Around half of Player width
@onready var corner_leeway_y : float = 8 # 8 Pixels from Player feet
#endregion

#region Jumping vars
var f_apply_gravity : bool = true
var f_is_grounded : bool = false:
	set(flag):
		if not f_is_grounded and flag == true:
			f_just_landed = true # Last frame not grounded, now grounded, means just landed
			f_do_variable_jump = false # Reset variable jump flag
		f_is_grounded = flag
var f_just_landed : bool = false
var f_is_rising : bool = false
var f_is_falling : bool = false
var f_jump_buffer_active : bool = false
var f_can_jump : bool = false # Flag to jump
var f_can_coyote : bool = false # Flag so coyote-time timer fires ONCE before jump
var f_do_variable_jump : bool = false # Flag so that jump height increases with held jump button
var close_to_ground_leeway : float = 12.0 # The distance to consider Player as "close to grounded"
var jump_peak_height : float = 60
var jump_time_to_peak : float = 0.36
var jump_time_to_floor : float = 0.38
var jump_initial_speed : CVP_Speed = CVP_Speed.new((2.0 * jump_peak_height / jump_time_to_peak))
var gravity_during_jump : CVP_Acceleration = CVP_Acceleration.new(2.0 * jump_peak_height / pow(jump_time_to_peak, 2)) # Multiply by physics delta time in get_gravity()
var gravity_during_fall : CVP_Acceleration = CVP_Acceleration.new(2.0 * jump_peak_height / pow(jump_time_to_floor, 2)) # Multiply by physics delta time in get_gravity()
var bump_initial_speed : CVP_Speed = CVP_Speed.new(jump_initial_speed.val * 0.8)
var max_fall_speed : CVP_Speed = CVP_Speed.new(689.0)
var coyote_time_duration : CVP_Duration = CVP_Duration.new(0.09, true, c_timer_coyote)
var jump_buffer_duration : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_jumpbuffer)

var mov_terrain_ref : Node2D # Reference to a MovableTerrain that Player is currently standing on
var f_mov_terrain_can_jump : bool = false # Whether Player is currently allowed to jump, while standing on a MovableTerrain
#endregion

#region Wall-slide & Ledge-up vars
var f_is_wallsliding : bool = false
var f_is_ledgeupping : bool = false
var wall_slide_speed : CVP_Speed = CVP_Speed.new(100.0)
var ledgeup_duration : CVP_Duration = CVP_Duration.new(0.13) # Time it takes to complete ledge up
@onready var ray_eye_len : float = half_width + 2.0
@onready var ray_ledge_x : float = c_raycast_ledgesurface.position.x
#endregion

#region Crouching vars
var f_is_crouching : bool = false
@onready var ray_stillstanding_on_ledge_x : float = c_raycast_stillstanding_on_ledge.position.x
#endregion

#region Dashing vars
var f_is_dashing : bool = false
var dash_distance : float = 135.0
var dash_distance_swordboarding : float = 100.0
var dash_distance_spearthrow : float = 70.0
var dash_speed : CVP_Speed = CVP_Speed.new(1000.0)
var dash_to_spear_duration : CVP_Duration = CVP_Duration.new(0.13)
#endregion

#region Input vars
var f_butt_jump_just_pressed : bool = false
var f_butt_jump_holding : bool = false
var f_butt_jump_just_released : bool = false
var f_crouch_just_pressed : bool = false
var f_crouch_holding : bool = false
var f_crouch_just_released : bool = false
#endregion

#region LastGroundedBundle (class used to store related Player last grounded attributes together)
var o_lastgroundedbundle : LastGroundedBundle
class LastGroundedBundle:
	var player_ref : Node
	var f_on_surface : bool:
		set(flag):
			f_on_surface = flag
			if not f_on_surface: # If not on surface, cannot be on ground or on wall
				f_on_ground = false
				f_on_wall = false
	var f_on_ground : bool:
		set(flag):
			f_on_ground = flag
			if f_on_ground: f_on_wall = false # Can't be on wall if on ground
	var f_on_wall : bool:
		set(flag):
			f_on_wall = flag
			if f_on_wall: f_on_ground = false # Can't be on ground if on wall
	var pos : Vector2

	func _init(_player_ref : Node):
		player_ref = _player_ref
	
	func get_pos() -> Vector2:
		if f_on_surface:
			# Player on surface, return last grounded/wall position
			return pos
		else:
			# Player airborne, return Player current position
			return player_ref.global_position
			
	func set_on_ground_pos(ground_pos : Vector2) -> void:
		"""
		Set when Player jumping from ground

		ground_pos : Vector2 -- position Player jumped from
		"""
		pos = ground_pos
		f_on_surface = true
		f_on_ground = true

	func set_on_wall_pos(wall_pos : Vector2) -> void:
		"""
		Set when Player jumping from wall

		wall_pos : Vector2 -- position Player jumped from
		"""
		pos = wall_pos
		f_on_surface = true
		f_on_wall = true

	func set_non_surface() -> void:
		"""
		Set when Player jumping in midair, using a Cy-point
		"""
		f_on_surface = false
#endregion

#region MoveOnRails (class to hold related movement vars together)
var o_move_onrails : MoveOnRails
var move_onrails_type_as_str : String: # For debugging
	get:
		return MoveOnRails.RAIL_TYPE.keys()[o_move_onrails.move_onrails_type]
var f_moving_onrails : bool
var f_mor_jump_just_pressed : bool = false # Pressing jump during move-on-rails
var f_jump_after_move_onrails : bool = false # Jump immediately after move-on-rails
var mor_curr_direction : float # Moving left/right during move-on-rails
#endregion

#region Cyarm-Sword Slash vars
var f_is_swordslashing : bool = false
var swordslashing_freeze_duration : CVP_Duration = CVP_Duration.new(0.24, true, c_timer_swordslash_freeze)
#endregion

#region Cyarm-Sword Iai vars
var f_is_swordiaiing : bool = false
var f_do_spawn_swordaiaistop : bool = false
var sword_iai_speed : CVP_Speed = CVP_Speed.new(max_speed.val * 8.8)
var sword_iai_after_hangtime_duration : CVP_Duration = CVP_Duration.new(0.13, true, c_timer_swordiai_hangtime)
enum SwordIaiState {NONE, READY, CUT, AFTER_CUT, DONE,}
var sword_iai_curr_state : SwordIaiState = SwordIaiState.NONE
#endregion

#region Cyarm-Spearbrooming vars
var f_is_spearbrooming : bool = false
var spearbrooming_flip_sprite_JC : JitterCounter
var spearbrooming_incline_sprite_JC : JitterCounter
var spearbrooming_dir : Vector2 = Vector2.ZERO
var spearbrooming_rot : float = PI / 128 # Adjust spearbrooming heading by a bit each frame when following mouse
var global_dist_to_mouse : float # Distance from Player middlepos to mouse (global_position)
var canvas_dist_to_mouse : float # Distance from Player middlepos to mouse (get_global_transform_with_canvas().origin)
var max_speed_spearbrooming : CVP_Speed = CVP_Speed.new(max_speed.val * 1.6)
var spearbrooming_turn_cooldown : CVP_Duration = CVP_Duration.new(0.08, true, c_timer_spearbroom_turn)
#endregion

#region Cyarm-Spear throw vars
var f_spear_unlock_after_dash : bool = false # If true, signal Cyarm-Spear to unlock itself after dash
var spear_pickup_range : float = 60.0 # How close Spear can be to be automatically "picked up"
#endregion

#region Cyarm-Spear tether vars
var f_is_speartethering : bool = false
var speartether_anchor_pos : Vector2 # Pivot of pendulum-like motion, Cyarm-Spear position
var speartether_length : float
var speartether_angle : float # Angle from Vector2.UP, instead of default Vector2.RIGHT
var gravity_speartether : float = 1.2#CVP_Acceleration = CVP_Acceleration.new(1.2)
var speartether_damping : float = 0.98 # Reduce current velocity each physics frame (simulate losing momentum)
var speartether_angle_speed : float # Current angular velocity (radians)
var speartether_max_angle_speed : CVP_Speed = CVP_Speed.new(PI / 18, false)
var speartether_max_tangential_speed = CVP_Speed.new(16.0) # Used to limit max angular velocity
var speartether_nudge_acceleration : CVP_Speed = CVP_Speed.new(0.0, false) # Recalculated every frame
var speartether_gravity_acceleration : CVP_Speed = CVP_Speed.new(0.0, false) # Recalculated every frame 
var speartether_hide_arrow_JC : JitterCounter
#endregion

var f_is_sickleswinging : bool = false
var sickleswing_anchor_pos : Vector2 # Pivot of pendulum-like motion, Cyarm-Spear position
var sickleswing_next_pos : Vector2
var sickleswing_length : float
var sickleswing_angle : float # Angle from Vector2.UP, instead of default Vector2.RIGHT
var sickleswing_damping : float = 0.98 # Reduce current velocity each physics frame (simulate losing momentum)
var sickleswing_curr_angle_speed : float # Current angular velocity (radians)
var sickle_swing_hangtime_before_swing : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_sickle_time_before_swing) # Don't put Player in pendulum calculations for a bit
#endregion

#region Cyarm-Sickle pull vars
var curr_sicklepull_type : CyarmSickle.SicklePull = CyarmSickle.SicklePull.END_PULL
var f_is_sicklepulling : bool = false
var f_a_just_sicklepulled : bool = false
var sicklepull_target : Node2D
var sicklepull_towards_dir : Vector2
var sicklepull_initial_speed : CVP_Speed = CVP_Speed.new(max_speed.val * 1.7)
var sicklepull_target_initial_speed : CVP_Speed = CVP_Speed.new(sicklepull_initial_speed.val * 0.8)
var sicklepull_acceleration : CVP_Acceleration = CVP_Acceleration.new(5.9)
var sicklepull_target_acceleration : CVP_Acceleration = CVP_Acceleration.new(sicklepull_acceleration.val * 2.3)
var sicklepull_decceleration : CVP_Acceleration = CVP_Acceleration.new(28.8)
var sickle_pull_after_hangtime_duration : CVP_Duration = CVP_Duration.new(0.17, true, c_timer_sicklepull_hangtime)
#endregion

#region Cyarm-Shield vars
var cyarm_shield_ref : CyarmShield
var f_cyarm_shield_overlapping : bool = false
#endregion

#region Cyarm-Shield slide vars
var f_is_shieldsliding : bool = false
var f_shieldslide_do_fall : bool = false
var f_a_just_shieldslide_bumped : bool = false
var shieldslide_bump_target_pos : Vector2
var shieldslide_dir : int = 1 # Either -1 or 1
var max_speed_shieldsliding : CVP_Speed = CVP_Speed.new(max_speed.val * 2.0)
var max_fall_speed_shieldsliding : CVP_Speed = CVP_Speed.new(max_fall_speed.val * 2.6)
var gravity_during_shieldsliding : CVP_Acceleration = CVP_Acceleration.new(98.1)
var shieldslide_friction : CVP_Acceleration = CVP_Acceleration.new(friction_air.val * 4.5)
var shieldslide_accel_default : CVP_Acceleration = CVP_Acceleration.new(3.7)
var shieldslide_accel_pressing : CVP_Acceleration = CVP_Acceleration.new(shieldslide_accel_default.val * 2.3)
var shieldslide_grind_cooldown : CVP_Duration = CVP_Duration.new(0.07, true, c_timer_grind_cooldown)
#endregion

#region Cyarm-Shield glide vars
var f_is_shieldgliding : bool = false
var fall_gravity_during_shieldglide : CVP_Acceleration = CVP_Acceleration.new(0.8)
var max_fall_speed_shieldgliding : CVP_Speed = CVP_Speed.new(max_fall_speed.val / 3)
var max_speed_shieldgliding : CVP_Speed = CVP_Speed.new(max_speed.val * 1.1)
var shieldglide_acceleration : CVP_Acceleration = CVP_Acceleration.new(acceleration_air.val * 1.5)
var shieldglide_friction : CVP_Acceleration = CVP_Acceleration.new(friction_air.val * 1.5)
#endregion

#region State & Animation vars
enum BodyState {
	DEFAULT,
	DYING,
	IDLE,
	RUN,
	JUMP, JUMPING,
	FALLING,
	LAND,
	WALLSLIDE,
	LEDGEUP,
	CROUCH_IDLE, CROUCH_WALK,
	DASH,
	SWORDSLASH,
	SWORDIAI, SWORDIAI_CUT,
	SPEARBROOM,
	SPEARTETHER,
	SICKLESWING, SICKLEPULL,
	SHIELDSLIDE, SHIELDGLIDE,
	}
var curr_body_state : BodyState = BodyState.JUMPING
var body_state_as_str : String:
	get:
		return BodyState.keys()[curr_body_state]

# BodyStateBundle class used to bundle Player BodyState functions together
var o_body_state_bundle_dict : Dictionary = {} # {BodyState -> BodyStateBundle}
class BodyStateBundle:
	var player_ref : Node
	
	# References to FUNCTIONS
	var func_animate : Callable
	var func_during_physics : Callable
	var func_exit_state : Callable

	func _init(
					_player_ref : Node,
					_func_animate : Callable,
					_func_during_physics : Callable,
					_func_exit_state : Callable
				):
		player_ref = _player_ref
		func_animate = _func_animate
		func_during_physics = _func_during_physics
		func_exit_state = _func_exit_state

@onready var orig_sprite_x : float = c_sprite.position.x
@onready var orig_sprite_y : float = c_sprite.position.y
var player_z_index : int = z_index
var f_a_just_jumped : bool = false
var f_a_just_changed_dir : bool = false
var anim_crouch : String = "crouch"
var anim_dash : String = "dash"
var anim_death : String = "death"
var anim_idle : String = "idle"
var anim_jump : String = "jump"
var anim_land : String = "land"
var anim_ledgeup : String = "ledgeup"
var anim_run : String = "run"
var anim_wallslide_left : String = "wallslide_left"
var anim_wallslide_right : String = "wallslide_right"
var anim_swordslash_ground: String = "swordslash_ground"
var anim_swordiai_ready: String = "swordiai_ready"
var anim_swordiai_cut: String = "swordiai_cut"
var anim_swordiai_sheathe: String = "swordiai_sheathe"
var anim_sicklepull: String = "sicklepull"
var anim_spearbroom_crouch: String = "spearbroom_crouch"
var anim_spearbroom_stand: String = "spearbroom_stand"
var anim_spearbroom_hangingonfordearlife: String = "spearbroom_hangingonfordearlife"
var anim_speartether_grounded: String = "speartether_grounded"
var anim_shieldslide: String = "shieldslide"
var anim_shieldglide: String = "shieldglide"
#endregion

#region Shader vars
var material_default : ShaderMaterial
var material_hit : ShaderMaterial
var material_outline : ShaderMaterial
@onready var shader_default = preload("res://scripts/shaders/unshaded.gdshader")
@onready var shader_hit = preload("res://scripts/shaders/hit.gdshader")
@onready var shader_outline = preload("res://scripts/shaders/outline.gdshader")
#endregion

######################
## Main functions
######################
func _ready():
	## Set Globals 
	Globals.player_max_HP = max_HP
	Globals.player_z_index = player_z_index
	update_globals()

	## Subscribe to signals
	var _HUD : Node = get_tree().get_first_node_in_group("HUD")
	_HUD.connect("sig_HUD_readied", _on_received_HUD_readied)
	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_player_freeze", _on_received_freeze)
		cyarm.connect("sig_player_stop_momentum", _on_received_stop_momentum)
		cyarm.connect("sig_player_dash_to_spear", _on_received_dash_to_spear)
		cyarm.connect("sig_player_dash_away_from_shield", _on_received_dash_away_from_shield)
		cyarm.connect("sig_player_swordslash", _on_received_swordslash)
		cyarm.connect("sig_player_swordiai", _on_received_swordiai)
		cyarm.connect("sig_player_swordiai_cut", _on_received_swordiai_cut)
		cyarm.connect("sig_player_spearbroom", _on_received_spearbroom)
		cyarm.connect("sig_player_speartether", _on_received_speartether)
		cyarm.connect("sig_player_sickleswing", _on_received_sickleswing)
		cyarm.connect("sig_player_sicklepull", _on_received_sicklepull)
		cyarm.connect("sig_player_sickleshard_pickup", _on_received_sickleshard_pickup)
		cyarm.connect("sig_player_shield_guard_invincible", _on_received_shield_guard_invincible)
		cyarm.connect("sig_player_shield_guard_success", _on_received_shield_guard_success)
		cyarm.connect("sig_player_shieldslide", _on_received_shield_slide)
		cyarm.connect("sig_player_shieldglide", _on_received_shield_glide)
	for movable_terrain in get_tree().get_nodes_in_group("MovableTerrain"):
		movable_terrain.connect("sig_chainedplatform_began_move", _on_received_chainedplatform_began_move)
		movable_terrain.connect("sig_chainedplatform_reached_anchor", _on_received_chainedplatform_reached_anchor)

	## Set timers
	c_timer_coyote.wait_time = coyote_time_duration.val
	c_timer_jumpbuffer.wait_time = jump_buffer_duration.val
	c_timer_invincible.wait_time = invincible_duration.val
	c_timer_swordslash_freeze.wait_time = swordslashing_freeze_duration.val
	c_timer_swordiai_hangtime.wait_time = sword_iai_after_hangtime_duration.val
	c_timer_spearbroom_turn.wait_time = spearbrooming_turn_cooldown.val
	c_timer_sickle_time_before_swing.wait_time = sickle_swing_hangtime_before_swing.val
	c_timer_sicklepull_hangtime.wait_time = sickle_pull_after_hangtime_duration.val
	c_timer_grind_cooldown.wait_time = shieldslide_grind_cooldown.val

	## Set raycasts
	SETUP_colliders(c_collider.shape.size.x, c_collider.shape.size.y) # Make sure any collider that needs to match base is resized
	curr_direction = 1 # Face the right on default
	change_player_direction() # Set raycasts right-facing
	c_raycast_below_left.target_position.y = height + 1
	c_raycast_below_right.target_position.y = height + 1
	c_raycast_ledge_left.target_position.x = width
	c_raycast_ledge_right.target_position.x = -width
	
	## Create objects
	SETUP_body_state_bundles()
	o_lastgroundedbundle = LastGroundedBundle.new(self)
	o_move_onrails = MoveOnRails.new(self)
	spearbrooming_flip_sprite_JC = JitterCounter.new()
	spearbrooming_incline_sprite_JC = JitterCounter.new()
	speartether_hide_arrow_JC = JitterCounter.new()

	## Set up materials/shaders
	material_default = ShaderMaterial.new()
	material_default.shader = shader_default
	material_hit = ShaderMaterial.new()
	material_hit.shader = shader_hit
	material_outline = ShaderMaterial.new()
	material_outline.shader = shader_outline

	## Set up sprites
	c_sprite_cyarm.visible = false

	## Send signal that Player is ready
	sig_player_readied.emit()
	
	## Add to DebugStats
	DebugStats.add_stat(self, "f_can_jump")
	DebugStats.add_stat(self, "f_is_grounded")
	DebugStats.add_stat(self, "f_just_landed")
	DebugStats.add_stat(self, "f_is_ledgeupping")
	DebugStats.add_stat(self, "f_is_wallsliding")
	DebugStats.add_stat(self, "f_is_crouching")
	DebugStats.add_stat(self, "f_is_collide_nextframe")
	DebugStats.add_stat(self, "f_moving_onrails")
	DebugStats.add_stat(self, "f_is_shieldsliding")
	DebugStats.add_stat(self, "f_is_shieldgliding")
	DebugStats.add_stat(self, "f_is_swordiaiing")
	DebugStats.add_stat(self, "curr_direction")
	DebugStats.add_stat(self, "velocity")
	DebugStats.add_stat(self, "body_state_as_str")
	DebugStats.add_stat(self, "move_onrails_type_as_str")

func _process(_delta : float) -> void:
	# Button presses
	if f_moving_onrails:
		# Capture inputs during Player currently moving-on-rails
		check_inputs_during_moveonrails()
	else:
		# Accept input if Player isn't currently moving-on-rails
		update_inputs()

	# Animations
	update_state()
	update_animations()

func _physics_process(delta : float) -> void:
	# Update Player variables for this frame
	update_physics_flags()

	# Update Global Player variables
	update_globals()

	# Only move if Player is not frozen
	if not f_freeze_movement:
		## Player moves-on-rails (disregards button input)
		if f_moving_onrails:
			move_onrails(delta)

		### Player movement based on input
		else:
			## Move Player towards where mouse_pos is, for debugging
			if f_GOD_MODE:
				global_position = global_position.move_toward(Globals.mouse_pos, 3.0 + global_position.distance_to(Globals.mouse_pos) / 10)
			
			## Player Cyarm-Sickleswinging moves in pendulum-like motion
			elif f_is_sickleswinging:
				sickleswing_calc_vel()
			
			## Player Cyarm-Sicklepulling may have hang time
			elif f_is_sicklepulling:
				sicklepull_calc_vel()
				
			## Player Cyarm-Shieldsliding falls, then slides against the ground in one direction
			elif f_is_shieldsliding:
				shieldslide_calc_vel()
			
			## Player Cyarm-Shieldgliding falls down slowly
			elif f_is_shieldgliding:
				shieldglide_calc_vel()
			
			## DEFAULT Player movement
			else:
				# Calculate Player velocity this physics frame
				calc_vel_x()
				calc_vel_y()

			# Actually move Player
			move_with_correction(delta)
		
		# Perform actions based on Player state
		update_physics_state()

func update_inputs() -> void:
	"""
	Updates Player flags corresponding to button presses
	"""
	if f_dead:
		return # Player is dying, do not accept inputs
	
	## Facing Direction
	calc_player_direction()
	
	## Jumping
	f_butt_jump_just_pressed = Input.is_action_just_pressed("up")
	f_butt_jump_holding = Input.is_action_pressed("up")
	f_butt_jump_just_released = Input.is_action_just_released("up")
	# Jump buffer (used to queue jump before hitting ground)
	if f_butt_jump_just_pressed:
		begin_jump_buffer()

	## Crouching
	f_crouch_just_pressed = Input.is_action_just_pressed("down")
	f_crouch_holding = Input.is_action_pressed("down")
	if f_is_crouching and f_crouch_just_released:
		pass # Don't update just_released flag, if crouch hasn't been released yet
	else:
		f_crouch_just_released = Input.is_action_just_released("down")

	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		pass
	if Input.is_action_just_pressed("testkey2"):
		pass

func update_globals() -> void:
	"""
	Updates Player variables shared to Global script
	"""
	Globals.player_f_is_grounded = f_is_grounded
	Globals.player_pos = global_position
	Globals.player_center_pos = mid_global_position
	Globals.player_canvas_pos = get_global_transform_with_canvas().origin
	Globals.player_cyarm_follow_pos = c_marker_cyarm.global_position
	Globals.player_sickle_tether_pos = c_marker_sicklepull_tether.global_position

func update_physics_flags() -> void:
	"""
	Update Player flags for this physics frame
	"""
	# Flags
	if f_just_landed: f_just_landed = false # Just landed flag is set for one physics frame, after f_is_grounded check, so reset here
	f_is_grounded = is_on_floor()
	f_is_rising = velocity.y < 0
	f_is_falling = velocity.y > 0
	f_moving_onrails = o_move_onrails.is_active()
	f_jump_buffer_active = (not c_timer_jumpbuffer.is_stopped()) # Jump buffer still active (Player just pressed jump button)
	
	# Other stuff
	mid_global_position = get_middlepos()
	mid_canvas_position = get_middlepos_canvas()
	global_dist_to_mouse = mid_global_position.distance_to(Globals.mouse_pos)
	canvas_dist_to_mouse = mid_canvas_position.distance_to(Globals.mouse_canvas_pos)
	calc_lastgrounded_pos() # Updates pos_last_grounded
	
	# Spearbrooming
	if f_is_spearbrooming:
		spearbroom_calc_dir()

func calc_player_direction() -> void:
	"""
	Update Player direction based on input, or Player flags
	"""
	if f_is_shieldsliding:
		# Cyarm-Shieldsliding only moves in the x direction that Player was facing when initiating the action
		curr_direction = shieldslide_dir

	elif f_is_spearbrooming:
		# Player sprite may jitter, where it flips back and forth rapidly when spearbrooming x
		# direction alternates between extremely small + and - (while moving towards mouse pos that is
		# straight up or down). Prevent this by requiring 5 frames of the same x sign before
		# setting current direction and flipping Player sprite
		var _dir_this_frame = sign(spearbrooming_dir.x)
		if curr_direction != _dir_this_frame:
			if spearbrooming_flip_sprite_JC.incr_and_trigger(): # Increment JitterCounter and potentally trigger if statement
				curr_direction = _dir_this_frame # Change direction
		else:
			spearbrooming_flip_sprite_JC.reset() # Reset JitterCounter on jitter
		
	else:
		# Accept movement keys
		curr_direction = Input.get_axis("left", "right")

func change_player_direction(new_dir : float = curr_direction) -> void:
	"""
	Updates variables that depend on Player direction
	"""
	if new_dir:
		# Flip marker positions
		c_marker_cyarm.position.x = -1 * left_or_right * abs(c_marker_cyarm.position.x) # Cyarm pos is behind left top of Player
		c_marker_grind.position.x = -1 * left_or_right * abs(c_marker_grind.position.x)
		c_marker_sicklepull_tether.position.x = left_or_right * abs(c_marker_sicklepull_tether.position.x)
		
		# Flip raycast directions
		c_raycast_eye.target_position.x = left_or_right * ray_eye_len
		c_raycast_shoulder.target_position.x = left_or_right * ray_eye_len
		c_raycast_walljump.target_position.x = left_or_right * ray_eye_len
		c_raycast_ledgesurface.position.x = left_or_right * ray_ledge_x
		c_raycast_stillstanding_on_ledge.position.x = left_or_right * ray_stillstanding_on_ledge_x
		
		# If the sprite were to be flipped, then set flag to spawn dust opposite where
		# Player is now facing
		if c_sprite.flip_h != f_facing_left:
			f_a_just_changed_dir = true

		# Display proper sprite
		c_sprite.flip_h = f_facing_left

func rotate_player_sprite_to(new_rot : float) -> void:
	"""
	Rotates Player sprite, and updates colliders to match up visually
	
	new_rot : float -- rotation, in radians, to set Player sprite to
	"""
	c_sprite.rotation = new_rot # Sprite
	c_collider.rotation = new_rot # Player collider
	c_collider_inside.rotation = new_rot # Inside Player collider
	c_shapecast_playerfits.rotation = new_rot # Player shapecast

######################
## Getter Functions
######################
func get_middlepos() -> Vector2:
	"""
	The global_position of the Player is at the bottom of the collider, at the sprite's feet, so this
	function returns the "middle" position, at sprite's center

	Returns : Vector2 -- the "middle" position of the Player (the center point of collider)
	"""
	return c_collider.global_position

func get_middlepos_canvas() -> Vector2:
	"""
	The get_global_transform_with_canvas().origin of the Player is at the bottom of the collider,
	at the sprite's feet, so this function returns the "middle" position, at sprite's center

	Returns : Vector2 -- the "middle" position of the Player (the center point of collider)
	"""
	return c_collider.get_global_transform_with_canvas().origin

func get_middlepos_relative_window_coords() -> Vector2:
	"""
	Returns : Vector2 -- the middle position of Player, relative to the top left corner of main window as origin (0, 0)
	"""
	return Utilities.get_full_viewport_pos_from_visible_viewport_pos(get_viewport(), get_middlepos_canvas())

func get_angle_to_mouse() -> float:
	"""
	Returns : float -- the angle, in radians, from the Player middle position pointing to mouse position
	"""
	return mid_global_position.angle_to_point(Globals.mouse_pos)

func get_mbody_collider() -> CollisionShape2D:
	"""
	Returns : CollisionShape2D -- the main body's collider
	"""
	return c_collider

func get_acceleration() -> float:
	"""
	Returns : float -- the current Player acceleration based on various factors
	"""
	## Normal Player-on-foot gravity
	if f_is_grounded:
		if f_is_crouching:
			return acceleration_grnd.val * 0.3 # If crouching, accelerate slower
		return acceleration_grnd.val
	else:
		return acceleration_air.val

func get_friction() -> float:
	"""
	Returns : float -- the current Player friction based on various factors
	"""
	if f_is_grounded:
		if curr_direction:
			return friction_grnd_lesser.val
		return friction_grnd_greater.val
	else:
		return friction_air.val

func get_gravity(context : BodyState = BodyState.DEFAULT) -> float:
	"""
	context : BodyState = BodyState.DEFAULT -- depending on what the Player is doing
	
	Returns : float -- the current Player gravity based on various factors
	"""
	# If GRAVITY is currently turned off, return 0 for gravity 
	if not f_apply_gravity:
		return 0.0
	
	var multiply_gravity_on_rising : float = 3.0 # When NOT holding jump key, jump is shorter, and so gravity is larger
	match context:
		BodyState.SHIELDGLIDE:
			if f_is_rising:
				return gravity_during_jump.val * multiply_gravity_on_rising * get_physics_process_delta_time()
			else: # During Cyarm-Shieldgliding, fall slower
				return fall_gravity_during_shieldglide.val
	
		# Default
		_:
			if f_is_rising:
				# Holding down jump button, Player rises to peak jump_height, else short tap is smaller jump
				if f_do_variable_jump and f_butt_jump_holding:
					multiply_gravity_on_rising = 1.0
				return gravity_during_jump.val * multiply_gravity_on_rising * get_physics_process_delta_time()

			else: # Player falling
				return gravity_during_fall.val * get_physics_process_delta_time()

func get_close_to_ground_distance() -> float:
	"""
	Returns : float -- the distance from Player feet to ground
	"""
	if f_is_grounded:
		return 0.0 # No need to check raycasts if Player is already grounded

	var _dist_to_ground : float = 99999
	# For each grounded raycast, get the minimum distance
	if c_raycast_lastgroundedpos.is_colliding():
		_dist_to_ground = min(_dist_to_ground,
							  abs(c_raycast_lastgroundedpos.get_collision_point().y - global_position.y))
	if c_raycast_below_left.is_colliding():
		_dist_to_ground = min(_dist_to_ground,
							  abs(c_raycast_below_left.get_collision_point().y - global_position.y))
	if c_raycast_below_right.is_colliding():
		_dist_to_ground = min(_dist_to_ground,
							  abs(c_raycast_below_right.get_collision_point().y - global_position.y))

	return _dist_to_ground

func is_close_to_wall() -> bool:
	"""
	Returns : bool -- whether or not Player is close enough to a wall (for a wall jump)
	"""
	return c_raycast_walljump.is_colliding()

func is_close_to_ground() -> bool:
	"""
	Returns : bool -- whether or not Player is "close" to the ground
	"""
	if f_is_grounded:
		return true # No need to check raycasts if Player is already grounded

	# Player is close to ground if the smallest distance to ground less than close_to_ground_leeway
	return get_close_to_ground_distance() <= close_to_ground_leeway

func player_fits_at(check_pos : Vector2) -> bool:
	"""
	Checks if there is enough space at position for Player
	
	check_pos : Vector2 -- position to check Player at

	Returns : bool -- whether Player would collide with terrain at supposed position
	"""
	# Adjust shapecast pos, since pivot for shapecast is in middle, while Player pivot is at bottom of collider
	c_shapecast_playerfits.global_position = check_pos - Vector2(0, c_collider.shape.size.y / 2)
	c_shapecast_playerfits.force_shapecast_update()
	return not c_shapecast_playerfits.is_colliding()

func dist_to_cyarm(use_midpos : bool = true) -> float:
	"""
	Returns : float -- the distance from Player to Cyarm
	
	use_midpos : bool -- whether to use the Player's middle pos in calculation instead of global_position
	"""
	var _start_pos : Vector2 = mid_global_position if use_midpos else global_position
	return _start_pos.distance_to(Globals.cyarm_pos)

######################
## Movement Functions
######################
func override_vel(new_velocity : Vector2, modifier : float = 1.0) -> void:
	"""
	Overrides the old velocity with new value pair
	
	new_velocity : Vector2 -- new velocity
	modifier : float -- scalar to modify velocity with
	"""
	velocity = new_velocity * modifier
	
func override_vel_x(new_velocity_x : float) -> void:
	"""
	Overrides the old x velocity with new value
	
	new_velocity_x : float -- new horizontal velocity
	"""
	velocity.x = new_velocity_x
	
func override_vel_y(new_velocity_y : float) -> void:
	"""
	Overrides the old y velocity with new value
	
	new_velocity_y : float -- new horizontal velocity
	"""
	velocity.y = new_velocity_y
	
func add_vel(vel_to_add : Vector2) -> void:
	"""
	Adds some value pair to the current velocity
	
	vel_to_add : Vector2 -- value pair to add to the current velocity
	"""
	velocity += vel_to_add

func calc_vel_x() -> void:
	"""
	Calculates Player horizontal movement (velocity.x) this frame
	"""
	# Slow Player down by friction
	override_vel_x(move_toward(velocity.x, 0.0, get_friction()))

	### Pressing run button
	if curr_direction:
		## On ground
		if f_is_grounded:
			# Changing direction (current velocity has opposide sign to current direction)
			if Utilities.opposite_sign(curr_direction, velocity.x):
				# Make it less slide-y when moving in opposite direction
				add_vel(Vector2(get_friction() * 3.6 * left_or_right, 0))
			else:
				if f_is_crouching:
					if not c_raycast_stillstanding_on_ledge.is_colliding():
						# Prevent Player from moving off of edges while crouching
						override_vel_x(0.0)
						return # Return so Player doesn't acclerate normally
					else:
						# Move at a CONSTANT (slow) speed while crouching
						override_vel_x(curr_direction * max_speed.val * 0.3)
						return # Return so Player doesn't acclerate normally

		# Accelerate towards top speed on ground / air
		override_vel_x(move_toward(velocity.x, curr_direction * max_speed.val, get_acceleration()))

func calc_vel_y() -> void:
	"""
	Calculates Player vertical movement (velocity.y) this frame
	"""
	## Wall slide & ledge up
	calc_walling_ledging()
	if f_is_ledgeupping:
		return # Decided to move-on-rails so ignore any following calculations
	
	### Fall speed
	if not f_is_grounded:
		if f_is_wallsliding:
			# During wallslide, fall slower than gravity
			override_vel_y(wall_slide_speed.val)
		else:
			# Falling by gravity
			add_vel(Vector2(0, get_gravity()))

	## Terminal fall velocity
	if velocity.y > max_fall_speed.val:
		override_vel_y(max_fall_speed.val)

	## Crouching
	if f_crouch_holding:
		crouch()
	elif f_crouch_just_released:
		uncrouch()

	## Jumping
	calc_jumping()

func calc_jumping() -> bool:
	"""
	Returns : bool -- whether or not Player jumped
	"""
	if (
			f_is_grounded or
			is_close_to_wall()
		):
		# Player can always jump when grounded/onwall
		f_can_jump = true
		f_can_coyote = true
	elif f_can_coyote:
		# On FIRST frame after Player leaves ground/wall, start coyote timer
		f_can_coyote = false
		c_timer_coyote.start() # On timeout, sets f_can_jump to false

	# Jump
	var _player_jumped = false
	if f_jump_buffer_active:
		## Do jump
		if (
			f_can_jump
			):
			jump()
			f_do_variable_jump = true # Player normal jump, allow variable jump height
			_player_jumped = true

	return _player_jumped

func begin_jump_buffer() -> void:
	"""
	Starts the jump buffer timer
	"""
	c_timer_jumpbuffer.start()

func jump(modifier : float = 1.0, do_anim : bool = true) -> void:
	"""
	Calculates Player jump velocity

	modifier : float -- multiplier of jump velocity, where 1.0 is normal jump
	do_anim : bool = true -- whether or not to display FX for jump
	"""
	var _jump_vel = Vector2.ZERO # Velocity of jump

	## Horizontal jump (wall jump, x velocity)
	if (
			not f_is_ledgeupping
			and
			(
				f_is_wallsliding # Moving into a wall
				or
				(not f_is_grounded and is_close_to_wall()) # Close enough to a wall
			)
		):
		var _dir_away_from_wall : int = -1 * left_or_right
		_jump_vel.x = jump_initial_speed.val * _dir_away_from_wall * modifier # Override x velocity

		# Set last "grounded" pos as wall jump pos
		o_lastgroundedbundle.set_on_wall_pos(c_raycast_walljump.get_collision_point())

	## Vertical jump (y velocity)
	_jump_vel.y = -1 * jump_initial_speed.val * modifier # Override y velocity
	
	# Modify Player velocity
	if _jump_vel.x: override_vel_x(_jump_vel.x) # Only override x velocity if wall jump
	override_vel_y(_jump_vel.y)

	jump_after(do_anim)
	return

func jump_after(do_anim : bool = true) -> void:
	"""
	Sets flags and velocity after calculating jump
	
	do_anim : bool = true -- whether or not to display FX for jump
	"""
	if do_anim:
		f_a_just_jumped = true # Flag for animation
	
	# Jump variable cleanup
	f_can_jump = false
	c_timer_jumpbuffer.stop()

func bump_up() -> void:
	"""
	Add velocity to move Player up a little
	"""
	override_vel_y(-1 * bump_initial_speed.val)

func calc_lastgrounded_pos() -> void:
	"""
	Calculates the last position where the Player was grounded (for spawning dust and such)
	"""
	## Also has checks in jump() and ledgeup()
	
	## Checks for "grounded" position on wall
	if f_is_wallsliding:
		o_lastgroundedbundle.set_on_wall_pos(c_raycast_walljump.get_collision_point())

	## Checks on ground
	elif f_is_grounded:
		# Middle ray colliding
		if c_raycast_lastgroundedpos.is_colliding():
			o_lastgroundedbundle.set_on_ground_pos(c_raycast_lastgroundedpos.get_collision_point())
		else:
			## Now check for grounded, but middle ray NOT colliding	
			var _check_left : bool = c_raycast_below_left.is_colliding()
			if _check_left and c_raycast_below_right.is_colliding():
				# The higher y collision (up is less) is the grounded y position
				_check_left = c_raycast_below_left.get_collision_point().y < c_raycast_below_right.get_collision_point().y

			var _ledge_x : float
			var _ledge_y : float
			if _check_left:
				# Leftest ray colliding, so Player on ledge that drops to
				# the right, so use the raycast starting from the right
				_ledge_x = c_raycast_ledge_right.get_collision_point().x
				_ledge_y = c_raycast_below_left.get_collision_point().y
			else: # check_right
				# Rightest ray colliding, so Player on ledge that drops to
				# the left, so use the raycast starting from the right
				_ledge_x = c_raycast_ledge_left.get_collision_point().x
				_ledge_y = c_raycast_below_right.get_collision_point().y

			o_lastgroundedbundle.set_on_ground_pos(Vector2(_ledge_x, _ledge_y))

func calc_walling_ledging() -> void:
	"""
	Calculates whether Player is wall sliding or ledge upping
	"""
	### Check wallsliding (moving into a wall, while falling)
	if (
				is_close_to_wall() and curr_direction and f_is_falling
			and
				not f_is_crouching
		):
		f_is_wallsliding = true
	else:
		f_is_wallsliding = false

	### Check ledgeupping
	if ( # Horizontal ledgeup
				curr_direction
			and
				not (f_is_crouching and f_is_grounded) # Not crouched and grounded
			and 
				not c_raycast_eye.is_colliding() and c_raycast_ledgesurface.is_colliding() # Ledge-uppable ledge is near
			and
				not (f_butt_jump_holding and velocity.y < -60) # Prevent ledgeup-cancel out of a jump
		):
		ledgeup(false, true)
	elif ( # Vertical ledgeup
			f_butt_jump_holding and
			f_cyarm_shield_overlapping and
			cyarm_shield_ref.shield_has_top_clearance(height) # Enough space to fit Player
		):
		# Cyarm-Shield is near and holding jump button
		ledgeup(true, false)

	if not o_move_onrails.is_to_target():
		# Once Player has finished moving-on-rails, ledgeup is finished
		f_is_ledgeupping = false

func ledgeup(is_cyarm_shield : bool = false, require_move_into_ledge : bool = false) -> void:
	"""
	Calculates the Player move atop ledge, starts a move-on-rails to that position
	
	is_shield : bool -- whether the ledge is Cyarm-Shield or Terrain
	require_move_into_ledge : bool -- whether ledge up action accounts for Player currently moving in direction
	"""
	## Calculate position to ledgeup to
	var _ledge_pos : Vector2 = Vector2(0, -1) # Make sure ledge up target is 1 pixel above the surface
	if is_cyarm_shield:
		_ledge_pos += cyarm_shield_ref.shield_get_ledgeup_pos()
	else:
		_ledge_pos += c_raycast_ledgesurface.get_collision_point()
	
	## Check if there is enough space above ledge to ledgeup to
	if not player_fits_at(_ledge_pos):
		# Not enough space for Player to ledgeup, so return
		return
	else:
		# Set last grounded position to ledgeup position
		o_lastgroundedbundle.set_on_ground_pos(_ledge_pos + Vector2(0, 1)) # 1 pixel back to surface

	var _ledge_dir : int = sign((_ledge_pos - global_position).x) # Direction of ledge (left or right, -1 or 1)
	var _ledge_y_dist : float = abs(global_position.y - _ledge_pos.y) # Vertical distance to ledge
	var _ledge_up_speed : float = global_position.distance_to(_ledge_pos) / ledgeup_duration.val # Time based ledgeup
	
	if _ledge_y_dist <= corner_leeway_y:
		# Don't bother ledging up if distance is small enough to be handled by corner_correction() anyway
		return
	elif _ledge_y_dist < half_height:
		# Speed up ledge up if distance to the ledge is short
		_ledge_up_speed *= 1.6
	
	if not f_moving_onrails:
		var _vel_to_restore : Vector2
		var _vel_y : float = 0.0 if velocity.y > 0 else velocity.y # Don't restore positive y vel, which would be a sudden drop after ledgeupping
		if require_move_into_ledge:
			# Horizontal ledgeup
			# Only ledgeup if the ledge is in the SAME direction as Player current movement
			if curr_direction == _ledge_dir:
				# After ledgeup, set Player horizontal velocity to max run speed
				_vel_to_restore = Vector2(max_speed.val * curr_direction, _vel_y)
				o_move_onrails.begin_to_target(_ledge_pos, _ledge_up_speed,
											   curr_direction, _vel_to_restore)
		else:
			# Vertical ledgeup
			# After ledgeup, set Player horizontal velocity to current run speed
			_vel_to_restore = Vector2(velocity.x, _vel_y)
			o_move_onrails.begin_to_target(_ledge_pos, _ledge_up_speed,
										   curr_direction, Vector2.ZERO)

	f_is_ledgeupping = true

func crouch() -> void:
	"""
	Player crouch
	"""
	f_is_crouching = true

func uncrouch() -> void:
	"""
	Player release crouch
	"""
	f_is_crouching = false

func dash(
			dash_type : MoveOnRails.RAIL_TYPE,
			_dash_to_pos : Vector2 = Vector2.ZERO,
			_dash_dir : Vector2 = Vector2.ZERO,
			_dash_speed : float = dash_speed.val,
			_dash_distance : float = dash_distance,
			_vel_to_restore = Vector2.ZERO,
		) -> void:
	"""
	Player dash, sets up MoveOnRails object
	
	dash_type : MoveOnRails.RAIL_TYPE -- the type of dash to perform
	_dash_to_pos : Vector2 -- the position to dash to
	_dash_dir : Vector2 = Vector2.ZERO -- the direction of dash
	_dash_speed : float = dash_speed.val -- the speed of dash
	_dash_distance : float = dash_distance -- the distance of dash
	"""
	## On default, calculate dash position as direction towards mouse position
	if _dash_dir == Vector2.ZERO:
		_dash_dir = (Globals.mouse_pos - mid_global_position).normalized()

	## Change Player current direction to face towards (horizontal) dash direction
	var _facing_dir = sign(_dash_dir.x)
	curr_direction = _facing_dir
	
	## Calculate position to dash to
	if _dash_to_pos == Vector2.ZERO:
		_dash_to_pos = global_position + (_dash_dir * _dash_distance)
	
	match dash_type:
		MoveOnRails.RAIL_TYPE.TO_TARGET:
			o_move_onrails.begin_to_target(_dash_to_pos, _dash_speed, _facing_dir, _vel_to_restore)
		MoveOnRails.RAIL_TYPE.FOR_DISTANCE:
			o_move_onrails.begin_for_distance(_dash_dir, _dash_distance, _dash_speed, _facing_dir, _vel_to_restore)
	
	c_timer_coyote.stop() # Cancel coyote time, which may allow Player to jump in mid-air after dashing far from the ground
	f_can_jump = false
	f_is_dashing = true

func swordslash(do_swordslashing : bool) -> void:
	"""
	Cyarm-Sword Slash
	
	do_swordslashing : bool -- whether to begin or to cancel swordslash
	"""
	# Begin Sword Slash
	if do_swordslashing:
		velocity = Vector2.ZERO # Reset velocity
		f_freeze_movement = true # Freeze Player
		c_timer_swordslash_freeze.start() # Unfreeze after a little time
	
	# End Sword Slash
	else:
		pass
	
	# Set flag
	f_is_swordslashing = do_swordslashing

func swordiai(do_swordiaiing : bool) -> void:
	"""
	Cyarm-Sword Iai
	
	do_swordiaiing : bool -- whether to begin or to cancel swordiai
	"""
	# Begin Sword Iai
	if do_swordiaiing:
		sig_world_dim.emit(true) # Dim World
		
		# Slow Player down to a stop, then signal the spawn of SwordIaiStop, which stops time
		f_do_spawn_swordaiaistop = true
		var tween = get_tree().create_tween()
		tween.tween_property(self, 'velocity', Vector2.ZERO, 0.15)
		tween.tween_callback(self.swordiai_SwordIaiStop_spawn)
		
		f_freeze_movement = false # Allow Player to dash

		sword_iai_curr_state = SwordIaiState.READY
	# Cancel Sword Iai
	else:
		sig_cyarm_swordiai_finish.emit() # Signal Cyarm-Sword to end iai
		f_freeze_movement = false # Stop Player hang time
		sword_iai_curr_state = SwordIaiState.DONE

	# Set flag
	f_is_swordiaiing = do_swordiaiing

func swordiai_SwordIaiStop_spawn() -> void:
	"""
	Spawns a SwordIaiStop, which stops time during Sword Iai, and captures input for the cut
	"""
	# If Sword Iai hasn't been canceled before tween ended
	if f_do_spawn_swordaiaistop:
		sig_cyarm_swordiai_SwordIaiStop_spawn.emit(mid_global_position)

func swordiai_cut(end_pos : Vector2, distance : float) -> void:
	"""
	Cyarm-Sword Iai cut
	
	end_pos : Vector2 -- position of cut end
	distance : float -- length of cut
	"""
	## Cancel spawn of SwordIaiStop
	f_do_spawn_swordaiaistop = false
	
	## Make Player invincible during the dash
	f_invincible = true
	
	## Calculate and begin dash
	var _player_to_iai_end_dir : Vector2 = (end_pos - mid_global_position).normalized()
	dash(MoveOnRails.RAIL_TYPE.FOR_DISTANCE, Vector2.ZERO,
		_player_to_iai_end_dir, sword_iai_speed.val,
		distance, Vector2.ZERO)
		
	sword_iai_curr_state = SwordIaiState.CUT

func swordiai_cut_after() -> void:
	"""
	After Sword iai cut
	"""
	sig_world_dim.emit(false) # Undim World
	sig_player_swordiai_ended_cut.emit() # Signal that Player has reached end of cut
	
	# Give Player a bit of hang time after pull
	f_freeze_movement = true

	# Make Player vulnerable after the dash
	f_invincible = false
	
	sword_iai_curr_state = SwordIaiState.AFTER_CUT

func spearbroom(do_spearbrooming : bool) -> void:
	"""
	Cyarm-Spearbrooming
	
	do_spearbrooming : bool -- whether to begin or to cancel spearbrooming
	"""
	# Begin Spearbrooming
	if do_spearbrooming:
		# Hide Cyarm-Sword
		sig_cyarm_hide.emit(true)
		
		f_is_spearbrooming = true

	# Cancel Spearbrooming
	else:
		# Show Cyarm-Sword
		sig_cyarm_hide.emit(false)

		f_is_spearbrooming = false

func spearbroom_calc_dir() -> void:
	"""
	Calculates the direction of Player's spearbrooming direction (spearbrooming_dir), pointing
	towards mouse position
	"""
	# Unit vector that points towards mouse
	var _forward : Vector2 = Vector2.RIGHT.rotated(get_angle_to_mouse())
	# Unit vector that points perpendicular to _forward
	var _up : Vector2 = Vector2(_forward.y, -1 * _forward.x) # clockwise (y, -x)
	
	# Some debugging lines
	#var _down : Vector2 = Vector2(-1 * _forward.y, _forward.x) # counterclockwise (-y, x) 
	#var _mid : Vector2 = mid_global_position
	#DebugDraw.add_debug_line("forward", _mid, _mid + _forward * 30, Color.RED, 2)
	#DebugDraw.add_debug_line("up", _mid, _mid + _up * 20, Color.ROYAL_BLUE, 1)
	#DebugDraw.add_debug_line("down", _mid, _mid + _down * 20, Color.HOT_PINK, 1)
	#DebugDraw.add_debug_line("spearbrooming_dir", _mid, _mid + spearbrooming_dir * 20, Color.GREEN_YELLOW, 1)

	## Check which direction Player should head towards
	# If direction to mouse points behind last frame's spearbrooming dir, Player should flip around
	var _points_behind : bool = spearbrooming_dir.dot(_forward) < 0
	if _points_behind:
		spearbrooming_dir = _forward # Flip to point towards mouse

	# If direction to mouse and spearbrooming current direction are both pointing similar directions
	else:
		# If direction to mouse points above Player last frame dir, Player should head up
		var _points_down : bool = spearbrooming_dir.dot(_up) < 0
		if _points_down:
			spearbrooming_dir = _forward.rotated(-1 * spearbrooming_rot) # Player should head up
		else:
			spearbrooming_dir = _forward.rotated(spearbrooming_rot) # Player should head down

func spearbroom_calc_vel() -> void:
	"""
	Calculates the velocity of Player this physics frame, to move towards mouse position
	"""
	## If NOT enough electro, slow Player down by friction
	if not Globals.EM_curr_electro > 0.0:
		calc_vel_x()
		calc_vel_y()
	
	## If enough electro, add speed towards mouse position
	else:
		# Adjust spearbrooming speed to scale faster the further the mouse gets from Player
		max_speed_spearbrooming.val = Utilities.map(
														clampf(canvas_dist_to_mouse, 0, 100),
														0, 100, # Achieves max spearbrooming speed at 100 units away
														0, max_speed_spearbrooming.CONST
													)
		# Set velocity
		override_vel(spearbrooming_dir * max_speed_spearbrooming.val)

func speartether(do_speartether : bool) -> void:
	"""
	Cyarm-Speartethering
	
	do_speartether : bool -- whether to begin or to cancel speartether
	"""
	## On speartether BEGIN
	if do_speartether:
		# Show tether
		c_line_spear_tether.visible = true
		
		# Set anchor (pivot) position as Cyarm-Spear position (Player acts as pendulum)
		# Set pendulum length (radius) as distance to Spear
		speartether_anchor_pos = Globals.cyarm_pos
		speartether_length = global_position.distance_to(speartether_anchor_pos)
		
		# Angle between UP vector, and vector pointing from Player to Cyarm-Spear
		speartether_angle = (speartether_anchor_pos - global_position).angle_to(Vector2.UP)
		
		# Set max speed / acceleration based on tether length (so velocity doesn't get out of hand)
		speartether_max_angle_speed.set_both(speartether_max_tangential_speed.val / speartether_length)
		speartether_nudge_acceleration.set_both(speartether_max_angle_speed.val / 44)
		
		# Start with some angular velocity based on current velocity
		if curr_direction:
			speartether_angle_speed = speartether_nudge_acceleration.val * curr_direction * velocity.length()
		
		# Set speartethering flag
		f_is_speartethering = true

		DebugDraw.add_debug_arc("speartethercircle", speartether_anchor_pos, speartether_length, 0, 2*PI, 100, Color.WHITE, 1.0, false)

	## On speartether END
	else:
		# Hide tether
		c_line_spear_tether.clear_points()
		c_line_spear_tether.visible = false
		
		# Calculate launch velocity (speed to set Player after letting go of tether)
		var _tangential_speed = velocity.length()
		var _tangential_dir : Vector2 = speartether_calc_tangential_dir()
		override_vel(_tangential_dir * _tangential_speed) # Set launch velocity

		# Have camera focus back on Player
		sig_cameraMgr_follow_node.emit(self)
		
		# Cancel speartethering flag
		f_is_speartethering = false

func speartether_calc_tangential_dir() -> Vector2:
	"""
	Calculates the tangential direction of the Player this physics frame on the pendulum swing
	"""
	var _spear_to_player_dir : Vector2 = (speartether_anchor_pos - global_position).normalized()
	var _is_counter_clockwise : bool = speartether_angle_speed > 0
	var _tangential_dir : Vector2 = Utilities.get_2d_perpendicular_vect(_spear_to_player_dir, _is_counter_clockwise)
	if get_slide_collision_count() > 0:
		# If Player is sliding along floor/wall instead of in the arc of pendulum, change tangential_dir to point in direction
		# of the floor/wall, so that there is no "wasted" velocity into the floor/wall
		var _normal : Vector2 = get_slide_collision(0).get_normal()
		_tangential_dir = Utilities.get_2d_perpendicular_vect(_normal, _is_counter_clockwise)
	
	return _tangential_dir

func speartether_calc_vel() -> void:
	"""
	Calculates the velocity of Player this physics frame, to do pendulum-like movement towards Cyarm-Spear
	
	Formula for angular acceleration of pendulum (https://www.myphysicslab.com/pendulum/pendulum-en.html):
		α = -g/R * sin(θ)
		where:
			α is the angular acceleration of the pendulum
			g is the acceleration due to gravity
			R is the length of the pendulum
			θ is the angle of the pendulum from the VERTICAL direction
	"""
	# Calculate angular velocity
	if curr_direction and Globals.EM_curr_electro > 0.0:
		# If Player is holding a directional key, and has electro, rotate pendulum in that direction
		speartether_angle_speed += speartether_nudge_acceleration.val * curr_direction
	else:
		# If Player is not holding a directional key, rotate pendulum based on gravity
		speartether_gravity_acceleration.set_both( ((-1 * get_gravity()) / speartether_length) * sin(speartether_angle) )
		speartether_angle_speed += speartether_gravity_acceleration.val

	# Clamp angular velocity
	speartether_angle_speed = clampf(speartether_angle_speed, -1 * speartether_max_angle_speed.val, speartether_max_angle_speed.val)
	speartether_angle_speed *= speartether_damping # Lose "momentum" over time
	if abs(speartether_angle_speed) < 0.0001 * Globals.time_scale: speartether_angle_speed = 0 # Throw away miniscule jitter

	# Set angle of pendulum based on velocity
	speartether_angle += speartether_angle_speed

	# Calculate the position this physics frame that pendulum (Player) should be based on angle
	var _next_pos = (
						speartether_anchor_pos + Vector2(speartether_length * sin(speartether_angle),
														 speartether_length * cos(speartether_angle))
						)
	
	# Set Player velocity to move to calculated position in a single frame
	override_vel((_next_pos - global_position) / get_physics_process_delta_time() * Globals.time_scale)

func sickleswing(do_sickleswing : bool, sickle_pos : Vector2, add_tangential_vel : bool = true) -> void:
	"""
	Cyarm-Sickleswing
	
	do_sickleswing : bool -- whether to begin or to cancel sickleswing
	sickle_pos : Vector2 -- global_position of Sickle
	add_tangential_vel : bool = true -- whether or not to launch Player after sickleswing is done
	"""
	## On sickleswing BEGIN
	if do_sickleswing:
		# Set anchor (pivot) position as Cyarm-Sickle position (Player acts as pendulum)
		# Set pendulum length (radius) as distance to Sickle
		sickleswing_anchor_pos = sickle_pos
		sickleswing_length = global_position.distance_to(sickleswing_anchor_pos) * 0.75 # A little shorter, to pull Player towards
		
		# Angle from Cyarm-Sickle to Player
		sickleswing_angle = sickleswing_anchor_pos.angle_to_point(global_position)

		# First position of pendulum swing
		sickleswing_next_pos = (
								sickleswing_anchor_pos + Vector2(sickleswing_length * cos(sickleswing_angle),
															 	 sickleswing_length * sin(sickleswing_angle),
															 	)
								)
		DebugDraw.add_debug_point("sickleswingendpos", sickleswing_next_pos, Color.YELLOW, 3)

		# Start with some angular velocity based on current velocity
		sickleswing_curr_angle_speed = curr_direction * Vector2(velocity.x, velocity.y / 6).length() * -0.0002
		
		# Start a timer that prevents Player from doing pendulum motion for a little bit
		c_timer_sickle_time_before_swing.start()
		
		# Have camera focus on the pivot point
		sig_cameraMgr_follow_pos.emit(Globals.cyarm_pos)
		
		# Set sickleswing flag
		f_is_sickleswinging = true

		DebugDraw.add_debug_arc("sickleswingcircle", sickleswing_anchor_pos, sickleswing_length, 0, 2*PI, 100, Color.WHITE, 1.0, false)

	## On speartether END
	else:
		# Calculate launch velocity (speed to set Player after letting go of tether)
		if add_tangential_vel:
			var _tangential_speed = velocity.length() * 1.1
			var _tangential_dir : Vector2 = sickleswing_calc_tangential_dir()
			override_vel(_tangential_dir * _tangential_speed) # Set launch velocity
		else:
			override_vel(Vector2.ZERO)

		# Have camera focus back on Player
		sig_cameraMgr_follow_node.emit(self)
		
		# Cancel sickleswing flag
		f_is_sickleswinging = false

func sickleswing_calc_vel() -> void:
	"""
	Calculates the velocity of Player this physics frame, to do pendulum-like movement around Cyarm-Sickle
	"""
	if not c_timer_sickle_time_before_swing.is_stopped():
		# Move Player towards beginning of pendulum arc
		override_vel(
						(sickleswing_next_pos - global_position).normalized()
						* (global_position.distance_to(sickleswing_next_pos) / c_timer_sickle_time_before_swing.wait_time)
					)
		return # For a bit of time, disallow Player from doing pendulum motion (to better line up sickle pulls)
	
	var _ang_accel = 0.01 * cos(sickleswing_angle) # Using cosine, the greatest simulated "gravity" at 0 and 180 degrees
	
	if curr_direction:
		# Increase acceleration if Player is holding a directional key
		_ang_accel += curr_direction * -0.002
	
	_ang_accel = _ang_accel
	
	sickleswing_curr_angle_speed += _ang_accel # Acclerate swing speed
	
	sickleswing_angle += sickleswing_curr_angle_speed # Update new angle by amount of radians moved this frame
	sickleswing_curr_angle_speed *= sickleswing_damping # Damping (simulate pendulum coming to rest)

	# Calculate the position this physics frame that pendulum (Player) should be based on angle
	sickleswing_next_pos = (
							sickleswing_anchor_pos + Vector2(sickleswing_length * cos(sickleswing_angle),
														 	 sickleswing_length * sin(sickleswing_angle),
														 	)
							)
	
	# Set Player velocity to move to calculated position in a single frame
	override_vel((sickleswing_next_pos - global_position) / get_physics_process_delta_time())

	DebugDraw.add_debug_point("sickleswingendpos", sickleswing_next_pos, Color.YELLOW, 3)
	DebugDraw.add_debug_point("sickleswinganchor", sickleswing_anchor_pos, Color.RED, 3)

func sickleswing_calc_tangential_dir() -> Vector2:
	"""
	Calculates the tangential direction of the Player this physics frame on the pendulum swing
	"""
	var _sickle_to_player_dir : Vector2 = (global_position - sickleswing_anchor_pos).normalized()
	var _is_counter_clockwise : bool = sickleswing_curr_angle_speed > 0
	var _tangential_dir : Vector2 = Utilities.get_2d_perpendicular_vect(_sickle_to_player_dir, _is_counter_clockwise)
	if get_slide_collision_count() > 0:
		# If Player is sliding along floor/wall instead of in the arc of pendulum, change tangential_dir to point in direction
		# of the floor/wall, so that there is no "wasted" velocity into the floor/wall
		var _normal : Vector2 = get_slide_collision(0).get_normal()
		_tangential_dir = Utilities.get_2d_perpendicular_vect(_normal, _is_counter_clockwise)
	
	return _tangential_dir

func sicklepull(sicklepull_type : CyarmSickle.SicklePull, sickle_stuck_target : Node2D) -> void:
	"""
	Cyarm-Sicklepull
	
	sicklepull_type : SicklePull -- the type of pull to do, either pull Player to Target, or Target to Player
	sickle_stuck_target : Node -- what Node is the Sickle stuck in
	"""
	if sicklepull_type == curr_sicklepull_type:
		# If already sicklepulling or cancelled, don't set attributes again
		return

	## Camera control
	if sicklepull_type != CyarmSickle.SicklePull.END_PULL:
		# Have camera focus on the the Sickle pull target
		sig_cameraMgr_follow_pos.emit(Globals.cyarm_pos)
	else:
		# Have camera focus back on Player
		sig_cameraMgr_follow_node.emit(self)
		
	## Pull decision
	match sicklepull_type:
		CyarmSickle.SicklePull.PLAYER_TO_TARGET:
			# Direction from Player to Target
			sicklepull_towards_dir = (Globals.cyarm_pos - mid_global_position).normalized() 
			
			# Change Player current direction to face towards (horizontal) pull direction
			curr_direction = sign(sicklepull_towards_dir.x)
			
			# Start Player with initial speed towards Target
			override_vel(sicklepull_towards_dir * sicklepull_initial_speed.val)
			
			# Lock target in place
			if Utilities.is_sicklepullable(sickle_stuck_target):
				sickle_stuck_target.sicklepull_me(Vector2.ZERO)
			
			f_is_sicklepulling = true
			f_a_just_sicklepulled = true

		CyarmSickle.SicklePull.TARGET_TO_PLAYER:
			if Utilities.is_sicklepullable(sickle_stuck_target):
				# If Target can be moved, add some initial velocity
				sicklepull_towards_dir = (mid_global_position - Globals.cyarm_pos).normalized() # Direction from Target to Player
				sickle_stuck_target.sicklepull_me(sicklepull_towards_dir * sicklepull_target_initial_speed.val)
				f_is_sicklepulling = true
				f_a_just_sicklepulled = true

			else:
				# If Target cannot be moved, then cancel trying to pull target to Player
				sicklepull(CyarmSickle.SicklePull.END_PULL, sickle_stuck_target)

		CyarmSickle.SicklePull.END_PULL:
			# End Sickle pull
			f_is_sicklepulling = false
			sig_cyarm_sicklepull_cancel.emit() # Signal Cyarm Sickle to cancel pull
			
			# Give Player a bit of hang time after pull
			f_apply_gravity = false
			c_timer_sicklepull_hangtime.start()
			
			if Utilities.is_sicklepullable(sickle_stuck_target):
				sickle_stuck_target.sicklepull_end(true) # Reenable friction/gravity on target
	
	### Assign attributes after matching Sickle pull decision
	sicklepull_target = sickle_stuck_target
	curr_sicklepull_type = sicklepull_type

func sicklepull_calc_vel() -> void:
	"""
	Calculates the velocity of Player during Sickle pull, to give hang time to Player after pulling to target, or
	pulling target to Player
	"""
	var _sicklepull_curr_towards_dir : Vector2 # Current direction Target or Player is being pulled towards

	if sicklepull_target: # Target is valid, and pull is not ended
		match curr_sicklepull_type:
			CyarmSickle.SicklePull.PLAYER_TO_TARGET:
				# Current direction
				_sicklepull_curr_towards_dir = (Globals.cyarm_pos - mid_global_position).normalized()
				
				# Update Player velocity
				add_vel(sicklepull_towards_dir * sicklepull_acceleration.val)
				
			CyarmSickle.SicklePull.TARGET_TO_PLAYER:
				# Current direction
				_sicklepull_curr_towards_dir = (mid_global_position - Globals.cyarm_pos).normalized()

				# Slow Player down to a stop
				override_vel(velocity.move_toward(Vector2.ZERO, sicklepull_decceleration.val))
				
				# Update target velocity
				sicklepull_target.sicklepull_me(sicklepull_towards_dir * sicklepull_target_acceleration.val)
				
		# Negative dot product, which means pointing in OPPOSITE directions, which means Target/Player has passed Player/Target
		var _passed_dot : float = sicklepull_towards_dir.dot(_sicklepull_curr_towards_dir)
		if _passed_dot < 0:
			sicklepull(CyarmSickle.SicklePull.END_PULL, sicklepull_target) # Cancel pull

func shieldslide(do_shieldslide : bool, on_press : bool) -> void:
	"""
	Cyarm-Shield Slide (speed up along the ground, get launched on enemy collision)
	
	do_shieldslide : bool -- whether to begin or to cancel shieldslide
	on_press : bool -- whether or not shield slide was initiated on action press (rather than hold)
	"""
	if do_shieldslide == f_is_shieldsliding:
		# If already shieldsliding or cancelled, don't set attributes again
		return
	
	## On shieldslide BEGIN
	if do_shieldslide:
		shieldslide_dir = left_or_right # Slide only happens in one direction
		
		# If shield slide was initiated on action button press (rather than hold), then allow Player to fall
		f_shieldslide_do_fall = true if on_press else false
		c_area_shieldslide.monitoring = true # Allow Player to slide into Enemy to jump up
		f_is_shieldsliding = true
	
	## On shieldslide END
	else:
		# Set flags
		f_shieldslide_do_fall = false
		c_area_shieldslide.set_deferred("monitoring", false)
		f_is_shieldsliding = false
		
		sig_cyarm_shieldslide_cancel.emit() # Signal Cyarm-Shield to cancel Shield slide

func shieldslide_calc_vel() -> void:
	"""
	Calculates the velocity of Player this physics frame, to fall down, then slide against the ground
	"""
	# Once first landed, make starting x velocity a factor of fall velocity
	if f_shieldslide_do_fall and f_is_grounded:
		override_vel_x(max_speed.val * shieldslide_dir)
	
	## Slide against the ground
	if f_is_grounded:
		# Accelerate towards top speed
		var _acceleration : float = shieldslide_accel_default.val
		if curr_direction and left_or_right == shieldslide_dir:
			# If Player pressing in direction, accelerate FASTER towards top speed
			_acceleration = shieldslide_accel_pressing.val
		override_vel_x(move_toward(velocity.x, shieldslide_dir * max_speed_shieldsliding.val, _acceleration))
		
		# Don't immediately plummet off ledges, unless Player presses Shield slide action again
		f_shieldslide_do_fall = false
		
	## Fall down
	else:
		if f_shieldslide_do_fall:
			## Fall fast
			override_vel_x(move_toward(velocity.x, 0.0, shieldslide_friction.val)) # Quickly remove Player horizontal movement
			override_vel_y(move_toward(velocity.y, max_fall_speed_shieldsliding.val, gravity_during_shieldsliding.val)) # Fall towards terminal velocty
		else:
			## Fall normally
			add_vel(Vector2(0, get_gravity()))
			if velocity.y > max_fall_speed.val: # Terminal fall velocity
				override_vel_y(max_fall_speed.val)

func shieldglide(do_shieldglide : bool) -> void:
	"""
	Cyarm-Shield Glide (slow descent, air control)
	
	do_shieldglide : bool -- whether to begin or to cancel shieldglide
	"""
	if do_shieldglide == f_is_shieldgliding:
		# If already shieldgliding or cancelled, don't set attributes again
		return
	
	## On shieldglide BEGIN
	if do_shieldglide:
		f_is_shieldgliding = true
		if velocity.y > 0: # If falling
			override_vel_y(0) # Stop falling
	
	## On shieldglide END
	else:
		# Set flags
		f_is_shieldgliding = false
		
		sig_cyarm_shieldglide_cancel.emit() # Signal Cyarm-Shield to cancel glide

func shieldglide_calc_vel() -> void:
	"""
	Calculates the velocity of Player this physics frame, gliding down
	"""
	## Cancel Shield glide once grounded
	if f_just_landed:
		shieldglide(false)
		sig_cyarm_shieldslide_request_begin.emit() # Request Cyarm-Shield to slide again, as long as action button held

	## Fall down slowly
	else:
		## Drift (horizontal)
		override_vel_x(move_toward(velocity.x, 0.0, shieldglide_friction.val)) # Slow Player down by friction
		if curr_direction:
			# Accelerate towards top speed in air
			override_vel_x(move_toward(velocity.x, curr_direction * max_speed_shieldgliding.val, shieldglide_acceleration.val))
		
		## Fall (vertical)
		add_vel(Vector2(0, get_gravity(BodyState.SHIELDGLIDE)))
		if velocity.y > max_fall_speed_shieldgliding.val: # Terminal fall velocity
			override_vel_y(max_fall_speed_shieldgliding.val)

func SETUP_colliders(new_width : float = -1, new_height : float = -1) -> void:
	"""
	Adjust Player colliders so that any additional colliders that depend on the size
	of the base collider are resized
	
	new_width : float -- new width of Player colliders (negative means ignore)
	new_height : float -- new height of Player colliders (negative means ignore)
	"""
	var new_size : Vector2 = c_collider.shape.size # Original size
	if new_width > 0: new_size.x = new_width # Update width
	if new_height > 0: new_size.y = new_height # Update height

	c_collider.shape.size = new_size # Player hitbox
	c_collider_inside.shape.size = new_size # Inside Player area
	c_shapecast_playerfits.shape.size = new_size # Check if Player fits area

func corner_correction(delta : float) -> void:
	"""
	Translates the Player to one side before a ceiling collision to allow smoother jumping
	Call this function AFTER all x and y velocity is set for frame

	delta : float -- time between physics frames
	"""
	# During a run, check if (player + current velocity) would collide with wall next frame
	if f_is_collide_nextframe:
		var _target_pos = c_raycast_ledgesurface.get_collision_point()
		if (
				c_raycast_ledgesurface.is_colliding() and # There is a surface to corner correct atop of
				(global_position.y - _target_pos.y) <= corner_leeway_y # Small enough distance for corner correction 
			):
			# Check wall up space free
			if not test_move(global_transform.translated(Vector2(0, -corner_leeway_y)), velocity * delta):
				# Test positions from above collider down (negative to positive)
				for up_pos in range(-corner_leeway_y, 1):
					if test_move(global_transform.translated(Vector2(0, up_pos)), velocity * delta):
						# On first position that collides,
						# translate player to the shortest up position without collision (prev loop)
						translate(Vector2(0, up_pos - 1))
						break

	# Only do the following checks for ceilings
	if not f_is_rising: return

	# During a jump, check if (player + current velocity) would collide with corner ceiling next frame
	if f_is_collide_nextframe:
		# Check ceiling left space free
		if not test_move(global_transform.translated(Vector2(-corner_leeway_x, 0)), velocity * delta):
			# Test positions from leftmost of collider forwards (negative to positive)
			for l_pos in range(-corner_leeway_x, 1):
				if test_move(global_transform.translated(Vector2(l_pos, 0)), velocity * delta):
					# On first position that collides,
					# translate player to the furthest left position without collision (prev loop)
					translate(Vector2(l_pos - 1, 0))
					break
		# Check ceiling right space free
		if not test_move(global_transform.translated(Vector2(corner_leeway_x, 0)), velocity * delta):
			# Test positions from rightmost of collider backwards (positive to negative)
			for r_pos in range(corner_leeway_x, -1, -1):
				if test_move(global_transform.translated(Vector2(r_pos, 0)), velocity * delta):
					# On first position that collides,
					# translate player to the furthest right position without collision (prev loop)
					translate(Vector2(r_pos + 1, 0))
					break

func move_with_correction(delta : float) -> void:
	"""
	Moves Player with built-in move_and_slide() function using velocity 
	Handles corner collisions before movement

	delta : float -- time between physics frames
	"""
	# Teleport Player around small corners so there is no sudden stop on collision
	corner_correction(delta)
	
	# Move Player based on velocity
	move_and_slide()

######################
## Move-on-rails functions
######################
func move_onrails(delta : float) -> void:
	"""
	Moves Player
	Handles calculations using Player's MoveOnRails object (o_move_onrails)

	delta : float -- time between physics frames
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match (_o_r.move_onrails_type):
		## Move Player to target position, ignoring collision
		_o_r.RAIL_TYPE.TO_TARGET:
			# Every frame, move Player closer to target at speed
			global_position = global_position.move_toward(_o_r.move_onrails_target,
														  _o_r.move_onrails_speed.val * delta)

			move_onrails_during(_o_r) # Actions to perform DURING move to target

			# Reached target position
			if global_position == _o_r.move_onrails_target:
				move_onrails_after(_o_r) # Perform Cyarm mode-specific actions AFTER reaching target

		## Move Player for distance, respecting collision
		_o_r.RAIL_TYPE.FOR_DISTANCE:
			var _distance_this_frame : float # Distance Player would move this frame
			var _distance_left : float # How much distance left to move "for distance"

			# Every frame, set Player velocity to the calculated distance
			override_vel(_o_r.move_onrails_target * _o_r.move_onrails_speed.val)
			_distance_this_frame = velocity.length() * delta

			# If Player would move past the endpoint in a single frame, reduce speed to reach endpoint this frame
			if _distance_this_frame > _o_r.move_onrails_dist_left:
				var endpoint : Vector2 = global_position + (_o_r.move_onrails_target * _o_r.move_onrails_dist_left)
				override_vel((endpoint - global_position) / delta)
				_distance_this_frame = velocity.length() * delta
			
			## During move-on-rails
			move_onrails_during(_o_r, delta) # Actions to perform DURING move to target
			_distance_left = _o_r.move_onrails_dist_left - _distance_this_frame
			_o_r.move_onrails_dist_left = _distance_left # Update distance left

			## Done
			if _distance_left <= 0.01 or Utilities.approx_equal_vec2(velocity, Vector2.ZERO):
				# Consider done, if reached there, or if velocity is zero
				# Travelled for specified distance
				move_onrails_after(_o_r) # Perform Cyarm mode-specific actions AFTER reaching target

func move_onrails_during(_o_r : MoveOnRails, delta : float = get_physics_process_delta_time()) -> void:
	"""
	Actions to perform during a move-on-rails
	
	delta : float -- time between physics frames
	"""
	match _o_r.move_onrails_type:
		## Move Player to target position, ignoring collision
		_o_r.RAIL_TYPE.TO_TARGET:
			# Disable collisions by unsetting "Terrain" bit
			# (don't want to fully disable collider with [c_collider.disabled], since
			#  other Nodes may scan for Player collider)
			Utilities.unset_col_mask_bit(self, "Terrain")

		## Move Player to target position, respecting collision
		_o_r.RAIL_TYPE.FOR_DISTANCE:
			move_with_correction(delta) # Attempt to move calculated distance this frame

func move_onrails_after(_o_r : MoveOnRails) -> void:
	"""
	Actions to perform after a move-on-rails is complete
	"""
	match _o_r.move_onrails_type:
		_o_r.RAIL_TYPE.TO_TARGET: # After reaching target position
			# Call move_and_slide() with zero velocity, in order to update physics flags
			# such as is_on_floor() for the new position at end of move-on-rails
			velocity = Vector2.ZERO
			move_and_slide()
			update_physics_flags()

			# Restore velocity
			if sign(mor_curr_direction) == sign(_o_r.vel_to_restore.x):
				# If Player currently moving in the same direction as vel_to_restore, then restore full velocity
				override_vel(_o_r.vel_to_restore)
			else:
				# Otherwise restore part of it (setting it to 0 is too abrupt)
				override_vel(_o_r.vel_to_restore * 0.4)

			# Set Player facing direction
			curr_direction = _o_r.move_onrails_end_dir

			# Reenable collider by setting "Terrain" bit back
			Utilities.set_col_mask_bit(self, "Terrain")

			# Jump right after ledgeupping
			if f_is_ledgeupping and f_jump_after_move_onrails:
				begin_jump_buffer()

			# Pickup Cyarm-Spear
			if f_is_dashing and dist_to_cyarm() <= spear_pickup_range:
				# If dash ended near Cyarm, send signal for Player to "pickup" Cyarm (Cyarm f_follow -> true)
				sig_cyarm_follow_player.emit()
				
				# Give Player a bit more airtime, if midair
				if not is_close_to_ground():
					bump_up()
			# After dashing to Cyarm-Spear, tell Spear to unlock itself
			if f_spear_unlock_after_dash:
				sig_cyarm_spear_unlock.emit()

		_o_r.RAIL_TYPE.FOR_DISTANCE: # After travelling for target distance
			# Restore stored velocity (could also be Vector2.ZERO)
			override_vel(_o_r.vel_to_restore)
			
			if f_is_swordiaiing:
				swordiai_cut_after() # After Sword iai cut is finished, clean up

	# Clean up input flags after move-on-rails
	f_jump_after_move_onrails = false

	# Cleanup move-on-rails object
	_o_r.cleanup()

func check_inputs_during_moveonrails() -> void:
	"""
	Checks input while Player is currently moving-on-rails
	"""
	var _o_r : MoveOnRails = o_move_onrails
	
	# Update button presses
	mor_curr_direction = Input.get_axis("left", "right")
	f_mor_jump_just_pressed = Input.is_action_just_pressed("up")

	# If move-on-rails is due to ledgeupping
	if f_is_ledgeupping:
		if f_mor_jump_just_pressed:
			# Immediately jump after exiting move-on-rails
			f_jump_after_move_onrails = true

######################
## Cyarm functions
######################


######################
## State & Animation functions
######################
func SETUP_body_state_bundles() -> void:
	"""
	Sets up o_body_state_bundle_dict (a Dictionary of {BodyState -> BodyStateBundle}):
		For each Player BodyState, sets up the prerequisite functions, such as what to do when
		exiting a particular state, or how to animate a particular state
	
	BodyStateBundle object constructor arguments:
	BodyStateBundle.new(
					_player_ref : Node,
					_func_animate : Callable,        # Function to be called when animating BodyState
					_func_during_physics : Callable, # Function to be called during physics_process while in BodyState
					_func_exit_state : Callable      # Function to be called after exiting BodyState
				)
	"""
	var _temp_bsb : BodyStateBundle

	for bs in BodyState.values(): # Iterate over enum values (the integers)
		match bs:
			BodyState.DYING:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						Utilities.play_no_repeat(c_animplayer, anim_death)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.IDLE:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						play_corrected(anim_idle)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.RUN:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_run()
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.JUMP:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_jump()
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.JUMPING:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						Utilities.play_no_repeat(c_animplayer, anim_jump)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.FALLING:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						Utilities.play_no_repeat(c_animplayer, anim_jump)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.LAND:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						play_corrected(anim_land)
						animate_land()
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.WALLSLIDE:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						if f_facing_left:
							play_corrected(anim_wallslide_left, orig_sprite_x + 2 * left_or_right, orig_sprite_y)
						else:
							play_corrected(anim_wallslide_left)
						,
					func():
						pass
						,
					func():
						f_is_wallsliding = false
						,
					)
			BodyState.LEDGEUP:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						play_corrected(anim_ledgeup, orig_sprite_x, orig_sprite_y + 3)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.CROUCH_IDLE:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						play_corrected(anim_crouch)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.CROUCH_WALK:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						play_corrected(anim_crouch)
						,
					func():
						pass
						,
					func():
						pass
						,
					)
			BodyState.DASH:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						play_corrected(anim_dash)
						sig_world_spawn_afterimage.emit(global_position, left_or_right)
						,
					func():
						pass
						,
					func():
						f_is_dashing = false
						,
					)
			BodyState.SWORDSLASH:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_swordslash()
						,
					func():
						pass
						,
					func():
						swordslash(false)
						,
					)
			BodyState.SWORDIAI:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_swordiai()
						,
					func():
						pass
						,
					func():
						swordiai(false)
						,
					)
			BodyState.SPEARBROOM:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_spearbroom()
						,
					func():
						# If Player is spearbrooming, LOSE electro
						sig_electroMgr_electro_spearbrooming.emit()
						,
					func():
						rotate_player_sprite_to(0) # Reset Player sprite rotation towards mouse
						f_is_spearbrooming = false
						,
					)
			BodyState.SPEARTETHER:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_speartether()
						,
					func():
						# If Player is speartethering (IN A DIRECTION), LOSE electro
						if curr_direction:
							sig_electroMgr_electro_speartethering_nudge.emit()
						,
					func():
						rotate_player_sprite_to(0) # Reset Player sprite rotation towards Spear pivot
						animate_arrow(false)
						f_is_speartethering = false
						,
					)
			BodyState.SICKLESWING:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_sickleswing()
						,
					func():
						pass
						,
					func():
						rotate_player_sprite_to(0) # Reset Player sprite rotation towards Spear pivot
						animate_arrow(false)
						f_is_sickleswinging = false
						,
					)
			BodyState.SICKLEPULL:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_sicklepull()
						,
					func():
						pass
						,
					func():
						sicklepull(CyarmSickle.SicklePull.END_PULL, null)
						,
					)
			BodyState.SHIELDSLIDE:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_shieldslide()
						,
					func():
						pass
						,
					func():
						shieldslide(false, true)
						,
					)
			BodyState.SHIELDGLIDE:
				_temp_bsb = BodyStateBundle.new(self,
					func():
						animate_shieldglide()
						,
					func():
						pass
						,
					func():
						shieldglide(false)
						,
					)
		# Add particular BodyStateBundle to dictionary, mapped to key of BodyState
		o_body_state_bundle_dict[bs] = _temp_bsb

func update_state() -> void:
	"""
	Updates Player current body state depending on current flags
	"""
	var _next_state : BodyState = curr_body_state
	match o_move_onrails.move_onrails_type:
		## Player moving-on-rails
		o_move_onrails.RAIL_TYPE.TO_TARGET, o_move_onrails.RAIL_TYPE.FOR_DISTANCE:
			if f_is_ledgeupping:
				_next_state = BodyState.LEDGEUP
			elif f_is_dashing:
				if f_is_sicklepulling:
					_next_state = BodyState.SICKLEPULL
				if f_is_swordiaiing:
					_next_state = BodyState.SWORDIAI
				else:
					_next_state = BodyState.DASH
		## Player NOT moving-on-rails
		o_move_onrails.RAIL_TYPE.NONE:
			## Cyarm-specific states
			if f_is_swordslashing:
				_next_state = BodyState.SWORDSLASH
			elif f_is_swordiaiing:
				_next_state = BodyState.SWORDIAI
			elif f_is_spearbrooming:
				_next_state = BodyState.SPEARBROOM
			elif f_is_speartethering:
				_next_state = BodyState.SPEARTETHER
			elif f_is_sickleswinging:
				_next_state = BodyState.SICKLESWING
			elif f_is_sicklepulling:
				_next_state = BodyState.SICKLEPULL
			elif f_is_shieldsliding:
				_next_state = BodyState.SHIELDSLIDE
			elif f_is_shieldgliding:
				_next_state = BodyState.SHIELDGLIDE
				
			## Player-specific states
			else:
				if f_is_grounded: # On Ground
					if curr_body_state == BodyState.FALLING:
						_next_state = BodyState.LAND
					else:
						if curr_direction:
							if f_is_crouching:
								_next_state = BodyState.CROUCH_WALK
							else:
								_next_state = BodyState.RUN
						else:
							if f_is_crouching:
								_next_state = BodyState.CROUCH_IDLE
							else:
								_next_state = BodyState.IDLE
				else: # Airborne
					if f_is_rising:
						if f_a_just_jumped:
							_next_state = BodyState.JUMP
							f_a_just_jumped = false
						else:
							_next_state = BodyState.JUMPING
					else:
						# Falling
						_next_state = BodyState.FALLING
						if f_is_wallsliding:
							_next_state = BodyState.WALLSLIDE

	# Player death overrides every other state
	if f_dead:
		_next_state = BodyState.DYING

	# Don't attempt to transition to the same state
	if not curr_body_state == _next_state:
		# Perform cleanup of current state
		exit_state()
		# Transition Player to next body state
		curr_body_state = _next_state

func on_animation_end(anim_name : String) -> void:
	"""
	Performs cleanup of current animation on finish
	
	anim_name : String -- name of animation that has ended
	"""
	match anim_name:
		_:
			pass

func update_animations() -> void:
	"""
	Updates animations:
		Player body sprite matching current state
	"""
	(o_body_state_bundle_dict[curr_body_state] as BodyStateBundle).func_animate.call()

func play_corrected(anim_name : String, x_offset : float = orig_sprite_x, y_offset : float = orig_sprite_y, play_once : bool = false):
	"""
	Play the specified animation with an offset (on default there's no offset, sprite position is (0, 0))
	
	anim_name : String -- the name of the animation to play
	x_offset : float = orig_sprite_x -- the x position of Player sprite
	y_offset : float = orig_sprite_y -- the y position of Player sprite
	"""
	if play_once:
		Utilities.play_no_repeat(c_animplayer, anim_name)
	else:
		c_animplayer.play(anim_name)

	c_sprite.position.x = x_offset
	c_sprite.position.y = y_offset

func animate_run() -> void:
	"""
	Play the animations for BodyState.RUN
	"""
	if f_a_just_changed_dir:
		sig_world_spawn_dust.emit(
			global_position + Vector2(half_width, 0) * left_or_right * -1,
			left_or_right * -1, 1, PSLib.anim_dust_run_stop, Vector2.DOWN
		)
		f_a_just_changed_dir = false

	play_corrected(anim_run)

func animate_jump() -> void:
	"""
	Play the animations for BodyState.JUMP
	"""
	# Spawn jump particles
	if o_lastgroundedbundle.f_on_ground:
		sig_world_spawn_dust.emit(o_lastgroundedbundle.get_pos(), 1, 1, PSLib.anim_dust_jump_ground, Vector2.DOWN)
	else: # o_lastgroundedbundle.f_on_wall
		sig_world_spawn_dust.emit(
			o_lastgroundedbundle.get_pos(), left_or_right * -1, 1,
			PSLib.anim_dust_jump_wall, Vector2.RIGHT * left_or_right
		)

	# Stretch sprite on jump
	var jump_tween = create_tween()
	jump_tween.tween_property(c_sprite, "scale", Vector2(.9, 1.1), 0.1)
	jump_tween.tween_property(c_sprite, "scale", Vector2(1, 1), 0.1)

func animate_land() -> void:
	"""
	Play the animations for BodyState.LAND
	"""
	# Spawn dust
	sig_world_spawn_dust.emit(o_lastgroundedbundle.get_pos(), 1, 1, PSLib.anim_dust_land, Vector2.DOWN)

	# Squash sprite on landing
	var land_tween = create_tween()
	land_tween.tween_property(c_sprite, "scale", Vector2(1.1, .8), 0.1)
	land_tween.tween_property(c_sprite, "scale", Vector2(1, 1), 0.1)

func animate_swordslash() -> void:
	"""
	Play the animations for BodyState.SWORDSLASH
	"""
	if f_is_grounded:
		Utilities.play_no_repeat(c_animplayer, anim_swordslash_ground)

func animate_swordiai() -> void:
	"""
	Play the animations for BodyState.SWORDIAI
	"""
	match sword_iai_curr_state:
		SwordIaiState.READY:
			play_corrected(anim_swordiai_ready)
		SwordIaiState.CUT:
			play_corrected(anim_swordiai_cut)
		SwordIaiState.AFTER_CUT:
			Utilities.play_no_repeat(c_animplayer, anim_swordiai_sheathe)

func anim_func_swordiai() -> void:
	"""
	Called by AnimationPlayer, after playing swordiai_sheathe
	"""
	swordiai(false) # End Sword Iai

func animate_spearbroom() -> void:
	"""
	Play the animations for BodyState.SPEARBROOM
	"""
	if Globals.EM_curr_electro <= 0.0 or f_is_grounded:
		rotate_player_sprite_to(0)
		play_corrected(anim_spearbroom_stand)
		return # Don't attempt to rotate towards mouse when Player can't move without electro
	
	# Rotate Player sprite towards mouse position
	var _spr_rot : float = mid_global_position.angle_to_point(Globals.mouse_pos)
	if f_facing_left:
		rotate_player_sprite_to(_spr_rot + PI)
	else:
		rotate_player_sprite_to(_spr_rot)
	
	# Get the Player's "incline", or how similarly Player is facing in the horizontal direction 
	var _player_incline : float = abs(spearbrooming_dir.dot(Vector2(left_or_right, 0)))
	
	# Play the correct spearbrooming animation based on Player "incline"
	var _next_anim : String
	if _player_incline > 0.97:
		_next_anim = anim_spearbroom_stand
	elif _player_incline > 0.3:
		_next_anim = anim_spearbroom_crouch
	else:
		_next_anim = anim_spearbroom_hangingonfordearlife

	# Prevent sprite jitter on threshold
	if _next_anim != c_animplayer.current_animation:
		if spearbrooming_incline_sprite_JC.incr_and_trigger(): # Increment JitterCounter and potentally trigger if statement
			play_corrected(_next_anim)
	else:
		spearbrooming_incline_sprite_JC.reset() # Reset JitterCounter on jitter

func animate_speartether() -> void:
	"""
	Play the animations for BodyState.SPEARTETHER
	"""
	# Draw Spear tether
	c_line_spear_tether.clear_points()
	c_line_spear_tether.add_point(to_local(mid_global_position))
	c_line_spear_tether.add_point(to_local(Globals.cyarm_pos))
	
	# Draw arrow showing Player launch direction
	var _tangential_speed : float = velocity.length()
	if _tangential_speed < 0.0001 * Globals.time_scale: # Prevent arrow appear/disappear jitter on threshold
		if speartether_hide_arrow_JC.incr_and_trigger(): # Increment JitterCounter and potentally trigger if statement
			animate_arrow(false)
	else:
		speartether_hide_arrow_JC.reset() # Reset JitterCounter on jitter
		animate_arrow(true)
	if c_line_arrowbody.visible: # If arrow not hidden, then animate
		var _tangential_dir : Vector2 = speartether_calc_tangential_dir()
		var _arrow_len : float = Utilities.map(
												clampf(_tangential_speed, 0, 1000 * Globals.time_scale),
												0, 1000 * Globals.time_scale, # tangential speed range
												0, 80 # Arrow length range
											)
		animate_arrow(true, mid_global_position + _tangential_dir * _arrow_len, 1.0)
	
	# Rotate Player sprite so that head points towards Cyarm-Spear pivot
	var _spr_rot : float = mid_global_position.angle_to_point(Globals.cyarm_pos)
	rotate_player_sprite_to(_spr_rot + PI/2)
	
	# Player sliding along floor/wall instead of following pendulum arc
	if get_slide_collision_count() > 0:
		var _normal : Vector2 = get_slide_collision(0).get_normal()
		var _grinding_fx : String
		var _col_pos = get_slide_collision(0).get_position()
		var _facing_dir_x : int
		var _facing_dir_y : int
		
		# Player anim
		if f_is_grounded:
			play_corrected(anim_speartether_grounded)
			_grinding_fx = PSLib.anim_swordboard_sparks
			_facing_dir_x = -1 * sign(speartether_angle_speed)
			_facing_dir_y = 1

	else:
		pass # Do nothing if swinging in midair

func animate_sickleswing() -> void:
	"""
	Play the animations for BodyState.SICKLESWING
	"""
	# Draw arrow showing Player launch direction
	var _tangential_speed : float = velocity.length()
	if _tangential_speed < 0.0001 * Globals.time_scale: # Prevent arrow appear/disappear jitter on threshold
		if speartether_hide_arrow_JC.incr_and_trigger(): # Increment JitterCounter and potentally trigger if statement
			animate_arrow(false)
	else:
		speartether_hide_arrow_JC.reset() # Reset JitterCounter on jitter
		animate_arrow(true)
	if c_line_arrowbody.visible: # If arrow not hidden, then animate
		var _tangential_dir : Vector2 = sickleswing_calc_tangential_dir()
		var _arrow_len : float = Utilities.map(
												clampf(_tangential_speed, 0, 1000 * Globals.time_scale),
												0, 1000 * Globals.time_scale, # tangential speed range
												0, 80 # Arrow length range
											)
		animate_arrow(true, mid_global_position + _tangential_dir * _arrow_len, 1.0)
	
	# Rotate Player sprite so that head points towards the Cyarm-Spear pivot
	var _spr_rot : float = mid_global_position.angle_to_point(sickleswing_anchor_pos)
	rotate_player_sprite_to(_spr_rot + PI/2)
	
	# Player sliding along floor/wall instead of following pendulum arc
	if get_slide_collision_count() > 0:
		var _normal : Vector2 = get_slide_collision(0).get_normal()
		var _grinding_fx : String
		var _col_pos = get_slide_collision(0).get_position()
		var _facing_dir_x : int
		var _facing_dir_y : int
		
		# Player anim
		if f_is_grounded:
			play_corrected(anim_speartether_grounded)
			_grinding_fx = PSLib.anim_swordboard_sparks
			_facing_dir_x = -1 * sign(speartether_angle_speed)
			_facing_dir_y = 1

	else:
		pass # Do nothing if swinging in midair

func animate_sicklepull() -> void:
	"""
	Play the animations for BodyState.SICKLEPULL
	"""
	play_corrected(anim_sicklepull)

	# Play an "air dash" effect on the subject that gets moved by Sickle pull
	if f_a_just_sicklepulled:
		var _pos_to_spawn_FX : Vector2
		
		if curr_sicklepull_type == CyarmSickle.SicklePull.TARGET_TO_PLAYER:
			_pos_to_spawn_FX = Globals.cyarm_pos
		else: # curr_sicklepull_type == CyarmSickle.SicklePull.PLAYER_TO_TARGET
			_pos_to_spawn_FX = mid_global_position
		
		# Spawn air dash FX
		sig_world_spawn_rot_effect.emit(_pos_to_spawn_FX, sicklepull_towards_dir.angle(), PSLib.anim_sicklepull_dash_FX)
		
		f_a_just_sicklepulled = false # Reset animation flag
	
func animate_shieldslide() -> void:
	"""
	Play the animations for BodyState.SHIELDSLIDE
	"""
	play_corrected(anim_shieldslide)
	
	# Play grinding FX
	if f_is_grounded:
		if c_timer_grind_cooldown.is_stopped():
			sig_world_spawn_dust.emit(c_marker_grind.global_position, -1 * left_or_right, 1.0,
										PSLib.anim_swordboard_sparks, Vector2.DOWN)
			c_timer_grind_cooldown.start()

func animate_shieldglide() -> void:
	"""
	Play the animations for BodyState.SHIELDGLIDE
	"""
	play_corrected(anim_shieldglide)

	# Player FX for when Player bumps into Enemy and gets launched
	if f_a_just_shieldslide_bumped:
		sig_world_spawn_dust.emit(shieldslide_bump_target_pos, left_or_right, 1.0,
									PSLib.anim_shieldslide_bump_FX, Vector2.ZERO)
		f_a_just_shieldslide_bumped = false

func animate_arrow(do_draw : bool, target_pos : Vector2 = Vector2.ZERO, alpha : float = 1.0) -> void:
	"""
	Draws Arrow that points from Player to point
	
	do_draw : bool -- whether to make arrow visible or not
	target_pos : Vector2 -- the end point of the arrow
	alpha : float -- the alpha (transparency, where 1.0 is full) of the arrow
	"""
	if not do_draw:
		c_line_arrowbody.clear_points()
		c_line_arrowbody.visible = false
		return
	else:
		c_line_arrowbody.visible = true

	# Draw arrow body
	c_line_arrowbody.clear_points()
	c_line_arrowbody.add_point(Vector2.ZERO)
	c_line_arrowbody.add_point(c_line_arrowbody.to_local(target_pos))
	c_line_arrowbody.modulate.a = alpha

	# Draw arrow head
	c_sprite_arrowhead.global_position = target_pos
	c_sprite_arrowhead.rotation = c_line_arrowbody.global_position.angle_to_point(target_pos)

func update_physics_state() -> void:
	"""
	Performs actions based on current BodyState, per physics frame
	"""
	(o_body_state_bundle_dict[curr_body_state] as BodyStateBundle).func_during_physics.call()

func exit_state() -> void:
	"""
	Performs cleanup of current BodyState
	"""
	(o_body_state_bundle_dict[curr_body_state] as BodyStateBundle).func_exit_state.call()

######################
## Damage/Attack functions
######################
func get_defense_modifier() -> float:
	"""
	Returns : float -- the amount of damage Player takes modifier
	"""
	return 1.0 # Take normal damage

func damage_me(damage : int, _damage_dir : Vector2) -> DamageManager.DamageResult:
	"""
	Handles damage dealt TO Player
	
	damage : int -- damage to be dealt
	_damage_dir : Vector2 -- direction of damage dealt
	"""
	# Check if damage should be parried
	if f_invincible_from_shield:
		return DamageManager.DamageResult.PARRIED # Take no damage if Player is invincible, and do something back to attacker
	elif f_invincible:
		return DamageManager.DamageResult.IGNORE # Take no damage if Player is invincible

	# Do damage
	curr_HP -= damage
	if curr_HP <= 0:
		die()
		return DamageManager.DamageResult.DEATH

	flash() # Sprite feedback to hit
	
	return DamageManager.DamageResult.SUCCESS

func flash() -> void:
	"""
	Flashes sprite white as hit feedback, and sets Player invincible for a bit
	"""
	c_sprite.material = material_hit
	c_sprite.material.set_shader_parameter("progress", 1) # Flash sprite
	c_timer_invincible.start()
	f_invincible = true

func die():
	"""
	Handles Player death
	"""
	override_vel(Vector2.ZERO)
	sig_player_died.emit()
	f_freeze_movement = true
	f_invincible = true # Stop taking damage when dead
	f_dead = true

func anim_func_respawn():
	"""
	Handles Player respawn, called after dying animation
	"""
	global_position = Globals.CheckpointM_curr_checkpoint_pos # Spawn at furthest reached checkpoint
	curr_HP = max_HP # Reset HP
	
	update_globals()
	sig_player_respawned.emit()
	f_freeze_movement = false
	c_timer_invincible.start() # Slight time of invincibility after spawn
	f_dead = false

######################
## Received Signals
######################
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	"""
	Clean up animation on end
	"""
	on_animation_end(anim_name)

func _on_coyote_timer_timeout() -> void:
	"""
	Prevent jump after coyote time timer runs out
	"""
	f_can_jump = false

func _on_sword_slash_freeze_timeout() -> void:
	"""
	Unfreeze Player movement after slash
	"""
	f_freeze_movement = false
	swordslash(false)

func _on_sword_iai_hangtime_timeout() -> void:
	"""
	Restore gravity after giving Player some hangtime after a Sword Iai
	"""
	f_apply_gravity = true

func _on_sicklepull_hangtime_timeout() -> void:
	"""
	Restore gravity after giving Player some hangtime after a Sickle pull
	"""
	f_apply_gravity = true

func _on_received_HUD_readied() -> void:
	"""
	Once HUD is ready, update HP
	"""
	curr_HP = max_HP

func _on_received_freeze(do_freeze : bool) -> void:
	"""
	Set flag to freeze Player movement
	"""
	f_freeze_movement = do_freeze

func _on_received_stop_momentum(stop_pos : Vector2) -> void:
	"""
	Zero out Player velocity
	
	stop_pos : Vector2 -- the position Player was at, at the momement the signal to stop momentum was sent
	"""
	override_vel(Vector2.ZERO)
	if stop_pos != Vector2.ZERO:
		global_position = stop_pos - Vector2(0, 1)

func _on_received_dash_to_spear() -> void:
	"""
	Calculate Player dash TO Cyarm-Spear
	"""
	var _dash_to_pos : Vector2 = Globals.cyarm_pos + Vector2(0, half_height) # Cyarm-Spear position, move down half Player height
	var _dash_dir : Vector2 = (_dash_to_pos - mid_global_position).normalized() # Direction of dash
	var _dash_speed : float = dist_to_cyarm(true) / dash_to_spear_duration.val # Dash takes same amount of time, regardless of distance
	
	dash(MoveOnRails.RAIL_TYPE.TO_TARGET, _dash_to_pos, _dash_dir, _dash_speed)
	
	f_spear_unlock_after_dash = true

func _on_received_dash_away_from_shield() -> void:
	"""
	Calculate Player dash AWAY FROM Cyarm-Shield
	"""
	var _dash_to_pos : Vector2 # Position to dash to
	var _dash_dir : Vector2 # Direction away from Cyarm-Shield
	var _dist_to_shield : Vector2 = (mid_global_position - Globals.cyarm_pos)

	if _dist_to_shield.length_squared() < 0.1:
		# For cases where Cyarm-Shield guards, and has the ALMOST SAME position as Player
		return # DON'T DASH
	else:
		_dash_dir = _dist_to_shield.normalized() # Direction away from Cyarm-Shield
		_dash_to_pos = global_position + (_dash_dir * dash_distance) # Position to dash to
		dash(MoveOnRails.RAIL_TYPE.FOR_DISTANCE, _dash_to_pos, _dash_dir, dash_speed.val)

func _on_invincible_timer_timeout() -> void:
	"""
	Revert Player back to being able to be damaged
	"""
	c_sprite.material = material_default # Reset sprite to default material
	f_invincible = false

func _on_check_movable_platform_body_entered(body: Node2D) -> void:
	"""
	When Player lands on a MovableTerrain, save a reference to the particular MovableTerrain
	"""
	mov_terrain_ref = body
	if not mov_terrain_ref.velocity.y < 0:
		f_mov_terrain_can_jump = true
	else:
		f_mov_terrain_can_jump = false

func _on_check_movable_platform_body_exited(_body: Node2D) -> void:
	"""
	When Player leaves a MovableTerrain, remove the reference to the particular MovableTerrain
	"""
	mov_terrain_ref = null

func _on_received_chainedplatform_began_move(platform_ref : Node, vel : Vector2) -> void:
	"""
	When the saved MovableTerrain reference begins to move UP, prevent Player from jumping
	"""
	if mov_terrain_ref == platform_ref:
		if vel.y < 0:
			f_mov_terrain_can_jump = false
		else:
			f_mov_terrain_can_jump = true
	
func _on_received_chainedplatform_reached_anchor(platform_ref : Node, last_vel : Vector2) -> void:
	"""
	Once the saved MovableTerrain stops moving, allow Player to jump once again
	"""
	# Wait an appropriate amount of physics frames before allowing Player to jump
	# Otherwise, Player might jump with an INSANE velocity if the Player jumps too soon after the
	# MovableTerrain stops.
	# This might be due to (MovableTerrain velocity + Player velocity + collision shenanigans = INSANE velocity)
	await get_tree().create_timer(get_physics_process_delta_time() * 2).timeout

	if (
			platform_ref == mov_terrain_ref
		and
			f_can_jump
		and
			f_jump_buffer_active
		and
			last_vel.y < 0 # MovableTerrain moving UP
		):
		var _modifier_ratio = abs(last_vel.y / jump_initial_speed.val) # Allow Player to jump higher depending on MovableTerrain speed
		jump(max(1.0, _modifier_ratio))

	f_mov_terrain_can_jump = true # Allow Player to jump on MovableTerrain

func _on_received_swordslash(do_swordslashing : bool):
	"""
	Cyarm-Sword Slash
	
	do_swordslashing : whether to begin or to end sword slash
	"""
	swordslash(do_swordslashing)

func _on_received_swordiai(do_swordiaiing : bool) -> void:
	"""
	Cyarm-Sword Iai
	
	do_swordiaiing : whether to begin or to end sword iai
	"""
	swordiai(do_swordiaiing)

func _on_received_swordiai_cancel() -> void:
	"""
	Cancel Cyarm-Sword Iai (Force subscribe by CyarmSwordIaiStop)
	"""
	swordiai(false)
	
	sig_world_dim.emit(false) # Undim World

func _on_received_swordiai_cut(end_pos : Vector2, distance : float) -> void:
	"""
	Cyarm-Sword Iai cut

	do_cut : bool -- whether or not to do the cut or to end Sword Iai
	end_pos : Vector2 -- position of cut end
	distance : float -- length of cut
	"""
	if f_is_swordiaiing:
		swordiai_cut(end_pos, distance)

func _on_received_spearbroom(do_spearbrooming : bool) -> void:
	"""
	Cyarm-Spearbrooming
	
	do_spearbrooming : bool -- whether to begin or to cancel spearbrooming
	"""
	spearbroom(do_spearbrooming)

func _on_received_speartether(do_speartether : bool) -> void:
	"""
	Cyarm-Spear tether, have Player "grapple" to Spear
	
	do_speartether : bool -- whether to begin or to cancel Spear tether
	"""
	speartether(do_speartether)

func _on_received_sickleswing(do_sickleswing : bool, sickle_pos : Vector2) -> void:
	"""
	Cyarm-Sickle swing, have Player swing from pivot (where Sickle is stuck)
	
	do_sickleswing : bool -- whether to begin or to cancel Sickle swing
	sickle_pos : Vector2 -- global_position of Sickle
	"""
	sickleswing(do_sickleswing, sickle_pos)

func _on_received_sicklepull(sicklepull_type : CyarmSickle.SicklePull, sickle_stuck_target : Node2D) -> void:
	"""
	(signal sent by CyarmSickle)
	CyarmSickle.SicklePull:
		- pull Player towards target
		- pull target towards Player
		- end current pull
	
	sicklepull_type : SicklePull -- the type of pull to do, either pull Player to Target, or Target to Player
	sickle_stuck_target : Node2D -- what Node is the Sickle stuck in
	"""
	sicklepull(sicklepull_type, sickle_stuck_target)

func _on_received_sickleshard_pickup() -> void:
	"""
	Allows Player to jump again, gives Player some velocity upwards if airborne
	"""
	if not f_is_grounded:
		bump_up()
		c_timer_sicklepull_hangtime.start() # A little extra hangtime
		f_can_jump = true
		f_can_coyote = false # Prevent coyote time timer

func _on_received_shield_guard_invincible(isInvincible : bool) -> void:
	"""
	Modify Player vulnerability to damage depending on Shield-guard
	
	isInvincible : bool -- whether Player should be rendered invincible to damage
	"""
	if isInvincible:
		override_vel(Vector2.ZERO) # Cancel all velocity when Cyarm-Shield-guard begins
		f_invincible_from_shield = true
		f_invincible = true
	else:
		f_invincible_from_shield = false
		f_invincible = false

func _on_received_shield_guard_success() -> void:
	"""
	On Shield having successfully guarded or reflected something, signal ElectroManager to
	GAIN electro
	"""
	sig_electroMgr_electro_shield_guard_success.emit()

func _on_received_shield_slide(do_shieldslide : bool, on_press : bool = true) -> void:
	"""
	Cyarm-Shield slide, have Player "slide" on Shield
	
	do_shieldslide : bool -- whether to begin or to cancel Shield slide
	on_press : bool = true -- whether or not shield slide was initiated on action press (rather than hold)
	"""
	shieldslide(do_shieldslide, on_press)

func _on_received_shield_glide(do_shieldglide : bool, on_click : bool) -> void:
	"""
	Cyarm-Shield glide, have Player "glide" using Shield
	
	do_shieldglide : bool -- whether to begin or to cancel Shield glide
	on_click : bool -- whether Shield glide was initiated from a double-click
	"""
	if on_click:
		# Launch Player into the air (faster depending on fall speed)
		var _launch_modifer : float = abs(velocity.y / jump_initial_speed.val)
		if is_zero_approx(velocity.y): _launch_modifer = 1.0
		jump(_launch_modifer, false)

	shieldglide(do_shieldglide)

func _on_shield_slide_hitbox_body_entered(body: Node2D) -> void:
	"""
	During Cyarm-Shield slide, if Player were to collide with Enemy, launch Player into the air
	"""
	# Launch Player into the air
	jump(2.6, false)
	
	f_shieldslide_do_fall = false
	f_do_variable_jump = false # NOT a normal jump, do NOT allow variable jump height
	
	# Animate Shield slide bump FX
	f_a_just_shieldslide_bumped = true # Flag to animate bump FX
	shieldslide_bump_target_pos = Utilities.get_middlepos_of(body)
	
	# Cancel shield slide
	shieldslide(false, true)
	
	# Request shield glide
	sig_cyarm_shieldglide_request_begin.emit()

func _on_inside_player_area_body_entered(body: Node2D) -> void:
	"""
	Cyarm-Shield currently inside Player collider
	"""
	cyarm_shield_ref = body # Save reference to Cyarm-Shield
	f_cyarm_shield_overlapping = true

func _on_inside_player_area_body_exited(_body: Node2D) -> void:
	"""
	Cyarm-Shield no longer overlapping Player collider
	"""
	f_cyarm_shield_overlapping = false
