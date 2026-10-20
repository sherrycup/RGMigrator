## 职责：回归验证：验证跟随者队列、移动同步和现场恢复。
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
##   func advance(player: Node,followers: RefCounted,frames: int) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 player（Node；必填）：当前玩家人物实例。
##     参数 followers（RefCounted；必填）：当前跟随者状态或显示集合。
##     参数 frames（int；必填）：需要推进或采样的帧数。
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
const Semantics=preload("res://runtime/scripts/10_Support/Scripting/ScriptSemantics.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var state=root.get_node("RuntimeState"); state.begin_new_game(Data.system(),{"enabled":false})
	state.map_id=10; state.party=[1,2]; state.variables["14"]=[2,1]
	var game: Node=load("res://runtime/scripts/10_Support/Boot/Game.gd").new(); game._events_enabled=false; root.add_child(game)
	await process_frame
	game._events_enabled=false; game.reset_event_execution(); game.set_process(false)
	var player: Node=game._player; player.set_process(false); player.motion.configure({"through":true,"move_speed":5}); player.move_to(3,3)
	var followers=state.flash_followers; followers.refresh()
	expect(followers.graphics[0].id==1 and player._name==state.actor(2).character_name,"actual support role is first follower, independently of the party's main actor order")
	expect(followers.move_list==[null,null,null,null,null] and followers.motions[0].cell==Vector2i(3,3),"actual moveto initializes the source five-slot nil history and follower positions")
	expect(player.move_straight(6) and followers.motions[0].is_idle(),"first successful player step guards source nil entries and does not advance the follower")
	advance(player,followers,4)
	expect(player.move_straight(6) and followers.motions[0].moving() and followers.motions[0].target==Vector2i(4,3),"second successful player step replays first action once into the support follower")
	advance(player,followers,4)
	expect(followers.motions[0].cell==Vector2i(4,3) and player.motion.cell==Vector2i(5,3),"source60Hz motion keeps the support exactly one successful move behind")
	var queue=followers.move_list.duplicate(true)
	expect(not player.move_straight(0) and followers.move_list==queue,"failed player movement never enters the follower history")
	player.move_to(3,3)
	expect(player.move_diagonal(Vector2i(1,1)),"actual diagonal movement starts")
	advance(player,followers,4); player.move_straight(6)
	expect(followers.motions[0].target==Vector2i(4,4),"source diagonal action preserves both offsets through the delayed queue")
	advance(player,followers,4); player.move_to(3,3)
	player.jump(1,0); advance(player,followers,12); player.move_straight(6)
	expect(followers.motions[0].jumping() and followers.motions[0].target==Vector2i(4,3),"successful jump is replayed as a jump with source offsets, rather than a walk")
	player.opacity=92; player.step_anime=true; player.transparent=true; followers.refresh()
	expect(followers.motions[0].options.opacity==92 and followers.motions[0].options.step_anime and followers.motions[0].options.transparent,"followers copy player opacity, step animation, speed and transparency")
	player.transparent=false; state.switches["20"]=true; followers.set_transparent_actors(true); followers.refresh()
	expect(not followers.motions[0].options.transparent,"source disabled transparent switch and unused setter do not invent a hide mechanism")
	state.variables["226"]={"2:51":1}; followers.refresh()
	expect(followers.graphics.any(func(row): return row.name=="152-Animal02"),"original variable226 slot51 creates the optional cat using a free stable follower view")
	player.move_to(3,3)
	var env=Semantics.new(state); env.begin({"kind":"follower-source"})
	var party=state.custom_data.data_ref("party")
	env.invoke(party,"set_characters_xy",[0,6,6])
	expect(env.invoke(party,"get_characters_xy",[0])==[6,6] and followers.motions[0].cell==Vector2i(6,6),"source coordinate bridge moves the live follower immediately")
	expect(env.finish(null).ok and followers.motions[0].cell==Vector2i(6,6),"source party follower API commits to the same formal motion state")
	env.begin({"kind":"follower-direct"}); env.invoke(party,"set_characters_xy",[0,4,4])
	expect(followers.motions[0].cell==Vector2i(4,4) and env.finish(null).ok,"a later script updates the same live follower motion without a staged copy")
	expect(game.event_map().transfer(8,2,2,6) and followers.motions.all(func(m): return m.cell==Vector2i(2,2)) and followers.move_list==[null,null,null,null,null],"actual cross-map transfer relocates every follower and clears prior-map history")
	var old_motions=followers.motions.duplicate(); state.begin_new_game(Data.system(),{"enabled":false})
	expect(followers.motions[0]!=old_motions[0] and followers.move_list==[null,null,null,null,null],"new game discards previous follower state and reconnects surviving views")
	game.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH FOLLOWERS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func advance(player: Node,followers: RefCounted,frames: int) -> void:
	for i in frames: followers.advance(1.0/60); player.advance_motion(1.0/60)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
