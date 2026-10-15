extends SceneTree
## Atomic selection and operations for native multiline command records.
var checks=0
var failures: Array[String]=[]

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func selected_rows(editor: Control) -> Array:
	var result: Array=[]
	for row in editor._command_list.get_root().get_children():
		if row.is_selected(0):
			result.append(int(row.get_metadata(0)))
			expect(row.is_selected(1),"selected command includes the status column")
	return result

func click_row(editor: Control, index: int, double_click: bool = false) -> void:
	var row=editor._command_list.get_root().get_children()[index]
	var position=editor._command_list.global_position+editor._command_list.get_item_area_rect(row).get_center()
	for pressed in [true,false]:
		var event=InputEventMouseButton.new(); event.position=position; event.global_position=position
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.double_click=double_click and pressed
		root.push_input(event,true)
	await process_frame

func run() -> void:
	root.size=Vector2i(1000,800); root.gui_embed_subwindows=true
	var commands=load("res://addons/rgm_editor/EditorCommands.gd")
	var docs=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var editor=load("res://addons/rgm_editor/EditorCommandList.gd").new()
	root.add_child(editor); editor.size=Vector2(900,750)
	var sample=[commands.command(101,0,["第一句"]),commands.command(401,0,["第二句"]),commands.command(401,0,[""]),commands.command(401,0,["末句"]),commands.command(108,0,["说明一"]),commands.command(408,0,["说明二"]),commands.command(408,0,["说明三"]),commands.command(106,0,[20]),commands.command(111,0,[0,1,0]),commands.command(101,1,["分支首句"]),commands.command(401,1,["分支续句"]),commands.command(412),commands.command(0)]
	sample[0]["custom_payload"]={"preserve":true}
	editor.configure(sample,docs)
	for frame in 4: await process_frame
	for index in range(4):
		await click_row(editor,index)
		expect(selected_rows(editor)==[0,1,2,3],"clicking any article line selects its whole block, including an empty line")
		expect(editor._selected_command()==0,"article selection resolves to the head record")
	await click_row(editor,5)
	expect(selected_rows(editor)==[4,5,6],"clicking a comment continuation selects every comment line only")
	await click_row(editor,10)
	expect(selected_rows(editor)==[9,10],"nested text selects its own command without enclosing branch commands")
	await click_row(editor,8)
	expect(selected_rows(editor)==[8],"selecting a condition does not highlight its body as continuations")
	expect(editor.draft()==sample and docs.dirty_paths().is_empty(),"selection preserves all original data without a document edit")
	await click_row(editor,2,true)
	expect(editor._command_index==0 and editor._command_dialog._parameters==["第一句\n第二句\n\n末句"],"double-clicking an empty continuation opens the complete original text")
	editor._command_dialog.hide(); await process_frame
	editor._copy_command()
	expect(editor._commands_clipboard==sample.slice(0,4),"copying from a continuation includes the complete command and unknown fields")
	editor._delete_command()
	expect(editor.draft()==sample.slice(4),"deleting from a continuation removes exactly one whole command")
	editor._paste_command()
	expect(editor.draft()==sample,"pasting restores the whole block, empty lines and unknown fields")
	expect(selected_rows(editor)==[0,1,2,3],"pasted command is selected as a whole")
	editor._move_command(1)
	expect(editor.draft().slice(0,3)==sample.slice(4,7) and editor.draft().slice(3,7)==sample.slice(0,4),"move preserves each native multiline block")
	expect(selected_rows(editor)==[3,4,5,6],"moved text retains complete selection")
	var key=InputEventKey.new(); key.keycode=KEY_DOWN; key.pressed=true
	editor._command_list.grab_focus(); root.push_input(key); await process_frame
	expect(selected_rows(editor)==[7],"keyboard down skips all continuations to the next command")
	key=InputEventKey.new(); key.keycode=KEY_UP; key.pressed=true; root.push_input(key); await process_frame
	expect(selected_rows(editor)==[3,4,5,6],"keyboard up selects the preceding complete block")
	key=InputEventKey.new(); key.keycode=KEY_ENTER; key.pressed=true; root.push_input(key); await process_frame
	expect(editor._command_index==3 and editor._command_dialog._parameters==["第一句\n第二句\n\n末句"],"keyboard accept opens the whole selected command")
	editor._command_dialog.hide(); await process_frame
	var long_text: Array=[commands.command(108,0,["长注释首句"])]
	for i in 40: long_text.append(commands.command(408,0,["说明%d" % i]))
	long_text.append(commands.command(0)); editor.configure(long_text,docs); editor._select_block(30)
	expect(selected_rows(editor).size()==41,"whole-command selection includes offscreen continuations with no row limit")
	for entry in [[209,509,[0,{"repeat":false,"skippable":false,"list":[{"code":0,"parameters":[]}]}],[{"code":1,"parameters":[]}]],[302,605,[0,1],[0,2]],[355,655,["original Ruby"],["continued Ruby"]]]:
		var list=[commands.command(entry[0],0,entry[2]),commands.command(entry[1],0,entry[3]),commands.command(0)]
		editor.configure(list,docs); editor._select_block(1)
		expect(selected_rows(editor)==[0,1] and editor._selected_command()==0,"other native continuation kinds belong to their head command")
		if entry[1]==509: expect(editor._rows[1].get_text(0)=="向下移动","event list displays the route action rather than a continuation label")
		if entry[1]==655: expect(editor._rows[1].get_description(0)=="continued Ruby","script continuation renders its source directly")
	var mismatched=[commands.command(108,0,["首行"]),commands.command(408,1,["原始异常缩进"]),commands.command(0)]
	editor.configure(mismatched,docs); editor._select_block(0); editor._copy_command()
	expect(editor._commands_clipboard==mismatched.slice(0,1),"copy does not include an unrelated continuation with mismatched indent")
	editor._delete_command(); expect(editor.draft()==mismatched.slice(1),"delete preserves the mismatched original record outside the selected block")
	var bound=[commands.command(355,0,["reward()"]),commands.command(355,0,["# adjacent source record"]),commands.command(655,0,[""]),commands.command(355,0,["false"]),commands.command(0)]
	bound[0]["_script_binding"]={"unit_id":"event_group","source_sha256":"original-group","command_count":4}
	bound[3]["_script_binding"]={"unit_id":"event_group_retry","source_sha256":"original-tail","command_count":1}
	editor.configure(bound,docs)
	expect(editor._rows[1].get_description(0)=="# adjacent source record" and editor._rows[2].get_description(0)=="" and editor._rows[3].get_description(0)=="false","bound adjacent355 source rows and empty655 lines share the source-only continuation display")
	await click_row(editor,3)
	expect(selected_rows(editor)==[0,1,2,3] and editor._selected_command()==0,"a bound adjacent355 group selects all source records including its retry tail")
	editor._edit_command(); editor._accept_command(355,editor._command_dialog._form.draft()); editor._command_dialog.hide()
	expect(editor.draft()==bound,"confirming an unchanged bound script preserves every continuation and retry binding")
	editor._accept_command(355,["changed_reward()"])
	var modified: Array=editor.draft()
	expect(modified.size()==2 and modified[0].parameters==["changed_reward()"] and modified[0]._script_binding.unit_id==bound[0]._script_binding.unit_id and int(modified[0]._script_binding.command_count)==1 and editor._status.text.contains("重新编译"),"editing a bound group retains identity and marks its stale binding for recompilation")
	editor._copy_command(); expect(editor._commands_clipboard==modified.slice(0,1),"bound script copy preserves the complete edited source group")
	editor._delete_command(); expect(editor.draft()==[commands.command(0)],"bound script delete removes one complete group")
	editor._paste_command(); expect(editor.draft()==modified,"bound script paste preserves edited source records and binding identity")
	for failure in failures: printerr("FAIL: ",failure)
	print("COMMAND BLOCK TESTS: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	editor.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
