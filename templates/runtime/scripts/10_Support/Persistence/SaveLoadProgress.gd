## 职责：显示读档动态进度，后台预载只读游戏资源，在主线程分帧完整校验存档并管理场景切换暂停。
##
## 调用方式：
##   由标题或地图菜单创建并加入SceneTree根节点，随后await read_slot(slot,host)，返回完整校验结果后才由持有方安装。
##   成功切换场景后调用finish_after_scene，失败调用close；预载资源仅在ResourceLoader后台读取，不在线程执行游戏或安装角色。
##
## 调用接口：
##   func read_slot(slot: int, host: Node) -> Dictionary
##     用途：异步预载游戏资源并完整校验本槽和必要的备份；结果未通过前不修改正式状态。
##     参数 slot（int；必填）：存档编号，范围与SaveService.maximum_slots一致。
##     参数 host（Node；必填）：发起读取的标题或地图菜单节点，用于取消归属检查。
##     返回：包含ok、prepared、recovered、saved_at和path的结果字典，失败含message。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func finish_after_scene() -> void
##     用途：场景切换后保持遮罩至新地图加入，随后恢复运行并释放本进度控件。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func close(restore_pause: bool = true) -> void
##     用途：关闭进度并清理执行重置监听。
##     参数 restore_pause（bool；默认值 true）：true恢复进入前暂停状态；false恢复正常地图运行。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##   func _input(_event: InputEvent) -> void
##     _event：为保持原接口位置保留，本实现未读取此参数。
##
## 注意：不依赖档案缩略图缓存进行读取，每次均核验当前文件、来源指纹、对象图及角色/事件/资源。
## 接口说明结束。

extends CanvasLayer
const Saves = preload("SaveService.gd")
const Data = preload("../../00_Game/RuntimeData.gd")
var game_scene: PackedScene
var _label: Label
var _elapsed = 0.0
var _cancelled = false
var _previous_pause = false
var _deadline = 0
var _resources: Array[Resource] = []
var _host: WeakRef
var _phase = "正在读取存档"


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_pause = get_tree().paused
	get_tree().paused = true
	var shade = ColorRect.new()
	shade.color = Color(0, 0.025, 0.05, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label.position = Vector2(-160, -24)
	_label.size = Vector2(320, 48)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", preload("../../04_UI_Common/UIResources.gd").font())
	_label.add_theme_font_size_override("font_size", 22)
	shade.add_child(_label)
	_process(0)


func read_slot(slot: int, host: Node) -> Dictionary:
	_host = weakref(host)
	RuntimeState.execution_reset.connect(_cancel)
	# Draw the feedback before any decoding or resource preparation begins.
	if not await _pulse(true):
		return Saves.fail("读取已取消。")
	var paths: Array[String] = ["res://scenes/03_Map/Game.tscn"]
	if RuntimeState.custom_data.manifest.get("profile") == "flash":
		for registry in ["script_units", "custom_units"]:
			for unit in (
				Data.read_json("res://data/" + registry + ".json", {}).get("units", {}).values()
			):
				if unit.get("status") == "generated":
					var path: String = unit.get("generated_path", "")
					if path.begins_with("res://runtime/generated/") and not paths.has(path):
						paths.append(path)
	_phase = "正在准备游戏资源"
	var pending: Dictionary = {}
	for path in paths:
		var error = ResourceLoader.load_threaded_request(path)
		if (
			error != OK
			and (
				ResourceLoader.load_threaded_get_status(path)
				not in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]
			)
		):
			return Saves.fail("无法准备游戏资源：" + path)
		pending[path] = true
		if not await _pulse():
			return Saves.fail("读取已取消。")
	while not pending.is_empty():
		for path in pending.keys():
			var status = ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				return Saves.fail("无法载入游戏资源：" + path)
			var resource = ResourceLoader.load_threaded_get(path)
			_resources.append(resource)
			if resource is PackedScene:
				game_scene = resource
			pending.erase(path)
		if not await _pulse(true):
			return Saves.fail("读取已取消。")
	_phase = "正在读取存档"
	var result = await Saves.read_slot_cooperatively(slot, RuntimeState.custom_data, _pulse)
	if RuntimeState.execution_reset.is_connected(_cancel):
		RuntimeState.execution_reset.disconnect(_cancel)
	return result


func finish_after_scene() -> void:
	_host = null
	_phase = "正在进入游戏"
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	close(false)


func close(restore_pause: bool = true) -> void:
	if RuntimeState.execution_reset.is_connected(_cancel):
		RuntimeState.execution_reset.disconnect(_cancel)
	get_tree().paused = _previous_pause if restore_pause else false
	set_process_input(false)
	set_process(false)
	visible = false
	queue_free()


func _cancel() -> void:
	_cancelled = true


func _pulse(force: bool = false) -> bool:
	if _cancelled or not is_inside_tree() or is_queued_for_deletion():
		return false
	if (
		_host != null
		and (not is_instance_valid(_host.get_ref()) or not _host.get_ref().is_inside_tree())
	):
		close()
		return false
	if force or Time.get_ticks_usec() >= _deadline:
		await get_tree().process_frame
		_deadline = Time.get_ticks_usec() + 6000
	return not _cancelled and is_inside_tree() and not is_queued_for_deletion()


func _process(delta: float) -> void:
	_elapsed += maxf(0, delta)
	_label.text = _phase + ".".repeat(int(_elapsed * 5) % 4)


func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
