## 职责：绘制闪翼角色状态 HUD，按变化更新生命、属性和相关显示。
##
## 调用方式：
##   由Game持有的FlashMapHUD继承，消费当前正式角色数据并绘制；临时F7预览由本HUD持有，不注册或保存角色。
##   Godot调试运行中F7切换地图与技能配置页的援护预览，长按不重复；原事件验收地图保留F7退出。新游戏、读档、回标题关闭预览。
##
## 调用接口：
##   func reset() -> void
##     用途：重置本服务持有的状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func set_support_preview(enabled: bool) -> bool
##     用途：启用或关闭仅用于查看援护区域的临时显示，缺少正式援护时使用原角色的脱离现场预设。
##     参数 enabled（bool；必填）：true启用、false关闭；只影响本HUD，不修改正式队伍、开关、战斗或存档。
##     返回：本HUD实际的预览开关状态；非闪翼工程不会启用。
##
##   func map_changed(_id: int) -> void
##     参数 _id（int；必填）：为保持原接口位置保留，本实现未读取此参数。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func visible_target() -> bool
##     参数：无。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
##   func set_itembar_selection(slot: int = -1) -> void
##     用途：让地图上唯一的物品栏显示预设编辑光标；只改变选择展示。
##     参数 slot（int；默认值 -1）：-1隐藏光标，0—8选择对应预设格；同一光标按八帧移动。
##     返回：无返回值。
##
##   func itembar_navigation_ready() -> bool
##     用途：检查共享物品栏的八帧光标移动是否结束。
##     参数：无。
##     返回：true允许下一次方向移动。
##
##   func refresh_rows() -> void
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_hud(target: Control) -> void
##     参数 target（Control；必填）：操作或效果作用的目标。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func draw_itembar(target: Control) -> void
##     用途：在唯一的item_canvas上绘制地图/物品页共用的九格物品栏和八帧选择光标。
##     参数 target（Control；必填）：本HUD长期持有的ItemCanvas绘图控件。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 场景树回调（Godot 自动调用）：
##   func _ready() -> void
##   func _input(event: InputEvent) -> void
##     event：输入事件或当前游戏事件对象，类型见签名。
##   func _process(delta: float) -> void
##     delta：本次推进的时间差，单位为秒。
##
## 注意：预览关闭时释放私有显示角色；已解锁的正式援护优先使用真实角色，不受预览关闭影响。
## 接口说明结束。

extends CanvasLayer
## Final 0197 PlayerData, 0183 ItemBar, 0188/0203 transfer map-name view.
## Source BUFF area remains empty. F7 adds a detached, display-only support preview.
const Presets = preload("../08_Menu/Item/ItemPresets.gd")
const Resources = preload("../04_UI_Common/UIResources.gd")
const Cache = preload("../10_Support/Cache/RmxpCache.gd")
const Data = preload("../00_Game/RuntimeData.gd")
const Bitmap = preload("../04_UI_Common/Bitmap.gd")
const Character = preload("CharacterSprite.gd")
const Palette = preload("../04_UI_Common/Palette.gd")
const Drawing = preload("../04_UI_Common/WindowDrawing.gd")


class ItemCanvas:
	extends Control
	var hud: CanvasLayer

	func _draw() -> void:
		hud.draw_itembar(self)


class Canvas:
	extends Control
	var hud: CanvasLayer

	func _draw() -> void:
		hud.draw_hud(self)


