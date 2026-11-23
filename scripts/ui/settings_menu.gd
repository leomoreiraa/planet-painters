class_name SettingsMenu
extends Control

signal back_pressed

@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterValLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_label: Label = %MusicValLabel
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_label: Label = %SFXValLabel

@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var vsync_check: CheckButton = %VSyncCheck

@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	_setup_options()
	_connect_signals()
	refresh_ui_from_settings()

func _setup_options() -> void:
	# Modos de tela
	window_mode_option.clear()
	window_mode_option.add_item("Janela", 0)
	window_mode_option.add_item("Tela Cheia", 1)
	window_mode_option.add_item("Tela Cheia Exclusiva", 2)

	# Resoluções
	resolution_option.clear()
	resolution_option.add_item("960 x 540", 0)
	resolution_option.add_item("1280 x 720 (HD)", 1)
	resolution_option.add_item("1600 x 900", 2)
	resolution_option.add_item("1920 x 1080 (Full HD)", 3)
	resolution_option.add_item("2560 x 1440 (2K)", 4)

func _connect_signals() -> void:
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)

	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	vsync_check.toggled.connect(_on_vsync_toggled)

	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	if close_button:
		close_button.pressed.connect(_on_back_pressed)
		close_button.mouse_entered.connect(func(): SoundEffects.play_hover())

	# Efeitos sonoros
	for btn in [reset_button, back_button, vsync_check]:
		btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		btn.focus_entered.connect(func(): SoundEffects.play_hover())
		btn.pressed.connect(func(): SoundEffects.play_click())

	for sld in [master_slider, music_slider, sfx_slider]:
		sld.mouse_entered.connect(func(): SoundEffects.play_hover())
		sld.drag_ended.connect(func(_val): SoundEffects.play_click())

func refresh_ui_from_settings() -> void:
	# Áudio
	var m_vol: float = SettingsManager.get_bus_volume("Master")
	master_slider.value = m_vol * 100.0
	master_label.text = "%d%%" % int(round(m_vol * 100.0))

	var bgm_vol: float = SettingsManager.get_bus_volume("Music")
	music_slider.value = bgm_vol * 100.0
	music_label.text = "%d%%" % int(round(bgm_vol * 100.0))

	var sfx_vol: float = SettingsManager.get_bus_volume("SFX")
	sfx_slider.value = sfx_vol * 100.0
	sfx_label.text = "%d%%" % int(round(sfx_vol * 100.0))

	# Vídeo
	var mode: int = SettingsManager.get_window_mode()
	window_mode_option.select(mode)
	_update_resolution_enabled_state(mode)

	var res_idx: int = SettingsManager.get_resolution_index()
	resolution_option.select(res_idx)

	var vsync: bool = SettingsManager.get_vsync()
	vsync_check.button_pressed = vsync

func _update_resolution_enabled_state(mode: int) -> void:
	# Se estiver em tela cheia, resolução de janela fica desativada para evitar conflito
	resolution_option.disabled = (mode != 0)

func _on_master_slider_changed(value: float) -> void:
	var linear := value / 100.0
	SettingsManager.set_bus_volume("Master", linear)
	master_label.text = "%d%%" % int(round(value))

func _on_music_slider_changed(value: float) -> void:
	var linear := value / 100.0
	SettingsManager.set_bus_volume("Music", linear)
	music_label.text = "%d%%" % int(round(value))

func _on_sfx_slider_changed(value: float) -> void:
	var linear := value / 100.0
	SettingsManager.set_bus_volume("SFX", linear)
	sfx_label.text = "%d%%" % int(round(value))

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)
	_update_resolution_enabled_state(index)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution_index(index)

func _on_vsync_toggled(toggled_on: bool) -> void:
	SettingsManager.set_vsync(toggled_on)

func _on_reset_pressed() -> void:
	SettingsManager.apply_defaults()
	refresh_ui_from_settings()

func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	back_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
