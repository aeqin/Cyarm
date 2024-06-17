extends Area2D

### Signals

### Component references
@onready var c_collider : CollisionShape2D = $LightningCollider
@onready var c_line_bolt_1 : Line2D = $Bolt1
@onready var c_line_bolt_2 : Line2D = $Bolt2
@onready var c_line_bolt_3 : Line2D = $Bolt3
@onready var c_line_bolt_4 : Line2D = $Bolt4

## Position
var f_spawned : bool = false
var start_pos : Vector2
var end_pos : Vector2

## Segment size (how big each kink of each bolt is)
var min_segment : float = 6.0
var max_segment : float = 14.0
var min_angle : float = -20.0 # How far to rotate until starting next kink
var max_angle : float = 20.0

## Damage
var o_lightning_damage : DamageManager.DamageBase = DamageManager.DamageBase.new(self, 30, 0, 1.0)

var damaged_dict : Dictionary = {} # Hold a dictionary of {Ref -> time of hit}, so that Lightning doesn't "hit" the same target multiple times in quick succession
var damage_mtick_cooldown : int = 550 # How many milliseconds can pass before Lighting can hit the same target again

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if f_spawned:
		draw_lightning() # Draw Lightning
		
		# Do Lightning damage
		for hit_body in damaged_dict:
			calc_lightning_hit(hit_body)

func spawn(spawn_start_pos : Vector2, spawn_end_pos : Vector2) -> void:
	"""
	Spawn Lightning
	spawn_start_pos : Vector2 -- start position of Lightning
	spawn_end_pos : Vector2 -- end position of Lightning
	"""
	# Position Lightning
	start_pos = spawn_start_pos
	end_pos = spawn_end_pos
	o_lightning_damage.modify_from_pos((start_pos + end_pos) / 2) # Avg position
	
	# Calculate angle (to make sure that Lightning doesn't become too thick)
	var _dist = start_pos.distance_to(end_pos)
	max_angle = Utilities.map(
								clampf(_dist, 10, 500),
								10, 500,  # Bigger distance
								25, 10    # Mapped to smaller angle
							) 
	min_angle = -1 * max_angle
	
	# Draw Lightning collision
	(c_collider.shape as RectangleShape2D).size.x = _dist # Length of rectangle
	c_collider.global_position = (start_pos + end_pos) / 2 # Midpoint beween start and end
	c_collider.rotation = (end_pos - start_pos).angle() # Rotate rectangle
	c_collider.disabled = false # Enable collision
	
	# Make sure Lightning draws above the Player sprite
	z_index = Globals.player_z_index + 1
	
	f_spawned = true # Set flag

func draw_lightning() -> void:
	"""
	Draws Lightning
	"""
	draw_bolt(start_pos, end_pos, c_line_bolt_1)
	draw_bolt(start_pos, end_pos, c_line_bolt_2)
	draw_bolt(start_pos, end_pos, c_line_bolt_3)
	draw_bolt(start_pos, end_pos, c_line_bolt_4)
	
func draw_bolt(start_pos : Vector2, end_pos : Vector2, bolt : Line2D) -> void:
	"""
	Draws each individual bolt that makes up Lightning
	
	start_pos : Vector2 -- start position of bolt 
	end_pos : Vector2 -- end position of bolt
	bolt : Line2D -- bolt to draw
	"""
	bolt.clear_points() # Redraw every frame
	
	bolt.add_point(to_local(start_pos)) # Start bolt pos
	
	## Draw the in-between bolt pos
	# First draw a point, rotate and move a random segment length to next point, then continue until the
	# distance to the end point is less than the maximum segment length
	var curr_pos : Vector2 = start_pos
	while curr_pos.distance_to(end_pos) > max_segment:
		# Point directly at end pos so rotation will never randomly turn backwards
		var move_vector = curr_pos.direction_to(end_pos) * Globals.random.randf_range(min_segment, max_segment)
		var new_point_rotated = curr_pos + move_vector.rotated(deg_to_rad(Globals.random.randf_range(min_angle, max_angle)))
		bolt.add_point(to_local(new_point_rotated))
		curr_pos = new_point_rotated
	
	bolt.add_point(to_local(end_pos)) # End bolt pos

func calc_lightning_hit(hit_body : Node2D) -> void:
	"""
	Calculates whether Lightning hit any target, and does damage
	"""
	if Utilities.is_damageable(hit_body):
		# Calculate if Lightning can hit this target
		var _can_hit : bool = true
		if damaged_dict.has(hit_body):
			# Make sure that Lightning doesn't "hit" the same target multiple times in quick succession
			if Time.get_ticks_msec() - damaged_dict[hit_body] < damage_mtick_cooldown:
				_can_hit = false

		# Do damage
		if _can_hit:
			var _dmg_result : DamageManager.DamageResult = DamageManager.calc_damage(o_lightning_damage, hit_body)
			
			if _dmg_result != DamageManager.DamageResult.IGNORE:
				damaged_dict[hit_body] = Time.get_ticks_msec() # Save the time of this hit

func _on_body_entered(hit_body : Node2D) -> void:
	"""
	When hit_body enters Lightning collision
	"""
	damaged_dict[hit_body] = 0

func _on_body_exited(hit_body: Node2D) -> void:
	"""
	When hit_body exits Lightning collision
	"""
	damaged_dict.erase(hit_body)