var canvas: Control
var item_canvas: Control
var _item_layer: CanvasLayer
var slots: Array = []
var rows: Array = []
var layout_flipped = false
var window_process = 0
var itembar_process = 0
var mapname_frame = 80
var mapname = ""
var _dirty = true
var _old_ids: Array = []
var _clock = 0.0
var _mapname_clock = 0.0
var _background: Texture2D
var _meters: Texture2D
var _frame: Texture2D
var _item_frame: Texture2D
var _portraits: Array = []
var _graphic_layout: Array = []
var _graphic_meters: Array = []
var support_preview_enabled = false
var _preview_actor: RefCounted
var _preview_actor_id = 0
var _itembar_slot = -1
var _itembar_from = 0.0
var _itembar_ticks = 8


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Canvas.new()
	canvas.hud = self
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	_item_layer = CanvasLayer.new()
	_item_layer.layer = 9
	add_child(_item_layer)
	item_canvas = ItemCanvas.new()
	item_canvas.hud = self
	item_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_layer.add_child(item_canvas)
	for i in 2:
		var character = Character.new()
		character.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(character)
		_portraits.append(character)
	var bitmap = Bitmap.new(36, 36)
	bitmap.draw_item_frame(Rect2i(0, 0, 36, 36))
	_item_frame = bitmap.texture()
	RuntimeState.state_changed.connect(func(): _dirty = true)
	get_viewport().size_changed.connect(func(): _dirty = true)
	RuntimeState.execution_reset.connect(reset)
	var game: Node = RuntimeState.game()
	if game != null:
		game.event_map().map_changed.connect(map_changed)
	_process(0)


func reset() -> void:
	support_preview_enabled = false
	_preview_actor = null
	_preview_actor_id = 0
	window_process = 0
	itembar_process = 0
	_itembar_slot = -1
	_itembar_ticks = 8
	_old_ids.clear()
	layout_flipped = false
	_dirty = true
	mapname_frame = 80
	if canvas != null:
		canvas.queue_redraw()
		if item_canvas != null:
			item_canvas.queue_redraw()


func set_support_preview(enabled: bool) -> bool:
	support_preview_enabled = (
		enabled and RuntimeState.custom_data.manifest.get("profile") == "flash"
	)
	if not support_preview_enabled:
		_preview_actor = null
		_preview_actor_id = 0
	_dirty = true
	if canvas != null:
		canvas.queue_redraw()
		if item_canvas != null:
			item_canvas.queue_redraw()
	return support_preview_enabled


func _input(event: InputEvent) -> void:
	if (
		OS.is_debug_build()
		and RuntimeState.playing
		and RuntimeState.game() != null
		and RuntimeState.game().get("_event_lab_hud") == null
		and RuntimeState.custom_data.manifest.get("profile") == "flash"
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode == KEY_F7 or event.physical_keycode == KEY_F7)
	):
		set_support_preview(not support_preview_enabled)
		get_viewport().set_input_as_handled()


func _support_preview(main_id: int, support_id: int) -> RefCounted:
	# Only this display node owns the fallback actor: no actor()/attach to live data.
	var id = support_id
	if id <= 0 or id == main_id:
		id = 2 if main_id == 3 else 3
	if RuntimeState.actors.has(id):
		return RuntimeState.actors[id]
	if _preview_actor_id == id and _preview_actor != null:
		return _preview_actor
	var definition: Dictionary = Data.record("Actors", id)
	if definition.is_empty():
		return null
	_preview_actor = RuntimeState.create_actor(id, definition, Data.record)
	_preview_actor_id = id
	var preset: Dictionary = (
		RuntimeState.custom_data.manifest.get("actor_presets", {}).get(str(id), {}).get("0", {})
	)
	# Apply the original preset to the detached actor, using the existing setters.
	for key in preset:
		if key in _preview_actor.PROJECT_KEYS:
			_preview_actor.set_project_parameter(key, int(preset[key]))
		elif key == "level":
			_preview_actor.set_level(int(preset[key]))
	for key in ["hp", "sp"]:
		if preset.has(key):
			_preview_actor.set(key, int(preset[key]))
	return _preview_actor


func map_changed(_id: int) -> void:
	if not RuntimeState.switches.get("5", false):
		mapname_frame = 80
		return
	mapname = str(
		Data.read_json("res://data/map_infos.json", {}).get(str(RuntimeState.map_id), {}).get(
			"name", ""
		)
	)
	mapname_frame = 0
	_mapname_clock = 0
	canvas.queue_redraw()


