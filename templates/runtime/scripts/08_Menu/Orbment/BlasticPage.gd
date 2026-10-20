## 职责：展示闪翼回路链与背包晶石，处理槽位选择和回路交换。
##
## 调用方式：
##   通过FlashMenuPages创建并接入同一RuntimeState；输入和业务在本页，绘图由同组View和持久FlashPageSurface负责。
##   父FlashMenuScreen通过set_menu_progress(value)提供唯一0—8进退时钟；选择、文本和窗口节点复用，按各自区域裁切。
##
## 调用接口：
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func commit_choice() -> Dictionary
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func handle_key(key: int) -> void
##     用途：处理页面或控件的键盘输入。
##     参数 key（int；必填）：Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func candidate_allowed(id: int) -> bool
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
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
## 公开常量：CRYSTAL_NAME。
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
const View = preload("BlasticView.gd")
## Source 0215–0221 and 0202: the same circle/slot/crystal transaction as .45.
const Blastic = preload("../../01_Battle/Blastic.gd")
const Actions = preload("../../01_Battle/Actions.gd")
const Data = preload("../../00_Game/RuntimeData.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Presets = preload("../Item/ItemPresets.gd")
const CRYSTAL_NAME = "结晶回路"  # 0221 source category, separate from Game_Item wrappers.
signal back_requested
signal sound_requested(key: String)
var page = "flash_blastic"
var blastic_id = 0
var slot = 0
var choosing = false
var candidates: Array = []
var candidate_index = 0
var notice = ""
var value: Dictionary = {}
var preview_elements: Array = []
var preview_rows: Array = []
var crystal_description = ""
var echo_rows: Array = []
var _content: Control
var _description_label: RichTextLabel
var echo_index = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _content == null:
		_content = Surface.new()
		add_child(_content)
	if RuntimeState.party.is_empty():
		value = {}
		View.render(self, _content)
		return
	var actor = RuntimeState.actor(int(RuntimeState.party[0]))
	blastic_id = int(actor.project_fields.blastic) if actor.project_fields.blastic != null else 0
	value = Blastic.record(RuntimeState.custom_data, blastic_id)
	if value.is_empty():
		View.render(self, _content)
		return
	var width = value.pos[0].size()
	var total = width + value.pos[1].size()
	slot = clampi(slot, 0, maxi(0, total - 1))
	var circle = int(slot / width)
	var column = slot % width
	candidates = [0]
	var storage: Dictionary = RuntimeState.custom_data.gameplay().rules.storage
	for key in storage.crystal:
		var native = Presets.native_item(int(key), RuntimeState)
		# Source item110 has a valid Storage.crystal and crystal name but omitted
		# its @category. Repair only that verified empty record (no formula change).
		var crystal_category = (
			Presets.category(native) == CRYSTAL_NAME
			or (
				int(key) == 110
				and str(native.get("description", "")).is_empty()
				and str(native.get("name", "")) == "结晶回路(刃牙)"
			)
		)
		if (
			int(key) >= 71
			and RuntimeState.inventory_count("item", int(key)) > 0
			and crystal_category
		):
			candidates.append(int(key))
	candidates.sort_custom(
		func(a, b):
			return (
				a < b
				if a == 0 or b == 0
				else (
					int(storage.crystal[str(a)][0]) < int(storage.crystal[str(b)][0])
					if storage.crystal[str(a)][0] != storage.crystal[str(b)][0]
					else a < b
				)
			)
	)
	candidate_index = clampi(candidate_index, 0, maxi(candidates.size() - 1, 0))
	preview_elements = value.element[circle].duplicate()
	if choosing:
		var old: Variant = value.equip[circle][column]
		var next = int(candidates[candidate_index])
		for i in 5:
			if old != null:
				preview_elements[i] -= int(storage.crystal[str(old)][2][i])
			if next > 0:
				preview_elements[i] += int(storage.crystal[str(next)][2][i])
	preview_rows = value.element.duplicate(true)
	preview_rows[circle] = preview_elements.duplicate()
	var selected: Variant = (
		int(candidates[candidate_index]) if choosing else value.equip[circle][column]
	)
	crystal_description = (
		str(Presets.native_item(int(selected), RuntimeState).get("description", "")).get_slice(
			"@", 0
		)
		if selected != null and int(selected) > 0
		else ""
	)
	echo_rows = Blastic.echoes(RuntimeState.custom_data, preview_elements, choosing)
	View.render(self, _content)


func commit_choice() -> Dictionary:
	var result = Actions.exchange_crystal(
		RuntimeState, blastic_id, slot, int(candidates[candidate_index])
	)
	notice = "回路已更新。" if result.ok else str(result.get("message", ""))
	refresh()
	return result


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		if choosing:
			choosing = false
			refresh()
		else:
			back_requested.emit()
		return
	if value.is_empty():
		return
	if key in [KEY_UP, KEY_DOWN]:
		notice = ""
		sound_requested.emit("cursor_se")
		var step = -1 if key == KEY_UP else 1
		if choosing:
			candidate_index = posmod(candidate_index + step, candidates.size())
		else:
			slot = posmod(slot + step, value.pos[0].size() + value.pos[1].size())
		refresh()
	elif key in [KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN] and not echo_rows.is_empty():
		echo_index = posmod(
			echo_index + (-1 if key in [KEY_LEFT, KEY_PAGEUP] else 1), echo_rows.size()
		)
		View.render(self, _content)
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		if choosing:
			commit_choice()
		else:
			var width = value.pos[0].size()
			if value.lock[int(slot / width)][slot % width]:
				choosing = true
				candidate_index = 0
			else:
				notice = "该孔位尚未解锁。"
			refresh()


func candidate_allowed(id: int) -> bool:
	if value.is_empty():
		return false
	var width = value.pos[0].size()
	var circle = int(slot / width)
	var column = slot % width
	if not value.lock[circle][column]:
		return false
	if id == 0:
		return true
	var table: Dictionary = RuntimeState.custom_data.gameplay().rules.storage.crystal
	if not table.has(str(id)):
		return false
	var restriction = int(value.restrict[circle][column])
	if restriction != 0 and restriction != int(table[str(id)][0]):
		return false
	for chain in 2:
		for cell in value.equip[chain].size():
			if chain == circle and cell == column:
				continue
			var equipped: Variant = value.equip[chain][cell]
			if equipped != null and table[str(equipped)][1] == table[str(id)][1]:
				return false
	return true


func set_menu_progress(value: int) -> void:
	if _content != null:
		_content.set_progress(value)
