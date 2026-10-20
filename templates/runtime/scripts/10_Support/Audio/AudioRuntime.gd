## 职责：管理游戏 BGM、BGS、ME 和 SE 播放，协调音量、渐变及音频现场恢复。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/10_Support/Audio/AudioRuntime.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/10_Support/Audio/AudioRuntime.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   static func prepare_audio( kind: String, audio: Dictionary, position_seconds: Variant = 0.0 ) -> Dictionary
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 audio（Dictionary；必填）：音频名称、音量及音调等参数。
##     参数 position_seconds（Variant；默认值 0.0）：音频起播位置，单位为秒。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func play(kind: String, audio: Dictionary, position_seconds: Variant = 0.0) -> Dictionary
##     用途：开始播放指定音频、动画或演出。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 audio（Dictionary；必填）：音频名称、音量及音调等参数。
##     参数 position_seconds（Variant；默认值 0.0）：音频起播位置，单位为秒。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func stop(kind: String) -> void
##     用途：停止当前播放、动作或服务。
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func stop_all() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func fade_out(kind: String, seconds: Variant) -> Dictionary
##     参数 kind（String；必填）：消息、操作或对象的种类标识。
##     参数 seconds（Variant；必填）：以秒计的时长。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func memorize() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func restore_memory() -> Dictionary
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func persistent_snapshot() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func can_autoplay_after_restore(kind: String) -> bool
##     用途：判断读档后某频道能否按地图自动播放；已恢复的曲目和明确停止优先。
##     参数 kind（String；必填）：BGM或BGS。
##     返回：true表示该背景频道没有保存的播放记录或明确停止标志。
##
##   static func decode_persistent(value: Variant) -> Dictionary
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func restore_prepared(prepared: Dictionary) -> void
##     参数 prepared（Dictionary；必填）：已经过准备或校验的数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _exit_tree() -> void
##
## 接口说明结束。

extends Node
## Shared playback. Read-only streams, independent channels/SE, time-based fades.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const P = preload("res://runtime/scripts/00_Game/PictureState.gd")
var channels: Dictionary = {}
var definitions: Dictionary = {}
var fades: Dictionary = {}
var memory: Dictionary = {}
var _effects: Array[AudioStreamPlayer] = []
var _stopped: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


static func prepare_audio(
	kind: String, audio: Dictionary, position_seconds: Variant = 0.0
) -> Dictionary:
	if (
		kind not in ["BGM", "BGS", "ME", "SE"]
		or not audio.get("name", "") is String
		or not P.numeric(audio.get("volume", 100), 0, 100)
		or not P.numeric(audio.get("pitch", 100), 50, 150)
		or not P.numeric(position_seconds, 0, 10000000)
	):
		return P.fail("音频类别、音量、音调或位置无效。")
	var name_value := str(audio.get("name", ""))
	var definition := {
		"name": name_value,
		"volume": float(audio.get("volume", 100)),
		"pitch": float(audio.get("pitch", 100)),
		"position": float(position_seconds)
	}
	if name_value.is_empty():
		return {"ok": true, "definition": definition, "stream": null}
	if not P.valid_name(name_value):
		return P.fail("音频文件名无效。")
	var path: String = Data.asset_path("Audio/%s/%s" % [kind, name_value])
	if path.is_empty() or not ResourceLoader.exists(path):
		return P.fail("Audio/%s/%s 缺失或已隔离；未补取 RTP。" % [kind, name_value])
	var stream := load(path) as AudioStream
	if stream == null:
		return P.fail("音频解码失败：%s" % path)
	return {"ok": true, "definition": definition, "stream": stream}


