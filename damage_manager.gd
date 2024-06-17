extends Node

#region Signals
signal sig_world_spawn_damage_text(damage : DamageManager.DamageBase, defender_pos : Vector2, damage_dir : Vector2)
signal sig_world_spawn_rot_effect(pos : Vector2, rot : float, anim : String)
#endregion

enum DamageResult{
	SUCCESS, # Did damage
	DEATH, # Did damage, and killed defender
	IGNORE, # Did no damage
	PARRIED, # Did no damage, and hurt attacker
	}
	
class DamageBase:
	var source : Node2D # Who produces this damage?
	var from_pos : Vector2 = Vector2.ZERO # Place where damage comes from
	var base_damage : int
	var damage_spread : int
	var crit_chance : float
	
	var curr_damage : int

	func _init(
				_source : Node2D,
				_base_damage : int = 0,
				_damage_spread : int = 0,
				_crit_chance : float = 0,
				) -> void:
		source = _source
		base_damage = _base_damage
		damage_spread = _damage_spread
		crit_chance = _crit_chance
		
	func roll() -> int:
		"""
		Returns : int -- current damage
		"""
		curr_damage = base_damage + Globals.random.randi_range(-1 * damage_spread, damage_spread)
		if (Globals.random.randf() <= crit_chance):
			curr_damage = max(curr_damage, base_damage) # Max floor
			curr_damage *= 2 # Double damage on crit
			
		return curr_damage
	
	func modify_from_pos(new_pos : Vector2) -> void:
		"""
		Updates the damage position (in case its different from the source position)
		"""
		from_pos = new_pos
	
	func get_from_pos() -> Vector2:
		"""
		Returns : Vector2 -- the global_position of the source of damage
		"""
		if from_pos != Vector2.ZERO:
			return from_pos
		else:
			return Utilities.get_middlepos_of(source)
	
	func copy_from(other : DamageBase) -> void:
		"""
		Copies attributes from other DamageBase object
		
		other : DamageBase -- other DamageBase to copy over
		"""
		source = other.source
		base_damage = other.base_damage
		damage_spread = other.damage_spread
		crit_chance = other.crit_chance

func calc_damage(attacker_dmg : DamageBase, defender : Node2D) -> DamageResult:
	"""
	Calculates damage between attacker and defender
	
	attacker_dmg : DamageBase -- object that represents the attacker's damage
	defender : Node2D -- subject that is being damaged
	"""
	if not Utilities.is_damageable(defender):
		return DamageResult.IGNORE # No damage was done
		
	## Damage to be dealt
	var _dmg_to_do : int = attacker_dmg.roll() # Randomize the attacker's damage for this instance
	if defender.has_method("get_defense_modifier"):
		# Modify damage based on defender
		_dmg_to_do *= defender.get_defense_modifier()
	if Utilities.is_player(defender):
		# Player takes damage per hit, so choose min between 0 and 1
		_dmg_to_do = min(_dmg_to_do, 1)
	attacker_dmg.curr_damage = _dmg_to_do # Set current damage to do

	## Direction of damage
	var _attacker_pos = attacker_dmg.get_from_pos()
	var _defender_pos = Utilities.get_middlepos_of(defender)
	var _dmg_dir = (_defender_pos - _attacker_pos).normalized()
	
	## Result of damage
	var _result = defender.damage_me(attacker_dmg.curr_damage, _dmg_dir)
	if _result == DamageResult.SUCCESS or _result == DamageResult.DEATH:
		# Signal World to spawn damage text
		var _above_defender_pos = _defender_pos + (_defender_pos - defender.global_position)
		sig_world_spawn_damage_text.emit(attacker_dmg, _above_defender_pos, _dmg_dir)
	elif _result == DamageResult.PARRIED:
		# Signal World to spawn parry FX
		var _between_pos : Vector2 = (_attacker_pos + _defender_pos) / 2
		sig_world_spawn_rot_effect.emit(_between_pos, Globals.random.randf_range(0.0, TAU), PSLib.anim_parry)

	## Do damage
	return _result
