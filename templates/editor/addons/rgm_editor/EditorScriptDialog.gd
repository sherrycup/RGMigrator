@tool
extends Window
const Workspace = preload("EditorScriptWorkspace.gd")
signal published
var _model: RefCounted
var _documents: RefCounted
var _entries: Array=[]
var _id=""
var _list: ItemList
var _search: LineEdit
var _kind: OptionButton
var _name: LineEdit
var _source: CodeEdit
var _original: CodeEdit
var _generated: CodeEdit
var _tabs: TabContainer
var _diagnostics: ItemList
var _mapping: ItemList
var _coverage: Tree
var _summary: Label
var _status: Label
var _pending=false
var _syncing=false
var _convert: Button

func _init() -> void:
	# A bare Window starts visible; keep it closed until the editor opens it.
	visible=false
	transient=true
	exclusive=true

func open(documents: RefCounted) -> void:
	if _source==null: _build()
	if _documents!=documents or _model==null: _documents=documents; _model=Workspace.new(documents)
	else:
		if not apply_current(): return
		_model.reload()
	_refresh_list(_id); _refresh_report()
	popup_centered(Vector2i(1180,800))
	grab_focus()

func apply_current() -> bool:
	if not _pending or _id.is_empty(): return true
	var result: Dictionary=_model.set_source(_id,_source.text)
	if result.ok: result=_model.rename(_id,_name.text)
	if not result.ok: _status.text=result.message; return false
	_pending=false; return true

func pending_status() -> String:
	return "脚本工作区有未应用的源码修改。" if _pending else ""

func reload() -> void:
	if _model==null: return
	_pending=false; _model.reload(); _refresh_list(_id); _refresh_report()

func _build() -> void:
	title="脚本工作区 · 原文 / 工作副本 / GDScript"; min_size=Vector2i(920,620)
	close_requested.connect(_close)
	var box=VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); box.offset_left=12; box.offset_right=-12; box.offset_top=12; box.offset_bottom=-12; add_child(box)
	var toolbar=HFlowContainer.new(); box.add_child(toolbar)
	_button(toolbar,"保存 Ctrl+S",_save)
	_convert=_button(toolbar,"保存并重新转换 F8",_compile)
	_button(toolbar,"新建 Ruby 脚本",_new_script)
	_button(toolbar,"用 Godot 编辑生成文件",_open_generated)
	_button(toolbar,"关闭",_close)
	var split=HSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(split)
	var sidebar=VBoxContainer.new(); sidebar.custom_minimum_size.x=260; split.add_child(sidebar)
	_search=LineEdit.new(); _search.placeholder_text="查找名称、单元或地图"; sidebar.add_child(_search); _search.text_changed.connect(func(_text: String) -> void: _filter())
	_kind=OptionButton.new(); sidebar.add_child(_kind)
	for caption in ["全部脚本","脚本库 · 按加载顺序","地图 / 公共事件","含转换诊断","工作副本"]: _kind.add_item(caption)
	_kind.item_selected.connect(func(_index: int) -> void: _filter())
	_list=ItemList.new(); _list.size_flags_vertical=Control.SIZE_EXPAND_FILL; sidebar.add_child(_list); _list.item_selected.connect(_select)
	var main=VBoxContainer.new(); main.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(main)
	var heading=HBoxContainer.new(); main.add_child(heading)
	var label=Label.new(); label.text="显示名称"; heading.add_child(label)
	_name=LineEdit.new(); _name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(_name); _name.text_changed.connect(func(_text: String) -> void: if not _syncing: _pending=true)
	_tabs=TabContainer.new(); _tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; _tabs.use_hidden_tabs_for_min_size=false; main.add_child(_tabs)
	_source=_code("Ruby 工作副本",true); _original=_code("原 Ruby · 只读",false); _generated=_code("生成 GDScript · 只读",false)
	_source.text_changed.connect(func() -> void: if not _syncing: _pending=true; _status.text="源码已修改；保存工作副本后，重新转换才会更新运行代码。")
	var bottom=TabContainer.new(); bottom.custom_minimum_size.y=190; bottom.use_hidden_tabs_for_min_size=false; main.add_child(bottom)
	_diagnostics=ItemList.new(); _diagnostics.name="转换诊断"; bottom.add_child(_diagnostics); _diagnostics.item_selected.connect(_jump_diagnostic)
	_mapping=ItemList.new(); _mapping.name="源码对应"; bottom.add_child(_mapping); _mapping.item_selected.connect(_jump_mapping)
	var coverage_box=VBoxContainer.new(); coverage_box.name="迁移覆盖"; bottom.add_child(coverage_box)
	_summary=Label.new(); _summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; coverage_box.add_child(_summary)
	_coverage=Tree.new(); _coverage.hide_root=true; _coverage.size_flags_vertical=Control.SIZE_EXPAND_FILL; coverage_box.add_child(_coverage); _coverage.item_activated.connect(_jump_coverage)
	_status=Label.new(); _status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(_status)

