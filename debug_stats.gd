extends CanvasLayer

var debug_stats : Array[DebugStat] = []
@onready var container = $MarginContainer/VBoxContainer

class DebugStat:
	var object : Object # The object being tracked
	var stat_name # The name of the attribute to display
	var stat_label : Label # A reference to the Label that displays the attribute

	func _init(_object, _stat_name, _stat_label):
		object = _object
		stat_name = _stat_name
		stat_label = _stat_label

	func update_label() -> bool:
		"""
		Updates DebugStat's label

		Returns : bool -- whether label was successfully updated
		"""
		if not object:
			# Object was probably freed
			return false

		# Sets the label's text.
		var str_to_display : String = object.name + "|" + stat_name + " : "
		var str_value : String

		var value = object.get(stat_name)
		if typeof(value) == TYPE_VECTOR2:
			value.x = snapped(value.x, 0.1)
			value.y = snapped(value.y, 0.1)
		
		str_value = str(value)
		if str_value == "false":
			stat_label.add_theme_color_override("font_color", Color(1,0,0))
		elif str_value == "true":
			stat_label.add_theme_color_override("font_color", Color(0,1,0))

		stat_label.text = str_to_display + str_value
		return true

func _process(_delta) -> void:
	if not Globals.DEBUG_MODE:
		# If debug mode is set to false, don't draw
		hide() # Hide label
		return
	
	var _destroy_arr : Array = []

	for stat in debug_stats:
		if not stat.update_label():
			_destroy_arr.append(stat)
	
	for stat in _destroy_arr:
		# For every object that failed to be updated, remove from debug stat list,
		# since the object being tracked is destroyed
		debug_stats.erase(stat)
		stat.stat_label.call_deferred("queue_free")

func add_stat(object, stat_to_display) -> void:
	var label : Label = Label.new()
	label.add_theme_font_size_override("font_size", 8)
	container.add_child(label)
	debug_stats.append(DebugStat.new(object, stat_to_display, label))

func remove_stat(object, stat_to_remove) -> void:
	for stat in debug_stats:
		if stat.object == object and stat.stat == stat_to_remove:
			debug_stats.erase(stat)
