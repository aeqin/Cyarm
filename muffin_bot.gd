extends EnemyBase

func _ready() -> void:
	# Assign vars from EnemyBase class
	c_collider = $MuffinBotCollider
	SETUP_colliders()
	health = 10
	f_apply_gravity = false
	
	super() # call EnemyBase _ready()

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
	pass

func update_animations() -> void:
	"""
	Updates animations
	"""
	pass
