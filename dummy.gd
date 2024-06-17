extends EnemyBase

### State & Animations
enum DummyState {
	IDLING,
	HIT,
	HITTING,
	}
var dummy_curr_state : DummyState = DummyState.IDLING
var dummy_state_as_str : String:
	get:
		return DummyState.keys()[dummy_curr_state]
var anim_dummy_idle : String = "dummy_idle"
var anim_dummy_hit : String = "dummy_hit"

func _ready() -> void:
	# Assign vars from EnemyBase class
	c_collider = $DummyCollider
	SETUP_colliders()
	health = 9999
	
	super() # call EnemyBase _ready()

######################
## Attack/Damage functions
######################
func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Enemy currently does
	"""
	return no_damage

func damage_me(damage : int, _damage_dir : Vector2) -> DamageManager.DamageResult:
	"""
	Handles damage dealt TO Enemy
	
	damage : int -- damage to be dealt
	_damage_dir : Vector2 -- direction of damage dealt
	"""
	dummy_curr_state = DummyState.HIT # Set hit state to animate
	c_sprite.flip_h = sign(_damage_dir.x) > 0
	
	return super(damage, _damage_dir) # call EnemyBase damage_me()

######################
## State & Animation functions
######################
func calc_physics_state_decision() -> void:
	"""
	Calculates state every physics frame
	"""
	if dummy_curr_state == DummyState.HITTING and not c_sprite.is_playing():
		# Hit animation finished playing, so return to idle animation
		dummy_curr_state = DummyState.IDLING

func update_animations() -> void:
	"""
	Updates animations
	"""
	match dummy_curr_state:
		DummyState.IDLING:
			c_sprite.play(anim_dummy_idle)
		DummyState.HIT:
			# Play hit animation
			c_sprite.set_frame_and_progress(0, 0.0) # Play from first frame each hit
			c_sprite.play(anim_dummy_hit)
			dummy_curr_state = DummyState.HITTING
		DummyState.HITTING:
			pass # Hit animation is currently playing

