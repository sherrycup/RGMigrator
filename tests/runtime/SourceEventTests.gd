## 职责：回归验证：直接执行原地图与公共事件记录并核对结果。
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
##   func execute_original(id: String,state: Node,event_id: int) -> Dictionary
##     参数 id（String；必填）：本接口所处理对象的编号。
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 event_id（int；必填）：当前地图上的事件编号；0 的具体含义由调用入口约定。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func original_commands(id: String) -> Array
##     参数 id（String；必填）：本接口所处理对象的编号。
##     返回：按本方法约定排列的集合；元素类型见返回类型。
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
const Custom=preload("res://runtime/scripts/00_Game/CustomDataState.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
class GameHost extends Node:
	var map: Node
	func event_map() -> Node: return map
	func event_screen_transition_active() -> bool: return false
	func event_scene_transition_active() -> bool: return false
class NativeOwner extends RefCounted:
	var _native_generation = 1
	var running = true
var native_owner = NativeOwner.new()
var failures: Array[String]=[]
var checks=0
var script_fields: Dictionary={}

func _init() -> void: call_deferred("run")

func run() -> void:
	var state=root.get_node("RuntimeState")
	state.party=[2]; state.variables["14"]=[2,0]; state.map_id=10
	var host=GameHost.new(); root.add_child(host)
	var map: Node=load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); host.add_child(map); host.map=map
	map.map_data=Data.map(10).duplicate(true)
	map._loaded_id=10
	state._game_ref=weakref(host)
	var floor_data=state.custom_data._floor(10)
	var event_id=int(floor_data.entries.keys()[0])
	var event: Node=load("res://runtime/scripts/03_Map/MapEvent.gd").new()
	event.event_id=event_id; event.character_id=event_id; event.map_id=10; event.map_runtime=map
	event.motion.relocate(Vector2i(int(map.map_data.events[str(event_id)].x),int(map.map_data.events[str(event_id)].y)))
	map.add_child(event); map._event_nodes.append(event)
	var player: Node=load("res://runtime/scripts/03_Map/MapCharacter.gd").new(); map.add_child(player); player.map_runtime=map; map.player_character=player
	var fields: Dictionary=floor_data.entries[str(event_id)].fields
	fields.maxhp=35; fields.hp=35; fields.atk=9; fields.pdef=3; fields.agi=10
	var actor=state.actor(2)
	actor.set_project_parameter("maxhp",100); actor.hp=100
	actor.set_project_parameter("patk",20); actor.set_project_parameter("pdef",5); actor.set_project_parameter("agi",10)
	actor.project_fields.battle_animation=0
	var before_gold=state.gold; var before_exp=actor.experience
	var first=execute_original("event_000001",state,event_id)
	expect(first.ok and actor.hp==100 and state.custom_data.values.floors["10"].entries[str(event_id)].battle.hp==0,"original common-event 1 opens battle through the actual binding; only enemy HP changes: "+str(first.get("message","")))
	var repeated=execute_original("event_000001",state,event_id)
	expect(repeated.ok and actor.hp==100,"repeating the original begin fragment preserves the fixed battle")
	var second=execute_original("event_000002",state,event_id)
	expect(second.ok and actor.hp==92 and state.custom_data.values.floors["10"].entries[str(event_id)].battle.pending==null,"original common-event 1 applies player damage and finishes: "+str(second.get("message","")))
	var third=execute_original("event_000003",state,event_id)
	expect(third.ok and third.value==false,"original enemy-survived condition consumes the same enemy HP")
	var reward=execute_original("event_000005",state,event_id)
	expect(reward.ok and actor.experience==before_exp+int(fields.exp) and state.gold==before_gold+int(fields.gold),"original reward fragment uses native shared EXP and gold: "+str(reward.get("message","")))
	# Source Level_Up has one designed bonus branch; empty branches still increase level.
	actor.set_level(1); actor.set_experience(41)
	var growth=execute_original("event_000073",state,event_id)
	expect(growth.ok and actor.level==2 and actor.experience==41,"original common-event 14 reaches generated Level_Up without auto-leveling in EXP setter: "+str(growth.get("message","")))
	var env=Scripts._session(state)
	expect(env.loaded_units.has("script_0318"),"source Level_Up runs from its generated GDScript library")
	var name_entry: Dictionary=map.map_data.events[str(event_id)]
	name_entry.name="怪物42"
	var name_battle=execute_original("event_000084",state,event_id)
	expect(name_battle.ok and name_battle.get("common_event_id")==1 and state.flash_temp_fields.enemy_id==42,"original name driver captures enemy ID and calls child common-event 1: "+str(name_battle.get("message","")))
	name_entry.name="血瓶<75>"
	var bottle_condition=execute_original("event_000085",state,event_id)
	var bottle_value=execute_original("event_000086",state,event_id)
	expect(bottle_condition.ok and bottle_condition.value=="血瓶<75>" and bottle_value.ok and state.flash_temp_fields.hp_addition==75,"captures survive condition-to-script boundary for the original bottle name")
	state.flash_temp_fields.potion_id=1
	var itemization=execute_original("event_000008",state,event_id)
	var bottle_item=execute_original("event_000009",state,event_id)
	expect(itemization.ok and itemization.value==true and bottle_item.ok and state.flash_temp_fields.item_id==32,"corrected original potion constant points to the restored ID table")
	state.flash_temp_fields.gem_id=1; state.flash_temp_fields.potion_id=0
	var gem_condition=execute_original("event_000024",state,event_id)
	var gem_table=execute_original("event_000025",state,event_id)
	var previous_patk=actor.get_parameter("patk")
	var gem_apply=execute_original("event_000026",state,event_id)
	expect(gem_condition.ok and gem_condition.value==true and gem_table.ok and gem_apply.ok and actor.get_parameter("patk")==previous_patk+1,"corrected gem selector and original generated Hash loop apply source bonus: "+str(gem_apply.get("message","")))
	name_entry.name="宝石<patk:1;pdef:1;resist:[0,0,0,0,1]>"
	var old_resist=actor.get_resist(); previous_patk=actor.get_parameter("patk")
	var gem_name=execute_original("event_000087",state,event_id)
	var gem_name_apply=execute_original("event_000026",state,event_id)
	expect(gem_name.ok and gem_name.common_event_id==3 and gem_name_apply.ok and actor.get_parameter("patk")==previous_patk+1 and actor.get_resist()[4]==old_resist[4]+1,"original gem name becomes compiled typed scalar and vector values: "+str(gem_name.get("message",""))+" / "+str(gem_name_apply.get("message","")))
	# Fatal case is covered in FailureIsolationProbe: gem-expression
	var correction_manifest: Dictionary=Data.read_json("res://data/source_corrections.json",{})
	expect(correction_manifest.get("entries",[]).any(func(entry):return entry.id=="gem_selector" and entry.origin.common_event_id==3),"correction is recorded against the original common-event location")
	name_entry.name="怪物42"
	var driver_commands=original_commands("event_000084")
	driver_commands.append({"code":121,"indent":0,"parameters":[8,8,0]})
	var child_events: Array=[null,{"id":1,"list":original_commands("event_000005")}]
	var interpreter: RefCounted=load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	interpreter.managed=true; interpreter.map_runtime=map; interpreter.common_events=child_events
	var child_diagnostics: Array=[]
	interpreter.diagnostic_requested.connect(func(message):child_diagnostics.append(message))
	before_gold=state.gold; before_exp=actor.experience
	interpreter.start(driver_commands,event_id)
	for frame in 8: interpreter.advance(0.1)
	expect(not interpreter.running and child_diagnostics.is_empty() and state.switches.get("8")==true and state.gold==before_gold+int(fields.gold) and actor.experience==before_exp+int(fields.exp),"native interpreter enters the source-triggered child, retains event ID and returns to parent cursor: "+str(child_diagnostics))
	state.custom_data.values.records["Items:32"]={"recover_hp":3,"recover_hp_rate":1,"recover_sp":0,"recover_sp_rate":0,"animation1_id":0}
	state.inventory["item:32"]=2; state.flash_temp_fields.item_id=32; state.flash_temp_fields.actor_id=2
	actor.hp=1
	var recover=Scripts.call_method({"__ruby_type":"Item"},"Recover",[],state)
	expect(recover.ok and actor.hp==actor.get_parameter("maxhp") and state.inventory["item:32"]==1,"original Item.Recover generated library preserves rate formula and commits healing/consumption together: "+str(recover.get("message","")))
	expect(env.loaded_units.has("script_0193"),"medicine behavior runs from the generated original library")
	var calculated=Scripts.new_object("Item_calc",[1,1],state)
	if calculated.ok:
		var item_object: Dictionary=calculated.value
		var graphic=Scripts.call_method(item_object,"chname",[],state)
		var direction=Scripts.call_method(item_object,"direct",[],state)
		var pattern=Scripts.call_method(item_object,"patt",[],state)
		expect(graphic.ok and graphic.value=="201-item01" and direction.value==2 and pattern.value==0,"original Item_calc constructor and methods calculate the walking graphic from icon 201-01")
	else: expect(false,"original Item_calc constructor loads: "+str(calculated.get("message","")))
	expect(env.loaded_units.has("script_0263"),"item graphic calculation runs from generated original library")
	var barrier=execute_original("event_000043",state,event_id)
	expect(barrier.ok and actor.get_state_ids().has(1),"original barrier fragment adds the source poison state to the shared actor: "+str(barrier.get("message","")))
	var ending=execute_original("event_000064",state,event_id)
	var score=actor.get_parameter("maxhp")*10+actor.experience*5+state.gold*5+actor.get_parameter("patk")+actor.get_parameter("pdef")+actor.get_parameter("matk")+actor.get_parameter("mdef")
	expect(ending.ok and state.flash_temp_fields.ending_score==maxi(score,0),"original ending-score formula and Array.max run from generated event code: "+str(ending.get("message","")))
	var aim_layer=int(state.custom_data.gameplay().rules.storage.aim_layer)
	map.map_data.data["values"][event.motion.cell.x+event.motion.cell.y*int(map.map_data.data.x_size)+aim_layer*int(map.map_data.data.x_size)*int(map.map_data.data.y_size)]=402
	# Preserve only this event so a refresh uses the actual target without unrelated graphics.
	map.map_data.events={str(event_id):name_entry}
	var box=execute_original("event_000057",state,event_id)
	expect(box.ok and state.self_switches.get("10:"+str(event_id)+":A")==true,"original box-target script reads 3D table and commits source self-switch key: "+str(box.get("message","")))
	var damage_refresh=execute_original("event_000062",state,event_id)
	expect(damage_refresh.ok,"original mapdamage refresh reaches the same ordinary prediction service: "+str(damage_refresh.get("message","")))
	var die=Scripts.call_method(state.custom_data.data_ref("map_event",10,"",event_id),"die",[],state)
	expect(die.ok and state.custom_data.values.system.event_name["10"][str(event_id)]==env.constants.DEFAULT_DEAD_CODE and map.event_node(event_id)==null,"permanent source die writes the shared system name override and refreshes the native map: "+str(die.get("message","")))
	for message in failures: printerr("FAIL: ",message)
	print("FLASH SOURCE EVENTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	state._game_ref=null; host.queue_free()
	quit(0 if failures.is_empty() else 1)

func execute_original(id: String,state: Node,event_id: int) -> Dictionary:
	var unit: Dictionary=Data.read_json("res://data/script_units.json",{}).units.get(id,{})
	if unit.get("status")!="generated": return {"ok":false,"message":"not generated: "+id}
	var common: Dictionary=Data.record("CommonEvents",int(unit.origin.common_event_id))
	var commands: Array=common.list
	var index=int(unit.origin.command_index)-1
	var binding: Dictionary=commands[index].get("_script_binding",{})
	var lines: Array[String]=[]
	for offset in int(binding.get("command_count",1)): lines.append(str(commands[index+offset].parameters[1 if int(commands[index+offset].code)==111 else 0]))
	var source = str(commands[index].parameters[1 if int(commands[index].code)==111 else 0]) if Scripts.NativeSource.is_native(binding) else "\n".join(lines)
	return Scripts.execute_bound(binding,source,state,{"owner":native_owner,"generation":native_owner._native_generation,"kind":"event","map_id":10,"event_id":event_id,"fields":script_fields,"stack_depth":0})

func original_commands(id: String) -> Array:
	var unit: Dictionary=Data.read_json("res://data/script_units.json",{}).units.get(id,{})
	var commands: Array=Data.record("CommonEvents",int(unit.origin.common_event_id)).list
	var index=int(unit.origin.command_index)-1
	var count=int(commands[index].get("_script_binding",{}).get("command_count",1))
	return commands.slice(index,index+count).duplicate(true)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
