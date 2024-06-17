extends Control

#region Signals
signal sig_HUD_readied
#endregion

### Components
@onready var c_label_cyarm_state : Label = $HBoxContainer/VBoxContainer/CyarmState
@onready var c_toggle_cyarm_follow_player : CheckButton = $HBoxContainer/VBoxContainer/CyarmFollowingPlayerToggle
@onready var c_progress_HP1 : TextureProgressBar = $HBoxContainer/VBoxContainerHP/HP1
@onready var c_progress_HP2 : TextureProgressBar = $HBoxContainer/VBoxContainerHP/HP2
@onready var c_progress_HP3 : TextureProgressBar = $HBoxContainer/VBoxContainerHP/HP3
@onready var c_progress_CyP1 : TextureProgressBar = $HBoxContainer/VBoxContainerCyP/CyP1
@onready var c_progress_CyP2 : TextureProgressBar = $HBoxContainer/VBoxContainerCyP/CyP2
@onready var c_progress_CyP3 : TextureProgressBar = $HBoxContainer/VBoxContainerCyP/CyP3
@onready var c_progress_electro : TextureProgressBar = $UI_electro_bar
@onready var c_progress_primaryaction_cooldown : TextureProgressBar = $UI_action_primary/PrimaryActionCooldown
@onready var c_progress_secondaryaction_cooldown : TextureProgressBar = $UI_action_secondary/SecondaryActionCooldown
@onready var c_textbutt_primaryaction : TextureButton = $UI_action_primary
@onready var c_textbutt_secondaryaction : TextureButton = $UI_action_secondary
@onready var c_textrect_HP : TextureRect = $UI_HP

var HP_segments : Array
var CyP_segments : Array
var CyP_color_not_full : Color = Globals.CY_GREEN

# Electro bar
var electro_can_cast_color : Color = Globals.CY_GREEN
var electro_CANNOT_cast_color : Color = Color("93baa0")
var electro_can_cast_under_text : Texture2D = preload("res://sprites/UI/electro_under_can_electro_cast.png")
var electro_CANNOT_cast_under_text : Texture2D = preload("res://sprites/UI/electro_under_CANNOT_electro_cast.png")

func _ready() -> void:
	## Subscribe to signals
	var _Player : Node = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_player_HP_changed", Callable(_on_received_change_segments).bind(true)) # .bind() parameters are added AFTER signal parameters
	_Player.connect("sig_HUD_display_HP", _on_received_display_HP)
	var _ElectroManager : Node = get_tree().get_first_node_in_group("ElectroManager")
	_ElectroManager.connect("sig_electroMgr_electro_percent", _on_received_electro_percent)
	var _CyarmManager : Node = get_tree().get_first_node_in_group("CyarmManager")
	_CyarmManager.connect("sig_HUD_update_primary_action", _on_received_update_primary_action)
	_CyarmManager.connect("sig_HUD_update_secondary_action", _on_received_update_secondary_action)

	## Set Segments Arrays
	HP_segments.append(c_progress_HP1)
	HP_segments.append(c_progress_HP2)
	HP_segments.append(c_progress_HP3)
	for HP_progress in HP_segments:
		HP_progress.max_value = 1 # As segments, each progress bar's maximum value is 1
	CyP_segments.append(c_progress_CyP1)
	CyP_segments.append(c_progress_CyP2)
	CyP_segments.append(c_progress_CyP3)
	for CyP_progress in CyP_segments:
		CyP_progress.max_value = 1 # As segments, each progress bar's maximum value is 1

	## Default "faded" color for Cy-Point segment when not yet full
	CyP_color_not_full.a = 0.2

	## Set default HUD values
	_on_received_change_segments(_Player.curr_HP, true)
	
	## Send signal that HUD is ready
	sig_HUD_readied.emit()

func _process(_delta: float) -> void:
	# Update HUD
	update_HUD()
	
func update_HUD() -> void:
	"""
	Update HUD (Player HP, Cyarm state, etc.)
	"""
	# Display Cyarm State
	c_label_cyarm_state.text = Globals.cyarm_state
	
	# Display if Cyarm is following Player
	if Globals.cyarm_f_follow and Globals.cyarm_f_follow_player:
		c_toggle_cyarm_follow_player.button_pressed = true
	else:
		c_toggle_cyarm_follow_player.button_pressed = false
		
	# Display Player HP

