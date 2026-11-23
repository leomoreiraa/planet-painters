extends Node

# SettingsManager.gd
# Gerenciador global de configurações do Planet Painters
# Responsável por persistir áudio, vídeo e preferências do jogador.

signal settings_changed
signal volume_changed(bus_name: String, value: float)

const SAVE_PATH: String = "user://settings.cfg"

# Configurações padrão
const DEFAULTS: Dictionary = {
	"audio": {
		"master": 0.8,
		"music": 0.7,
		"sfx": 0.8
	},
	"video": {
		"window_mode": 1, # 0 = Janela, 1 = Tela Cheia, 2 = Tela Cheia Exclusiva
		"resolution_idx": 3, # 1920x1080 (Full HD)
		"vsync": true
	}
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

var config: ConfigFile = ConfigFile.new()

func _ready() -> void:
	_ensure_audio_buses()
	load_settings()

func _ensure_audio_buses() -> void:
	# Garante que os barramentos 'Music' e 'SFX' existam
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func load_settings() -> void:
	var err: Error = config.load(SAVE_PATH)
	if err != OK:
		# Se não existir, aplica os padrões e salva
		apply_defaults()
		save_settings()
		return

	# Áudio
	set_bus_volume("Master", float(config.get_value("audio", "master", DEFAULTS.audio.master)))
	set_bus_volume("Music", float(config.get_value("audio", "music", DEFAULTS.audio.music)))
	set_bus_volume("SFX", float(config.get_value("audio", "sfx", DEFAULTS.audio.sfx)))

	# Vídeo
	var mode: int = int(config.get_value("video", "window_mode", DEFAULTS.video.window_mode))
	var res_idx: int = int(config.get_value("video", "resolution_idx", DEFAULTS.video.resolution_idx))
	var vsync: bool = bool(config.get_value("video", "vsync", DEFAULTS.video.vsync))

	set_resolution_index(res_idx)
	set_window_mode(mode)
	set_vsync(vsync)

	settings_changed.emit()

func save_settings() -> void:
	config.save(SAVE_PATH)
	settings_changed.emit()

func apply_defaults() -> void:
	set_bus_volume("Master", DEFAULTS.audio.master)
	set_bus_volume("Music", DEFAULTS.audio.music)
	set_bus_volume("SFX", DEFAULTS.audio.sfx)

	set_window_mode(DEFAULTS.video.window_mode)
	set_resolution_index(DEFAULTS.video.resolution_idx)
	set_vsync(DEFAULTS.video.vsync)

	save_settings()

# --- Funções de Áudio ---

func set_bus_volume(bus_name: String, linear_value: float) -> void:
	linear_value = clampf(linear_value, 0.0, 1.0)
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		if linear_value <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value))
	
	config.set_value("audio", bus_name.to_lower(), linear_value)
	volume_changed.emit(bus_name, linear_value)

func get_bus_volume(bus_name: String) -> float:
	return float(config.get_value("audio", bus_name.to_lower(), DEFAULTS.audio.get(bus_name.to_lower(), 0.8)))

# --- Funções de Vídeo ---

func set_window_mode(mode_idx: int) -> void:
	config.set_value("video", "window_mode", mode_idx)
	match mode_idx:
		0: # Janela
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Tela Cheia (Janela sem bordas / Fullscreen borderless)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Tela Cheia Exclusiva
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func get_window_mode() -> int:
	return int(config.get_value("video", "window_mode", DEFAULTS.video.window_mode))

func set_resolution_index(idx: int) -> void:
	if idx < 0 or idx >= RESOLUTIONS.size():
		idx = DEFAULTS.video.resolution_idx
	config.set_value("video", "resolution_idx", idx)

	# Apenas redimensiona se estiver no modo janela
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		var target_size: Vector2i = RESOLUTIONS[idx]
		DisplayServer.window_set_size(target_size)
		# Centraliza na tela
		var screen_idx: int = DisplayServer.window_get_current_screen()
		var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
		var center_pos: Vector2i = screen_rect.position + (screen_rect.size - target_size) / 2
		DisplayServer.window_set_position(center_pos)

func get_resolution_index() -> int:
	return int(config.get_value("video", "resolution_idx", DEFAULTS.video.resolution_idx))

func set_vsync(enabled: bool) -> void:
	config.set_value("video", "vsync", enabled)
	var mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func get_vsync() -> bool:
	return bool(config.get_value("video", "vsync", DEFAULTS.video.vsync))
