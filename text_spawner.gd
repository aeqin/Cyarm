extends CharacterBody2D
class_name TextSpawner

## Components
@onready var c_label : Label = $Label
@onready var c_timer_life : Timer = $Lifetime

var text : String = ""
var pos : Vector2 = Vector2.ZERO
var initial_velocity : Vector2 = Vector2.ZERO
var lifetime : float = 1.0
var gravity : float = 0.0
var intensity : float = 1.0
var text_start_size : int = 12
var fade : bool = true

func _ready() -> void:
	c_label.text = text
	global_position = pos
	velocity = initial_velocity
	c_timer_life.wait_time = lifetime # How long text lives
	c_label.add_theme_font_size_override("font_size", int(text_start_size * clamp(intensity, 1.0, 2.2))) # Text start size
	if intensity >= 2.0:
		# Crit
		c_label.modulate = Color.ORANGE_RED
		scale = Vector2(1.2, 1.2)

	if fade:
		var _fade_tween = create_tween()
		_fade_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
		_fade_tween.tween_property(self, "scale", Vector2(0.3, 0.3), lifetime)
		_fade_tween.tween_property(self, "modulate:a", 0.0, lifetime)

	c_timer_life.start()

func _physics_process(_delta : float) -> void:
	velocity.y += gravity # Fall

	move_and_slide()

func initialize(
				_text, _pos, _initial_velocity,
				_lifetime = 1.0, _gravity = 0, _fade = true,
				_intensity = 1.0,) -> void:
	"""
	Basically Constructor, because there's no calling _init() while instantiating node
	"""
	text = _text
	pos = _pos
	initial_velocity = _initial_velocity
	lifetime = _lifetime # How long text lives
	gravity = _gravity
	fade = _fade
	intensity = _intensity

##################
## Received Signals
##################
func _on_lifetime_timeout() -> void:
	call_deferred("queue_free")
