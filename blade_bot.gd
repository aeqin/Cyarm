extends EnemyBase

### Components
@onready var c_collider_attack : CollisionShape2D = $AttackHitbox/AttackCollider
@onready var c_collider_attack_range : CollisionPolygon2D = $AttackRange/AttackRangeCollider
@onready var c_timer_attack_cooldown : Timer = $Timers/AttackCooldown
@onready var c_timer_stun : Timer = $Timers/StunTimer
@onready var c_timer_decision : Timer = $Timers/DecisionTimer
@onready var c_timer_aggro : Timer = $Timers/AggroTimer
@onready var c_timer_chaseturn : Timer = $Timers/ChaseTurnTimer

### Bladebot state
enum BladeState {
					IDLING, MOVING,
					READY_TO_ATTACK, ATTACKING,
					PARRIED, STUNNED
				,}
var blade_curr_state : BladeState = BladeState.IDLING
var blade_state_as_str : String:
	get:
		return BladeState.keys()[blade_curr_state]
var min_decision_duration :float = 3.5 # Minimum amount of time for DecisionTimer

### Movement Variables
@export var f_do_patrol : bool = true
var chase_x_dir : float = 1.0
var min_chaseturn_duration : float = 0.35 # Minimum amount of time for ChaseTurnTimer
var walk_speed : CVP_Speed = CVP_Speed.new(108.0)
var aggro_speed : CVP_Speed = CVP_Speed.new(188.0)
var aggro_dist : float = 300.0
var aggro_max_height_above : float = -200.0

### Attack variables
var f_aggroed_on_player : bool = false
var f_player_in_attack_range : bool = false
var attack_dist : float = 80.0
var min_aggro_duration : float = 2.5 # Minimum amount of time for AggroTimer
var attack_cooldown_duration : CVP_Duration = CVP_Duration.new(3.5, true, c_timer_attack_cooldown)
var damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 30)
var attack_dash_speed : CVP_Speed = CVP_Speed.new(708.0)

### Stunned Variables
var stun_duration : CVP_Duration = CVP_Duration.new(3.0, true, c_timer_stun)

### Animation variables
var anim_idle : String = "idle"
var anim_run : String = "run"
var anim_ready_attack : String = "ready_attack"
var anim_attack : String = "attack"
var anim_parried : String = "parried"
var anim_stunned : String = "stunned"

func _ready() -> void:
	# Assign vars from EnemyBase class
	c_collider = $BladeBotCollider
	SETUP_colliders()
	health = 140
	grnd_x_friction = CVP_Acceleration.new(1.0) 
	air_x_friction = CVP_Acceleration.new(1.0)
	label_start_pos = c_label.position
	
	super() # call EnemyBase _ready()

	## Set timers
	c_timer_attack_cooldown.wait_time = attack_cooldown_duration.val
	c_timer_stun.wait_time = stun_duration.val
	c_timer_decision.start(min_decision_duration)
	
	## Set raycasts
	
	DebugStats.add_stat(self, "blade_state_as_str")

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
	
	# Flip the attack collider to the other side
	c_collider_attack.position.x = left_or_right * abs(c_collider_attack.position.x)
	c_collider_attack_range.scale.x = left_or_right

func calc_aggro() -> bool:
	"""
	Returns : bool -- whether or not Bladebot should aggro onto Player
	"""
	# If already aggroed, still aggro if Player within a small range
	if (
			f_aggroed_on_player
		and
			(get_dist_to_player() < aggro_dist / 2.5)
		and
				is_player_in_sight() # Bladebot has line of sight with Player
		):
			return true
	
	return (
				(get_x_dir_to_player() == curr_direction) # Facing Player
			and
				(get_dist_to_player() < aggro_dist) # Player is within aggro distance
			and
				(Utilities.in_rangef(get_y_dist_to_player(false), aggro_max_height_above, 1)) # Player is above/level with Bladebot
			and
				is_player_in_sight() # Bladebot has line of sight with Player
			)

func aggro() -> void:
	"""
	Aggro onto Player
	"""
	if not f_aggroed_on_player:
		show_exclamation(true, label_start_pos) # Show alert if not already aggroed

	c_timer_aggro.start(min_aggro_duration)
	f_aggroed_on_player = true

