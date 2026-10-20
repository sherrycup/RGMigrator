## 职责：绘制闪翼原商店命令、买卖列表、数量与所持信息，成交仍由ShopService校验。
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
const Service = preload("ShopService.gd")


static func render(page: Control, surface: Control) -> void:
	surface.begin()
	var help = surface.window("help", Rect2(0, 0, page.size.x, 64))
	var item: Dictionary = (
		page._entries[page.selected]
		if not page._entries.is_empty() and page.mode != "commands"
		else {}
	)
	help.rich(
		page.message if not page.message.is_empty() else str(item.get("description", "")),
		Rect2(16, 16, page.size.x - 32, 32),
		18
	)
	var commands = surface.window("commands", Rect2(0, 64, page.size.x - 160, 64))
	var type = int(RuntimeState.flash_temp_fields.get("shop_type", 0))
	for i in 3 if type == 0 else 0:
		commands.line(Rect2(20 + i * 148, 16, 128, 32), ["购买", "卖出", "离开"][i], 21)
	if type > 0:
		commands.line(
			Rect2(20, 16, commands.size.x - 40, 32), "请选择您要购买的物品" if type == 1 else "请选择您要出售的物品", 21
		)
	elif page.mode == "commands":
		commands.select(Rect2(16 + page.command_index * 148, 16, 140, 32), 2)
	var gold = surface.window("gold", Rect2(page.size.x - 160, 64, 160, 64))
	gold.line(Rect2(16, 16, 128, 32), str(RuntimeState.gold), 20, Palette.color(12), 2)
	if page.mode == "commands":
		surface.window("dummy", Rect2(0, 128, page.size.x, 352))
		surface.finish()
		return
	var selling = page.mode == "sell" or page.mode == "number" and page._number_mode == "sell"
	var columns = 2 if selling and page.mode != "number" else 1
	var panel = surface.window("list", Rect2(0, 128, page.size.x if columns == 2 else 368, 352))
	if page.mode == "number":
		panel.image(Cache.icon(str(item.get("icon_name", ""))), Rect2(20, 112, 32, 32))
		panel.line(Rect2(60, 112, 208, 32), str(item.get("name", "")), 20)
		panel.line(Rect2(272, 112, 64, 32), "× %d" % page.quantity, 20, Color.WHITE, 2)
		panel.select(Rect2(304, 112, 40, 32), 2)
		panel.line(
			Rect2(20, 176, 312, 32),
			str(page.quantity * int(page._quote.get("unit_price", 0))),
			20,
			Palette.color(12),
			2
		)
		panel.line(Rect2(20, 256, 312, 48), "↑↓±10  ←→±1\n空格确认  Esc取消", 16, Palette.color(17), 1)
	else:
		var rows = surface.window(
			"rows", Rect2(16, 16, panel.size.x - 32, 320), Vector2.ZERO, "list", false
		)
		var first = maxi(0, int(page.selected / columns) - 8)
		var width = rows.size.x / columns
		page._scroll_rows["sell" if selling else "buy"] = first
		for i in range(first * columns, mini((first + 10) * columns, page._entries.size())):
			var row: Dictionary = page._entries[i]
			var quote = (
				Service.quote_sell(RuntimeState, row.kind, row.id)
				if selling
				else Service.quote_buy(RuntimeState, page.goods, row.kind, row.id)
			)
			var tint = Color.WHITE if quote.ok and quote.maximum > 0 else Color(1, 1, 1, 0.5)
			var point = Vector2((i % columns) * width, (int(i / columns) - first) * 32)
			rows.image(
				Cache.icon(str(row.get("icon_name", ""))),
				Rect2(point + Vector2(4, 0), Vector2(32, 32)),
				Rect2(),
				tint
			)
			rows.line(
				Rect2(point + Vector2(44, 0), Vector2(width - 128, 32)), str(row.name), 20, tint
			)
			rows.line(
				Rect2(point + Vector2(width - 80, 0), Vector2(76, 32)),
				(
					str(RuntimeState.inventory_count(row.kind, row.id))
					if selling
					else str(row.get("price", 0))
				),
				18,
				tint,
				2
			)
		if not page._entries.is_empty():
			rows.select(
				Rect2(
					(page.selected % columns) * width,
					(int(page.selected / columns) - first) * 32,
					width,
					32
				),
				2
			)
	if columns == 1:
		var status = surface.window("status", Rect2(368, 128, maxf(240, page.size.x - 368), 352))
		if not item.is_empty():
			status.line(Rect2(20, 16, 144, 32), "所持数", 20, Palette.color(17))
			status.line(
				Rect2(164, 16, status.size.x - 180, 32),
				str(RuntimeState.inventory_count(item.kind, item.id)),
				20,
				Color.WHITE,
				2
			)
			if item.kind != "item":
				for i in mini(3, RuntimeState.party.size()):
					var actor = RuntimeState.actor(int(RuntimeState.party[i]))
					status.line(
						Rect2(20, 80 + 64 * i, status.size.x - 40, 32), actor.actor_name, 18
					)
					var slot = 0 if item.kind == "weapon" else 2
					var current = RuntimeState.custom_data.record(
						"Weapons" if item.kind == "weapon" else "Armors", int(actor.equipment[slot])
					)
					status.line(
						Rect2(20, 112 + 64 * i, status.size.x - 40, 32),
						str(current.get("name", "—")),
						16,
						Palette.color(17)
					)
	surface.finish()
