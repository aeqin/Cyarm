extends CharacterBody2D
class_name Crosshair

### Component references
@onready var c_sprite : AnimatedSprite2D = $CrosshairSprite
@onready var c_sprite_sub : AnimatedSprite2D = $Anchor/CrosshairSubSprite

### State
var cyarm_manager_ref : CyarmManager
enum CrossState {DEFAULT, HIT,}
var cross_curr_state : CrossState = CrossState.DEFAULT
var c_sprite_to_display : AnimatedSprite2D = c_sprite

### Mouse
var mouse_ref : InputEventMouseMotion

### Rotation disc variables
# Rotation disc is an invisible collection of Marker2D that rotate over time, so that Electro have
# a more dynamic and interesting target to follow that simply the Crosshair global_position
var marker_dist : float = 2.3
var rotation_speed : float = deg_to_rad(60) * .2

func _ready() -> void:
	## Save reference to CyarmManager
	cyarm_manager_ref = get_tree().get_first_node_in_group("CyarmManager") as CyarmManager

	## Subscribe to signals
	var _World : Node2D = get_tree().get_first_node_in_group("World")
	_World.connect("sig_world_paused", _on_received_world_paused)
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_player_readied", _on_received_player_readied)
	
	### Hide mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	# Crosshair position, depending on current Cyarm mode
	update_crosshairs()

	# Crosshair sprite, depending on current Cyarm mode
	update_state()

######################
## State & Animation functions
######################
func update_crosshairs(mouse_pos : Vector2 = Globals.mouse_pos) -> void:
	"""
	There are 2 Crosshairs:
		main one that follows mouse position
		sub one that follows the position most relevant to the current Cyarm
	"""
	var _main_pos : Vector2 = mouse_pos
	var _sub_pos : Vector2 = cyarm_manager_ref.get_crosshair_proposed_pos()
	
	if _main_pos == _sub_pos:
		c_sprite_sub.visible = false # Hide the sub Crosshair
		c_sprite_to_display = c_sprite # Change sprite of main Crosshair

	else:
		c_sprite_sub.visible = true # Reveal the sub Crosshair
		c_sprite_sub.global_position = _sub_pos
		c_sprite_to_display = c_sprite_sub # Change sprite of sub Crosshair

	global_position = _main_pos # Position main Crosshair

func update_state() -> void:
	"""
	Changes Crosshair sprite depending on current Cyarm
	"""
	# If current Cyarm can hit Enemy at current mouse pos
	if cross_curr_state == CrossState.DEFAULT and cyarm_manager_ref.cyarm_can_hit():
		c_sprite_to_display.play("hit")
		cross_curr_state = CrossState.HIT

	# If current Cyarm cannot hit Enemy at current mouse pos
	elif cross_curr_state == CrossState.HIT and not cyarm_manager_ref.cyarm_can_hit():
		c_sprite_to_display.play("default")
		cross_curr_state = CrossState.DEFAULT

##################
## Received Signals
##################
func _on_received_player_readied() -> void:
	# Make sure Crosshair draws above the Player sprite
	z_index = Globals.player_z_index + 100
	
func _on_received_world_paused(pause_status : bool) -> void:
	"""
	pause_status : bool -- whether World gets paused or unpaused
	
	Since Crosshair gets paused alongside the World, hide its sprite
	"""
	update_crosshairs() # Since crosshairs may move in pause menu, update position before showing crosshairs again

	visible = not pause_status
	c_sprite_sub.visible = false # Hide the sub Crosshair