func stand() -> void:
	"""
	Bladebot doesn't wanna move
	"""
	# Check if Bladebot should aggro onto Player
	if calc_aggro():
		aggro()
		blade_curr_state = BladeState.MOVING

func patrol() -> void:
	"""
	Move BladeBot in either direction, switching directions upon nearing a wall
	"""
	if not f_is_grounded: # Do not attempt to patrol if airborne
		return
	
	if f_do_patrol: # Only move if allowed to patrol
		override_vel(Vector2(walk_speed.val * left_or_right, velocity.y)) # Walk
	
	# Check collision with walls or off ledges
	if will_walk_into_wall() or will_walk_off_ledge():
		override_vel(Vector2.ZERO) # Stop moving, then
		curr_direction *= -1 # Flip directions
	
	# Check if Bladebot should aggro onto Player
	if calc_aggro():
		aggro()

func calc_attack() -> bool:
	"""
	Returns : bool -- whether or not Bladebot should attack Player
	"""
	return (
				f_player_in_attack_range # Player is within Bladebot cone
			and
				is_player_in_sight() # Bladebot has line of sight with Player
			)

func chase() -> void:
	"""
	Move BladeBot to follow Player
	"""
	# Prevent Bladebot from spazzing out if Player jumps above by limiting turn frequency
	if c_timer_chaseturn.is_stopped():
		var _next_turn_wait : float = min_chaseturn_duration + min_chaseturn_duration * Globals.random.randf_range(0.15, 2.0)
		c_timer_chaseturn.start(_next_turn_wait)
		chase_x_dir = get_x_dir_to_player()
	
	# Check if Bladebot should attack Player
	if f_player_in_attack_range:
		if ready_attack():
			pass # Attack was readied
			
		else: # Attack is still on cooldown
			
			# Turn around if too close to Player
			if get_dist_to_player() < attack_dist:
				var _next_turn_wait : float = min_chaseturn_duration + min_chaseturn_duration * Globals.random.randf_range(0.15, 2.0)
				c_timer_chaseturn.start(_next_turn_wait)
				chase_x_dir = -1 * curr_direction
	
	# Player still out of range, so keep chasing
	else:
		if not will_walk_off_ledge(): # Don't run off ledge
			override_vel(Vector2(aggro_speed.val * chase_x_dir, velocity.y)) # Run
			curr_direction = chase_x_dir

######################
## Attack/Damage functions
######################
func ready_attack() -> bool:
	"""
	Returns : bool -- whether or not attack was readied
	"""
	# Only begin attack if cooldown is over
	if c_timer_attack_cooldown.is_stopped():
		curr_direction = get_x_dir_to_player() # Turn to Player
		blade_curr_state = BladeState.READY_TO_ATTACK
		return true
	
	return false

func attack() -> void:
	"""
	Move BladeBot forward to attack
	"""
	override_vel(Vector2(attack_dash_speed.val * left_or_right, velocity.y)) # Dash forward
	c_animplayer.play(anim_attack) # Attack collider is enabled during animation
	c_timer_attack_cooldown.start()
	blade_curr_state = BladeState.ATTACKING

func anim_func_start_attack() -> void:
	"""
	Called by AnimationPlayer, begin attack (after ready_attack animation is finished)
	"""
	attack()

func anim_func_finish_attack() -> void:
	"""
	Called by AnimationPlayer, finish attack
	"""
	override_vel(Vector2.ZERO) # Cancel momentum
	c_collider_attack.disabled = true
	blade_curr_state = BladeState.IDLING
	c_timer_decision.start(Globals.random.randf_range(0.15, 2.0)) # Random time until walk again

func get_damage() -> DamageManager.DamageBase:
	"""
	Returns : DamageManager.DamageBase -- the amount of damage Enemy currently does
	"""
	return damage

func get_defense_modifier() -> float:
	"""
	Returns : float -- the amount of damage Enemy takes modifier
	"""
	if blade_curr_state == BladeState.STUNNED or blade_curr_state == BladeState.PARRIED:
		return 3.5 # Take more damage
	else:
		return 1.0 # Take normal damage

