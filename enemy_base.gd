extends CharacterBody2D
class_name EnemyBase # Enemy base class

### Signals
signal sig_world_spawn_explosion(pos : Vector2, size : float)
signal sig_enemy_pull_reached()

### External Scenes


### Components
@onready var c_node_HP_bundle : Node2D = $HPPosNScale
@onready var c_animplayer : AnimationPlayer = $AnimationPlayer
@onready var c_area_explode_on_toss : Area2D = $ExplodeOnTossHitbox
var c_collider : CollisionShape2D
var c_collider_explode_on_toss : CollisionShape2D
@onready var c_shapecast_explosion : ShapeCast2D = $ExplosionHitcast
@onready var c_raycast_left : RayCast2D = $Raycasts/WallCasts/LeftCast
@onready var c_raycast_right : RayCast2D = $Raycasts/WallCasts/RightCast
@onready var c_raycast_ground_left : RayCast2D = $Raycasts/GroundCasts/GroundLeft
@onready var c_raycast_ground_right : RayCast2D = $Raycasts/GroundCasts/GroundRight
@onready var c_raycast_player_lineofsight : RayCast2D = $Raycasts/PlayerLineOfSightCast
@onready var c_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var c_sprite_status : AnimatedSprite2D = $HPPosNScale/StatusIcon
@onready var c_label : Label = $Label
@onready var c_progress_hp : TextureProgressBar = $HPPosNScale/HP
@onready var c_timer_invincible : Timer = $Timers/InvincibleTimer
@onready var c_timer_explode : Timer = $Timers/ExplodeTimer
@onready var c_timer_hang : Timer = $Timers/HangTimer

### Shaders
var material_hit : ShaderMaterial
@onready var shader_hit = preload("res://scripts/shaders/hit.gdshader")

### Status
enum EnemyStatus {NONE, CAN_BE_HIT, STAGGERED,}
var enemy_curr_status : EnemyStatus = EnemyStatus.NONE
var enemy_curr_status_as_str : String:
	get:
		return EnemyStatus.keys()[enemy_curr_status]
var f_status_staggered : bool = false
var f_status_can_be_hit : bool = false
var label_start_pos : Vector2

### Damage variables
var f_already_dead : bool = false
var f_invincible : bool = false
var killer : Node
var health : float = 100:
	set(newHealth):
		health = newHealth
		c_progress_hp.value = health # Update HP bar
var no_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 0)

### Movement Variables
@export var f_debug_control : bool = false 
var f_is_grounded : bool
var f_in_control : bool = true # Should the Enemy move on its own?
var f_apply_gravity : bool = true
var f_apply_friction : bool = true
@export var left_or_right : int = 1 # GUARENTEED to be either -1 or 1
var curr_direction : float = 1.0:
	set(newDir):
		if not is_equal_approx(curr_direction, newDir): # Only set if curr_direction changes
			curr_direction = newDir
			if curr_direction: # Only left or right
				left_or_right = sign(curr_direction) # Always -1 or 1
				change_direction() # Flips raycasts

const MAX_MASS = 1000
const DEFAULT_MASS = 100
var mass : float = DEFAULT_MASS
var curr_x_friction: CVP_Acceleration:
	get:
		if f_is_grounded:
			return grnd_x_friction
		else:
			return air_x_friction
var grnd_x_friction : CVP_Acceleration
var air_x_friction : CVP_Acceleration
var curr_y_friction : CVP_Acceleration
var max_fall_speed : CVP_Speed
var gravity : CVP_Acceleration
var damping : CVP_Acceleration
var hang_time_duration : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_hang)

### Raycast variables
var player_lineofsight_len : float = 400

### Explode when die variables
var f_explode_when_die : bool = true
var f_explode_indicator_full : bool = false
var f_explode_ready : bool = false:
	get:
		return c_timer_explode.wait_time < 0.01 # Interval between explosion flashes
var f_exploded : bool = false # Did Enemy already explode?
var explode_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 9999)
var explode_radius : float = 70.0
var explode_next_tick_scale : float = 0.9 # The next explosion interval is this much of the previous
var explode_start_duration : CVP_Duration = CVP_Duration.new(0.4)

