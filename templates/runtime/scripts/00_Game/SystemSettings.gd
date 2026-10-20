## 职责：维护游戏系统设置及事件可修改的系统选项，参与存档恢复。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/SystemSettings.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/SystemSettings.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func windowskin_name() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func decode(value: Variant) -> Dictionary
##     用途：解析编码数据并返回对应原值或结构。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 接口说明结束。

extends RefCounted
## Runtime overrides never modify the imported System database.
const Data = preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const P = preload("res://runtime/scripts/00_Game/PictureState.gd")
var windowskin_override: Variant = null


func windowskin_name() -> String:
	return (
		str(Data.system().get("windowskin_name", ""))
		if windowskin_override == null
		else windowskin_override
	)


func snapshot() -> Dictionary:
	return {"windowskin_name": windowskin_override}


static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 1 or not value.has("windowskin_name"):
		return P.fail("系统设置存档无效。")
	var name: Variant = value.windowskin_name
	if (
		name != null
		and (
			not name is String
			or name.length() > 1024
			or (not name.is_empty() and not P.valid_name(name))
		)
	):
		return P.fail("窗口皮肤设置无效。")
	var instance: RefCounted = load("res://runtime/scripts/00_Game/SystemSettings.gd").new()
	instance.windowskin_override = name
	return {"ok": true, "value": instance}
