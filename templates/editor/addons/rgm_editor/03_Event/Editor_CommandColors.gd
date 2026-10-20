## 职责：统一事件指令的分类颜色与显示样式，供事件列表和菜单共用。
##
## 调用方式：
##   静态接口：preload("res://addons/rgm_editor/03_Event/Editor_CommandColors.gd").方法名(...)。
##
## 调用接口：
##   static func group(code: int, route: bool = false) -> String
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 route（bool；默认值 false）：人物移动路线数据。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func apply( tree: Tree, row: TreeItem, code: int, unsupported: bool = false, route: bool = false ) -> void
##     用途：应用已选定或已准备的修改。
##     参数 tree（Tree；必填）：树形控件或语法树数据。
##     参数 row（TreeItem；必填）：当前列表行、文本行或记录。
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 unsupported（bool；默认值 false）：未支持的指令、字段或来源集合。
##     参数 route（bool；默认值 false）：人物移动路线数据。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 公开常量：DARK、LIGHT。
## 接口说明结束。

@tool
extends RefCounted
## Shared command classification and colors, independent of native payloads.
const DARK = {
	"text": "8ed9ff",
	"flow": "b5b8ff",
	"state": "f2be72",
	"move": "8ed6a5",
	"screen": "d6a9f0",
	"audio": "80ddd1",
	"actor": "f3afc4",
	"inventory": "ead27b",
	"scene": "c4d0e8",
	"comment": "9eb9a3",
	"unsupported": "eeaa86",
	"end": "939cae"
}
const LIGHT = {
	"text": "075f88",
	"flow": "493a9b",
	"state": "805010",
	"move": "21653d",
	"screen": "71348b",
	"audio": "006a62",
	"actor": "963859",
	"inventory": "705800",
	"scene": "3f506d",
	"comment": "466447",
	"unsupported": "a03e17",
	"end": "596171"
}


static func group(code: int, route: bool = false) -> String:
	if code == 0:
		return "end"
	if route:
		if code in [27, 28]:
			return "state"
		if code == 44:
			return "audio"
		if code == 45:
			return "unsupported"
		return "move"
	if code in [108, 408]:
		return "comment"
	if code in [355, 655]:
		return "unsupported"
	if code in [101, 103, 104, 105, 401]:
		return "text"
	if code in [102, 106, 111, 112, 113, 115, 117, 118, 119, 402, 403, 404, 411, 412, 413]:
		return "flow"
	if code in [121, 122, 123, 124, 134, 135]:
		return "state"
	if code in [201, 202, 203, 208, 209, 210, 509, 116]:
		return "move"
	if code >= 204 and code <= 207 or code >= 221 and code <= 236:
		return "screen"
	if code >= 241 and code <= 251:
		return "audio"
	if code >= 125 and code <= 128 or code in [302, 605]:
		return "inventory"
	if code == 129 or code >= 303 and code <= 322:
		return "actor"
	return "scene"


static func apply(
	tree: Tree, row: TreeItem, code: int, unsupported: bool = false, route: bool = false
) -> void:
	var light = tree.get_theme_color("font_color").get_luminance() < 0.5
	var palette = LIGHT if light else DARK
	row.set_custom_color(0, Color(palette["unsupported" if unsupported else group(code, route)]))
	if tree.columns > 1 and unsupported:
		row.set_custom_color(1, Color(palette.unsupported))
	# Selection remains high contrast, including category-colored rows.
	var style = tree.get_theme_stylebox("selected")
	var background = style.bg_color if style is StyleBoxFlat else Color("35609a")
	var selected = Color("171b22") if background.get_luminance() > 0.45 else Color.WHITE
	if tree.get_theme_color("font_selected_color") != selected:
		tree.add_theme_color_override("font_selected_color", selected)
