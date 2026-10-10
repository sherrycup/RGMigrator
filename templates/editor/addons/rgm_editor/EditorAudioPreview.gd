@tool
extends Node
## Editor-owned audio; never touches RuntimeState or shared stream settings.
var _players: Array[AudioStreamPlayer]=[]
var _error=""

func play(documents: RefCounted, category: String, audio: Dictionary, replace: bool = true) -> bool:
	if replace: stop()
	_error=""
	if str(audio.get("name","")).is_empty(): return true
	var stream: AudioStream=documents.asset_audio(category,str(audio.name))
	if stream==null: _error="无法试听：Audio/%s/%s 缺失、未导入或格式不支持。" % [category,audio.name]; return false
	# Imported resources can loop; preview owns a copy and always finishes once.
	stream=stream.duplicate()
	if stream is AudioStreamWAV: stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3: stream.loop=false
	if _players.size()>=32: _release(_players[0])
	var player=AudioStreamPlayer.new(); player.stream=stream; player.process_mode=Node.PROCESS_MODE_ALWAYS
	player.volume_db=linear_to_db(maxf(0.00001,float(audio.get("volume",100))/100)); player.pitch_scale=maxf(0.01,float(audio.get("pitch",100))/100)
	add_child(player); _players.append(player); player.finished.connect(_release.bind(player)); player.play(); return true

func set_parameters(volume: float, pitch: float) -> void:
	for player in _players:
		player.volume_db=linear_to_db(maxf(0.00001,volume/100)); player.pitch_scale=maxf(0.01,pitch/100)

func stop() -> void:
	for player in _players.duplicate(): _release(player)

func _release(player: AudioStreamPlayer) -> void:
	_players.erase(player)
	if is_instance_valid(player): player.stop(); player.stream=null; player.queue_free()

func _exit_tree() -> void:
	stop()

func _process(_delta: float) -> void:
	if not _players.is_empty() and not get_window().visible: stop()