func visible_target() -> bool:
	# 最终0202进入技能配置时重新展开同一份PlayerData；不另建角色/HUD状态。
	var game: Node = RuntimeState.game()
	var menus: Node = game.get("_menus") if game != null else null
	if menus != null and menus.menu != null:
		var menu: Control = menus.menu
		if menu.page == "flash_menu" and menu.active_command == 8 and not menu._child_closing:
			return true
	return (
		not _ui_open()
		and bool(RuntimeState.custom_data.values.system.get("show_playerdata", true))
		and not bool(RuntimeState.switches.get("6", false))
	)


func _ui_open() -> bool:
	var game: Node = RuntimeState.game()
	var menus: Node = game.get("_menus") if game != null else null
	return menus != null and (menus.menu != null or menus.shop != null or menus.name_input != null)


func _item_page() -> Control:
	var game = RuntimeState.game()
	var menus = game.get("_menus") if game != null else null
	var menu = menus.menu if menus != null else null
	if menu == null or menu.get("page") != "flash_menu":
		return null
	if menu.active_command != 0 or menu._child_closing or menu.child == null:
		return null
	return menu.child if menu.child.stage != "target" else null


func set_itembar_selection(slot: int = -1) -> void:
	slot = clampi(slot, -1, 8)
	if slot == _itembar_slot:
		return
	_itembar_from = (
		lerpf(_itembar_from, float(_itembar_slot), _itembar_ticks / 8.0)
		if _itembar_slot >= 0
		else float(slot)
	)
	_itembar_ticks = 8 if _itembar_slot < 0 or slot < 0 else 0
	_itembar_slot = slot
	if canvas != null:
		canvas.queue_redraw()
		if item_canvas != null:
			item_canvas.queue_redraw()


func itembar_navigation_ready() -> bool:
	return _itembar_ticks >= 8


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		# Notifications arrive inside commit; normalize on the next frame.
		Presets.normalize(RuntimeState)
		slots = Presets.slots(RuntimeState)
		refresh_rows()
		canvas.queue_redraw()
		if item_canvas != null:
			item_canvas.queue_redraw()
	if RuntimeState.map_time_paused() and not _ui_open():
		return
	_clock += maxf(0, delta) * 60
	_mapname_clock += maxf(0, delta) * 60
	var ticks = mini(120, int(_clock))
	_clock -= ticks
	var old = window_process
	var old_mapname = mapname_frame
	window_process = clampi(window_process + (ticks if visible_target() else -ticks), 0, 8)
	var old_bar = itembar_process
	var item_page = _item_page()
	_item_layer.layer = 55 if item_page != null else 9
	itembar_process = clampi(
		itembar_process + (ticks if not _ui_open() or item_page != null else -ticks), 0, 8
	)
	if item_page == null:
		set_itembar_selection(-1)
	var old_cursor = _itembar_ticks
	_itembar_ticks = mini(8, _itembar_ticks + ticks)
	if mapname_frame < 80:
		var elapsed = mini(120, int(_mapname_clock))
		_mapname_clock -= elapsed
		mapname_frame = mini(80, mapname_frame + elapsed)
	else:
		_mapname_clock = 0
	_update_portrait_positions()
	if (
		old != window_process
		or old_mapname != mapname_frame
		or old_bar != itembar_process
		or old_cursor != _itembar_ticks
	):
		canvas.queue_redraw()
		if item_canvas != null:
			item_canvas.queue_redraw()


