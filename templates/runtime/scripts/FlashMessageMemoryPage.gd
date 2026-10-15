extends Control
## 0157/0200/0202: L history, Tab channels, latest entry selected, source limits.
signal close_requested
const Text=preload("FlashMessageText.gd")
const Resources=preload("UIResources.gd")
var page="flash_history"
var mode_index=0
var index=0
var records: Array=[]
var _content: Control
var _scroll: ScrollContainer
var _selected: Control

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(refresh); check_text()

func check_text() -> void:
	records=RuntimeState.flash_messages.history(mode_index==1)
	index=maxi(0,records.size()-1); refresh()

func refresh() -> void:
	if not is_inside_tree() or size.x<1: return
	if _content!=null: remove_child(_content); _content.queue_free()
	_content=Control.new(); _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_content)
	_label("剧情回顾",Rect2(24,12,size.x-48,36),24)
	_label("剧情文本" if mode_index==0 else "主动信息",Rect2(size.x-128,64,112,32),20)
	_label("Tab 切换",Rect2(size.x-128,108,112,32),17)
	_label("%d / %d" % [0 if records.is_empty() else index+1,records.size()],Rect2(size.x-128,size.y-100,112,32),20)
	_label("↑↓条目 · Esc返回",Rect2(24,size.y-48,size.x-48,32),17)
	_scroll=ScrollContainer.new(); _scroll.position=Vector2(24,64); _scroll.size=Vector2(maxf(1,size.x-172),maxf(1,size.y-132)); _content.add_child(_scroll)
	var list=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",12); _scroll.add_child(list)
	_selected=null
	for entry_id in records.size():
		var row=HBoxContainer.new(); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_child(row)
		var name=Label.new(); name.text=str(records[entry_id][0]); name.custom_minimum_size.x=96; name.add_theme_font_override("font",Resources.font()); name.add_theme_font_size_override("font_size",18); name.vertical_alignment=VERTICAL_ALIGNMENT_TOP; row.add_child(name)
		var separator=VSeparator.new(); row.add_child(separator)
		var text=RichTextLabel.new(); text.fit_content=true; text.scroll_active=false; text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; text.custom_minimum_size.x=maxf(40,_scroll.size.x-128)
		text.text=plain_text(str(records[entry_id][1])); text.add_theme_font_override("normal_font",Resources.font()); text.add_theme_font_size_override("normal_font_size",18); row.add_child(text)
		if entry_id==index: row.modulate=Color("f9e6b7"); _selected=row
	if _selected!=null: _scroll.call_deferred("ensure_control_visible",_selected)
	queue_redraw()

func plain_text(raw: String) -> String:
	var parsed=Text.parse(raw.replace("\\n","\n"),RuntimeState)
	if not parsed.ok: return parsed.message
	var result=""
	for token in parsed.tokens:
		if token is String: result+=token
		elif token[0].unicode_at(0)==2: result+=str(RuntimeState.custom_data.currency())+str(preload("RuntimeData.gd").system().get("words",{}).get("gold",""))
	return result

func handle_key(key: int) -> void:
	if key in [KEY_ESCAPE,KEY_X]: close_requested.emit()
	elif key==KEY_TAB: mode_index=1-mode_index; check_text()
	elif key in [KEY_UP,KEY_DOWN] and not records.is_empty(): index=posmod(index+(1 if key==KEY_DOWN else -1),records.size()); refresh()
	elif key in [KEY_PAGEUP,KEY_PAGEDOWN]: _scroll.scroll_vertical+=int(_scroll.size.y)*(1 if key==KEY_PAGEDOWN else -1)

func _label(text: String,rect: Rect2,font_size: int) -> void:
	var label=Label.new(); label.text=text; label.position=rect.position; label.size=rect.size; label.add_theme_font_override("font",Resources.font()); label.add_theme_font_size_override("font_size",font_size); _content.add_child(label)

func _draw() -> void: draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,0.78))
