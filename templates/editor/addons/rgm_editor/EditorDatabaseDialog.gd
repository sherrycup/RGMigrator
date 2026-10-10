@tool
extends ConfirmationDialog
const Schema = preload("EditorDatabaseSchema.gd")
const Scripts = preload("EditorScriptAdapter.gd")
const Form = preload("EditorDatabaseForm.gd")
const CommandList = preload("EditorCommandList.gd")
var _documents: RefCounted
var _category=""
var _id=0
var _before: Dictionary={}
var _form: VBoxContainer
var _commands: VBoxContainer
var _categories: OptionButton
var _records: ItemList
var _search: LineEdit
var _status: Label
var _heading: Label
var _preview: Control
var _preview_path: Array=[]
var _clear_dialog: ConfirmationDialog
var _new_button: Button
var _copy_button: Button
var _clear_button: Button
var _building=false
var _reserved_ids: Dictionary={}
var _offset=0
var _page: Label
var _jump: SpinBox
var _capacity: ConfirmationDialog
var _maximum: SpinBox
var _capacity_button: Button
var _pages: HBoxContainer
var _page_memory: Dictionary={}
var _form_category=""
var _data: Variant
var _tileset_editor: VBoxContainer
var _sources_dialog: ConfirmationDialog
var _audio_browser: VBoxContainer

func open(documents: RefCounted) -> void:
	_documents=documents
	if _form==null: _build()
	if _category.is_empty(): _select_category(0)
	else: _reload_record()
	popup_centered(Vector2i(1120,720))
	get_cancel_button().hide()

func apply_current() -> bool:
	if _before.is_empty() or _read_only(): return true
	var value=_draft()
	if value==_before: return true
	var reason=Schema.reason(_category,value,_before,_documents)
	if not reason.is_empty(): _status.text=reason; return false
	var path=_path()
	var data: Variant=_documents.read(path)
	if _category=="System": data=value
	else: data[_id]=value
	var result: Dictionary
	if _category=="Tilesets":
		var prepared=preload("EditorTilesetOps.gd").prepare(_documents,_id,_before,value)
		if not prepared.ok: _status.text=prepared.message; return false
		result=_documents.apply_batch(prepared.changes,"编辑图块集 %04d" % _id)
	else: result=_documents.apply(path,data,"编辑%s %04d" % [Schema.CATEGORIES.get(_category,_category),_id])
	if not result.ok: _status.text=result.message; return false
	_refresh_records(_id); _load_record(_id)
	_status.text="已应用到草稿；未保存文件%d。" % _documents.dirty_paths().size()
	return true

func open_tileset(documents: RefCounted, id: int) -> void:
	open(documents)
	for i in _categories.item_count:
		if _categories.get_item_metadata(i)=="Tilesets":
			_categories.select(i); _select_category(i); break
	_refresh_records(id); _load_record(id)

func pending_status() -> String:
	return "数据库当前条目有修改，保存时合并。" if not _before.is_empty() and not _read_only() and _draft()!=_before else ""

