extends Node2D

#region Debug vars
var debug_point_arr : Array[DebugPoint] = []
var debug_point_dict : Dictionary = {}

var debug_line_arr : Array[DebugLine] = []
var debug_line_dict : Dictionary = {}

var debug_arc_arr : Array[DebugArc] = []
var debug_arc_dict : Dictionary = {}

var id_counter : int = 0
#endregion

#region DebugPoint (class used to store points)
class DebugPoint:
	var ref : Node2D
	var id : String
	var pos : Vector2
	var color : Color
	var size : float
	var label : Label

	func _init(_ref : Node2D, _id : String, _pos : Vector2, _color : Color, _size : float):
		"""
		_ref : Node2D -- reference to DebugDraw parent class
		_id : String -- name of DebugPoint
		_pos : Vector2 -- position of DebugPoint (global_position)
		_color : Color -- color of DebugPoint
		_size : float -- size of DebugPoint
		"""
		ref = _ref
		id = _id
		pos = _pos
		color = _color
		size = _size
		
		# Auto-assign a name, if one isn't provided
		if id.is_empty():
			id = str(_ref.id_counter)
			_ref.id_counter += 1
		
		# Create a Label to display the id
		label = ref.create_label(id, color)
#endregion

#region DebugLine (class used to store lines)
class DebugLine:
	var ref : Node2D
	var id : String
	var pos_from : Vector2
	var pos_to: Vector2
	var color : Color
	var width : float
	var label : Label

	func _init(_ref : Node2D, _id : String, _pos_from : Vector2, _pos_to : Vector2, _color : Color, _width : float):
		"""
		_ref : Node2D -- reference to DebugDraw parent class
		_id : String -- name of DebugLine
		_pos_from : Vector2 -- start position of DebugLine (global_position)
		_pos_to : Vector2 -- end position of DebugLine (global_position)
		_color : Color -- color of DebugLine
		_width : float -- width of DebugLine
		"""
		ref = _ref
		id = _id
		pos_from = _pos_from
		pos_to = _pos_to
		color = _color
		width = _width
		
		# Auto-assign a name, if one isn't provided
		if id.is_empty():
			id = str(_ref.id_counter)
			_ref.id_counter += 1

		# Create a Label to display the id
		label = ref.create_label(id, color)
#endregion

#region DebugArc (class used to store arcs)
class DebugArc:
	var ref : Node2D
	var id : String
	var pos : Vector2
	var radius : float
	var angle_from : float
	var angle_to : float
	var num_points : int
	var color : Color
	var width : float
	var use_aa : bool
	var label : Label

	func _init(
				_ref : Node2D, _id : String, _pos : Vector2, _radius : float,
				_angle_from : float, _angle_to : float, _num_points : int,
				_color : Color, _width : float, _use_aa : bool
			):
		"""
		_ref : Node2D -- reference to DebugDraw parent class
		_id : String -- name of DebugArc
		_pos : Vector2 -- position of DebugArc (global_position)
		_radius : float -- radius of DebugArc's circle
		_angle_from : float -- angle to start drawing arc (radians)
		_angle_to : float -- angle to end drawing arc (radians)
		_num_points : int -- how many points to draw arc with (higher is less jagged arc)
		_color : Color -- color of DebugArc
		_width : float -- width of DebugArc
		_use_aa : bool -- whether arc should be drawn with antialiasing
		"""
		ref = _ref
		id = _id
		pos = _pos
		radius = _radius
		angle_from = _angle_from
		angle_to = _angle_to
		num_points = _num_points
		color = _color
		width = _width
		use_aa = _use_aa
		
		# Auto-assign a name, if one isn't provided
		if id.is_empty():
			id = str(_ref.id_counter)
			_ref.id_counter += 1

		# Create a Label to display the id
		label = ref.create_label(id, color)
#endregion

