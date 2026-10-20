## 职责：绘制原灵视焦点、横向列表、敌人参数、技能详情和行动顺序，读取同一战斗快照。
##
## 调用方式：
##   由对应页面refresh调用render(page,surface)，页面拥有输入、业务请求和生命周期；本文件只绘制或读取展示快照。
##   surface为该页面长期持有的FlashPageSurface；窗口与文字节点按稳定键复用，不能把显示对象保存到游戏数据。
##
## 调用接口：
##   static func render(page: Control, surface: Control) -> void
##     用途：按最终有效来源绘制本页当前内容、说明和独立光标。
##     参数 page（Control；必填）：持有正式选择、快照及业务接口的当前功能页控件。
##     参数 surface（Control；必填）：当前页面的持久FlashPageSurface实例，接收本次绘图区域与内容。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends RefCounted
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Palette = preload("../../04_UI_Common/Palette.gd")
const Bitmap = preload("../../04_UI_Common/Bitmap.gd")


static func render(page: Control, surface: Control) -> void:
	surface.begin()
	var model = page.model
	var focus = surface.window("focus", Rect2(0, 0, 224, 80), Vector2(-96, 0))
	for i in 4:
		var tint = Color.WHITE if model.focus == i else Color(1, 1, 1, 0.5)
		focus.image(
			Cache.picture("Causal/focus.png"),
			Rect2(24 + 48 * i, 16, 32, 32),
			Rect2([0, 1, 2, 4][i] * 32, 0, 32, 32),
			tint
		)
		focus.line(
			Rect2(16 + 48 * i, 48, 48, 16),
			model.FOCUS_NAMES[i],
			14,
			Palette.color(17) if model.focus == i else Color8(128, 128, 128, 192),
			1
		)
	focus.fill(Rect2(22 + 48 * model.focus, 16, 36, 32), Color8(224, 240, 255), false)
	if model.stage == "list":
		_list(page, surface)
	elif not page.snapshot.is_empty():
		if model.stage == "actions":
			_actions(page, surface)
		else:
			_enemy(page, surface)
	elif model.description_visible and not model.description().is_empty():
		var text = surface.window(
			"map_description", Rect2(page._near_tile(Vector2(256, 120)), Vector2(256, 120))
		)
		text.rich(model.description(), Rect2(16, 16, 224, 88), 16)
	if not model.failure.is_empty():
		var notice = surface.window("notice", Rect2(16, page.size.y - 64, page.size.x - 32, 56))
		notice.line(Rect2(16, 12, notice.size.x - 32, 32), model.failure, 16, Palette.color(2))
	surface.finish()


static func _list(page: Control, surface: Control) -> void:
	var model = page.model
	var panel = surface.window(
		"list", Rect2(0, 88, 224 if model.focus == 1 else 176, 80), Vector2(-64, 0)
	)
	panel.line(
		Rect2(0, 0, 64, 16), "敌人列表" if model.focus == 1 else "物品列表", 12, Palette.color(17), 1
	)
	var rows = surface.window(
		"focus_rows", Rect2(16, 16, panel.size.x - 32, 48), Vector2.ZERO, "list", false
	)
	if model.groups.is_empty():
		rows.line(Rect2(0, 16, 192, 24), "当前地图不存在敌人", 12, Color.WHITE, 1)
		return
	var first = maxi(0, model.list_index - 1) if model.focus == 1 else 0
	var cell_width = 64 if model.focus == 1 else 48
	for i in range(first, mini(first + 3, model.groups.size())):
		var group: Dictionary = model.groups[i]
		if group.has("node"):
			var node = group.node
			rows.portrait(
				str(i),
				node._name,
				int(node._hue),
				Rect2((i - first) * cell_width + 16, 0, 32, 32),
				node.motion.direction
			)
		elif model.focus == 2:
			var icon = [["宝石(gems)2-8", 0, 2], ["宝石(gems)3-3", 2, 1], ["Recover", 2, 0]][i]
			rows.image(
				Cache.character(icon[0]),
				Rect2((i - first) * cell_width + 8, -4, 32, 32),
				Rect2(icon[1] * 32, icon[2] * 32, 32, 32),
				Color.WHITE if not group.event_ids.is_empty() else Color(0.5, 0.5, 0.5, 0.6)
			)
		rows.line(
			Rect2((i - first) * cell_width, 26, cell_width, 16),
			"x %s" % group.event_ids.size(),
			12,
			Color.WHITE if not group.event_ids.is_empty() else Color(0.5, 0.5, 0.5),
			1
		)
	rows.select(Rect2((model.list_index - first) * cell_width, 0, cell_width, 48))


