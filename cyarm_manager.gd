extends Node
class_name CyarmManager

### Signals
signal sig_cyMgr_cyarm_enabled
signal sig_cyPop_spawn_offscreen_popup(do_spawn : bool, wait_timer : float)
signal sig_HUD_update_primary_action(cyactiontext : CyarmBase.CyarmActionTexture)
signal sig_HUD_update_secondary_action(cyactiontext : CyarmBase.CyarmActionTexture)
signal sig_cameraMgr_follow_node(new_node : Node2D)

### Components

### Cyarm distance to Player Variables
var f_onscreen : bool = true:
	set(flag):
		if f_onscreen != flag: # Only send signal when flag is flipped
			if not f_onscreen:
				sig_cyPop_spawn_offscreen_popup.emit(false) # Hide popup immediately
			else:
				sig_cyPop_spawn_offscreen_popup.emit(true, cyarm_popup_delay) # Have a little delay after leaving screen to show popup

		f_onscreen = flag # Set flag after sending signal

var distance_to_player : float # Distance to Player
var max_distance_to_player : float = 600.0 # Maximum distance to the Player
var cyarm_popup_delay : float = 0.1

### Cyarm Mode variables
enum CyMode {NONE, SWORD, SPEAR, SICKLE, SHIELD}
var cyarm_sword_ref : CyarmSword # Reference to Cyarm-Sword
var cyarm_spear_ref : CyarmSpear # Reference to Cyarm-Spear
var cyarm_sickle_ref : CyarmSickle # Reference to Cyarm-Sickle
var cyarm_shield_ref : CyarmShield # Reference to Cyarm-Shield
var curr_cyarm : CyarmBase # Reference to current active Cyarm
var curr_cyarm_cymode : CyMode
var queued_unlock_cymode : CyMode # Cymode representation of Cyarm to change to, the moment current Cyarm is unlocked
var curr_cyarm_state_as_str : String:
	get:
		return get_curr_cyarm_state()
var curr_cyarm_locked : bool:
	get:
		return false if not curr_cyarm else curr_cyarm.is_locked()
var curr_cyarm_follow_player : bool:
	get:
		return false if not curr_cyarm else curr_cyarm.f_follow_player

### Cyarm action variables
var action_texture_primary : Texture2D
var action_texture_secondary : Texture2D
var curr_cyarm_primary_action_as_str : String:
	get:
		if curr_cyarm.o_curr_primary_action:
			return curr_cyarm.o_curr_primary_action.action_name
		else:
			return ""
var curr_cyarm_secondary_action_as_str : String:
	get:
		if curr_cyarm.o_curr_secondary_action:
			return curr_cyarm.o_curr_secondary_action.action_name
		else:
			return ""

#################
## Main functions
#################
func _ready() -> void:
	## Set Global variables
	Globals.CM_cyarm_to_player_maxdist = max_distance_to_player
	
	## Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_player_readied", _on_received_player_readied)
	_Player.connect("sig_player_respawned", _on_received_player_respawned)
	var _CyarmMenu : Control = get_tree().get_first_node_in_group("CyarmMenu")
	_CyarmMenu.connect("sig_cyMgr_change_mode", _on_received_change_mode)
	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_cyarm_unlocked", _on_received_cyarm_unlocked)
		cyarm.connect("sig_cyMgr_request_camera_focus", _on_received_request_camera_focus)

	## Set timers


	## Store Cyarm node references
	cyarm_sword_ref = get_tree().get_first_node_in_group("CyarmSword")
	cyarm_spear_ref = get_tree().get_first_node_in_group("CyarmSpear")
	cyarm_sickle_ref = get_tree().get_first_node_in_group("CyarmSickle")
	cyarm_shield_ref = get_tree().get_first_node_in_group("CyarmShield")

	## Add to DebugStats
	DebugStats.add_stat(self, "curr_cyarm_state_as_str")
	DebugStats.add_stat(self, "curr_cyarm_locked")
	DebugStats.add_stat(self, "curr_cyarm_follow_player")
	DebugStats.add_stat(self, "curr_cyarm_primary_action_as_str")
	DebugStats.add_stat(self, "curr_cyarm_secondary_action_as_str")

