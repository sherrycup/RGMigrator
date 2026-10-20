## 职责：绘制原技能分类、技能大图、参数、简易/详细富文本与快捷提示，不装配技能。
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
const Data = preload("../../00_Game/RuntimeData.gd")
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Config = preload("SkillConfig.gd")
const Palette = preload("../../04_UI_Common/Palette.gd")


static func render(page: Control, surface: Control) -> void:
	surface.begin()
	var actor = page.actor()
	if actor == null:
		var empty = surface.window("empty", Rect2(16, 104, 256, 80))
		empty.line(Rect2(16, 16, 224, 48), "队伍中没有角色", 20)
		surface.finish()
		return
	var rows: Array = []
	var selected_row = 0
	for group in 5:
		rows.append({"id": 0, "name": ["-状态型被动-", "-追加型技能-", "-主动技能-", "-即时技能-", "-魔法-"][group]})
		for id in page.skill_ids:
			if Config.category(Data.record("Skills", int(id))) != group:
				continue
			if id == page.selected_id():
				selected_row = rows.size()
			rows.append({"id": id, "name": str(Data.record("Skills", int(id)).get("name", ""))})
	var x = page.size.x - 184
	var category = surface.window(
		"category", Rect2(x, 104, 192, mini(11, rows.size()) * 32 + 32), Vector2(64, 0)
	)
	var list = surface.window(
		"skill_rows",
		Rect2(12, 12, 168, mini(11, rows.size()) * 32),
		Vector2.ZERO,
		"category",
		false
	)
	var first = maxi(0, selected_row - 9)
	for i in range(first, mini(first + 11, rows.size())):
		var row = rows[i]
		var tint = Palette.color(17)
		if row.id > 0:
			var skill = Data.record("Skills", int(row.id))
			var elements: Array = skill.get("element_set", [])
			tint = Palette.color(
				4 if not elements.is_empty() and int(elements[-1]) % 2 == 0 else 15
			)
			if not Config.available(RuntimeState.custom_data, actor, int(row.id)):
				tint = Color(0.5, 0.5, 0.5)

		list.line(
			Rect2(0, (i - first) * 32, 160, 32),
			row.name,
			18,
			tint,
			1,
			row.id > 0 and actor.project_skill_slot(int(row.id))[0]
		)
	if not page.skill_ids.is_empty():
		list.select(Rect2(0, (selected_row - first) * 32, 152, 28))
	var detail = surface.window("detail", Rect2(x - 352, 72, 352, 448), Vector2(0, 64))
	if page.selected_id() > 0:
		var skill = Data.record("Skills", page.selected_id())
		detail.line(Rect2(12, 16, 328, 32), str(skill.get("name", "")), 24, Color.WHITE, 1)
		var icon = Cache.skills(str(skill.get("name", "")) + ".png")
		if icon == null:
			icon = Cache.icon(str(skill.get("icon_name", "")))
		detail.image(icon, Rect2(42, 88, 72, 72))
		detail.line(Rect2(40, 152, 76, 24), "Lv.     1", 16)
		var elements: Array = skill.get("element_set", [])
		var tag = int(elements[-1]) if not elements.is_empty() else 0
		var values = [
			{13: "主战主动", 14: "主战被动", 15: "援护主动", 16: "援护被动"}.get(tag, ""),
			"无消耗" if skill.get("sp_cost", 0) == 0 else str(skill.sp_cost) + " sp",
			"敌方单体" if skill.get("scope", 0) == 1 else "—",
			"—" if skill.get("eva_f", 0) == 0 else str(skill.eva_f) + " 回合",
			"—" if skill.get("power", 0) == 0 else str(skill.power)
		]
		for i in 5:
			detail.line(
				Rect2(128, 56 + 24 * i, 96, 24),
				["技能类型", "技能消耗", "作用对象", "冷却时间", "僵直"][i],
				16,
				Color.WHITE,
				1
			)
			detail.line(Rect2(224, 56 + 24 * i, 112, 24), str(values[i]), 16, Color.WHITE, 1)
		detail.line(Rect2(16, 196, 128, 32), "技能简介", 24)
		detail.line(Rect2(128, 200, 204, 24), "（按A切换为%s描述）" % ("详细" if page.easy else "简易"), 12)
		var value: Variant = (
			RuntimeState
			. custom_data
			. gameplay()
			. rules
			. storage
			. get("skill_easy_description" if page.easy else "skill_description", {})
			. get(str(page.selected_id()), skill.get("description", ""))
		)
		var description = "\n".join(value) if value is Array else str(value)
		var text = surface.window(
			"description", Rect2(20, 232, 312, 200), Vector2.ZERO, "detail", false
		)
		text.rich(description, Rect2(0, 0, 312, 200), 16, page.description_scroll, 0, 24)
		page._detail_nodes["description"] = text.rich_label
	var help = surface.window("help", Rect2(page.size.x - 160, 416, 160, 160), Vector2(96, 0))
	for i in 5:
		help.line(
			Rect2(16, 20 + 24 * i, 128, 24),
			["W+数字:主战保存", "E+数字:援护保存", "空格:装配/卸下", "数字:设置回合", "TAB:切换角色"][i],
			16,
			Palette.color(17),
			1
		)
	var topic = surface.window("topic", Rect2(page.size.x - 136, 8, 128, 80), Vector2(64, 0))
	topic.line(Rect2(8, 20, 112, 32), "角色技能", 20, Color.WHITE, 1)
	if not page.notice.is_empty():
		var notice = surface.window(
			"notice", Rect2(16, page.size.y - 64, maxf(200, page.size.x - 32), 56)
		)
		notice.line(Rect2(16, 12, notice.size.x - 32, 32), page.notice, 16, Palette.color(6))
	surface.finish()
