extends Object
class_name MoveOnRails
"""
Object MoveOnRails used to bundle a bunch of related variables regarding movement
"""

enum RAIL_TYPE {NONE, TO_TARGET, FOR_DISTANCE, IN_DIRECTION} # The type of move-on-rails movement
#	NONE -- Currently NOT moving-on-rails
#	TO_TARGET -- Move subject to target position, ignoring collision
#	FOR_DISTANCE -- Move subject for a certain distance, respecting collision
#	IN_DIRECTION -- Move subject in direction, stopping on collision

### Movement
var subject : Node2D
var move_onrails_type : RAIL_TYPE
var move_onrails_type_as_str : String:
	get:
		return RAIL_TYPE.keys()[move_onrails_type]
var vel_to_restore : Vector2
var move_onrails_start : Vector2 # Position MoveOnRails was initiated
var move_onrails_target : Vector2 # Position MoveOnRails should end at
var move_onrails_speed : ConstValPair = ConstValPair.new(150.0, 150.0)
var move_onrails_end_dir : float
var move_onrails_dist_left : float

func _init(_subject : Node2D):
	subject = _subject
	cleanup()

func _to_string() -> String:
	"""
	Override so that print() can be used on this object to return String of attributes
	"""
	return ("move_onrails_type: " + move_onrails_type_as_str +
			" vel_to_restore: " + str(vel_to_restore) +
			" move_onrails_start: " + str(move_onrails_start) +
			" move_onrails_target: " + str(move_onrails_target) +
			" move_onrails_speed: " + str(move_onrails_speed) +
			" move_onrails_end_dir: " + str(move_onrails_end_dir) +
			" move_onrails_dist_left: " + str(move_onrails_dist_left)
			)

func update_vel_to_restore(new_velocity : Vector2) -> void:
	"""
	Updates the velocity to restore later

	new_velocity : Vector2 -- new velocity to restore
	"""
	vel_to_restore = new_velocity

func update_speed(new_speed : float) -> void:
	"""
	Updates the speed to move during move-on-rails

	new_speed : float -- new speed move-on-rails
	"""
	move_onrails_speed.val = new_speed

func begin_to_target(
						_move_onrails_target : Vector2,
						_move_onrails_speed : float = move_onrails_speed.CONST,
						_move_onrails_end_dir : float = 0,
						_vel_to_restore : Vector2 = Vector2.ZERO,
					) -> void:
	"""
	Sets given attributes to allow subject to move to target position, ignoring collision

	_move_onrails_target : Vector2 -- position to move subject to
	_move_onrails_speed : float -- speed at which to move the subject
	_move_onrails_end_dir : float -- direction the subject should face once move-on-rails is done
	_vel_to_restore : Vector2 -- velocity subject will be restored to once move-on-rails is done
	"""
	if is_active():
		# Do nothing if currently moving-on-rails
		return
	
	move_onrails_type = RAIL_TYPE.TO_TARGET
	move_onrails_start = subject.global_position
	move_onrails_target = _move_onrails_target
	move_onrails_speed.val = _move_onrails_speed
	move_onrails_end_dir = _move_onrails_end_dir
	vel_to_restore = _vel_to_restore

func begin_for_distance(
							_move_onrails_target : Vector2,
							_move_onrails_dist_left : float,
							_move_onrails_speed : float = move_onrails_speed.CONST,
							_move_onrails_end_dir : float = 0,
							_vel_to_restore : Vector2 = Vector2.ZERO,
						) -> void:
	"""
	Sets given attributes to allow subject to move in direction for a distance, respecting collision

	_move_onrails_target : Vector2 -- direction to move subject in
	_move_onrails_dist_left : float -- distance to move subject
	_move_onrails_speed : float -- speed at which to move the subject
	_move_onrails_end_dir : float -- direction the subject should face once move-on-rails is done
	_vel_to_restore : Vector2 -- velocity subject will be restored to once move-on-rails is done
	"""
	if is_active():
		# Do nothing if currently moving-on-rails
		return

	move_onrails_type = RAIL_TYPE.FOR_DISTANCE
	move_onrails_start = subject.global_position
	move_onrails_target = _move_onrails_target
	move_onrails_dist_left = _move_onrails_dist_left
	move_onrails_speed.val = _move_onrails_speed
	move_onrails_end_dir = _move_onrails_end_dir
	vel_to_restore = _vel_to_restore

func begin_in_direction(
							_move_onrails_target : Vector2,
							_move_onrails_speed : float = move_onrails_speed.CONST,
							_move_onrails_end_dir : float = 0,
						) -> void:
	"""
	Sets given attributes to allow subject to move with given velocity, stopping on collision

	_move_onrails_target : Vector2 -- direction at which to move the subject
	_move_onrails_speed : float -- speed at which to move the subject
	_move_onrails_end_dir : float -- direction the subject should face once move-on-rails is done
	"""
	if is_active():
		# Do nothing if currently moving-on-rails
		return
	
	move_onrails_type = RAIL_TYPE.IN_DIRECTION
	move_onrails_start = subject.global_position
	move_onrails_target = _move_onrails_target
	move_onrails_speed.val = _move_onrails_speed

func is_active() -> bool:
	"""
	Returns : bool -- whether or not subject is currently moving-on-rails
	"""
	return move_onrails_type != RAIL_TYPE.NONE

func is_to_target() -> bool:
	"""
	Returns : bool -- whether or not subject is currently moving-on-rails to a target
	"""
	return move_onrails_type == RAIL_TYPE.TO_TARGET

func is_for_distance() -> bool:
	"""
	Returns : bool -- whether or not subject is currently moving-on-rails for a distance
	"""
	return move_onrails_type == RAIL_TYPE.FOR_DISTANCE

func is_in_direction() -> bool:
	"""
	Returns : bool -- whether or not subject is currently moving-on-rails in a direction
	"""
	return move_onrails_type == RAIL_TYPE.IN_DIRECTION

func get_start() -> Vector2:
	"""
	Returns : Vector2 -- position move-on-rails starts at
	"""
	return move_onrails_start

func get_target() -> Vector2:
	"""
	Returns : Vector2 -- position move-on-rails should end at, or direction move-on-rails should go towards 
	"""
	return move_onrails_target

func cleanup():
	"""
	Sets MoveOnRails attributes to default
	"""
	move_onrails_type = RAIL_TYPE.NONE
	vel_to_restore = Vector2.ZERO
	move_onrails_target = Vector2.ZERO
	move_onrails_speed.val = move_onrails_speed.CONST
	move_onrails_end_dir = 0