func play(kind: String, audio: Dictionary, position_seconds: Variant = 0.0) -> Dictionary:
	var prepared := prepare_audio(kind, audio, position_seconds)
	if not prepared.ok:
		return prepared
	if (
		kind in ["BGM", "BGS"]
		and channels.has(kind)
		and definitions[kind].name == prepared.definition.name
		and float(position_seconds) == 0
	):
		# Replaying the same native background track updates settings, not its clock.
		channels[kind].volume_db = linear_to_db(maxf(0.00001, prepared.definition.volume / 100))
		channels[kind].pitch_scale = prepared.definition.pitch / 100
		definitions[kind] = {
			"name": prepared.definition.name,
			"volume": prepared.definition.volume,
			"pitch": prepared.definition.pitch
		}
		fades.erase(kind)
		return {"ok": true}
	_commit_play(kind, prepared)
	return {"ok": true}


func _commit_play(kind: String, prepared: Dictionary) -> void:
	var audio: Dictionary = prepared.definition
	if audio.name.is_empty():
		# Native empty SE is a no-op; 251 explicitly stops concurrent effects.
		if kind != "SE":
			stop(kind)
		return
	_stopped.erase(kind)
	var player := AudioStreamPlayer.new()
	if RuntimeState.flash_preferences != null:
		player.bus = (
			preload("../../00_Game/Preferences.gd").EFFECT_BUS
			if kind == "SE"
			else preload("../../00_Game/Preferences.gd").MUSIC_BUS
		)
		if kind == "BGM":
			RuntimeState.flash_preferences.unlock_music(audio.name)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = prepared.stream
	player.volume_db = linear_to_db(maxf(0.00001, audio.volume / 100))
	player.pitch_scale = audio.pitch / 100
	if kind == "SE":
		if _effects.size() >= 32:
			_release_effect(_effects[0])
		_effects.append(player)
		player.finished.connect(_release_effect.bind(player))
	else:
		_stop_channel(kind, false)
		channels[kind] = player
		definitions[kind] = {"name": audio.name, "volume": audio.volume, "pitch": audio.pitch}
		player.finished.connect(
			func() -> void:
				if channels.get(kind) != player:
					return
				if kind in ["BGM", "BGS"]:
					player.play()
				else:
					stop("ME")
		)
	add_child(player)
	player.play(audio.position)
	if kind == "ME" and channels.has("BGM"):
		channels.BGM.stream_paused = true
	if kind == "BGM" and channels.has("ME"):
		player.stream_paused = true


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
	if kind == "ME" and resume_bgm and channels.has("BGM"):
		channels.BGM.stream_paused = false


func stop(kind: String) -> void:
	if kind in ["BGM", "BGS"]:
		_stopped[kind] = true
	if kind == "SE":
		for player in _effects.duplicate():
			_release_effect(player)
	else:
		_stop_channel(kind)


func stop_all() -> void:
	for kind in ["ME", "BGM", "BGS", "SE"]:
		stop(kind)
	memory.clear()


func fade_out(kind: String, seconds: Variant) -> Dictionary:
	if kind not in ["BGM", "BGS", "ME"] or not P.numeric(seconds, 0, 3600):
		return P.fail("淡出类别/秒数无效。")
	if not channels.has(kind):
		return {"ok": true}
	if seconds == 0:
		stop(kind)
	else:
		fades[kind] = {
			"remaining": float(seconds), "volume": db_to_linear(channels[kind].volume_db)
		}
	return {"ok": true}


func memorize() -> Dictionary:
	memory = snapshot()
	return memory.duplicate(true)


func restore_memory() -> Dictionary:
	var prepared := {}
	# Decode every remembered stream before replacing either channel.
	for kind in ["BGM", "BGS"]:
		var audio: Variant = memory.get(kind, {"name": "", "position": 0.0})
		if not audio is Dictionary:
			return P.fail("记忆音频格式无效。")
		var result := prepare_audio(kind, audio, audio.get("position", 0.0))
		if not result.ok:
			return result
		prepared[kind] = result
	for kind in ["BGM", "BGS"]:
		_commit_play(kind, prepared[kind])
	return {"ok": true}