### MoveOnRails (class to hold related movement vars together)
var o_move_onrails : MoveOnRails

func _ready() -> void:
	## Subscribe to signals
	
	## Start at max HP, and hide HP bar
	c_progress_hp.max_value = health
	c_progress_hp.value = health
	c_progress_hp.visible = false
	c_sprite_status.visible = false
	# Display HP bar above Enemy based on collider size
	var _y_pos : float = (-1 * (c_collider.shape as RectangleShape2D).size.y / 2) + c_collider.position.y / 2
	c_node_HP_bundle.global_position = get_middlepos() + Vector2(0, _y_pos)
	c_node_HP_bundle.rotation = rotation # Rotate so HP bar is always horizontal
	
	## Set movement variables depending on "mass"
	grnd_x_friction = CVP_Acceleration.new(10.0 + 20 * (mass / DEFAULT_MASS))
	air_x_friction = CVP_Acceleration.new(7.0 + 20 * (mass / DEFAULT_MASS))
	curr_y_friction = CVP_Acceleration.new(6.0 + 20 * (mass / DEFAULT_MASS))
	max_fall_speed = CVP_Speed.new(350.0 + 350 * (mass / DEFAULT_MASS))
	gravity = CVP_Acceleration.new(40.0 * (mass / DEFAULT_MASS)) # More gravity with bigger mass, less with less
	
	## Set timers
	c_timer_hang.wait_time = hang_time_duration.val
	
	## Set raycasts
	c_shapecast_explosion.global_position = get_middlepos()
	c_shapecast_explosion.shape.radius = explode_radius
	
	## Set up shader
	material_hit = ShaderMaterial.new()
	material_hit.shader = shader_hit

	## Create Objects
	o_move_onrails = MoveOnRails.new(self)
	o_pull_bundle = PullBundle.new()
	
	## Set current direction
	curr_direction = left_or_right

func _process(_delta: float) -> void:
	if f_in_control:
		# Animations
		update_animations()

func _physics_process(delta: float) -> void:
	if f_debug_control:
		# Control a single Enemy with arrow keys for debugging (enable with checkbox in inspector)
		var input_direction = Input.get_vector("left", "right", "up", "down")
		velocity = input_direction * 300.0
		f_in_control = false
	
	# Update Enemy movement flags for this frame
	update_physics_flags()

	# Status
	update_status()

	# States
	if f_in_control:
		calc_physics_state_decision()
	
	# Move Enemy
	if o_move_onrails.is_active():
		move_onrails(delta)
	else:
		if f_in_control:
			apply_gravity()
			apply_friction()

		move_and_slide() # Move Enemy using velocity attribute

func update_physics_flags() -> void:
	"""
	Update Enemy flags for this physics frame
	"""
	# Flags
	f_is_grounded = is_on_floor()

func SETUP_colliders() -> void:
	"""
	Sets up additional colliders depending on Enemy base collider
	"""
	if c_collider:
		# Make additional collider match up shape and size with base collider
		var _rect : RectangleShape2D = c_collider.shape.duplicate()
		c_collider_explode_on_toss = CollisionShape2D.new()
		c_collider_explode_on_toss.shape = _rect
		c_collider_explode_on_toss.position = c_collider.position
		c_area_explode_on_toss.add_child(c_collider_explode_on_toss)

######################
## Movement functions
######################
func override_vel(new_velocity : Vector2):
	"""
	Overrides the old velocity with new value pair
	
	new_velocity : Vector2 -- new velocity
	"""
	velocity = new_velocity

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

func change_direction(new_dir : float = left_or_right) -> void:
	"""
	Changes Enemy facing direction
	"""
	c_sprite.flip_h = new_dir < 0

func will_walk_into_wall() -> bool:
	"""
	Returns : bool -- whether or not Enemy will walk into a wall
	"""
	return ((c_raycast_left.is_colliding() and curr_direction < 0)
			or
			(c_raycast_right.is_colliding() and curr_direction > 0))

