extends RefCounted
## Copied to the generated runtime; importer and execution share capability rules.
const SUPPORTED := [355,655,0, 101, 401, 102, 103, 104, 105, 106, 108, 408, 111, 112, 113, 115, 116, 117, 118, 119, 121, 122, 123, 124, 125, 126, 127, 128, 129, 134, 135, 131, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 509, 221, 222, 223, 224, 225, 231, 232, 233, 234, 235, 236, 241, 242, 245, 246, 247, 248, 249, 250, 251, 302, 303, 351, 352, 353, 354, 605, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 402, 403, 404, 411, 412, 413]
const BATTLE := [132, 133, 136, 301, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 601, 602, 603, 604]

static func reason(code: int, parameters: Array = []) -> String:
	if code in [355,655] and (parameters.size()!=1 or not parameters[0] is String): return "脚本指令须包含原文字符串和迁移绑定。"
	if code in BATTLE: return "原生回合制战斗事件不在迁移范围；魔塔结算后续通过公共事件接入"
	if code in [221, 222, 223, 224, 225, 231, 232, 233, 234, 235, 236]: return _screen_reason(code, parameters)
	if code in [131, 203, 204, 205, 206, 241, 242, 245, 246, 247, 248, 249, 250, 251]: return _presentation_reason(code, parameters)
	if code in [129, 135, 303, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 351, 352, 353, 354]: return _actor_scene_reason(code, parameters)
	if code == 134 and (parameters.size() != 1 or not _integer(parameters[0], 0, 1)): return "禁止存档参数须为0禁止/1允许。"
	if code == 106:
		if parameters.size() != 1 or not _integer(parameters[0], 0, 999): return "等待参数须为0..999的整数（原生单位1/20秒）"
	if code in [101, 401] and (parameters.size() != 1 or not parameters[0] is String): return "文章参数须为一段文本"
	if code == 102:
		if parameters.size() != 2 or not parameters[0] is Array or parameters[0].is_empty() or parameters[0].size() > 4 or not _integer(parameters[1], 0, 5): return "选择项参数无效（1..4项，取消类型0..5）"
		for choice in parameters[0]:
			if not choice is String: return "选择项须为文本"
		if int(parameters[1]) in [1, 2, 3, 4] and int(parameters[1]) > parameters[0].size(): return "取消目标超出选择项范围"
	if code == 103 and (parameters.size() != 2 or not _id(parameters[0]) or not _integer(parameters[1], 1, 8)): return "数值输入须指定变量和1..8位"
	if code == 104 and (parameters.size() != 2 or not _integer(parameters[0], 0, 2) or not _integer(parameters[1], 0, 1)): return "文章选项须指定位置0..2和窗口0..1"
	if code == 105 and (parameters.size() != 1 or not _id(parameters[0])): return "按键输入须指定有效变量"
	if code == 111: return _condition_reason(parameters)
	if code == 121 and (parameters.size() != 3 or not _range(parameters) or not _integer(parameters[2], 0, 1)): return "开关范围或操作无效"
	if code == 122: return _variable_reason(parameters)
	if code == 123 and (parameters.size() != 2 or parameters[0] not in ["A", "B", "C", "D"] or not _integer(parameters[1], 0, 1)): return "独立开关参数无效"
	if code == 124:
		if parameters.size() not in [1,2] or not _integer(parameters[0],0,1): return "计时器须指定开始/停止"
		if int(parameters[0])==0 and parameters.size()!=2: return "开始计时器须指定有效秒数"
		if parameters.size()==2 and not _integer(parameters[1],0,359999): return "计时器秒数无效"
	if code == 125 and not _amount(parameters): return "金钱增减参数无效"
	if code in [126, 127, 128] and (parameters.size() != 4 or not _id(parameters[0]) or not _amount(parameters.slice(1))): return "物品增减参数无效"
	if code == 201:
		if parameters.size() != 6 or not _integer(parameters[0], 0, 1) or not _id(parameters[1]) or not _direction(parameters[4], true) or not _integer(parameters[5], 0, 1): return "场所移动须指定方式、地图、坐标、方向及淡化选项"
		if not (_integer(parameters[2], 0, 1000000) and _integer(parameters[3], 0, 1000000) if int(parameters[0]) == 0 else _id(parameters[2]) and _id(parameters[3])): return "场所移动坐标或变量无效"
	if code == 202:
		if parameters.size() != 5 or not _target(parameters[0]) or not _integer(parameters[1], 0, 2) or not _direction(parameters[4], true): return "设置事件位置参数无效"
		match int(parameters[1]):
			0: if not _integer(parameters[2], 0, 1000000) or not _integer(parameters[3], 0, 1000000): return "事件坐标无效"
			1: if not _id(parameters[2]) or not _id(parameters[3]): return "事件坐标变量无效"
			2: if not _target(parameters[2]) or not _integer(parameters[3], 0, 0): return "事件交换目标无效"
	if code == 207 and (parameters.size() != 2 or not _target(parameters[0]) or not _integer(parameters[1], 0, 1000000)): return "显示动画须指定人物及动画ID（0为空动画）"
	if code == 208 and (parameters.size() != 1 or not _integer(parameters[0], 0, 1)): return "透明状态须为0隐藏、1显示"
	if code == 209:
		if parameters.size() != 2 or not _target(parameters[0]): return "移动路线须指定人物和路线"
		var validation := route_validation(parameters[1])
		if not validation.ok: return "移动路线第%d条：%s" % [validation.get("route_index", 0), validation.message]
	if code == 210 and not parameters.is_empty(): return "等待移动结束没有参数"
	if code == 509:
		if parameters.size() != 1 or not parameters[0] is Dictionary: return "移动路线续行须包含一条路线指令"
		if not _integer(parameters[0].get("code", -1), 0, 45) or not parameters[0].get("parameters", []) is Array: return "移动路线续行格式无效"
		return route_reason(int(parameters[0].get("code", -1)), parameters[0].get("parameters", []))
	if code not in SUPPORTED: return "事件指令尚未接入"
	return ""