func persistent_snapshot() -> Dictionary:
	var progress := {}
	for kind in ["BGM", "BGS"]:
		if fades.has(kind):
			progress[kind] = fades[kind].duplicate()
	return {
		"playing": snapshot(),
		"memory": memory.duplicate(true),
		"fades": progress,
		"stopped": _stopped.duplicate()
	}


func can_autoplay_after_restore(kind: String) -> bool:
	return kind in ["BGM", "BGS"] and not channels.has(kind) and not _stopped.get(kind, false)


static func decode_persistent(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() not in [3, 4]:
		return P.fail("音频存档格式无效。")
	if value.size() == 4 and not value.has("stopped"):
		return P.fail("音频存档包含未知字段。")
	var stopped: Variant = value.get("stopped", {})
	if not stopped is Dictionary or stopped.size() > 2:
		return P.fail("音频停止状态无效。")
	for kind in stopped:
		if kind not in ["BGM", "BGS"] or not stopped[kind] is bool or not stopped[kind]:
			return P.fail("音频停止状态无效。")
		if value.get("playing") is Dictionary and value.playing.has(kind):
			return P.fail("音频不能同时播放和停止。")
	var prepared := {
		"ok": true, "playing": {}, "memory": {}, "fades": {}, "stopped": stopped.duplicate()
	}
	for field in ["playing", "memory", "fades"]:
		if not value.get(field) is Dictionary or value[field].size() > 2:
			return P.fail("音频存档频道无效。")
		for kind in value[field]:
			if kind not in ["BGM", "BGS"]:
				return P.fail("音频存档只能保存BGM/BGS。")
			var entry: Variant = value[field][kind]
			if not entry is Dictionary:
				return P.fail("音频存档条目无效。")
			if field == "fades":
				if (
					entry.size() != 2
					or not value.playing.has(kind)
					or not P.numeric(entry.get("remaining"), 0.00000001, 3600)
					or not P.numeric(entry.get("volume"), 0, 1)
				):
					return P.fail("音频淡出进度无效。")
				if not is_equal_approx(
					float(value.playing[kind].get("volume", -1)) / 100, entry.volume
				):
					return P.fail("音频音量与淡出进度不一致。")
				prepared.fades[kind] = entry.duplicate()
			else:
				if (
					entry.size() != 4
					or not entry.get("name") is String
					or entry.name.is_empty()
					or not entry.has("volume")
					or not entry.has("pitch")
					or not entry.has("position")
				):
					return P.fail("音频定义/位置无效。")
				var result := prepare_audio(kind, entry, entry.position)
				if not result.ok:
					return result
				prepared[field][kind] = result if field == "playing" else result.definition
	return prepared


func restore_prepared(prepared: Dictionary) -> void:
	stop_all()
	for kind in ["BGM", "BGS"]:
		if prepared.playing.has(kind):
			_commit_play(kind, prepared.playing[kind])
	memory = prepared.memory.duplicate(true)
	fades = prepared.fades.duplicate(true)
	_stopped = prepared.get("stopped", {}).duplicate()


func snapshot() -> Dictionary:
	var result := {}
	for kind in ["BGM", "BGS"]:
		if channels.has(kind):
			result[kind] = definitions[kind].duplicate()
			result[kind].volume = db_to_linear(channels[kind].volume_db) * 100
			result[kind].position = maxf(0, channels[kind].get_playback_position())
	return result


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	for kind in fades.keys():
		if not channels.has(kind):
			fades.erase(kind)
			continue
		var fade: Dictionary = fades[kind]
		fade.volume *= maxf(0, 1 - delta / fade.remaining)
		fade.remaining = maxf(0, fade.remaining - delta)
		channels[kind].volume_db = linear_to_db(maxf(0.00001, fade.volume))
		if fade.remaining <= 0.00000001:
			stop(kind)


func _exit_tree() -> void:
	stop_all()
