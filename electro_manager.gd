extends Node
class_name ElectroManager

### Signals
signal sig_electroMgr_electro_percent(new_electro : float)

#region Electro variables
var min_electro : float = 0.0
var max_electro : float = 99.0
var curr_electro : float = 0.0:
	set(new_CyP):
		curr_electro = clampf(new_CyP, min_electro, max_electro)
		update_globals() # Sends a signal to HUD
var electro_cost_ratio : float = (1.0 / 3.0) # How much (of a full electro bar) does an electro-relevant skill cost
var electro_gain_idle : float = 0.1 # How much electro to gain by doing nothing
var electro_gain_hit : float = (max_electro * electro_cost_ratio) / 1 # How much electro to gain when Player hits something
var electro_gain_shield_guard : float = electro_gain_hit # How much electro to gain when Player shield guards something
var electro_loss_swordboard_slash_dash : float = (max_electro * electro_cost_ratio) # How much electro to lose when Player dashes during swordboard
var electro_loss_swordboarding : float = electro_loss_swordboard_slash_dash # How much electro to lose on Player initial swordboard slide
var electro_loss_spearbrooming : float = 2.1 # How much electro to lose while Player is spearbrooming
var electro_loss_speartethering_nudge : float = 0.3 # How much electro to lose while Player is speartethering (in a direction)
var electro_loss_spear_dash : float = electro_loss_swordboard_slash_dash # How much electro to lose when Player dashes towards Spear
var electro_loss_shield_pulse : float = electro_loss_swordboard_slash_dash # How much electro to lose when Player uses Shield pulse
#endregion

func _ready() -> void:
	# Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_electroMgr_electro_swordboard_slide", _on_received_electro_swordboard_slide)
	_Player.connect("sig_electroMgr_electro_swordboard_slash", _on_received_electro_swordboard_slash)
	_Player.connect("sig_electroMgr_electro_spearbrooming", _on_received_electro_spearbrooming)
	_Player.connect("sig_electroMgr_electro_speartethering_nudge", _on_received_electro_speartethering_nudge)
	_Player.connect("sig_electroMgr_electro_shield_guard_success", _on_received_electro_shield_guard_success)
	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_electroMgr_electro_hit", _on_received_electro_hit)
		cyarm.connect("sig_electroMgr_electro_spear_dash", _on_received_electro_spear_dash)
		cyarm.connect("sig_electroMgr_electro_shield_pulse", _on_received_electro_shield_pulse)
	var _HUD : Node = get_tree().get_first_node_in_group("HUD")
	_HUD.connect("sig_HUD_readied", _on_received_HUD_readied)

	# Set defaults and update HUD
	curr_electro = (max_electro * electro_cost_ratio)
	update_globals()

func _process(_delta: float) -> void:
	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		#print(self, "Globals.EM_f_can_electro_cast:", Globals.EM_f_can_electro_cast,
		#" ", "Globals.EM_curr_electro:", Globals.EM_curr_electro,
		#" ", "curr_electro:", curr_electro,
		#" ", "max_electro:", max_electro,
		#" ", "electro_cost_ratio:", electro_cost_ratio,)
		pass

func _physics_process(delta: float) -> void:
	# Over time, allow Player to gain some electro
	curr_electro += electro_gain_idle

func update_globals() -> void:
	# Update Globals
	Globals.EM_f_can_electro_cast = (curr_electro / max_electro) >= electro_cost_ratio
	Globals.EM_curr_electro = curr_electro - electro_gain_idle
	Globals.EM_curr_electro_ratio = (curr_electro / max_electro)
	
	# Update HUD
	var _percent : float = curr_electro / max_electro
	sig_electroMgr_electro_percent.emit(_percent)

##################
## Received Signals
##################
func _on_received_HUD_readied() -> void:
	"""
	Once HUD is ready, update HUD with current electro
	"""
	update_globals()

func _on_received_electro_hit() -> void:
	"""
	If Cyarm hits something, GAIN electro
	"""
	curr_electro += electro_gain_hit

func _on_received_electro_swordboard_slide() -> void:
	"""
	On Player swordboard initial slide speed, DECREASE electro
	"""
	curr_electro -= electro_loss_swordboarding

func _on_received_electro_swordboard_slash() -> void:
	"""
	If Player dashes during swordboard slash, DECREASE electro
	"""
	curr_electro -= electro_loss_swordboard_slash_dash

func _on_received_electro_spearbrooming() -> void:
	"""
	If Player is spearbrooming, DECREASE electro
	"""
	curr_electro -= (electro_loss_spearbrooming * Globals.time_scale)

func _on_received_electro_speartethering_nudge() -> void:
	"""
	If Player is spearbrooming, DECREASE electro
	"""
	curr_electro -= (electro_loss_speartethering_nudge * Globals.time_scale)

func _on_received_electro_spear_dash() -> void:
	"""
	If Player dashes to Spear, DECREASE electro
	"""
	curr_electro -= electro_loss_spear_dash

func _on_received_electro_shield_guard_success() -> void:
	"""
	If Player uses Shield guard and SUUCCESSFULLY guards against something, INCREASE electro
	"""
	curr_electro += electro_gain_shield_guard

func _on_received_electro_shield_pulse() -> void:
	"""
	If Player uses Shield pulse, DECREASE electro
	"""
	curr_electro -= electro_loss_shield_pulse