func _build() -> void:
	title="数据库与公共事件 · "+preload("res://runtime/scripts/RuntimeVersion.gd").VERSION
	get_ok_button().text="关闭（保留草稿）"; get_cancel_button().text="关闭"
	confirmed.connect(func() -> void:
		if not apply_current(): call_deferred("popup_centered",Vector2i(1120,720)))
	canceled.connect(_close_draft)
	var box=VBoxContainer.new(); box.custom_minimum_size=Vector2(990,590); add_child(box)
	var bar=HFlowContainer.new(); box.add_child(bar)
	_categories=OptionButton.new(); bar.add_child(_categories)
	for key in Schema.CATEGORIES: _categories.add_item(Schema.CATEGORIES[key]); _categories.set_item_metadata(_categories.item_count-1,key)
	_categories.add_item("音频素材"); _categories.set_item_metadata(_categories.item_count-1,"Audio")
	_categories.item_selected.connect(_select_category)
	_new_button=_button(bar,"新增条目",_new_record.bind(false))
	_copy_button=_button(bar,"复制条目",_new_record.bind(true))
	_clear_button=_button(bar,"清空条目",func() -> void: _clear_dialog.popup_centered())
	_capacity_button=_button(bar,"设置最大编号…",_open_capacity)
	_button(bar,"保存 Ctrl+S",_save)
	_button(bar,"撤销",_undo.bind(false)); _button(bar,"重做",_undo.bind(true))
	var note=Label.new(); note.custom_minimum_size.x=990; note.size.x=990; note.text="切换条目或关闭保留编辑草稿；Ctrl+S保存文件，撤销可恢复。编号保持不变，空槽位可直接编辑。"; note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(note)
	var split=HSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(split)
	var left=VBoxContainer.new(); left.custom_minimum_size.x=230; split.add_child(left)
	_search=LineEdit.new(); _search.placeholder_text="按编号或名称搜索"; left.add_child(_search); _search.text_changed.connect(func(_text: String) -> void: _offset=0; _refresh_records())
	_records=ItemList.new(); _records.size_flags_vertical=Control.SIZE_EXPAND_FILL; left.add_child(_records); _records.item_selected.connect(_select_record)
	_pages=HBoxContainer.new(); left.add_child(_pages)
	_button(_pages,"‹",_page_by.bind(-100)); _button(_pages,"›",_page_by.bind(100))
	_page=Label.new(); _page.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _pages.add_child(_page)
	_jump=SpinBox.new(); _jump.min_value=1; _jump.max_value=32767; _jump.step=1; _jump.custom_minimum_size.x=90; _pages.add_child(_jump)
	_button(_pages,"跳转",_jump_to)
	_capacity=ConfirmationDialog.new(); _capacity.title="设置最大编号"; add_child(_capacity)
	var capacity_box=VBoxContainer.new(); capacity_box.custom_minimum_size.x=440; _capacity.add_child(capacity_box)
	var capacity_note=Label.new(); capacity_note.text="新增编号默认为空槽位，可按区间规划。\n编号0保留；缩容须通过内容和引用检查。\n确认只修改草稿，Ctrl+S保存文件。"; capacity_box.add_child(capacity_note)
	_maximum=SpinBox.new(); _maximum.min_value=1; _maximum.max_value=32767; _maximum.step=1; capacity_box.add_child(_maximum)
	_capacity.dialog_hide_on_ok=false; _capacity.confirmed.connect(_resize_capacity)
	_preview=preload("EditorAssetPreview.gd").new(); _preview.custom_minimum_size=Vector2(180,140); left.add_child(_preview); _preview.activated.connect(func() -> void: if not _preview_path.is_empty(): _form.edit_asset(_preview_path))
	var right=VBoxContainer.new(); right.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(right)
	_heading=Label.new(); right.add_child(_heading)
	_tileset_editor=preload("EditorTilesetEditor.gd").new(); _tileset_editor.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(_tileset_editor); _tileset_editor.sources_requested.connect(_open_sources)
	_audio_browser=preload("EditorAudioBrowser.gd").new(); _audio_browser.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(_audio_browser); _audio_browser.hide()
	_form=Form.new(); _form.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(_form); _form.value_changed.connect(func(_v: Variant, _p: Array, _e: Variant) -> void: _update_preview())
	_form.asset_edit_requested.connect(func(_path: Array) -> void: _open_sources())
	_commands=CommandList.new(); _commands.custom_minimum_size.y=240; _commands.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(_commands)
	_status=Label.new(); _status.custom_minimum_size.x=990; _status.size.x=990; _status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(_status)
	_clear_dialog=ConfirmationDialog.new(); _clear_dialog.title="清空数据库条目"; _clear_dialog.dialog_text="将此条目重置为空白默认定义，并保留ID。其他事件或条目的引用仍指向这个编号。保存前可以撤销。"; add_child(_clear_dialog); _clear_dialog.confirmed.connect(_clear_record)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button=Button.new(); button.text=text; button.pressed.connect(action); parent.add_child(button); return button

func _path() -> String:
	return "data/system.json" if _category=="System" else "data/database/%s.json" % _category

func _read_only() -> bool:
	return _category in ["Troops","Audio"]

