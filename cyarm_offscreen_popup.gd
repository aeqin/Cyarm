extends Control

### Components
@onready var c_panel : Panel = $Panel
@onready var c_label : Label = $Panel/Label
@onready var c_viewport : SubViewport = $Panel/SubViewportContainer/SubViewport
@onready var c_camera : Camera2D = $Panel/SubViewportContainer/SubViewport/Camera2D
@onready var c_timer : Timer = $SpawnTimer

enum ScreenLoc {NON_EDGE,
				TOP, BOTTOM,
				LEFT, RIGHT,
				TOP_LEFT, TOP_RIGHT,
				BOTTOM_LEFT, BOTTOM_RIGHT}
var f_close_to_recall : bool = false: # When Cyarm is close to being recalled automatically back to player (from getting too far)
	set(flag):
		if f_close_to_recall != flag:
			update_popup(f_close_to_recall)
		f_close_to_recall = flag
var f_spawn_popup : bool = false

var max_x_pos : float
var max_y_pos : float

##################
## Main Functions
##################
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## Subscribe to signals
	var _CyarmManager : Node = get_tree().get_first_node_in_group("CyarmManager")
	_CyarmManager.connect("sig_cyPop_spawn_offscreen_popup", _on_received_spawn_offscreen_popup)

	# Make sure viewport is connected to the main world
	c_viewport.world_2d = Globals.main_world
	# Popup maximum x and y positions depend on its panel size
	max_x_pos = Globals.viewport_bound_x - c_panel.size.x
	max_y_pos = Globals.viewport_bound_y - c_panel.size.y
	
	# Hide and disable Popup on spawn
	f_spawn_popup = false
	_on_spawn_timer_timeout()

func _physics_process(_delta: float) -> void:
	# Have camera follow the position of the Cyarm
	c_camera.global_position = Globals.cyarm_pos
	
	# Have popup be in the position of Cyarm, clamped to the edge of the screen
	position_popup_at_cyarm()
	
	# Update popup visuals
	c_label.text = str(snapped(Globals.CM_cyarm_to_player_dist, 1)) # Display distance
	f_close_to_recall = Globals.CM_cyarm_to_player_dist / Globals.CM_cyarm_to_player_maxdist < 0.9 # 90%

func position_popup_at_cyarm():
	"""
	Positions the CyarmOffscreenPopup at the edge of the screen to follow Cyarm's position
	"""
	global_position = Globals.cyarm_canvas_pos - c_panel.size / 2
	global_position.x = clamp(global_position.x, 0, max_x_pos)
	global_position.y = clamp(global_position.y, 0, max_y_pos)

func update_popup(is_close : bool) -> void:
	"""
	Changes CyarmOffscreenPopup to indicate when Cyarm is close to leaving max range from Player
	"""
	if is_close:
		c_panel.get_theme_stylebox("panel").bg_color = Color.RED
	else:
		c_panel.get_theme_stylebox("panel").bg_color = Color("#d6f731")

func get_screen_location() -> ScreenLoc:
	"""
	Returns : ScreenLoc -- the location of the popup in regards to the screen
	"""
	var f_top : bool = is_equal_approx(global_position.y, 0)
	var f_bottom : bool = is_equal_approx(global_position.y, max_y_pos)
	var f_left : bool = is_equal_approx(global_position.x, 0)
	var f_right : bool = is_equal_approx(global_position.x, max_x_pos)
	
	if f_top:
		if f_left:
			return ScreenLoc.TOP_LEFT
		elif f_right:
			return ScreenLoc.TOP_RIGHT
		else:
			return ScreenLoc.TOP
	elif f_bottom:
		if f_left:
			return ScreenLoc.BOTTOM_LEFT
		elif f_right:
			return ScreenLoc.BOTTOM_RIGHT
		else:
			return ScreenLoc.BOTTOM
	elif f_left:
		return ScreenLoc.LEFT
	elif f_right:
		return ScreenLoc.RIGHT
	else:
		return ScreenLoc.NON_EDGE

func get_panel_pivot_from_screen_loc() -> Vector2:
	"""
	Returns : Vector2 -- the position of the panel's pivot offset to match popup's screen location
	"""
	match get_screen_location():
		ScreenLoc.TOP_LEFT:
			return Vector2.ZERO
		ScreenLoc.TOP_RIGHT:
			return Vector2(c_panel.size.x, 0)
		ScreenLoc.BOTTOM_LEFT:
			return Vector2(0, c_panel.size.y)
		ScreenLoc.BOTTOM_RIGHT:
			return Vector2(c_panel.size.x, c_panel.size.y)
		ScreenLoc.TOP:
			return Vector2(c_panel.size.x / 2, 0)
		ScreenLoc.BOTTOM:
			return Vector2(c_panel.size.x / 2, c_panel.size.y)
		ScreenLoc.LEFT:
			return Vector2(0, c_panel.size.y / 2)
		ScreenLoc.RIGHT:
			return Vector2(c_panel.size.x, c_panel.size.y / 2)
	
	return Vector2(c_panel.size.x / 2, c_panel.size.y / 2) # ScreenLoc.NON_EDGE is center pivot

##################
## Received Signals
##################
func _on_received_spawn_offscreen_popup(do_spawn : bool, wait_timer : float = 0.0) -> void:
	"""
	Either shows or hides CyarmOffscreenPopup
	
	do_spawn : bool -- whether popup is shown or hidden
	wait_timer : float -- how long before popup is shown or hidden
	"""
	# Stop the timer (disregards any past commands)
	c_timer.stop()
	
	# Show or hide
	f_spawn_popup = do_spawn

	if wait_timer > 0.0:
		# Show/hide popup after a delay
		c_timer.wait_time = wait_timer
		c_timer.start()
	else:
		_on_spawn_timer_timeout() # Directly show/hide the popup if there's no delay

func _on_spawn_timer_timeout() -> void:
	"""
	Either shows or hides CyarmOffscreenPopup when timer times out
	"""
	if f_spawn_popup:
		position_popup_at_cyarm()
		set_physics_process(true)
		show()

		# Have the popup "pop" into view
		c_panel.pivot_offset = get_panel_pivot_from_screen_loc()
		var embiggen_tween : Tween = create_tween()
		embiggen_tween.tween_property(c_panel, "scale", Vector2.ONE, 0.1).from(Vector2.ZERO)
	else:
		hide()
		set_physics_process(false) # Do not process while invisible
