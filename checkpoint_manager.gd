extends Node
class_name CheckpointManager

"""
CheckpointManager is a folder, where the "furthest" checkpoint is on the bottom
"""

var array_checkpoints : Array
var furthest_index : int = 0

func _ready() -> void:
	### Subscribe to signals
	for checkpoint : Checkpoint in get_children():
		checkpoint.sig_checkpointMgr_checkpoint_reached.connect(_on_received_checkpoint_reached)
	
	# Set up first Checkpoint spawn position
	if get_child_count() > 0:
		Globals.CheckpointM_curr_checkpoint_pos = get_child(0).global_position

##################
## Received Signals
##################
func _on_received_checkpoint_reached(order_num : int) -> void:
	"""
	Once Player reaches a Checkpoint, save its global_position if it is the furthest Checkpoint reached
	"""
	if order_num >= furthest_index:
		furthest_index = order_num
		Globals.CheckpointM_curr_checkpoint_pos = get_child(furthest_index).global_position
	
