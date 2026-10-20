## 职责：展示闪翼笔记条目、分类及内容，处理阅读和返回。
##
## 调用方式：
##   通过FlashMenuPages创建并接入同一RuntimeState；输入和业务在本页，绘图由同组View和持久FlashPageSurface负责。
##   父FlashMenuScreen通过set_menu_progress(value)提供唯一0—8进退时钟；选择、文本和窗口节点复用，按各自区域裁切。
##
## 调用接口：
##   func enabled(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_menu_progress(value: int) -> void
##     用途：接收父菜单进退，不重复推进位移或透明度。
##     参数 value（int；必填）：父菜单给出的0—8逻辑帧进退进度。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 对外信号：
##   back_requested()：由持有方发出，通知对应状态或操作结果。
##   sound_requested(key: String)：请求原系统光标/确认/取消音效；由父菜单统一播放，不创建第二个音频现场。
##     key：查询或写入使用的键名。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 公开常量：CATEGORIES。
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
const View = preload("NoteView.gd")
## Source 0224–0227 and 0202: original category lock, entries and description.
const Data = preload("../../00_Game/RuntimeData.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Scripts = preload("../../10_Support/Scripting/ScriptRuntime.gd")
const CATEGORIES = ["说明", "主线", "随笔", "战斗", "书籍"]
signal back_requested
signal sound_requested(key: String)
var page = "flash_notes"
var category = 0
var index = 0
var selecting = false
var entries: Array = []
var description = ""
var _content: Control
var description_scroll = 0.0
var _text: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lock_id = int(RuntimeState.custom_data.gameplay().rules.constants.get("NOTECATE_LOCK", 10))
	if not RuntimeState.variables.get(str(lock_id)) is Array:
		Scripts.call_transaction(
			RuntimeState,
			{"source": "0225.initialize.NOTECATE_LOCK"},
			func(env): return env.index_set({"__state_table": "variable"}, lock_id, [0, 0, 0, 0, 0])
		)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func enabled(id: int) -> bool:
	var locks: Variant = RuntimeState.variables.get(
		str(RuntimeState.custom_data.gameplay().rules.constants.get("NOTECATE_LOCK", 10))
	)
	return locks is Array and id >= 0 and id < locks.size() and locks[id] == 1


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _content == null:
		_content = Surface.new()
		add_child(_content)
	var storage: Dictionary = RuntimeState.custom_data.gameplay().rules.storage
	entries = storage.get("note_name", {}).get(str(category), []) if enabled(category) else []
	index = clampi(index, 0, maxi(0, entries.size() - 1))
	var texts: Variant = storage.get("note_desc", {}).get(str(category))
	description = (
		str(texts.get(str(index), "")) if texts is Dictionary and enabled(category) else ""
	)
	View.render(self, _content)


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		if selecting:
			index = 0
			description_scroll = 0.0
			selecting = false
			refresh()
		else:
			back_requested.emit()
	elif not selecting and key in [KEY_LEFT, KEY_RIGHT]:
		sound_requested.emit("cursor_se")
		category = posmod(category + (-1 if key == KEY_LEFT else 1), 5)
		index = 0
		refresh()
	elif not selecting and key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE] and enabled(category):
		selecting = true
		refresh()
	elif selecting and key in [KEY_UP, KEY_DOWN] and not entries.is_empty():
		sound_requested.emit("cursor_se")
		index = posmod(index + (-1 if key == KEY_UP else 1), entries.size())
		description_scroll = 0.0
		var texts: Variant = (
			RuntimeState
			. custom_data
			. gameplay()
			. rules
			. storage
			. get("note_desc", {})
			. get(str(category))
		)
		description = str(texts.get(str(index), "")) if texts is Dictionary else ""
		View.render(self, _content)
	elif key in [KEY_PAGEUP, KEY_PAGEDOWN] and _text != null:
		description_scroll = maxf(0, description_scroll + (-320 if key == KEY_PAGEUP else 320))
		View.render(self, _content)


func set_menu_progress(value: int) -> void:
	if _content != null:
		_content.set_progress(value)
