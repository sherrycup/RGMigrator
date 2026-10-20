## 职责：定义事件编辑器的指令分类、参数表单与显示摘要，供指令编写界面使用。
##
## 调用方式：
##   静态接口：preload("res://addons/rgm_editor/03_Event/Editor_Commands.gd").方法名(...)。
##
## 调用接口：
##   static func name_for(code: int) -> String
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func available() -> Array
##     参数：无。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func command(code: int, indent: int = 0, parameters: Array = []) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 indent（int；默认值 0）：事件指令的结构缩进层级。
##     参数 parameters（Array；默认值 []）：按对应接口或事件指令约定排列的参数。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func defaults(code: int) -> Array
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func route_command(code: int = 3) -> Dictionary
##     参数 code（int；默认值 3）：对应指令、按键或操作的编码。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func parameters_for(code: int, p: Array) -> Array
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；必填）：对应事件指令的参数数组。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func variant_parameters(code: int, p: Array, index: int, value: Variant) -> Array
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；必填）：对应事件指令的参数数组。
##     参数 index（int；必填）：集合或列表中的位置索引。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func expand(code: int, p: Array, indent: int) -> Array
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 p（Array；必填）：对应事件指令的参数数组。
##     参数 indent（int；必填）：事件指令的结构缩进层级。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
##   static func span(list: Array, index: int) -> Vector2i
##     参数 list（Array；必填）：待编辑或处理的有序记录列表。
##     参数 index（int；必填）：集合或列表中的位置索引。
##     返回：Vector2i 类型的对象或值，供调用方继续使用。
##
##   static func validate_structure(list: Array) -> String
##     参数 list（Array；必填）：待编辑或处理的有序记录列表。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func summary( c: Dictionary, documents: RefCounted = null, characters: Dictionary = {} ) -> String
##     参数 c（Dictionary；必填）：当前检查的指令或颜色值，类型见签名。
##     参数 documents（RefCounted；默认值 null）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 characters（Dictionary；默认值 {}）：当前地图中可供选择的人物名称与编号信息。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
## 公开常量：SCHEMA、ROUTE_NAMES、MARKERS。
## 接口说明结束。