func damage_me(damage : int, _damage_dir : Vector2) -> DamageManager.DamageResult:
	"""
	Handles damage dealt TO Enemy
	
	damage : int -- damage to be dealt
	_damage_dir : Vector2 -- direction of damage dealt
	
	Returns : DamageManager.DamageResult -- the result of the damage
	"""
	var _dmg_result : DamageManager.DamageResult = super(damage, _damage_dir)
	if _dmg_result == DamageManager.DamageResult.SUCCESS:
		if not f_aggroed_on_player:
			curr_direction *= -1 # Turn around, potentially aggro Player
	
	# If damaged during stun state, end stun state
	if blade_curr_state == BladeState.STUNNED or blade_curr_state == BladeState.PARRIED:
		c_timer_stun.stop()
		_on_stun_timer_timeout()

	return _dmg_result

func parry_me() -> void:
	"""
	Handles Enemy being parried by Player
	"""
	if blade_curr_state == BladeState.ATTACKING:
		override_vel(Vector2.ZERO)
		show_exclamation(false, label_start_pos)
		f_aggroed_on_player = false
		blade_curr_state = BladeState.PARRIED

######################
## State & Animation functions
######################
func calc_physics_state_decision() -> void:
	"""
	Calculates state every physics frame
	"""
	match blade_curr_state:
		BladeState.IDLING:
			stand()
		BladeState.MOVING:
			if not f_aggroed_on_player:
				patrol()
			else:
				chase()
		BladeState.READY_TO_ATTACK:
			pass
		BladeState.ATTACKING:
			pass
		BladeState.PARRIED:
			pass
		BladeState.STUNNED:
			pass

func update_animations() -> void:
	"""
	Updates animations
	"""
	match blade_curr_state:
		BladeState.IDLING:
			c_animplayer.play(anim_idle)
		BladeState.MOVING:
			if abs(velocity.x) > 0.0:
				if not f_aggroed_on_player:
					c_animplayer.play(anim_run)
				else:
					c_animplayer.play(anim_run, -1, (aggro_speed.val / walk_speed.val)) # Play run animation, but faster
			else:
				c_animplayer.play(anim_idle)
		BladeState.READY_TO_ATTACK:
			c_animplayer.play(anim_ready_attack)
		BladeState.ATTACKING:
			c_animplayer.play(anim_attack)
		BladeState.PARRIED:
			Utilities.play_no_repeat(c_animplayer, anim_parried)
		BladeState.STUNNED:
			c_animplayer.play(anim_stunned)

func anim_func_end_parried() -> void:
	"""
	End playing "parried" animation
	"""
	c_timer_stun.start() # How long Bladebot should stay stunned
	blade_curr_state = BladeState.STUNNED

##################
## Received Signals
##################
func _on_decision_timer_timeout() -> void:
	# Start a timer for the next decision
	var _next_decision_wait : float = min_decision_duration + min_decision_duration * Globals.random.randf_range(0.15, 2.0)
	c_timer_decision.start(_next_decision_wait)
	
	match blade_curr_state:
		BladeState.IDLING:
			blade_curr_state = BladeState.MOVING # Start patrolling again
		BladeState.MOVING:
			if not f_aggroed_on_player:
				blade_curr_state = BladeState.IDLING # Stand and idle for a bit

func _on_aggro_timer_timeout() -> void:
	# Check if Bladebot should REMAIN aggro onto Player
	if f_aggroed_on_player:
		if calc_aggro():
			# Start a timer for the next aggro check
			var _next_aggro_wait : float = min_aggro_duration + min_aggro_duration * Globals.random.randf_range(0.15, 2.0)
			c_timer_aggro.start(_next_aggro_wait)
	
		else:
			show_exclamation(false, label_start_pos)
			f_aggroed_on_player = false # Lose aggro

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	"""
	Body entered attack hitbox
	"""
	if blade_curr_state == BladeState.ATTACKING:
		# Do damage to the body that BladeBot slash hit
		var _dmg_result : DamageManager.DamageResult = do_damage_to(body)
		
		match _dmg_result:
			DamageManager.DamageResult.PARRIED:
				parry_me()
			_:
				pass # Do nothing special if damage goes through

func _on_attack_range_body_entered(body: Node2D) -> void:
	"""
	Player enters attack range
	"""
	f_player_in_attack_range = true

func _on_attack_range_body_exited(body: Node2D) -> void:
	"""
	Player exits attack range
	"""
	f_player_in_attack_range = false

func _on_stun_timer_timeout() -> void:
	"""
	End Bladebot stun
	"""
	blade_curr_state = BladeState.IDLING
