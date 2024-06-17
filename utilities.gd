extends Node

var layer_bit_dict : Dictionary = {} # Dictionary of {String, int} (Maps collision layer name to its bit)
func _ready() -> void:
	## Store the collision layers for easy access
	# For each collision layer
	for layer_num in range(1, 32):
		var _layer_name = ProjectSettings.get_setting("layer_names/2d_physics/layer_" + str(layer_num))
		layer_bit_dict[_layer_name] = layer_num - 1 # Bit starts from 0 instead of 1

#############################
## Math-ish Functions
#############################
func opposite_sign(num1, num2) -> bool:
	"""
	Calculates whether two numbers have opposite signs
	If one number is 0, return false

	num1 -- signed number
	num2 -- signed number
	
	Returns : bool -> whether the two given numbers have opposite signs
	"""
	var _sign1 = sign(int(num1))
	var _sign2 = sign(int(num2))
	if _sign1 == 0 or _sign2 == 0:
		return false
	else:
		return _sign1 != _sign2

func bound_rot(rotation : float) -> float:
	"""
	Given a rotation in radians, returns an equal (but positive) rotation between 0 and 2PI (TAU)
	"""
	return fposmod(rotation, TAU)

func clean_neg_zero_vec2(vec2 : Vector2) -> Vector2:
	"""
	Given a Vector2, returns the Vector2, but with any 0 value as a positive 0
	
	This is due to following scenario:
		2*PI and -2*PI rotation are functionally pointing in the same direction, BUT
		direction of 2*PI => Vector2.RIGHT.rotated(2*PI) => Vector2(1, 0)
		direction of -2*PI => Vector2.RIGHT.rotated(-2*PI) => Vector2(1, -0)
		
		Comparing "same" directions, Vector2(1, 0) == Vector2(1, -0) is FALSE
		
		SO, just clean the Vector2 so that any -0 show up as 0
	"""
	var _new_vec2 : Vector2 = vec2
	
	if is_equal_approx(_new_vec2.x, 0.0):
		_new_vec2.x = 0.0
	if is_equal_approx(_new_vec2.y, 0.0):
		_new_vec2.y = 0.0
	
	return _new_vec2

func approx_equal_vec2(vec2_a : Vector2, vec2_b : Vector2, leeway : float = 0.0001) -> bool:
	"""
	Given two Vector2s, return whether they are "equal"
	
	leewayy : float -- how small the margin to consider two Vector2s as equal
	"""
	if (
			abs(vec2_a.x - vec2_b.x) < leeway and
			abs(vec2_a.y - vec2_b.y) < leeway
		):
			return true
	else:
		return false

func map(
			val : float,
			val_range_start : float, val_range_end : float,
			other_range_start : float, other_range_end : float
		) -> float:
	"""
	Given a number within a range, return the same number linearly mapped to a second range
	
	val : float -- value to linearly map
	val_range_start : float -- start of range value is in
	val_range_end : float -- end of range value is in
	other_range_start : float -- start of range value wants to be mapped into
	other_range_end : float -- end of range value wants to be mapped into
	"""
	var ratio : float = (other_range_end - other_range_start) / (val_range_end - val_range_start)
	return ratio * (val - val_range_start) + other_range_start

func get_2d_perpendicular_vect(vect : Vector2, is_counter_clockwise : bool) -> Vector2:
	"""
	Gets the vector perpendicular to the given vector
	
	vect : Vector2 -- given vector
	is_counter_clockwise : bool -- whether to get perpendicular vector 
	"""
	if is_counter_clockwise: # Counterclockwise (positive radians)
		return Vector2(-1 * vect.y, vect.x)
	else: # Clockwise (negative radians)
		return Vector2(vect.y, -1 * vect.x)

func in_rangei(num : int, min : int, max : int) -> bool:
	"""
	Returns : bool -- whether num is within range of [min, max]
	"""
	return (num >= min and num <= max)

func in_rangef(num : float, min : float, max : float) -> bool:
	"""
	Returns : bool -- whether num is within range of [min, max]
	"""
	return (num >= min and num <= max)

#############################
## Pixel translations
#############################
func get_full_viewport_pos_from_visible_viewport_pos(viewport : Viewport, canvas_pos : Vector2) -> Vector2:
	"""
	Visible viewport may have different resolution to the full viewport (black bars). For example,
	visible viewport size is [640, 480], while the full viewport is [1280, 720], which means that
	the pos [1280, 720] on the full viewport is mapped to pos [746.7, 480] on the visible viewport.
	
	viewport : Viewport -- the viewport to do the calculations against
	canvas_pos : Vector2 -- visible canvas coordinates [get_global_transform_with_canvas().origin] to translate into full viewport coordinates
	
	Returns the proportional coordinates of VISIBLE viewport to FULL viewport
	"""
	var _viewport_full : Vector2 = viewport.size
	var _viewport_visible : Vector2 = viewport.get_visible_rect().size
	
	var _proportional_coord : Vector2 = canvas_pos
	_proportional_coord.x *= _viewport_full.x / _viewport_visible.x
	_proportional_coord.y *= _viewport_full.y / _viewport_visible.y
	
	return _proportional_coord