func _draft() -> Dictionary:
	var value: Dictionary=_tileset_editor.draft() if _category=="Tilesets" else _form.draft()
	if _category=="CommonEvents": value.list=_commands.draft()
	return Schema.normalize(_category,value,_before)

func _select_category(index: int) -> void:
	if not apply_current():
		for i in _categories.item_count:
			if _categories.get_item_metadata(i)==_category: _categories.select(i)
		return
	_remember_page()
	_category=str(_categories.get_item_metadata(index)); _search.text=""; _id=0; _before={}; _offset=0
	_pages.visible=_category not in ["System","Audio"]
	_capacity_button.disabled=_category in ["System","Audio","Troops"]
	_search.visible=_category not in ["System","Audio"]
	_audio_browser.visible=_category=="Audio"
	_form._tabs.tabs_visible=_category!="System"
	if _category=="Audio":
		_before={}; _new_button.disabled=true; _copy_button.disabled=true; _clear_button.disabled=true
		_form.hide(); _tileset_editor.hide(); _commands.hide(); _preview.hide()
		_refresh_records(); _select_record(0); return
	if _category=="CommonEvents":
		var data: Variant=_documents.read(_path())
		if data is Array:
			var adapted=Scripts.adapt_common(data)
			if adapted!=data: _documents.apply(_path(),adapted,"公共事件脚本注释占位")
	_refresh_records()
	_new_button.disabled=_category=="System" or _read_only(); _copy_button.disabled=_new_button.disabled; _clear_button.disabled=_new_button.disabled
	_tileset_editor.visible=_category=="Tilesets"
	_form.visible=_category!="Tilesets"
	var values: Variant=_documents.read(_path())
	if _category=="System": _load_record(0)
	elif values is Array:
		for i in range(1,values.size()):
			if values[i] is Dictionary: _load_record(i); return
		_form.configure({},Schema.LABELS,_documents); _tileset_editor.hide(); _preview.hide(); _commands.hide(); _heading.text="此数据库为空，可以新增条目。"
	else: _status.text="数据库缺失或格式无效："+_path()

func _refresh_records(preferred: int = -1) -> void:
	_building=true; _records.clear()
	var data: Variant=_documents.read(_path()) if _category!="Audio" else null
	_data=data
	_reserved_ids.clear()
	var setup: Variant=_documents.read("data/test_setup.json")
	if setup is Dictionary:
		for entry in setup.get("definitions",{}).get(_category,[]): _reserved_ids[int(entry.get("id",0))]=true
	if _category=="Audio":
		for kind in ["BGM","BGS","ME","SE"]: _records.add_item(kind); _records.set_item_metadata(_records.item_count-1,kind)
		_records.select(0); _building=false; return
	if _category=="System":
		for index in _form._tabs.get_tab_count(): _records.add_item(_form._tabs.get_tab_title(index)); _records.set_item_metadata(index,index)
		preferred=_form._tabs.current_tab
	elif data is Array:
		var matches: Array=[]; var query=_search.text.to_lower()
		for i in range(1,data.size()):
			var title=_documents.reference_label(_category,i) if data[i] is Dictionary else "[%04d] 空槽位" % i
			if _reserved(i): title="[%04d] 测试保留" % i
			if not query.is_empty() and not title.to_lower().contains(query): continue
			matches.append({"id":i,"title":title})
		if preferred>0:
			for index in matches.size():
				if matches[index].id==preferred: _offset=int(index/100)*100; break
		_offset=clampi(_offset,0,maxi(0,int((matches.size()-1)/100)*100))
		for index in range(_offset,mini(_offset+100,matches.size())):
			_records.add_item(matches[index].title); _records.set_item_metadata(_records.item_count-1,matches[index].id)
		_page.text="%d–%d / %d" % [mini(_offset+1,matches.size()),mini(_offset+100,matches.size()),matches.size()]
		_jump.max_value=maxi(1,data.size()-1)
	for i in _records.item_count:
		if int(_records.get_item_metadata(i))==preferred: _records.select(i)
	_building=false

