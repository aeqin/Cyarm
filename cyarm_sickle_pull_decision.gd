extends Control

#region Signals
signal sig_player_sicklepull_player_to_target
signal sig_player_sicklepull_target_to_player
signal sig_player_sicklepull_release

### Components
@onready var c_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var c_progress_time_left : TextureProgressBar = $TimeLeftDisplay
@onready var c_timer_timeleft : Timer = $TimeLeftTimer

var f_spawned : bool = false
var sickle_stuck_target : Node # What Node is the Sickle stuck in? 
var dir_player_to_sickle : Vector2
var sickle_pos : Vector2
var pull_past_dist : float = 80 # Extra distance to pull target past Player
var pull_initial_speed : float = 700
var pull_max_speed : float = 1000
var pull_midpoint_progress : float = 0.7 # Between 0 and 1, how much progress must be made to consider pull past "midpoint"

enum SicklePull {
	RELEASE,        # Pull out Sickle, for damage
	TO_TARGET,  # Pull Player towards target
	TO_PLAYER,  # Pull target towards Player
	}
var curr_sickle_pull_decision : SicklePull = SicklePull.RELEASE
var sickle_cancel_radius : float = 30
var anim_neutral : String = "release"
var anim_to_player : String = "to_player"
var anim_to_target : String = "to_target"

func _ready() -> void:
	## Force node to subscribe to signals
	var _Player : Node = get_tree().get_first_node_in_group("Player")
	self.sig_player_sicklepull_player_to_target.connect(_Player._on_received_sicklepull_player_to_target)
	self.sig_player_sicklepull_target_to_player.connect(_Player._on_received_sicklepull_target_to_player)
	self.sig_player_sicklepull_release.connect(_Player._on_received_sicklepull_release)
	
	## Subscribe to signals
	var _cyarm_sickle : Node = get_tree().get_first_node_in_group("CyarmSickle")
	_cyarm_sickle.sig_cyarm_sickle_disabled.connect(self.die)

func _process(delta: float) -> void:
	update_inputs()
	update_sickle_pull_decision()
	
	if not c_timer_timeleft.is_stopped():
		update_timer_progress()
		
	update_animations()

func update_inputs() -> void:
	"""
	Updates SicklePullDecision depending to button presses
	"""
	## Jumping
	if Input.is_action_just_pressed("up"):
		sig_player_sicklepull_player_to_target.emit()
		die()

	## Crouching
	if Input.is_action_just_pressed("down"):
		# Pull target towards Player, and a bit past
		if Utilities.is_pullable(sickle_stuck_target):
			var _sickle_to_player_dir : Vector2 = (Globals.player_center_pos - Globals.cyarm_pos).normalized()
			var _sickle_to_player_dist : float = Globals.player_center_pos.distance_to(Globals.cyarm_pos)
			sickle_stuck_target.pull_me(_sickle_to_player_dir,
										_sickle_to_player_dist + pull_past_dist,
										pull_initial_speed, pull_max_speed,
										pull_midpoint_progress)
			
			# Notify Player
			sig_player_sicklepull_target_to_player.emit()
		die()
	
	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("testkey"):
		pass
	if Input.is_action_just_pressed("testkey2"):
		pass

func update_sickle_pull_decision() -> void:
	"""
	Updates what "decision" will be made regarding Sickle pull depending on mouse position:
		Mouse within cancel range -> SicklePull.RELEASE
		Sickle to mouse pointing towards Player -> SicklePull.TO_PLAYER
		Sickle to mouse pointing away from Player -> SicklePull.TO_TARGET
	"""
	# If mouse within time left circle, then cancel sickle pull (pull out for damage, no movement)
	if sickle_pos.distance_to(Globals.mouse_pos) <= sickle_cancel_radius:
		curr_sickle_pull_decision = SicklePull.RELEASE
		return
	
	# If dot product positive, then both unit vectors are facing similar directions, meaning decision
	# is pointing to pull target towards Player
	var _dir_mouse_to_sickle = (sickle_pos - Globals.mouse_pos).normalized()
	if _dir_mouse_to_sickle.dot(dir_player_to_sickle) > 0:
		curr_sickle_pull_decision = SicklePull.TO_PLAYER
	else:
		curr_sickle_pull_decision = SicklePull.TO_TARGET

func update_timer_progress() -> void:
	"""
	Updates the radial progress that displays time left 
	"""
	c_progress_time_left.value = (c_timer_timeleft.time_left / c_timer_timeleft.wait_time) * c_progress_time_left.max_value

func update_animations() -> void:
	match curr_sickle_pull_decision:
		SicklePull.RELEASE:
			c_sprite.play(anim_neutral)
		SicklePull.TO_TARGET:
			c_sprite.play(anim_to_target)
		SicklePull.TO_PLAYER:
			c_sprite.play(anim_to_player)

func spawn(_sickle_pos : Vector2, time_until_death : float, _sickle_stuck_target : Node):
	"""
	Starts the timer that measures time until destruction

	_sickle_pos : Vector2 -- position of the Sickle
	time_until_death : float -- how long SicklePullDecision lasts
	_sickle_stuck_target : Node -- what Node is the Sickle stuck in
	"""
	sickle_stuck_target = _sickle_stuck_target
	dir_player_to_sickle = (_sickle_pos - Globals.player_center_pos).normalized()
	c_sprite.rotation = dir_player_to_sickle.angle() # Rotate sprite
	
	sickle_pos = _sickle_pos
	set_global_position(sickle_pos) # Display the time left around Sickle

	# Stop time, then set timer to reenable normal time
	Globals.set_time_scale_stopped()
	c_timer_timeleft.wait_time = time_until_death
	c_timer_timeleft.start()

func die() -> void:
	"""
	Destroys SicklePullDecision
	"""
	Globals.set_time_scale_normal()
	call_deferred("queue_free") # Destroy SicklePullDecision

##################
## Received Signals
##################
func _on_time_left_timer_timeout() -> void:
	"""
	Set time scale back to normal then destroy SicklePullDecision
	"""
	sig_player_sicklepull_release.emit() # Make sure Player cancels Sickle pull
	die()
	