func refresh_rows() -> void:
	var previous = rows
	rows = []
	var ids: Array = RuntimeState.custom_data.gameplay().role_actor_ids()
	var preview: RefCounted
	var support_id = int(ids[1])
	ids = [int(ids[0]), support_id if RuntimeState.switches.get("160", false) else 0]
	if support_preview_enabled and ids[1] <= 0:
		preview = _support_preview(ids[0], support_id)
		if preview != null:
			ids[1] = preview.id
	if (
		_old_ids.size() == 2
		and ids[0] == _old_ids[1]
		and ids[1] == _old_ids[0]
		and ids[0] != ids[1]
	):
		layout_flipped = not layout_flipped
	_old_ids = ids.duplicate()
	for role in 2:
		var actor: RefCounted = (
			preview
			if role == 1 and preview != null
			else RuntimeState.actor(ids[role]) if ids[role] > 0 else null
		)
		if actor == null:
			rows.append({})
			continue
		var skills: Array = []
		var passive: Variant = actor.project_fields.equip_skills.get(
			"-1", actor.project_fields.equip_skills.get("-2", 0)
		)
		if passive is Array:
			passive = passive[0] if not passive.is_empty() else 0
		skills.append(int(passive))
		for turn in range(1, 4 if role == 0 else 3):
			var skill: Variant = actor.project_fields.equip_skills.get(str(turn), 0)
			if skill is Array:
				skill = skill[0] if not skill.is_empty() else 0
			skills.append(int(skill))
		rows.append(
			{
				"id": actor.id,
				"name": actor.character_name,
				"hue": actor.character_hue,
				"hp": int(actor.hp),
				"maxhp": int(actor.get_parameter("maxhp")),
				"sp": int(actor.sp),
				"maxsp": int(actor.get_parameter("maxsp")),
				"patk": actor.get_parameter("patk"),
				"pdef": actor.get_parameter("pdef"),
				"agi": actor.get_parameter("agi"),
				"int": actor.get_parameter("int"),
				"exp": actor.experience,
				"next_exp": actor.next_level_experience(),
				"level": actor.level,
				"skills": skills
			}
		)
	if rows == previous and _background != null:
		return
	_build_graphics()
	for i in _portraits.size():
		_portraits[i].visible = not rows[i].is_empty()
		if (
			not rows[i].is_empty()
			and (
				i >= previous.size()
				or previous[i].is_empty()
				or rows[i].name != previous[i].name
				or rows[i].hue != previous[i].hue
			)
		):
			_portraits[i].configure(rows[i].name, rows[i].hue, 2, 0)
			_portraits[i].size = _portraits[i]._frame_size
	_update_portrait_positions()
	canvas.queue_redraw()


func _build_graphics() -> void:
	var layout = [layout_flipped, rows[0].is_empty(), rows[1].is_empty()]
	if layout != _graphic_layout or _background == null or _frame == null:
		_build_static_graphics()
		_graphic_layout = layout
	var meters: Array = [layout_flipped]
	for row in rows:
		meters.append(
			[] if row.is_empty() else [row.hp, row.maxhp, row.sp, row.maxsp, row.exp, row.next_exp]
		)
	if meters != _graphic_meters or _meters == null:
		_build_meter_graphics()
		_graphic_meters = meters


func _build_static_graphics() -> void:
	var bitmap = Bitmap.new(640, 196)
	bitmap.draw_h8_background(Rect2i(0, 4, 640, 168))
	bitmap.draw_h8_bulge(Vector2i(176, 20), Vector2i(464, 20), false, 20, 0)
	var main_y = 104 if layout_flipped else 40
	var support_y = 40 if layout_flipped else 104
	bitmap.draw_hud_back(Rect2i(88, main_y + 4, 160, 6), 1)
	bitmap.draw_hud_back(Rect2i(88, main_y + 28, 160, 6), 1)
	bitmap.fill_rounded_rect(
		Rect2i(264, 100, 112, 56) if layout_flipped else Rect2i(268, 28, 96, 56),
		10,
		Color8(30, 56, 58, 184)
	)
	bitmap.fill_rounded_rect(Rect2i(372, 28, 240, 76), 10, Color8(0, 8, 16, 128))
	bitmap.draw_line2(
		Vector2i(18, 88), Vector2i(336, 88), 2, [Color.TRANSPARENT, Color8(0, 128, 192)]
	)
	var turn = Vector2i(366, 72 if layout_flipped else 104)
	bitmap.draw_line2(Vector2i(336, 88), turn, 2, [Color.TRANSPARENT, Color8(0, 128, 192)])
	bitmap.draw_line2(
		turn + Vector2i(0, -1 if layout_flipped else 1),
		Vector2i(366, 22 if layout_flipped else 154),
		2,
		[Color.TRANSPARENT, Color8(0, 128, 192)]
	)
	if not rows[1].is_empty():
		bitmap.draw_hud_back(Rect2i(80, support_y + 4, 80, 6), 1)
		bitmap.draw_hud_back(Rect2i(80, support_y + 28, 80, 6), 1)
	_background = bitmap.texture()
	bitmap = Bitmap.new(640, 196)
	for i in 4:
		bitmap.draw_skill_frame(Rect2i(392 + i * 56, 116, 32, 32), 1 if i == 0 else 2, true)
	if not rows[1].is_empty():
		for i in 3:
			bitmap.draw_skill_frame(
				Rect2i(192 + i * 56, (48 if layout_flipped else 112) + 4, 32, 32),
				1 if i == 0 else 3,
				true
			)
	_frame = bitmap.texture()


