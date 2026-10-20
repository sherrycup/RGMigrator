## 职责：按菜单命令创建闪翼具体子页面，集中页面构造与必要依赖。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/Main/MenuPages.gd").方法名(...)。
##
## 调用接口：
##   static func create(command: int, save_callback: Callable) -> Control
##     参数 command（int；必填）：单条事件、界面或路线指令。
##     参数 save_callback（Callable；必填）：请求保存时调用的回调。
##     返回：Control 类型的对象或值，供调用方继续使用。
##
## 公开常量：PAGES。
## 接口说明结束。

extends RefCounted
## Source 0202.update_command: construct only pages with an implemented branch.
## The parent screen owns page signals, focus, lifetime and returning to the map.
const PAGES = {
	0: "res://runtime/scripts/08_Menu/Item/ItemPage.gd",
	1: "res://runtime/scripts/07_Archive/ArchivePage.gd",
	3: "res://runtime/scripts/08_Menu/Note/NotePage.gd",
	4: "res://runtime/scripts/08_Menu/Orbment/BlasticPage.gd",
	7: "res://runtime/scripts/05_Title/ConfigPage.gd",
	8: "res://runtime/scripts/08_Menu/Skill/SkillPage.gd",
}


static func create(command: int, save_callback: Callable) -> Control:
	# Equipment, achievements and crafting remain empty in the final source.
	if not PAGES.has(command):
		return null
	var path: String = PAGES[command]
	if command in [3, 7] and not ResourceLoader.exists(path):
		return null
	var page: Control = load(path).new()
	if command == 1:
		page.save_callback = save_callback
	return page