static func supported(code: int, parameters: Array = []) -> bool:
	return reason(code, parameters).is_empty()

static func color_values(value: Variant, tone: bool = true) -> Array:
	var parts: Array = []
	if value is Array: parts = value
	elif value is Dictionary:
		if value.get("_class", "Tone" if tone else "Color") != ("Tone" if tone else "Color"): return []
		for key in ["red", "green", "blue", "gray" if tone else "alpha"]: parts.append(value.get(key))
	if parts.size() != 4: return []
	for index in 4:
		if not _numeric(parts[index], -255 if tone and index < 3 else 0, 255): return []
	return parts.duplicate()

static func _screen_reason(code: int, p: Array) -> String:
	match code:
		221: if not p.is_empty(): return "准备过渡没有参数"
		222: if p.size() != 1 or not _asset_name(p[0]): return "执行过渡只接受Transitions名称（空名称为普通淡化）"
		223, 224:
			if p.size() != 2 or color_values(p[0], code == 223).is_empty() or not _integer(p[1], 0, 999): return "画面色调/闪光及原生时长无效"
		225: if p.size() != 3 or not _integer(p[0], 0, 9) or not _integer(p[1], 0, 9) or not _integer(p[2], 0, 999): return "震动须指定原生强度/速度0..9及时长0..999"
		231, 232:
			if p.size() != 10 or not _integer(p[0], 1, 50) or not _integer(p[2], 0, 1) or not _integer(p[3], 0, 1): return "图片编号/原点/坐标方式无效"
			if (not _asset_name(p[1])) if code == 231 else (not _integer(p[1], 0, 999)): return "图片名称或移动时长无效"
			if not (_integer(p[4], -1000000, 1000000) and _integer(p[5], -1000000, 1000000) if int(p[3]) == 0 else _id(p[4]) and _id(p[5])): return "图片坐标或变量ID无效"
			if not _integer(p[6], 0, 10000) or not _integer(p[7], 0, 10000) or not _integer(p[8], 0, 255) or not _integer(p[9], 0, 2): return "图片缩放/不透明度/合成方式无效"
		233: if p.size() != 2 or not _integer(p[0], 1, 50) or not _integer(p[1], -90, 90): return "图片旋转编号或速度无效"
		234: if p.size() != 3 or not _integer(p[0], 1, 50) or color_values(p[1]).is_empty() or not _integer(p[2], 0, 999): return "图片色调编号/色调/时长无效"
		235: if p.size() != 1 or not _integer(p[0], 1, 50): return "删除图片须指定编号1..50"
		236: if p.size() != 3 or not _integer(p[0], 0, 3) or not _integer(p[1], 0, 9) or not _integer(p[2], 0, 999): return "天候须指定类型0..3、强度0..9和原生时长0..999"
	return ""

