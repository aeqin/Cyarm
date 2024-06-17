extends Control

#region Signals
signal sig_player_swordiai_cancel()
signal sig_cyarm_swordiai_cut(begin_pos : Vector2, end_pos : Vector2)
signal sig_cyarm_swordiai_cancel()

### Components
@onready var c_progress_time_left : TextureProgressBar = $TimeLeftDisplay
@onready var c_line_potential_cut_small_to_big : Line2D = $PotentialCut_small_to_big
@onready var c_line_potential_cut_big_to_small : Line2D = $PotentialCut_big_to_small
@onready var c_timer_timeleft : Timer = $TimeLeftTimer

## Shader vars
var material_default : ShaderMaterial
@onready var shader_default = preload("res://scripts/shaders/unshaded.gdshader")

var max_iai_len : float
var cut_end_point : Vector2
var cut_distance : float

func _ready() -> void:
	## Force node to subscribe to signals
	var _Player : Node = get_tree().get_first_node_in_group("Player")
	self.sig_player_swordiai_cancel.connect(_Player._on_received_swordiai_cancel)

	var _cyarm_sword : Node = get_tree().get_first_node_in_group("CyarmSword")
	self.sig_cyarm_swordiai_cut.connect(_cyarm_sword._on_received_swordiai_cut)
	self.sig_cyarm_swordiai_cancel.connect(_cyarm_sword._on_received_swordiai_cancel)
	
	## Subscribe to signals
	_cyarm_sword.sig_cyarm_sword_disabled.connect(self.die)

	## Set up materials/shaders
	material_default = ShaderMaterial.new()
	material_default.shader = shader_default
	c_progress_time_left.material = material_default # Make sure Timer doesn't get dimmed when World is dimmed during Sword Iai
	c_line_potential_cut_small_to_big.material = material_default # And potential cut line
	c_line_potential_cut_big_to_small.material = material_default

func _process(delta: float) -> void:
	update_inputs()
	
	if not c_timer_timeleft.is_stopped():
		update_timer_progress()
		update_potential_cut()

func update_inputs() -> void:
	"""
	Updates SwordIaiStop depending to button presses
	"""
	## Release Action Button
	if Input.is_action_just_pressed("primary_action"): # Allow Player to cancel Sword Iai
		sig_player_swordiai_cancel.emit()
		sig_cyarm_swordiai_cancel.emit()
		die()
	if Input.is_action_just_released("secondary_action"):
		sig_cyarm_swordiai_cut.emit(global_position, cut_end_point) # Signal Cyarm-Sword to spawn SwordIaiCut
		die()
	
	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		pass
	if Input.is_action_just_pressed("testkey2"):
		pass

func update_timer_progress() -> void:
	"""
	Updates the radial progress that displays time left 
	"""
	c_progress_time_left.value = (c_timer_timeleft.time_left / c_timer_timeleft.wait_time) * c_progress_time_left.max_value

func update_potential_cut() -> void:
	"""
	Updates the potential path of Sword Iai cut
	"""
	# Draw the potential path of Sword Iai cut
	var _dir_to_endpoint : Vector2 = (Globals.mouse_pos - global_position).normalized()
	var _len_to_endpoint : float = global_position.distance_to(Globals.mouse_pos)
	cut_distance = min(max_iai_len, _len_to_endpoint) # Cut has a maximum distance
	cut_end_point = global_position + _dir_to_endpoint * cut_distance
	
	var _local_endpoint : Vector2 = c_line_potential_cut_big_to_small.to_local(cut_end_point)
	var _local_midpoint : Vector2 = _local_endpoint / 2
	c_line_potential_cut_small_to_big.clear_points()
	c_line_potential_cut_big_to_small.clear_points()
	
	# Draw small to big (from start point to midpoint)
	c_line_potential_cut_small_to_big.add_point(Vector2.ZERO)
	c_line_potential_cut_small_to_big.add_point(_local_midpoint)
	
	# Draw big to small (from midpoint to endpoint)
	c_line_potential_cut_big_to_small.add_point(_local_midpoint)
	c_line_potential_cut_big_to_small.add_point(_local_endpoint)

func spawn(player_pos : Vector2, time_until_death : float, max_length : float):
	"""
	Starts the timer that measures time until destruction

	player_pos : Vector2 -- position of the Player
	time_until_death : float -- how long SwordIaiStop lasts
	max_length : float -- the maximum cut length of Sword Iai
	"""
	set_global_position(player_pos) # Display the time left around Sickle
	z_index = Globals.player_z_index + 1 # Display above Player sprite

	# Stop time, then set timer to reenable normal time
	Globals.set_time_scale_stopped()
	c_timer_timeleft.wait_time = time_until_death
	c_timer_timeleft.start()
	
	max_iai_len = max_length # Set max

func die() -> void:
	"""
	Destroys SwordIaiStop
	"""
	Globals.set_time_scale_normal()
	call_deferred("queue_free") # Destroy SwordIaiStop

##################
## Received Signals
##################
func _on_time_left_timer_timeout() -> void:
	"""
	Set time scale back to normal then destroy SwordIaiStop
	"""
	sig_player_swordiai_cancel.emit()
	sig_cyarm_swordiai_cancel.emit()
	die()
	
