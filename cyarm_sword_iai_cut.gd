extends Area2D

#region Signals
signal sig_cyarm_swordiai_cut_killed()

### Components
@onready var c_animplayer : AnimationPlayer = $AnimationPlayer
@onready var c_sprite : AnimatedSprite2D = $CutSprite
@onready var c_collider : CollisionShape2D = $CutCollider
@onready var c_shapecast_before_cut : ShapeCast2D = $BeforeCutCast
@onready var c_line_beforestream : Line2D = $BeforeStreamLine
@onready var c_line_cut_small_to_big : Line2D = $PotentialCut_small_to_big
@onready var c_line_cut_big_to_small : Line2D = $PotentialCut_big_to_small
@onready var c_particles_stream : GPUParticles2D = $StreamParticles

var begin_pos : Vector2
var mid_pos : Vector2
var end_pos : Vector2
var int_distance : int = 100
var o_cut_damage : DamageManager.DamageBase
var frozen_enemies : Array

var anim_swordiai_before_cut : String = "before_cut"
var anim_swordiai_cut : String = "cut"
var anim_swordiai_blank : String = "blank"

func _ready() -> void:
	## Force node to subscribe to signals
	var _cyarm_sword : Node = get_tree().get_first_node_in_group("CyarmSword")
	self.sig_cyarm_swordiai_cut_killed.connect(_cyarm_sword._on_received_swordiai_cut_killed)
	
	## Subscribe to signals
	var _Player : Node = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_player_swordiai_ended_cut", _on_received_swordiai_end_cut)

func _process(delta: float) -> void:
	update_animations()

func update_animations() -> void:
	"""
	Play animation of Sword Iai cut
	"""
	pass

func spawn(begin : Vector2, end : Vector2, o_damage : DamageManager.DamageBase):
	"""
	Spawns SwordIaiCut

	begin : Vector2 -- begin position of cut
	end : Vector2 -- end position of cut
	o_damage : DamageManager.DamageBase -- damage of cut
	"""
	# Calculate positions and distance
	begin_pos = begin
	end_pos = end
	mid_pos = (begin_pos + end_pos) / 2
	int_distance = int(begin_pos.distance_to(end_pos))
	
	# Set position and rotation
	global_position = mid_pos
	rotation = (end_pos - begin_pos).normalized().angle()
	z_index = Globals.player_z_index # Display on Player layer (above Enemies)
	
	# Calibrate slash
	(c_collider.shape as RectangleShape2D).size.x = int_distance # Distance of cut
	o_cut_damage = o_damage # Damage of cut

	# For each Enemy that would be hit by cut, freeze them
	(c_shapecast_before_cut.shape as RectangleShape2D).size.x = int_distance
	c_shapecast_before_cut.force_shapecast_update()
	while c_shapecast_before_cut.is_colliding():
		var _enemy : Node2D = c_shapecast_before_cut.get_collider(0)
		if Utilities.is_freezable(_enemy):
			_enemy.freeze(true)
		
		frozen_enemies.append(_enemy)
		c_shapecast_before_cut.add_exception(_enemy)
		c_shapecast_before_cut.force_shapecast_update()

	# Begin with nothing playing
	c_sprite.play(anim_swordiai_blank)

func die() -> void:
	"""
	Destroys SwordIaiCut
	"""
	# Unfreeze Enemies frozen before cut
	for _enemy in frozen_enemies:
		if _enemy != null:
			_enemy.unfreeze()
	
	call_deferred("queue_free")

func clear_lines() -> void:
	"""
	Clears points of all the Line2Ds
	"""
	c_line_beforestream.clear_points()
	c_line_cut_small_to_big.clear_points()
	c_line_cut_big_to_small.clear_points()

func animfunc_line() -> void:
	"""
	Called by AnimationPlayer, spawns a line before stream of particles
	"""
	clear_lines()
	c_line_beforestream.add_point(to_local(begin_pos))
	c_line_beforestream.add_point(to_local(end_pos))

func animfunc_stream() -> void:
	"""
	Called by AnimationPlayer, spawns a stream of particles before Sword Iai cut
	"""
	clear_lines()
	
	# Number of particles increases as the distance of Sword Iai cut increases
	c_particles_stream.amount = int_distance
	(c_particles_stream.process_material as ParticleProcessMaterial).emission_box_extents.x = int_distance / 2
	c_particles_stream.emitting = true

func animfunc_cut(thickness : float) -> void:
	"""
	Called by AnimationPlayer, spawns a diamond that represents SwordIaiCut
	"""
	clear_lines()
	
	## Draw the potential path of Sword Iai cut
	var _beginpoint : Vector2 = to_local(begin_pos)
	var _midpoint : Vector2 = to_local(mid_pos)
	var _endpoint : Vector2 = to_local(end_pos)
	
	# Draw small to big (from start point to midpoint)
	c_line_cut_small_to_big.width = thickness
	c_line_cut_small_to_big.add_point(_beginpoint)
	c_line_cut_small_to_big.add_point(_midpoint)
	
	# Draw big to small (from midpoint to endpoint)
	c_line_cut_big_to_small.width = thickness
	c_line_cut_big_to_small.add_point(_midpoint)
	c_line_cut_big_to_small.add_point(_endpoint)
	
	# Turn ON collision for slash check
	monitoring = true

func animfunc_end_cut() -> void:
	# Turn OFF collision for slash check
	monitoring = false
	
	die()

##################
## Received Signals
##################
func _on_received_swordiai_end_cut() -> void:
	"""
	Once Player has reached end of cut, play animation of cut and do cut damage
	"""
	c_animplayer.play(anim_swordiai_before_cut)

func _on_body_entered(hit_body: Node2D) -> void:
	"""
	Do Sword Iai Cut damage
	
	hit_body: Node2D -- subject to be hit
	"""
	var _damage_result : DamageManager.DamageResult = DamageManager.calc_damage(o_cut_damage, hit_body)
	if _damage_result == DamageManager.DamageResult.DEATH:
		# If Sword Iai cut kills something, then send signal to refresh its cooldown
		sig_cyarm_swordiai_cut_killed.emit()
