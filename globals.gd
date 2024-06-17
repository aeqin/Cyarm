extends Node2D

## Signals
signal sig_globals_time_scale_changed(old_time_scale : float, new_time_scale : float)

## Debug mode
const DEBUG_MODE : bool = false # Setting to false prevents DebugDraw and DebugStats from drawing on screen

## World Variables
var main_world : World2D # The main "world" that links physics and rendering together
var main_viewport : Viewport # The main screen
var viewport_rect : Rect2
var viewport_bound_x : float # The edge of the horizontal screen
var viewport_bound_y : float # The edge of the vertical screen

## Player Variables
var player_f_is_grounded : bool
var player_max_HP : int
var player_z_index : int
var player_pos : Vector2 = Vector2.ZERO # Position at Player sprite feet
var player_center_pos : Vector2 = Vector2.ZERO # Position at Player sprite center
var player_canvas_pos : Vector2 = Vector2.ZERO # Position of Player in regards to screen coords

var player_cyarm_follow_pos : Vector2 = Vector2.ZERO # Position near the player where the Cyarm should follow
var player_sickle_tether_pos : Vector2 = Vector2.ZERO # Position where Cyarm-Sickle should tether to

## CyarmManager Variables
var CM_cyarm_to_player_dist : float # Distance of Cyarm to Player
var CM_cyarm_to_player_maxdist : float # Maximum distance of Cyarm to Player

## Cyarm Variables
var cyarm_state : String # State of the Cyarm
var cyarm_pos : Vector2 = Vector2.ZERO # Position of the Cyarm
var cyarm_canvas_pos : Vector2 = Vector2.ZERO # Position of the Cyarm in regards to screen coords
var cyarm_f_follow : bool # Is Cyarm following a position?
var cyarm_f_follow_player : bool # Is Cyarm following Player
var cyarm_sickle_tetherpos : Vector2 = Vector2.ZERO # Position of Cyarm-Sickle's tether position

## ElectroManager Variables
var EM_f_can_electro_cast : bool
var EM_curr_electro : float
var EM_curr_electro_ratio : float

## CameraManager Variables
var CamM_f_camera_reached : bool

## CheckpointManager Variables
var CheckpointM_curr_checkpoint_pos : Vector2

## Mouse Position Variables
var mouse_pos : Vector2 = Vector2.ZERO # Position of the mouse (global_position)
var mouse_canvas_pos : Vector2 = Vector2.ZERO # Position of the mouse in regards to screen coords

## Time Scale Variables
var time_scale : float = 1.0 # How fast time is perceived in game (1.0 is normal, 0.0 is stopped)
const TIME_SLOW : float = 0.1 # Typical slowed down time scale
const TIME_NORMAL : float = 1.0 # Typical normal time scale
const TIME_STOP : float = 0.0 # Typical stopped time scale

## Random
var random : RandomNumberGenerator = RandomNumberGenerator.new()

## Color Constants
const CY_GREEN : Color = Color("#43efb5")
const CY_RED : Color = Color("#e23d4b")

#############################
## Main Functions
#############################
func _ready() -> void:
	# Set Viewport variables
	main_viewport = get_viewport()
	viewport_rect = main_viewport.get_visible_rect()
	viewport_bound_x = viewport_rect.size.x
	viewport_bound_y = viewport_rect.size.y
	
	# Set Random seed
	random.randomize()
	print(self, "Set random seed as: ", random.seed)
	
	## Add to DebugStats
	DebugStats.add_stat(self, "time_scale")
	DebugStats.add_stat(self, "mouse_pos")
	DebugStats.add_stat(self, "mouse_canvas_pos")
	DebugStats.add_stat(self, "EM_curr_electro")
	DebugStats.add_stat(self, "CamM_f_camera_reached")

func _process(_delta : float) -> void:
	update_mouse_pos()

func update_mouse_pos() -> void:
	# Have Globals store mouse position once each frame, so other Nodes don't need to call get_global_mouse_position() multiple times per frame
	mouse_pos = get_global_mouse_position()
	mouse_canvas_pos = get_viewport().get_mouse_position()

#############################
## Time Scale Functions
#############################
func set_time_scale(new_time_scale : float):
	"""
	Sets the timescale of the world
	
	new_time_scale : float -- new time scale, assumes range between [0, 1]
	"""
	if time_scale == new_time_scale:
		# Don't call the setter if new timescale is the same as before
		return
	
	sig_globals_time_scale_changed.emit(time_scale, new_time_scale) # Emit signal to all relevant nodes that care about time
	time_scale = new_time_scale
	
func set_time_scale_normal():
	"""
	Sets the timescale of the world to normal 1.0
	"""
	set_time_scale(Globals.TIME_NORMAL)

func set_time_scale_slow():
	"""
	Slows the world down to 0.1
	"""
	set_time_scale(Globals.TIME_SLOW)

func set_time_scale_stopped():
	"""
	Stops the world
	"""
	set_time_scale(Globals.TIME_STOP)
