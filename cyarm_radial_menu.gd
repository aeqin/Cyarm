#@tool # Allow script to run in editor
extends Control

# Signals
signal sig_cyMgr_change_mode(cyarm : CyarmManager.CyMode, action_context : CyarmActionContext)

# Components
@onready var c_sprite_crosshair : AnimatedSprite2D = $DONT_SCALE_CROSSHAIR/CrosshairSprite

# Style vars
@export var color_background : Color
@export var color_line : Color
@export var color_highlight : Color
@export var radius_outer : int = 96
@export var radius_inner : int = 40
@export var line_width : int = 2
@export var cyarm_textures : Array[Texture2D]
@export var cancel_texture : Texture2D
@export var lock_texture : Texture2D
@export var num_options : int = 3
@export var slice_offset : float = TAU / 4 # Radians (used to rotate the drawing of the radial menu)

var f_locked_selection : bool = false
var selection : int # Chosen option
var action_context : CyarmActionContext = CyarmActionContext.new()
var func_get_icon_texture_ref : Callable # Reference to CyarmManager.get_radial_icon_action_texture(mode : CyMode, action_context : CyarmActionContext)

func _ready() -> void:
	hide_menu() # Menu should only be available when game paused

	# Subscribe to signals
	var _World : Node2D = get_tree().get_first_node_in_group("World")
	_World.connect("sig_world_paused", _on_received_world_paused)

	var _Cyarm_manager : Node = get_tree().get_first_node_in_group("CyarmManager")
	func_get_icon_texture_ref = _Cyarm_manager.get_radial_icon_action_texture

func _process(delta: float) -> void:
	# Update CyarmActionContext object
	update_inputs()
	
	# The normal World crosshair is paused, so update position for another one
	c_sprite_crosshair.global_position = get_global_mouse_position()

	# Draw CyarmRadialMenu
	queue_redraw()

func _draw():
	# Main wheel
	draw_circle(Vector2.ZERO, radius_outer, color_background)
	
	# Inner wheel
	draw_arc(Vector2.ZERO, radius_inner, 0, TAU, 256, color_line, line_width, false)
	
	# Calculate selection
	selection = calc_selection()
	
	# Draw slices
	draw_slices()

func update_inputs() -> void:
	"""
	Updates CyarmActionContext object
	"""
	var _primary_pressed : bool = Input.is_action_pressed("primary_action")
	var _secondary_pressed : bool = Input.is_action_pressed("secondary_action")
	action_context.set_all(
							_primary_pressed,
							_secondary_pressed,
							get_global_mouse_position())
	
	# If pressing an action button, then "lock" the current selection so that moving the mouse
	# can aim the currently selected action instead of swtiching to a different Cyarm selection
	if _primary_pressed or _secondary_pressed:
		f_locked_selection = true
	else:
		f_locked_selection = false
		
	# If pressing action buttons while in "cancel" zone, then override context and don't register
	# action buttons as pressed, so that the cyarm textures don't change
	#if selection == -1:
	#	action_context.set_primary_pressed(false)
	#	action_context.set_secondary_pressed(false)

func hide_menu() -> void:
	"""
	When the World is resumed, hide CyarmRadialMenu
	"""
	hide() # Hide change Cyarm UI
	
	c_sprite_crosshair.visible = false # Hide crosshair
	
	# Disable processes
	set_process(false)
	set_physics_process(false)

func show_menu() -> void:
	"""
	When the World is paused, show CyarmRadialMenu
	"""
	# Enable processes
	set_process(true)
	set_physics_process(true)
	
	# Warp mouse to center of UI
	warp_mouse(Vector2.ZERO)
	
	show() # Show change Cyarm UI
	
	# On show, grow the UI
	var _grow_tween = create_tween()
	_grow_tween.set_parallel(true)
	_grow_tween.tween_property(self, "scale", Vector2.ONE, 0.1).from(Vector2(0.2, 0.2))
	
	c_sprite_crosshair.visible = true # Show crosshair

func calc_selection() -> int:
	"""
	Calculate which slice the mouse is hovering over
	
	Returns : int -- the integer that represents the selection of a section of the radial menu
	"""
	# If selection is "locked", simply return the already selected selection
	if f_locked_selection:
		return selection
	
	var _mouse_pos : Vector2 = get_local_mouse_position() # From center of screen [0,0]
	var _mouse_radius : float = _mouse_pos.length()
	var _selection : int = -1
	
	if _mouse_radius < radius_inner: # Within inner circle
		_selection = -1
	else:
		var _mouse_radians : float = fposmod(_mouse_pos.angle() * -1, TAU) # Clamp to positive [0, TAU]
		_selection = wrapi((_mouse_radians + slice_offset) / TAU * num_options, 0, num_options) # If over num_options (because of offset), wrap back to 0

	return _selection