#############################
## Bit-wise Functions
#############################
func get_col_layer_bit(layer_name : String) -> int:
	"""
	Returns : int -- the [bit] of the collision layer
	
	layer_name : String -- the name of the layer to get its bit
	"""
	return layer_bit_dict[layer_name]

func get_col_layer_value(layer_name : String) -> int:
	"""
	Returns : int -- the [value] of the collision layer
	
	layer_name : String -- the name of the layer to get its value
	"""
	return int(pow(2, get_col_layer_bit(layer_name)))

func bitmask_contains_bit(bitmask : int, bit_to_check : int) -> bool:
	"""
	Returns : bool -- whether bitmask contains bit

	bitmask : int -- bitmask potentially containing bit
	bit_to_check : int -- bit to check
	"""
	# To check if value B exists in bitmask A, do (A & B)==B
	if (bitmask & bit_to_check == bit_to_check):
		return true
	else:
		return false

func set_col_layer_bit(body : Node, col_layer : String) -> void:
	"""
	Sets a bit on a subject's collision layer (in physics, I am this)

	body : Node -- subject to have collision modified
	col_layer : String -- name of the layer whose bit should be set
	"""
	var _bit_set = get_col_layer_bit(col_layer)
	body.collision_layer |= (1 << _bit_set)

func unset_col_layer_bit(body : Node, col_layer : String) -> void:
	"""
	UNsets a bit on a subject's collision layer

	body : Node -- subject to have collision modified
	col_layer : String -- name of the layer whose bit should be set
	"""
	var _bit_unset = get_col_layer_bit(col_layer)
	body.collision_layer &= ~(1 << _bit_unset)

func set_col_mask_bit(body : Node, col_layer : String) -> void:
	"""
	Sets a bit on a subject's collision mask (in physics, I want to collide with this)

	body : Node -- subject to have collision modified
	col_layer : String -- name of the layer whose bit should be set
	"""
	var _bit_set = get_col_layer_bit(col_layer)
	body.collision_mask |= (1 << _bit_set)

func unset_col_mask_bit(body : Node, col_layer : String) -> void:
	"""
	UNsets a bit on a subject's collision mask

	body : Node -- subject to have collision modified
	col_layer : String -- name of the layer whose bit should be set
	"""
	var _bit_unset = get_col_layer_bit(col_layer)
	body.collision_mask &= ~(1 << _bit_unset)

#############################
## Component Functions
#############################
func set_raycast_len(ray : RayCast2D, hypotenuse : float, force_update : bool = false) -> void:
	"""
	Sets raycast length
	
	ray : RayCast2D -- raycast to have length set
	hypotenuse : float -- new length to set raycast to
	force_update : bool = false -- whether or not to force update raycast
	"""
	var _side = hypotenuse / sqrt(2) # Formula for side of isosceles right triangle
	ray.target_position = Vector2(-_side, _side)
	if force_update:
		ray.force_raycast_update()

func reset_animplayer(c_player : AnimationPlayer):
	"""
	Resets animations of AnimationPlayer
	
	c_player : AnimationPlayer -- the AnimationPlayer to reset
	"""
	c_player.stop()
	c_player.current_animation = ""
	c_player.assigned_animation = ""

func play_no_repeat(c_player : AnimationPlayer, anim_name : String):
	"""
	Plays animation once. Won't repeat even when called again, as long as animation stays the same

	c_player : AnimationPlayer -- the AnimationPlayer that plays the animation
	anim_name : String -- name of animation to play without repeating
	"""
	if (
			c_player.assigned_animation != anim_name or # Completely different animation
			(
				c_player.current_animation == anim_name and
				c_player.current_animation_position <= c_player.current_animation_length * 0.97 # Same animation, not yet finished
			)
		):
		c_player.play(anim_name) # Play animation
	elif not c_player.is_playing():
		return # Return, which keeps the animation on the same last frame
	#else:
	#	c_player.advance(c_player.current_animation_length) # Move animation to last frame

