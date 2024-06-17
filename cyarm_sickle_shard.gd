extends CharacterBody2D
#region Signals
signal sig_world_spawn_sickleshardpickup_effect(pos : Vector2)
#endregion


### Components
@onready var c_collider : CollisionShape2D = $SickleShardHitbox/SickleShardCollider
@onready var c_area_hitbox : Area2D = $SickleShardHitbox
@onready var c_sprite : AnimatedSprite2D = $SickleShardSprite
@onready var c_timer_lifetime : Timer = $LifetimeTimer

### Throw variables
var sickle_ref : CyarmSickle
var curr_throw_speed : CVP_Speed
var base_throw_speed : CVP_Speed = CVP_Speed.new(500.0)
var throw_direction : Vector2
var empowered_level : int

### Launch variables
var launch_speed : CVP_Speed = CVP_Speed.new(380.0)
var base_launch_sideways_speed : CVP_Speed = CVP_Speed.new(90.0)
var gravity_after_launch : CVP_Acceleration = CVP_Acceleration.new(12.1)

### Lifetime variables
var lifetime_duration : CVP_Duration = CVP_Duration.new(4.0, true, c_timer_lifetime) # How long the CyarmSickleShard lasts
var onhit_particles_duration : CVP_Duration = CVP_Duration.new(0.4, true) # How long the CyarmSickleShard lasts after hitting something

### Damage
var o_this_sickle_shard_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 0)

### State & Animations
enum ShardState {
	THROWING,
	BOUNCING,
	}
var shard_curr_state : ShardState = ShardState.THROWING
var shard_state_as_str : String:
	get:
		return ShardState.keys()[shard_curr_state]
var anim_shard_throw : String = "shard_throw"
var anim_shard_bounce : String = "shard_bounce"

func _ready() -> void:
	## Force node to subscribe to signals
	var _World : Node = get_tree().get_first_node_in_group("World")
	self.sig_world_spawn_sickleshardpickup_effect.connect(_World._on_received_spawn_sickleshard_pickup_effect)
	
	## Set timers
	c_timer_lifetime.wait_time = lifetime_duration.val
	c_timer_lifetime.start() # Start lifetime timer

func _process(delta: float) -> void:
	update_animations()

func _physics_process(delta: float) -> void:
	# Move forward
	if shard_curr_state == ShardState.THROWING:
		pass
		
	# Move upwards first, then fall downwards
	elif shard_curr_state == ShardState.BOUNCING:
		velocity += (Vector2.DOWN * gravity_after_launch.val) # Fall
		
	move_and_slide()

func spawn(_sickle_ref : Node2D, pos : Vector2, dir : Vector2, level : int) -> void:
	"""
	Spawn CyarmSickleShard
	
	_sickle_ref : Node2D -- reference to CyarmSickle
	pos : Vector2 -- position to spawn Shard
	dir : Vector2 -- direction to throw Shard in
	level : int -- how fast Shard should be thrown (level increases with every Player pickup of Shards before throwing)
	"""
	# Spawn at right position and orientation
	global_position = pos
	throw_direction = dir
	rotation = dir.angle()
	
	# Store reference to CyarmSickle
	sickle_ref = _sickle_ref
	
	# Based on level, empower the CyarmSickleShard
	empowered_level = level
	curr_throw_speed = CVP_Speed.new(base_throw_speed.val * pow(1.2, empowered_level)) # Make throw faster
	scale *= pow(1.3, empowered_level) # Make sprite bigger
	
	o_this_sickle_shard_damage.copy_from(sickle_ref.o_sickle_shard_damage)
	o_this_sickle_shard_damage.base_damage *= pow(1.4, empowered_level) # Make Shard deal more damage
	throw()

func throw() -> void:
	"""
	After spawning, throw CyarmSickleShard in direction
	"""
	velocity = throw_direction * curr_throw_speed.val

func launch(launch_pos : Vector2) -> void:
	"""
	After colliding with an Enemy, launch CyarmSickleShard upwards from that Enemy
	
	launch_pos : Vector2 -- location of the Enemy to launch from
	"""
	rotation = 0
	global_position = launch_pos # Launch from Enemy position
	velocity = Vector2.UP * launch_speed.val # Launch UP velocity
	var _launch_side_speed : float = Utilities.map(
										clampf(curr_throw_speed.val, base_throw_speed.val, base_throw_speed.val * 4),
										base_throw_speed.val, base_throw_speed.val * 4, # How fast is Shard throw
										base_launch_sideways_speed.val, base_launch_sideways_speed.val * 4 # How fast will be sideways launch velocity
									)
	velocity += Vector2.RIGHT * sign(throw_direction.x) * _launch_side_speed # Launch HORIZONTAL velocity 
	
	# Change collision mask
	Utilities.unset_col_mask_bit(c_area_hitbox, "Enemies") # Don't collide with Enemies after hitting one
	Utilities.set_col_mask_bit(c_area_hitbox, "Player") # Now DO collide with Player, so that Player can "catch" CyarmSickleShard
	(c_collider.shape as CircleShape2D).radius = 16 # Make slightly larger
	
	# Set state
	shard_curr_state = ShardState.BOUNCING

func pickup() -> void:
	"""
	After Player picks up launched CyarmSickleShard, power up the next thrown Shard
	"""
	# Store # of pickups in Cyarm-Sickle
	sickle_ref.sickle_shard_pickup()
	
	die()

func die() -> void:
	"""
	Destroys the CyarmSickleShard
	"""
	# Spawn pickup effect
	sig_world_spawn_sickleshardpickup_effect.emit(global_position)

	call_deferred("queue_free")

func update_animations() -> void:
	"""
	Updates CyarmSickleShard sprite to animation
	"""
	if shard_curr_state == ShardState.THROWING:
		c_sprite.play(anim_shard_throw)
	elif shard_curr_state == ShardState.BOUNCING:
		c_sprite.play(anim_shard_bounce)

func do_onhit(hit_body : Node2D) -> void:
	"""
	When the CyarmSickleShard collides with something, play onhit particles, and
	update timer to shorter duration to destroy CyarmSickleShard
	
	hit_body : Node2D -- body that was hit by CyarmSickleShard
	"""
	# Hit Player
	if Utilities.is_player(hit_body):
		pickup()
		
	# Hit Enemy
	elif Utilities.is_damageable(hit_body):
		DamageManager.calc_damage(o_this_sickle_shard_damage, hit_body) # Do damage
		launch(Utilities.get_middlepos_of(hit_body)) # Launch CyarmSickleShard upwards from Enemy
		
	# Hit Terrain
	elif Utilities.is_terrain(hit_body):
		die()

##################
## Received Signals
##################
func _on_lifetime_timer_timeout() -> void:
	# If SickleShard currently being thrown, then die after not hitting anything for a time
	if shard_curr_state == ShardState.THROWING:
		die()

func _on_sickle_shard_hitbox_body_entered(body: Node2D) -> void:
	do_onhit(body)