func _ready() -> void:

	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_player_readied", _on_received_player_readied)
	
	if not Globals.DEBUG_MODE:
		# If debug mode is set to false, disable physics and process calls
		set_process(false)
		set_physics_process(false)
	
func _process(_delta: float) -> void:
	if not Globals.DEBUG_MODE:
		# If debug mode is set to false, don't draw
		return
	
	# For _draw()
	queue_redraw()

func _draw() -> void:
	# Draw debug points
	for dp:DebugPoint in debug_point_arr:
		# Draw the circle
		draw_circle(to_local(dp.pos), dp.size, dp.color)
		dp.label.global_position = dp.pos

	# Draw debug lines
	for dl:DebugLine in debug_line_arr:
		# Draw the line
		draw_line(to_local(dl.pos_from), to_local(dl.pos_to), dl.color, dl.width)
		dl.label.global_position = dl.pos_from

	# Draw debug arcs
	for da:DebugArc in debug_arc_arr:
		# Draw the arc
		draw_arc(to_local(da.pos), da.radius, da.angle_from, da.angle_to, da.num_points, da.color, da.width, da.use_aa)
		da.label.global_position = da.pos

func create_label(id : String, color : Color) -> Label:
	"""
	Returns : Label -- a Label used to display the id of a DebugDraw
	
	id : String -- the name of the DebugDraw to display
	"""
	var label : Label = Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.text = id
	add_child(label)

	return label

func add_debug_point(_id : String, _pos : Vector2, _color : Color, _size : float) -> void:
	"""
	Adds a DebugPoint to draw every frame

	_id : String -- name of DebugPoint
	_pos : Vector2 -- position of DebugPoint (global_position)
	_color : Color -- color of DebugPoint
	_size : float -- size of DebugPoint

	DebugDraw.add_debug_point("example_point", global_position, Color.RED, 3)
	"""
	if debug_point_dict.has(_id):
		update_debug_point(_id, _pos, _color, _size)
	else:
		var dp : DebugPoint = DebugPoint.new(self, _id, _pos, _color, _size)
		debug_point_arr.append(dp)
		debug_point_dict[dp.id] = dp

func update_debug_point(_id : String, _pos : Vector2, _color : Color, _size : float):
	"""
	Updates a DebugPoint already drawn
	
	_id : String -- name of DebugPoint
	_pos : Vector2 -- position of DebugPoint (global_position)
	_color : Color -- color of DebugPoint
	_size : float -- size of DebugPoint
	"""
	if not debug_point_dict.has(_id):
		return

	(debug_point_dict[_id] as DebugPoint).pos = _pos
	(debug_point_dict[_id] as DebugPoint).color = _color
	(debug_point_dict[_id] as DebugPoint).label.add_theme_color_override("font_color", _color)
	(debug_point_dict[_id] as DebugPoint).size = _size

func update_debug_point_pos(_id : String, _pos : Vector2):
	"""
	Updates the position of a DebugPoint already drawn
	
	_id : String -- name of DebugPoint
	_pos : Vector2 -- position of DebugPoint (global_position)
	"""
	(debug_point_dict[_id] as DebugPoint).pos = _pos
	
func add_debug_line(_id : String, _pos_from : Vector2, _pos_to : Vector2, _color : Color, _width : float) -> void:
	"""
	Adds a DebugLine to draw every frame

	_id : String -- name of DebugLine
	_pos_from : Vector2 -- start position of DebugLine (global_position)
	_pos_to : Vector2 -- end position of DebugLine (global_position)
	_color : Color -- color of DebugLine
	_width : float -- width of DebugLine
	
	DebugDraw.add_debug_line("example_line", start.global_position, end.global_position, Color.RED, 1)
	"""
	if debug_line_dict.has(_id):
		update_debug_line(_id, _pos_from, _pos_to, _color, _width)
	else:
		var dl : DebugLine = DebugLine.new(self, _id, _pos_from, _pos_to, _color, _width)
		debug_line_arr.append(dl)
		debug_line_dict[dl.id] = dl

