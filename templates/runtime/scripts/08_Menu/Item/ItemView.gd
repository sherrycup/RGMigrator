## 职责：读取物品页分类、背包和选择，绘制列表、说明与恢复目标；右侧预设栏复用地图HUD，不重复创建。
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
## 注意：物品栏由地图上同一个FlashPlayerHUD.item_canvas绘制，不在本页创建第二份预设窗口。
## 接口说明结束。

extends RefCounted
const Cache = preload("../../10_Support/Cache/RmxpCache.gd")
const Presets = preload("ItemPresets.gd")
const Service = preload("../../00_Game/InventoryService.gd")
const Palette = preload("../../04_UI_Common/Palette.gd")


static func render(page: Control, surface: Control) -> void:
	surface.begin()
	var category = surface.window(
		"category",
		Rect2(8, 136, 176, mini(5, maxi(1, page.categories.size())) * 32 + 48),
		Vector2(-64, 0)
	)
	var start = maxi(0, page.category_index - 4)
	for i in range(start, mini(start + 5, page.categories.size())):
		category.line(
			Rect2(16, 16 + (i - start) * 32, 144, 32), str(page.categories[i]), 20, Color.WHITE, 1
		)
	if not page.categories.is_empty():
		category.select(Rect2(24, 18 + (page.category_index - start) * 32, 128, 28), 2)
	var list = surface.window("items", Rect2(200, 136, 320, 304), Vector2(0, 64))
	var rows = surface.window("item_rows", Rect2(16, 16, 288, 272), Vector2.ZERO, "items", false)
	var first = maxi(0, page.index - 7)
	for i in range(first, mini(first + 8, page.item_ids.size())):
		var id = int(page.item_ids[i])
		var item = Presets.native_item(id, RuntimeState)
		var tint = Palette.color(int(item.get("color", 0)))
		if not Service.item_reason(id).is_empty():
			tint.a *= 0.5
		rows.image(
			Cache.icon(str(item.get("icon_name", ""))),
			Rect2(24, (i - first) * 32, 32, 32),
			Rect2(),
			tint
		)
		rows.line(Rect2(64, (i - first) * 32, 192, 32), str(item.get("name", "")), 20, tint)
		rows.line(
			Rect2(256, (i - first) * 32, 32, 32),
			str(RuntimeState.inventory_count("item", id)),
			20,
			tint,
			2
		)
	if page.stage == "item" and not page.item_ids.is_empty():
		rows.select(Rect2(8, (page.index - first) * 32 + 2, 280, 28))
	if page.stage != "category":
		var help = surface.window("help", Rect2(8, 512, 176, 128), Vector2(-96, 0))
		help.line(
			Rect2(16, 24, 144, 25),
			"Space:设置" if page.stage == "preset" else "Space:使用物品",
			17,
			Palette.color(17),
			1
		)
		help.line(
			Rect2(16, 64, 144, 25),
			"Q:置空" if page.stage == "preset" else "A:进入物品预设",
			17,
			Palette.color(17),
			1
		)
		var item = Presets.native_item(
			page.active_item if page.stage == "target" else page.selected_id(), RuntimeState
		)
		var y = clampf(176 + (page.index - first) * 32, 8, maxf(8, page.size.y - 208))
		var desc = surface.window("description", Rect2(minf(352, page.size.x - 272), y, 272, 208))
		desc.rich(
			str(item.get("description", "")).get_slice("@", 0),
			Rect2(16, 16, 240, 176),
			18,
			0,
			0,
			32
		)
		page._description = desc.rich_label
	if page.stage == "target":
		surface.party(
			"target",
			Rect2(maxf(8, (page.size.x - 480) / 2), 16, 480, 128),
			page.target_index,
			Vector2(0, -96)
		)
	if not page.notice.is_empty():
		var notice = surface.window(
			"notice", Rect2(200, page.size.y - 64, maxf(200, page.size.x - 216), 56)
		)
		notice.line(Rect2(16, 12, notice.size.x - 32, 32), page.notice, 16, Palette.color(6))
	surface.finish()
