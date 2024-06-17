extends EnemyBase

### Components
@onready var c_collider_attack : CollisionPolygon2D = $AttackHitbox/AttackCollider
@onready var c_timer_attack_cooldown : Timer = $Timers/AttackCooldown
@onready var c_timer_stagger : Timer = $Timers/StaggerTimer
@onready var c_timer_decision : Timer = $Timers/DecisionTimer

### Pot state
enum PotState {IDLING, MOVING,
				READY_TO_ATTACK, ATTACKING,
				STAGGERED, STAGGERING
				,}
var pot_curr_state : PotState = PotState.MOVING
var pot_state_as_str : String:
	get:
		return PotState.keys()[pot_curr_state]

### Stagger Variables
var stagger_duration : CVP_Duration = CVP_Duration.new(2.0, true, c_timer_stagger)

### Movement Variables
var walk_speed : CVP_Speed = CVP_Speed.new(108.0)
var aggro_speed : CVP_Speed = CVP_Speed.new(188.0)

### Attack variables
var f_attack_in_range : bool = false
var attack_cooldown_duration : CVP_Duration = CVP_Duration.new(0.5, true)
var damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 30)

func _ready() -> void:
	# Assign vars from EnemyBase class
	c_collider = $PotBotCollider
	SETUP_colliders()
	health = 30
	
	super() # call EnemyBase _ready()

	## Set timers
	c_timer_attack_cooldown.wait_time = attack_cooldown_duration.val
	c_timer_stagger.wait_time = stagger_duration.val
	
	## Set raycasts

func _process(delta: float) -> void:
	super(delta) # call EnemyBase _process()

	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		pass
	if Input.is_action_just_pressed("testkey2"):
		pass

func _physics_process(delta: float) -> void:
	super(delta) # call EnemyBase _physics_process()

######################
## Movement functions
######################
func change_direction(new_dir : float = left_or_right) -> void:
	"""
	Changes Enemy facing direction
	"""
	super(new_dir)
	
	c_collider_attack.scale.x = left_or_right

func patrol() -> void:
	"""
	Move PotBot in either direction, switching directions upon nearing a wall
	"""
	override_vel(Vector2(walk_speed.val * left_or_right, velocity.y))
	
	# Check collision with walls or off ledges
	if will_walk_into_wall() or will_walk_off_ledge():
		override_vel(Vector2.ZERO) # Stop moving, then
		curr_direction *= -1 # Flip directions

######################
## Attack/Damage functions
######################
func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Enemy currently does
	"""
	return damage

func parry_me() -> void:
	"""
	Handles Enemy being parried by Player
	"""
	if pot_curr_state == PotState.ATTACKING:
		f_status_staggered = true
		pot_curr_state = PotState.STAGGERED

######################
## State & Animation functions
######################
func calc_physics_state_decision() -> void:
	"""
	Calculates state every physics frame
	"""
	# Decide to attack
	if (
			f_attack_in_range # Player in range
			and
			c_timer_attack_cooldown.is_stopped() # Attack done cooling down
			and
			(
				pot_curr_state == PotState.IDLING or 
				pot_curr_state == PotState.MOVING
			)
		):
		pot_curr_state = PotState.READY_TO_ATTACK
	
	match pot_curr_state:
		PotState.IDLING:
			patrol()
		PotState.MOVING:
			patrol()
		PotState.READY_TO_ATTACK:
			c_animplayer.play("pot_attack")
			c_timer_attack_cooldown.start()
			pot_curr_state = PotState.ATTACKING
		PotState.ATTACKING:
			pass
		PotState.STAGGERED:
			c_timer_stagger.start()
			pot_curr_state = PotState.STAGGERING
		PotState.STAGGERING:
			if c_timer_stagger.is_stopped():
				f_status_staggered = false
				pot_curr_state = PotState.IDLING

func update_animations() -> void:
	"""
	Updates animations
	"""
	match pot_curr_state:
		PotState.IDLING:
			pass
		PotState.MOVING:
			pass
		PotState.READY_TO_ATTACK:
			pass
		PotState.ATTACKING:
			pass
		PotState.STAGGERED:
			pass
		PotState.STAGGERING:
			pass

##################
## Received Signals
##################
func _on_attack_range_body_entered(body: Node2D) -> void:
	"""
	Body entered attack range
	"""
	if Utilities.is_player(body):
		f_attack_in_range = true
	
func _on_attack_range_body_exited(body: Node2D) -> void:
	"""
	Body exited attack range
	"""
	if Utilities.is_player(body):
		f_attack_in_range = false

func _on_attack_hitbox_body_entered(hit_body: Node2D) -> void:
	"""
	Body entered attack hitbox
	"""
	# Do damage to the body that PotBot slash hit
	do_damage_to(hit_body)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	"""
	Once animation finished playing
	"""
	if (
			pot_curr_state == PotState.ATTACKING
		and
			anim_name == "pot_attack"
		):
		pot_curr_state = PotState.IDLING # After attacking, go back to idling