func _process(_delta) -> void:
	# Update Globals script
	update_globals()
	
	# Button presses
	update_inputs()

func _physics_process(_delta : float) -> void:
	# Update Cyarm flags for this frame
	f_onscreen = is_on_screen()
	distance_to_player = curr_cyarm.global_position.distance_to(Globals.player_center_pos)
	if distance_to_player > max_distance_to_player:
		# Once Cyarm gets too far from Player, automatically recall it
		change_mode(CyMode.SWORD)
		curr_cyarm.sword_spin()
		sig_cyPop_spawn_offscreen_popup.emit(false) # Hide popup immediately when returning to Player

	# Notify HUD to update Cyarm actions
	sig_HUD_update_primary_action.emit(curr_cyarm.get_action_texture(true)) # Update HUD with current primary action
	sig_HUD_update_secondary_action.emit(curr_cyarm.get_action_texture(false)) # Update HUD with current secondary action
	
	#DebugDraw.add_debug_point("cyarm_sword", cyarm_sword_ref.global_position, Color.ANTIQUE_WHITE, 3)
	#DebugDraw.add_debug_point("cyarm_spear", cyarm_spear_ref.global_position, Color.AQUA, 3)
	#DebugDraw.add_debug_point("cyarm_sickle", cyarm_sickle_ref.global_position, Color.DARK_KHAKI, 3)
	#DebugDraw.add_debug_point("cyarm_shield", cyarm_shield_ref.global_position, Color.AQUAMARINE, 3)

func update_inputs() -> void:
	"""
	Updates Cyarm flags corresponding to button presses
	"""
	# Switching Cyarm Mode
	if Input.is_action_just_pressed("sword"):
		change_mode(CyMode.SWORD)
	if Input.is_action_just_pressed("spear"):
		change_mode(CyMode.SPEAR)
	if Input.is_action_just_pressed("sickle"):
		change_mode(CyMode.SICKLE)
	if Input.is_action_just_pressed("shield"):
		change_mode(CyMode.SHIELD)

	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		#print(self, "curr cyarm:", curr_cyarm,
		#"\ncurr vel:", curr_cyarm.velocity,
		#"\ncurr accel:", curr_cyarm.follow_acceleration,
		#"\ncurr max speed:", curr_cyarm.follow_max_speed)
		pass

func update_globals() -> void:
	"""
	Updates Cyarm variables shared to Global script
	"""
	Globals.CM_cyarm_to_player_dist = distance_to_player

func change_mode(requested_mode : CyMode, action_context : CyarmActionContext = null) -> void:
	"""
	Changes current active Cyarm
	
	requested_mode : CyMode -- new mode to change current Cyarm to
	action_context : CyarmActionContext = null -- the state of pressed action buttons + mouse global_position
	"""
	# Return if attempting to change into already active mode
	#if curr_cyarm_cymode == requested_mode:
	#	return
	
	# If current Cyarm is locked from changing mode, save requested mode, to be changed to once Cyarm unlocks
	if curr_cyarm.is_locked():
		queued_unlock_cymode = requested_mode
		return
	
	var old_cyarm : CyarmBase = curr_cyarm # Ref to old Cyarm
	curr_cyarm = mode_to_ref(requested_mode) # Ref to new Cyarm
	
	# Disable old cyarm
	old_cyarm.disable()
	
	# Enable new Cyarm
	curr_cyarm.enable(old_cyarm.get_follow_pos(), action_context)
	sig_cyMgr_cyarm_enabled.emit()
	
	curr_cyarm_cymode = requested_mode

func mode_to_ref(mode : CyMode) -> CyarmBase:
	"""
	Translates CyMode representation to CyarmBase Reference
	
	mode : CyMode -- mode to get reference of
	
	Returns : CyarmMode -- reference of given CyMode
	"""
	match mode:
		CyMode.SWORD:
			return cyarm_sword_ref
		CyMode.SPEAR:
			return cyarm_spear_ref
		CyMode.SICKLE:
			return cyarm_sickle_ref
		CyMode.SHIELD:
			return cyarm_shield_ref

	return cyarm_sword_ref

