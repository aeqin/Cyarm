extends CharacterBody2D
class_name ParticleSpawner

### Components
@onready var c_sprite : AnimatedSprite2D = $Sprite
@onready var c_collider_dust : CollisionShape2D = $DustCollider
@onready var c_raycast_findground : RayCast2D = $FindSurfaceCast
@onready var c_particles_explosion : GPUParticles2D = $ExplosionFolder/ExplosionParticles
@onready var c_particles_smoke : GPUParticles2D = $ExplosionFolder/SmokeParticles
@onready var c_particles_sickleshardpickup : GPUParticles2D = $SickleShardPickup

### Particle variables
var f_free_when_done : bool = false
var c_particles_to_check : GPUParticles2D

### Movement variables
var f_physical : bool = false
var gravity_base_accel : CVP_Acceleration = CVP_Acceleration.new(32.1)
var gravity : Vector2 = Vector2.ZERO

func _ready() -> void:
	# Subscribe to signals
	Globals.connect("sig_globals_time_scale_changed", _on_received_globals_time_scale_changed)

	# May spawn when time is slowed
	c_sprite.speed_scale = Globals.time_scale
	c_particles_explosion.speed_scale = Globals.time_scale
	c_particles_smoke.speed_scale = Globals.time_scale
	
	# On ready, hide sprite
	c_sprite.visible = false
	
	# Display above Player
	z_index = Globals.player_z_index + 10

func _process(_delta: float) -> void:
	if f_free_when_done:
		if not c_particles_to_check.emitting:
			die() # Destroy node once particles are done emitting

func _physics_process(_delta: float) -> void:
	if f_physical:
		velocity += gravity
		move_and_slide() # Allow ParticleSpawner velocity to be modified (dust moving with moving platforms)

######################
## Main functions
######################
func make_physical() -> void:
	"""
	Makes ParticleSpawner "physical":
		Enables collider
		Enables velocity
	"""
	c_collider_dust.disabled = false
	f_physical = true

func spawn_rot_effect(pos : Vector2, rot : float, anim : String) -> void:
	"""
	Spawn rotate-able particle effect
	"""
	# Spawn at right position
	global_position = pos
	rotation = rot
	
	# Play specific hit animation
	play_anim(anim)

func spawn_dust(pos : Vector2, facing_dir_x : float, facing_dir_y : float, anim : String, ground_dir : Vector2) -> void:
	"""
	Spawn particle effect that displays on x OR y axis

	pos : Vector2 -- position of FX
	facing_dir_x : float -- x scale of FX sprite
	facing_dir_y : float -- y scale of FX sprite
	anim : String -- name of FX
	ground_dir : Vector2 -- direction of the "ground" that FX should be mindful of
	"""
	# Spawn at right position
	global_position = pos
	
	# Flip sprite
	scale = Vector2(facing_dir_x, facing_dir_y)
	z_index = 100
	visible = true

	# If the direction of the "ground" is provided, then modify position, collision, and "gravity"
	# so that the FX spawns and stays on the "ground"
	if ground_dir != Vector2.ZERO:
		make_physical() # Enable collider
		
		gravity = ground_dir * gravity_base_accel.val # Update "gravity" to point towards the "ground"
		
		# Point raycast towards "ground"
		c_raycast_findground.target_position = ground_dir * 50 # Arrow length
		c_raycast_findground.position = ground_dir * -5 # Arrow base start
		c_raycast_findground.force_raycast_update()
		if c_raycast_findground.is_colliding():
			global_position = c_raycast_findground.get_collision_point() # Teleport FX to "ground"
		else:
			# If there is no "ground" near FX, then don't spawn FX at all
			die()
			return
	
	# Play specific dust animation
	play_anim(anim)

func spawn_explosion(pos : Vector2, size : float) -> void:
	"""
	Spawn an explosion
	"""
	# Spawn at right position
	global_position = pos
	
	# Play explosion
	play_explode(size)

func spawn_sickle_shard_pickup(pos : Vector2) -> void:
	"""
	Spawn a explosion that indicates Player has picked up a CyarmSickleShard
	"""
	# Spawn at right position
	global_position = pos
	
	# Play explosion
	play_sickleshardpickup_effect()

func die() -> void:
	"""
	Destroys ParticleSpawner
	"""
	call_deferred("queue_free")

######################
## State & Animation functions
######################
func play_anim(anim_to_play : String) -> void:
	"""
	Sets sprite to be visible, then plays animation
	"""
	c_sprite.visible = true
	c_sprite.play(anim_to_play)

func play_explode(size : float) -> void:
	"""
	Sets explosion particles to be visible, then starts emitting
	"""
	(c_particles_explosion.process_material as ParticleProcessMaterial).scale_min = size / 100 * 2
	c_particles_explosion.emitting = true
	c_particles_smoke.emitting = true
	
	f_free_when_done = true # flag to free this node once particles are done
	c_particles_to_check = c_particles_smoke

func play_sickleshardpickup_effect() -> void:
	"""
	Plays effects when Player pickups CyarmSickleShard
	"""
	c_particles_sickleshardpickup.emitting = true
	
	f_free_when_done = true # flag to free this node once particles are done
	c_particles_to_check = c_particles_sickleshardpickup

##################
## Received Signals
##################
func _on_animated_sprite_2d_animation_finished() -> void:
	# Destroy ParticleSpawner after playing animation
	die()

func _on_received_globals_time_scale_changed(old_time_scale : float, new_time_scale : float) -> void:
	"""
	Adjust ParticleSpawner time-sensitive attributes to reflect timescale
	"""
	var _ts : float = new_time_scale
	var _ratio : float = old_time_scale / _ts

	# Speeds
	
	# Accelerations

	# Durations
	
	# Animation Speed
	c_sprite.speed_scale = _ts
	c_particles_explosion.speed_scale = _ts
	c_particles_smoke.speed_scale = _ts
	c_particles_sickleshardpickup.speed_scale = _ts
  