func _build_meter_graphics() -> void:
	var bitmap = Bitmap.new(640, 196)
	var main_y = 104 if layout_flipped else 40
	var support_y = 40 if layout_flipped else 104
	for i in 2:
		if rows[i].is_empty():
			continue
		var row: Dictionary = rows[i]
		var y = main_y if i == 0 else support_y
		var width = 160 if i == 0 else 80
		var x = 88 if i == 0 else 80
		bitmap.draw_hud_line(
			Rect2i(x, y + 4, width, 6), row.hp, row.maxhp, Palette.color(9), Palette.color(3), 1
		)
		bitmap.draw_hud_line(
			Rect2i(x, y + 28, width, 6), row.sp, row.maxsp, Palette.color(4), Palette.color(1), 1
		)
		if i == 0:
			bitmap.draw_trapezoid_meter(
				Rect2i(176, 0, 288, 20),
				row.exp,
				int(row.next_exp) if row.next_exp != null else 0,
				Color8(40, 104, 206, 128),
				Color8(255, 165, 0, 128)
			)
	_meters = bitmap.texture()


func draw_hud(target: Control) -> void:
	var font = Resources.font()
	if support_preview_enabled:
		target.draw_string(
			font,
			Vector2(12, 24),
			"援护UI预览 · F7关闭",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("ffe9a8")
		)
	var base = Vector2(0, target.size.y - 20 * window_process - 4)
	var opacity = clampf(window_process * 32.0 / 255, 0, 1)
	if window_process > 0 and _background != null:
		target.draw_texture(_background, base, Color(1, 1, 1, opacity))
		target.draw_texture(_meters, base, Color(1, 1, 1, opacity))
		target.draw_texture(_frame, base, Color(1, 1, 1, opacity))
		for role in 2:
			if rows[role].is_empty():
				continue
			var row: Dictionary = rows[role]
			var y = (88 if layout_flipped else 24) if role == 0 else (24 if layout_flipped else 88)
			for vital in 2:
				var text = (
					"%d/%d" % [row.hp, row.maxhp] if vital == 0 else "%d/%d" % [row.sp, row.maxsp]
				)
				target.draw_string(
					font,
					base + Vector2(128 if role == 0 else 72, y + 23 + vital * 24),
					text,
					HORIZONTAL_ALIGNMENT_RIGHT,
					128 if role == 0 else 96,
					18 if role == 0 else 16,
					Color(1, 0.65, 0.65, opacity) if vital == 0 else Color(0.25, 0.75, 1, opacity)
				)
			if role == 0:
				target.draw_string(
					font,
					base + Vector2(202, 18),
					"Lv.%d" % row.level,
					HORIZONTAL_ALIGNMENT_LEFT,
					80,
					18,
					Color(0.84, 0.92, 0.97, opacity)
				)
				target.draw_string(
					font,
					base + Vector2(310, 18),
					str(row.exp) + "/" + (str(row.next_exp) if row.next_exp != null else ""),
					HORIZONTAL_ALIGNMENT_RIGHT,
					128,
					18,
					Color(1, 0.83, 0.46, opacity)
				)
				for i in 4:
					var point = base + Vector2(376 + i % 2 * 128, 53 + int(i / 2) * 36)
					target.draw_string(
						font,
						point,
						["攻击", "防御", "速度", "术法"][i],
						HORIZONTAL_ALIGNMENT_LEFT,
						45,
						18,
						Color(0.71, 0.88, 0.92, opacity)
					)
					target.draw_string(
						font,
						point + Vector2(36, -6),
						str(row[["patk", "pdef", "agi", "int"][i]]),
						HORIZONTAL_ALIGNMENT_RIGHT,
						66,
						18,
						Color(1, 1, 1, opacity)
					)
			var x = 392 if role == 0 else 192
			var sy = 112 if role == 0 else (48 if layout_flipped else 112)
			for i in row.skills.size():
				var point = base + Vector2(x + i * 56, sy + 4)
				var id = int(row.skills[i])
				if id > 0:
					var icon = Cache.skills(str(Data.record("Skills", id).get("name", "")) + ".png")
					if icon != null:
						target.draw_texture_rect(
							icon,
							Rect2(point + Vector2(4, 4), Vector2(40, 40)),
							false,
							Color(1, 1, 1, opacity)
						)
				target.draw_string(
					font,
					point + Vector2(34, 31),
					str(i),
					HORIZONTAL_ALIGNMENT_CENTER,
					10,
					10,
					Color(1, 1, 1, opacity)
				)
	if mapname_frame < 80:
		var step = mini(16, mapname_frame) if mapname_frame < 64 else 80 - mapname_frame
		var position = Vector2(target.size.x - 128, -56 + step * 4)
		target.draw_style_box(
			Bitmap.panel_style(Vector2i(128, 80), 8), Rect2(position, Vector2(128, 80))
		)
		target.draw_string(
			font,
			position + Vector2(8, 42),
			mapname,
			HORIZONTAL_ALIGNMENT_CENTER,
			112,
			20,
			Color(0.83, 0.95, 1, clampf(step * 16.0 / 255, 0, 1))
		)


