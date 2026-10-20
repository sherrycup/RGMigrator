## 职责：回归验证：验证自定义数据运行覆盖、脚本访问及存档恢复。
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
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func execute(name: String,state: Node,env: RefCounted) -> Dictionary
##     用途：执行该脚本或已准备的操作。
##     参数 name（String；必填）：对象、资源或字段名称。
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 env（RefCounted；必填）：当前脚本调用共享的 ScriptSemantics 会话。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var checks=0
var failures: Array[String]=[]
class FloorEvent extends Node:
	var motion={"cell":Vector2i(7,13)}
class FloorMap extends Node:
	var events={}
	func event_node(id: int) -> Node: return events.get(id)
class FloorGame extends Node:
	var map: Node
	func event_map() -> Node: return map
func _init() -> void: call_deferred("run")
func run() -> void:
	var state: Node=root.get_node("RuntimeState")
	var data: Script=load("res://runtime/scripts/00_Game/RuntimeData.gd")
	var runtime: Script=load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
	var decimal: Script=load("res://runtime/scripts/10_Support/Utilities/DecimalInteger.gd")
	var codec: Script=load("res://runtime/scripts/10_Support/Persistence/SaveCodec.gd")
	state.begin_new_game(data.system(),{"enabled":false})
	for source_unit in data.read_json("res://data/custom_units.json",{"units":{}}).units.values():
		var compiled: Script=load(source_unit.generated_path)
		expect(compiled!=null and compiled.can_instantiate(),"real generated data expression compiles: "+str(source_unit.generated_path))
	var env: RefCounted=runtime._session(state)
	var source_hp: Variant=data.source_record("Enemies",1).maxhp
	var executed=execute("data_access",state,env)
	expect(executed.ok and executed.value==12345678901,"generated data getter/setter handles source values above int32")
	expect(data.source_record("Enemies",1).maxhp==source_hp and data.record("Enemies",1).maxhp==12345678901,"mutable definitions are session overrides and native readers share them")
	expect(state.variables["8188"][1].__ruby_hash.values()[0]==25,"script variables retain arrays and typed Hash values")
	var before=JSON.stringify([state.variables,state.custom_data.snapshot(),state.gold])
	var bad=execute("rollback",state,env)
	expect(not bad.ok and before==JSON.stringify([state.variables,state.custom_data.snapshot(),state.gold]),"failure rolls back nested variable, record and money together")
	state.set_event_variable(8190,9)
	var unit={"pure_expression":true,"status":"generated","source":"$game_variables[8190] + 2","source_sha256":"$game_variables[8190] + 2".sha256_text(),"generated_path":"res://runtime/generated/data_test_expression.gd","compiler_format":"rgm-gdscript-v2"}
	var custom_registry: Dictionary=data.read_json("res://data/custom_units.json",{"units":{}}).duplicate(true)
	custom_registry.units["data_test_expression"]=unit; data._cache["res://data/custom_units.json"]=custom_registry
	var expression_result=runtime.evaluate_data_expression("data_test_expression",state)
	if not expression_result.ok: printerr(expression_result)
	expect(expression_result.ok and expression_result.get("value")==11,"analyzable data expressions execute generated GDScript")
	if state.custom_data.manifest.profile=="flash":
		executed=execute("flash_attributes",state,env)
		expect(executed.ok and executed.value==37 and state.custom_actor_attributes(2).tp_plus.patk==37,"source custom actor attribute is shared with menu snapshots")
		expect(state.custom_data.currency("kin")==50 and state.custom_data.currency("spar:3")==17,"finite currency dispatch retains original argument order")
		expect(not state.gain_currency("kin",0.5).ok,"fractional money is rejected")
		state.gain_currency("kin",999999999); expect(state.custom_data.currency("kin")==9999999,"source KIN cap applies")
		var maps: Array=state.custom_data.manifest.floors.maps.keys()
		if not maps.is_empty():
			var map_id=10; env.begin({"kind":"floor_test"})
			var floor_ref: Dictionary=env._custom.data_ref("floor",map_id)
			var enemies: Variant=env.invoke(floor_ref,"enemies",[])
			var count: Variant=env.invoke(enemies,"size",[])
			var source_entries: Dictionary=env._custom.values.floors[str(map_id)].entries
			expect(count==2,"real Map010 includes event70 at y13 and excludes event71 at y15")
			if not source_entries.is_empty():
				var id=int(source_entries.keys()[0]); var pos: Array=source_entries[str(id)].position
				var at: Variant=env.invoke(floor_ref,"enemy_check",pos)
				expect(at!=null and at[0]==id,"floor coordinate lookup retains original event ID")
				var by_id: Variant=env.index_get(enemies,id)
				expect(by_id!=null and by_id[0]==pos,"floor event lookup points to the same data instance")
				env.invoke(at[1],"hp=",[3]); expect(env.invoke(by_id[1],"hp",[])==3,"both floor indices share a mutable monster")
			expect(env.finish(null).ok,"floor changes commit")
			var fixture_game=FloorGame.new(); var fixture_map=FloorMap.new(); var fixture_event=FloorEvent.new()
			fixture_game.map=fixture_map; fixture_map.events[70]=fixture_event
			root.add_child(fixture_game); fixture_game.add_child(fixture_map); fixture_map.add_child(fixture_event)
			var old_map_id=state.map_id; state.map_id=map_id; state.register_game(fixture_game)
			fixture_event.motion.cell=Vector2i(8,12)
			env.begin({}); floor_ref=env._custom.data_ref("floor",map_id); env.invoke(floor_ref,"update",[])
			expect(env.invoke(floor_ref,"enemy_check",[7,13])==null and env.invoke(floor_ref,"enemy_check",[8,12])!=null,"live event movement updates the floor coordinate index")
			env.finish(null); fixture_map.events.erase(70)
			env.begin({}); floor_ref=env._custom.data_ref("floor",map_id); env.invoke(floor_ref,"update",[])
			expect(env.invoke(floor_ref,"enemy_event",[70])==null and env.invoke(floor_ref,"variety",[]).is_empty(),"erased live events disappear from queries and species lists")
			env.finish(null); state._game_ref=null; state.map_id=old_map_id; fixture_game.queue_free(); await process_frame
			env.begin({}); env.invoke(env._custom.data_ref("floor",map_id),"clear_enemies",[]); env.finish(null)
			expect(state.custom_data.values.floors[str(map_id)].entries.is_empty(),"floor clear mutates the real session data")
		else: expect(false,"source floor manifest is present")
	else:
		executed=execute("big_currency",state,env)
		expect(executed.ok and executed.value==true,"Ruby Bignum source cap and comparisons stay exact")
		expect(str(state.gold)==str(decimal.add(state.custom_data.currency_maximum(),-123)),"gold loss preserves all digits above int64")
		expect(data.source_record("Weapons",150).str_plus==10000000000,"real equipment loader retains ten billion bonus")
		env.begin({}); var monster: Variant=env.read_name("Monster",{},null,"Object")
		env.invoke(monster,"set",[997,123456789012,20,30,40,2,-1,-1,2]); expect(env.finish(null).ok,"Monster.set adapter commits dynamic source arguments")
		expect(state.custom_record("Enemies",997).maxhp==246913578024,"Monster rate is applied exactly to the first three fields")
	var saved: Dictionary=codec.capture(state); var prepared: Dictionary=codec.prepare(saved)
	expect(prepared.ok,"custom scalar and collection data save with native progress")
	if prepared.ok:
		var money: Variant=state.gold; var snapshot=JSON.stringify(state.custom_data.snapshot()); var vars=JSON.stringify(state.variables)
		state.begin_new_game(data.system(),{"enabled":false}); state.restore_prepared(prepared)
		expect(state.gold==money and JSON.stringify(state.custom_data.snapshot())==snapshot and JSON.stringify(state.variables)==vars,"restore preserves money, raw attributes, floor mutations, arrays and Hash")
		var corrupt=saved.duplicate(true); corrupt.custom_data.money["unknown"]=1
		expect(not codec.prepare(corrupt).ok,"unknown currency in save is rejected before restore")
		corrupt=saved.duplicate(true); corrupt.custom_data.actors["1"]=[]
		expect(not codec.prepare(corrupt).ok,"malformed custom actor state is rejected before restore")
	var menu: Control=load("res://runtime/scripts/08_Menu/Main/MenuScene.gd").new(); root.add_child(menu); await process_frame
	menu.show_currency_details()
	expect(menu._data_details.get_node("Data").text.contains(str(state.gold)),"menu currency detail reads the committed exact balance")
	if state.custom_data.manifest.profile=="flash": expect("\n".join(menu._attribute_lines(state.custom_actor_attributes(2))).contains("物攻：37"),"menu attribute labels read the committed original actor field")
	menu.queue_free(); await process_frame
	state.begin_new_game(data.system(),{"enabled":false})
	expect(state.gold==0 and state.custom_data.values.records.is_empty() and state.variables.is_empty(),"new game discards prior mutable custom data")
	var shared: Array=[1]; state.variables["8188"]=[shared,shared]
	expect(codec.capture(state).has("script_error"),"shared data is rejected even before a script session exists")
	state.variables.clear()
	for failure in failures: printerr("FAIL: ",failure)
	print("CUSTOM DATA RUNTIME: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://runtime/generated/data_test_expression.gd"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://runtime/generated/data_test_expression.gd.uid"))
	quit(0 if failures.is_empty() else 1)
func execute(name: String,state: Node,env: RefCounted) -> Dictionary:
	var script: Script=load("res://.godot/v044_generated/"+name+".gd")
	return script.execute(state,env) if script!=null else {"ok":false,"message":"Missing generated test: "+name}
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
