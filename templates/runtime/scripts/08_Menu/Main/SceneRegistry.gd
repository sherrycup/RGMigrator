## 职责：登记闪翼页面名称与实际场景入口，连接原脚本的页面呼叫。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/08_Menu/Main/SceneRegistry.gd").方法名(...)。
##
## 调用接口：
##   static func validate(name: String, args: Array, state: Object) -> String
##     用途：检查输入数据是否符合该服务的约定。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 args（Array；必填）：按调用顺序排列的参数值。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   static func create(name: String, args: Array, state: Object) -> Control
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 args（Array；必填）：按调用顺序排列的参数值。
##     参数 state（Object；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     返回：Control 类型的对象或值，供调用方继续使用。
##
##   static func construct(custom: RefCounted, name: String, args: Array) -> Variant
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 args（Array；必填）：按调用顺序排列的参数值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
##   static func stage(custom: RefCounted, value: Dictionary) -> Variant
##     参数 custom（RefCounted；必填）：自定义数据运行服务或当前自定义配置。
##     参数 value（Dictionary；必填）：需要读取、校验或写入的值。
##     返回：动态类型结果；允许的具体类型由输入和实际返回分支决定。
##
## 公开常量：SCENES。
## 接口说明结束。

extends RefCounted
## Explicit portable entry points for original standalone scenes. Empty final
## menu branches stay empty; callers use Game.show_flash_scene(name,args).
const SCENES = {
	"Scene_Flytofloor": "SelectionPage",
	"Scene_CP": "SelectionPage",
	"Scene_Item": "ItemPage",
	"Scene_Skill": "CastingPage",
	"Scene_Equip": "EquipmentPage",
	"Scene_Debug": "DebugPage",
	"Scene_Shop": "ShopScene"
}


static func validate(name: String, args: Array, state: Object) -> String:
	if not SCENES.has(name):
		return "独立页面尚未注册：" + name
	if name in ["Scene_Skill", "Scene_Equip"]:
		if args.size() > 2 or not args.all(func(value): return value is int and value >= 0):
			return "角色页面参数需要非负整数索引。"
		if state.party.is_empty() or (not args.is_empty() and args[0] >= state.party.size()):
			return "角色页面的队伍索引无效。"
		if name == "Scene_Equip" and args.size() > 1 and args[1] >= 6:
			return "闪翼装备页槽位须为0—5。"
	elif not args.is_empty():
		return "该独立页面构造器没有参数。"
	return ""


static func create(name: String, args: Array, state: Object) -> Control:
	var page: Control = (
		load(
			preload("res://runtime/scripts/10_Support/Scripting/ScriptPaths.gd").runtime(
				SCENES[name] + ".gd"
			)
		)
		. new()
	)
	if name in ["Scene_Flytofloor", "Scene_CP"]:
		page.kind = "actor" if name == "Scene_CP" else "floor"
	if name in ["Scene_Skill", "Scene_Equip"]:
		page.actor_id = int(state.party[args[0] if not args.is_empty() else 0])
	if name == "Scene_Equip" and args.size() > 1:
		page.slot = args[1]
	return page


static func construct(custom: RefCounted, name: String, args: Array) -> Variant:
	var reason = validate(name, args, custom._owner.get_ref())
	if not reason.is_empty():
		return custom.reject(reason)
	return {"__custom_ref": "flash_scene", "database": name, "args": args.duplicate()}


static func stage(custom: RefCounted, value: Dictionary) -> Variant:
	if custom.execution_context.get("kind") == "route":
		return custom.reject("人物路线脚本不能切换独立页面，请从事件脚本调用。")
	var state: Object = custom._owner.get_ref()
	var game: Node = state.game()
	if (
		game == null
		or game._menus.menu != null
		or game._menus.shop != null
		or game._menus.name_input != null
		or game.get_tree().paused
		or game._dialogue.is_open()
		or not game._player.is_idle()
	):
		return custom.reject("独立页面的地图上下文被占用。")
	var reason = validate(str(value.database), value.args, state)
	if not reason.is_empty():
		return custom.reject(reason)
	if not custom.scene_request.is_empty():
		return custom.reject("同一脚本片段不能同时打开两个页面。")
	custom.scene_request = value.duplicate(true)
	return value