static func _presentation_reason(code: int, p: Array) -> String:
	match code:
		131: if p.size() != 1 or not _asset_name(p[0]): return "窗口外观须指定Windowskins名称"
		203: if p.size() != 3 or not _direction(p[0]) or not _integer(p[1], 0, 1000) or not _integer(p[2], 1, 6): return "滚图须指定方向、格数0..1000及原生速度1..6"
		204:
			if p.is_empty() or not _integer(p[0], 0, 2): return "地图设置类型无效"
			if int(p[0]) == 2: return "地图战斗背景属于原生回合制战斗，不在迁移范围"
			if p.size() != (3 if int(p[0]) == 0 else 8) or not _asset_name(p[1]) or not _integer(p[2], 0, 360): return "全景/雾名称及色相无效"
			if int(p[0]) == 1 and (not _integer(p[3], 0, 255) or not _integer(p[4], 0, 2) or not _integer(p[5], 1, 10000) or not _integer(p[6], -10000, 10000) or not _integer(p[7], -10000, 10000)): return "雾不透明度、混合、缩放或滚动参数无效"
		205: if p.size() != 2 or color_values(p[0]).is_empty() or not _integer(p[1], 0, 999): return "雾色调或原生时长无效"
		206: if p.size() != 2 or not _integer(p[0], 0, 255) or not _integer(p[1], 0, 999): return "雾不透明度或原生时长无效"
		241, 245, 249, 250:
			if p.size() != 1 or not p[0] is Dictionary or not _asset_name(p[0].get("name")) or not _integer(p[0].get("volume"), 0, 100) or not _integer(p[0].get("pitch"), 50, 150): return "音频须指定名称、音量0..100和音调50..150"
		242, 246: if p.size() != 1 or not _integer(p[0], 0, 60): return "音频淡出须指定0..60秒"
		247, 248, 251: if not p.is_empty(): return "记忆/还原音频与停止SE没有参数"
	return ""

static func _actor_scene_reason(code: int, p: Array) -> String:
	match code:
		129: if p.size() != 3 or not _id(p[0]) or not _integer(p[1], 0, 1) or not _integer(p[2], 0, 1): return "队员变更须指定角色、加入/离开与初始化选项"
		135: if p.size() != 1 or not _integer(p[0], 0, 1): return "禁止菜单须为0禁止、1允许"
		303: if p.size() != 2 or not _id(p[0]) or not _integer(p[1], 1, 99): return "姓名输入须指定角色及最大字符数1..99"
		311, 312, 315, 316:
			if p.size() != (5 if code == 311 else 4) or not _integer(p[0], 0, 1000000) or not _amount(p.slice(1, 4)): return "角色增减须指定单个/全体及常量/变量操作数"
			if code == 311 and not p[4] is bool: return "允许死亡须为布尔值"
		313: if p.size() != 3 or not _integer(p[0], 0, 1000000) or not _integer(p[1], 0, 1) or not _id(p[2]): return "状态须指定单个/全体、附加/解除和状态ID"
		314: if p.size() != 1 or not _integer(p[0], 0, 1000000): return "全回复须指定单个角色或0全体"
		317: if p.size() != 5 or not _id(p[0]) or not _integer(p[1], 0, 5) or not _amount(p.slice(2)): return "能力值须指定角色、原生六项和增减操作数"
		318: if p.size() != 3 or not _id(p[0]) or not _integer(p[1], 0, 1) or not _id(p[2]): return "特技须指定角色、学习/遗忘和特技ID"
		319: if p.size() != 3 or not _id(p[0]) or not _integer(p[1], 0, 4) or not _integer(p[2], 0, 1000000): return "装备须指定角色、五槽0..4及装备ID（0卸下）"
		320: if p.size() != 2 or not _id(p[0]) or not p[1] is String or p[1].length() > 1024: return "角色姓名参数无效"
		321: if p.size() != 2 or not _id(p[0]) or not _id(p[1]): return "角色职业参数无效"
		322: if p.size() != 5 or not _id(p[0]) or not _asset_name(p[1]) or not _integer(p[2], 0, 360) or not _asset_name(p[3]) or not _integer(p[4], 0, 360): return "角色图形须包含行走图/战斗图名称及色相；战斗图仅保存数据"
		351, 352, 353, 354: if not p.is_empty(): return "菜单/游戏结束/返回标题没有参数"
	return ""

