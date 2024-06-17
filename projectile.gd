extends Area2D

### Components
@onready var c_collider : CollisionShape2D = $CollisionShape2D
@onready var c_sprite : Sprite2D = $Sprite2D
@onready var c_particles_onhit: GPUParticles2D = $HitParticles
@onready var c_timer_lifetime : Timer = $LifetimeTimer

### Movement variables
var speed : CVP_Speed = CVP_Speed.new(250.0)
var direction : Vector2 = Vector2.UP

### Lifetime variables
var lifetime_duration : CVP_Duration = CVP_Duration.new(4.0, true, c_timer_lifetime) # How long the Projectile lasts
var onhit_particles_duration : CVP_Duration = CVP_Duration.new(0.4, true) # How long the Projectile lasts after hitting something

### Damage
var o_projectile_damage : DamageManager.DamageBase

### Collisions
var creator : Node = self: # Who created this particular Projectile
	set(new_creator):
		if not creator == self:
			push_warning("Attempting to assign already assigned creator, ", creator, " to ", self)
		else:
			add_collision_exception(new_creator) # By default, creator of Projectile cannot be hit by Projectile
			creator = new_creator

var collision_exceptions : Array = []

func _ready() -> void:
	## Set timers
	c_timer_lifetime.wait_time = lifetime_duration.val # On spawn, Projectile dies after the longer duration
	c_particles_onhit.lifetime = onhit_particles_duration.val # How long onhit particles should last
	
	## Start lifetime timer (can be updated in do_onhit())
	c_timer_lifetime.start()

func _physics_process(delta: float) -> void:
	position += direction * speed.val * delta

func spawn(_creator : Node, _damage : DamageManager.DamageBase, pos : Vector2, dir : Vector2) -> void:
	"""
	Spawn Projectile

	_creator : Node -- the Node that created this Projectile
	o_damage : DamageManager.DamageBase -- how much damage this Projectile should do
	pos : Vector2 -- what position to spawn in
	dir : Vector2 -- what direction to move in
	"""
	# Spawn at right position and orientation
	global_position = pos
	direction = dir
	rotation = dir.angle() + PI/2
	
	# Set creator and damage
	creator = _creator
	o_projectile_damage = _damage

func add_collision_exception(body: Node2D) -> void:
	"""
	Adds a body to list of exceptions (don't act on collision with this body)
	"""
	if body not in collision_exceptions: # Only allows one entry in array
		collision_exceptions.append(body)

func rem_collision_exception(body: Node2D) -> void:
	"""
	Removes a body from list of exceptions (again act on collision with this body)
	"""
	collision_exceptions.erase(body)

func do_onhit(hit_body : Node2D) -> void:
	"""
	When the Projectile collides with something, play onhit particles, and
	update timer to shorter duration to destroy Projectile
	
	hit_body : Node2D -- body that was hit by Projectile
	"""
	c_collider.set_deferred("disabled", true) # Disable collider so Projectile does not collide multiple times
	c_sprite.visible = false # Hide Projectile
	c_particles_onhit.emitting = true # Begin onhit particles
	c_timer_lifetime.start(onhit_particles_duration.val) # Set Projectile to be destroyed once onhit particles is DONE playing
	
	# Do damage to the body that Projectile hit
	if Utilities.is_damageable(hit_body):
		DamageManager.calc_damage(o_projectile_damage, hit_body)

func return_to_sender() -> void:
	"""
	Called by Cyarm-Shield during Shield guard, to reflect Projectile back to creator
	"""
	c_sprite.modulate = Globals.CY_GREEN # Change Projectile color
	direction = -direction * 1.7 # Inverse Projectile direction, make it faster
	rem_collision_exception(creator) # Allow creator of Projectile to be hit

func die() -> void:
	"""
	Destroys the Projectile
	"""
	call_deferred("queue_free")

##################
## Received Signals
##################
func _on_body_entered(body: Node2D) -> void:
	if body not in collision_exceptions: 
		do_onhit(body)
		if body.has_method("test"):
			body.test()

func _on_lifetime_timer_timeout() -> void:
	die()
