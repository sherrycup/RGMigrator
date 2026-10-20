## 职责：展示闪翼技能学习和配置页面，协调技能说明及配置操作。
##
## 调用方式：
##   通过FlashMenuPages创建并接入同一RuntimeState；输入和业务在本页，绘图由同组View和持久FlashPageSurface负责。
##   父FlashMenuScreen通过set_menu_progress(value)提供唯一0—8进退时钟；选择、文本和窗口节点复用，按各自区域裁切。
##   Tab仅在配置期间交换前两角色；Esc按0202恢复进入时的角色顺序，保留各角色已经修改的技能。
##
## 调用接口：
##   func actor() -> RefCounted
##     用途：按原编号取得当前运行角色实例。
##     参数：无。
##     返回：RefCounted 类型的对象或值，供调用方继续使用。
##
##   func refresh() -> void
##     用途：按当前状态刷新显示或缓存。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func selected_id() -> int
##     参数：无。
##     返回：数值结果；编号、单位与计算含义由本接口用途决定。
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
## 接口说明结束。

extends Control
const Surface = preload("../../04_UI_Common/PageSurface.gd")
const View = preload("SkillView.gd")
## Source 0207/0208/0209 and 0202: category, details, slots and configuration.
const Data = preload("../../00_Game/RuntimeData.gd")
const Config = preload("SkillConfig.gd")
const Actions = preload("../../01_Battle/Actions.gd")
const Resources = preload("../../04_UI_Common/UIResources.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
signal back_requested
signal sound_requested(key: String)
var page = "flash_skills"
var skill_ids: Array = []
var index = 0
var easy = false
var notice = ""
var _content: Control
var description_scroll = 0.0
var _entry_actor_id = 0
var _detail_nodes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_entry_actor_id = int(RuntimeState.party[0]) if not RuntimeState.party.is_empty() else 0
	RuntimeState.state_changed.connect(refresh)
	resized.connect(refresh)
	refresh()


func actor() -> RefCounted:
	return (
		RuntimeState.actor(int(RuntimeState.party[0]))
		if not RuntimeState.party.is_empty()
		else null
	)


func refresh() -> void:
	if not is_inside_tree() or size.x < 1:
		return
	if _content == null:
		_content = Surface.new()
		add_child(_content)
	var value = actor()
	skill_ids.clear()
	var groups: Array = [[], [], [], []]
	if value != null:
		for id in value.get_skill_ids():
			var group = Config.category(Data.record("Skills", id))
			if group >= 0:
				groups[group].append(id)
	for group in groups:
		skill_ids.append_array(group)
	index = clampi(index, 0, maxi(0, skill_ids.size() - 1))
	View.render(self, _content)


func selected_id() -> int:
	return int(skill_ids[index]) if not skill_ids.is_empty() else 0


func _details(_value: RefCounted, _id: int) -> void:
	View.render(self, _content)


func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE, KEY_X]:
		if _entry_actor_id > 0:
			Config.restore_page_actor(RuntimeState, _entry_actor_id)
		back_requested.emit()
		return
	if actor() == null:
		return
	if key in [KEY_UP, KEY_DOWN] and not skill_ids.is_empty():
		sound_requested.emit("cursor_se")
		index = posmod(index + (-1 if key == KEY_UP else 1), skill_ids.size())
		description_scroll = 0.0
		_details(actor(), selected_id())
		return
	if key in [KEY_PAGEUP, KEY_PAGEDOWN]:
		description_scroll = maxf(0, description_scroll + (-168 if key == KEY_PAGEUP else 168))
		View.render(self, _content)
		return
	if key == KEY_A:
		easy = not easy
		description_scroll = 0.0
		if selected_id() > 0:
			_details(actor(), selected_id())
		return
	var result: Dictionary = {}
	if key == KEY_TAB:
		result = Config.switch_page_actor(RuntimeState)
		index = 0
	elif key >= KEY_1 and key <= KEY_8:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_E):
			var side = "atk" if Input.is_key_pressed(KEY_W) else "sup"
			var ids = RuntimeState.custom_data.gameplay().role_actor_ids()
			var actor_id = int(ids[0 if side == "atk" else 1])
			result = (
				Actions.save_skill_set(RuntimeState, actor_id, key - KEY_1, side)
				if actor_id > 0
				else {"ok": false, "message": "队伍中不存在援护角色。"}
			)
			notice = (
				"已保存技能组 %d。" % (key - KEY_1 + 1) if result.ok else str(result.get("message", ""))
			)
		else:
			result = Config.set_skill(RuntimeState, actor().id, selected_id(), key - KEY_1 + 1)
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_SPACE] and selected_id() > 0:
		result = Config.set_skill(RuntimeState, actor().id, selected_id())
	if not result.is_empty() and not result.ok:
		notice = str(result.get("message", ""))
	refresh()


func set_menu_progress(value: int) -> void:
	if _content != null:
		_content.set_progress(value)
