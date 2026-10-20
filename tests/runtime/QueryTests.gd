## 职责：回归验证：验证生成脚本查询分析、来源归属及实际状态行为。
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
##   func expect(ok: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func bound(scripts: Script,unit: Dictionary,state: Node,event_id: int,fields: Dictionary) -> Dictionary
##     参数 scripts（Script；必填）：原脚本来源或脚本记录集合。
##     参数 unit（Dictionary；必填）：脚本迁移或执行单元的记录。
##     参数 state（Node；必填）：正式游戏运行状态；沿用现有 RuntimeState 实例。
##     参数 event_id（int；必填）：当前地图上的事件编号；0 的具体含义由调用入口约定。
##     参数 fields（Dictionary；必填）：字段名称或字段值集合。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
const Proof=preload("res://runtime/scripts/10_Support/Scripting/ScriptQueryProof.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func bound(scripts: Script,unit: Dictionary,state: Node,event_id: int,fields: Dictionary) -> Dictionary:
	return scripts.execute_bound({"unit_id":unit.generated_path.get_file().trim_suffix(".gd"),"source_sha256":unit.source_sha256},unit.source,state,{"kind":"event","map_id":10,"event_id":event_id,"fields":fields,"index":0})
func run() -> void:
	var scripts=load("res://runtime/scripts/10_Support/Scripting/ScriptRuntime.gd")
	var state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.player_x=2; state.player_y=2; state.party=[2,3]; state.variables["14"]=[2,3]; state.actor(2); state.actor(3)
	var game=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); game.set_process(false)
	await process_frame; game.reset_event_execution(); game._player.set_process(false); game._event_ui.cancel_all(); game._dialogue.dismiss()
	var units: Dictionary=Data.read_json("res://data/script_units.json",{}).units
	expect(Proof.plan(units.event_000085).get("kind")=="expression" and Proof.plan(units.event_000030).get("kind")=="expression","original regex and scalar temporary comparisons are proven read-only")
	expect(Proof.plan(units.event_000087).get("kind")=="guard" and Proof.plan(units.event_000095).is_empty(),"guarded branches and ordinary writes remain distinct")
	var clear={"origin":{"command_code":111},"ast":{"body":[{"kind":"call","name":"attr_addition_clear","arguments":[],"block":{},"receiver":{"kind":"name","name":"$game_temp"}}]}}
	expect(Proof.plan(clear).is_empty(),"the mutating temporary getter is excluded")
	clear.ast.body[0].name="puts_start"
	expect(Proof.plan(clear).is_empty(),"global debug helpers are excluded even on a temporary-service receiver")
	expect(Proof.plan(units.event_000107).get("kind")=="expression" and Proof.plan(units.event_000109).get("kind")=="expression","both original parallel door checks are proven read-only")
	var doors=state.custom_data.values
	var left=bound(scripts,units.event_000107,state,72,{}); var right=bound(scripts,units.event_000109,state,74,{})
	expect(left.ok and right.ok and is_same(doors,state.custom_data.values),"parallel coordinate and event-name lookups retain the live graph")
	state.flash_temp_fields.door_id=1
	var prior: Dictionary=state.custom_data.values
	var scalar=bound(scripts,units.event_000030,state,22,{})
	expect(scalar.ok and scalar.value==true and is_same(prior,state.custom_data.values),"scalar conditions retain the mutable graph")
	var fields={}; fields.self=fields; state.variables["610"]=fields
	prior=state.custom_data.values
	var regex=bound(scripts,units.event_000085,state,9,fields)
	expect(regex.ok and regex.value=="血瓶<20>" and fields.__rgm_regex.groups[1]=="<20>","regex query preserves matched text and captures")
	expect(is_same(prior,state.custom_data.values) and is_same(state.variables["610"],fields) and is_same(fields.self,fields),"regex fields preserve aliases and cycles")
	state.variables.erase("610"); fields.erase("self")
	prior=state.custom_data.values
	var missed=bound(scripts,units.event_000087,state,22,{})
	expect(missed.ok and missed.value==null and is_same(prior,state.custom_data.values),"unmatched original branch skips a full transaction")
	prior=state.custom_data.values
	var matched=bound(scripts,units.event_000087,state,10,{})
	expect(matched.ok and matched.common_event_id==3 and state.flash_temp_fields.gem_id==1 and is_same(prior,state.custom_data.values),"matched branch writes the live graph in direct mode")
	state.flash_temp_fields.door_id={"__ruby_class":"Object","fields":{}}; prior=state.custom_data.values
	var comparison=bound(scripts,units.event_000030,state,22,{})
	expect(comparison.ok and comparison.value==false and is_same(prior,state.custom_data.values),"non-scalar comparison retains Ruby semantics on the live graph")
	state.flash_temp_fields.door_id=1
	var unit: Dictionary=units.event_000030; var path: String=unit.generated_path; var original=FileAccess.get_file_as_string(path)
	var edited=original.replace("\treturn result","\tenv._custom.temp_fields[\"manual_query_probe\"] = 47\n\treturn result")
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(edited); file.close(); prior=state.custom_data.values
	var manual=bound(scripts,unit,state,22,{})
	file=FileAccess.open(path,FileAccess.WRITE); file.store_string(original); file.close()
	expect(manual.ok and state.flash_temp_fields.get("manual_query_probe")==47 and is_same(prior,state.custom_data.values),"edited generated files are reloaded and write the live graph")
	state.flash_temp_fields.erase("manual_query_probe"); prior=state.custom_data.values
	var restored=bound(scripts,unit,state,22,{})
	expect(restored.ok and restored.value==true and is_same(prior,state.custom_data.values),"restored source is reloaded and retains direct execution")
	var env: RefCounted=state.script_session; env.execution_context={"fields":{}}; var before=state.flash_temp_fields.door_id
	env.begin_query({}, {"kind":"expression"}); env.invoke(env._custom.data_ref("temp"),"door_id=",[99]); var stopped=env.finish_query(null)
	expect(stopped.get("retry_full_transaction",false) and state.flash_temp_fields.door_id==before and env._snapshot.is_empty(),"unexpected mutation is rejected before touching live data")
	game.queue_free(); await process_frame
	for failure in failures: printerr("FAIL: ",failure)
	print("FLASH QUERY: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