func will_walk_off_ledge() -> bool:
	"""
	Returns : bool -- whether or not Enemy will walk off a ledge
	"""
	return ((not c_raycast_ground_left.is_colliding() and curr_direction < 0)
			or
			(not c_raycast_ground_right.is_colliding() and curr_direction > 0))

func get_dist_to_player(use_center : bool = true) -> float:
	"""
	Returns : float -- the distance to the Player
	
	use_center : bool = true -- whether to use the center of Player sprite, or position at base
	"""
	var _p_pos : Vector2 = Globals.player_center_pos if use_center else Globals.player_pos
	return global_position.distance_to(_p_pos)

func get_x_dist_to_player(use_center : bool = true) -> float:
	"""
	Returns : float -- the x distance to the Player
	
	use_center : bool = true -- whether to use the center of Player sprite, or position at base
	"""
	var _p_pos : Vector2 = Globals.player_center_pos if use_center else Globals.player_pos
	return _p_pos.x - global_position.x

func get_y_dist_to_player(use_center : bool = true) -> float:
	"""
	Returns : float -- the y distance to the Player
	
	use_center : bool = true -- whether to use the center of Player sprite, or position at base
	"""
	var _p_pos : Vector2 = Globals.player_center_pos if use_center else Globals.player_pos
	return _p_pos.y - global_position.y

func get_dir_to_player(use_center : bool = true) -> Vector2:
	"""
	Returns : Vector2 -- the unit vector that points from Enemy to Player
	"""
	var _p_pos : Vector2 = Globals.player_center_pos if use_center else Globals.player_pos
	return (_p_pos - global_position).normalized()

func get_x_dir_to_player(use_center : bool = true) -> float:
	"""
	Returns : float -- whether the Player is to the left (-1) or to the right (1) of the Enemy
	"""
	return sign(get_x_dist_to_player(use_center))

func get_y_dir_to_player(use_center : bool = true) -> float:
	"""
	Returns : float -- whether the Player is above (-1) or below (1) the Enemy
	"""
	return sign(get_y_dist_to_player(use_center))

func is_player_in_sight() -> bool:
	"""
	Returns : bool -- whether Enemy has line of sight with Player (not blocked by Terrain)
	"""
	c_raycast_player_lineofsight.target_position = get_dir_to_player() * player_lineofsight_len
	return Utilities.is_player(c_raycast_player_lineofsight.get_collider())

func get_middlepos() -> Vector2:
	"""
	Returns : Vector2 -- the global_position of the Enemy, at the middle of its sprite
	"""
	return c_collider.global_position

func apply_friction() -> void:
	"""
	Dampens Enemy movement over time, so an impact won't have them flying off forever
	"""
	if not f_apply_friction:
		return

	override_vel_x(move_toward(velocity.x, 0.0, curr_x_friction.val)) # Move X velocity towards 0 every frame
	override_vel_y(move_toward(velocity.y, 0.0, curr_y_friction.val)) # Move Y velocity towards 0 every frame

func apply_gravity() -> void:
	"""
	Makes Enemy fall down
	"""
	if not f_apply_gravity:
		return

	# Falling by gravity
	add_vel(Vector2(0, gravity.val))

	## Terminal fall velocity
	if velocity.y > max_fall_speed.val:
		override_vel_y(max_fall_speed.val)

# Class used to store related Pull attributes together
var o_pull_bundle : PullBundle
class PullBundle:
	var f_is_being_pulled : bool = false
	var initial_speed : float
	var max_speed : float
	var midpoint : Vector2
	var endpoint : Vector2
	var initial_dist_midpoint : float
	var initial_dist_endpoint : float
	var initial_dir_to_midpoint : Vector2

	func _init(): pass

	func begin_pull(
				_initial_speed : float, _max_speed : float,
				_midpoint : Vector2, _endpoint : Vector2,
				_initial_dist_midpoint : float, _initial_dist_endpoint : float, _initial_dir_to_midpoint : Vector2
			):
		initial_speed = _initial_speed
		max_speed = _max_speed
		midpoint = _midpoint
		endpoint = _endpoint
		initial_dist_midpoint = _initial_dist_midpoint
		initial_dist_endpoint = _initial_dist_endpoint
		initial_dir_to_midpoint = _initial_dir_to_midpoint
		f_is_being_pulled = true
	
	func done_pull() -> void:
		f_is_being_pulled = false

