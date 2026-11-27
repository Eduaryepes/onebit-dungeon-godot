class_name SfxManager
extends Node

## 100% procedural 8-bit chiptune SFX & ambient loop generator.
## Synthesizes crisp retro AudioStreamWAV clips in memory so the repo
## remains text-based and works out-of-the-box on Android, desktop, and headless CI.

const MIX_RATE: int = 22050
const POOL_SIZE: int = 8

var muted: bool = false
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	_build_all_sfx()
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -17.0
	_bgm_player.stream = _make_dungeon_bgm()
	add_child(_bgm_player)
	if not muted:
		_bgm_player.play()


func _exit_tree() -> void:
	if _bgm_player != null:
		_bgm_player.stop()
		_bgm_player.stream = null
	for p in _pool:
		p.stop()
		p.stream = null
	_streams.clear()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		if _bgm_player != null:
			_bgm_player.stop()
		for p in _pool:
			p.stop()
	else:
		if _bgm_player != null and not _bgm_player.playing:
			_bgm_player.play()
		play("ui_click")
	return muted


func play(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = -4.0) -> void:
	if muted:
		return
	if not _streams.has(sfx_name):
		return
	if _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	player.stream = _streams[sfx_name]
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.2)
	player.volume_db = volume_db
	player.play()


func _build_all_sfx() -> void:
	_streams["step"] = _make_sweep(0.045, 165.0, 95.0, "triangle", 0.24)
	_streams["wall_bump"] = _make_sweep(0.085, 115.0, 52.0, "square", 0.26)
	_streams["ui_click"] = _make_sweep(0.04, 620.0, 880.0, "square", 0.18)

	# Weapons
	_streams["attack_sword"] = _make_slash(0.11, 520.0, 170.0, 0.35, 0.32)
	_streams["attack_dagger"] = _make_notes([880.0, 1180.0], 0.038, "square", 0.28)
	_streams["attack_spear"] = _make_slash(0.13, 300.0, 920.0, 0.22, 0.30)
	_streams["attack_axe"] = _make_slash(0.18, 220.0, 68.0, 0.45, 0.42)
	_streams["attack_staff"] = _make_fm_zap(0.19, 760.0, 260.0, 32.0, 0.34)

	# Combat impacts
	_streams["hit_enemy"] = _make_noise_hit(0.095, 240.0, 90.0, 0.38)
	_streams["crit"] = _make_notes([659.25, 987.77, 1318.5], 0.055, "square", 0.38)
	_streams["enemy_die"] = _make_notes([440.0, 349.23, 261.63, 174.61], 0.055, "square", 0.34)
	_streams["boss_die"] = _make_notes(
		[220.0, 277.18, 329.63, 440.0, 554.37, 659.25, 880.0],
		0.085,
		"square",
		0.42
	)
	_streams["player_hurt"] = _make_sweep(0.19, 210.0, 65.0, "saw", 0.42)

	# Pickups & progression
	_streams["pickup_coin"] = _make_notes([987.77, 1318.51], 0.065, "square", 0.28)
	_streams["pickup_potion"] = _make_notes([440.0, 587.33, 783.99], 0.06, "triangle", 0.34)
	_streams["pickup_weapon"] = _make_notes([392.0, 523.25, 659.25, 783.99], 0.07, "square", 0.34)
	_streams["pickup_key"] = _make_notes([587.33, 783.99, 987.77, 1174.66], 0.075, "square", 0.35)
	_streams["heal"] = _make_notes([392.0, 493.88, 587.33, 783.99], 0.065, "triangle", 0.36)
	_streams["weapon_swap"] = _make_notes([330.0, 523.25], 0.04, "square", 0.22)
	_streams["level_clear"] = _make_notes(
		[523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5],
		0.09,
		"square",
		0.36
	)
	_streams["game_over"] = _make_notes(
		[392.0, 349.23, 329.63, 261.63, 196.0],
		0.14,
		"triangle",
		0.38
	)


