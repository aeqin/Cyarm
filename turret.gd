extends EnemyBase

### Signals
signal sig_world_spawn_projectile(pos : Vector2, direction : Vector2, creator : Node)

### Components
@onready var c_collider_turret : CollisionShape2D = $TurretCollider
@onready var c_collider_attack_range : CollisionShape2D = $AttackRange/CollisionShape2D
@onready var c_raycast_gun : RayCast2D = $Sprites/Gun/GunCast
@onready var c_sprite_base : AnimatedSprite2D = $Sprites/TurretBase
@onready var c_sprite_gun : AnimatedSprite2D = $Sprites/Gun
@onready var c_sprite_active : Sprite2D = $Sprites/ActiveLight
@onready var c_marker_lock_left : Marker2D = $Markers/LockLeft
@onready var c_marker_lock_right : Marker2D = $Markers/LockRight
@onready var c_marker_up : Marker2D = $Markers/Up
@onready var c_marker_projectile_spawn : Marker2D = $Sprites/Gun/ProjectileSpawn
@onready var c_timer_decision : Timer = $Timers/DecisionTimer
@onready var c_timer_gun_cooldown : Timer = $Timers/GunShootCooldown

### Turret state
enum TurretState {NA, INACTIVE, BOOTING, CALC_AIMING, AIMING, READY_TO_FIRE, FIRE_GUN, RELOADING}
var turret_curr_state : TurretState = TurretState.INACTIVE
var turret_next_state : TurretState = TurretState.INACTIVE
var turret_state_as_str : String:
	get:
		return TurretState.keys()[turret_curr_state]

var f_player_in_range : bool = false
var turret_health : float = 10.0
var turret_boot_duration : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_decision) # Small pause before Turret can target Player

### Gun variables
var projectile_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 20)
var gun_target_rot : float = 0.0 # Rotation gun should rotate to
var gun_aim_speed : CVP_Speed = CVP_Speed.new(15.0)
var gun_range : float = 200.0
var gun_cooldown_duration : CVP_Duration = CVP_Duration.new(0.8, true, c_timer_gun_cooldown) # How often turret can shoot
var gun_before_duration : CVP_Duration = CVP_Duration.new(0.4, true, c_timer_decision) # Small pause before shooting
var gun_after_duration : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_decision) # Small pause before aiming again

### Turret gun boundaries
var left_bound_rad : float
var right_bound_rad : float
var turret_angle_offset : float # Turret rotation offsets the rotations of sprites and calculations

func _ready() -> void:
	# Assign vars from EnemyBase class
	c_sprite = c_sprite_base
	c_collider = c_collider_turret
	health = turret_health
	mass = 10
	
	super() # call EnemyBase _ready()
	
	## Set timers
	c_timer_gun_cooldown.wait_time = gun_cooldown_duration.val
	
	## Set raycasts
	c_collider_attack_range.shape.radius = gun_range
	c_raycast_gun.target_position.x = gun_range
	
	### Calculate the angle to bound the turret to 180 degrees (don't shoot under itself)
	var _dir_to_left : Vector2 = (c_marker_lock_left.global_position - c_sprite_gun.global_position).normalized()
	left_bound_rad = Utilities.bound_rot(atan2(_dir_to_left.y, _dir_to_left.x) - rotation)
	var _dir_to_right : Vector2 = (c_marker_lock_right.global_position - c_sprite_gun.global_position).normalized()
	right_bound_rad = Utilities.bound_rot(atan2(_dir_to_right.y, _dir_to_right.x) - rotation)

	turret_angle_offset = -rotation # Offset all rotation calculations by turret rotation

func calc_gun_rot(target : Vector2, do_random_offset : bool = true) -> float:
	"""
	Calculates the rotation gun should rotate to

	target : Vector2 -- position to rotate towards
	do_random_offset : bool -- whether gun rotation should be off a bit (for more shooting variance)
	"""
	var _dir_to_target : Vector2 = (target - c_sprite_gun.global_position).normalized()
	var _rotate_to : float = Utilities.bound_rot(atan2(_dir_to_target.y, _dir_to_target.x) + turret_angle_offset) # Angle offset by Turret rotation
	
	if do_random_offset:
		# Randomly offset gun aim a bit
		_rotate_to = Globals.random.randf_range(_rotate_to * 0.97,
												_rotate_to * 1.03) # +/- 3% dir towards Player

	return _rotate_to

func point_gun_at(
					target_rot : float,
					force_instant : bool = false,
					look_speed : float = 15.0,
					delta : float = get_physics_process_delta_time()
				) -> bool:
	"""
	Rotates Turret's gun sprite to look at a target
	
	target_rot : float -- target rotation (in radians) to rotate gun towards
	force_instant : bool -- whether to instantly look at, or lerp smoothly there
	look_speed : float -- how fast to smoothly look there
	delta : float -- time between physics frames
	
	Returns : bool -- whether gun has rotated to reach the target direction
	"""
	# Prevent the turret gun from rotating past its set bounds (aiming underneath itself)
	if target_rot < left_bound_rad:
		if target_rot > left_bound_rad - PI/2:
			target_rot = left_bound_rad
		else:
			target_rot = right_bound_rad

	# Rotate the gun
	if force_instant:
		c_sprite_gun.rotation = target_rot
	else:
		c_sprite_gun.rotation = lerp_angle(c_sprite_gun.rotation, target_rot, look_speed * delta)

	# Returns whether current gun rotation matches target rotation
	return (
			Utilities.approx_equal_vec2
				(
					Utilities.clean_neg_zero_vec2(Vector2.RIGHT.rotated(c_sprite_gun.rotation)),
					Utilities.clean_neg_zero_vec2(Vector2.RIGHT.rotated(target_rot))
				)
			)