func _code(caption: String, editable: bool) -> CodeEdit:
	var edit=CodeEdit.new(); edit.name=caption; edit.editable=editable; edit.gutters_draw_line_numbers=true; edit.size_flags_vertical=Control.SIZE_EXPAND_FILL; _tabs.add_child(edit)
	var highlighter=CodeHighlighter.new(); highlighter.number_color=Color("b5cea8"); highlighter.symbol_color=Color("d4d4d4")
	for keyword in ["class","module","def","end","if","else","elsif","unless","while","for","return","nil","true","false","extends","func","var","const","static"]: highlighter.add_keyword_color(keyword,Color("c586c0"))
	edit.syntax_highlighter=highlighter; edit.add_theme_color_override("font_readonly_color",Color(0.87,0.87,0.87)); return edit

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button=Button.new(); button.text=caption; parent.add_child(button); button.pressed.connect(callback); return button

func _refresh_list(preferred: String="") -> void:
	_entries=_model.entries(); _filter(preferred)

func _filter(preferred: String="") -> void:
	var wanted=preferred if not preferred.is_empty() else _id
	_list.clear(); var selected=-1
	for row in _entries:
		var query=_search.text.strip_edges().to_lower()
		if not query.is_empty() and not (str(row.name)+" "+row.unit_id).to_lower().contains(query): continue
		if _kind.selected==1 and row.origin.kind!="script" or _kind.selected==2 and row.origin.kind not in ["map_event","common_event"] or _kind.selected==3 and _model.diagnostics(row.unit_id).is_empty() or _kind.selected==4 and not row.changed: continue
		var status=str(row.status)
		var classification=str(row.get("service_classification",""))
		if classification in ["service_adapted_with_original_retained","generated_and_service_adapted"] and status=="unsupported": status="服务适配 · Ruby未自动生成"
		_list.add_item(row.name+"  ["+status+"]"); _list.set_item_metadata(_list.item_count-1,row.unit_id)
		_list.set_item_tooltip(_list.item_count-1,row.unit_id+"\n"+JSON.stringify(row.origin))
		if row.unit_id==wanted: selected=_list.item_count-1
	if selected<0 and _list.item_count>0: selected=0
	if selected>=0: _list.select(selected); _select(selected)

func _select(index: int) -> void:
	if not apply_current(): return
	_id=str(_list.get_item_metadata(index)); var row: Dictionary={}
	for entry in _entries:
		if entry.unit_id==_id: row=entry; break
	_syncing=true; _name.text=row.name; _source.text=_model.source(_id); _source.editable=row.editable; _name.editable=row.editable
	_original.text=_model.source(_id,true); _generated.text=_model.generated(_id); _pending=false; _syncing=false
	if str(row.get("generated_path","")).is_empty() and _tabs.current_tab==2: _tabs.current_tab=1
	_status.text=("工作副本可编辑；原文和生成文件保留独立归属。" if row.editable else "原Ruby由专用GDScript/数据服务承担；在迁移覆盖中打开实际实现，原文仅查看。")+"  来源："+row.name+"（"+_id+"）"
	_refresh_diagnostics(); _mapping.clear()
	for mapping in _model.mappings(_id):
		_mapping.add_item("Ruby L%d → GDScript L%d · %s" % [int(mapping.get("span",{}).get("line",1)),int(mapping.get("generated_line",1)),mapping.get("generated_method",mapping.get("generated_function","program"))]); _mapping.set_item_metadata(_mapping.item_count-1,mapping)

func _refresh_diagnostics() -> void:
	_diagnostics.clear()
	for row in _model.diagnostics(_id):
		_diagnostics.add_item("L%d:C%d  %s" % [int(row.get("line",1)),int(row.get("column",1)),row.get("message",row.get("code","转换诊断"))]); _diagnostics.set_item_metadata(_diagnostics.item_count-1,row)
	if _diagnostics.item_count==0: _diagnostics.add_item("当前单元没有转换诊断；行为验证以专项记录和整体验收为准。"); _diagnostics.set_item_metadata(0,{})