func pull_me(dir_to_be_pulled_in : Vector2, distance_to_pull : float, initial_speed : float, max_speed : float, midpoint_progress : float = 1.0) -> void:
	"""
	Pulls Enemy towards position
	
	dir_to_be_pulled_in : Vector2 -- direction to pull Enemy in
	distance_to_pull : float -- ideal distance to pull Enemy for
	initial_speed : float -- how fast to start pulling Enemy
	max_speed : float -- fastest speed to pull Enemy
	midpoint_progress : float = 1.0 -- the "midpoint", percentage-wise, of progress needed before
										switching accelerating pull to decelerating pull (speed
										up Enemy until "midpoint", then slow down Enemy until
										reaching endpoint)
	"""
	var _midpoint : Vector2 = global_position + dir_to_be_pulled_in * distance_to_pull * midpoint_progress
	var _endpoint : Vector2 = global_position + dir_to_be_pulled_in * distance_to_pull
	var _initial_dist_midpoint : float = global_position.distance_to(_midpoint)
	var _initial_dist_endpoint : float = _midpoint.distance_to(_endpoint)
	var _initial_dir_to_midpoint : Vector2 = (_midpoint - global_position).normalized()
	
	# Cleanup move-on-rails object (in case Enemy was mid-pull)
	o_move_onrails.cleanup()
	
	# Store pull attributes, then begin the actual pull routine
	o_pull_bundle.begin_pull(initial_speed, max_speed, _midpoint, _endpoint, _initial_dist_midpoint, _initial_dist_endpoint, _initial_dir_to_midpoint)
	o_move_onrails.begin_for_distance(dir_to_be_pulled_in, distance_to_pull, initial_speed)

func sicklepull_me(vel_to_add : Vector2) -> void:
	"""
	Remove control from Enemy
	
	vel_to_add : Vector2 -- value pair to add to the current velocity
	"""
	freeze() # Remove control from Enemy
	
	# If Enemy is about to explode, make it easier for Player to toss them further
	if f_already_dead:
		vel_to_add *= 1.5

	add_vel(vel_to_add)
	
func sicklepull_end(do_hangtime : bool = false) -> void:
	"""
	Return control back to Enemy
	
	do_hangtime : bool -- whether or not to give Enemy some hangtime after being Sicklepulled
	"""
	if do_hangtime:
		c_timer_hang.start()
	else:
		unfreeze()

func freeze(zero_vel : bool = false) -> void:
	"""
	Remove control from Enemy
	"""
	f_in_control = false
	c_sprite.pause()
	c_animplayer.pause()
	
	if zero_vel:
		override_vel(Vector2.ZERO)
	
func unfreeze() -> void:
	"""
	Return control back to Enemy
	"""
	f_in_control = true
	c_sprite.play()
	c_animplayer.play()

