## 职责：管理编辑器专用音频试听节点及参数，隔离游戏音频和共享资源。
##
## 调用方式：
##   实例接口：先用 preload("res://addons/rgm_editor/05_Assets/Editor_AudioPreview.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func play(documents: RefCounted, category: String, audio: Dictionary, replace: bool = true) -> bool
##     用途：开始播放指定音频、动画或演出。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 category（String；必填）：数据库、素材或界面的分类名称。
##     参数 audio（Dictionary；必填）：音频名称、音量及音调等参数。
##     参数 replace（bool；默认值 true）：是否替换已有内容。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func set_parameters(volume: float, pitch: float) -> void
##     参数 volume（float；必填）：音频音量参数。
##     参数 pitch（float；必填）：音频音调参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func stop() -> void
##     用途：停止当前播放、动作或服务。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _exit_tree() -> void
##   func _process(_delta: float) -> void
##     _delta：为保持原接口位置保留，本实现未读取此参数。
##
## 接口说明结束。

@tool
extends Node
## Editor-owned audio; never touches RuntimeState or shared stream settings.
var _players: Array[AudioStreamPlayer] = []
var _error = ""


func play(documents: RefCounted, category: String, audio: Dictionary, replace: bool = true) -> bool:
	if replace:
		stop()
	_error = ""
	if str(audio.get("name", "")).is_empty():
		return true
	var stream: AudioStream = documents.asset_audio(category, str(audio.name))
	if stream == null:
		_error = "无法试听：Audio/%s/%s 缺失、未导入或格式不支持。" % [category, audio.name]
		return false
	# Imported resources can loop; preview owns a copy and always finishes once.
	stream = stream.duplicate()
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	if _players.size() >= 32:
		_release(_players[0])
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = linear_to_db(maxf(0.00001, float(audio.get("volume", 100)) / 100))
	player.pitch_scale = maxf(0.01, float(audio.get("pitch", 100)) / 100)
	add_child(player)
	_players.append(player)
	player.finished.connect(_release.bind(player))
	player.play()
	return true


func set_parameters(volume: float, pitch: float) -> void:
	for player in _players:
		player.volume_db = linear_to_db(maxf(0.00001, volume / 100))
		player.pitch_scale = maxf(0.01, pitch / 100)


func stop() -> void:
	for player in _players.duplicate():
		_release(player)


func _release(player: AudioStreamPlayer) -> void:
	_players.erase(player)
	if is_instance_valid(player):
		player.stop()
		player.stream = null
		player.queue_free()


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if not _players.is_empty() and not get_window().visible:
		stop()
