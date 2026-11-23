extends Node

# SoundEffects.gd
# Gerador e reprodutor de efeitos sonoros procedurais para UI e ferramentas
# Não requer arquivos de áudio externos.

var _player_pool: Array[AudioStreamPlayer] = []
var _pool_size: int = 6
var _current_player_idx: int = 0

var hover_sound: AudioStreamWAV
var click_sound: AudioStreamWAV
var paint_sound: AudioStreamWAV
var sculpt_sound: AudioStreamWAV
var meteor_sound: AudioStreamWAV
var thunder_sound: AudioStreamWAV
var rain_sound: AudioStreamWAV
var freeze_sound: AudioStreamWAV
var spawn_sound: AudioStreamWAV

func _ready() -> void:
	_init_audio_pool()
	_generate_audio_streams()

func _init_audio_pool() -> void:
	_pool_size = 10
	for i in range(_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_player_pool.append(player)

func _get_free_player() -> AudioStreamPlayer:
	_current_player_idx = (_current_player_idx + 1) % _pool_size
	return _player_pool[_current_player_idx]

func _generate_audio_streams() -> void:
	hover_sound = _create_chirp(880.0, 1100.0, 0.035, 0.15)
	click_sound = _create_chirp(520.0, 780.0, 0.06, 0.25)
	paint_sound = _create_chirp(440.0, 660.0, 0.05, 0.2)
	sculpt_sound = _create_chirp(180.0, 260.0, 0.08, 0.3)
	meteor_sound = _create_explosion_sound(0.4, 0.5)
	thunder_sound = _create_thunder_sound(0.3, 0.45)
	rain_sound = _create_chirp(1200.0, 800.0, 0.04, 0.18)
	freeze_sound = _create_chirp(900.0, 1600.0, 0.12, 0.22)
	spawn_sound = _create_chirp(300.0, 750.0, 0.09, 0.28)

func _create_explosion_sound(duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var total_frames := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_frames * 2)

	var phase := 0.0
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := pow(1.0 - t, 2.0)
		var freq := lerpf(140.0, 45.0, t)
		phase += TAU * freq / float(mix_rate)
		# Mistura seno grave com ruído
		var noise := randf_range(-0.5, 0.5)
		var sample_val := (sin(phase) * 0.6 + noise * 0.4) * env * volume
		var val_16 := int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		var idx := i * 2
		data[idx] = val_16 & 0xFF
		data[idx + 1] = (val_16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _create_thunder_sound(duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var total_frames := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_frames * 2)

	var phase := 0.0
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := pow(1.0 - t, 1.5)
		var crackle := randf_range(-0.8, 0.8) if t < 0.2 else randf_range(-0.3, 0.3)
		var freq := lerpf(280.0, 60.0, t)
		phase += TAU * freq / float(mix_rate)
		var sample_val := (sin(phase) * 0.4 + crackle * 0.6) * env * volume
		var val_16 := int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		var idx := i * 2
		data[idx] = val_16 & 0xFF
		data[idx + 1] = (val_16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func _create_chirp(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var total_frames := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(total_frames * 2)

	var phase := 0.0
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		# Envoltória suave (fade out)
		var env := 1.0 - t
		var current_freq := lerpf(freq_start, freq_end, t)
		phase += TAU * current_freq / float(mix_rate)

		var sample_val := sin(phase) * env * volume
		var val_16 := int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		var idx := i * 2
		data[idx] = val_16 & 0xFF
		data[idx + 1] = (val_16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func play_hover() -> void:
	if hover_sound:
		var p := _get_free_player()
		p.stream = hover_sound
		p.pitch_scale = randf_range(0.98, 1.05)
		p.play()

func play_click() -> void:
	if click_sound:
		var p := _get_free_player()
		p.stream = click_sound
		p.pitch_scale = randf_range(0.95, 1.05)
		p.play()

func play_paint() -> void:
	if paint_sound:
		var p := _get_free_player()
		p.stream = paint_sound
		p.pitch_scale = randf_range(0.9, 1.15)
		p.play()

func play_sculpt() -> void:
	if sculpt_sound:
		var p := _get_free_player()
		p.stream = sculpt_sound
		p.pitch_scale = randf_range(0.85, 1.1)
		p.play()

func play_meteor() -> void:
	if meteor_sound:
		var p := _get_free_player()
		p.stream = meteor_sound
		p.pitch_scale = randf_range(0.9, 1.1)
		p.play()

func play_thunder() -> void:
	if thunder_sound:
		var p := _get_free_player()
		p.stream = thunder_sound
		p.pitch_scale = randf_range(0.95, 1.15)
		p.play()

func play_rain() -> void:
	if rain_sound:
		var p := _get_free_player()
		p.stream = rain_sound
		p.pitch_scale = randf_range(0.85, 1.25)
		p.play()

func play_freeze() -> void:
	if freeze_sound:
		var p := _get_free_player()
		p.stream = freeze_sound
		p.pitch_scale = randf_range(0.95, 1.1)
		p.play()

func play_spawn() -> void:
	if spawn_sound:
		var p := _get_free_player()
		p.stream = spawn_sound
		p.pitch_scale = randf_range(0.9, 1.2)
		p.play()