func _select_record(index: int) -> void:
	if _building: return
	if _category=="Audio":
		var kind=str(_records.get_item_metadata(index)); _audio_browser.configure(_documents,kind); _heading.text="音频素材 / "+kind; _status.text="素材来自当前工程Audio目录；双击文件试听。音量和声调只影响试听，不改写原文件。"; return
	if _category=="System": _form._tabs.current_tab=index; return
	var id=int(_records.get_item_metadata(index))
	if not apply_current(): _refresh_records(_id); return
	_load_record(id)

func _load_record(id: int) -> void:
	_remember_page()
	_id=id
	_form.size_flags_vertical=Control.SIZE_FILL if _category=="CommonEvents" else Control.SIZE_EXPAND_FILL
	_form.custom_minimum_size.y=130 if _category=="CommonEvents" else 260
	_form._tabs.tabs_visible=_category not in ["System","CommonEvents"]
	if _reserved(id):
		_clear_button.disabled=true; _copy_button.disabled=true
		_before={}; _form.configure({},Schema.LABELS,_documents,{},true); _commands.hide(); _tileset_editor.hide()
		_heading.text="[%04d] 测试保留编号" % id; _status.text="此编号由测试定义使用，请选择其它空槽位。"; return
	_clear_button.disabled=_category=="System" or _read_only(); _copy_button.disabled=_clear_button.disabled
	var data: Variant=_data
	_before=data.duplicate(true) if _category=="System" and data is Dictionary else data[id].duplicate(true) if data is Array and id<data.size() and data[id] is Dictionary else Schema.new_record(_category,id,_documents)
	var value=_before.duplicate(true)
	_commands.visible=_category=="CommonEvents"
	if _category=="CommonEvents":
		_commands.configure(value.get("list",[]),_documents)
		value.erase("list")
	_tileset_editor.visible=_category=="Tilesets"; _form.visible=_category!="Tilesets"
	if _category=="Tilesets":
		_form.configure({},Schema.LABELS,null)
		_tileset_editor.configure(value,_documents)
	else: _form.configure(value,Schema.LABELS,_documents,Schema.hints(_category,value),_read_only())
	_restore_page()
	if _category=="System": _refresh_records()
	_heading.text="%s / %04d   %s" % [Schema.CATEGORIES.get(_category,_category),_id,_path()]
	_status.text="原生敌群与战斗页仅保留查看；自定义$game_troop数据不删除，Ruby转换暂缓。" if _read_only() else "在画布上点格或拖动修改属性，右侧精确设置；切换属性复用同一张图块画布。" if _category=="Tilesets" else "从左侧选择系统设置页；起点在地图上点选，音乐与音效可试听。Ctrl+S保存文件。" if _category=="System" else "按用途切换页签；名称、数值和选项直接编辑，双击图片更换素材。Ctrl+S保存文件。"
	for i in _records.item_count:
		if _category!="System" and int(_records.get_item_metadata(i))==id: _records.select(i); break
	_update_preview()

func _update_preview() -> void:
	# Database forms already show named image previews in their primary tab.
	_preview_path=[]; _preview.hide(); return

func _reload_record() -> void:
	if _category.is_empty(): return
	if _category=="Audio": _audio_browser.stop(); return
	_refresh_records(_id)
	var data: Variant=_documents.read(_path())
	if _category=="System": _load_record(0)
	elif data is Array and _id>0 and _id<data.size(): _load_record(_id)
	else: _before={}; _select_category(_categories.selected)

func _open_sources() -> void:
	if _category!="Tilesets" or _before.is_empty(): return
	if _sources_dialog==null:
		_sources_dialog=preload("EditorTilesetSourcesDialog.gd").new(); add_child(_sources_dialog)
		_sources_dialog.accepted.connect(func(_value: Dictionary) -> void: _reload_record())
	_sources_dialog.open(_documents,_tileset_editor.draft())

