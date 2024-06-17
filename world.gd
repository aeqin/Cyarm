extends Node2D

### Signals
signal sig_world_paused(pause_status : bool)
signal sig_world_readied

### External Scenes
var s_afterimage : PackedScene = preload("res://scenes/afterimage.tscn")
var s_particle_spawner : PackedScene = preload("res://scenes/particle_spawner.tscn")
var s_text_spawner : PackedScene = preload("res://scenes/text_spawner.tscn")
var s_projectile : PackedScene = preload("res://scenes/projectile.tscn")
var s_laser_grenade : PackedScene = preload("res://scenes/laser_grenade.tscn")
var s_laser_grenade_launcher : PackedScene = preload("res://scenes/laser_grenade_launcher.tscn")
var s_mine : PackedScene = preload("res://scenes/mine.tscn")
var s_lightning : PackedScene = preload("res://scenes/lightning.tscn")
var s_swordiaistop : PackedScene = preload("res://scenes/cyarm_sword_iai_stop.tscn")
var s_swordiaicut : PackedScene = preload("res://scenes/cyarm_sword_iai_cut.tscn")
var s_sicklepulldecision : PackedScene = preload("res://scenes/cyarm_sickle_pull_decision.tscn")
var s_sickleshard : PackedScene = preload("res://scenes/cyarm_sickle_shard.tscn")

var s_electro : PackedScene = preload("res://scenes/electro.tscn")

### Component references
@onready var c_folder_pausable : Node = $Pausable
@onready var c_folder_whenpaused : Node = $WhenPaused
@onready var c_folder_pausable_terrain : Node = $Pausable/Terrain
@onready var c_folder_pausable_objects : Node = $Pausable/Objects
@onready var c_folder_pausable_fx : Node = $Pausable/FX
@onready var c_canvmod_dimmer : CanvasModulate = $WorldDimmer
@onready var c_canvmod_background_dimmer : CanvasModulate = $Background/BackgroundDimmer

#################
## Main functions
#################
func _ready() -> void:
	# Subscribe to signals
	var _Player : Node2D = get_tree().get_first_node_in_group("Player")
	_Player.connect("sig_world_dim", _on_received_dim)
	_Player.connect("sig_world_spawn_afterimage", _on_received_spawn_afterimage)
	_Player.connect("sig_world_spawn_dust", _on_received_spawn_dust)
	_Player.connect("sig_world_spawn_rot_effect", _on_received_spawn_rot_effect)
	_Player.connect("sig_world_spawn_sicklepulldecision", _on_received_spawn_sicklepulldecision)

	for cyarm in get_tree().get_nodes_in_group("Cyarm"):
		cyarm.connect("sig_world_spawn_rot_effect", _on_received_spawn_rot_effect)
		cyarm.connect("sig_world_spawn_swordiaistop", _on_received_spawn_swordiaistop)
		cyarm.connect("sig_world_spawn_swordiaicut", _on_received_spawn_swordiaicut)

	DamageManager.connect("sig_world_spawn_damage_text", _on_received_spawn_damage_text)
	DamageManager.connect("sig_world_spawn_rot_effect", _on_received_spawn_rot_effect)

	for explodable in get_tree().get_nodes_in_group("Explodable"):
		explodable.connect("sig_world_spawn_explosion", _on_received_spawn_explosion)
	for pause_req in get_tree().get_nodes_in_group("PauseRequester"):
		pause_req.connect("sig_world_pause", _on_received_pause_world)
	for projectile_spawner in get_tree().get_nodes_in_group("ProjectileSpawner"):
		projectile_spawner.connect("sig_world_spawn_projectile", _on_received_spawn_projectile)
	for laser_grenade_spawner in get_tree().get_nodes_in_group("LaserGrenadeSpawner"):
		laser_grenade_spawner.connect("sig_world_spawn_laser_grenade", _on_received_spawn_laser_grenade)
	for laser_grenade_launcher_spawner in get_tree().get_nodes_in_group("LaserGrenadeLauncherSpawner"):
		laser_grenade_launcher_spawner.connect("sig_world_spawn_laser_grenade_launcher", _on_received_spawn_laser_grenade_launcher)
	for lightning_generator in get_tree().get_nodes_in_group("LightningGenerator"):
		lightning_generator.connect("sig_world_spawn_lightning", _on_received_spawn_lightning)
	for shard_spawner in get_tree().get_nodes_in_group("CyarmSickleShardSpawner"):
		shard_spawner.connect("sig_world_spawn_sickleshard", _on_received_spawn_sickleshard)
		
	# Signal that the World is ready
	sig_world_readied.emit()

