## 职责：回归验证：验证闪翼物品、装备、技能和回路业务操作。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Actions=preload("res://runtime/scripts/01_Battle/Actions.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
const Semantics=preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")
class Host extends Node:
	var map: Node
	func event_map() -> Node: return map
	func event_screen_transition_active() -> bool: return false
	func event_scene_transition_active() -> bool: return false
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2,3]; state.variables["14"]=[2,3]; state.map_id=10; state.playing=true
	for id in state.party:
		var actor=state.actor(id); actor.set_project_parameter("maxhp",100); actor.set_project_parameter("maxsp",20)
		actor.set_project_parameter("agi",10); actor.hp=70.5; actor.sp=9.25
		actor.learn_skill(40); actor.learn_skill(41)
		actor.equip_project_skill(40,1); actor.save_project_skill_set(0,"atk")
		actor.clear_project_skills(); actor.equip_project_skill(41,1); actor.save_project_skill_set(0,"sup")
	var host=Host.new(); root.add_child(host)
	var map: Node=load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); host.add_child(map); host.map=map; state._game_ref=weakref(host)
	var definition=Data.map(10).duplicate(true); definition.events={}
	for i in 3: definition.events[str(i+1)]={"id":i+1,"name":["物品1","物品20","箱子"][i],"x":i+10,"y":9,"pages":[]}
	Data._cache["res://data/maps/Map010.json"]=definition
	map.map_data=definition.duplicate(true); map._loaded_id=10
	for i in 3:
		var event: Node=load("res://runtime/scripts/03_Map/MapEvent.gd").new(); map.add_child(event)
		event.event_id=i+1; event.character_id=i+1; event.map_id=10; event.map_runtime=map; event.motion.relocate(Vector2i(i+10,9)); map._event_nodes.append(event)
	var player: Node=load("res://runtime/scripts/03_Map/PlayerController.gd").new(); map.add_child(player); map.player_character=player
	player.configure(map); player.motion.relocate(Vector2i(13,9)); player.opacity=20; player.blend_type=1
	var result=Actions.switch_roles(state)
	expect(result.ok and result.value==true and state.variables["14"]==[3,2],"source role-switch business changes the shared role variable")
	expect(state.actor(3).project_fields.equip_skills["1"]==40 and state.actor(2).project_fields.equip_skills["1"]==41,"source switch loads each actor's first main/support skill set")
	expect(player.opacity==255 and player.blend_type==0 and player._graphic_signature.begins_with(state.actor(3).character_name),"role switch refreshes the actual native player using the source main actor")
	state.actor(3).inflict_battle_down()
	var before=state.variables["14"].duplicate()
	result=Actions.switch_roles(state)
	expect(result.ok and result.value==false and state.variables["14"]==before,"down actor locks the source manual role switch")
	state.actor(3).recover_battle_down()
	var recovery_id=0; var tool_id=0
	for item in Data.database("Items"):
		if not item is Dictionary: continue
		if recovery_id==0 and int(item.get("occasion",3))==0 and int(item.get("recover_hp",0))>0: recovery_id=int(item.id)
		if tool_id==0 and int(item.get("occasion",3))==2: tool_id=int(item.id)
	expect(recovery_id>0 and tool_id>0,"business tests use original database recovery and tool items")
	if recovery_id>0:
		state.inventory["item:"+str(recovery_id)]=1; var actor=state.actor(2); actor.hp=70.5
		var item: Dictionary=Data.record("Items",recovery_id)
		var expected=min(actor.hp+actor.get_parameter("maxhp")*item.get("recover_hp_rate",0)+item.get("recover_hp",0),actor.get_parameter("maxhp"))
		result=Actions.recover_item(state,recovery_id,2)
		expect(result.ok and actor.hp==expected and state.inventory_count("item",recovery_id)==0 and state.flash_temp_fields.actor_id==2,"business recovery invokes actual generated Item.Recover with source formula and one deduction: "+str(result.get("message","")))
		expect(state.inventory_count("item",recovery_id)==0,"successful recovery consumes its last inventory entry exactly once; script errors are tested by the fatal subprocess probe")
		state.custom_data.values.records["Items:"+str(recovery_id)]={"recover_hp_rate":1,"recover_hp":3,"recover_sp_rate":0,"recover_sp":0,"consumable":false}
		state.inventory["item:"+str(recovery_id)]=1; actor.hp=70.5
		result=state.use_item(recovery_id,2)
		expect(result.ok and actor.hp==100 and state.inventory_count("item",recovery_id)==0,"public RuntimeState.use_item uses original Item.Recover rate and deduction, including nonconsumable source items")
		state.custom_data.values.records.erase("Items:"+str(recovery_id))
	if tool_id>0:
		state.inventory["item:"+str(tool_id)]=1
		result=Actions.request_tool(state,tool_id)
		expect(result.ok and state.common_event_reservation.id==9 and state.flash_temp_fields.item_id==tool_id and state.inventory_count("item",tool_id)==1,"source tool request sets item_id and reserves original CE9 without premature deduction: "+JSON.stringify(result)+" / "+JSON.stringify(state.common_event_reservation))
		state.common_event_reservation={}
		result=state.use_item(tool_id,0)
		expect(result.ok and result.common_event==9 and state.common_event_reservation.id==9 and state.inventory_count("item",tool_id)==1,"public tool use reserves original CE9 and leaves the original consumption command responsible for one deduction")
	var equipped=load("res://runtime/scripts/00_Game/InventoryService.gd").equip(state,2,5,1)
	expect(equipped.ok and state.actor(2).equipment[5]==1,"existing inventory service routes the sixth Flash slot through source equipment business")
	var env=Semantics.new(state); env.begin({"kind":"flash_source_helpers"})
	expect(env.invoke(0,"in?",[false,0])==true and env.invoke(false,"in?",[0])==false,"source Object.in? preserves Ruby boolean/numeric identity")
	expect(env.invoke(null,"to_param",[])=="v" and env.invoke(1,"to_param",[])=="l" and env.invoke(1.0,"to_param",[])=="p","source Object.to_param distinguishes nil, integer and float")
	expect(env.invoke([],"random_element",[])==null and env.invoke([7],"random_element",[])==7,"source random_element handles empty and singleton arrays")
	expect(env.invoke([1,2,3],"old_val",[-1])==3,"source Array.old_val retains underlying negative indexing")
	expect(env.invoke(" -0x1f tail","to_i",[16])==-31,"source hexadecimal helper preserves sign, prefix and trailing text")
	var utils=env.type_ref("Utils")
	expect(env.invoke(utils,"MHT_Distance",[1,4,9,2])==10,"source geometry helper retains unusual x1,x2,y1,y2 argument order")
	expect(env.invoke(utils,"Find_Event",["钥匙"])==[1,2],"source key alias performs original regex matching")
	expect(env.invoke(utils,"Find_Event",[["物品","物品1"]])==[1,1,2],"source event finder preserves duplicate results for overlapping patterns")
	expect(env.invoke(utils,"Check_Area",[12,9,1,0])==true,"source area helper includes boundary events and player")
	expect(env.invoke(utils,"Check_Area",[0,0,1,1])==false,"source area helper excludes distant objects")
	expect(env.invoke(utils,"Unit",[1000])==null,"source unfinished numeric display helper keeps its empty behavior")
	var tree=env.invoke(env.type_ref("DataBase"),"maptree",[])
	expect(env.index_get(tree,[1,1])==4 and env.index_get(env.index_get(tree,4),"P")==5 and env.index_get(env.index_get(tree,4),"I")==[1,1],"source maptree retains its mixed region/floor and map-id keys with flat P template field")
	expect(env.invoke(tree,"has_key?",[[1,1]])==true and env.invoke(tree,"has_key?",[99999])==false,"source mixed-key tree exposes actual Hash key membership")
	expect(env.finish(null).ok,"source helpers run within the shared script transaction")
	for message in failures: printerr("FAIL: ",message)
	print("FLASH BUSINESS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	state._game_ref=null; host.queue_free()
	quit(0 if failures.is_empty() else 1)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
