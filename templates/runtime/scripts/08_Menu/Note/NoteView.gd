## 职责：绘制原笔记双语分类、锁定、独立列表光标和可滚动富文本。
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
	var category = surface.window(
		"category", Rect2(maxf(8, page.size.x - 592), 16, 496, 80), Vector2(0, -64)
	)
	for i in 5:
		category.line(
			Rect2(36 + 96 * i, 24, 64, 32),
			["Help", "Story", "Essay", "Battle", "Book"][i],
			18,
			Color8(192, 192, 160, 160),
			1
		)
		category.line(
			Rect2(16 + 96 * i, 16, 64, 32),
			page.CATEGORIES[i],
			20,
			Color.WHITE if page.enabled(i) else Color(1, 1, 1, 0.5),
			1
		)
	category.line(
		Rect2(16 + 96 * page.category, 16, 64, 32),
		page.CATEGORIES[page.category],
		20,
		Palette.color(4),
		1
	)
	var list = surface.window("list", Rect2(24, 128, 192, 304), Vector2(-64, 0))
	var rows = surface.window("note_rows", Rect2(16, 16, 160, 256), Vector2.ZERO, "list", false)
	var first = maxi(0, page.index - 7)
	for i in range(first, mini(first + 8, page.entries.size())):
		rows.line(Rect2(0, (i - first) * 32, 160, 32), str(page.entries[i]), 20, Color.WHITE, 1)
	if page.selecting and not page.entries.is_empty():
		rows.select(Rect2(4, 2 + (page.index - first) * 32, 144, 28), 2)
	var x = 232.0
	var desc = surface.window(
		"description", Rect2(x, 112, maxf(240, page.size.x - x), 448), Vector2(64, 0)
	)
	var text = surface.window(
		"note_text",
		Rect2(16, 16, maxf(208, desc.size.x - 32), 416),
		Vector2.ZERO,
		"description",
		false
	)
	text.rich(page.description, Rect2(Vector2.ZERO, text.size), 18, page.description_scroll, 1, 32)
	page._text = text.rich_label
	surface.finish()
