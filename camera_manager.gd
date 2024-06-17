extends Node
class_name CameraManager

# Signals

# Components
@onready var c_camera : Camera2D = $Camera2D

# Player ref
var player_ref : Node2D

# Camera follow variables
var f_spawned : bool = false
var f_camera_reached : bool = false
var target_pos : Vector2
var target_node : Node2D
var move_speed : float = 5.0

func _ready() -> void:
	## Set Globals
	
	## Subscribe to signals
	player_ref = get_tree().get_first_node_in_group("Player")
	player_ref.connect("sig_player_readied", _on_received_player_readied)
	player_ref.connect("sig_cameraMgr_follow_node", _on_received_follow_node)
	player_ref.connect("sig_cameraMgr_follow_pos", _on_received_follow_pos)
	var _CyarmManager : Node = get_tree().get_first_node_in_group("CyarmManager")
	_CyarmManager.connect("sig_cameraMgr_follow_node", _on_received_follow_node)
	
	c_camera.enabled = false
	
func _process(_delta: float) -> void:
	update_globals()
	
func _physics_process(delta: float) -> void:
	if f_spawned:
		update_target_pos()
		move_camera(delta)

func update_globals() -> void:
	"""
	Updates variables in Globals script
	"""
	Globals.CamM_f_camera_reached = f_camera_reached

func spawn_camera() -> void:
	"""
	Sets up the main camera
	"""
	# First follow Player node, and set default camera start position on Player position
	target_node = player_ref
	update_target_pos()
	
	# Enable camera
	c_camera.enabled = true
	c_camera.global_position = target_pos
	c_camera.make_current() # Make this "Main" camera
	Globals.main_world = c_camera.get_viewport().world_2d # Main world is attached the main camera
	f_spawned = true

func update_target_pos() -> void:
	"""
	Updates the target position for Camera to follow
	"""
	if target_node:
		target_pos = Utilities.get_middlepos_of(target_node)

func move_camera(delta : float) -> void:
	"""
	Updates camera global_position to smoothly move towards target position
	
	delta : float -- time between physics frames
	"""
	var target = target_pos
	var mid_x = (target.x + Globals.mouse_pos.x) / 2
	var mid_y = (target.y + Globals.mouse_pos.y) / 2
	
	c_camera.global_position = c_camera.global_position.lerp(target, move_speed * delta)
	if Utilities.approx_equal_vec2(c_camera.global_position, target, 1.0):
		f_camera_reached = true
	else:
		f_camera_reached = false

##################
## Received Signals
##################
func _on_received_player_readied() -> void:
	spawn_camera()

func _on_received_follow_pos(new_pos : Vector2) -> void:
	"""
	Adjusts camera focus onto position
	
	new_pos: Vector2 -- new position to focus camera on
	"""
	target_pos = new_pos
	target_node = null # Unfocus from whatever Node camera was watching

func _on_received_follow_node(new_node : Node2D) -> void:
	"""
	Adjusts camera focus onto new node
	
	new_node : Node2D -- new node to focus camera on
	"""
	target_node = new_node
