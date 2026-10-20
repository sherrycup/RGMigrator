## 职责：回归验证：执行原公共事件 36 的完整指令与子调用链。
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
## The original CE36 remains editable/callable. Exercise its complete native
## command_117 chain, including the original CE2 HP settlement and CE14 growth.
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Custom=preload("res://runtime/scripts/00_Game/CustomDataState.gd")
const Scripts=preload("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
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
	var units: Dictionary=Data.read_json("res://data/script_units.json",{}).get("units",{})
	expect(units.get("event_000099",{}).get("status")=="generated","retained original CE36 fragment is generated rather than a skipped placeholder")
	var corrections: Array=Data.read_json("res://data/source_corrections.json",{}).get("entries",[])
	expect(corrections.any(func(entry):return entry.get("origin",{}).get("common_event_id")==36 and str(entry.get("original",entry.get("before",""))).contains("battle_data")),"legacy field repair keeps its original common-event provenance")
	_test_descriptions(state)
	_run_case(state,false)
	_run_case(state,true)
	for message in failures: printerr("FAIL: ",message)
	print("FLASH LEGACY FLOW: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func _run_case(state: Node,defeat_enemy: bool) -> void:
	state.actors.clear(); state.custom_data=Custom.new(state); Data.bind_custom_data(state.custom_data)
	state.script_session=null; state.party=[2]; state.variables={"14":[2,0],"1":0}
	state.switches.clear(); state.map_id=10; state.playing=true; state.gold=7
	state.flash_temp_fields=Custom.native_value(Data.read_json("res://data/flash_gameplay.json",{}).get("temp_defaults",{})).duplicate(true)
	var host=Host.new(); root.add_child(host)
	var map: Node=load("res://runtime/scripts/03_Map/MapRuntime.gd").new(); host.add_child(map); host.map=map
	map.map_data=Data.map(10).duplicate(true); map._loaded_id=10; state._game_ref=weakref(host)
	var floor_data=state.custom_data._floor(10)
	var event_id=int(floor_data.entries.keys()[0]); var entry: Dictionary=floor_data.entries[str(event_id)]
	var definition: Dictionary=map.map_data.events[str(event_id)]
	map.map_data.events={str(event_id):definition}
	var event: Node=load("res://runtime/scripts/03_Map/MapEvent.gd").new()
	event.event_id=event_id; event.character_id=event_id; event.map_id=10; event.map_runtime=map
	event.motion.relocate(Vector2i(int(definition.x),int(definition.y))); map.add_child(event); map._event_nodes.append(event)
	var player: Node=load("res://runtime/scripts/03_Map/MapCharacter.gd").new(); map.add_child(player)
	player.map_runtime=map; map.player_character=player
	var fields: Dictionary=entry.fields
	fields.maxhp=35 if defeat_enemy else 5000; fields.hp=fields.maxhp
	fields.atk=9; fields.pdef=3; fields.agi=10; fields.eva=3; fields.exp=30; fields.gold=11
	entry.erase("battle"); entry.erase("battler")
	var actor=state.actor(2)
	actor.set_project_parameter("maxhp",100 if defeat_enemy else 10000); actor.hp=actor.get_parameter("maxhp")
	actor.set_project_parameter("patk",20); actor.set_project_parameter("pdef",5); actor.set_project_parameter("agi",10)
	actor.project_fields.battle_animation=0; actor.set_level(1); actor.set_experience(0)
	var reference: Dictionary=state.custom_data.data_ref("floor_enemy",10,"",event_id)
	var prediction=Scripts.call_method(reference,"battle_result",[],state)
	expect(prediction.ok,"legacy flow uses the current ordinary prediction: "+str(prediction.get("message","")))
	if not prediction.ok:
		state._game_ref=null; host.queue_free(); return
	var result: Dictionary=prediction.value
	var before_hp=actor.hp; var before_enemy_hp=int(state.custom_data.values.floors["10"].entries[str(event_id)].battle.hp)
	var before_patience=int(state.custom_data.values.floors["10"].entries[str(event_id)].battle.patience)
	var interpreter: RefCounted=load("res://runtime/scripts/02_Event/EventInterpreter.gd").new()
	interpreter.managed=true; interpreter.map_runtime=map
	var diagnostics: Array=[]; var visited: Array=[]
	interpreter.diagnostic_requested.connect(func(message):diagnostics.append(message))
	interpreter.start([{"code":117,"indent":0,"parameters":[36]},{"code":121,"indent":0,"parameters":[83,83,0]},{"code":0,"indent":0,"parameters":[]}],event_id)
	for frame in 300:
		if not interpreter.running: break
		interpreter.advance(0.1,1)
		if not visited.has(interpreter.context.common_id): visited.append(interpreter.context.common_id)
	expect(not interpreter.running and diagnostics.is_empty(),"full original CE36 returns without a source diagnostic: "+str(diagnostics))
	expect(state.switches.get("83")==true and interpreter.context.stack.is_empty(),"retained CE36 returns to its native caller cursor")
	expect(visited.has(36) and visited.has(5) and visited.has(2) and visited.has(14),"the original 36 -> 5/2/14 common-event chain remains in use")
	var battle: Dictionary=state.custom_data.values.floors["10"].entries[str(event_id)].battle
	expect(actor.hp==max(before_hp-result.damage,0),"legacy CE2 deducts current main damage exactly once")
	expect(battle.hp==max(before_enemy_hp-int(result.enemy_damage),0),"legacy CE2 deducts current enemy damage exactly once")
	expect(battle.pending==null and not battle.get("patience_deferred",false),"legacy flow does not open or finish a second pending battle")
	expect(state.flash_temp_fields.hp_addition==0 and state.flash_temp_fields.enemy_hp_addition==0 and state.flash_temp_fields.battle_id==0,"original CE2 clears its shared settlement fields")
	if defeat_enemy:
		expect(battle.hp==0 and state.gold==18 and actor.experience==30,"original legacy defeat branch gives each enemy reward once")
		expect(actor.level==2 and Scripts._session(state).loaded_units.has("script_0318"),"original CE14 reaches generated Level_Up through the legacy flow")
		expect(battle.patience==before_patience,"legacy defeat branch does not invent patience settlement")
	else:
		expect(battle.hp>0 and state.gold==7 and actor.experience==0,"original legacy survived branch gives no enemy reward")
		expect(battle.patience==max(before_patience-1,0) and state.flash_temp_fields.event_erase==false,"original CE36 preserves its own patience-minus-one and erase flag")
		expect(actor.level==1,"original CE14 preserves a below-threshold actor level")
	state._game_ref=null; host.queue_free()

func _test_descriptions(state: Node) -> void:
	var storage: Dictionary=state.custom_data.gameplay().rules.get("storage",{})
	var descriptions: Dictionary=storage.get("skill_description",{})
	var easy: Dictionary=storage.get("skill_easy_description",{})
	expect(descriptions.size()==7 and easy.size()==1,"original source has seven full descriptions and one easy description")
	var expected={
		"41":"进行[分散度]次攻攻击，每次攻击造成[命中率]%\\C[2]\\FB[T]基础攻击伤害\\C[0]\\FB[F]",
		"61":"在进行一个攻击回合后，会以本回合造成伤害的10%额外进行一次\\C[5]\\FB[T]追击\\C[0]\\FB[F]",
		"62":"本回合以65%的攻击力进行四次独立攻击，若成功造成了伤害，则会打断对方\\C[4]\\FB[T]吟唱\\C[0]\\FB[F]。\\n回合结束后获得10%速度提升，持续3回合",
		"81":"当主攻角色每受到六次独立伤害后，卡洛斯以自身80%的攻击力进行一次\\C[5]\\FB[T]追击\\C[0]\\FB[F]",
		"101":"似乎面对任何敌人都能从中找到适合的形状，无视敌人10%的防御",
		"121":"主战角色每受到12次独立攻击后，艾蕾会以自身150%的攻击进行一次\\C[5]\\FB[T]追击\\C[0]\\FB[F]，并降低敌人10%防御3回合",
		"132":"该被动分为关闭/开启两种状态。\\n  关闭时受到野生敌人的伤害减少20%。\\n  开启时受到野生敌人的伤害增加20%，若本次战斗将敌人击败，会将该敌人此时的耐心值转化为捕获值，当捕获值到达一定数量后（各种魔物捕获值不同）即可捕获此类魔物，并使用魔物的相关技能。"
	}
	for id in expected: expect(descriptions.get(id)==expected[id],"source skill description "+id+" preserves exact wording and escape codes")
	expect(easy.get("61")=="在进行一次攻击后会额外造成一次低倍率的\\C[5]\\FB[T]追击\\C[0]\\FB[F]","source easy description keeps its exact escape codes")

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
