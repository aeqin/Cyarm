extends CharacterBody2D

### Signals
signal sig_chainedplatform_began_move(self_ref : Node, vel : Vector2)
signal sig_chainedplatform_reached_anchor(self_ref : Node, last_vel : Vector2)

### Components
@onready var c_folder_dontmove_anchorNchain : Node = $"Don'tMoveChainNAnchor"
@onready var c_folder_anchorNchain : Node2D = $AnchorNChain
@onready var c_sprite : Sprite2D = $PlatformSprite
@onready var c_sprite_anchor_a : Sprite2D = $AnchorNChain/AnchorA
@onready var c_sprite_anchor_b : Sprite2D = $AnchorNChain/AnchorB
@onready var c_collider : CollisionShape2D = $PlatformCollider
@onready var c_shapecast_collidenext : ShapeCast2D = $CollideNextCast
@onready var c_shapecast_crush : ShapeCast2D = $CrushCast
@onready var c_line_chain : Line2D = $AnchorNChain/Chain

### State
enum PlatformState {MOVING_TO_A, MOVING_TO_B, STOPPED_AT_A, STOPPED_AT_B,}
var platform_curr_state : PlatformState = PlatformState.MOVING_TO_A
var platform_state_as_str : String:
	get:
		return PlatformState.keys()[platform_curr_state]

### Movement variables
var f_is_rising : bool
var chain_dir_to_a : Vector2
var chain_dir_to_b : Vector2
var platform_next_movement : Vector2 # How much ChainedPlatform will move this physics frame
var platform_speed : CVP_Speed = CVP_Speed.new(700.0)

### Crush variables
# Dictionary of {Node, int} that holds a ref to every Entity that might be crushed by ChainedPlatform
var crush_dict : Dictionary
var crush_damage : int = 9999
var o_crush_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, crush_damage, 0, 1.0)

func _ready() -> void:
	## Set raycasts
	#c_shapecast_collidenext.shape = c_collider.shape
	
	### Draw chain
	# Move anchors and chain to a folder that DOESN'T move with ChainedPlatform
	# (they start out in a folder that DOES move with ChainedPlatform so that I can see where the anchors are in the editor)
	c_folder_anchorNchain.remove_child(c_sprite_anchor_a)
	c_folder_anchorNchain.remove_child(c_sprite_anchor_b)
	c_folder_anchorNchain.remove_child(c_line_chain)
	c_folder_dontmove_anchorNchain.add_child(c_sprite_anchor_a)
	c_folder_dontmove_anchorNchain.add_child(c_sprite_anchor_b)
	c_folder_dontmove_anchorNchain.add_child(c_line_chain)
	# Need to set pos, since these children don't move with parent ChainedPlatform
	c_sprite_anchor_a.global_position = global_position + c_sprite_anchor_a.position
	c_sprite_anchor_b.global_position = global_position + c_sprite_anchor_b.position
	c_line_chain.clear_points()
	c_line_chain.add_point(c_sprite_anchor_a.position)
	c_line_chain.add_point(c_sprite_anchor_b.position)
	# Set direction ChainedPlatform can move in
	chain_dir_to_a = (c_sprite_anchor_a.global_position - c_sprite_anchor_b.global_position).normalized()
	chain_dir_to_b = (c_sprite_anchor_b.global_position - c_sprite_anchor_a.global_position).normalized()
	
	# Move ChainedPlatform to an anchor
	velocity = get_dir() * platform_speed.val

func _process(_delta: float) -> void:
	update_inputs()
	
func update_inputs() -> void:
	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		match platform_curr_state:
			PlatformState.MOVING_TO_A:
				override_vel(chain_dir_to_b * platform_speed.val) # switch opposite
			PlatformState.MOVING_TO_B:
				override_vel(chain_dir_to_a * platform_speed.val) # switch opposite
			PlatformState.STOPPED_AT_A:
				override_vel(chain_dir_to_b * platform_speed.val) # switch opposite
			PlatformState.STOPPED_AT_B:
				override_vel(chain_dir_to_a * platform_speed.val) # switch opposite

func _physics_process(delta: float) -> void:
	# Update ChainedPlatform movement flags for this frame
	f_is_rising = velocity.y < 0
	platform_next_movement = get_next_movement(delta) # How much ChainedPlatform will move this frame

	if has_reached_anchor():
		if not velocity == Vector2.ZERO:
			stop_at_anchor()

	check_collisions(crush_dict)
	crush_the_unworthy(crush_dict)
	move_and_slide()