func move_onrails(delta : float) -> void:
	"""
	Moves Enemy
	Handles calculations using Enemy's MoveOnRails object (o_move_onrails)

	delta : float -- time between physics frames
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		_o_r.RAIL_TYPE.TO_TARGET:
			## Move Enemy to target position
			global_position = global_position.move_toward(_o_r.move_onrails_target,
														  _o_r.move_onrails_speed.val * delta)

			move_onrails_during() # Perform Enemy mode-specific actions DURING move to target

			## Reached target position
			if global_position == _o_r.move_onrails_target:
				velocity = Vector2.ZERO # Freeze Enemy

				move_onrails_after() # Perform Enemy mode-specific actions AFTER reaching target

				_o_r.cleanup() # Cleanup this particular move-on-rails

		## Move Enemy for distance, respecting collision
		_o_r.RAIL_TYPE.FOR_DISTANCE:
			var _distance_this_frame : float # Distance Enemy would move this frame
			var _distance_left : float # How much distance left to move "for distance"
			var _speed_this_frame : float = _o_r.move_onrails_speed.val
			var _o_pb : PullBundle = o_pull_bundle
			
			if _o_pb.f_is_being_pulled:
				# Have Enemy speed up to midpoint, then slow down to endpoint
				var _dir_to_midpoint : Vector2 = (_o_pb.midpoint - global_position).normalized()
				if (_dir_to_midpoint).dot(_o_pb.initial_dir_to_midpoint) > 0:
					# Speed up
					var _speed_up_progress : float = 1.0 - (global_position.distance_to(_o_pb.midpoint) / _o_pb.initial_dist_midpoint) # Goes towards 1
					_speed_this_frame = _o_pb.initial_speed + ((_o_pb.max_speed - _o_pb.initial_speed) * _speed_up_progress)
				else:
					# Slow down
					var _slow_down_progress : float = 0.1 + (global_position.distance_to(_o_pb.endpoint)) / _o_pb.initial_dist_endpoint # Goes towards 0.1 (going to 0 is too slow)
					_speed_this_frame = _o_pb.max_speed * _slow_down_progress
			
			# Every frame, set Enemy velocity to the calculated distance
			override_vel(_o_r.move_onrails_target * _speed_this_frame)
			_distance_this_frame = velocity.length() * delta

			# If Enemy would move past the endpoint in a single frame, reduce speed to reach endpoint this frame
			if _distance_this_frame > _o_r.move_onrails_dist_left:
				var endpoint : Vector2 = global_position + (_o_r.move_onrails_target * _o_r.move_onrails_dist_left)
				override_vel((endpoint - global_position) / delta)
				_distance_this_frame = velocity.length() * delta
			
			## During move-on-rails
			move_onrails_during() # Actions to perform DURING move to target
			_distance_left = _o_r.move_onrails_dist_left - _distance_this_frame
			_o_r.move_onrails_dist_left = _distance_left # Update distance left

			## Done
			if _distance_left <= 0.01 or Utilities.approx_equal_vec2(velocity, Vector2.ZERO):
				# Consider done, if reached there, or if velocity is zero
				# Travelled for specified distance
				move_onrails_after() # Perform Cyarm mode-specific actions AFTER reaching target

func move_onrails_during() -> void:
	"""
	Actions to perform during a move-on-rails 
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		## Move Enemy to target position, ignoring collision
		_o_r.RAIL_TYPE.TO_TARGET:
			pass

		## Move Enemy to target position, respecting collision
		_o_r.RAIL_TYPE.FOR_DISTANCE:
			move_and_slide()

func move_onrails_after() -> void:
	"""
	Actions to perform after a move-on-rails is complete
	"""
	var _o_r : MoveOnRails = o_move_onrails
	match _o_r.move_onrails_type:
		## Move Enemy to target position, ignoring collision
		_o_r.RAIL_TYPE.TO_TARGET:
			pass

		## Move Enemy to target position, respecting collision
		_o_r.RAIL_TYPE.FOR_DISTANCE:
			o_pull_bundle.done_pull()
			sig_enemy_pull_reached.emit() # Signal emitted that Enemy has reached position after pull

	# Cleanup move-on-rails object
	_o_r.cleanup()

