## 职责：展示闪翼物品列表、详情和目标选择，调用正式物品业务接口。
##
## 调用方式：
##   通过FlashMenuPages创建并接入同一RuntimeState；输入和业务在本页，绘图由同组View和持久FlashPageSurface负责。
##   父FlashMenuScreen通过set_menu_progress(value)提供唯一0—8进退时钟；选择、文本和窗口节点复用，按各自区域裁切。
##
## 调用接口：
##   func selected_id() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
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
##   func assign_preset() -> void
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
##   common_event_requested()：由持有方发出，通知对应状态或操作结果。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
const View = preload("ItemView.gd")
## Source 0177–0183/0202: owned RPG categories, recover targets and nine presets.
const Presets = preload("ItemPresets.gd")
const Actions = preload("../../01_Battle/Actions.gd")
const Service = preload("../../00_Game/InventoryService.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Data = preload("../../00_Game/RuntimeData.gd")
signal back_requested
signal sound_requested(key: String)
signal common_event_requested
var page = "flash_items"
var stage = "category"
var categories: Array = []
var category_index = 0
var item_ids: Array = []
var index = 0
var target_index = 0
var slot = 0
var active_item = 0
var notice = ""
var _content: Control
var _description: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Presets.normalize(RuntimeState)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func selected_id() -> int:
	return int(item_ids[index]) if not item_ids.is_empty() else 0


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _content == null:
		_content = Surface.new()
		add_child(_content)
	var groups: Dictionary = {}
	# Source category/item scans ascending RPG item IDs; weapon/armor branches empty.
	for id in Data.database("Items").size():
		if id <= 0 or RuntimeState.inventory_count("item", id) <= 0:
			continue
		var name = Presets.category(Presets.native_item(id, RuntimeState))
		if not groups.has(name):
			groups[name] = []
		groups[name].append(id)
	categories = groups.keys()
	category_index = clampi(category_index, 0, maxi(categories.size() - 1, 0))
	item_ids = groups.get(categories[category_index], []) if not categories.is_empty() else []
	index = clampi(index, 0, maxi(item_ids.size() - 1, 0))
	View.render(self, _content)
	_sync_item_bar()


func activate() -> void:
	if stage == "category":
		index = 0
		sound_requested.emit("decision_se")
		stage = "item"
		refresh()
		return
	if stage == "preset":
		assign_preset()
		return
	var id = active_item if stage == "target" else selected_id()
	if id <= 0:
		return
	var result: Dictionary = {}
	if stage == "target":
		if RuntimeState.party.is_empty():
			return
		result = Actions.recover_item(RuntimeState, id, int(RuntimeState.party[target_index]))
		if result.ok and RuntimeState.inventory_count("item", id) == 0:
			stage = "item"
			active_item = 0
	else:
		var reason = Service.item_reason(id)
		if not reason.is_empty():
			sound_requested.emit("buzzer_se")
			notice = reason
			refresh()
			return
		sound_requested.emit("decision_se")
		if int(Data.record("Items", id).get("occasion", 3)) == 0:
			active_item = id
			target_index = 0
			stage = "target"
			refresh()
			return
		result = Actions.request_tool(RuntimeState, id)
		if result.ok:
			common_event_requested.emit()
			return
	if not result.is_empty():
		notice = "物品已使用。" if result.ok else str(result.get("message", ""))
	refresh()


func assign_preset() -> void:
	var result = Presets.set_slot(RuntimeState, slot + 1, selected_id())
	sound_requested.emit("decision_se" if result.ok else "buzzer_se")
	notice = "物品预设已更新。" if result.ok else str(result.get("message", ""))
	refresh()


func handle_key(key: int) -> void:
	var game = RuntimeState.game()
	if stage == "preset" and key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and game != null:
		if not game._flash_hud.itembar_navigation_ready():
			return
	if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE, KEY_X, KEY_A]:
		notice = ""
	if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		sound_requested.emit("cursor_se")
	if key in [KEY_ESCAPE, KEY_X]:
		if stage == "category":
			back_requested.emit()
		else:
			if stage != "target":
				sound_requested.emit("cancel_se")
			stage = "item" if stage in ["preset", "target"] else "category"
			active_item = 0
			refresh()
	elif key == KEY_Q and stage == "preset":
		var result = Presets.set_slot(RuntimeState, slot + 1, 0)
		notice = "物品预设已置空。" if result.ok else str(result.get("message", ""))
		refresh()
	elif key == KEY_A and stage == "item" and selected_id() > 0:
		stage = "preset"
		slot = 0
		refresh()
	elif key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var step = -1 if key in [KEY_UP, KEY_LEFT] else 1
		if stage == "category" and not categories.is_empty():
			var next = posmod(category_index + step, categories.size())
			if next != category_index:
				category_index = next
				index = 0
				refresh()
			return
		elif stage == "item" and not item_ids.is_empty():
			index = posmod(index + step, item_ids.size())
		elif stage == "target" and not RuntimeState.party.is_empty():
			target_index = posmod(target_index + step, RuntimeState.party.size())
		elif stage == "preset":
			slot = posmod(slot + step, 9)
		_paint_selection()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()


func _paint_selection() -> void:
	View.render(self, _content)
	_sync_item_bar()


func _sync_item_bar() -> void:
	var game = RuntimeState.game()
	if game != null and game.get("_flash_hud") != null:
		game._flash_hud.set_itembar_selection(slot if stage == "preset" else -1)


func set_menu_progress(value: int) -> void:
	if _content != null:
		_content.set_progress(value)