func _refresh_report() -> void:
	var report: Dictionary=_model.coverage(); var c: Dictionary=report.counts
	_summary.text="AST %d / 生成 %d / 事件绑定 %d / 排除 %d / 含诊断 %d / 手工文件 %d。各项独立统计。" % [c.parsed,c.generated,c.bound,c.excluded,c.diagnostic_units,c.manual_files]
	_coverage.clear(); var top=_coverage.create_item(); var units=_coverage.create_item(top); units.set_text(0,"功能与服务入口")
	for row in report.units:
		var item=_coverage.create_item(units); item.set_text(0,row.unit_id+" · "+row.status+" · "+row.service_classification); item.set_metadata(0,{"unit_id":row.unit_id})
		for target in row.service_paths:
			var path=str(target)
			if path.ends_with(".gd"):
				var child=_coverage.create_item(item); child.set_text(0,"GDScript："+path); child.set_metadata(0,{"path":"res://runtime/scripts/"+path.get_file()})
		item.collapsed=true
	units.collapsed=true
	var syntax=_coverage.create_item(top); syntax.set_text(0,"语法节点 · 已解析输入")
	for key in report.syntax_nodes: var item=_coverage.create_item(syntax); item.set_text(0,str(key)+"："+str(report.syntax_nodes[key]))
	syntax.collapsed=true
	var api=_coverage.create_item(top); api.set_text(0,"API候选 · 尚需结合服务和行为证据判断")
	for key in report.api_candidates:
		var item=_coverage.create_item(api); item.set_text(0,str(key)+" · "+str(report.api_candidates[key].size())+"处")
		for entry in report.api_candidates[key]:
			var child=_coverage.create_item(item); child.set_text(0,entry.unit_id+" · L"+str(entry.line)); child.set_metadata(0,entry)
		item.collapsed=true
	api.collapsed=true
	var ownership=_coverage.create_item(top); ownership.set_text(0,"生成文件归属")
	for row in report.ownership:
		var item=_coverage.create_item(ownership); item.set_text(0,row.path+" · "+row.owner); item.set_metadata(0,{"path":"res://"+row.path})
	ownership.collapsed=true

func _save() -> void:
	if not apply_current(): return
	var result: Dictionary=_model.save(); _status.text="工作副本已保存；运行代码在转换成功后更新。" if result.ok else result.message
	if result.ok: _entries=_model.entries(); _refresh_report()

func _compile() -> void:
	if not apply_current(): return
	var saved: Dictionary=_model.save()
	if not saved.ok: _status.text=saved.message; return
	_convert.disabled=true; _status.text="正在转换当前工程脚本与事件…"; await get_tree().process_frame
	var result: Dictionary=_model.recompile(); _convert.disabled=false
	if result.ok:
		_refresh_list(_id); _refresh_report(); _status.text="转换成功，已更新运行代码、事件绑定和覆盖报告；备份："+str(result.backup)
		if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().scan()
		published.emit()
	else:
		_status.text=result.message
		if not result.get("diagnostics",[]).is_empty():
			var failed_id=str(result.diagnostics[0].get("unit_id",""))
			for i in _list.item_count:
				if _list.get_item_metadata(i)==failed_id: _list.select(i); _select(i); break
			_refresh_diagnostics(); _status.text=result.message

func _new_script() -> void:
	if not apply_current(): return
	var result: Dictionary=_model.add_script()
	if result.ok: _refresh_list(result.unit_id); _tabs.current_tab=0
	else: _status.text=result.message

func _jump_diagnostic(index: int) -> void:
	var row: Dictionary=_diagnostics.get_item_metadata(index)
	if row.is_empty(): return
	_tabs.current_tab=0; _jump(_source,int(row.get("line",1)),int(row.get("column",1)))

func _jump_mapping(index: int) -> void:
	var row: Dictionary=_mapping.get_item_metadata(index)
	_tabs.current_tab=2; _jump(_generated,int(row.get("generated_line",1)),1)

func _jump(edit: CodeEdit, line: int, column: int) -> void:
	edit.set_caret_line(clampi(line-1,0,edit.get_line_count()-1)); edit.set_caret_column(maxi(0,column-1)); edit.center_viewport_to_caret(); edit.grab_focus()

func _jump_coverage() -> void:
	var item=_coverage.get_selected()
	if item==null: return
	var metadata: Variant=item.get_metadata(0)
	if not metadata is Dictionary: return
	if metadata.has("path"): _open_script(metadata.path); return
	if metadata.has("unit_id"):
		_search.text=""; _kind.select(0); _filter(str(metadata.unit_id)); _tabs.current_tab=0; _jump(_source,int(metadata.get("line",1)),1)

func _open_generated() -> void:
	var path=str(_model._registry.get("units",{}).get(_id,{}).get("generated_path",""))
	if path.is_empty(): _status.text="该单元没有生成文件；请在迁移覆盖中查看服务实现。"; return
	_open_script(path)

func _open_script(path: String) -> void:
	if not Engine.is_editor_hint() or not FileAccess.file_exists(path): _status.text="实际源码："+path; return
	var script: Script=load(path)
	if script!=null: EditorInterface.edit_script(script); _status.text="手工修改后的生成文件会阻止自动覆盖："+path

func _close() -> void:
	if apply_current(): hide()

func _shortcut_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.keycode==KEY_S: _save(); get_viewport().set_input_as_handled()
	elif event.keycode==KEY_F8: _compile(); get_viewport().set_input_as_handled()
