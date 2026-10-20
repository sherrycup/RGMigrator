## 职责：绘制独立六槽装备兼容入口的状态、候选和只读预览，不启用主菜单原空分支。
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
const Palette = preload("../../04_UI_Common/Palette.gd")


static func render(page: Control, surface: Control) -> void:
	surface.begin()
	var actor = RuntimeState.actor(page.actor_id)
	var header = surface.window("header", Rect2(0, 0, page.size.x, 64))
	header.line(
		Rect2(16, 16, page.size.x - 32, 32),
		(
			page.message
			if not page.message.is_empty()
			else actor.actor_name + " · 角色装备" if actor != null else "没有可操作的角色"
		),
		20,
		Palette.color(17)
	)
	if actor == null:
		surface.finish()
		return
	var stats = surface.window("stats", Rect2(0, 64, 272, 416))
	stats.portrait("actor", actor.character_name, actor.character_hue, Rect2(16, 16, 48, 48))
	page.preview = (
		page.preview_equipment(int(page.candidates[page.index].id))
		if page.choosing and not page.candidates.is_empty()
		else {}
	)
	for i in actor.PROJECT_KEYS.size():
		var key = actor.PROJECT_KEYS[i]
		var value = actor.get_parameter(key)
		var next: Variant = page.preview.get(key, value)
		var tint = (
			Palette.color(3) if next > value else Palette.color(2) if next < value else Color.WHITE
		)
		stats.line(
			Rect2(16, 72 + i * 36, 80, 32),
			{
				"maxhp": "生命",
				"maxsp": "魂量",
				"patk": "物攻",
				"pdef": "物防",
				"matk": "魔攻",
				"mdef": "魔防",
				"agi": "速度",
				"int": "智力"
			}[key],
			18,
			Palette.color(17)
		)
		stats.line(
			Rect2(96, 72 + i * 36, 160, 32),
			str(value) + (" → " + str(next) if page.choosing else ""),
			18,
			tint,
			2
		)
	var slots = surface.window("slots", Rect2(272, 64, maxf(256, page.size.x - 272), 208))
	for i in 6:
		var row = RuntimeState.custom_data.record(page.DATABASES[i], int(actor.equipment[i]))
		slots.line(
			Rect2(16, 16 + i * 28, slots.size.x - 32, 28),
			page.SLOT_NAMES[i] + "  " + str(row.get("name", "—")),
			16
		)
	if not page.choosing:
		slots.select(Rect2(12, 16 + page.slot * 28, slots.size.x - 24, 28), 2)
	var choices = surface.window("choices", Rect2(272, 272, maxf(256, page.size.x - 272), 208))
	if page.choosing:
		var first = maxi(0, page.index - 4)
		for i in range(first, mini(first + 5, page.candidates.size())):
			choices.line(
				Rect2(16, 16 + (i - first) * 32, choices.size.x - 32, 32),
				str(page.candidates[i].name),
				18
			)
		choices.select(Rect2(12, 16 + (page.index - first) * 32, choices.size.x - 24, 28), 2)
		var desc = surface.window("description", Rect2(16, 496, page.size.x - 32, 96))
		desc.rich(
			str(page.candidates[page.index].get("description", "")),
			Rect2(16, 16, desc.size.x - 32, 64),
			16
		)
	surface.finish()
