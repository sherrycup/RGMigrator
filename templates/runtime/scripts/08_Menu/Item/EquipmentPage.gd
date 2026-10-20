## 职责：展示闪翼装备槽与候选装备，执行穿戴卸下并刷新角色属性。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/08_Menu/Item/EquipmentPage.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func candidate_rows() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   func preview_equipment(id: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func activate() -> Dictionary
##     用途：确认当前选择并执行对应操作。
##     参数：无。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
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
## 公开常量：SLOT_NAMES、DATABASES。
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
const View = preload("EquipmentView.gd")
## 0258 page uses the final source Game_Actor six-slot equip implementation;
## source 0123's obsolete five RGSS getters are adapted to this same array.
const Data = preload("../../00_Game/RuntimeData.gd")
const Catalog = preload("../../00_Game/ObjectCatalog.gd")
const Actions = preload("../../01_Battle/Actions.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Bitmap = preload("../../04_UI_Common/Bitmap.gd")
const SLOT_NAMES = ["主手", "副手", "防具一", "防具二", "饰品一", "饰品二"]
const DATABASES = ["Weapons", "Deputies", "Armors", "Armors", "Ornaments", "Ornaments"]
signal back_requested
signal sound_requested(key: String)
var page = "flash_equipment"
var actor_id = 0
var slot = 0
var index = 0
var choosing = false
var candidates: Array = []
var preview: Dictionary = {}
var message = ""
var _content: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func candidate_rows() -> Array:
	var result: Array = []
	var actor = RuntimeState.actor(actor_id)
	var database: String = DATABASES[slot]
	var inventory_kind = (
		"weapon" if database == "Weapons" else "armor" if database == "Armors" else "ornament"
	)
	if database != "Deputies":
		for entry in RuntimeState.inventory_entries():
			if entry.kind != inventory_kind or entry.count <= 0:
				continue
			var classes: Variant = Catalog.value(
				RuntimeState.custom_data, database, int(entry.id), "class_set"
			)
			if classes is Array and not classes.is_empty() and not classes.has(actor.class_id):
				continue
			result.append(
				{
					"id": entry.id,
					"name": entry.name,
					"description": entry.description,
					"count": entry.count
				}
			)
	result.append({"id": 0, "name": "卸下", "description": "", "count": 0})
	return result


func preview_equipment(id: int) -> Dictionary:
	var actor = RuntimeState.actor(actor_id)
	var selected = actor.equipment.duplicate()
	selected[slot] = id
	var values: Dictionary = {}
	for key in actor.PROJECT_KEYS:
		values[key] = actor._parameter_with_states(key, actor.state_ids, selected)
	return values


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _content == null:
		_content = Surface.new()
		add_child(_content)
	View.render(self, _content)


func activate() -> Dictionary:
	if not choosing:
		candidates = candidate_rows()
		choosing = true
		index = 0
		refresh()
		return {"ok": true}
	var result = Actions.equip(RuntimeState, actor_id, slot, int(candidates[index].id))
	message = "" if result.ok else str(result.get("message", ""))
	if result.ok:
		choosing = false
	refresh()
	sound_requested.emit("equip_se" if result.ok else "buzzer_se")
	return result


func back() -> void:
	if choosing:
		choosing = false
		message = ""
		refresh()
	else:
		back_requested.emit()


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		back()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE]:
		activate()
	elif key in [KEY_UP, KEY_DOWN]:
		if choosing:
			index = posmod(index + (-1 if key == KEY_UP else 1), candidates.size())
		else:
			slot = posmod(slot + (-1 if key == KEY_UP else 1), 6)
		refresh()
	elif key in [KEY_PAGEUP, KEY_PAGEDOWN] and not choosing and not RuntimeState.party.is_empty():
		actor_id = int(
			RuntimeState.party[posmod(
				RuntimeState.party.find(actor_id) + (-1 if key == KEY_PAGEUP else 1),
				RuntimeState.party.size()
			)]
		)
		refresh()
