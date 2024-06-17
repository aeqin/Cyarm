extends CharacterBody2D

### Signals
signal sig_cyMgr_update_CyP(add_CyP : int)

### Component references
@onready var c_trail : Line2D = $Electro

### ElectroManager
var EM_ref : ElectroManager

### Orbit variables
var orbit_width : float = 10
var orbit_height : float = 10

### Trail variables
var trail_queue : Array = []
var max_trail_length : int = 30

### Follow target variables
var crosshair_ref : Crosshair
var electro_target : Vector2 # Target that Electro is moving toward
var electro_angle : float = TAU # Angle that Electro is moving in
var dist_to_orbit : float = 30.0
var move_speed_min : float = 12
var move_speed_max : float = 2000
var move_speed : float = move_speed_min
var turn_radius_min : float = PI/40
var turn_radius_max : float = PI/8
var turn_radius : float = turn_radius_max

func _ready() -> void:
	## Save reference to ElectroManager
	EM_ref = get_tree().get_first_node_in_group("ElectroManager") as ElectroManager
	
	## Save reference to Crosshair
	crosshair_ref = get_tree().get_first_node_in_group("Crosshair") as Crosshair

func _process(_delta: float) -> void:
	# Update trail
	update_trail()

func _physics_process(_delta: float) -> void:
	# Update Electro variables for this frame
	#electro_target = Globals.mouse_pos
	electro_target = crosshair_ref.get_rand_disc_pos()
	
	# Follow mouse position
	calc_to_target(electro_target)
	
	# Move Electro with velocity
	move_and_slide()
	
func _draw() -> void:
	pass
	# Draw debug stuff
#	var _angle_to_mouse : float = global_position.angle_to_point(electro_target)
#	var _dist : Vector2 = Vector2.RIGHT.rotated(_angle_to_mouse) * 30
#	draw_line(to_local(electro_target), to_local(electro_target + _dist), Color.DARK_RED, 2.0)

######################
## Main functions
######################
func spawn(pos : Vector2) -> void:
	"""
	Spawn Electro
	"""
	# Spawn at right position
	global_position = pos
	visible = true
	
	# Add itself to ElectroManager
	EM_ref.add_electro(self)

func die() -> void:
	"""
	Destroy Electro
	"""
	call_deferred("queue_free")

######################
## Movement Functions
######################
func calc_to_target(target_pos : Vector2) -> void:
	"""
	Modifies velocity to move Electro towards target

	target_pos : Vector2 -- position to move towards
	"""
	velocity = nudge(target_pos)

func nudge(target_pos : Vector2) -> Vector2:
	"""
	Returns : Vector2 -- the movement this physics frame to move Electro towards target
	
	target_pos : Vector2 -- position to move towards
	"""
	var _angle_to_mouse : float = global_position.angle_to_point(target_pos)
	var _dist_to_mouse : float = global_position.distance_to(target_pos)
	var _movement : Vector2

	# Adjust speed and turn radius to increase as distance increases
	move_speed = clampf(move_speed_min * _dist_to_mouse, move_speed_min, move_speed_max)
	turn_radius = clampf(turn_radius_min * _dist_to_mouse, turn_radius_min, turn_radius_max)

	if _dist_to_mouse > dist_to_orbit:
		electro_angle = _angle_to_mouse # Don't bother turning when mouse is really far away
		
	else:
		# Flip (clockwise vs counter-clockwise) 
		if(electro_angle - _angle_to_mouse > PI):
			_angle_to_mouse += TAU # Turn opposite, 180 degrees
		elif (_angle_to_mouse - electro_angle > PI):
			_angle_to_mouse -= TAU
		
		# Turn towards target
		if(electro_angle < _angle_to_mouse):
			electro_angle += turn_radius
		else:
			electro_angle -= turn_radius
	
	_movement = Vector2(
						 cos(electro_angle) * move_speed,
						 sin(electro_angle) * move_speed
						)
	
	return _movement

######################
## State & Animation functions
######################
func update_trail() -> void:
	"""
	Updates a trail behind Electro 
	"""
	trail_queue.push_front(global_position) # Add point to trail
	if trail_queue.size() > max_trail_length:
		# Fade trail
		trail_queue.pop_back()

	# Redraw trail every frame
	c_trail.clear_points()
	for pt in trail_queue:
		var _local_pos : Vector2 = to_local(pt) # Line2D draws in local space
		c_trail.add_point(_local_pos)
