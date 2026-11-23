extends Control

@onready var back_button: Button = %BackToMenuButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_to_menu_pressed)

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
