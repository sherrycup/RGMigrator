## 职责：回归验证：验证敌人显伤标签更新、存活过滤和异步结果处理。
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
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func settle(labels: Node) -> void
##     参数 labels（Node；必填）：控件或字段的显示名称集合。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
## 接口说明结束。

extends SceneTree
const Data=preload("res://runtime/scripts/00_Game/RuntimeData.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(640,640); var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false}); state.map_id=10; state.party=[2]; state.variables["14"]=[2,0]
	var actor=state.actor(2); actor.set_project_parameter("maxhp",300); actor.hp=300; actor.set_project_parameter("patk",30); actor.set_project_parameter("pdef",10); actor.set_project_parameter("agi",20)
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game); await process_frame; game.reset_event_execution(); game.set_process(false); game._player.set_process(false)
	var labels: Node
	for child in game.get_children():
		if child.get_script()!=null and child.get_script().resource_path.ends_with("EnemyMapLabels.gd"): labels=child
	labels.set_process(false); state.switches["3"]=false; labels._process(0)
	expect(not labels._canvas.visible and labels.rebuild_count==0,"source switch3 hides labels without executing hidden battle previews")
	var before_hp=actor.hp; var before_gold=state.gold; var before_inventory=state.inventory.duplicate(); state.switches["3"]=true; labels._process(0)
	await settle(labels)
	expect(labels._canvas.visible and not labels.entries.is_empty(),"actual map enemy labels resolve original current enemy events")
	expect(actor.hp==before_hp and state.gold==before_gold and state.inventory==before_inventory,"map-label prediction never spends HP, gold or inventory")
	var rebuilds=labels.rebuild_count; game._camera.position.x+=16; labels._process(1.0/60)
	expect(labels.rebuild_count==rebuilds,"camera movement updates live positions without rebuilding label data")
	var type=load("res://runtime/scripts/03_Map/EnemyMapLabels.gd")
	expect(type.damage_grade(0,300)==1 and type.damage_grade(99,300)==2 and type.damage_grade(100,300)==3 and type.damage_grade(200,300)==4 and type.damage_grade(300,300)==5 and type.damage_grade(9999999,300)==0,"source damage grades preserve exact HP thirds and invincible sentinel")
	expect(type.damage_grade(0,0)==5 and type.damage_grade(10,0)==5,"source zero-HP grades preserve original NaN/infinity branch result without division exception")
	var event: Node=labels.entries[0].node.get_ref(); game._map.erase_event(event.event_id); labels._dirty=true; labels._process(0)
	expect(not labels.entries.any(func(entry):return entry.node.get_ref()==event),"erased source enemy releases its damage and patience labels")
	game._map.load_map(10)
	await settle(labels)
	expect(labels._last_result.thread_id!=OS.get_thread_caller_id(),"damage simulation runs on an actual background thread")
	var custom=state.custom_data; var floor=custom._floor(10); var gameplay=custom.gameplay()
	expect(floor.entries.values().all(func(entry):return not entry.has("battle") or entry.battle.cache==null),"map-wide labels do not serialize UI prediction caches into undo snapshots")
	var enemy: Node=labels.entries[0].node.get_ref(); var id=enemy.event_id
	var expected: Variant=gameplay.predict(10,id)
	expect(labels.entries[0].damage==int(expected.damage),"worker prediction equals the authoritative source battle calculator")
	var battle: Dictionary=floor.entries[str(id)].battle
	var hp: Variant=battle.hp
	battle.pending=expected.duplicate(true); battle.hp=0; battle.defeated=true
	labels.request_refresh(); labels._process(0)
	expect(not labels.entries.any(func(entry):return entry.node.get_ref()==enemy),"lethal pending battle hides label before enemy erase or next worker response")
	await settle(labels)
	expect(not labels.entries.any(func(entry):return entry.node.get_ref()==enemy),"completed worker cannot publish zero-damage label for a dying enemy")
	battle.pending=null; labels.request_refresh(); labels._process(0); await settle(labels)
	expect(not labels.entries.any(func(entry):return entry.node.get_ref()==enemy),"finish_battle clearing pending result cannot flash zero before event disappearance")
	battle.hp=hp; battle.defeated=false
	labels.request_refresh(); labels._process(0)
	var obsolete=labels._revision
	actor.set_project_parameter("patk",300)
	for i in 30: labels.request_refresh()
	labels._process(0); await settle(labels)
	expect(labels._last_result.revision>obsolete and labels._last_result.revision==labels._revision,"rapid state changes coalesce and discard stale damage results")
	expected=gameplay.predict(10,id)
	var restored=labels.entries.filter(func(entry):return entry.node.get_ref()==enemy)
	expect(restored.size()==1 and restored[0].damage==int(expected.damage),"latest actor attributes and revived enemy receive matching labels")
	var current_revision=labels._revision
	for i in 12:
		state.state_changed.emit(); labels._process(0); await process_frame
	expect(labels._revision==current_revision,"unchanged parallel-event notifications do not starve background damage publication")
	var stale=labels._last_result.duplicate(true); var old_entries=labels.entries
	stale.generation-=1; labels._accept_result(stale)
	expect(is_same(labels.entries,old_entries),"result for an earlier map generation cannot replace current labels")
	gameplay.simulator.registry.define_skill(0,func(definition):definition.display("thread catalog isolation"))
	labels.request_refresh(); labels._process(0); await settle(labels)
	expect(labels._last_result.revision==labels._revision,"catalog replacement during worker use reads a detached skill snapshot")
	game._menus._open_menu(); var hud: Node=game._flash_hud; hud._process(8.0/60); labels._process(0)
	expect(hud.window_process==0 and hud.itembar_process==0 and not labels._canvas.visible,"modal source page hides live HUD, item bar and map labels after original eight steps")
	game._menus.close_menu(); hud._process(8.0/60); labels._process(0)
	expect(hud.window_process==8 and hud.itembar_process==8 and labels._canvas.visible,"source map presentation returns after page closes without replacing actor state")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MAP LABELS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func settle(labels: Node) -> void:
	for i in 240:
		labels._process(0)
		if not labels._last_result.is_empty() and labels._last_result.revision==labels._revision and not labels._dirty: return
		await process_frame
	expect(false,"background damage request completes within four seconds")
