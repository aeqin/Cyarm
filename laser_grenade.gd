extends CharacterBody2D

### Components
@onready var c_sprite : AnimatedSprite2D = $LaserGrenadeSprite
@onready var c_collider : CollisionShape2D = $LaserGrenadeCollider
@onready var c_raycast_laser : RayCast2D = $LaserCast
@onready var c_line_laser: Line2D = $LaserSprite
@onready var c_timer_laser_active : Timer = $LaserActiveTimer
@onready var c_timer_laser_indicator_blink : Timer = $LaserIndicatorBlinkTimer
@onready var c_timer_laser_launch_duration : Timer = $LaunchDuration
@onready var c_timer_laser_enable_collider : Timer = $EnableColliderTimer

### State
enum LaserState {LAUNCHING, INDICATING, LASERING,}
var curr_laser_state : LaserState = LaserState.LAUNCHING
var laser_state_as_str : String:
	get:
		return LaserState.keys()[curr_laser_state]

### Laser
var f_laser_indicator_active : bool = true
var f_laser_active : bool = false
var laser_max_len : float = 1000.0
var laser_curr_len : float
var laser_end_point : Vector2
var laser_INactive_color : Color = Color("#a62d3764")
var laser_active_color : Color = Globals.CY_RED
var laser_until_activate_duration : CVP_Duration = CVP_Duration.new(1.4, true, c_timer_laser_active) # How long until laser activates
var laser_indicator_blink_duration : CVP_Duration = CVP_Duration.new(laser_until_activate_duration.val / 9, true, c_timer_laser_indicator_blink)

### Launch
var launch_speed : CVP_Speed = CVP_Speed.new(0.0, false)
var launch_ang_speed : CVP_Speed = CVP_Speed.new(0.0, false)
var launch_duration : CVP_Duration = CVP_Duration.new(0.5, true, c_timer_laser_launch_duration) # How long LaserGrenade moves with launch
var enable_collider_duration : CVP_Duration = CVP_Duration.new(0.1, true, c_timer_laser_enable_collider) # How long before LaserGrenade enables collider

### Spin
var f_can_spin : bool = false
var start_rot : float
var travelled_ang : float = 0
var curr_ang_speed : CVP_Speed = CVP_Speed.new(0.0, false)
var ang_accel : CVP_Acceleration = CVP_Acceleration.new(0.001)

### Movement
var f_begin_damping : bool = false
var damping_scalar : float = 0.89

### Damage
var o_laser_damage : DamageManager.DamageBase
var damaged_dict : Dictionary = {} # Hold a dictionary of {Ref -> time of hit}, so that Laser doesn't "hit" the same target multiple times in quick succession
var damage_mtick_cooldown : int = 550 # How many milliseconds can pass before laser can hit the same target again

### Collisions
var creator : Node = self: # Who created this particular LaserGrenade
	set(new_creator):
		if not creator == self:
			push_warning("Attempting to assign already assigned creator, ", creator, " to ", self)
		else:
			creator = new_creator

func _ready() -> void:
	## Subscribe to signals

	## Set timers
	c_timer_laser_active.wait_time = laser_until_activate_duration.val
	c_timer_laser_indicator_blink.wait_time = laser_indicator_blink_duration.val
	c_timer_laser_launch_duration.wait_time = launch_duration.val
	c_timer_laser_enable_collider.wait_time = enable_collider_duration.val

	## Set raycasts
	c_raycast_laser.target_position.x = laser_max_len
	c_collider.disabled = true
	
	## Set sprites
	c_line_laser.visible = false # Laser OFF at start
	c_line_laser.default_color = laser_INactive_color # Default color is laser indicator color

func _process(_delta: float) -> void:
	# Draw the laser
	if f_laser_active or f_laser_indicator_active:
		c_line_laser.clear_points()
		c_line_laser.add_point(c_raycast_laser.position)
		c_line_laser.add_point(to_local(laser_end_point))
	else:
		c_line_laser.clear_points()

func _physics_process(_delta: float) -> void:
	# Calculate laser end_point
	calc_laser_end_point()
	
	match curr_laser_state:
		LaserState.LAUNCHING:
			# Launch LaserGrenade in a direction, spinning until landing on a random angle
			spin_constant()
		LaserState.INDICATING:
			# Blink the laser indicator handled in _on_laser_indicator_blink_timer_timeout()
			pass
		LaserState.LASERING:
			# Activate the laser and spin it around, doing damage if possible
			calc_laser_hit() # Calculate laser hit
			spin_and_accelerate()
	
	if f_begin_damping:
		apply_damping()
	
	# Move
	move_and_slide()

func spawn(_creator : Node, o_damage : DamageManager.DamageBase, pos : Vector2, dir : Vector2, dist : float) -> void:
	"""
	Spawn LaserGrenade
	_creator : Node -- the Node that created this LaserGrenade
	_damage : int -- how much damage this LaserGrenade should do
	pos : Vector2 -- what position to spawn in
	dir : Vector2 -- what direction is the LaserGrenade launched in
	dist : float -- how far LaserGrenade should be launched
	"""
	# Spawn LaserGrenade at right position and orientation
	global_position = pos
	rotation = dir.angle() # Spawn with launch angle

	# Launch LaserGrenade in a direction, for distance
	launch(dir, dist)
	
	# Set creator and damage
	creator = _creator
	o_laser_damage = o_damage