func draw_itembar(target: Control) -> void:
	var font = Resources.font()
	for cell in slots.size():
		if itembar_process == 0:
			break
		var alpha = clampf(itembar_process * 32.0 / 255, 0, 1)
		var rect = Rect2(target.size.x - 40 + (8 - itembar_process) * 12, 82 + cell * 40, 36, 36)
		var id = int(slots[cell][0])
		target.draw_texture(_item_frame, rect.position, Color(1, 1, 1, alpha))
		if id > 0:
			var icon = Cache.icon(str(Presets.native_item(id, RuntimeState).get("icon_name", "")))
			if icon != null:
				target.draw_texture_rect(
					icon,
					Rect2(rect.position + Vector2(4, 4), Vector2(28, 28)),
					false,
					Color(1, 1, 1, alpha)
				)
			var count_color = Color.WHITE if slots[cell][1] > 0 else Color("b8c6d2")
			count_color.a = alpha
			target.draw_string(
				font,
				rect.position + Vector2(4, 32),
				"x%d" % int(slots[cell][1]),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				count_color
			)
		target.draw_string(
			font,
			rect.position + Vector2(2, 12),
			str(cell + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(1, 0.94, 0.69, alpha)
		)
	if _itembar_slot >= 0 and itembar_process > 0:
		var slot_y = lerpf(_itembar_from, float(_itembar_slot), _itembar_ticks / 8.0)
		Drawing.cursor(
			target,
			Rect2(target.size.x - 42 + (8 - itembar_process) * 12, 80 + slot_y * 40, 40, 40),
			2,
			Vector2.ZERO,
			minf(1, itembar_process * 32.0 / 255)
		)


func _update_portrait_positions() -> void:
	if canvas == null:
		return
	var base = Vector2(0, canvas.size.y - 20 * window_process)
	for i in _portraits.size():
		_portraits[i].position = (
			base
			+ Vector2(
				32, (92 if layout_flipped else 24) if i == 0 else (24 if layout_flipped else 92)
			)
		)
		_portraits[i].modulate.a = clampf(window_process * 32.0 / 255, 0, 1)