static func _asset_name(value: Variant) -> bool:
	if not value is String or value.length() > 1024 or value.is_absolute_path() or value.contains(":") or value.contains("\\"): return false
	if value.is_empty(): return true
	for component in value.split("/"):
		if component in ["", ".", ".."]: return false
	for character in value:
		if character.unicode_at(0) < 32: return false
	return true

static func _numeric(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func route_reason(code: int, parameters: Array = []) -> String:
	if code == 45: return "" if parameters.size()==1 and parameters[0] is String else "路线脚本须为字符串。"
	if code < 0 or code > 44: return "未知移动路线指令"
	match code:
		14: if parameters.size() != 2 or not _integer(parameters[0], -1000000, 1000000) or not _integer(parameters[1], -1000000, 1000000): return "跳跃须指定整数偏移"
		15: if parameters.size() != 1 or not _integer(parameters[0], 0, 999): return "路线等待须为0..999的整数（单位1/20秒）"
		27, 28: if parameters.size() != 1 or not _id(parameters[0]): return "路线开关ID无效"
		29: if parameters.size() != 1 or not _integer(parameters[0], 1, 6): return "移动速度须为1..6"
		30: if parameters.size() != 1 or not _integer(parameters[0], 1, 6): return "移动频度须为1..6"
		41:
			if parameters.size() != 4 or not parameters[0] is String or not _integer(parameters[1], 0, 360) or not _direction(parameters[2]) or not _integer(parameters[3], 0, 3): return "路线图形、色相、方向或图案无效"
		42: if parameters.size() != 1 or not _integer(parameters[0], 0, 255): return "不透明度须为0..255"
		43: if parameters.size() != 1 or not _integer(parameters[0], 0, 2): return "合成方式须为0..2"
		44:
			if parameters.size() != 1 or not parameters[0] is Dictionary: return "路线SE参数无效"
			var audio: Dictionary = parameters[0]
			if not audio.get("name", "") is String or not _integer(audio.get("volume", 100), 0, 100) or not _integer(audio.get("pitch", 100), 50, 150): return "路线SE名称、音量或音调无效"
		_: if not parameters.is_empty(): return "该路线指令没有参数"
	return ""

static func route_validation(route: Variant) -> Dictionary:
	if not route is Dictionary or not route.get("repeat", null) is bool or not route.get("skippable", null) is bool or not route.get("list", null) is Array: return {"ok": false, "message": "路线须包含repeat/skippable布尔值和list数组"}
	var list: Array = route.list
	if list.is_empty() or list.size() > 100000: return {"ok": false, "message": "路线列表为空或过长"}
	for index in list.size():
		var command: Variant = list[index]
		if not command is Dictionary or not _integer(command.get("code", -1), 0, 45) or not command.get("parameters", []) is Array: return {"ok": false, "message": "路线指令格式无效", "route_index": index + 1}
		var code := int(command.code)
		var message := route_reason(code, command.get("parameters", []))
		if not message.is_empty(): return {"ok": false, "message": message, "route_index": index + 1}
		if code == 0 and index != list.size() - 1: return {"ok": false, "message": "路线结束标记必须位于末尾", "route_index": index + 1}
	if int(list[-1].code) != 0: return {"ok": false, "message": "路线缺少末尾结束标记", "route_index": list.size()}
	return {"ok": true}

static func _target(value: Variant) -> bool:
	return _integer(value, -1, 1000000)

static func _direction(value: Variant, allow_zero: bool = false) -> bool:
	return _integer(value, 0, 8) and (int(value) in [2, 4, 6, 8] or (allow_zero and int(value) == 0))

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and value >= minimum and value <= maximum

static func _id(value: Variant) -> bool:
	return _integer(value, 1, 1000000)

static func _range(p: Array) -> bool:
	return _id(p[0]) and _id(p[1]) and p[0] <= p[1] and p[1] - p[0] <= 99999

static func _amount(p: Array) -> bool:
	return p.size() == 3 and _integer(p[0], 0, 1) and _integer(p[1], 0, 1) and (_integer(p[2], 0, 99999999) if int(p[1]) == 0 else _id(p[2]))

static func _condition_reason(p: Array) -> String:
	if p.is_empty() or not _integer(p[0], 0, 12): return "条件类型无效"
	var type := int(p[0])
	if type == 12: return "" if p.size()==2 and p[1] is String else "脚本条件须为字符串。"
	if type == 5: return "敌人条件属于原生回合制战斗，不在迁移范围"
	var valid := false
	match type:
		0: valid = p.size() == 3 and _id(p[1]) and _integer(p[2], 0, 1)
		1: valid = p.size() == 5 and _id(p[1]) and _integer(p[2], 0, 1) and (_integer(p[3], -99999999, 99999999) if int(p[2]) == 0 else _id(p[3])) and _integer(p[4], 0, 5)
		2: valid = p.size() == 3 and p[1] in ["A", "B", "C", "D"] and _integer(p[2], 0, 1)
		3, 7: valid = p.size() == 3 and _integer(p[1], 0, 99999999) and _integer(p[2], 0, 1)
		4:
			valid = p.size() >= 3 and _id(p[1]) and _integer(p[2], 0, 5)
			if valid: valid = (p.size() == 3 or p.size() == 4) if int(p[2]) == 0 else (p.size() == 4 and (p[3] is String if int(p[2]) == 1 else _integer(p[3], 0 if int(p[2]) in [3, 4] else 1, 1000000)))
		6: valid = p.size() == 3 and _integer(p[1], -1, 1000000) and _integer(p[2], 2, 8) and int(p[2]) in [2, 4, 6, 8]
		8, 9, 10: valid = p.size() == 2 and _id(p[1])
		11: valid = p.size() == 2 and _integer(p[1], 2, 18) and int(p[1]) in [2, 4, 6, 8, 11, 12, 13, 14, 15, 16, 17, 18]
	return "" if valid else "条件分支参数无效"

static func _variable_reason(p: Array) -> String:
	if p.size() < 5 or not _range(p) or not _integer(p[2], 0, 5) or not _integer(p[3], 0, 7): return "变量范围、操作或操作数类型无效"
	var valid := false
	match int(p[3]):
		0: valid = p.size() == 5 and _integer(p[4], -99999999, 99999999)
		1, 3: valid = p.size() == 5 and _id(p[4])
		2: valid = p.size() == 6 and _integer(p[4], -99999999, 99999999) and _integer(p[5], -99999999, 99999999) and p[4] <= p[5]
		4: valid = p.size() == 6 and _id(p[4]) and _integer(p[5], 0, 13)
		5: return "敌人操作数属于原生回合制战斗，不在迁移范围"
		6: valid = p.size() == 6 and _integer(p[4], -1, 1000000) and _integer(p[5], 0, 5)
		7: valid = p.size() == 5 and _integer(p[4], 0, 6)
	return "" if valid else "变量操作数参数无效"