func shoot_gun() -> void:
	"""
	Shoot Turret gun
	"""
	# Decide Projectile direction
	var _pos : Vector2 = c_marker_projectile_spawn.global_position
	var _direction : Vector2 = (c_marker_projectile_spawn.global_position - c_sprite_gun.global_position).normalized()

	sig_world_spawn_projectile.emit(self, get_damage(), _pos, _direction) # Signal World to spawn Projectile
	
	# Set a wait before shooting again
	var _next_cooldown : float = Globals.random.randf_range(
									gun_cooldown_duration.val * 0.6,
									gun_cooldown_duration.val * 1.4) # 40% up or down from normal cooldown timer
	c_timer_gun_cooldown.start(_next_cooldown)

######################
## Movement functions
######################
func override_vel(_new_velocity : Vector2):
	"""
	Overrides the old velocity with new value pair
	
	new_velocity : Vector2 -- new velocity
	"""
	velocity = Vector2.ZERO # Turret won't move

func sicklepull_me(vel_to_add : Vector2) -> void:
	"""
	Remove control from Enemy
	
	vel_to_add : Vector2 -- value pair to add to the current velocity
	"""
	pass # Ignore any attempt to Sickle pull

######################
## Attack/Damage functions
######################
func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Enemy currently does
	"""
	return projectile_damage

######################
## State & Animation functions
######################
func calc_physics_state_decision() -> void:
	"""
	Calculates state every physics frame
	"""
	match turret_curr_state:
		TurretState.INACTIVE:
			pass # Do nothing

		TurretState.CALC_AIMING:
			# Calculate rotation Turret gun should move towards
			gun_target_rot = calc_gun_rot(Globals.player_center_pos)

			# After calculating rotation, set Turret state to rotate towards it
			turret_curr_state = TurretState.AIMING
		
		TurretState.AIMING:
			# Point Turret gun at Player
			var _f_reached_target = point_gun_at(gun_target_rot, false, gun_aim_speed.val)
			if _f_reached_target:
				# Check whether line of sight actually reaches Player
				if c_raycast_gun.is_colliding():
					var _collider = c_raycast_gun.get_collider()
					if _collider and Utilities.is_player(_collider):
						# Player in line of sight, set Turret state ready to fire
						turret_curr_state = TurretState.READY_TO_FIRE
					else:
						# Enemy/Terrain in line of sight, blocking Player
						# so re-calculate target state
						turret_curr_state = TurretState.CALC_AIMING
				else:
					# Line of sight reached nothing, re-calculate aim
					turret_curr_state = TurretState.CALC_AIMING

		TurretState.READY_TO_FIRE:
			# Wait a bit before firing, so indicater light can be acknowledged by Player
			if c_timer_decision.is_stopped():
				c_timer_decision.start(gun_before_duration.val)
				turret_next_state = TurretState.FIRE_GUN

		TurretState.FIRE_GUN:
			# If Turret can shoot
			if c_timer_gun_cooldown.is_stopped():
				# Shoot Projectile
				shoot_gun()
				
				# After shooting, set Turret state RELOADING, so the aiming at a new target doesn't look instant
				c_timer_decision.start(gun_after_duration.val)
				turret_curr_state = TurretState.RELOADING

		TurretState.RELOADING:
			# Wait a bit until timer runs out, then aim the Turret gun 
			if c_timer_decision.is_stopped():
				turret_curr_state = TurretState.CALC_AIMING

func update_animations() -> void:
	"""
	Updates Turret animations
	"""
	if turret_curr_state == TurretState.INACTIVE:
		# Have Turret light turn off to show its inactive
		c_sprite_active.visible = false
	else:
		if (
				turret_curr_state == TurretState.READY_TO_FIRE or
				turret_curr_state == TurretState.FIRE_GUN
			):
			# Turret about to shoot
			c_sprite_active.modulate = Color.RED
		else:
			# Turret active
			c_sprite_active.modulate = Color.YELLOW
		c_sprite_active.visible = true

##################
## Received Signals
##################
func _on_attack_range_body_entered(_body: Node2D) -> void:
	"""
	Begin timer to set Turret active once Player enters attack range
	"""
	c_timer_decision.start(turret_boot_duration.val)

	f_player_in_range = true
	turret_curr_state = TurretState.BOOTING
	turret_next_state = TurretState.CALC_AIMING

func _on_attack_range_body_exited(_body: Node2D) -> void:
	"""
	Set Turret inactive once Player exits attack range
	"""
	f_player_in_range = false
	turret_curr_state = TurretState.INACTIVE

func _on_timer_timeout() -> void:
	"""
	Set Turret next state on timeout
	"""
	if (
			f_player_in_range and
			not turret_next_state == TurretState.NA
		):
		# Only set state if Player still in Turret attack range
		turret_curr_state = turret_next_state
		turret_next_state = TurretState.NA

