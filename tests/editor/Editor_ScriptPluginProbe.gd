## 职责：回归验证：检查实际插件首次打开脚本窗口、窗口归属、关闭重开和 F8 输入。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func run(plugin: EditorPlugin,panel: Control) -> void
##     用途：执行当前迁移流程或回归场景。
##     参数 plugin（EditorPlugin；必填）：Godot EditorPlugin 插件实例。
##     参数 panel（Control；必填）：魔塔编辑器主面板实例。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

@tool
extends RefCounted
var checks=0
var failures: Array[String]=[]
func run(plugin: EditorPlugin,panel: Control) -> void:
	var tree=plugin.get_tree()
	var editor_window=EditorInterface.get_base_control().get_window()
	var embedded="--embed-probe" in OS.get_cmdline_user_args()
	if embedded:
		editor_window.gui_embed_subwindows=true
		editor_window.size=Vector2i(1280,900)
		editor_window.position=Vector2i(-10000,-10000)
	var pending: Array=[panel]; var button: Button=null
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		if node is Button and node.text=="脚本工作区 F8": button=node; break
		pending.append_array(node.get_children())
	expect(button!=null,"workspace toolbar button exists in actual EditorPlugin")
	expect(not panel._scripts.visible,"workspace starts hidden before its first click")
	expect(panel._scripts.transient and panel._scripts.exclusive,"workspace is an editor-owned modal window")
	if button!=null:
		print("PLUGIN BEFORE: ",panel._scripts.visible," / editor=",Engine.is_editor_hint())
		var started=Time.get_ticks_msec()
		button.pressed.emit()
		print("PLUGIN OPEN MS: ",Time.get_ticks_msec()-started)
		for i in 5: await tree.process_frame
		print("PLUGIN AFTER: ",panel._scripts.visible," / source=",panel._scripts._source!=null," / entries=",panel._scripts._entries.size())
		expect(panel._scripts.visible,"clicking actual editor button shows the workspace")
		expect(panel._scripts._source!=null and panel._scripts._entries.size()>=483,"actual editor loads sources and events")
		expect(editor_window.get_last_exclusive_window()==panel._scripts,"workspace is the editor's active modal window")
		if embedded and DisplayServer.get_name()!="headless":
			for i in 8: await tree.process_frame
			RenderingServer.force_draw(false); await tree.process_frame
			expect(editor_window.get_texture().get_image().save_png("res://.godot/script_plugin_click.png")==OK,"actual editor renders the workspace after clicking")
		panel._scripts.close_requested.emit()
		expect(not panel._scripts.visible and editor_window.get_last_exclusive_window()==editor_window,"closing releases the editor's modal window")
		button.pressed.emit(); await tree.process_frame
		expect(panel._scripts.visible,"actual editor can reopen the workspace")
		panel._scripts._close()
		var key=InputEventKey.new(); key.keycode=KEY_F8; key.pressed=true
		editor_window.push_input(key)
		for i in 5: await tree.process_frame
		expect(panel._scripts.visible,"F8 opens the workspace through actual editor input")
		panel._scripts._close()
	for failure in failures: printerr("FAIL: ",failure)
	print("SCRIPT PLUGIN PROBE: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	var file=FileAccess.open("res://.godot/script_plugin_probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures})); file.close()
	tree.quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
