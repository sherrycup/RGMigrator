extends CanvasLayer
## Standard Godot replacement for source 0323 MCI. Supported codecs are engine
## resources; absent/unsupported videos fail explicitly before a request starts.
signal completed(request_id: int)
var player: VideoStreamPlayer
var skippable=true
var request_id=0
var _serial=0
var _results: Dictionary={}

func _ready() -> void:
	layer=80; player=VideoStreamPlayer.new(); player.expand=true; player.mouse_filter=Control.MOUSE_FILTER_IGNORE; player.finished.connect(stop); add_child(player)
	player.hide()
func resolve_path(filename: String) -> String:
	var name=filename.replace("\\","/").trim_prefix("res://")
	if name.contains("..") or name.contains(":") or name.begins_with("/"): return ""
	for candidate in ["res://legacy/extras/"+name,"res://legacy/extras/Movies/"+name,"res://Movies/"+name]:
		if FileAccess.file_exists(candidate): return candidate
	return ""
func play(filename: String,wait: bool=true,allow_skip: bool=true,x: int=0,y: int=0,width: int=640,height: int=640) -> Dictionary:
	if width<1 or height<1 or width>8192 or height>8192: return {"ok":false,"message":"视频显示区域无效。"}
	var path=resolve_path(filename)
	if path.is_empty(): return {"ok":false,"message":"原视频素材缺失或路径不属于目标工程："+filename}
	if path.get_extension().to_lower()!="ogv": return {"ok":false,"message":"标准版Godot视频需要Ogg Theora(.ogv)，原文件尚未转换："+path}
	var stream: Resource=load(path)
	if not stream is VideoStream: return {"ok":false,"message":"视频资源无法解码："+path}
	stop(); _serial+=1; request_id=_serial; skippable=allow_skip
	player.stream=stream; player.position=Vector2(x,y); player.size=Vector2(width,height); player.paused=false; player.show(); player.play()
	return {"ok":true,"request_id":request_id,"wait":wait}
func stop() -> void:
	if player!=null: player.stop(); player.hide(); player.stream=null
	if request_id>0:
		var id=request_id; request_id=0; _results[id]={"ok":true}; completed.emit(id)
	while _results.size()>128: _results.erase(_results.keys()[0])
func pause() -> bool:
	if request_id==0: return false
	player.paused=true; return true
func resume() -> bool:
	if request_id==0: return false
	player.paused=false; return true
func resize(x: int=0,y: int=0,width: int=640,height: int=640) -> bool:
	if request_id==0 or width<1 or height<1: return false
	player.position=Vector2(x,y); player.size=Vector2(width,height); return true
func playing() -> bool: return request_id>0 and player.is_playing() and not player.paused
func status(id: int) -> Dictionary:
	return {"ok":true,"pending":true} if id==request_id else _results.get(id,{"ok":false,"message":"视频请求已失效。"})
func _input(event: InputEvent) -> void:
	if request_id>0 and skippable and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_X,KEY_Z,KEY_ENTER,KEY_SPACE]: stop(); get_viewport().set_input_as_handled()
