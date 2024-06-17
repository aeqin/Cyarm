extends CharacterBody2D

### Components
@onready var c_sprite : AnimatedSprite2D = $MineSprite
@onready var c_collider : CollisionShape2D = $MineCollider
@onready var c_collider_explosion : CollisionShape2D = $ExplosionArea/ExplosionCollider
@onready var c_area_explosion : Area2D = $ExplosionArea
@onready var c_area_player_hit : Area2D = $PlayerHitArea
@onready var c_particles_explosion : GPUParticles2D = $ExplosionParticles
@onready var c_timer_explosion_indicator : Timer = $ExplosionIndicatorTimer
@onready var c_timer_time_until_explosion : Timer = $TimeUntilExplosionTimer

### State
enum MineState {IDLING, BLINKING, TRIGGERING, EXPLODING,}
var curr_mine_state : MineState = MineState.IDLING
var mine_state_as_str : String:
	get:
		return MineState.keys()[curr_mine_state]
var anim_idle : String = "idle"
var anim_trigger : String = "trigger"

### Movement
var f_is_grounded : bool = false
var gravity : CVP_Acceleration = CVP_Acceleration.new(19.8)
var friction_grnd : CVP_Acceleration = CVP_Acceleration.new(51.3)
var friction_air : CVP_Acceleration = CVP_Acceleration.new(14.0)

### Explosion
var f_doing_blink : bool = false
var explosion_radius : float = 60.0
var indicator_color : Color = Globals.CY_RED
var time_until_explosion_duration : CVP_Duration = CVP_Duration.new(1.4, true, c_timer_time_until_explosion)
var explosion_blink_duration : CVP_Duration = CVP_Duration.new(time_until_explosion_duration.val / 9, true, c_timer_explosion_indicator)

### Damage
var o_mine_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 30)

### Collisions
var creator : Node = self: # Who created this particular Mine
	set(new_creator):
		if not creator == self:
			push_warning("Attempting to assign already assigned creator, ", creator, " to ", self)
		else:
			creator = new_creator

### Shaders
var material_hit : ShaderMaterial
@onready var shader_hit = preload("res://scripts/shaders/hit.gdshader")

func _ready() -> void:
	## Subscribe to signals

	## Set timers
	c_timer_time_until_explosion.wait_time = time_until_explosion_duration.val
	c_timer_explosion_indicator.wait_time = explosion_blink_duration.val

	## Set raycasts
	(c_collider_explosion.shape as CircleShape2D).radius = explosion_radius
	c_area_explosion.monitoring = false

	## Set up shader
	material_hit = ShaderMaterial.new()
	material_hit.shader = shader_hit

func _physics_process(_delta: float) -> void:
	apply_gravity() # Fall down so mine lies on floor
	apply_friction() # Stop Mine from sliding forever, if pushed by Shield pulse
	move_and_slide()

func spawn(_creator : Node, o_damage : DamageManager.DamageBase, pos : Vector2) -> void:
	"""
	Spawn Mine
	_creator : Node -- the Node that created this Mine
	o_damage : DamageManager.DamageBase -- how much damage this Mine should do
	pos : Vector2 -- what position to spawn in
	"""
	# Spawn Mine at right position and orientation
	global_position = pos
	
	# Set creator and damage
	creator = _creator
	o_mine_damage = o_damage

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

func begin_explosion_sequence() -> void:
	"""
	Start blinking the explosion indicator
	"""
	c_timer_time_until_explosion.start() # Time until explosion happens
	c_timer_explosion_indicator.start() # Time until next blink happens
	
	curr_mine_state = MineState.BLINKING # Set state

func begin_trigger_sequence() -> void:
	"""
	Play a short animation before exploding (no long explosion indicator)
	"""
	if curr_mine_state == MineState.TRIGGERING:
		return # Don't trigger a second time
	
	c_sprite.play(anim_trigger)
	curr_mine_state = MineState.TRIGGERING # Set state

func explode() -> void:
	"""
	Explode Mine
	"""
	c_sprite.visible = false # Hide Mine
	c_particles_explosion.emitting = true # Show explosion
	c_area_explosion.monitoring = true # Allow explosion to do damage
	c_area_player_hit.monitoring = false # Prevent Player from triggering Mine during explosion

	curr_mine_state = MineState.EXPLODING # Set state

func do_explosion_damage(hit_body : Node2D) -> void:
	"""
	Do explosion damage
	
	hit_body : Node2D -- Node that was hit by explosion
	"""
	if Utilities.is_damageable(hit_body):
		DamageManager.calc_damage(o_mine_damage, hit_body) # Do damage

func damage_me(damage : int, _damage_dir : Vector2) -> DamageManager.DamageResult:
	"""
	Handles damage dealt TO Mine
	
	damage : int -- damage to be dealt
	_damage_dir : Vector2 -- direction of damage dealt
	
	Returns : DamageManager.DamageResult -- the result of the damage
	"""
	match curr_mine_state:
		MineState.IDLING:
			begin_explosion_sequence()
		MineState.BLINKING:
			explode()
		MineState.TRIGGERING:
			explode()
		MineState.EXPLODING:
			pass
			
	return DamageManager.DamageResult.SUCCESS

func die() -> void:
	"""
	Destroys Mine after it explodes
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

func get_middlepos() -> Vector2:
	"""
	Returns : Vector2 -- the global_position of the LaserGrenade, at the middle of its sprite
	"""
	return c_collider.global_position

func apply_friction() -> void:
	"""
	Dampens Mine movement over time, so an impact won't have them flying off forever
	"""
	var _friction : float
	if is_on_floor(): # Ground friction
		_friction = friction_grnd.val
	else: # Air friction
		_friction = friction_air.val
	
	# Move horizontal velocity towards 0 every physics frame
	override_vel(Vector2(move_toward(velocity.x, 0.0, _friction), velocity.y))

func apply_gravity() -> void:
	"""
	Makes Mine fall down
	"""
	override_vel(velocity + (Vector2.DOWN * gravity.val))

##################
## Received Signals
##################
func _on_player_hit_area_body_entered(body: Node2D) -> void:
	"""
	When Player triggers Mine, trigger explode
	"""
	begin_trigger_sequence()

func _on_explosion_indicator_timer_timeout() -> void:
	"""
	Blink mine explosion indicator
	"""
	if not curr_mine_state == MineState.BLINKING:
		return
	else:
		# Color sprite
		if f_doing_blink:
			unflash()
			f_doing_blink = false
		else:
			flash(indicator_color)
			f_doing_blink = true
		
		# Make next interval before blink slightly shorter
		c_timer_explosion_indicator.wait_time = c_timer_explosion_indicator.wait_time * 0.9
		c_timer_explosion_indicator.start()

func _on_time_until_explosion_timer_timeout() -> void:
	"""
	Explode Mine
	"""
	explode()

func _on_explosion_area_body_entered(hit_body: Node2D) -> void:
	"""
	Explosion damage
	"""
	do_explosion_damage(hit_body)

func _on_explosion_particles_finished() -> void:
	"""
	Once Explosion is finished
	"""
	die()

func _on_mine_sprite_animation_finished() -> void:
	"""
	Mine animation finished
	"""
	if c_sprite.animation == anim_trigger:
		explode()
