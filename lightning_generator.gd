@tool  # Allow script to run in editor, to draw line between generators

extends Node2D
class_name LightningGenerator

### Signals
signal sig_world_spawn_lightning(start_pos : Vector2, end_pos : Vector2)

### Component references
@export var paired_generator : LightningGenerator = null # What other LightningGenerator is this one linked to
@onready var c_marker_lightning : Marker2D = $GeneratorSprite/LightningPos

### Primary (have one generator assiged as "boss", so only one signal is sent / one line is drawn / etc...)
@export var f_is_boss = false
@export var f_is_secondary = false
@export var f_can_clear_indicator = false

func _ready() -> void:
	# ONLY while game is RUNNING
	if not Engine.is_editor_hint():
		# Subscribe to signals
		var _World : Node2D = get_tree().get_first_node_in_group("World")
		_World.connect("sig_world_readied", _on_received_world_readied)

		# Clear screen
		queue_redraw()

func _physics_process(delta: float) -> void:
	# ONLY while in EDITOR mode
	if Engine.is_editor_hint():
		decide_boss()

		# Draw editor indicators
		queue_redraw() 
		
	# ONLY while game is RUNNING
	else:
		pass
	
func _draw() -> void:
	"""
	Draw a line between paired LightningGenerators
	"""
	# ONLY while in EDITOR mode
	if Engine.is_editor_hint():
		
		if paired_generator:
			if f_is_boss and paired_generator.paired_generator == self:
				# Draw a line connecting paired LightningGenerators
				draw_line(to_local(get_lightning_pos()), to_local(paired_generator.get_lightning_pos()), Color.RED, 2)
				f_can_clear_indicator = true
			
			elif paired_generator.paired_generator != self:
				# Draw a circle indicating that only one half of LightningGenerator pair is paired
				draw_circle(to_local(get_lightning_pos()), 5, Color.RED)
				f_can_clear_indicator = true

	# ONLY while game is RUNNING
	else:
		pass # Clear screen

func get_lightning_pos() -> Vector2:
	"""
	Returns the position that Lightning should be generated from
	"""
	return c_marker_lightning.global_position

func decide_boss() -> void:
	"""
	Decide which one of the paired LightningGenerators is the "boss", by being the
	first LightningGenerator to run this code
	"""
	if not paired_generator:
		reset_generator()
		return # Return if not paired
	else:
		if paired_generator.paired_generator == null:
			reset_generator()
			return # Return if secondary has unpaired itself

	if f_is_boss or f_is_secondary:
		return # Stop deciding if already decided
	
	if paired_generator: # Paired
		if paired_generator.paired_generator == self: # Paired with self
			if paired_generator.f_is_boss: # Paired with already decided "boss"
				f_is_secondary = true # So become secondary
			else:
				f_is_boss = true # First LightningGenerator to reach this, become "boss"

func reset_generator() -> void:
	"""
	Reset attributes and clear screen
	"""
	f_is_boss = false 
	f_is_secondary = false
	
	if f_can_clear_indicator: # Clear once
		queue_redraw()
		f_can_clear_indicator = false

##################
## Received Signals
##################
func _on_received_world_readied() -> void:
	"""
	Once the World is ready (subscribed to all signals), then signal World to generate Lightning
	"""
	if f_is_boss and paired_generator:
		sig_world_spawn_lightning.emit(get_lightning_pos(), paired_generator.get_lightning_pos())