func _new_record(copy: bool) -> void:
	if _read_only() or _category=="System" or not apply_current(): return
	var data: Array=_documents.records(_category)
	if data.is_empty(): data.append(null)
	var id=data.size()
	# Test definitions occupy separate, higher IDs. Do not create a collision.
	var setup: Variant=_documents.read("data/test_setup.json")
	var reserved: Array=[]
	if setup is Dictionary:
		for record in setup.get("definitions",{}).get(_category,[]): reserved.append(int(record.get("id",0)))
	while id in reserved: data.append(null); id+=1
	var value=_before.duplicate(true) if copy and not _before.is_empty() else Schema.new_record(_category,id,_documents)
	value.id=id; value.name=str(value.get("name",""))+" 副本" if copy else "新建"+str(Schema.CATEGORIES.get(_category,_category))
	data.append(value); _documents.apply(_path(),data,"新增数据库条目"); _refresh_records(id); _load_record(id)

func _clear_record() -> void:
	if _read_only() or _category=="System": return
	var data: Array=_documents.records(_category); data[_id]=Schema.new_record(_category,_id,_documents)
	var result: Dictionary
	if _category=="Tilesets":
		var plan=preload("EditorTilesetOps.gd").prepare(_documents,_id,_before,data[_id])
		if not plan.ok: _status.text=plan.message; return
		result=_documents.apply_batch(plan.changes,"清空图块集（保留ID）")
	else: result=_documents.apply(_path(),data,"清空数据库条目（保留ID）")
	if not result.ok: _status.text=result.message; return
	_refresh_records(_id); _load_record(_id)

func _undo(redo: bool) -> void:
	if not pending_status().is_empty(): _reload_record(); _status.text="已撤销当前尚未应用的字段。"; return
	if redo: _documents.redo()
	else: _documents.undo()
	_reload_record()

func _save() -> void:
	if not apply_current(): return
	var result: Dictionary=_documents.save_all()
	_status.text="已保存%d个文件。重新运行游戏读取新定义。" % int(result.get("count",0)) if result.ok else str(result.message)
	if result.ok and int(result.get("count",0))>0 and Engine.is_editor_hint() and not EditorInterface.get_resource_filesystem().is_scanning(): EditorInterface.get_resource_filesystem().scan()

func _shortcut_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.keycode==KEY_S:
		_save(); set_input_as_handled()
	elif event.ctrl_pressed and event.keycode in [KEY_Z,KEY_Y]:
		var focus=gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		_undo(event.keycode==KEY_Y); set_input_as_handled()

func _remember_page() -> void:
	if _form_category.is_empty() or _form==null or _form._tabs.get_tab_count()==0: return
	_page_memory[_form_category]=_form._tabs.get_tab_title(_form._tabs.current_tab)

func _restore_page() -> void:
	_form_category=_category
	var wanted=str(_page_memory.get(_category,""))
	for index in _form._tabs.get_tab_count():
		if _form._tabs.get_tab_title(index)==wanted: _form._tabs.current_tab=index; return

func _close_draft() -> void:
	if not apply_current(): call_deferred("popup_centered",Vector2i(1120,720))

func _reserved(id: int) -> bool:
	return _reserved_ids.has(id)

func _page_by(delta: int) -> void:
	_offset=maxi(0,_offset+delta); _refresh_records()

func _jump_to() -> void:
	if not apply_current(): return
	var id=int(_jump.value); _search.text=""; _refresh_records(id); _load_record(id)

func _open_capacity() -> void:
	if _capacity_button.disabled or not apply_current(): return
	_maximum.value=maxi(1,_documents.records(_category).size()-1); _capacity.popup_centered(Vector2i(500,240))

func _resize_capacity() -> void:
	if not apply_current(): return
	var prepared=preload("EditorCapacityOps.gd").resize(_documents,_category,_documents.records(_category),int(_maximum.value))
	if not prepared.ok: _status.text=prepared.message; return
	var result=_documents.apply(_path(),prepared.value,"设置%s最大编号%d" % [Schema.CATEGORIES[_category],int(_maximum.value)])
	if not result.ok: _status.text=result.message; return
	_capacity.hide(); _before={}; _refresh_records(mini(_id,int(_maximum.value))); _load_record(clampi(_id,1,int(_maximum.value)))
	_status.text="最大编号%d；空槽位按需编辑，Ctrl+S保存文件。" % int(_maximum.value)