func _make_stream_from_samples(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


func _osc(phase: float, wave: String) -> float:
	var p: float = fposmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"pulse":
			return 1.0 if p < 0.25 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
		_:
			return sin(p * TAU)


func _make_sweep(duration: float, f_start: float, f_end: float, wave: String, gain: float) -> AudioStreamWAV:
	var n: int = maxi(1, int(duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(f_start, f_end, t)
		phase += freq / float(MIX_RATE)
		var env: float = (1.0 - t) * (1.0 - t)
		samples[i] = _osc(phase, wave) * env * gain
	return _make_stream_from_samples(samples)


func _make_slash(duration: float, f_start: float, f_end: float, noise_mix: float, gain: float) -> AudioStreamWAV:
	var n: int = maxi(1, int(duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	var lfsr: int = 0x5A31
	for i in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(f_start, f_end, t)
		phase += freq / float(MIX_RATE)
		if i % 3 == 0:
			var bit: int = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1
			lfsr = (lfsr >> 1) | (bit << 15)
		var noise: float = 1.0 if (lfsr & 1) == 1 else -1.0
		var tone: float = _osc(phase, "pulse")
		var env: float = sin(minf(1.0, t * 5.0) * PI * 0.5) * (1.0 - t)
		samples[i] = lerpf(tone, noise, noise_mix) * env * gain
	return _make_stream_from_samples(samples)


func _make_noise_hit(duration: float, f_start: float, f_end: float, gain: float) -> AudioStreamWAV:
	var n: int = maxi(1, int(duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	var lfsr: int = 0xACE1
	for i in range(n):
		var t: float = float(i) / float(n)
		var freq: float = lerpf(f_start, f_end, t)
		phase += freq / float(MIX_RATE)
		if i % 2 == 0:
			var bit: int = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1
			lfsr = (lfsr >> 1) | (bit << 15)
		var noise: float = 1.0 if (lfsr & 1) == 1 else -1.0
		var punch: float = _osc(phase, "square")
		var env: float = pow(1.0 - t, 1.7)
		samples[i] = (punch * 0.65 + noise * 0.35) * env * gain
	return _make_stream_from_samples(samples)


func _make_fm_zap(duration: float, f_start: float, f_end: float, mod_hz: float, gain: float) -> AudioStreamWAV:
	var n: int = maxi(1, int(duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(MIX_RATE)
		var freq: float = lerpf(f_start, f_end, t) + sin(sec * TAU * mod_hz) * 140.0
		phase += maxf(40.0, freq) / float(MIX_RATE)
		var env: float = (1.0 - t)
		samples[i] = _osc(phase, "pulse") * env * gain
	return _make_stream_from_samples(samples)


func _make_notes(freqs: Array, note_dur: float, wave: String, gain: float) -> AudioStreamWAV:
	var per_note: int = maxi(1, int(note_dur * MIX_RATE))
	var total: int = per_note * freqs.size()
	var samples := PackedFloat32Array()
	samples.resize(total)
	var phase: float = 0.0
	for idx in range(freqs.size()):
		var freq: float = float(freqs[idx])
		var base: int = idx * per_note
		for i in range(per_note):
			var t: float = float(i) / float(per_note)
			phase += freq / float(MIX_RATE)
			var attack: float = minf(1.0, t * 18.0)
			var release: float = 1.0 - t * 0.72
			samples[base + i] = _osc(phase, wave) * attack * release * gain
	return _make_stream_from_samples(samples)


func _make_dungeon_bgm() -> AudioStreamWAV:
	# Minimalist dark 8-bit chiptune loop (D minor pentatonic arpeggio + bass pulse)
	var step_dur: float = 0.20
	var bass_notes: Array[float] = [
		73.42, 73.42, 87.31, 87.31,
		98.00, 98.00, 82.41, 65.41,
		73.42, 73.42, 110.00, 110.00,
		98.00, 87.31, 82.41, 73.42,
	]
	var arp_notes: Array[float] = [
		293.66, 349.23, 440.00, 349.23,
		261.63, 349.23, 392.00, 329.63,
		293.66, 440.00, 523.25, 440.00,
		392.00, 349.23, 329.63, 293.66,
	]
	var per_step: int = int(step_dur * MIX_RATE)
	var total: int = per_step * bass_notes.size()
	var samples := PackedFloat32Array()
	samples.resize(total)
	var bass_phase: float = 0.0
	var arp_phase: float = 0.0

	for s in range(bass_notes.size()):
		var bf: float = bass_notes[s]
		var af: float = arp_notes[s]
		var base: int = s * per_step
		for i in range(per_step):
			var t: float = float(i) / float(per_step)
			bass_phase += bf / float(MIX_RATE)
			arp_phase += af / float(MIX_RATE)
			var bass_env: float = (1.0 - t * 0.65)
			var arp_env: float = pow(1.0 - t, 1.8)
			var v: float = _osc(bass_phase, "triangle") * bass_env * 0.24
			v += _osc(arp_phase, "pulse") * arp_env * 0.12
			samples[base + i] = v

	return _make_stream_from_samples(samples, true)