######################
## Attack/Damage functions
######################
func get_mbody_collider() -> CollisionShape2D:
	"""
	Returns : CollisionShape2D -- the main body's collider
	"""
	return c_collider

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Enemy currently does
	"""
	assert(false, "Override me in children.")
	return no_damage

func get_defense_modifier() -> float:
	"""
	Returns : float -- the amount of damage Enemy takes modifier
	"""
	if f_status_staggered:
		return 2.0 # Take twice as much damage
	else:
		return 1.0 # Take normal damage

func damage_me(damage : int, _damage_dir : Vector2) -> DamageManager.DamageResult:
	"""
	Handles damage dealt TO Enemy
	
	damage : int -- damage to be dealt
	_damage_dir : Vector2 -- direction of damage dealt
	
	Returns : DamageManager.DamageResult -- the result of the damage
	"""
	if f_invincible:
		DamageManager.DamageResult.IGNORE # Take no damage if Enemy is invincible
	
	if not f_already_dead:
		# Do damage
		health -= damage
		if health <= 0:
			begin_death_sequence() # Die
			return DamageManager.DamageResult.DEATH

		# On hit, make Enemy invincible for a bit
		flash(Color.WHITE) # Flash white for feedback
		f_invincible = true
		c_timer_invincible.start()

	else: # Enemy is already dead
		begin_death_sequence() # So prime explosion
		
	return DamageManager.DamageResult.SUCCESS

func do_damage_to(hit_body : Node2D, damage : DamageManager.DamageBase = get_damage()) -> DamageManager.DamageResult:
	"""
	Does damage to subject
	
	hit_body : Node2D -- subject that can possibly take damage
	
	Returns : DamageManager.DamageResult -- the result of the damage
	"""
	return DamageManager.calc_damage(damage, hit_body)

func do_explode_and_damage():
	"""
	Before Enemy is destroyed, explode and damage surroundings that can be damaged
	"""
	if f_exploded:
		# If already exploded, prevent infinite recursion by exploding alongside another exploding Enemy nearby
		return
	else: f_exploded = true

	# Enable explosion cast
	c_shapecast_explosion.enabled = true
	c_shapecast_explosion.force_shapecast_update()
	
	# For every Node affected by damage, do damage to it
	for collision_dict in c_shapecast_explosion.collision_result:
		var _enemy_ref : Node = collision_dict["collider"]
		do_damage_to(_enemy_ref, explode_damage)
		
	# Spawn explosion particles where Enemy dies
	sig_world_spawn_explosion.emit(get_middlepos(), explode_radius)

func parry_me() -> void:
	"""
	Handles Enemy being parried by Player
	"""
	assert(false, "Override me in children.")

func flash(flash_color : Color, flash_intensity : float = 1.0) -> void:
	"""
	Recolors sprite with shader and sets Enemy to be invincible for a bit
	"""
	c_sprite.material = material_hit
	c_sprite.material.set_shader_parameter("color", flash_color) # Flash sprite
	c_sprite.material.set_shader_parameter("progress", flash_intensity)

func unflash() -> void:
	"""
	Reverts Enemy to default sprite colors
	"""
	c_sprite.material = material_hit
	c_sprite.material.set_shader_parameter("progress", 0) # Reset sprite to normal colors

func prime_explode() -> void:
	"""
	If not about to explode:
		start blinking Enemy sprite faster and faster until explosion
	If blinking already underway:
		explode immediately
	"""
	if c_timer_explode.is_stopped(): # Begin explosion countdown (Enemy sprite flashing)
		flash(Color.RED)
		f_explode_indicator_full = true
		c_timer_explode.start(explode_start_duration.val)
	elif not f_explode_ready: # Enemy was hit during explosion countdown (explode immediately)
		die()
	elif f_explode_ready: # Enemy explosion timer finshed counting down (explode naturally)
		die()

func begin_death_sequence() -> void:
	"""
	When Enemy HP reaches 0 or below, begin death sequence:
		1. Begin explode sequence
		2. Die
	"""
	if f_explode_when_die:
		prime_explode() # Begin explosion countdown, or, if already underway, speed it up
	else:
		die()

	# Pause animations and updating of states
	freeze(true)

	f_already_dead = true

func die():
	"""
	Handles death
	"""
	if f_explode_when_die:
		do_explode_and_damage() # On death, explode and damage surroundings

	# Destroy Enemy
	call_deferred("queue_free")

######################
## Enemy Status functions
######################
func show_exclamation(do_show : bool, start_pos : Vector2):
	"""
	Show an exclamation point
	
	do_show : bool -- whether to show or hide exclamation point
	start_pos : Vector2 -- start position of the exclamation point
	"""
	c_label.visible = do_show
	if do_show:
		c_label.text = "!"
		c_label.modulate = Color.RED
		
		var _grow_tween : Tween = create_tween()
		var _duration : float = 0.15 
		_grow_tween.set_ease(Tween.EASE_OUT).set_parallel(true)
		_grow_tween.tween_property(c_label, "scale", Vector2(1.2, 1.2), _duration).from(Vector2.ZERO)
		_grow_tween.tween_property(c_label, "position", start_pos + Vector2(0, -20), _duration).from(start_pos + Vector2(0, 15))
		_grow_tween.tween_callback(fall_exclamation.bind(start_pos)).set_delay(_duration)

func fall_exclamation(return_pos : Vector2):
	"""
	Make an exclamation point fall down
	
	return_pos : Vector2 -- position of the exclamation point to fall down and return to
	"""
	var _fall_tween = create_tween()
	var _duration : float = 0.08
	_fall_tween.set_ease(Tween.EASE_IN)
	_fall_tween.tween_property(c_label, "position", return_pos, _duration)

func update_status() -> void:
	"""
	Changes Enemy's status depending on flags
	"""
	var old_status : EnemyStatus = enemy_curr_status
	if f_status_staggered:
		enemy_curr_status = EnemyStatus.STAGGERED
	elif f_status_can_be_hit:
		enemy_curr_status = EnemyStatus.CAN_BE_HIT
	else:
		enemy_curr_status = EnemyStatus.NONE
		
	if old_status != enemy_curr_status: # Enemy changed status, should show the change
		if enemy_curr_status == EnemyStatus.NONE:
			hide_status()
		else:
			show_status()

func show_status() -> void:
	"""
	Shows the Enemy HP bar and status icon
	"""
	# HP Bar
	c_progress_hp.visible = true
	
	# Status Icon
	if enemy_curr_status == EnemyStatus.NONE:
		c_sprite_status.visible = false
	else:
		c_sprite_status.visible = true
		match enemy_curr_status:
			EnemyStatus.CAN_BE_HIT:
				pass
			EnemyStatus.STAGGERED:
				c_sprite_status.play("staggered")

func hide_status() -> void:
	"""
	Hides the Enemy HP bar and status icon
	"""
	if not (c_progress_hp.value < c_progress_hp.max_value): # Haven't received damage
		c_progress_hp.visible = false # Don't hide if Enemy has received damage
	c_sprite_status.visible = false

func notify_can_be_hit(can_be_hit : bool) -> void:
	"""
	Called by other Nodes, to notify Enemy that it can be hit
	
	can_be_hit : bool -- whether Enemy can be hit
	"""
	f_status_can_be_hit = can_be_hit
	
######################
## State & Animation functions
######################
func calc_physics_state_decision() -> void:
	"""
	Calculates Enemy state every physics frame
	"""
	assert(false, "Override me in children.")

func update_animations() -> void:
	"""
	Updates animations
	"""
	assert(false, "Override me in children.")

##################
## Received Signals
##################
func _on_invincible_timer_timeout() -> void:
	"""
	Revert Enemy back to being able to be damaged
	"""
	unflash()
	f_invincible = false

func _on_hp_value_changed(_value: float) -> void:
	"""
	Enemy was damaged, so show HP bar
	"""
	c_progress_hp.visible = true

func _on_explode_timer_timeout() -> void:
	"""
	Blink Enemy, then explode when timer ends
	"""
	if f_explode_indicator_full:
		unflash()
	else:
		flash(Color.RED)
	f_explode_indicator_full = not f_explode_indicator_full
	
	if not f_explode_ready:
		c_timer_explode.wait_time = c_timer_explode.wait_time * explode_next_tick_scale
		c_timer_explode.start()
	else:
		die()

func _on_explode_on_toss_hitbox_body_entered(body: Node2D) -> void:
	"""
	When Enemy is about to explode (blinking), when thrown into another Enemy, immediately blow up
	"""
	if velocity.length_squared() > 1: # Needs to be thrown
		if not c_timer_explode.is_stopped():
			prime_explode()

func _on_hang_timer_timeout() -> void:
	"""
	Return control back to Enemy after some hangtime
	"""
	f_in_control = true
