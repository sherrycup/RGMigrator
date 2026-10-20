## 职责：处理闪翼视频播放请求、界面归属和完成等待。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/10_Support/Utilities/MoviePlayer.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func resolve_path(filename: String) -> String
##     参数 filename（String；必填）：带扩展名的稳定脚本文件名。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func play( filename: String, wait: bool = true, allow_skip: bool = true, x: int = 0, y: int = 0, width: int = 640, height: int = 640 ) -> Dictionary
##     用途：开始播放指定音频、动画或演出。
##     参数 filename（String；必填）：带扩展名的稳定脚本文件名。
##     参数 wait（bool；默认值 true）：是否等待当前操作完成。
##     参数 allow_skip（bool；默认值 true）：是否允许用户跳过当前演出。
##     参数 x（int；默认值 0）：横向坐标。
##     参数 y（int；默认值 0）：纵向坐标。
##     参数 width（int；默认值 640）：区域或画布宽度。
##     参数 height（int；默认值 640）：区域或画布高度。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func stop() -> void
##     用途：停止当前播放、动作或服务。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func pause() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func resume() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func resize(x: int = 0, y: int = 0, width: int = 640, height: int = 640) -> bool
##     参数 x（int；默认值 0）：横向坐标。
##     参数 y（int；默认值 0）：纵向坐标。
##     参数 width（int；默认值 640）：区域或画布宽度。
##     参数 height（int；默认值 640）：区域或画布高度。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func playing() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func status(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 对外信号：
##   completed(request_id: int)：当前事件或操作正常完成。
##     request_id：用于匹配响应、取消和等待的请求编号。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _input(event: InputEvent) -> void
##     event：输入事件或当前游戏事件对象，类型见签名。
##
## 接口说明结束。

extends CanvasLayer
## Standard Godot replacement for source 0323 MCI. Supported codecs are engine
## resources; absent/unsupported videos fail explicitly before a request starts.
signal completed(request_id: int)
var player: VideoStreamPlayer
var skippable = true
var request_id = 0
var _serial = 0
var _results: Dictionary = {}


func _ready() -> void:
	layer = 80
	player = VideoStreamPlayer.new()
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.finished.connect(stop)
	add_child(player)
	player.hide()


func resolve_path(filename: String) -> String:
	var name = filename.replace("\\", "/").trim_prefix("res://")
	if name.contains("..") or name.contains(":") or name.begins_with("/"):
		return ""
	for candidate in [
		"res://legacy/extras/" + name, "res://legacy/extras/Movies/" + name, "res://Movies/" + name
	]:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func play(
	filename: String,
	wait: bool = true,
	allow_skip: bool = true,
	x: int = 0,
	y: int = 0,
	width: int = 640,
	height: int = 640
) -> Dictionary:
	if width < 1 or height < 1 or width > 8192 or height > 8192:
		return {"ok": false, "message": "视频显示区域无效。"}
	var path = resolve_path(filename)
	if path.is_empty():
		return {"ok": false, "message": "原视频素材缺失或路径不属于目标工程：" + filename}
	if path.get_extension().to_lower() != "ogv":
		return {"ok": false, "message": "标准版Godot视频需要Ogg Theora(.ogv)，原文件尚未转换：" + path}
	var stream: Resource = load(path)
	if not stream is VideoStream:
		return {"ok": false, "message": "视频资源无法解码：" + path}
	stop()
	_serial += 1
	request_id = _serial
	skippable = allow_skip
	player.stream = stream
	player.position = Vector2(x, y)
	player.size = Vector2(width, height)
	player.paused = false
	player.show()
	player.play()
	return {"ok": true, "request_id": request_id, "wait": wait}


func stop() -> void:
	if player != null:
		player.stop()
		player.hide()
		player.stream = null
	if request_id > 0:
		var id = request_id
		request_id = 0
		_results[id] = {"ok": true}
		completed.emit(id)
	while _results.size() > 128:
		_results.erase(_results.keys()[0])


func pause() -> bool:
	if request_id == 0:
		return false
	player.paused = true
	return true


func resume() -> bool:
	if request_id == 0:
		return false
	player.paused = false
	return true


func resize(x: int = 0, y: int = 0, width: int = 640, height: int = 640) -> bool:
	if request_id == 0 or width < 1 or height < 1:
		return false
	player.position = Vector2(x, y)
	player.size = Vector2(width, height)
	return true


func playing() -> bool:
	return request_id > 0 and player.is_playing() and not player.paused


func status(id: int) -> Dictionary:
	return (
		{"ok": true, "pending": true}
		if id == request_id
		else _results.get(id, {"ok": false, "message": "视频请求已失效。"})
	)


func _input(event: InputEvent) -> void:
	if (
		request_id > 0
		and skippable
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_ESCAPE, KEY_X, KEY_Z, KEY_ENTER, KEY_SPACE]
	):
		stop()
		get_viewport().set_input_as_handled()