func _process(_delta : float) -> void:
	update_inputs()

func update_inputs() -> void:
	if Input.is_action_just_pressed("change_cyarm"):
		pause(true)
	if Input.is_action_just_released("change_cyarm"):
		pause(false)

	# Debug a mechanic with a test key
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("testkey"):
		pass
	if Input.is_action_just_pressed("testkey2"):
		pass

func pause(status : bool) -> void:
	"""
	Pause the world
	"""
	get_tree().paused = status
	
	Globals.update_mouse_pos() # Update mouse position before re-enabling crosshair (since mouse may move during pause menu)
	
	sig_world_paused.emit(status)

func dim_world() -> void:
	"""
	Dims the world
	"""
	var tween = get_tree().create_tween()
	tween.tween_property(c_canvmod_dimmer, 'color', Color.DIM_GRAY, 0.3)

	var tween_background = get_tree().create_tween()
	tween_background.tween_property(c_canvmod_background_dimmer, 'color', Color.DIM_GRAY, 0.3)
	
func undim_world() -> void:
	"""
	Undims the world
	"""
	var tween = get_tree().create_tween()
	tween.tween_property(c_canvmod_dimmer, 'color', Color.WHITE, 0.3)

	var tween_background = get_tree().create_tween()
	tween_background.tween_property(c_canvmod_background_dimmer, 'color', Color.WHITE, 0.3)

#################
## Signals
#################
func _on_received_dim(do_dim : bool):
	"""
	Dims/Undims world
	"""
	if do_dim: dim_world()
	else: undim_world()

func _on_received_spawn_afterimage(pos : Vector2, facing_dir : float) -> void:
	"""
	Spawn afterimage of Player dash
	"""
	var afterimage : Node2D = s_afterimage.instantiate()
	afterimage.global_position = pos
	afterimage.scale.x = facing_dir
	c_folder_pausable_fx.add_child(afterimage)

func _on_received_spawn_dust(
								pos : Vector2, facing_dir_x : float, facing_dir_y : float,
								anim : String,
								ground_dir : Vector2 = Vector2.ZERO
							) -> void:
	"""
	Spawn dust of Player (land, jump, etc.)
	"""
	var _dust : Node2D = s_particle_spawner.instantiate() as ParticleSpawner
	c_folder_pausable_fx.call_deferred("add_child", _dust)
	_dust.call_deferred("spawn_dust", pos, facing_dir_x, facing_dir_y, anim, ground_dir)

func _on_received_spawn_rot_effect(pos : Vector2, rot : float, anim : String) -> void:
	"""
	Spawn rotate-able effect, like Cyarm hit or Electro flick
	"""
	var _rot_effect : Node2D = s_particle_spawner.instantiate() as ParticleSpawner
	c_folder_pausable_fx.call_deferred("add_child", _rot_effect)
	_rot_effect.call_deferred("spawn_rot_effect", pos, rot, anim)

func _on_received_spawn_explosion(pos : Vector2, size : float) -> void:
	"""
	Spawn explosion
	"""
	var expl : Node2D = s_particle_spawner.instantiate() as ParticleSpawner
	c_folder_pausable_fx.call_deferred("add_child", expl)
	expl.call_deferred("spawn_explosion", pos, size)

func _on_received_spawn_damage_text(damage : DamageManager.DamageBase, defender_pos : Vector2, damage_dir : Vector2) -> void:
	"""
	Spawn damage text
	
	damage : DamageManager.DamageBase -- object containing damage done
	defender_pos : Vector2 -- position to spawn damage text (subject getting hit)
	damage_dir : Vector2 -- direction of the damage
	
	o_dmg : Damage -- object bundle of damage properties
	"""
	var _left_or_right : float = -1 * sign(damage_dir.x)
	var _horizontal_vel = -40 + RandomNumberGenerator.new().randi_range(-15, 15)
	var _vertical_vel = -300
	var _textLaunch_dir = Vector2(_left_or_right * _horizontal_vel, _vertical_vel)
	var _lifetime : float = 0.4
	var _gravity : float = 24
	var _intensity : float = float(damage.curr_damage) / damage.base_damage

	var hitText : Node2D = s_text_spawner.instantiate() as TextSpawner
	hitText.initialize("-" + str(damage.curr_damage), defender_pos,
						_textLaunch_dir, _lifetime, _gravity, true, _intensity)
	add_child(hitText)

