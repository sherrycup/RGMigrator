extends Node
## Shared playback. Read-only streams, independent channels/SE, time-based fades.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const P = preload("res://runtime/scripts/PictureState.gd")
var channels: Dictionary = {}
var definitions: Dictionary = {}
var fades: Dictionary = {}
var memory: Dictionary = {}
var _effects: Array[AudioStreamPlayer] = []
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func play(kind: String, audio: Dictionary, position_seconds: Variant = 0.0) -> Dictionary:
	if kind not in ["BGM", "BGS", "ME", "SE"] or not audio.get("name", "") is String or not P.numeric(audio.get("volume", 100), 0, 100) or not P.numeric(audio.get("pitch", 100), 50, 150) or not P.numeric(position_seconds, 0, 10000000): return P.fail("音频类别、音量、音调或位置无效。")
	var name_value := str(audio.get("name", ""))
	if name_value.is_empty():
		stop(kind)
		return {"ok": true}
	if not P.valid_name(name_value): return P.fail("音频文件名无效。")
	var path: String = Data.asset_path("Audio/%s/%s" % [kind, name_value])
	if path.is_empty() or not ResourceLoader.exists(path): return P.fail("Audio/%s/%s 缺失或已隔离；未补取 RTP。" % [kind, name_value])
	var stream: AudioStream = load(path)
	if stream == null: return P.fail("音频解码失败：%s" % path)
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.00001, float(audio.get("volume", 100)) / 100))
	player.pitch_scale = float(audio.get("pitch", 100)) / 100
	if kind == "SE":
		if _effects.size() >= 32: _release_effect(_effects[0])
		_effects.append(player)
		player.finished.connect(_release_effect.bind(player))
	else:
		_stop_channel(kind, false)
		channels[kind] = player
		definitions[kind] = {"name": name_value, "volume": float(audio.get("volume", 100)), "pitch": float(audio.get("pitch", 100))}
		player.finished.connect(func() -> void:
			if channels.get(kind) != player: return
			if kind in ["BGM", "BGS"]: player.play()
			else: stop("ME")
		)
	add_child(player)
	player.play(float(position_seconds))
	if kind == "ME" and channels.has("BGM"): channels.BGM.stream_paused = true
	if kind == "BGM" and channels.has("ME"): player.stream_paused = true
	return {"ok": true}

func _release_effect(player: AudioStreamPlayer) -> void:
	_effects.erase(player)
	if is_instance_valid(player):
		player.stop()
		player.stream = null
		player.queue_free()

func _stop_channel(kind: String, resume_bgm: bool = true) -> void:
	var player: AudioStreamPlayer = channels.get(kind)
	if player != null:
		player.stop()
		player.stream = null
		player.queue_free()
	channels.erase(kind)
	definitions.erase(kind)
	fades.erase(kind)
	if kind == "ME" and resume_bgm and channels.has("BGM"): channels.BGM.stream_paused = false

func stop(kind: String) -> void:
	if kind == "SE":
		for player in _effects.duplicate(): _release_effect(player)
	else: _stop_channel(kind)

func stop_all() -> void:
	for kind in ["ME", "BGM", "BGS", "SE"]: stop(kind)
	memory.clear()

func fade_out(kind: String, seconds: Variant) -> Dictionary:
	if kind not in ["BGM", "BGS", "ME"] or not P.numeric(seconds, 0, 3600): return P.fail("淡出类别/秒数无效。")
	if not channels.has(kind): return {"ok": true}
	if seconds == 0: stop(kind)
	else: fades[kind] = {"remaining": float(seconds), "volume": db_to_linear(channels[kind].volume_db)}
	return {"ok": true}

func memorize() -> Dictionary:
	memory = snapshot()
	return memory.duplicate(true)

func restore_memory() -> Dictionary:
	for kind in memory:
		var path: String = Data.asset_path("Audio/%s/%s" % [kind, memory[kind].name])
		if path.is_empty() or not ResourceLoader.exists(path): return P.fail("记忆音频缺失：%s" % path)
	for kind in ["BGM", "BGS"]:
		if memory.has(kind):
			var result := play(kind, memory[kind], memory[kind].position)
			if not result.ok: return result
		else: stop(kind)
	return {"ok": true}

func snapshot() -> Dictionary:
	var result := {}
	for kind in ["BGM", "BGS"]:
		if channels.has(kind):
			result[kind] = definitions[kind].duplicate()
			result[kind].volume = db_to_linear(channels[kind].volume_db) * 100
			result[kind].position = maxf(0, channels[kind].get_playback_position())
	return result

func _process(delta: float) -> void:
	for kind in fades.keys():
		if not channels.has(kind):
			fades.erase(kind)
			continue
		var fade: Dictionary = fades[kind]
		fade.volume *= maxf(0, 1 - delta / fade.remaining)
		fade.remaining = maxf(0, fade.remaining - delta)
		channels[kind].volume_db = linear_to_db(maxf(0.00001, fade.volume))
		if fade.remaining == 0: stop(kind)

func _exit_tree() -> void: stop_all()
