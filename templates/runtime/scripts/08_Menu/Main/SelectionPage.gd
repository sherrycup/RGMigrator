## 职责：提供闪翼列表选择页的公共展示、光标和确认取消流程。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/Main/SelectionPage.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func read_entries() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func activate() -> void
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func back() -> void
##     用途：从当前页面或操作返回。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：由持有方发出，通知对应状态或操作结果。
##   sound_requested(key: String)：由持有方发出，通知对应状态或操作结果。
##     key：查询或写入使用的键名。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
## 0117/0118 + 0254/0255: standalone floor/actor selection returns source vars.
const Data = preload("../../00_Game/RuntimeData.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Scripts = preload("../../10_Support/Scripting/ScriptRuntime.gd")
const Bitmap = preload("../../04_UI_Common/Bitmap.gd")
signal back_requested
signal sound_requested(key: String)
var page = "flash_selection"
var kind = "floor"
var index = 0
var entries: Array = []
var message = ""
var _content: Control
var _scroll_start = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	read_entries()
	resized.connect(refresh)
	refresh()


func read_entries() -> void:
	entries = []
	if kind == "actor":
		entries = RuntimeState.party.duplicate()
		return
	var floors: Variant = RuntimeState.variables.get("18")
	var chapter: Variant = RuntimeState.variables.get("3", 0)
	var list: Variant = null
	if chapter is int or chapter is float:
		if floors is Array and chapter >= 0 and chapter < floors.size():
			list = floors[int(chapter)]
		elif floors is Dictionary:
			list = floors.get("2:" + str(int(chapter)), floors.get(str(int(chapter))))
	if list is Array:
		for floor in list:
			if (floor is int or floor is float) and not entries.has(floor):
				entries.append(floor)
	index = maxi(0, entries.find(RuntimeState.variables.get("2", 0)))


func refresh() -> void:
	if _content == null:
		_content = Surface.new()
		add_child(_content)
	_content.begin()
	var header = _content.window("header", Rect2(0, 0, size.x, 64))
	header.line(
		Rect2(16, 16, size.x - 32, 32), "请选择您要操作的角色。" if kind == "actor" else "请选择你要到达的楼层。", 20
	)
	_content.window("panel", Rect2(0, 64, size.x, 416))
	var rows = _content.window("rows", Rect2(16, 80, size.x - 32, 384), Vector2.ZERO, "", false)
	var columns = 2 if kind == "actor" else 4
	var width = (size.x - 32) / columns
	_scroll_start = maxi(0, int(index / columns) - 9)
	for i in range(_scroll_start * columns, mini(entries.size(), (_scroll_start + 12) * columns)):
		var rect = Rect2((i % columns) * width, (int(i / columns) - _scroll_start) * 32, width, 32)
		var entry = entries[i]
		var actor = RuntimeState.actor(int(entry)) if kind == "actor" else null
		rows.line(
			Rect2(rect.position + Vector2(32, 0), rect.size - Vector2(32, 0)),
			actor.actor_name if actor != null else "第%s层" % entry,
			18
		)
		var pictures: Variant = RuntimeState.variables.get("94")
		var name = (
			str(pictures[int(entry) - 1])
			if (
				kind == "actor"
				and pictures is Array
				and int(entry) >= 1
				and int(entry) <= pictures.size()
			)
			else str(RuntimeState.variables.get("3", 0)) if kind == "floor" else ""
		)
		if not name.is_empty():
			rows.image(Cache.picture(name), Rect2(rect.position, Vector2(28, 28)))
	if not entries.is_empty():
		rows.select(
			Rect2(
				(index % columns) * width,
				(int(index / columns) - _scroll_start) * 32,
				width - 4,
				30
			),
			2
		)
	else:
		rows.line(Rect2(16, 16, 320, 32), "没有可选项目", 18)
	if not message.is_empty():
		var notice = _content.window("notice", Rect2(16, 496, size.x - 32, 64))
		notice.line(Rect2(16, 16, notice.size.x - 32, 32), message, 18)
	_content.finish()


func _return(value: Variant) -> void:
	var result = Scripts.call_transaction(
		RuntimeState,
		{"source": "0255.Scene_CP" if kind == "actor" else "0254.Scene_Flytofloor"},
		func(env):
			return env.index_set(
				{"__state_table": "variable"}, 12 if kind == "actor" else 13, value
			)
	)
	if not result.ok:
		message = str(result.get("message", ""))
		refresh()
		sound_requested.emit("buzzer_se")
		return
	back_requested.emit()


func activate() -> void:
	if entries.is_empty():
		sound_requested.emit("buzzer_se")
		return
	_return(int(entries[index]) - 1 if kind == "actor" else entries[index])


func back() -> void:
	_return(RuntimeState.custom_data.gameplay().role_ids()[0] if kind == "actor" else "stop")


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()
	elif key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and not entries.is_empty():
		index = posmod(
			(
				index
				+ {
					KEY_UP: -2 if kind == "actor" else -4,
					KEY_DOWN: 2 if kind == "actor" else 4,
					KEY_LEFT: -1,
					KEY_RIGHT: 1
				}[key]
			),
			entries.size()
		)
		var columns = 2 if kind == "actor" else 4
		if maxi(0, int(index / columns) - 9) != _scroll_start:
			refresh()
		else:
			_paint_selection()
		sound_requested.emit("cursor_se")


func _paint_selection() -> void:
	refresh()
