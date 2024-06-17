extends Area2D
class_name Checkpoint

### Signals
signal sig_checkpointMgr_checkpoint_reached(order_num : int)

func _on_body_entered(body: Node2D) -> void:
	"""
	Player entered Checkpoint
	"""
	sig_checkpointMgr_checkpoint_reached.emit(get_index())