func update_debug_line(_id : String, _pos_from : Vector2, _pos_to : Vector2, _color : Color, _width : float) -> void:
	"""
	Adds a DebugLine to draw every frame

	_id : String -- name of DebugLine
	_pos_from : Vector2 -- start position of DebugLine (global_position)
	_pos_to : Vector2 -- end position of DebugLine (global_position)
	_color : Color -- color of DebugLine
	_width : float -- width of DebugLine
	"""
	if not debug_line_dict.has(_id):
		return

	(debug_line_dict[_id] as DebugLine).pos_from = _pos_from
	(debug_line_dict[_id] as DebugLine).pos_to = _pos_to
	(debug_line_dict[_id] as DebugLine).color = _color
	(debug_line_dict[_id] as DebugLine).label.add_theme_color_override("font_color", _color)
	(debug_line_dict[_id] as DebugLine).width = _width

func add_debug_arc(
					_id : String, _pos : Vector2, _radius : float,
					_angle_from : float, _angle_to : float, _num_points : int,
					_color : Color, _width : float, _use_aa : bool
				) -> void:
	"""
	Adds a DebugArc to draw every frame

	_id : String -- name of DebugArc
	_pos : Vector2 -- position of DebugArc (global_position)
	_radius : float -- radius of DebugArc's circle
	_angle_from : float -- angle to start drawing arc (radians)
	_angle_to : float -- angle to end drawing arc (radians)
	_num_points : int -- how many points to draw arc with (higher is less jagged arc)
	_color : Color -- color of DebugArc
	_width : float -- width of DebugArc
	_use_aa : bool -- whether arc should be drawn with antialiasing
	
	DebugDraw.add_debug_arc("example_circle", global_position, radius, 0, 2*PI, 100, Color.RED, 1.0, false)
	"""
	if debug_arc_dict.has(_id):
		update_debug_arc(_id, _pos, _radius, _angle_from, _angle_to, _num_points, _color, _width, _use_aa)
	else:
		var da : DebugArc = DebugArc.new(self, _id, _pos, _radius, _angle_from, _angle_to, _num_points, _color, _width, _use_aa)
		debug_arc_arr.append(da)
		debug_arc_dict[da.id] = da

func update_debug_arc(
						_id : String, _pos : Vector2, _radius : float,
						_angle_from : float, _angle_to : float, _num_points : int,
						_color : Color, _width : float, _use_aa : bool
					) -> void:
	"""
	Adds a DebugLine to draw every frame

	_id : String -- name of DebugArc
	_pos : Vector2 -- position of DebugArc (global_position)
	_radius : float -- radius of DebugArc's circle
	_angle_from : float -- angle to start drawing arc (radians)
	_angle_to : float -- angle to end drawing arc (radians)
	_num_points : int -- how many points to draw arc with (higher is less jagged arc)
	_color : Color -- color of DebugArc
	_width : float -- width of DebugArc
	_use_aa : bool -- whether arc should be drawn with antialiasing
	"""
	if not debug_arc_dict.has(_id):
		return

	(debug_arc_dict[_id] as DebugArc).pos = _pos
	(debug_arc_dict[_id] as DebugArc).radius = _radius
	(debug_arc_dict[_id] as DebugArc).angle_from = _angle_from
	(debug_arc_dict[_id] as DebugArc).angle_to = _angle_to
	(debug_arc_dict[_id] as DebugArc).num_points = _num_points
	(debug_arc_dict[_id] as DebugArc).color = _color
	(debug_arc_dict[_id] as DebugArc).label.add_theme_color_override("font_color", _color)
	(debug_arc_dict[_id] as DebugArc).width = _width
	(debug_arc_dict[_id] as DebugArc).use_aa = _use_aa

##################
## Received Signals
##################
func _on_received_player_readied() -> void:
	# Make sure Debug stuff draws above the Player sprite
	z_index = Globals.player_z_index + 1