@tool
extends RefCounted
## Authoring schema only. Execution capability remains in EventCommandCatalog.
const Catalog = preload("res://runtime/scripts/02_Event/EventCommandCatalog.gd")
static var _definitions: Dictionary = JSON.parse_string(SCHEMA)
const SCHEMA := '{"0": {"name": "结束", "defaults": [], "labels": []}, "101": {"name": "显示文章", "defaults": ["请输入文章"], "labels": ["文章"]}, "401": {"name": "文章续行", "defaults": [], "labels": []}, "102": {"name": "显示选项", "defaults": [["是", "否"], 0], "labels": ["选项", "取消类型"]}, "103": {"name": "数值输入", "defaults": [1, 4], "labels": ["变量ID", "位数"]}, "104": {"name": "文章选项", "defaults": [2, 0], "labels": ["位置", "背景"]}, "105": {"name": "按键输入", "defaults": [1], "labels": ["变量ID"]}, "106": {"name": "等待", "defaults": [20], "labels": ["等待（1/20秒）"]}, "108": {"name": "注释", "defaults": [""], "labels": ["注释"]}, "408": {"name": "注释续行", "defaults": [], "labels": []}, "111": {"name": "条件分支", "defaults": [0, 1, 0], "labels": ["条件类型", "开关ID", "开关状态"]}, "112": {"name": "循环", "defaults": [], "labels": []}, "113": {"name": "跳出循环", "defaults": [], "labels": []}, "115": {"name": "结束事件", "defaults": [], "labels": []}, "116": {"name": "暂时删除事件", "defaults": [], "labels": []}, "117": {"name": "调用公共事件", "defaults": [1], "labels": ["公共事件ID"]}, "118": {"name": "标签", "defaults": ["标签"], "labels": ["标签"]}, "119": {"name": "跳转标签", "defaults": ["标签"], "labels": ["标签"]}, "121": {"name": "操作开关", "defaults": [1, 1, 0], "labels": ["起始开关ID", "结束开关ID", "状态"]}, "122": {"name": "操作变量", "defaults": [1, 1, 0, 0, 0], "labels": ["起始变量ID", "结束变量ID", "操作", "操作数类型", "常量"]}, "123": {"name": "操作独立开关", "defaults": ["A", 0], "labels": ["独立开关", "状态"]}, "124": {"name": "操作计时器", "defaults": [0, 60], "labels": ["操作", "秒数"]}, "125": {"name": "增减金钱", "defaults": [0, 0, 1], "labels": ["增减", "数值来源", "数值或变量ID"]}, "126": {"name": "增减物品", "defaults": [1, 0, 0, 1], "labels": ["物品ID", "增减", "数值来源", "数值或变量ID"]}, "127": {"name": "增减武器", "defaults": [1, 0, 0, 1], "labels": ["武器ID", "增减", "数值来源", "数值或变量ID"]}, "128": {"name": "增减防具", "defaults": [1, 0, 0, 1], "labels": ["防具ID", "增减", "数值来源", "数值或变量ID"]}, "129": {"name": "更改队员", "defaults": [1, 0, 0], "labels": ["角色ID", "加入/离开", "初始化"]}, "131": {"name": "更改窗口外观", "defaults": [""], "labels": ["窗口皮肤"]}, "134": {"name": "更改禁止存档", "defaults": [0], "labels": ["禁止/允许"]}, "135": {"name": "更改禁止菜单", "defaults": [0], "labels": ["禁止/允许"]}, "201": {"name": "场所移动", "defaults": [0, 1, 0, 0, 2, 0], "labels": ["坐标来源", "地图ID或变量ID", "X或变量ID", "Y或变量ID", "朝向", "淡化"]}, "202": {"name": "设置事件位置", "defaults": [0, 0, 0, 0, 0], "labels": ["人物ID", "位置方式", "X/变量ID/交换人物ID", "Y或变量ID", "朝向"]}, "203": {"name": "地图滚动", "defaults": [2, 1, 4], "labels": ["方向", "格数", "速度"]}, "204": {"name": "更改地图设置", "defaults": [0, "", 0], "labels": ["类型", "素材名称", "色相"]}, "205": {"name": "更改雾色调", "defaults": [{"_class": "Tone", "red": 0, "green": 0, "blue": 0, "gray": 0}, 20], "labels": ["色调", "时长（1/20秒）"]}, "206": {"name": "更改雾不透明度", "defaults": [255, 20], "labels": ["不透明度", "时长（1/20秒）"]}, "207": {"name": "显示动画", "defaults": [0, 0], "labels": ["人物ID", "动画ID"]}, "208": {"name": "更改玩家透明状态", "defaults": [0], "labels": ["隐藏/显示"]}, "209": {"name": "设置移动路线", "defaults": [0, {"_class": "RPG::MoveRoute", "repeat": false, "skippable": false, "list": [{"code": 0, "parameters": []}]}], "labels": ["人物ID", "移动路线"]}, "210": {"name": "等待移动结束", "defaults": [], "labels": []}, "509": {"name": "路线显示续行", "defaults": [], "labels": []}, "221": {"name": "准备过渡", "defaults": [], "labels": []}, "222": {"name": "执行过渡", "defaults": [""], "labels": ["过渡蒙版（空为普通）"]}, "223": {"name": "更改画面色调", "defaults": [{"_class": "Tone", "red": 0, "green": 0, "blue": 0, "gray": 0}, 20], "labels": ["色调", "时长（1/20秒）"]}, "224": {"name": "画面闪光", "defaults": [{"_class": "Color", "red": 255, "green": 255, "blue": 255, "alpha": 128}, 20], "labels": ["颜色", "时长（1/20秒）"]}, "225": {"name": "画面震动", "defaults": [5, 5, 20], "labels": ["强度", "速度", "时长（1/20秒）"]}, "231": {"name": "显示图片", "defaults": [1, "", 0, 0, 0, 0, 100, 100, 255, 0], "labels": ["图片编号", "图片名称", "原点", "坐标来源", "X或变量ID", "Y或变量ID", "X缩放%", "Y缩放%", "不透明度", "混合"]}, "232": {"name": "移动图片", "defaults": [1, 20, 0, 0, 0, 0, 100, 100, 255, 0], "labels": ["图片编号", "时长（1/20秒）", "原点", "坐标来源", "X或变量ID", "Y或变量ID", "X缩放%", "Y缩放%", "不透明度", "混合"]}, "233": {"name": "旋转图片", "defaults": [1, 5], "labels": ["图片编号", "旋转速度"]}, "234": {"name": "更改图片色调", "defaults": [1, {"_class": "Tone", "red": 0, "green": 0, "blue": 0, "gray": 0}, 20], "labels": ["图片编号", "色调", "时长（1/20秒）"]}, "235": {"name": "删除图片", "defaults": [1], "labels": ["图片编号"]}, "236": {"name": "更改天候", "defaults": [0, 5, 40], "labels": ["天气", "强度", "时长（1/40秒）"]}, "241": {"name": "演奏BGM", "defaults": [{"_class": "RPG::AudioFile", "name": "", "volume": 100, "pitch": 100}], "labels": ["BGM"]}, "242": {"name": "淡出BGM", "defaults": [1], "labels": ["秒数"]}, "245": {"name": "演奏BGS", "defaults": [{"_class": "RPG::AudioFile", "name": "", "volume": 100, "pitch": 100}], "labels": ["BGS"]}, "246": {"name": "淡出BGS", "defaults": [1], "labels": ["秒数"]}, "247": {"name": "记忆BGM/BGS", "defaults": [], "labels": []}, "248": {"name": "还原BGM/BGS", "defaults": [], "labels": []}, "249": {"name": "演奏ME", "defaults": [{"_class": "RPG::AudioFile", "name": "", "volume": 100, "pitch": 100}], "labels": ["ME"]}, "250": {"name": "演奏SE", "defaults": [{"_class": "RPG::AudioFile", "name": "", "volume": 100, "pitch": 100}], "labels": ["SE"]}, "251": {"name": "停止SE", "defaults": [], "labels": []}, "302": {"name": "商店处理", "defaults": [0, 1], "labels": ["商品类型", "商品ID"]}, "605": {"name": "商品续行", "defaults": [], "labels": []}, "303": {"name": "姓名输入", "defaults": [1, 8], "labels": ["角色ID", "最大字符数"]}, "311": {"name": "增减HP", "defaults": [0, 0, 0, 1, false], "labels": ["角色ID（0为全体）", "增减", "数值来源", "数值或变量ID", "允许死亡"]}, "312": {"name": "增减SP", "defaults": [0, 0, 0, 1], "labels": ["角色ID（0为全体）", "增减", "数值来源", "数值或变量ID"]}, "313": {"name": "更改状态", "defaults": [0, 0, 1], "labels": ["角色ID（0为全体）", "附加/解除", "状态ID"]}, "314": {"name": "全回复", "defaults": [0], "labels": ["角色ID（0为全体）"]}, "315": {"name": "增减经验", "defaults": [0, 0, 0, 1], "labels": ["角色ID（0为全体）", "增减", "数值来源", "数值或变量ID"]}, "316": {"name": "增减等级", "defaults": [0, 0, 0, 1], "labels": ["角色ID（0为全体）", "增减", "数值来源", "数值或变量ID"]}, "317": {"name": "增减能力值", "defaults": [1, 0, 0, 0, 1], "labels": ["角色ID", "能力", "增减", "数值来源", "数值或变量ID"]}, "318": {"name": "增减特技", "defaults": [1, 0, 1], "labels": ["角色ID", "学习/遗忘", "特技ID"]}, "319": {"name": "更改装备", "defaults": [1, 0, 0], "labels": ["角色ID", "槽位", "装备ID（0卸下）"]}, "320": {"name": "更改角色姓名", "defaults": [1, "新姓名"], "labels": ["角色ID", "姓名"]}, "321": {"name": "更改职业", "defaults": [1, 1], "labels": ["角色ID", "职业ID"]}, "322": {"name": "更改角色图形", "defaults": [1, "", 0, "", 0], "labels": ["角色ID", "行走图", "行走图色相", "战斗图（仅保留）", "战斗图色相"]}, "351": {"name": "打开菜单", "defaults": [], "labels": []}, "352": {"name": "打开存档", "defaults": [], "labels": []}, "353": {"name": "游戏结束", "defaults": [], "labels": []}, "354": {"name": "返回标题", "defaults": [], "labels": []}, "402": {"name": "选项分支", "defaults": [], "labels": []}, "403": {"name": "取消分支", "defaults": [], "labels": []}, "404": {"name": "选项结束", "defaults": [], "labels": []}, "411": {"name": "否则", "defaults": [], "labels": []}, "412": {"name": "条件结束", "defaults": [], "labels": []}, "413": {"name": "循环结束", "defaults": [], "labels": []}, "355": {"name": "脚本", "defaults": [""], "labels": ["GDScript业务代码"]}, "655": {"name": "脚本续行", "defaults": [""], "labels": ["脚本续行（已合并至首条）"]}}'

