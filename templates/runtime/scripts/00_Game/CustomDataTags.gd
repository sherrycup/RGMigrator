## 职责：定义自定义数据中的类型标记，统一对象、容器及原值的识别方式。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/CustomDataTags.gd").方法名(...)。
##
## 调用接口：
##   static func parse(name: String) -> Array
##     用途：解析原文本并保留来源与诊断。
##     参数 name（String；必填）：对象、资源或字段名称。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
##
## 接口说明结束。

extends RefCounted


## Keep the raw token even when its eventual gameplay meaning is unknown.
static func parse(name: String) -> Array:
	var result: Array = []
	var parts = name.split(":")
	var matcher = RegEx.new()
	matcher.compile("^([A-Za-z%]+)([-+]?[0-9]+(?:\\.[0-9]+)?)$")
	for i in range(1, parts.size()):
		var found = matcher.search(parts[i])
		var value: Variant = null
		if found != null:
			var raw = found.get_string(2)
			value = raw if abs(float(raw)) > 9007199254740991 else float(raw)
		result.append(
			{
				"raw": parts[i],
				"key": found.get_string(1) if found != null else "",
				"value": value,
				"behavior_stage": "0.45"
			}
		)
	return result
