extends StaticBody2D

### Signals
signal sig_world_spawn_laser_grenade(_creator : Node, _damage : DamageManager.DamageBase, pos : Vector2, dir : Vector2, dist : float)

### Components
@onready var c_sprite : AnimatedSprite2D = $LauncherSprite
@onready var c_progress_1 : TextureProgressBar = $LauncherSprite/Progress1
@onready var c_progress_2 : TextureProgressBar = $LauncherSprite/Progress2
@onready var c_collider : CollisionShape2D = $LauncherCollider
@onready var c_raycast_launch_dir : RayCast2D = $LauncherSprite/LaunchDirectionCast
@onready var c_particles_launch: GPUParticles2D = $LauncherSprite/LaunchParticles
@onready var c_timer_launch_duration : Timer = $LaunchTimer

### State & Animation
enum LauncherState {IDLING, INDICATING, LAUNCHING,}
var curr_launcher_state : LauncherState = LauncherState.LAUNCHING
var launcher_state_as_str : String:
	get:
		return LauncherState.keys()[curr_launcher_state]
var anim_idle : String = "idle"
var anim_launch : String = "launch"

### Launch
var launch_wait_duration : CVP_Duration = CVP_Duration.new(5.0, true, c_timer_launch_duration)
var launch_distance : float = 100
var o_laser_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 20)

func _ready() -> void:
	## Subscribe to signals

	## Set timers
	c_timer_launch_duration.wait_time = launch_wait_duration.val
	c_timer_launch_duration.start() # Wait until launch

func _process(_delta: float) -> void:
	# Display how much time until launching LaserGrenade
	c_progress_1.value = c_progress_1.max_value * (1 - c_timer_launch_duration.time_left / c_timer_launch_duration.wait_time)
	c_progress_2.value = c_progress_2.max_value * (1 - c_timer_launch_duration.time_left / c_timer_launch_duration.wait_time)

func _physics_process(_delta: float) -> void:
	pass

func spawn(pos : Vector2, dir : Vector2) -> void:
	"""
	Spawn LaserGrenadeLauncher
	pos : Vector2 -- what position to spawn in
	dir : Vector2 -- what direction is the LaserGrenadeLauncher pointed in
	"""
	global_position = pos # Position
	rotation = dir.angle() + PI/2 # Point the LaserGrenadeLauncher in the direction the tile is orientated in
	c_timer_launch_duration.start() # Wait until launch

func launch_begin() -> void:
	"""
	Begin launch
	"""
	c_sprite.play(anim_launch) # Open animation
	c_particles_launch.emitting = true # Emit particles of smoke

func launch() -> void:
	"""
	Launch the LaserGrenade
	"""
	var _launch_dir : Vector2 = (c_raycast_launch_dir.to_global(c_raycast_launch_dir.target_position) - global_position).normalized()
	
	# Signal World to spawn LaserGrenade
	sig_world_spawn_laser_grenade.emit(self, o_laser_damage, global_position, _launch_dir, launch_distance)
	
	# Close the doors
	c_sprite.play_backwards(anim_launch)
	
	# Wait until ready to launch again
	c_timer_launch_duration.start()

func is_on_screen() -> bool:
	"""
	Returns : bool -- whether LaserLauncher is currently visible on screen
	"""
	return Globals.viewport_rect.has_point(get_global_transform_with_canvas().origin)

func _on_launch_timer_timeout() -> void:
	"""
	When Timer done, begin LaserGrenade launch sequence
	"""
	# Only launch LaserGrenade if LaserGrenadeLauncher is on screen, otherwise begin timer again
	if is_on_screen():
		launch_begin()
	else:
		c_timer_launch_duration.start()

func _on_launcher_sprite_animation_finished() -> void:
	"""
	When animation is done, actually launch LaserGrenade
	"""
	if c_sprite.animation == anim_launch and c_timer_launch_duration.is_stopped():
		launch()
