class_name MainMenu
extends Control

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var about_button: Button = %AboutButton
@onready var quit_button: Button = %QuitButton

@onready var settings_menu: Control = %SettingsMenu
@onready var about_dialog: Control = %AboutDialog
@onready var close_about_button: Button = %CloseAboutButton

var _buttons: Array[Button] = []

func _ready() -> void:
	play_button.icon = preload("res://resources/ui/icons/icon_new_world.png")
	play_button.text = "Criar Planeta"
	settings_button.icon = preload("res://resources/ui/icons/icon_gear.png")
	settings_button.text = "Configurações"
	about_button.icon = preload("res://resources/ui/icons/icon_info.png")
	about_button.text = "Sobre o Simulador"
	quit_button.icon = preload("res://resources/ui/icons/icon_exit.png")
	quit_button.text = "Sair"

	_buttons = [play_button, settings_button, about_button, quit_button]

	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	about_button.pressed.connect(_on_about_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	for btn in _buttons:
		_setup_button_effects(btn)

	settings_menu.visible = false
	settings_menu.back_pressed.connect(_on_settings_back_pressed)

	about_dialog.visible = false
	close_about_button.pressed.connect(_on_close_about_pressed)
	_setup_button_effects(close_about_button)

	# Foco inicial para navegação por teclado ou gamepad
	play_button.grab_focus()

func _setup_button_effects(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		SoundEffects.play_hover()
		_animate_button(btn, true)
	)
	btn.mouse_exited.connect(func():
		_animate_button(btn, false)
	)
	btn.focus_entered.connect(func():
		SoundEffects.play_hover()
		_animate_button(btn, true)
	)
	btn.focus_exited.connect(func():
		_animate_button(btn, false)
	)

func _animate_button(btn: Button, hovered: bool) -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if hovered:
		tween.tween_property(btn, "modulate", Color(1.15, 1.25, 1.4, 1.0), 0.15)
	else:
		tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

func _on_play_pressed() -> void:
	SoundEffects.play_click()
	get_tree().change_scene_to_file("res://scenes/game/planet_creator.tscn")

func _on_settings_pressed() -> void:
	SoundEffects.play_click()
	settings_menu.visible = true
	if settings_menu.has_method("refresh_ui_from_settings"):
		settings_menu.refresh_ui_from_settings()

func _on_settings_back_pressed() -> void:
	SoundEffects.play_click()
	settings_menu.visible = false
	settings_button.grab_focus()

func _on_about_pressed() -> void:
	SoundEffects.play_click()
	about_dialog.visible = true
	close_about_button.grab_focus()

func _on_close_about_pressed() -> void:
	SoundEffects.play_click()
	about_dialog.visible = false
	about_button.grab_focus()

func _on_quit_pressed() -> void:
	SoundEffects.play_click()
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if settings_menu.visible:
				_on_settings_back_pressed()
				get_viewport().set_input_as_handled()
			elif about_dialog.visible:
				_on_close_about_pressed()
				get_viewport().set_input_as_handled()
