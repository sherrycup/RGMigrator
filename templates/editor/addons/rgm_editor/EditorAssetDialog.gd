@tool
extends ConfirmationDialog
signal accepted(asset_name: String, settings: Dictionary)
const Preview=preload("EditorAssetPreview.gd")
var _documents: RefCounted
var _category=""
var _current=""
var _selected=""
var _settings: Dictionary={}
var _names: Array=[]
var _filtered: Array=[]
var _offset=0
var _search: LineEdit
var _list: ItemList
var _preview: Control
var _status: Label
var _page_label: Label
var _scroll: ScrollContainer
var _native: CheckButton
var _hue: SpinBox
var _opacity: SpinBox
var _character_bar: HBoxContainer
var _updating=false
var _caption=""

func open(documents: RefCounted, category: String, current: String, settings: Dictionary = {}, caption: String = "") -> void:
	_documents=documents; _category=category; _current=current; _selected=current; _settings=settings.duplicate(); _offset=0
	_caption=caption if not caption.is_empty() else str(Preview.TITLES.get(category,category))
	if _list==null: _build()
	title="更换素材 · "+_caption; _search.text=""; _native.set_pressed_no_signal(false)
	_names=_documents.assets(category); _names.push_front("")
	if not current.is_empty() and not current in _names: _names.insert(1,current)
	_updating=true; _hue.value=int(settings.get("hue",settings.get("character_hue",0))); _opacity.value=int(settings.get("opacity",255)); _updating=false
	_character_bar.visible=category=="Characters"; _filter(""); _update_preview(); popup_centered(Vector2i(900,650)); _search.grab_focus()

func _build() -> void:
	get_ok_button().text="使用此素材"; confirmed.connect(func() -> void: accepted.emit(_selected,_settings.duplicate()))
	var box=VBoxContainer.new(); box.custom_minimum_size=Vector2(820,520); add_child(box)
	_search=LineEdit.new(); _search.placeholder_text="搜索素材名称"; box.add_child(_search); _search.text_changed.connect(_filter)
	var split=HSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(split)
	var left=VBoxContainer.new(); left.custom_minimum_size.x=290; split.add_child(left)
	_list=ItemList.new(); _list.icon_mode=ItemList.ICON_MODE_LEFT; _list.fixed_icon_size=Vector2i(48,48); _list.size_flags_vertical=Control.SIZE_EXPAND_FILL; left.add_child(_list)
	_list.item_selected.connect(_select); _list.item_activated.connect(func(i: int) -> void: _select(i); if _category!="Characters": confirmed.emit(); hide())
	var pages=HBoxContainer.new(); left.add_child(pages)
	for entry in [["上一组",-80],["下一组",80]]:
		var button=Button.new(); button.text=entry[0]; pages.add_child(button); button.pressed.connect(_page.bind(entry[1]))
	_page_label=Label.new(); pages.add_child(_page_label)
	var right=VBoxContainer.new(); right.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(right)
	_native=CheckButton.new(); _native.text="原图尺寸（可滚动）"; right.add_child(_native); _native.toggled.connect(func(_pressed: bool) -> void: _update_preview())
	_scroll=ScrollContainer.new(); _scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; right.add_child(_scroll)
	_preview=Preview.new(); _preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _preview.size_flags_vertical=Control.SIZE_EXPAND_FILL; _scroll.add_child(_preview)
	_preview.frame_selected.connect(func(direction: int, pattern: int) -> void: _settings.direction=direction; _settings.pattern=pattern; _status.text="%s · 朝向%s · 第%d帧" % [_selected,{2:"下",4:"左",6:"右",8:"上"}[direction],pattern+1])
	_character_bar=HBoxContainer.new(); right.add_child(_character_bar)
	for entry in [["色相",360],["不透明度",255]]:
		var label=Label.new(); label.text=entry[0]; _character_bar.add_child(label)
		var spin=SpinBox.new(); spin.max_value=entry[1]; spin.allow_greater=true; spin.allow_lesser=true; _character_bar.add_child(spin)
		if entry[0]=="色相": _hue=spin
		else: _opacity=spin
		spin.value_changed.connect(func(_v: float) -> void:
			if _updating: return
			_settings.hue=int(_hue.value); _settings.opacity=int(_opacity.value); _update_preview())
	_status=Label.new(); _status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(_status)

func _filter(query: String) -> void:
	_filtered=_names.filter(func(n: Variant) -> bool: return query.is_empty() or str(n).to_lower().contains(query.to_lower()) or str(n).is_empty() and "无素材".contains(query))
	var at=_filtered.find(_selected); _offset=(at/80)*80 if at>=0 else 0; _fill()

func _fill() -> void:
	_list.clear()
	for i in range(_offset,mini(_offset+80,_filtered.size())):
		var asset_name=str(_filtered[i]); var texture=_documents.asset_texture(_category,asset_name); var icon: Texture2D=texture
		if texture!=null and _category=="Characters":
			var atlas=AtlasTexture.new(); atlas.atlas=texture; atlas.region=Rect2(Vector2.ZERO,texture.get_size()/4.0); icon=atlas
		_list.add_item("无素材" if asset_name.is_empty() else asset_name,icon); _list.set_item_metadata(_list.item_count-1,asset_name)
		if asset_name==_selected: _list.select(_list.item_count-1); _list.ensure_current_is_visible()
	_page_label.text="%d–%d / %d" % [mini(_offset+1,_filtered.size()),mini(_offset+80,_filtered.size()),_filtered.size()]

func _page(delta: int) -> void:
	_offset=clampi(_offset+delta,0,maxi(0,((_filtered.size()-1)/80)*80)); _fill()

func _select(index: int) -> void:
	_selected=str(_list.get_item_metadata(index)); _update_preview()

func _update_preview() -> void:
	_preview.configure(_documents,_category,_selected,_settings,true,false,_caption)
	var image: Texture2D=_preview.texture
	_preview.custom_minimum_size=Vector2(image.get_width()+12,image.get_height()+110) if _native.button_pressed and image!=null else Vector2(430,330)
	_status.text="当前：%s%s" % ["无素材" if _selected.is_empty() else _selected,"；素材缺失，原名称保留" if image==null and not _selected.is_empty() else "；确认后替换，取消保留原设置"]