func _on_received_spawn_projectile(_creator : Node, o_damage : DamageManager.DamageBase, pos : Vector2, dir : Vector2) -> void:
	"""
	Spawn Projectile
	"""
	var projectile : Node2D = s_projectile.instantiate()
	projectile.call_deferred("spawn", _creator, o_damage, pos, dir)
	
	c_folder_pausable_objects.add_child(projectile)

func _on_received_spawn_laser_grenade(_creator : Node, o_damage : DamageManager.DamageBase, pos : Vector2, dir : Vector2, dist : float) -> void:
	"""
	Spawn LaserGrenade
	"""
	var laser_grenade : Node2D = s_laser_grenade.instantiate()
	laser_grenade.call_deferred("spawn", _creator, o_damage, pos, dir, dist)
	
	c_folder_pausable_objects.add_child(laser_grenade)

func _on_received_spawn_laser_grenade_launcher(pos : Vector2, dir : Vector2) -> void:
	"""
	Spawn LaserGrenadeLauncher
	"""
	var laser_grenade_launcher : Node2D = s_laser_grenade_launcher.instantiate()
	laser_grenade_launcher.connect("sig_world_spawn_laser_grenade", _on_received_spawn_laser_grenade)
	laser_grenade_launcher.call_deferred("spawn", pos, dir)
	
	c_folder_pausable_objects.add_child(laser_grenade_launcher)

func _on_received_spawn_mine(_creator : Node, _damage : DamageManager.DamageBase, pos : Vector2) -> void:
	"""
	Spawn Mine
	"""
	var mine : Node2D = s_mine.instantiate()
	mine.call_deferred("spawn", _creator, _damage, pos)
	 
	c_folder_pausable_objects.add_child(mine)

func _on_received_spawn_lightning(start_pos : Vector2, end_pos : Vector2) -> void:
	"""
	Spawn Lightning
	"""
	var lightning : Node2D = s_lightning.instantiate()
	lightning.call_deferred("spawn", start_pos, end_pos)
	
	c_folder_pausable_objects.add_child(lightning)

func _on_received_spawn_swordiaistop(start_pos : Vector2, time_left : float, max_length : float) -> void:
	"""
	Spawn SwordIaiStop
	
	start_pos : Vector2 -- position of the Player
	time_left : float -- how long SwordIaiStop lasts
	max_length : float -- the maximum cut length of Sword Iai
	"""
	var swordiaistop : Control = s_swordiaistop.instantiate()
	swordiaistop.call_deferred("spawn", start_pos, time_left, max_length)

	c_folder_pausable_objects.add_child(swordiaistop)

func _on_received_spawn_swordiaicut(begin : Vector2, end : Vector2, o_damage : DamageManager.DamageBase) -> void:
	"""
	Spawn SwordIaiCut
	
	begin : Vector2 -- begin position of cut
	end : Vector2 -- end position of cut
	o_damage : DamageManager.DamageBase -- damage of Sword Iai cut
	"""
	var swordiaicut : Area2D = s_swordiaicut.instantiate()
	swordiaicut.call_deferred("spawn", begin, end, o_damage)

	c_folder_pausable_objects.add_child(swordiaicut)

func _on_received_spawn_sicklepulldecision(start_pos : Vector2, time_left : float, sickle_stuck_target : Node) -> void:
	"""
	Spawn SicklePullDecision
	
	start_pos : Vector2 -- position of the Sickle
	time_left : float -- how long SicklePullDecision lasts
	sickle_stuck_target : Node -- what Node is the Sickle stuck in
	"""
	var sicklepulldecision : Control = s_sicklepulldecision.instantiate()
	sicklepulldecision.call_deferred("spawn", start_pos, time_left, sickle_stuck_target)

	c_folder_pausable_objects.add_child(sicklepulldecision)

func _on_received_spawn_sickleshard(sickle_ref : Node2D, start_pos : Vector2, dir : Vector2, level : int) -> void:
	"""
	Spawn CyarmSickleShard
	"""
	var sickleshard : Node2D = s_sickleshard.instantiate()
	sickleshard.call_deferred("spawn", sickle_ref, start_pos, dir, level)
	
	c_folder_pausable_objects.add_child(sickleshard)

func _on_received_spawn_sickleshard_pickup_effect(pos : Vector2) -> void:
	"""
	Spawn effect from Player pickng up CyarmSickleShard
	"""
	var pickup_effect : Node2D = s_particle_spawner.instantiate() as ParticleSpawner
	c_folder_pausable_fx.call_deferred("add_child", pickup_effect)
	pickup_effect.call_deferred("spawn_sickle_shard_pickup", pos)

func _on_received_pause_world(doPause : bool) -> void:
	"""
	Pause the world
	"""
	pause(doPause)