##################
## Received Signals
##################
func _on_received_electro_percent(new_electro_percent : float) -> void:
	"""
	Displays new electro
	
	new_electro_percent : float -- percentage of electro to display
	"""
	var _display_color : Color
	if Globals.EM_f_can_electro_cast:
		_display_color = electro_can_cast_color
		c_progress_electro.texture_under = electro_can_cast_under_text
	else:
		_display_color = electro_CANNOT_cast_color
		c_progress_electro.texture_under = electro_CANNOT_cast_under_text
	
	c_progress_electro.tint_progress = _display_color
	c_progress_electro.value = new_electro_percent * (c_progress_electro.max_value - c_progress_electro.min_value)
	
func _on_received_change_segments(new_progress_val : float, is_hp : bool) -> void:
	"""
	Displays new Cyarm CyP
	"""
	var segment_arr : Array = CyP_segments
	if is_hp:
		segment_arr = HP_segments

	var num_segments : int = len(segment_arr) # Number of progress bars
	var segment_max : float = segment_arr[0].max_value # Max value for each individual progress bar
	var progress_left : float = clampf(new_progress_val, 0, num_segments) # Clamp to [0, number of segment components]

	for c_progress_bar in segment_arr:
		if progress_left <= 0: # All progress has been rendered in the bars so far, so clear subsequent bars
			c_progress_bar.value = 0
		else:
			if segment_arr == CyP_segments:
				# Specific actions for CyP HUD elements
				update_CyP_progress_bar(c_progress_bar, clampf(progress_left, 0, segment_max))
			
			# Set current progress bar to progress left, then clear the excess
			c_progress_bar.value = progress_left
			progress_left -= segment_max

func update_CyP_progress_bar(c_progress_bar : TextureProgressBar, progress_left : float):
	"""
	Updates Cy-Point progress bars. (Dull color when not full, some juice once filled)
	
	c_progress_bar : TextureProgressBar -- Progress bar to render
	progress_left : float -- how much progress to render
	"""
	var max_val = c_progress_bar.max_value

	# If current progress bar value ISN'T max and 
	# the progress to be rendered IS max
	# then this progress bar was JUST filled
	if (
			c_progress_bar.value != max_val and
			is_equal_approx(clampf(progress_left, 0, max_val), max_val) # Use is_equal_approx() for floats
		):
		c_progress_bar.tint_progress = Globals.CY_GREEN
		var embiggen_tween : Tween = create_tween()
		embiggen_tween.tween_property(c_progress_bar, "scale", Vector2(1.1, 1.1), 0.1)
		embiggen_tween.tween_property(c_progress_bar, "scale", Vector2(1, 1), 0.1)
	else:
		if c_progress_bar.value != max_val:
			# Dull progress bar while recovering CyP but not yet full
			c_progress_bar.tint_progress = CyP_color_not_full

func _on_received_display_HP(new_text : Texture2D):
	"""
	Updates HUD to display Cyarm's current primary action
	
	new_text : Texture2D -- texture of HP to display
	"""
	c_textrect_HP.texture = new_text

func _on_received_update_primary_action(cyactiontext : CyarmBase.CyarmActionTexture) -> void:
	"""
	Updates HUD to display Cyarm's current primary action
	
	cyactiontext : CyarmBase.CyarmActionTexture -- class that contains action texture to display, and how "ready" it is
	"""
	c_textbutt_primaryaction.texture_normal = cyactiontext.texture
	c_progress_primaryaction_cooldown.texture_progress = cyactiontext.texture
	c_progress_primaryaction_cooldown.value = c_progress_primaryaction_cooldown.max_value * (1 - cyactiontext.availability)

func _on_received_update_secondary_action(cyactiontext : CyarmBase.CyarmActionTexture) -> void:
	"""
	Updates HUD to display Cyarm's current secondary action
	
	cyactiontext : CyarmBase.CyarmActionTexture -- class that contains action texture to display, and how "ready" it is
	"""
	c_textbutt_secondaryaction.texture_normal = cyactiontext.texture
	c_progress_secondaryaction_cooldown.texture_progress = cyactiontext.texture
	c_progress_secondaryaction_cooldown.value = c_progress_secondaryaction_cooldown.max_value * (1 - cyactiontext.availability)