func is_on_screen() -> bool:
	"""
	Returns : bool -- whether Cyarm is currently visible on screen
	"""
	return Globals.viewport_rect.has_point(Globals.cyarm_canvas_pos)

func cyarm_can_hit() -> bool:
	"""
	Returns : bool -- whether Cyarm can hit Enemy based on current mouse position
	"""
	return curr_cyarm.f_about_to_hit

func get_curr_cyarm_state() -> String:
	"""
	Returns : String -- the state of the current Cyarm
	"""
	match curr_cyarm_cymode:
		CyMode.SWORD:
			return cyarm_sword_ref.sword_state_as_str
		CyMode.SPEAR:
			return cyarm_spear_ref.spear_state_as_str
		CyMode.SICKLE:
			return cyarm_sickle_ref.sickle_state_as_str
		CyMode.SHIELD:
			return cyarm_shield_ref.shield_state_as_str
		_:
			return cyarm_sword_ref.sword_state_as_str

func get_curr_cyarm_action_texture(get_primary : bool) -> CyarmBase.CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	return curr_cyarm.get_action_texture(get_primary)

func get_radial_icon_action_texture(mode : CyMode, action_context : CyarmActionContext) -> CyarmBase.CyarmActionTexture:
	"""
	Returns : CyarmActionTexture -- object containing UI texture of the requested currently possible Cyarm action
	
	get_primary : bool -- whether to return texture of primary action or secondary action
	"""
	return mode_to_ref(mode).get_radial_icon_action_texture(action_context)

func get_crosshair_proposed_pos() -> Vector2:
	"""
	Returns : Vector2 -- the position of the crosshair to best represent the current Cyarm mode
	"""
	return curr_cyarm.get_crosshair_proposed_pos()

##################
## Received Signals
##################
func _on_received_player_readied() -> void:
	"""
	Once Player is ready, then ready each Cyarm
	Because default follow position depends on Player
	"""
	# First cycle through every mode to make sure each Cyarm mode runs their setup
	curr_cyarm = cyarm_sword_ref
	change_mode(CyMode.SWORD)
	change_mode(CyMode.SPEAR)
	change_mode(CyMode.SICKLE)
	change_mode(CyMode.SHIELD)

	# Default mode is Cyarm-Sword
	change_mode(CyMode.SWORD)
	(curr_cyarm as CyarmBase).set_follow_pos(Globals.player_cyarm_follow_pos, true) # At default, follow Player

func _on_received_player_respawned() -> void:
	"""
	When Player respawns, reenable default Cyarm
	"""
	# Default mode is Cyarm-Sword
	change_mode(CyMode.SWORD)
	(curr_cyarm as CyarmBase).set_follow_pos(Globals.player_cyarm_follow_pos, true) # At default, follow Player
	
func _on_received_change_mode(cyarm : CyarmManager.CyMode, action_context : CyarmActionContext) -> void:
	"""
	Change Cyarm mode depending on what was selected in the radial menu
	
	cyarm : CyMode -- new mode to change current Cyarm to
	action_context : CyarmActionContext -- how actions buttons are currently pressed + mouse position
	"""
	match cyarm:
		CyMode.SWORD:
			change_mode(CyMode.SWORD, action_context)
		CyMode.SPEAR:
			change_mode(CyMode.SPEAR, action_context)
		CyMode.SICKLE:
			change_mode(CyMode.SICKLE, action_context)
		CyMode.SHIELD:
			change_mode(CyMode.SHIELD, action_context)

func _on_received_cyarm_unlocked() -> void:
	"""
	After Cyarm unlocks, immediately change Cyarm mode into queued mode
	"""
	if not queued_unlock_cymode == CyMode.NONE:
		change_mode(queued_unlock_cymode)
		queued_unlock_cymode = CyMode.NONE # Clear queue once mode was changed

func _on_received_request_camera_focus(new_node : Node2D) -> void:
	"""
	A Cyarm requests camera focus
	"""
	if curr_cyarm == new_node:
		sig_cameraMgr_follow_node.emit(new_node)
