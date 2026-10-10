extends SceneTree
var _checks=0
var _failures: Array[String]=[]
var _docs: RefCounted
var _folder=""
var _commands: GDScript
var _display: GDScript

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	_checks+=1
	if not ok: _failures.append(message)

func _write(path: String, data: Variant) -> void:
	var full=_folder.path_join(path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file=FileAccess.open(full,FileAccess.WRITE)
	file.store_string(JSON.stringify(data)); file.close()

func _text(code: int, p: Array, characters: Dictionary = {}) -> String:
	return _commands.summary(_commands.command(code,0,p),_docs,characters)

func _has_safe_display(command: Dictionary, documents: RefCounted, characters: Dictionary = {}) -> bool:
	# A genuine empty continuation is a visible blank row in a multiline block.
	return not _commands.summary(command,documents,characters).is_empty() or int(command.get("code",0)) in [401,408] and command.get("parameters",[])==[""]

func _row(form: Control, path: Array) -> TreeItem:
	var items: Array=[form._tree.get_root()]
	while not items.is_empty():
		var item: TreeItem=items.pop_back()
		if item.get_metadata(0)==path: return item
		items.append_array(item.get_children())
	return null

func run() -> void:
	_commands=load("res://addons/rgm_editor/EditorCommands.gd")
	_display=load("res://addons/rgm_editor/EditorPresentation.gd")
	_folder=ProjectSettings.globalize_path("res://.godot/readability_%d" % Time.get_ticks_usec())
	_write("data/system.json",{"switches":[null,"剧情开始","","大门已打开"],"variables":[null,"钥匙数量","目标地图","目标X","目标Y"],"elements":[null,"火"]})
	_write("data/map_infos.json",{"1":{"name":"城镇"}})
	_write("data/test_setup.json",{})
	_write("data/asset_index.json",{})
	for category in ["Actors","Classes","Items","Weapons","Armors","Skills","States","Animations","Tilesets","CommonEvents"]:
		_write("data/database/%s.json" % category,[null,{"id":1,"name":category+"名称"}])
	_docs=load("res://addons/rgm_editor/EditorDocuments.gd").new(_folder)
	expect(_display.reference_text(_docs,"switches",1)=="[0001] 剧情开始","reference includes name and stable ID")
	expect(_display.reference_text(_docs,"switches",2)=="[0002] 未命名","unnamed differs from missing")
	expect(_display.reference_text(_docs,"switches",9)=="[0009] 缺失引用","missing ID is not renamed or guessed")
	expect(_display.reference_text(_docs,"Actors",0,"全体队员")=="[0000] 全体队员","zero actor means all only in valid context")
	expect(_display.reference_text(_docs,"Actors",0)=="[0000] 缺失引用","ordinary actor zero is invalid")
	expect(_display.reference_text(_docs,"variables",1.5).contains("无效编号"),"fractional reference is never truncated")
	expect(_text(121,[1,1,0])=="开关 [0001] 剧情开始 打开","switch summary decodes operation")
	expect(_text(121,[1,3,1]).contains("关闭") and _text(121,[1,3,1]).contains("含中间编号"),"switch ranges keep endpoints and middle IDs")
	expect(_text(122,[1,1,1,0,10])=="变量 [0001] 钥匙数量 += 10","variable constant is a value rather than an ID")
	expect(_text(122,[1.0,1.0,1.0,0.0,10.0])=="变量 [0001] 钥匙数量 += 10","JSON integer floats display as natural numbers")
	expect(_text(122,[1,1,0,1,2]).contains("变量 [0002] 目标地图"),"variable operand resolves its name")
	expect(_text(122,[1,1,0,2,3,5]).contains("随机整数 3…5"),"random operand expresses the range")
	expect(_text(122,[1,1,0,4,1,2]).contains("[0001] Actors名称 的HP"),"actor data operand is explicit")
	expect(_text(122,[1,1,0,6,-1,0]).contains("玩家 的地图X"),"character data has correct player target")
	expect(_text(111,[0,3,0]).contains("[0003] 大门已打开 为开启"),"condition states function and reference")
	expect(_text(111,[1,1,1,2,1]).contains("大于等于 变量 [0002] 目标地图"),"right-hand variable comparison is named")
	expect(_text(111,[4,1,2,1]).contains("已学特技 [0001] Skills名称"),"actor skill condition resolves nested reference")
	expect(_text(201,[0,1,3,4,2,0]).contains("场所 [0001] 城镇 移动；坐标(3, 4)；下；淡化"),"direct transfer names map, coordinates, direction and fade")
	expect(_text(201,[1,2,3,4,0,1]).contains("[0003] 目标X") and _text(201,[1,2,3,4,0,1]).contains("[0004] 目标Y"),"variable transfer resolves three distinct references")
	expect(_text(202,[2,2,-1,0,0],{"2":"[0002] 守卫"}).contains("位置 [0002] 守卫 设置：与 玩家 交换位置"),"event exchange resolves targets")
	expect(_text(207,[0,0]).contains("本事件（由调用上下文确定）") and _text(207,[0,0]).contains("[0000] 无动画"),"current event and empty animation are explicit")
	expect(_text(311,[0,1,1,1,false]).contains("HP [0000] 全体队员 −变量 [0001] 钥匙数量"),"party zero and amount source are decoded")
	expect(_text(319,[1,0,0]).contains("更换为 [0000] 卸下"),"equipment zero means unequip")
	expect(_text(106,[20]).contains("1秒"),"wait duration uses the existing 20Hz unit")
	expect(_text(236,[1,5,40]).contains("雨；强度5；1秒"),"weather duration uses the existing 40Hz unit")
	expect(_text(121,[]).contains("原始数据保留"),"malformed data has a safe fallback")
	expect(_text(999,[1]).contains("999") and _text(999,[1]).contains("保留"),"unknown code remains identifiable")
	expect(_commands.summary({"code":108,"parameters":["原Ruby"],"_editor_original":{"code":355}},_docs).contains("Ruby脚本占位"),"Ruby is visibly preserved rather than reported executable")
	for code in _commands.available():
		var c: Dictionary=_commands.command(code,0,_commands.defaults(code))
		var before=c.duplicate(true)
		var text: String=_commands.summary(c,_docs)
		expect(not text.is_empty() and not text.contains("原始参数保留"),"semantic summary exists for command "+str(code))
		expect(c==before,"rendering never changes command "+str(code))
		_display.parameter_hints(code,c.parameters)
	var form: Control=load("res://addons/rgm_editor/EditorValueForm.gd").new(); root.add_child(form)
	form.configure([1,1,0],_commands.parameters_for(121,[1,1,0]),_docs,_display.parameter_hints(121,[1,1,0]))
	expect(_row(form,[0]).get_text(1)=="[0001] 剧情开始","actual field tree displays reference name")
	expect(_row(form,[2]).get_text(1)=="开启（ON）","actual field tree displays the enum function")
	_row(form,[0]).select(0); form._edit_selected()
	var search: LineEdit
	var picker: ItemList
	for child in form._edit_body.get_children():
		if child is LineEdit: search=child
		if child is ItemList: picker=child
	expect(search!=null and picker!=null,"reference picker has a searchable name list")
	search.text="剧情"; search.text_changed.emit(search.text); expect(picker.item_count==1 and int(picker.get_item_metadata(0))==1,"name search retains the original ID")
	search.text="0003"; search.text_changed.emit(search.text); picker.item_selected.emit(0); form._accept(); form._dialog.hide()
	expect(form.draft()[0]==3 and _row(form,[0]).get_text(1)=="[0003] 大门已打开","choosing a name edits the ID, never the label")
	var list: Control=load("res://addons/rgm_editor/EditorCommandList.gd").new(); root.add_child(list)
	list.configure([_commands.command(121,0,[1,1,0]),_commands.command(111,0,[0,3,0]),_commands.command(106,1,[20]),_commands.command(411),_commands.command(412),_commands.command(0)],_docs)
	expect(list._command_list.get_root().get_children()[2].get_text(0).begins_with("│  等待"),"nested command has a readable branch guide")
	var system: Dictionary=_docs.read("data/system.json"); system.switches[1]="剧情入口"
	_docs.apply("data/system.json",system,"改名")
	expect(list._command_list.get_root().get_children()[0].get_text(0).contains("剧情入口"),"command list refreshes on draft rename")
	expect(_docs.undo() and list._command_list.get_root().get_children()[0].get_text(0).contains("剧情开始"),"undo refreshes reference labels")
	form.configure([77],[],_docs,{"0":{"options":{"0":"关闭","1":"开启"}}})
	_row(form,[0]).select(0); form._edit_selected(); form._accept(); form._dialog.hide()
	expect(form.draft()[0]==77,"confirming an unknown enum never substitutes the first option")
	form.configure([900000000],[],_docs,{"0":{"db":"switches","min":1}})
	_row(form,[0]).select(0); form._edit_selected(); form._accept(); form._dialog.hide()
	expect(form.draft()[0]==900000000,"opening a missing legacy reference never clamps its number")
	form.configure([0],[],_docs,_display.parameter_hints(314,[0])); _row(form,[0]).select(0); form._edit_selected()
	for child in form._edit_body.get_children():
		if child is ItemList: expect(child.get_item_metadata(0)==0 and child.get_item_text(0).contains("全体队员"),"zero sentinel is selectable by its meaning")
	form._dialog.hide()
	var route: Control=load("res://addons/rgm_editor/EditorRouteForm.gd").new(); root.add_child(route)
	route.configure({"repeat":false,"skippable":false,"list":[{"code":27,"parameters":[1]},{"code":43,"parameters":[1]},{"code":0,"parameters":[]}]},_docs)
	expect(route._list.get_root().get_children()[0].get_text(0).contains("开关 [0001] 剧情开始 打开"),"route list uses the same switch labels")
	expect(route._list.get_root().get_children()[1].get_text(0).contains("加算"),"route list displays blend meaning")
	var dialog: ConfirmationDialog=load("res://addons/rgm_editor/EditorCommandDialog.gd").new(); root.add_child(dialog)
	dialog.open(_docs,201,[1,2,3,4,0,1],false)
	expect(dialog._form._display(3,[2]).contains("目标X"),"transfer form decodes variable coordinates")
	dialog.hide(); dialog.open(_docs,302,[[0,1],[1,1],[2,1]],false)
	expect(_row(dialog._form,[0,0]).get_text(1)=="物品" and _row(dialog._form,[1,1]).get_text(1)=="[0001] Weapons名称","shop rows show type and database name")
	dialog._form._put([0,0],1); await process_frame
	expect(_row(dialog._form,[0,1]).get_text(1)=="[0001] Weapons名称","changing shop type refreshes its dependent reference")
	dialog.hide()
	form.queue_free(); list.queue_free(); route.queue_free(); dialog.queue_free(); await process_frame
	var source: RefCounted=load("res://addons/rgm_editor/EditorDocuments.gd").new()
	var manifest: Dictionary=source.read("data/manifest.json")
	var count=0
	for map_name in manifest.maps:
		var map: Dictionary=source.read("data/maps/"+str(map_name)+".json")
		var targets={}
		for key in map.get("events",{}): targets[str(int(key))]="[%04d] %s" % [int(key),map.events[key].get("name","")]
		for event in map.get("events",{}).values():
			for page in event.get("pages",[]):
				for c in page.list: expect(_has_safe_display(c,source,targets),"original map command has safe display"); count+=1
		await process_frame
	for common in source.records("CommonEvents"):
		if common is Dictionary:
			for c in common.get("list",[]): expect(_has_safe_display(c,source),"original common command has safe display"); count+=1
	expect(source.dirty_paths().is_empty(),"all original summaries leave documents unchanged")
	print("READABILITY ORIGINAL COMMANDS: ",count)
	for failure in _failures: printerr("FAIL: ",failure)
	print("EDITOR READABILITY TESTS: ","PASSED" if _failures.is_empty() else "FAILED"," / ",_checks," checks")
	quit(0 if _failures.is_empty() else 1)
