## 职责：回归验证：执行事件层级指引、列表选择与结构可视化场景。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run(parent: Node, documents: RefCounted, capture: Callable = Callable()) -> void
##     用途：执行当前迁移流程或回归场景。
##     参数 parent（Node；必填）：父节点、父对象或继承关系的上级。
##     参数 documents（RefCounted；必填）：编辑器文档服务，持有独立草稿与保存接口。
##     参数 capture（Callable；默认值 Callable()）：已捕获的现场数据或画面。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(ok: bool, message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 ok（bool；必填）：本项检查是否通过。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

@tool
extends RefCounted
var checks := 0
var failures: Array[String] = []

func run(parent: Node, documents: RefCounted, capture: Callable = Callable()) -> void:
	var tree := parent.get_tree()
	var commands: Script = load("res://addons/rgm_editor/03_Event/Editor_Commands.gd")
	var window := Window.new(); window.title="0.40 条件、循环与多行指令层级"; window.size=Vector2i(1000,680); parent.add_child(window)
	var editor: Control = load("res://addons/rgm_editor/03_Event/Editor_CommandList.gd").new(); editor.custom_minimum_size=Vector2(1000,680); window.add_child(editor)
	var sample: Array = [commands.command(111,0,[0,1,0]),commands.command(101,1,["外层文章首句"]),commands.command(401,1,["外层文章续句"]),commands.command(111,1,[0,2,0]),commands.command(108,2,["内层注释首句"]),commands.command(408,2,["内层注释续句"]),commands.command(112,2),commands.command(101,3,["第三层循环文章"]),commands.command(401,3,["循环文章续行"]),commands.command(413,2),commands.command(411,1),commands.command(108,2,["内层否则分支"]),commands.command(412,1),commands.command(411,0),commands.command(108,1,["外层否则分支"]),commands.command(412,0),commands.command(0)]
	editor.configure(sample,documents); window.popup(Rect2i(Vector2i(20,20),window.size))
	for frame in 8: await tree.process_frame
	expect(editor._structures==[{"start":0,"end":16,"indent":0},{"start":3,"end":13,"indent":1},{"start":6,"end":10,"indent":2}],"outer condition / nested condition / loop include matching end markers")
	expect(editor._rows[7].get_text(0).begins_with("            "),"three nested levels reserve distinct command guide positions")
	expect(editor._rows[8].get_description(0).contains("循环文章续行"),"native continuation text remains available")
	if capture.is_valid(): await capture.call(window,"structure-guides")
	# Actual click on a continuation selects the complete text command only.
	var row: TreeItem=editor._rows[8]
	row.select(0); editor._command_list.ensure_cursor_is_visible()
	for frame in 2: await tree.process_frame
	var point: Vector2=editor._command_list.get_item_area_rect(row).get_center()
	var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	editor._command_list.gui_input.emit(event)
	var selected: Array=[]
	for i in editor._rows.size():
		if editor._rows[i].is_selected(0): selected.append(i); expect(editor._rows[i].is_selected(1),"selection includes full status column")
	expect(selected==[7,8],"continuation selection excludes enclosing conditions and loop: selected=%s point=%s tree_size=%s" % [selected,point,editor._command_list.size])
	expect(editor.draft()==sample,"drawing and selection leave event records intact")
	if capture.is_valid(): await capture.call(window,"structure-selected")
	# Long outer structure must continue through scrolling and to its end.
	var long_list: Array=[commands.command(111,0,[0,1,0])]
	for i in 80: long_list.append(commands.command(108,1,["滚动内部指令 %d" % i]))
	long_list.append(commands.command(412)); long_list.append(commands.command(0))
	editor.configure(long_list,documents); editor._select_block(82); editor._command_list.ensure_cursor_is_visible()
	for frame in 8: await tree.process_frame
	expect(editor._structures[0].end==82 and int(editor._list[81].code)==412,"long structure includes its true ending after scrolling")
	if capture.is_valid(): await capture.call(window,"structure-scrolled")
	window.queue_free(); await tree.process_frame

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
