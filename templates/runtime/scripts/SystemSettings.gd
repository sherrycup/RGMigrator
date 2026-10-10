extends RefCounted
## Runtime overrides never modify the imported System database.
const Data = preload("res://runtime/scripts/RuntimeData.gd")
const P = preload("res://runtime/scripts/PictureState.gd")
var windowskin_override: Variant = null

func windowskin_name() -> String:
	return str(Data.system().get("windowskin_name", "")) if windowskin_override == null else windowskin_override

func snapshot() -> Dictionary:
	return {"windowskin_name": windowskin_override}

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 1 or not value.has("windowskin_name"): return P.fail("系统设置存档无效。")
	var name: Variant = value.windowskin_name
	if name != null and (not name is String or name.length() > 1024 or (not name.is_empty() and not P.valid_name(name))): return P.fail("窗口皮肤设置无效。")
	var instance: RefCounted = load("res://runtime/scripts/SystemSettings.gd").new()
	instance.windowskin_override = name
	return {"ok": true, "value": instance}