func get_track_and_key_ids_for_method_track(anim : Animation, method_name : String) -> Array[int]:
	"""
	anim - given Animation to scan for method track
	method_name - method name to scan for in method track
	
	Returns : Array[int] -- If given Animation contains the method track:
						-- index 0, the track_id for FIRST occurence of method
						-- index 1, the key_id for FIRST occurence of method
						-- If Animation does NOT contain method track, return [-1, -1]
	"""
	var _f_found : bool = false
	var _track_id : int = -1
	var _key_id : int = -1
	
	# For every track in Animation, find a method track
	for track_id in anim.get_track_count():
		# Found a method track
		if anim.find_track(anim.track_get_path(track_id), Animation.TYPE_METHOD) != -1:
			# For every key in method track
			for key_id in anim.track_get_key_count(track_id):
				if anim.method_track_get_name(track_id, key_id) == method_name:
					# Found the EXACT method name for key in track
					_track_id = track_id
					_key_id = key_id
					_f_found = true
					break # Break key loop
		if _f_found:
			break # Break track loop

	return [_track_id, _key_id]

#############################
## Node Helper Functions
#############################
func wait(secs : float) -> void:
	"""
	Waits for some seconds before continuing

	secs : float -- how many seconds to wait
	
	Use like this: "await Utilities.wait(10)"
	"""
	await get_tree().create_timer(secs).timeout

func is_player(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body is Player 
	"""
	if body == null: return false

	if body.is_in_group("Player"):
		return true
	else:
		return false

func is_cyarm(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body is Cyarm 
	"""
	if body == null: return false

	if body.is_in_group("Cyarm"):
		return true
	else:
		return false

func is_terrain(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body is Terrain 
	"""
	if body == null: return false

	if body.is_in_group("Terrain"):
		return true
	else:
		return false

func is_RID_terrain(rid : RID) -> bool:
	"""
	rid : RID -- the RID of some collider to query

	Returns : bool -- whether or not given body is Terrain
	"""
	var _bit_mask = PhysicsServer2D.body_get_collision_layer(rid)
	# To check if value exists in bitmask A, do (A & B)==B
	if bitmask_contains_bit(_bit_mask, get_col_layer_value("Terrain")):
		return true
	else:
		return false

func is_pulsable(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body is can be affected by Cyarm-Shield pulse 
	"""
	if body == null: return false

	if body.is_in_group("Pulsable"):
		return true
	else:
		return false

func is_freezable(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body can be frozen in place
	"""
	if body == null: return false

	if body.has_method("freeze"):
		return true
	else:
		return false

func is_moveable(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body can be moved
	"""
	if body == null: return false

	if body.has_method("add_vel"):
		return true
	else:
		return false

func is_sicklepullable(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body can be pulled with Cyarm-Sickle
	"""
	if body == null: return false

	if body.has_method("sicklepull_me"):
		return true
	else:
		return false

func is_pullable(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body can be pulled with Cyarm-Sickle
	"""
	if body == null: return false

	if body.has_method("pull_me"):
		return true
	else:
		return false

func is_damageable(body : Node) -> bool:
	"""
	body : Node -- subject to query

	Returns : bool -- whether or not given body can be damaged
	"""
	if body == null: return false

	if body.has_method("damage_me"):
		return true
	else:
		return false

func get_middlepos_of(body : Node) -> Vector2:
	"""
	body : Node -- subject to get middle position of

	Returns : Vector2 -- the subject's middle position
	"""
	if body == null: return Vector2.ZERO
	
	if body.has_method("get_middlepos"):
		return body.get_middlepos()
	else:
		return body.global_position

func get_main_sprite(body : Node) -> Node2D:
	"""
	body : Node -- subject to get main sprite of

	Returns : Node2D -- Sprite2D or AnimatedSprite2D
	"""
	if not "c_sprite" in body:
		return null
	else:
		return body.c_sprite

func get_crush_collider(body : Node) -> CollisionShape2D:
	"""
	body : Node -- subject to get collider of

	Returns : CollisionShape2D --
		if the subject can be crushed (to death), then its main body collider
		else, null
	"""
	if not is_damageable(body): # If body cannot be damaged, it cannot be crushed
		return null
		
	if not body.has_method("get_mbody_collider"): # If body has no main body collider, it cannot be crushed
		return null
	else:
		return body.get_mbody_collider()

func notify_can_be_hit(enemy_ref, can_be_hit : bool) -> void:
	"""
	Calls notify_can_be_hit() on given Node
	
	enemy_ref : Node -- the Node to call the function on (or null, if the Enemy was destroyed)
	can_be_hit : bool -- whether the Node in question can be hit
	"""
	# Make sure Enemy ref is valid (might be destroyed before this function is called)
	if not enemy_ref == null:
		enemy_ref.notify_can_be_hit(can_be_hit)