######################
## Movement functions
######################
func override_vel(new_velocity : Vector2):
	"""
	Overrides the old velocity with new value pair
	
	new_velocity : Vector2 -- new velocity
	"""
	var _dir = new_velocity.normalized()
	if _dir.dot(chain_dir_to_a) > 0: # Similar direction as towards anchor A
		velocity = chain_dir_to_a * platform_speed.val

	else: # Similar direction as towards anchor B
		velocity = chain_dir_to_b * platform_speed.val
		
	sig_chainedplatform_began_move.emit(self, velocity)

func get_dir() -> Vector2:
	"""
	Returns the direction that ChainedPlatform wants to move, depending on state
	"""
	match platform_curr_state:
		PlatformState.MOVING_TO_A:
			return chain_dir_to_a
		PlatformState.MOVING_TO_B:
			return chain_dir_to_b
		PlatformState.STOPPED_AT_A:
			return chain_dir_to_a
		PlatformState.STOPPED_AT_B:
			return chain_dir_to_b
		_:
			return chain_dir_to_a # Default

func get_next_movement(delta : float) -> Vector2:
	"""
	Returns the amount of distance (x and y) that ChainedPlatform will move this physics frame
	
	delta : float -- time between physics frames
	"""
	return velocity * delta

func has_reached_anchor() -> bool:
	"""
	Returns whether or not ChainedPlatform has reached an anchor
	"""
	if velocity == Vector2.ZERO:
		return true

	var _next_pos : Vector2 = global_position + platform_next_movement # Next position of ChainedPlatform at end of physics frame
	var _chain_dir : Vector2
	var _anchor_dir : Vector2
	var _anchor : Sprite2D
	if velocity.dot(chain_dir_to_a) > 0: # Platform is moving towards anchor A, so STOP at anchor A
		_anchor = c_sprite_anchor_a
		_chain_dir = chain_dir_to_a
		platform_curr_state = PlatformState.MOVING_TO_A

	else: # Platform is moving towards anchor B, so STOP at anchor B
		_anchor = c_sprite_anchor_b
		_chain_dir = chain_dir_to_b
		platform_curr_state = PlatformState.MOVING_TO_B

	_anchor_dir = (_anchor.global_position - _next_pos).normalized()
	if _anchor_dir.dot(_chain_dir) < 0:
		return true
	else:
		return false

func stop_at_anchor() -> void:
	"""
	Stop ChainedPlatform at anchor
	"""
	var _vel_b4_stop : Vector2 = velocity
	velocity = Vector2.ZERO # Stop platform
	
	# In cases where velocity would move past anchor in a single physics frame,
	# teleport ChainedPlatform to anchor
	if platform_curr_state == PlatformState.MOVING_TO_A:
		platform_curr_state = PlatformState.STOPPED_AT_A
		global_position = c_sprite_anchor_a.global_position
	elif platform_curr_state == PlatformState.MOVING_TO_B:
		platform_curr_state = PlatformState.STOPPED_AT_B
		global_position = c_sprite_anchor_b.global_position
	
	sig_chainedplatform_reached_anchor.emit(self, _vel_b4_stop)

func check_collisions(_crush_dict : Dictionary) -> void:
	"""
	Checks any collisions in the path of ChainedPlatform
	May stop velocity of any Entity encountered, or log Entity as potentially crushed (to death)
	
	_crush_dict : Dictionary -- Dictionary of {Node, int} that keeps track of Entitities that potentially can be crushed
	"""
	if (
			velocity == Vector2.ZERO
		and 
			_crush_dict.is_empty()
	):
		# Skipping checking collisions if ChainedPlatform is stopped AND there are no relevant potential crushed to check
		return 
	
	c_shapecast_collidenext.position = platform_next_movement
	c_shapecast_collidenext.force_shapecast_update()
	var _collision_entities : Array = []
	for collision_dict in c_shapecast_collidenext.collision_result:
		var _entity_ref : Node = collision_dict["collider"]
		_collision_entities.append(_entity_ref)

		if f_is_rising:
			# Instead of knocking Entity higher with a collision, cancel the
			# upwards momentum of Entity
			#_entity_ref.velocity.y = 0
			pass
		
		# If Entity hasn't been logged yet, add it to a list of potentially crushed
		if not _crush_dict.has(_entity_ref):
			_crush_dict[_entity_ref] = 0
	
	# If no collisions happen next frame, clear list of potentially crushed
	if not c_shapecast_collidenext.is_colliding():
		_crush_dict.clear()
	else:
		# Prune list of potentially crushed
		var _rem_pot_crush : Array = []
		for entity_ref in _crush_dict:
			if entity_ref not in _collision_entities:
				# Log each Entity that will NOT be collided with next frame
				_rem_pot_crush.append(entity_ref)
		for entity_ref in _rem_pot_crush:
			# Each Entity that will NOT be collided with ChainedPlatform next frame, CAN'T be crushed
			_crush_dict.erase(entity_ref)

