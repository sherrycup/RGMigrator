extends RefCounted
## Explicit portable entry points for original standalone scenes. Empty final
## menu branches stay empty; callers use Game.show_flash_scene(name,args).
const SCENES={"Scene_Flytofloor":"FlashSelectionPage","Scene_CP":"FlashSelectionPage","Scene_Item":"FlashItemPage","Scene_Skill":"FlashCastingPage","Scene_Equip":"FlashEquipmentPage","Scene_Debug":"FlashDebugPage","Scene_Shop":"ShopScene"}
static func validate(name: String,args: Array,state: Object) -> String:
	if not SCENES.has(name): return "独立页面尚未注册："+name
	if name in ["Scene_Skill","Scene_Equip"]:
		if args.size()>2 or not args.all(func(value):return value is int and value>=0): return "角色页面参数需要非负整数索引。"
		if state.party.is_empty() or (not args.is_empty() and args[0]>=state.party.size()): return "角色页面的队伍索引无效。"
		if name=="Scene_Equip" and args.size()>1 and args[1]>=6: return "闪翼装备页槽位须为0—5。"
	elif not args.is_empty(): return "该独立页面构造器没有参数。"
	return ""
static func create(name: String,args: Array,state: Object) -> Control:
	var page: Control=load("res://runtime/scripts/"+SCENES[name]+".gd").new()
	if name in ["Scene_Flytofloor","Scene_CP"]: page.kind="actor" if name=="Scene_CP" else "floor"
	if name in ["Scene_Skill","Scene_Equip"]: page.actor_id=int(state.party[args[0] if not args.is_empty() else 0])
	if name=="Scene_Equip" and args.size()>1: page.slot=args[1]
	return page
static func construct(custom: RefCounted,name: String,args: Array) -> Variant:
	var reason=validate(name,args,custom._owner.get_ref())
	if not reason.is_empty(): return custom.reject(reason)
	return {"__custom_ref":"flash_scene","database":name,"args":args.duplicate()}
static func stage(custom: RefCounted,value: Dictionary) -> Variant:
	if custom.execution_context.get("kind")=="route": return custom.reject("人物路线脚本不能切换独立页面，请从事件脚本调用。")
	var state: Object=custom._owner.get_ref(); var game: Node=state.game()
	if game==null or game._menus.menu!=null or game._menus.shop!=null or game._menus.name_input!=null or game.get_tree().paused or game._dialogue.is_open() or not game._player.is_idle(): return custom.reject("独立页面的地图上下文被占用。")
	var reason=validate(str(value.database),value.args,state)
	if not reason.is_empty(): return custom.reject(reason)
	if not custom.scene_request.is_empty(): return custom.reject("同一脚本片段不能同时打开两个页面。")
	custom.scene_request=value.duplicate(true); return value
