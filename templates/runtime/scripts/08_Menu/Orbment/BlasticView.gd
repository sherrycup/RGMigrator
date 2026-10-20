## 职责：绘制原魔盘孔位、装配链、元素预览、回响和结晶候选，不修改背包或回路。
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
const Presets = preload("../Item/ItemPresets.gd")


static func render(page: Control, surface: Control) -> void:
	surface.begin()
	if page.value.is_empty():
		var empty = surface.window("empty", Rect2(24, 48, 272, 96))
		empty.line(
			Rect2(16, 16, 240, 64),
			(
				RuntimeState.custom_data.failure
				if not RuntimeState.custom_data.failure.is_empty()
				else "队伍中没有角色"
			),
			18
		)
		surface.finish()
		return
	var value: Dictionary = page.value
	var width = value.pos[0].size()
	var circle = int(page.slot / width)
	var column = page.slot % width
	var storage: Dictionary = RuntimeState.custom_data.gameplay().rules.storage
	# 原0215始终使用地之魔盘；不按ID补造其它圆盘选择业务。
	var scale = minf(1.0, maxf(240, page.size.x - 288) / 480.0)
	var disc = surface.window(
		"disc", Rect2(280, 132, 480 * scale, 480 * scale), Vector2(0, 96), "", false
	)
	disc.image(Cache.picture("Blastic/地之魔盘.png"), Rect2(0, 0, 480 * scale, 480 * scale))
	for chain in 2:
		for cell in value.pos[chain].size():
			var point = Vector2(value.pos[chain][cell][0], value.pos[chain][cell][1]) * scale
			var equipped: Variant = value.equip[chain][cell]
			var type = 0 if equipped == null else int(storage.crystal[str(equipped)][0])
			if not value.lock[chain][cell] or equipped != null:
				disc.image(
					Cache.picture("Blastic/slot_items.png"),
					Rect2(point - Vector2(16, 16) * scale, Vector2(32, 32) * scale),
					Rect2(type * 32, 0, 32, 32)
				)
			if page.slot == chain * width + cell:
				disc.image(
					Cache.picture("Blastic/cursor.png"),
					Rect2(point - Vector2(32, 32) * scale, Vector2(64, 64) * scale)
				)
	var equip = surface.window("equip", Rect2(24, 48, 272, 288), Vector2(0, -96))
	for chain in 2:
		for cell in value.pos[chain].size():
			var row = chain * width + cell
			var label = (
				("Line%d┳" % (chain + 1))
				if cell == 0
				else "     ┗" if cell == value.pos[chain].size() - 1 else "     ┣"
			)
			equip.line(Rect2(16, 16 + row * 24, 80, 24), label, 16, Palette.color(17))
			var crystal: Variant = value.equip[chain][cell]
			var type = int(value.restrict[chain][cell])
			var name = "未开封"
			var tint = Color(1, 1, 1, 0.5)
			var atlas = Cache.picture("Blastic/结晶孔.png")
			var source = Rect2(0, 0, 16, 16)
			if value.lock[chain][cell]:
				tint = Color.WHITE
				name = "可装入" + ["全", "地", "水", "火", "风", "无"][clampi(type, 0, 5)] + "属性"
				source = Rect2(16 + 16 * type, 0, 16, 16)
				if crystal != null:
					name = str(Presets.native_item(int(crystal), RuntimeState).get("name", ""))
					atlas = Cache.picture("Blastic/equip_slot.png")
					source = Rect2(16 * (int(storage.crystal[str(crystal)][0]) - 1), 0, 16, 16)
			equip.image(atlas, Rect2(96, 20 + row * 24, 16, 16), source, tint)
			equip.line(Rect2(120, 16 + row * 24, 144, 24), name, 16, tint)
	if not page.choosing:
		equip.select(Rect2(96, 18 + page.slot * 24, 160, 20))
	var attr = surface.window("attributes", Rect2(24, 336, 336, 144), Vector2(0, -96))
	var atlas = Cache.picture("Blastic/属性值.png")
	for i in 5:
		attr.image(atlas, Rect2(88 + 48 * i, 32, 24, 24), Rect2([0, 1, 2, 3, 6][i] * 24, 0, 24, 24))
	for chain in 2:
		attr.line(
			Rect2(40, 60 + chain * 32, 32, 32), "主" if chain == 0 else "援", 22, Color.WHITE, 1
		)
		for i in 5:
			var change = int(page.preview_rows[chain][i]) - int(value.element[chain][i])
			var tint = (
				Palette.color(6)
				if change > 0
				else Color8(255, 0, 0, 192) if change < 0 else Color.WHITE
			)
			attr.line(
				Rect2(68 + 48 * i, 60 + chain * 32, 48, 32),
				str(page.preview_rows[chain][i]),
				18,
				tint,
				1
			)
	var echo = surface.window("echo", Rect2(page.size.x - 364, 48, 352, 144), Vector2(0, 96))
	var echoes = surface.window("echo_rows", Rect2(12, 12, 328, 120), Vector2.ZERO, "echo", false)
	page.echo_index = clampi(page.echo_index, 0, maxi(0, page.echo_rows.size() - 1))
	var first = maxi(0, page.echo_index - 1)
	for i in range(first, mini(first + 2, page.echo_rows.size())):
		var row = page.echo_rows[i]
		var y = (i - first) * 56
		echoes.line(
			Rect2(4, y, 304, 28),
			str(row.name),
			18,
			Color.WHITE if row.active else Palette.color(19)
		)
		echoes.line(Rect2(24, y + 28, 288, 24), "角色受到的所有伤害减少0%", 14)
		var n = 0
		for element in range(4, -1, -1):
			if row.required[element] <= 0:
				continue
			var x = 224 - n * 80
			echoes.image(
				Cache.picture("Blastic/回响属性值.png"),
				Rect2(x, y + 6, 16, 16),
				Rect2(element * 16, 0, 16, 16)
			)
			echoes.line(
				Rect2(x + 16, y, 64, 24),
				"%s/%s" % [page.preview_elements[element], row.required[element]],
				16,
				Palette.color(6) if row.active else Color.WHITE,
				2
			)
			n += 1
	if not page.echo_rows.is_empty():
		echoes.select(Rect2(0, (page.echo_index - first) * 56, 312, 56), 3)
	if page.choosing:
		var top = clampf(84 + page.slot * 24, 24, page.size.y - 236)
		var choices = surface.window("candidates", Rect2(248, top, 224, 212), Vector2(32, 0))
		var rows = surface.window(
			"crystal_rows", Rect2(16, 16, 192, 180), Vector2.ZERO, "candidates", false
		)
		var begin = maxi(0, page.candidate_index - 6)
		for i in range(begin, mini(begin + 7, page.candidates.size())):
			var id = int(page.candidates[i])
			var tint = Color.WHITE if page.candidate_allowed(id) else Color(1, 1, 1, 0.5)
			if id == 0:
				rows.line(Rect2(16, (i - begin) * 24, 176, 24), "[卸下回路]", 16, tint)
			else:
				rows.image(
					Cache.picture("Blastic/select_slot.png"),
					Rect2(16, 2 + (i - begin) * 24, 24, 24),
					Rect2((int(storage.crystal[str(id)][0]) - 1) * 24, 0, 24, 24),
					tint
				)
				rows.line(
					Rect2(48, (i - begin) * 24, 128, 24),
					str(Presets.native_item(id, RuntimeState).get("name", "")),
					16,
					tint
				)
				rows.line(
					Rect2(160, (i - begin) * 24, 24, 24),
					str(RuntimeState.inventory_count("item", id)),
					16,
					tint,
					2
				)
		rows.select(Rect2(0, 2 + (page.candidate_index - begin) * 24, 176, 20))
	var desc = surface.window(
		"description", Rect2(24, 496, maxf(256, page.size.x - 48), 72), Vector2(0, 64)
	)
	desc.rich(
		(
			page.notice
			if not page.notice.is_empty()
			else (
				"需要一个拆卸器"
				if page.choosing and page.candidates[page.candidate_index] == 0
				else page.crystal_description
			)
		),
		Rect2(24, 24, desc.size.x - 48, 32),
		16
	)
	page._description_label = desc.rich_label
	surface.finish()