const ROUTE_NAMES := [
	"结束",
	"向下移动",
	"向左移动",
	"向右移动",
	"向上移动",
	"向左下移动",
	"向右下移动",
	"向左上移动",
	"向右上移动",
	"随机移动",
	"接近玩家",
	"远离玩家",
	"前进",
	"后退",
	"跳跃",
	"等待",
	"朝下",
	"朝左",
	"朝右",
	"朝上",
	"右转90°",
	"左转90°",
	"转180°",
	"随机左/右转",
	"随机方向",
	"朝向玩家",
	"背向玩家",
	"开关ON",
	"开关OFF",
	"改变速度",
	"改变频度",
	"行走动画ON",
	"行走动画OFF",
	"踏步动画ON",
	"踏步动画OFF",
	"固定方向ON",
	"固定方向OFF",
	"穿透ON",
	"穿透OFF",
	"置顶ON",
	"置顶OFF",
	"更改图形",
	"不透明度",
	"混合方式",
	"演奏SE",
	"脚本"
]
const MARKERS := [0, 401, 408, 402, 403, 404, 411, 412, 413, 509, 605, 655]


static func name_for(code: int) -> String:
	return str(_definitions.get(str(code), {}).get("name", "未接入指令 [%d]" % code))


static func available() -> Array:
	var result: Array = []
	for key in _definitions:
		var code = int(key)
		if code not in MARKERS and code in Catalog.SUPPORTED:
			result.append(code)
	result.sort()
	return result


