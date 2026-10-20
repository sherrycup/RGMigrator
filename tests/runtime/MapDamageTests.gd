## 职责：回归验证：验证地图显伤请求、战斗后刷新和结果归属。
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
##   func map_action(id: int,damage: int,ratio: int,rating: int) -> Dictionary
##     参数 id（int；必填）：本接口所处理对象的编号。
##     参数 damage（int；必填）：伤害数值或伤害计算结果。
##     参数 ratio（int；必填）：比例系数。
##     参数 rating（int；必填）：原技能或行动的评价参数。
##     返回：字典结果；字段结构与本方法返回的数据一致。
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
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
const Abilities=preload("res://runtime/scripts/01_Battle/EnemyAbilities.gd")
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
	state.party=[2]; state.map_id=10
	var actor=state.actor(2); actor.set_project_parameter("maxhp",101); actor.hp=101
	var host=Host.new(); root.add_child(host)
	var map: Node=load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); host.add_child(map); host.map=map; state._game_ref=weakref(host)
	var definition=Data.map(10).duplicate(true); definition.events={}
	var coordinates=[Vector2i(12,9),Vector2i(14,9),Vector2i(13,10),Vector2i(13,8)]
	for i in 4: definition.events[str(i+1)]={"id":i+1,"name":"怪物1","x":coordinates[i].x,"y":coordinates[i].y,"pages":[]}
	Data._cache["res://data/maps/Map010.json"]=definition
	map.map_data=definition.duplicate(true); map._loaded_id=10
	for i in 4:
		var event: Node=load("res://runtime/scripts/03_Map/MapEvent.gd").new(); map.add_child(event)
		event.event_id=i+1; event.character_id=i+1; event.map_id=10; event.map_runtime=map; event.motion.relocate(coordinates[i]); map._event_nodes.append(event)
	var player: Node=load("res://runtime/scripts/03_Map/MapCharacter.gd").new(); map.add_child(player); player.map_runtime=map; player.motion.relocate(Vector2i(13,9)); map.player_character=player
	var constants: Dictionary=state.custom_data.gameplay().rules.constants
	var enemies: Array=Data.database("Enemies").duplicate(true)
	enemies[1].actions=[map_action(int(constants.COTACK_SKILL_ID),1,50,1)]
	Data._cache["res://data/database/Enemies.json"]=enemies
	var params=Abilities.map_parameters(enemies[1].actions,constants)
	expect(params.cotack.ratio==50 and params.cotack.damage==0,"source default clamp parameters read actual action fields")
	state.inventory["item:"+str(constants.COTACK_ITEM_ID)]=1
	var result=Scripts.call_method(state.custom_data.data_ref("player",10),"cotack_deal",[],state)
	expect(result.ok and actor.get_parameter("maxhp")==25 and actor.hp==25,"two-axis clamp applies X then Y ratios with source fractional bonus and Integer getter: "+str(result.get("message","")))
	state.custom_data.values.records["States:1"]={"name":"中毒:10"}
	actor.add_state(1)
	result=Scripts.call_method(state.custom_data.data_ref("player",10),"poison_deal",[],state)
	expect(result.ok and actor.get_parameter("maxhp")==15 and actor.hp==15,"poison reads source state-name amount and changes MAXHP")
	actor.set_project_parameter("maxhp",5); actor.hp=5
	result=Scripts.call_method(state.custom_data.data_ref("player",10),"poison_deal",[],state)
	expect(result.ok and actor.hp==0 and state.flash_temp_fields.ending_id==2 and state.common_event_reservation.id==12,"poison death reserves source ending 2/common-event 12")
	actor.remove_state(1); actor.set_project_parameter("maxhp",100); actor.hp=100
	var floor: Dictionary=state.custom_data._floor(10)
	for entry in floor.entries.values(): entry.fields.skills=[int(constants.HIDE_SKILL_ID)]
	floor.indices.hide=[[12,9],[14,9],[13,10],[13,8]]
	state.inventory["item:"+str(constants.HIDE_ITEM_ID)]=1
	result=Scripts.call_method(state.custom_data.data_ref("player",10),"hide_deal",[],state)
	expect(result.ok and map.event_node(1).opacity==int(constants.HIDE_ITEM_EFFECT[1]),"hide uses source Manhattan radius and opacity on actual native events")
	player.motion.relocate(Vector2i(18,14))
	result=Scripts.call_method(state.custom_data.data_ref("player",10),"hide_deal",[],state)
	expect(result.ok and map.event_node(1).opacity==0,"hide removes visibility outside its source radius")
	var built=Abilities.map_parameters([map_action(int(constants.MANOR_SKILL_ID),1,100,2),map_action(int(constants.HOOK_SKILL_ID),1,100,1)],constants)
	expect(built.manor.damage==constants.DEFAULT_MANOR_DAMAGE and built.hook.damage==constants.DEFAULT_HOOK_DAMAGE,"confirmed typo corrections retain original manor/hook defaults")
	player.motion.relocate(Vector2i(13,9))
	floor=state.custom_data._floor(10)
	floor.indices.manor=[[12,9]]
	floor.entries["1"].fields.skills=[int(constants.MANOR_SKILL_ID),int(constants.HOOK_SKILL_ID)]
	floor.entries["1"].fields.skill_parameters={"manor":{"range":1,"damage":7},"hook":{"damage":3}}
	state.inventory["item:"+str(constants.MANOR_ITEM_ID)]=1
	state.inventory["item:"+str(constants.HOOK_ITEM_ID)]=1
	var before_damage=actor.get_parameter("maxhp")
	result=Scripts.call_method(state.custom_data.data_ref("player",10),"manor_deal",[],state)
	expect(result.ok and actor.get_parameter("maxhp")==before_damage-7 and actor.hp==before_damage-7,"manor uses source Chebyshev distance and fixed MAXHP subtraction: "+str(actor.get_parameter("maxhp"))+" / "+str(result.get("message","")))
	result=Scripts.call_method(state.custom_data.data_ref("player",10),"hook_deal",[],state)
	expect(result.ok and actor.get_parameter("maxhp")==before_damage-10 and map.event_node(1).motion.target==Vector2i(11,9),"hook moves its native event through finite direction dispatch and skips non-hook enemies: "+str(result.get("message","")))
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MAP DAMAGE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	state._game_ref=null; host.queue_free()
	quit(0 if failures.is_empty() else 1)

func map_action(id: int,damage: int,ratio: int,rating: int) -> Dictionary:
	return {"kind":1,"condition_level":10,"skill_id":id,"condition_turn_a":0,"condition_turn_b":damage,"condition_hp":ratio,"rating":rating}
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
