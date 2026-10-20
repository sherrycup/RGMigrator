## 职责：回归验证：验证消息控制器的队列、等待、输入与结束流程。
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
##   func cmd(code: int,parameters: Array) -> Dictionary
##     参数 code（int；必填）：对应指令、按键或操作的编码。
##     参数 parameters（Array；必填）：按对应接口或事件指令约定排列的参数。
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
var checks=0
var failures: Array[String]=[]
var state: Node
var controller: RefCounted
func _init() -> void: call_deferred("run")
func run() -> void:
	state=root.get_node("RuntimeState"); state.flash_preferences.apply_display=false
	state.begin_new_game(Data.system(),{"enabled":false}); state.party=[2]; state.variables["14"]=[2,0]; state.switches["6"]=true
	controller=state.flash_messages
	expect(controller!=null and controller.history().is_empty(),"RuntimeState owns one reset message controller")
	expect(not controller.present({"kind":"choice","lines":[],"choices":null,"cancel":0}).ok and controller.boxes.is_empty() and controller.history().is_empty(),"malformed message packet rejects before history/UI state mutation")
	var words=state.custom_data.named("Message::Words"); var pickaxe=int(state.custom_data.gameplay().rules.constants.PICKAXE_ITEM_ID)
	expect(state.custom_data.invoke(words,"item_fails",[pickaxe,0])=="对面不是墙体" and state.custom_data.invoke(words,"item_fails",[pickaxe,2])==null,"source Words module retains exact tool texts and nil unmatched parameter")
	var result=controller.present({"kind":"message","lines":["\\m[艾蕾]\\p[320,500]\\mo[2]\\>你好\\C[5]闪翼"]},10,7)
	expect(result.ok and controller.message_window_showing(),"original metadata creates actual blocking message")
	var entry: Dictionary=controller.boxes[0]
	expect(entry.layout.name_text=="艾蕾" and entry.layout.fixed_anchor==Vector2(320,500) and entry.layout.box_size.y>32,"source speaker/name/explicit position contribute measured layout")
	for i in 20: controller.tick()
	expect(entry.model.plain_text()=="你好闪翼" and entry.model.state==3,"actual controller completes styled text through source state model")
	var responses: Array=[]
	controller.responded.connect(func(id,kind,value):responses.append([id,kind,value]))
	controller.confirm()
	for i in 10: controller.tick()
	expect(controller.boxes.is_empty() and responses==[[10,"message",null]],"closing releases request exactly once and removes its rendered state")
	expect(controller.history()==[["艾蕾","\\m[艾蕾]\\p[320,500]\\mo[2]\\>你好\\C[5]闪翼"]],"source history keeps raw control text independently of live glyphs")
	var before=controller.history(); result=controller.present({"kind":"message","lines":["\\fg[missing-face,0]x"]},11)
	expect(not result.ok and controller.boxes.is_empty() and controller.history()==before,"missing face rejects construction without partial box/history")
	result=controller.present({"kind":"message","lines":["\\mo[2]\\>a\\MR\nb\n\\a[2]c"]},12)
	entry=controller.boxes[0]
	expect(result.ok and entry.layout.rows.size()==2 and entry.layout.rows[0].width>entry.layout.rows[1].width,"MR merges source lines while A selects whole-row alignment")
	controller.reset()
	controller.viewport_size=Vector2(280,480)
	controller.present({"kind":"message","lines":["\\mo[2]\\>"+"很长的中文".repeat(30)]},13)
	entry=controller.boxes[0]
	expect(entry.layout.box_size.x<=280 and entry.layout.rows.size()>4,"known viewport width wraps long text using its font metrics")
	controller.reset(); controller.viewport_size=Vector2(640,640)
	state.flash_temp_fields.unblocking_text="\\p[320,500]\\mo[1]\\>获得物品\\bo[255]\\t[1]"; state.flash_temp_fields.event_id=[0,9]
	controller.advance(0)
	expect(state.flash_temp_fields.unblocking_text==null and state.flash_temp_fields.event_id==[0,0] and not controller.message_window_showing(),"source hint consume atomically clears temp binding without blocking map")
	for i in 12: controller.tick()
	expect(controller.boxes.is_empty() and controller.history(true).size()==1,"hint independently expires with original T timing and records its channel")
	controller.present({"kind":"message","lines":["\\mo[2]\\>a\\!b"]},-1,0,true)
	for i in 3: controller.tick()
	var hint=controller.boxes[0]; var consumed=controller.confirm(); controller.tick()
	expect(not consumed and hint.model.plain_text()=="ab","confirmation repairs source paused hint without blocking map or consuming player key")
	controller.reset()
	for id in 102:
		controller.present({"kind":"message","lines":[str(id)]}); controller.reset()
	expect(controller.history().size()==100 and controller.history()[0][1]=="2" and controller.history()[-1][1]=="101","source dialogue limit evicts oldest raw records")
	for id in 51:
		controller.present({"kind":"message","lines":[str(id)]},-1,0,true); controller.reset()
	expect(controller.history(true).size()==50 and controller.history(true)[0][1]=="1","source hint limit is independent 50")
	controller.present({"kind":"choice","lines":["问题"],"choices":["同意","拒绝"],"cancel":5},20)
	entry=controller.boxes[0]; entry.model.process=0; entry.model.state=3
	controller.handle_key(KEY_DOWN); controller.confirm()
	for i in 10: controller.tick()
	expect(responses[-1]==[20,"choice",1] and controller.history()[-1]==["分支","→ 同意\\n→ 拒绝\\n"],"choice returns selected source branch only after close and preserves history arrow format")
	controller.present({"kind":"choice","lines":[],"choices":["A","B"],"cancel":0},21)
	entry=controller.boxes[0]; entry.model.process=0; entry.model.state=3; controller.handle_key(KEY_ESCAPE)
	expect(entry.model.state==3,"source uncancellable choice cannot resolve by escape")
	controller.reset()
	state.variables["99"]=12
	controller.present({"kind":"number","lines":["数值"],"variable":99,"digits":3},22)
	entry=controller.boxes[0]; entry.model.process=0; entry.model.state=3; controller.handle_key(KEY_3); controller.confirm()
	for i in 10: controller.tick()
	expect(responses[-1]==[22,"number",123],"numeric source packet keeps its digits and initial variable")
	# Real EventInterpreter -> EventUIBroker -> DialogueOverlay -> Flash controller.
	var dialogue=load("res://runtime/scripts/06_Message/DialogueOverlay.gd").new(); root.add_child(dialogue); dialogue.set_process(false); dialogue._flash_view.set_process(false)
	var owner=load("res://runtime/scripts/02_Event/EventInterpreter.gd").new(); var broker=load("res://runtime/scripts/02_Event/EventUIBroker.gd").new(); broker.bind_interpreter(owner)
	broker.requested.connect(func(kind,payload,id):
		if kind=="message": dialogue.show_message(payload[0],id,payload[1])
		elif payload.size()==1: dialogue.show_event(payload[0],id)
		elif kind=="choice": dialogue.show_choices(payload[0],payload[1],id,payload[2]))
	dialogue.event_response.connect(func(id,_kind,value):broker.resolve(id,value)); dialogue.event_failed.connect(broker.reject)
	owner.start([cmd(101,["\\mo[2]\\>a\\.b\\!c"]),cmd(122,[77,77,0,0,99]),cmd(0,[])],42); broker.pump()
	expect(owner.wait_kind()=="message" and controller.boxes[0].event_id==42,"broker retains original event identity and waits on actual visible Flash message")
	for i in 5: controller.tick()
	expect(not owner.running and state.variables.get("77")==99 and dialogue.is_open() and controller.boxes[0].model.state==2,"source wake resumes actual interpreter once while paused box still blocks player")
	controller.confirm()
	for i in 8: controller.tick()
	controller.confirm()
	for i in 10: controller.tick()
	expect(not dialogue.is_open() and not broker.busy(),"remaining text finishes without reusing stale broker callback")
	owner.parallel=true
	owner.start([cmd(101,["\\mo[1]\\>提示\\bo[255]\\t[1]\\+"]),cmd(101,["续行"]),cmd(122,[78,78,0,0,7]),cmd(0,[])],8)
	expect(not owner.running and state.variables.get("78")==7 and str(state.flash_temp_fields.unblocking_text).ends_with("\n续行") and not broker.busy(),"parallel Flash 101 plus-append preserves nonblocking source execution")
	controller.advance(0)
	expect(controller.boxes.size()==1 and controller.boxes[0].hint and controller.boxes[0].event_id==8,"parallel source temp message uses actual hint channel/identity")
	controller.reset(); owner.parallel=false
	owner.start([cmd(101,["1"]),cmd(401,["2"]),cmd(401,["3"]),cmd(102,[["A","B","C"],5]),cmd(0,[])],3); broker.pump()
	expect(owner.wait_kind()=="choice" and controller.boxes[0].kind=="choice" and controller.boxes[0].payload.lines.size()==3,"Flash source allows merged choices up to eight source rows")
	owner.cancel(); broker.pump(); controller.reset()
	var source_lines: Array=[]
	for command in Data.record("CommonEvents",12).get("list",[]):
		if command.get("code")==101: source_lines.append(command)
	if not source_lines.is_empty():
		owner.start([source_lines[0],cmd(0,[])],0); broker.pump()
		expect(controller.boxes.size()==1 and controller.history()[-1][1]==str(source_lines[0].parameters[0]),"actual original CE12 article reaches Flash renderer/history with source text intact")
		owner.cancel(); broker.pump(); controller.reset()
	var memory=load("res://runtime/scripts/06_Message/MessageMemoryPage.gd").new(); root.add_child(memory)
	var old_history=controller.history().size()
	var unsafe_choice=controller.present({"kind":"choice","lines":["\\T[1]请选择"],"choices":["一","二"],"cancel":0},98)
	expect(not unsafe_choice.ok and controller.history().size()==old_history,"auto-closing choice rejects before history commit and cannot leave an unresolved broker wait")
	var unsafe_number=controller.present({"kind":"number","lines":["\\~"],"variable":10,"digits":2},99)
	expect(not unsafe_number.ok,"source close code cannot silently return a missing number-input result")
	expect(memory.index==memory.records.size()-1 and not memory.plain_text("\\m[名字]\\C[5]内容").contains("\\C"),"history selects latest and removes source control codes from visible text")
	memory.handle_key(KEY_TAB); expect(memory.mode_index==1 and memory.records==controller.history(true),"Tab history uses independent source hint records")
	controller.present({"kind":"message","lines":["unfinished"]},30); state.begin_new_game(Data.system(),{"enabled":false})
	expect(controller.boxes.is_empty() and controller.history().is_empty() and controller.history(true).is_empty(),"new game resets all active boxes and source history without stale callbacks")
	memory.queue_free(); dialogue.queue_free(); await process_frame
	for message in failures: printerr("FAIL: ",message)
	print("FLASH MESSAGE CONTROLLER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func cmd(code: int,parameters: Array) -> Dictionary: return {"code":code,"indent":0,"parameters":parameters}
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