func draw_slices() -> void:
	"""
	Draw each slice (borders, highlighted slice, Cyarm textures) of the radial menu.
	"""
	for option in range(num_options):
		var _angle_start : float = TAU * (float(num_options - option) / num_options) + slice_offset # Angle of slice START
		var _angle_end : float = TAU * (float(num_options - option - 1) / num_options) + slice_offset # Angle of slice END
		var _point_start_inner : Vector2 = Vector2(radius_inner * cos(_angle_start), radius_inner * sin(_angle_start)) # BEGIN coord of slice START
		var _point_start_outer : Vector2 = Vector2(radius_outer * cos(_angle_start), radius_outer * sin(_angle_start)) # END coord of slice START
		
		# Draw border (slice START)
		draw_line(_point_start_inner, _point_start_outer, color_line, line_width)
		
		# Highlight selection
		if selection == -1:
			# Highlight inner circle
			draw_circle(Vector2.ZERO, radius_inner, color_highlight)
		elif selection == option:
			# Highlight slice of circle
			var _num_points : int = 32 # Bigger means smoother arc
			var _points_inner = PackedVector2Array()
			var _points_outer = PackedVector2Array()

			# Highlight slice by filling in the shape made from the points of the inner and outer arc
			for p in range(_num_points + 1):
				var _between_angle = _angle_start + p * (_angle_end - _angle_start) / _num_points
				_points_inner.push_back(Vector2(cos(_between_angle), sin(_between_angle)) * radius_inner)
				_points_outer.push_back(Vector2(cos(_between_angle), sin(_between_angle)) * radius_outer)
			
			_points_outer.reverse() # Need to reverse _points_outer so that first point in array does not cross over shape
			draw_polygon(_points_inner + _points_outer, PackedColorArray([color_highlight]))
			
		## Draw Cyarm texture (in the middle of each slice)
		# Calculate position
		var _mid_angle = (_angle_start + _angle_end) / 2
		var _point_start_middle : Vector2 = Vector2(radius_inner * cos(_mid_angle), radius_inner * sin(_mid_angle))
		var _point_end_middle : Vector2 = Vector2(radius_outer * cos(_mid_angle), radius_outer * sin(_mid_angle))
		var _point_mid_middle : Vector2 = (_point_start_middle + _point_end_middle) / 2
		# Get texture from reference to texture function
		var _relevant_context : CyarmActionContext = action_context if (selection == option) else null # Only pass CyarmActionContext if relevant Cyarm is selected
		var _action_texture : CyarmBase.CyarmActionTexture = func_get_icon_texture_ref.call(get_cymode_from_option(option), _relevant_context)
		var _icon_texture : Texture2D = _action_texture.texture
		draw_texture(_icon_texture, _point_mid_middle - _icon_texture.get_size() / 2)
	
	# Draw center texture
	if f_locked_selection and selection != -1:
		draw_texture(lock_texture, Vector2.ZERO - lock_texture.get_size() / 2)
	elif selection == -1:
		draw_texture(cancel_texture, Vector2.ZERO - cancel_texture.get_size() / 2)

func get_cymode_from_option(option : int) -> CyarmManager.CyMode:
	"""
	Returns the translation of option to CyarmManager.CyMode
	
	option : int -- the option on CyarmRadialMenu to translate
	"""
	match option:
		0:
			return CyarmManager.CyMode.SWORD
		1:
			return CyarmManager.CyMode.SICKLE
		2:
			return CyarmManager.CyMode.SHIELD
		
	return CyarmManager.CyMode.SWORD # Default

func choose_cyarm() -> void:
	"""
	Emit signal to change Cyarm based on selection in radial menu
	"""
	if selection == -1:
		pass # Select nothing
	
	sig_cyMgr_change_mode.emit(get_cymode_from_option(selection), action_context)

##################
## Received Signals
##################
func _on_received_world_paused(paused : bool) -> void:
	if paused:
		show_menu() # Show UI
	else:
		hide_menu() # Hide UI
		choose_cyarm()