static func command(code: int, indent: int = 0, parameters: Array = []) -> Dictionary:
	return {
		"_class": "RPG::EventCommand",
		"code": code,
		"indent": indent,
		"parameters": parameters.duplicate(true)
	}


static func defaults(code: int) -> Array:
	if code == 355:
		return [preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").template()]
	return _canonical(_definitions.get(str(code), {}).get("defaults", []))


static func route_command(code: int = 3) -> Dictionary:
	var p: Array = []
	match code:
		14:
			p = [0, 0]
		15:
			p = [20]
		27, 28:
			p = [1]
		29, 30:
			p = [4]
		41:
			p = ["", 0, 2, 0]
		42:
			p = [255]
		43:
			p = [0]
		44:
			p = [{"_class": "RPG::AudioFile", "name": "", "volume": 100, "pitch": 100}]
		45:
			p = [preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").template()]
	var command = {"_class": "RPG::MoveCommand", "code": code, "parameters": p}
	if code == 45:
		command._script_binding = (
			preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").binding(str(p[0]))
		)
	return command


static func parameters_for(code: int, p: Array) -> Array:
	var labels: Array = _definitions.get(str(code), {}).get("labels", []).duplicate()
	if code == 111:
		labels = (
			{
				0: ["条件类型", "开关ID", "状态"],
				1: ["条件类型", "变量ID", "比较来源", "比较值或变量ID", "比较"],
				2: ["条件类型", "独立开关", "状态"],
				3: ["条件类型", "秒数", "比较"],
				4: ["条件类型", "角色ID", "角色条件", "条件值"],
				6: ["条件类型", "人物ID", "朝向"],
				7: ["条件类型", "金钱", "比较"],
				8: ["条件类型", "物品ID"],
				9: ["条件类型", "武器ID"],
				10: ["条件类型", "防具ID"],
				11: ["条件类型", "按键"],
				12: ["条件类型", "GDScript 条件"]
			}
			. get(int(p[0]) if not p.is_empty() else 0, ["条件类型"])
		)
	if code == 122:
		labels = ["起始变量ID", "结束变量ID", "操作", "操作数类型"]
		labels.append_array(
			(
				{
					0: ["常量"],
					1: ["变量ID"],
					2: ["随机下限", "随机上限"],
					3: ["物品ID"],
					4: ["角色ID", "角色数据"],
					6: ["人物ID", "人物数据"],
					7: ["其他数据"]
				}
				. get(int(p[3]) if p.size() > 3 else 0, ["值"])
			)
		)
	if code == 204 and not p.is_empty() and int(p[0]) == 1:
		labels = ["类型", "素材名称", "色相", "不透明度", "混合", "缩放%", "横向速度", "纵向速度"]
	return labels


static func variant_parameters(code: int, p: Array, index: int, value: Variant) -> Array:
	var result = p.duplicate(true)
	result[index] = value
	if code == 111 and index == 0:
		result = (
			{
				0: [0, 1, 0],
				1: [1, 1, 0, 0, 0],
				2: [2, "A", 0],
				3: [3, 0, 0],
				4: [4, 1, 0],
				6: [6, 0, 2],
				7: [7, 0, 0],
				8: [8, 1],
				9: [9, 1],
				10: [10, 1],
				11: [11, 11],
				12:
				[12, preload("res://runtime/scripts/02_Event/NativeScriptSource.gd").template(true)]
			}
			. get(int(value), result)
			. duplicate(true)
		)
	if code == 111 and index == 2 and int(result[0]) == 4:
		result.resize(3 if int(value) == 0 else 4)
		if result.size() == 4:
			result[3] = "" if int(value) == 1 else 1
	if code == 122 and index == 3:
		result = result.slice(0, 4)
		result.append_array(
			{0: [0], 1: [1], 2: [0, 1], 3: [1], 4: [1, 0], 6: [0, 0], 7: [0]}.get(int(value), [0])
		)
	if code == 204 and index == 0:
		result = [0, "", 0] if int(value) == 0 else [1, "", 0, 255, 0, 100, 0, 0]
	return result


static func expand(code: int, p: Array, indent: int) -> Array:
	var result: Array = [command(code, indent, p)]
	if code in [101, 108]:
		var lines = str(p[0]).split("\n", true)
		result[0].parameters = [lines[0]]
		for i in range(1, lines.size()):
			result.append(command(401 if code == 101 else 408, indent, [lines[i]]))
	if code == 102:
		for i in p[0].size():
			result.append(command(402, indent, [i, p[0][i]]))
		if int(p[1]) == 5:
			result.append(command(403, indent))
		result.append(command(404, indent))
	if code == 111:
		result.append_array([command(411, indent), command(412, indent)])
	if code == 112:
		result.append(command(413, indent))
	# 209 keeps the immutable route in its own payload; redundant 509 is optional.
	return result


static func span(list: Array, index: int) -> Vector2i:
	if index < 0 or index >= list.size():
		return Vector2i(-1, -1)
	var c: Dictionary = list[index]
	var code = int(c.get("code", 0))
	var indent = int(c.get("indent", 0))
	var end = index + 1
	if code == 355 and c.has("_script_binding"):
		var count := int(c._script_binding.get("command_count", 1))
		if count > 0 and index + count <= list.size():
			return Vector2i(index, index + count)
	if code in [102, 111, 112]:
		var closing = {102: 404, 111: 412, 112: 413}[code]
		while end < list.size():
			if (
				int(list[end].get("code", 0)) == closing
				and int(list[end].get("indent", 0)) == indent
			):
				return Vector2i(index, end + 1)
			end += 1
		return Vector2i(-1, -1)
	var continuation: int = {101: 401, 108: 408, 209: 509, 302: 605, 355: 655}.get(code, -1)
	while continuation >= 0 and end < list.size() and int(list[end].get("code", 0)) == continuation:
		end += 1
	return Vector2i(index, end)


static func validate_structure(list: Array) -> String:
	if (
		list.is_empty()
		or not list[-1] is Dictionary
		or int(list[-1].get("code", -1)) != 0
		or int(list[-1].get("indent", -1)) != 0
	):
		return "事件缺少末尾结束标记。"
	var stack: Array = []
	for i in list.size():
		var c: Variant = list[i]
		if not c is Dictionary or not c.get("parameters", []) is Array:
			return "第%d条指令格式无效。" % (i + 1)
		var code = int(c.get("code", -1))
		var indent = int(c.get("indent", -1))
		if indent < 0:
			return "第%d条缩进无效。" % (i + 1)
		if code in [102, 111, 112]:
			stack.append(
				{"code": code, "indent": indent, "branches": [], "cancel": false, "else": false}
			)
		elif code in [402, 403, 404, 411, 412, 413]:
			var required: int = {402: 102, 403: 102, 404: 102, 411: 111, 412: 111, 413: 112}[code]
			if stack.is_empty() or stack[-1].code != required or stack[-1].indent != indent:
				return "第%d条分支标记没有对应的开始。" % (i + 1)
			if code == 402:
				if (
					c.parameters.size() != 2
					or not c.parameters[0] is float and not c.parameters[0] is int
					or int(c.parameters[0]) in stack[-1].branches
				):
					return "选项分支编号无效或重复。"
				stack[-1].branches.append(int(c.parameters[0]))
			if code == 403:
				if stack[-1].cancel:
					return "取消分支重复。"
				stack[-1].cancel = true
			if code == 411:
				if stack[-1].else:
					return "否则分支重复。"
				stack[-1].else = true
			if code in [404, 412, 413]:
				stack.pop_back()
	if not stack.is_empty():
		return "条件、选项或循环没有结束。"
	return ""


static func summary(
	c: Dictionary, documents: RefCounted = null, characters: Dictionary = {}
) -> String:
	var code = int(c.get("code", 0))
	var p: Variant = c.get("parameters", [])
	var name = name_for(code)
	var native = preload("res://runtime/scripts/02_Event/NativeScriptSource.gd")
	if native.is_native(c.get("_script_binding")) and code in [355, 111]:
		return (
			("如果（GDScript）：" if code == 111 else "脚本（GDScript）：")
			+ native.preview(str(p[1] if code == 111 else p[0]))
		)
	if c.has("_editor_original"):
		return (
			"Ruby脚本占位（原代码保留）："
			+ str(p[0] if p is Array and not p.is_empty() else "").replace("\n", " ↵ ")
		)
	if not p is Array:
		return name + "（参数格式无效；原始数据保留）"
	if code in [108, 408] and (p.size() != 1 or not p[0] is String):
		return name + "（原始参数保留）"
	if code == 402 and (p.size() != 2 or not (p[0] is int or p[0] is float) or not p[1] is String):
		return name + "（原始参数保留）"
	if not Catalog.reason(code, p).is_empty():
		return name + "（未支持或参数无效；原始数据保留）"
	if code == 509:
		var action: Dictionary = p[0]
		var route_code = int(action.code)
		return preload("../07_Common/Editor_Presentation.gd").route_summary(
			route_code, action.get("parameters", []), ROUTE_NAMES[route_code], documents
		)
	var text = preload("../07_Common/Editor_Presentation.gd").summary(
		code, p, name, documents, characters
	)
	if code == 209:
		var actions: Array = p[1].get("list", []).filter(
			func(action): return int(action.get("code", 0)) != 0
		)
		var parts: Array[String] = []
		var index = 0
		while index < actions.size() and parts.size() < 4:
			var action: Dictionary = actions[index]
			var action_code = int(action.code)
			var next = index + 1
			if action_code in [1, 2, 3, 4, 5, 6, 7, 8, 12, 13]:
				while next < actions.size() and int(actions[next].code) == action_code:
					next += 1
			var detail = preload("../07_Common/Editor_Presentation.gd").route_summary(
				action_code, action.get("parameters", []), ROUTE_NAMES[action_code], documents
			)
			parts.append(detail + ("%d步" % (next - index) if next - index > 1 else ""))
			index = next
		if index < actions.size():
			parts.append("…")
		if not parts.is_empty():
			text += "；" + " → ".join(parts)
	return text


static func _canonical(value: Variant) -> Variant:
	if value is float and floor(value) == value:
		return int(value)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _canonical(value[key])
		return result
	return value