func launch(dir : Vector2, dist : float) -> void:
	"""
	Launch LaserGrenade

	dir : Vector2 -- what direction is the LaserGrenade launched in
	dist : float -- how far LaserGrenade should be launched
	"""
	# Set launch speed of LaserGrenade to travel given distance in given time
	launch_speed.set_both(dist / launch_duration.val)
	velocity = dir * launch_speed.val
	
	# Set angular velocity of LaserGrenade, so that it makes a full rotation and then some, before firing the laser
	var _start_laser_angle : float = Globals.random.randf_range(0, TAU)
	var _ang_speed_b4_laser : float = ((TAU + _start_laser_angle) / launch_duration.val) * get_physics_process_delta_time()
	launch_ang_speed.set_both(_ang_speed_b4_laser)
	
	# Set timer for how long launch lasts
	c_timer_laser_launch_duration.start()
	c_timer_laser_enable_collider.start() # Timer to enable c_collider
	
	# Set state
	curr_laser_state = LaserState.LAUNCHING

func activate_laser() -> void:
	"""
	Set attributes as laser is activated
	"""
	c_line_laser.default_color = laser_active_color
	f_laser_active = true
	f_can_spin = true
	curr_laser_state = LaserState.LASERING

func calc_laser_end_point() -> void:
	"""
	Calculates the end point of the laser to draw
	"""
	if c_raycast_laser.is_colliding():
		laser_end_point = c_raycast_laser.get_collision_point()
	else:
		laser_end_point = c_raycast_laser.to_global(c_raycast_laser.target_position)

func calc_laser_hit() -> void:
	"""
	Calculates whether laser hit any target, and does damage
	"""
	# Do damage to the body that laser hit
	if c_raycast_laser.is_colliding():
		var _hit_body : Node = c_raycast_laser.get_collider()
		if Utilities.is_damageable(_hit_body):
			
			# Calculate if laser can hit this target
			var _can_hit : bool = true
			if damaged_dict.has(_hit_body):
				# Make sure that laser doesn't "hit" the same target multiple times in quick succession
				if Time.get_ticks_msec() - damaged_dict[_hit_body] < damage_mtick_cooldown:
					_can_hit = false

			# Do damage
			if _can_hit:
				var _dmg_result : DamageManager.DamageResult = DamageManager.calc_damage(o_laser_damage, _hit_body) # Do damage
				
				if _dmg_result != DamageManager.DamageResult.IGNORE:
					damaged_dict[_hit_body] = Time.get_ticks_msec() # Save the time of this hit

func spin_constant() -> void:
	"""
	Launch the LaserGrenade, and spin it (constant)
	"""
	rotation += launch_ang_speed.val
	
func spin_and_accelerate() -> void:
	"""
	Spin the laser (accelerating)
	"""
	curr_ang_speed.set_both(curr_ang_speed.val + ang_accel.val)
	rotation += curr_ang_speed.val
	
	travelled_ang += abs(curr_ang_speed.val)
	if travelled_ang >= TAU + 0.06: # One full rotation + a lil extra
		die()

func die() -> void:
	"""
	Destroys the LaserGrenade after it completes one revolution
	"""
	call_deferred("queue_free")

######################
## Movement functions
######################
func override_vel(new_velocity : Vector2):
	"""
	Overrides the old velocity with new value pair
	
	new_velocity : Vector2 -- new velocity
	"""
	velocity = new_velocity
	
	# override_vel() will be called by some other Node, such as Cyarm-Shield, so begin damping movement
	f_begin_damping = true

func get_middlepos() -> Vector2:
	"""
	Returns : Vector2 -- the global_position of the LaserGrenade, at the middle of its sprite
	"""
	return c_collider.global_position

func apply_damping() -> void:
	"""
	Dampens LaserGrenade movement over time, so an impulse won't have them flying off forever
	"""
	override_vel(velocity * damping_scalar * Globals.time_scale) # Move velocity towards 0 every frame

##################
## Received Signals
##################
func _on_launch_duration_timeout() -> void:
	"""
	On launch end
	"""
	velocity = Vector2.ZERO

	# Activate laser
	c_line_laser.visible = true
	c_timer_laser_active.start()
	c_timer_laser_indicator_blink.start()
	
	# Set state
	curr_laser_state = LaserState.INDICATING

func _on_laser_indicator_blink_timer_timeout() -> void:
	"""
	Blink laser indicator
	"""
	if not curr_laser_state == LaserState.INDICATING:
		return
	else:
		# Make next interval before blink slightly shorter
		f_laser_indicator_active = not f_laser_indicator_active
		c_timer_laser_indicator_blink.wait_time = c_timer_laser_indicator_blink.wait_time * 0.9
		c_timer_laser_indicator_blink.start()

func _on_laser_active_timer_timeout() -> void:
	"""
	Activate laser 
	"""
	activate_laser()

func _on_enable_collider_timer_timeout() -> void:
	"""
	Enable collider a bit after launch, else LaserGrenade might get stuck in LaserGrenadeLauncher
	"""
	c_collider.disabled = false
