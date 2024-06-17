extends Node2D

@onready var c_sprite_dash = $Sprite2D

func _ready() -> void:
	var fade_tween = create_tween()
	fade_tween.tween_property(c_sprite_dash, "modulate:a", 0, 0.1)
	fade_tween.tween_callback(queue_free)