######################
## Attack/Damage functions
######################
func do_crush_damage_to(hit_body : Node2D, _crush_dict : Dictionary):
	"""
	Does damage to subject
	
	hit_body : Node2D -- subject that can possibly take damage
	_crush_dict : Dictionary -- Dictionary of {Node, int} that keeps track of Entitities that potentially can be crushed
	"""
	var _hit_body_pos : Vector2 = Utilities.get_middlepos_of(hit_body)

	if Utilities.is_damageable(hit_body):
		DamageManager.calc_damage(o_crush_damage, hit_body)
		
		# Squish Entity on crush
		var _squish_tween : Tween = create_tween()
		var _entity_sprite : Node2D = Utilities.get_main_sprite(hit_body)
		var _entity_collider : CollisionShape2D = Utilities.get_crush_collider(hit_body)
		if (
				not _entity_sprite == null
			and
				not _entity_collider == null
			):
			_squish_tween.tween_property(_entity_sprite, "scale", Vector2(1.5, 0.3), 0.1)
			# TODO: give every Entity a squished sprite

func crush(entity_ref : Node2D, _crush_dict : Dictionary) -> void:
	"""
	Checks whether or not subject can be crushed (to death), and if so, crushes subject (to death)
	
	entity_ref : Node2D -- Entity to be potentially crushed
	_crush_dict : Dictionary -- Dictionary of {Node, int} that keeps track of Entitities that potentially can be crushed
	"""
	var _collider = Utilities.get_crush_collider(entity_ref)
	if not _collider == null:
		# Place a shapecast with the same size and pos as the Entity, then query to see if Entity should be considered crushed
		c_shapecast_crush.shape = _collider.shape
		c_shapecast_crush.exclude_parent = false
		c_shapecast_crush.global_position = _collider.global_position
		c_shapecast_crush.force_shapecast_update()

		var _num_crushers : int = 0 # Number of things that can potentially crush Entity, such as Terrain or MovableTerrain
		for collision_dict in c_shapecast_crush.collision_result:
			var _potential_crusher : Node = collision_dict["collider"]
			var _potential_crusher_rid : RID = collision_dict["rid"]
			
			if (
					not entity_ref == _potential_crusher # Don't count Entity itself as something that can crush it
				and
					Utilities.is_RID_terrain(_potential_crusher_rid) # Entity can only be crushed between "Terrain" collisions
				): 
				_num_crushers += 1

		# Log number of crushed in Dict of {Node, int}
		_crush_dict[entity_ref] = _num_crushers
		
		# Entity is trapped between at least 2 Terrain, and so must be dead
		if _num_crushers > 1:
			do_crush_damage_to(entity_ref, _crush_dict)

func crush_the_unworthy(_crush_dict : Dictionary) -> void:
	"""
	Iterates through a list of Entities to be potentially crushed (to death)
	
	_crush_dict : Dictionary -- Dictionary of {Node, int} that keeps track of Entitities that potentially can be crushed
	"""
	var _destroyed_ref_arr : Array = []
	
	# Attempt to crush each Entity logged by check_collision()
	for entity_ref in _crush_dict:
		if entity_ref == null:
			_destroyed_ref_arr.append(entity_ref)
		else:
			crush(entity_ref, _crush_dict)

	# Remove entries of Entities that have since been destroyed
	for destroyed_ref in _destroyed_ref_arr:
		_crush_dict.erase(destroyed_ref)

######################
## Received Signals
######################
