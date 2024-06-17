extends EnemyBase

### Floatbot state
enum FloatState {
					IDLING, MOVING,
					READY_TO_ATTACK, ATTACKING
				,}
var float_curr_state : FloatState = FloatState.IDLING
var float_state_as_str : String:
	get:
		return FloatState.keys()[float_curr_state]

### Animation variables
var anim_idle : String = "idle"
var bob_speed : CVP_Speed = CVP_Speed.new(0.005)
var bob_distance : float = 5.0

func _ready() -> void:
	# Assign vars from EnemyBase class
	c_collider = $FloatBotCollider
	SETUP_colliders()
	health = 50
	mass = 150
	f_apply_gravity = false # Flying enemy, don't fall
	
	# Make each Floatbot bob at a different cadence
	bob_speed = CVP_Speed.new(bob_speed.val + Globals.random.randf_range(-.15, .15) * bob_speed.val)
	
	super() # call EnemyBase _ready()

func _physics_process(delta: float) -> void:
	
	super(delta) # call EnemyBase _physics_process()

func apply_gravity() -> void:
	"""
	Makes Enemy fall down
	"""
	if not f_apply_gravity:
		return

	pass # Don't apply gravity

######################
## Attack/Damage functions
######################
func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Enemy currently does
	"""
	return no_damage

######################
## State & Animation functions
######################
func calc_physics_state_decision() -> void:
	"""
	Calculates state every physics frame
	"""
	match float_curr_state:
		FloatState.IDLING:
			c_animplayer.play(anim_idle)
		FloatState.MOVING:
			c_animplayer.play(anim_idle)
		FloatState.READY_TO_ATTACK:
			pass # TODO: Add an laser attack, two signal that move towards center before firing upon meeting
		FloatState.ATTACKING:
			pass

func update_animations() -> void:
	"""
	Updates animations
	"""
	match float_curr_state:
		FloatState.IDLING:
			bob()
		FloatState.MOVING:
			bob()
		FloatState.READY_TO_ATTACK:
			pass
		FloatState.ATTACKING:
			pass

func bob() -> void:
	"""
	Slightly moves the Floatbot sprite up and down
	"""
	var bob_vel_y = (sin(Time.get_ticks_msec() * bob_speed.val) * bob_distance * get_physics_process_delta_time())
	c_sprite.position.y += bob_vel_y
	c_node_HP_bundle.position.y += bob_vel_y
	c_animplayer.play(anim_idle)
	