static func _enemy(page: Control, surface: Control) -> void:
	var snapshot: Dictionary = page.snapshot
	var model = page.model
	var count = snapshot.skills.size()
	var rows = mini(3, int(ceil(float(count) / 3)))
	var height = 238 if rows <= 1 else 284 if rows == 2 else 330
	var origin = page._near_tile(Vector2(280, height))
	var panel = surface.window("enemy", Rect2(origin, Vector2(280, height)))
	panel.line(
		Rect2(12, 6, 224, 26),
		str(snapshot.fields.get("name", "")).get_slice(":", 0),
		18,
		Color.WHITE,
		1
	)
	panel.line(Rect2(224, 12, 48, 20), "耐心%s" % snapshot.enemy.patience, 12, Palette.color(17), 2)
	page._hp_label = panel.label("hp", Rect2(16, 34, 248, 26), "", 16, Palette.color(2))
	page._after_hp_label = panel.label("after_hp", Rect2(16, 34, 248, 26), "", 16, Palette.color(2))
	page._update_hp()
	var attr: Dictionary = snapshot.attributes
	var values = [
		int(attr.attack),
		int(attr.defense),
		int(attr.speed),
		int(attr.magic_attack),
		snapshot.result.main_turns,
		snapshot.fields.get("exp", 0)
	]
	for i in 6:
		var x = 16 + (i % 2) * 124
		var y = 62 + int(i / 2) * 24
		var color = Palette.color([11, 1, 10, 15, 0, 12][i])
		panel.line(Rect2(x, y, 48, 28), ["攻击", "防御", "速度", "魔攻", "回合", "经验"][i], 18, color)
		panel.line(Rect2(x + 48, y, 64, 28), str(values[i]), 17, color, 2)
	var drops: Array = snapshot.drops if snapshot.drops is Array else []
	var slot = 0
	for i in mini(5, drops.size()):
		if drops[i] <= 0 or slot >= 4:
			continue
		panel.image(
			Cache.picture("Causal/耀晶石.png"),
			Rect2(16 + slot * 60, 140, 16, 16),
			Rect2(i * 16, 0, 16, 16)
		)
		panel.line(Rect2(32 + slot * 60, 136, 40, 24), str(drops[i]), 14)
		slot += 1
	var page_index = int(model.skill_index / 9)
	for i in mini(9, maxi(0, count - page_index * 9)):
		var info = model.skill_presentation(snapshot.skills[page_index * 9 + i], snapshot.skill_set)
		var rect = Rect2(12 + i % 3 * 84, 164 + int(i / 3) * 46, 80, 38)
		panel.image(Bitmap.skill_style(Vector2i(80, 38), 3, false).texture, rect)
		panel.line(Rect2(rect.position, Vector2(80, 24)), info.name, 14, info.color, 1)
		if not info.origin.is_empty():
			panel.line(
				Rect2(rect.position + Vector2(0, 21), Vector2(80, 14)),
				info.origin,
				11,
				Palette.color(2),
				1
			)
		if model.stage == "skills" and model.skill_index == page_index * 9 + i:
			panel.select(rect, 2)
	panel.line(
		Rect2(12, height - 28, 256, 20),
		"技能 %d/%d" % [page_index + 1, maxi(1, int(ceil(float(count) / 9)))],
		13,
		Palette.color(17),
		2
	)
	if count > 0:
		var detail_index = model.skill_index if model.stage == "skills" else page.automatic_index
		var info = model.skill_presentation(
			snapshot.skills[clampi(detail_index, 0, count - 1)], snapshot.skill_set
		)
		var x = origin.x + 288 if origin.x + 488 <= page.size.x else origin.x - 208
		var detail = surface.window(
			"detail",
			Rect2(
				clampf(x, 8, maxf(8, page.size.x - 200)),
				clampf(origin.y, 88, maxf(88, page.size.y - 350)),
				200,
				280
			),
			Vector2(0, -64)
		)
		var body = surface.window(
			"detail_body", Rect2(0, 0, 200, 240), Vector2.ZERO, "detail", false
		)
		body.line(Rect2(16, 12, 168, 24), info.name, 16, info.color, 1)
		var turn = (
			"回合: ——"
			if info.type in ["rage", "passive"]
			else "回合: 通常" if info.turn == 0 and info.period == 1 else "行动: 第%d次" % info.turn
		)
		var stiff = (
			"僵直: ——"
			if info.type in ["rage", "passive"] or info.stiffness == 0
			else "僵直: %s" % info.stiffness
		)
		body.line(Rect2(16, 36, 104, 20), turn, 12)
		body.line(Rect2(116, 36, 68, 20), stiff, 12, Color.WHITE, 2)
		var text = surface.window(
			"skill_description", Rect2(16, 64, 168, 168), Vector2.ZERO, "detail_body", false
		)
		text.rich(info.description, Rect2(0, 0, 168, 168), 14, page.detail_scroll, 0, 18)
		page._detail = text.rich_label
		body.modulate.a = page.browse_alpha
		detail.image(Cache.title("config/Q.png"), Rect2(16, 248, 20, 20))
		detail.image(Cache.title("config/E.png"), Rect2(164, 248, 20, 20))
		detail.line(
			Rect2(40, 244, 120, 24),
			"Q/E 详情" if model.stage == "skills" else "%d/%d" % [detail_index + 1, count],
			12,
			Color.WHITE,
			1
		)


static func _actions(page: Control, surface: Control) -> void:
	var panel = surface.window(
		"actions", Rect2(96, 0, 320, maxf(240, page.size.y - 40)), Vector2(-64, 0)
	)
	var signature = str([page.snapshot.event.id, page.snapshot.timeline])
	if page._action_scroll == null or page._action_scroll.get_meta("signature", "") != signature:
		if page._action_scroll != null:
			page._action_scroll.get_parent().remove_child(page._action_scroll)
			page._action_scroll.queue_free()
		var order = preload("../../01_Battle/ActionOrder.gd").new()
		order.rows = page.snapshot.timeline
		var result: Dictionary = page.snapshot.result
		for key in ["actor_1", "actor_2", "enemy_1"]:
			var id = int(
				(
					result.main_actor_id
					if key == "actor_1"
					else result.support_actor_id if key == "actor_2" else 0
				)
			)
			if id > 0:
				var actor = RuntimeState.actor(id)
				order.sprites[key] = {
					"name": actor.character_name, "hue": actor.character_hue, "direction": 2
				}
			elif key == "enemy_1":
				var node = page.snapshot.event.node
				order.sprites[key] = {
					"name": node._name, "hue": node._hue, "direction": node.motion.direction
				}
		order.set_meta("signature", signature)
		panel.add_child(order)
		page._action_scroll = order
	page._action_scroll.position = Vector2(8, 8)
	page._action_scroll.size = panel.size - Vector2(16, 16)
